#lang racket/base
;;; The workman at the frame.
;;;
;;; A compositor holds a composing stick set to the measure and fills it
;;; letter by letter from the two cases before him. He cannot see the line as
;;; the reader will see it; he sees a row of metal upside down and back to
;;; front, and he knows a line is finished when it will not take another sort.
;;;
;;; The order of operations is the order of the trade:
;;;
;;; The order below is the order it happened in, and it matters that there is
;;; only one place where the spelling of a word is settled. An earlier version
;;; settled it twice -- habit committed a form as the word was made, and
;;; justification revised that form when the line came up short -- so the two
;;; could and did contradict each other, turning `composed' into `compos'd' and
;;; back into `composed' and reporting both moves. A compositor does not change
;;; his mind about a word after setting it; he decides once, and the line is
;;; part of what he decides with. So habit proposes and the measure disposes:
;;; step 3 may give the habit up (which costs the reader nothing, and is
;;; therefore the first thing tried), but nothing after step 3 touches spelling.
;;;
;;;   1. he reads a stretch of copy, and may misread it;
;;;   2. he sets it in his own spelling, not his author's;
;;;   3. he finds the line will not justify, and settles the spelling for room
;;;      rather than for habit: first by giving the habit up and setting what
;;;      the copy said, then, if that will not serve, by another spelling;
;;;   4. he applies the conventions of the house: long s, u for v, i for j;
;;;   5. he picks the sorts, and picks some of them wrong.
;;;
;;; TWO THINGS THE RACKET VERSION DOES THAT THE PYTHON ONE COULD NOT.
;;;
;;; Words are immutable. In the Python original, trying whether one more word
;;; would pinch into a line meant mutating the words, discovering it would
;;; not, and restoring them from a snapshot -- and a bug in that restore was
;;; real. Here `justify' returns a fresh line built from fresh words, or #f if
;;; the line will not go. A rejected trial simply is not used; there is
;;; nothing to undo, because nothing was ever changed.
;;;
;;; And the measure is a contract, not a test. A line wider than the measure
;;; cannot be locked up in a chase, so it must not be constructible. `make-line'
;;; carries a post-condition to that effect, which means the invariant is
;;; checked at every construction rather than by a script run afterwards.

(require racket/list racket/string racket/match racket/contract racket/math
         "metrics.rkt" "orthography.rkt" "typecase.rkt" "copytext.rkt" "rng.rkt")

(provide WORD-STAGES at-stage
         (struct-out word) (struct-out set-line) (struct-out event)
         (struct-out profile) (struct-out page-spec)
         PROFILES make-comp comp? comp-profile comp-events comp-rng comp-case
         line-set-width line-text
         set-prose set-verse set-stage-direction set-heading set-centred
         speech-prefix
         pick-line! add-event! comp-event-list
         (contract-out
          [make-line (->* ((listof word?) (listof exact-integer?)
                           exact-nonnegative-integer? exact-positive-integer?
                           symbol?)
                          (#:justification string? #:turned-over? boolean?
                           #:quadded? boolean? #:italic? boolean?)
                          set-line?)]))

;; ---------------------------------------------------------------------------
;; Record keeping
;; ---------------------------------------------------------------------------

;; One thing that happened at the frame, for the record of composition.
;; kind is 'habit 'justification 'accident 'copy 'shift 'press
(struct event (kind detail page line word compositor before after)
  #:transparent)

(define (make-event kind detail
                    #:page [page ""] #:line [line 0] #:word [wd -1]
                    #:compositor [c ""] #:before [b ""] #:after [a ""])
  (event kind detail page line wd c b a))

;; A single word on its way from copy to metal.
;;
;; Every stage is kept, because the difference between any two of them is a
;; different kind of bibliographical fact: copy against read is a misreading,
;; read against habit is the workman's spelling, habit against final is the
;; measure talking, and composed against printed is the case.
;; `pieces' records which individually identifiable types printed this word,
;; as (character-index . sort-piece). It is the raw material of Hinman's
;; method: the same piece turning up in another forme proves a shared case.
;;
;; `stage' is how far through the setting this word has got, and it is here to
;; make one rule checkable: **each field belongs to one stage, and no stage may
;; write a field a later one owns.**
;;
;;   set     he reads the copy, misreads it or not, and sets it in his own
;;           spelling. `copy', `read' and `habit' are settled here; `final',
;;           `composed' and `printed' stand provisionally at the habit's form.
;;   fitted  the measure settles the spelling: `final', `composed', `width'.
;;   picked  the case supplies the metal: `printed', `pieces'.
;;
;; This is not decoration. `revise' writes `printed' back to `composed', so a
;; revision after picking would silently undo every foul case, every forced
;; substitution and every place held for the proof in that word. Nothing but
;; the order of two calls in book.rkt prevented it -- and that is the same
;; shape as the bug that turned `composed' into `compos'd' and back: two
;; writers, one field, and a convention keeping them apart. A convention
;; written in a comment is a hope; one the constructor checks is an invariant.
(struct word (copy read habit final composed printed width causes italic? pieces
              stage)
  #:transparent)

(define WORD-STAGES '(set fitted picked))

(define (stage-index s)
  (or (index-of WORD-STAGES s)
      (error 'word "unknown stage ~s; expected one of ~s" s WORD-STAGES)))

;; Advance a word to `to', refusing to go backwards. `who' is the writer, named
;; so that a violation says which stage overstepped and onto what.
(define (at-stage wd to who)
  (define from (word-stage wd))
  (when (> (stage-index from) (stage-index to))
    (error who
           (string-append
            "this stage may not write a word that has reached `~a'.\n"
            "  word:      ~s\n"
            "  its stage: ~a\n"
            "  writing as: ~a\n"
            "Each field of a word belongs to one stage; see the struct.")
           from (word-copy wd) from to))
  (struct-copy word wd [stage to]))

(struct set-line
  (words spaces indent measure kind justification turned-over? quadded? italic?)
  #:transparent)

(define (line-set-width l)
  (+ (for/sum ([w (in-list (set-line-words l))]) (word-width w))
     (for/sum ([s (in-list (set-line-spaces l))]) s)
     (set-line-indent l)))

(define (line-text l)
  (string-join (map word-printed (set-line-words l)) " "))

;; The one physical law: a line wider than the measure cannot be locked up.
(define (make-line ws spaces indent measure kind
                   #:justification [j ""] #:turned-over? [t #f]
                   #:quadded? [q #f] #:italic? [i #f])
  (define l (set-line ws spaces indent measure kind j t q i))
  (unless (or (<= (line-set-width l) measure) (<= (length ws) 1))
    (error 'make-line
           "line overhangs the measure by ~a units: ~s"
           (- (line-set-width l) measure) (line-text l)))
  l)

;; ---------------------------------------------------------------------------
;; The workmen
;; ---------------------------------------------------------------------------

(struct profile
  (name spellings care misread-rate memorial-rate contracts
        normalises-verse? habit-strength pattern-style description)
  #:transparent)

(define (tests-for name)
  (for/hash ([(head forms) (in-hash SPELLING-TESTS)]
             #:when (hash-has-key? forms name))
    (values head (hash-ref forms name))))

;; A and B carry the spelling habits Satchell isolated and Hinman generalised.
;; E is the prentice hand -- on the usual account John Leason, bound in 1622 --
;; whose stint is the worst-set and most heavily corrected in the Folio.
(define PROFILES
  (hash
   "A" (profile "A" (tests-for "A") 1.0 0.008 0.004 0.35 #f 0.82 "A"
                (string-append
                 "a steady journeyman; keeps the older fuller forms, "
                 "reluctant to tamper with the lineation of his copy"))
   "B" (profile "B" (tests-for "B") 1.15 0.013 0.011 0.75 #t 0.91 "B"
                (string-append
                 "fast, confident and free with his copy; modernises "
                 "spelling, abbreviates readily, and will set verse as prose "
                 "sooner than turn a line over"))
   ;; C sets doe and goe like A, but heere like B. Hinman found him working
   ;; at case x beside A in quires T and V, "in the absence of B", and again
   ;; in quire L. He "reproduces a few here spellings from copy -- more than
   ;; B is ever likely to -- but he also changes here to heere" (i. 196).
   "C" (profile "C" (tests-for "C") 1.05 0.010 0.006 0.45 #f 0.78 #f
                (string-append
                 "a third hand, at case x; A's man for do and go but B's for "
                 "heere, which is what betrays him. Partnered A when B was "
                 "wanted elsewhere"))
   ;; D is the difficult one. His *preferences* are A's -- doe, goe, here --
   ;; so no spelling test separates them. What distinguishes him is his
   ;; tolerance: he "is very much more tolerant of the short spellings than
   ;; either A or C is" and "much more likely to reproduce the do-go spellings
   ;; in his copy than A is" (i. 197, 199). That is a difference of habit
   ;; strength, not of habit, and it is exactly what habit-strength models.
   "D" (profile "D" (tests-for "D") 1.10 0.011 0.008 0.50 #f 0.42 #f
                (string-append
                 "the man who brought case z into use in quire K. His "
                 "preferences are A's, so no spelling test will separate "
                 "them; what marks him is how readily he lets a copy "
                 "spelling stand"))
   ;; --- Nicholas Okes's shop, 1607-8 (Blayney, i, ch. 5) -----------------
   ;; Okes's B set sheets B-G and most of H alone. His markers are doe, goe,
   ;; here, capitalised King, -our endings, and a free use of the apostrophe.
   "OkesB" (profile "OkesB" (tests-for "OkesB") 1.0 0.011 0.007 0.5 #f 0.80 "OkesB"
                    (string-append
                     "Okes's principal workman; set sheets B-G and most of H "
                     "alone. Sets doe, goe, here and -our, and uses the "
                     "apostrophe freely"))
   ;; C set four short stints in H-L, some 455 lines in all, working at the
   ;; second case. Blayney: he "refused five opportunities to use an
   ;; apostrophe", and sets heere, do, and -or.
   "OkesC" (profile "OkesC" (tests-for "OkesC") 1.15 0.013 0.009 0.6 #f 0.72 "OkesC"
                    (string-append
                     "Okes's second hand, in four short stints across H-L. "
                     "Sets do, go, heere and -or, and avoids the apostrophe "
                     "where B would use it"))
   ;; E's spellings are B's, not A's. Hinman states the confusion twice and
   ;; in both directions: "material set by Compositor E has been confused with
   ;; work set by B", and the older attributions assigned "much or all of E's
   ;; work in the Tragedies to B" -- just as C's work was confused with A's.
   ;; This program had E carrying A's habits, which inverted the very mistake
   ;; the scholarship made.
   ;;
   ;; What separates E from B is not direction but strength. E "tended to
   ;; follow his copy far more closely than B (or than A, or C, or even D)",
   ;; and "none of his preferences can be said to be strong ones", so "his
   ;; spelling is likely not only to be mixed but to reflect many of the
   ;; peculiarities of the materials from which he worked". A low
   ;; habit-strength is exactly that: a man whose page reports his copy rather
   ;; than himself.
   "E" (profile "E" (tests-for "B") 2.6 0.030 0.020 0.55 #f 0.28 "B"
                (string-append
                 "the prentice hand; a substitute rather than a regular, who "
                 "stepped in to keep the Folio going when one of the other "
                 "men was wanted elsewhere, and who had no case or working "
                 "space of his own. He leans the same way as B on do, go and "
                 "heere but leans weakly, following his copy more closely "
                 "than any of the others, so a spelling test reads his pages "
                 "as B's -- which is how his stint went unnoticed until "
                 "Hinman found it in the type"))))

(struct page-spec (measure lines verse-indent prose-indent) #:transparent)

;; Blayney, i. 176: compositor C's -ie preference is 57% overall, 64% in
;; unjustified lines; B's is nothing that survives counting. This is the one
;; measured rate for a habit that applies to a class of words rather than to
;; particular ones, and it governs the -ie/-y, -ll/-l and -'d/-ed patterns.
(define PATTERN-STRENGTH 0.57)

(struct comp (profile case conventions rng events) #:transparent)

(define (make-comp prof tc cv g)
  (comp prof tc cv g (box '())))

(define (add-event! c e)
  (set-box! (comp-events c) (cons e (unbox (comp-events c)))))

(define (comp-event-list c) (reverse (unbox (comp-events c))))

;; ---------------------------------------------------------------------------
;; One word
;; ---------------------------------------------------------------------------

;; `wd' is either a copy token or a (copy . as-read) pair.
(define (make-word c wd #:italic? [italic? #f])
  (define-values (copy-word read-word)
    (if (pair? wd) (values (car wd) (cdr wd)) (values wd wd)))
  (define prof (comp-profile c))
  (define cv (comp-conventions c))
  (define g (comp-rng c))
  (define pref (preferred read-word (profile-spellings prof)))
  ;; Habit strength is not one number. Hinman's counts for quire L show
  ;; Compositor C imposing doe/goe on four opportunities in five but heere on
  ;; only one in two (i. 195). A profile may therefore carry either a scalar
  ;; or a table keyed by the head-word, with a fallback.
  (define (strength-for word)
    (define hs (profile-habit-strength prof))
    (cond
      [(real? hs) hs]
      [else (define-values (core tail) (split-point word))
            (define head (head-form core))
            (hash-ref hs (or head "") (lambda () (hash-ref hs "" 0.85)))]))
  ;; Habit is not the whole of it. Blayney showed that a compositor choosing
  ;; between two spellings is influenced by what is left in the box the choice
  ;; would empty -- see `supply-factor'. A habit that spends a scarce sort is
  ;; indulged less often than the same habit costing nothing.
  (define (strength-toward from to)
    (* (strength-for from)
       (supply-factor (comp-case c)
                      (apply-conventions cv from)
                      (apply-conventions cv to))))
  (define habit
    (cond
      [(and pref (< (rnd g) (strength-toward read-word pref))) pref]
      [else
       (define-values (form rule)
         (pattern-form read-word (profile-pattern-style prof)))
       ;; A class habit is weaker than a word habit, and the program was
       ;; treating them alike. Hinman's four-in-five is a figure about `doe',
       ;; `goe' and `heere' -- particular words, of which he says they "alone
       ;; usually provide all the evidence that is needed". The only measured
       ;; figure for a *class* habit is Blayney's, and it is much lower:
       ;; Okes's C set -ie 57% of the time overall and 64% in unjustified
       ;; lines, and his fellow B had no preference at all that survived
       ;; being counted.
       ;;
       ;; Applied at the test-word strength, the patterns produced 78% of
       ;; every habit in the book -- 255 of 328 in _Areopagitica_, against 73
       ;; from the named words. That is the tail wagging the dog: the strong
       ;; evidence is the small set Hinman actually rests on, and the -ie,
       ;; -ll and -'d classes are the weak evidence that happens to be common.
       (if (and form (< (rnd g) (* PATTERN-STRENGTH
                                   (supply-factor (comp-case c)
                                                  (apply-conventions cv read-word)
                                                  (apply-conventions cv form)))))
           form
           read-word)]))
  (define composed (apply-conventions cv habit))
  (word copy-word read-word habit habit composed composed
        (width-of-word composed) '() italic? '() 'set))

;; Purely functional: returns a new word, leaves the old one alone.
;;
;; The measure settling a spelling. It rewrites `printed' along with the rest,
;; which is safe only while the case has not yet supplied any metal -- hence
;; the stage check, and hence its being here rather than in a comment.
(define (revise cv wd form cause)
  (define composed (apply-conventions cv form))
  (struct-copy word (at-stage wd 'fitted 'revise)
               [final form]
               [composed composed]
               [printed composed]
               [width (width-of-word composed)]
               [causes (append (word-causes wd) (list cause))]))

;; Alternative forms, with their true widths after the conventions.
;; `g' is the compositor's own randomness, and it is here for one reason: the
;; scribal signs are offered only sometimes. Counting them in 5,287 EEBO books
;; showed the program setting tildes about ten times, and superscript
;; brevigraphs about nine hundred times, oftener than a real printed book of the
;; period. Neither is a rate that can be set directly -- a compositor abbreviates
;; when a line will not come out, not to a quota -- so what is gated is whether
;; the sign is in his repertoire at this moment at all. When it is not, he must
;; find another way to close the line, which is what the corpus says he did.
(define (word-variants cv wd widen? g)
  (define year (conventions-year cv))
  (define p (if (conventions-scribal? cv) (tilde-chance year) 0.0))
  (define raw (if widen?
                  (expansions (word-final wd))
                  (contractions (word-final wd)
                                #:tilde? (< (rnd g) p)
                                #:brevigraph? (< (rnd g) (* p BREVIGRAPH-SHARE)))))
  (define out
    (for/list ([v (in-list raw)])
      (list (variant-form v)
            (width-of-word (apply-conventions cv (variant-form v)))
            (variant-device v))))
  ;; The cheapest change he can make to a word is not to make the one he was
  ;; going to make. If his habit turned `composed' into `compos'd' and the line
  ;; then wants filling, he sets what the copy said; he does not contrive a
  ;; third spelling to undo the second.
  ;;
  ;; This move was missing altogether, so it could only happen by accident --
  ;; as whatever orthographic device happened to map the habit form back, and
  ;; ranked as violently as any other. The record then read
  ;;
  ;;   habit: “cōposed” → “cōpos'd”; justification: “cōpos'd” → “cōposed”
  ;;
  ;; which is a round trip to nowhere, and looks like two stages fighting each
  ;; other. They were not: one decision was taken, and taken once, when the
  ;; line turned out not to hold.
  ;;
  ;; Blayney's numbers say this is the common case rather than a curiosity.
  ;; Okes's compositor C set -ie 57% of the time overall but 64% in unjustified
  ;; lines (i. 190): a habit is weaker where the measure has to be met, which
  ;; is only possible if meeting the measure is what suspends it.
  (define unhabit
    (let* ([r (word-read wd)]
           [wid (and (not (string=? r (word-final wd)))
                     (width-of-word (apply-conventions cv r)))])
      (and wid
           (if widen? (> wid (word-width wd)) (< wid (word-width wd)))
           (list (list r wid "the habit not applied here")))))
  (sort (append (or unhabit '()) out) (if widen? > <) #:key cadr))

;; How much a device costs the reader. The compositor works down this list.
;; The ampersand ranks below the spelling variants, not above them. A reader
;; barely registers `honestie' for `honesty', but an ampersand is a visible
;; substitution of a sign for a word. The Folio bears this out: fourteen
;; ampersands in twelve thousand words, against a quarto's six -- the trade
;; used it, but sparingly, and after everything gentler had been tried.
(define violence-table
  ;; Below everything: setting the copy's own spelling costs the reader nothing
  ;; at all, because it is what the copy said.
  '(("habit not applied" -1)
    ("terminal -e" 0) ("full form" 0) ("short form" 1) ("-ll for -l" 1)
    ("-ie for -y" 1) ("and for &" 1) ("elided" 1) ("written out" 1)
    ("-y for -ie" 2)
    ("double" 3) ("& for and" 4) ("contracted to" 5) ("tilde" 6)))

(define (violence device)
  (or (for/or ([row (in-list violence-table)])
        (and (string-contains? device (car row)) (cadr row)))
      3))

;; ---------------------------------------------------------------------------
;; Squeezing and stretching
;; ---------------------------------------------------------------------------
;; Both return (values new-words note) or (values #f #f). Nothing is mutated,
;; so a caller that does not like the result simply discards it.

;; A word already altered once for the measure is not altered again. Without
;; this the squeeze loop kept reaching for the same word, and "implementation"
;; came out as "implēētatiō" -- three contractions stacked on one word, which
;; no compositor ever set and no reader could have unpicked.
(define (already-altered? wd)
  (for/or ([c (in-list (word-causes wd))]) (string-prefix? c "justification")))

(define (adjust cv ws need widen? g)
  (define candidates
    (for*/list ([(wd i) (in-indexed (in-list ws))]
                #:unless (already-altered? wd)
                [v (in-list (word-variants cv wd widen? g))]
                #:when (let ([d (- (cadr v) (word-width wd))])
                         (if widen? (> d 0) (< d 0))))
      (define gain (abs (- (cadr v) (word-width wd))))
      (list gain (violence (caddr v)) i (car v) (caddr v))))
  (cond
    [(null? candidates) (values #f #f)]
    [else
     (define enough (filter (lambda (c) (>= (car c) need)) candidates))
     (define pool (if (null? enough) candidates enough))
     ;; the gentlest device that will serve; among equals, the smallest
     ;; sufficient change
     (define best
       (for/fold ([best (car pool)]) ([c (in-list (cdr pool))])
         (if (or (< (cadr c) (cadr best))
                 (and (= (cadr c) (cadr best)) (< (car c) (car best))))
             c best)))
     (match-define (list gain _v i form device) best)
     (values (list-set ws i (revise cv (list-ref ws i) form
                                    (string-append "justification: " device)))
             (format "~a (~a ~a em)" device (if widen? "gaining" "saving")
                     (real->decimal-string (ems gain) 2)))]))

(define (squeeze cv ws g [need 0]) (adjust cv ws need #f g))
(define (stretch cv ws g [need 0]) (adjust cv ws need #t g))

;; ---------------------------------------------------------------------------
;; Justification
;; ---------------------------------------------------------------------------

;; Divide the white evenly, giving the odd units to the wider gaps first. A
;; compositor cannot cut a space in half; he makes up the difference from the
;; finer spaces in the box, which is why justified hand-set prose has slightly
;; unequal word spacing even when it is well done.
;; Divide the white between the gaps -- in pieces of metal, which is the whole
;; difficulty.
;;
;; This used to hand out single units of 1/120 em until the arithmetic came
;; out, and there is no such thing as a 1/120-em space. Measured on
;; _Areopagitica_, 86% of the gaps it produced were widths no combination of
;; bodies could make: 43/120 of an em, 41, 47. The line filled the measure
;; exactly and could not have been set.
;;
;; What a compositor actually does is Moxon's account, and it is quantised: he
;; sets with one space between words, and if the line will not fill he "puts a
;; Space more between every Word", and if still not, another. So every gap gets
;; a body, and then some gaps get a second piece. Which gaps is his choice; the
;; sizes are not.
;;
;; The line therefore fills to within less than a hair -- under a tenth of an
;; em -- rather than exactly, and that residual is real. It is taken up by the
;; pressure of the lock-up, as it was in a chase.
(define (apportion white gaps)
  (cond
    [(<= gaps 0) '()]
    [else
     ;; `SPACE-LADDER', not a second copy of it. This was written out again
     ;; here, so the case had its bodies listed in two places and the two could
     ;; drift -- the failure this project has met three times and named "one
     ;; property, one decision point". It matters now rather than later:
     ;; roadmap §4 will change what bodies exist, since Moxon's fount has four
     ;; where this has six, and a private list would have gone on offering a
     ;; middle space after the case stopped holding one.
     (define target (quotient white gaps))
     ;; the largest single body that will not overshoot the average gap
     (define base
       (or (for/or ([b (in-list SPACE-LADDER)]) (and (<= b target) b))
           (last SPACE-LADDER)))
     (define v (make-vector gaps base))
     ;; then the surplus, in whole pieces, spread over successive gaps
     (let loop ([left (- white (* base gaps))] [i 0] [guard 0])
       (define piece (for/or ([b (in-list SPACE-LADDER)]) (and (<= b left) b)))
       (when (and piece (< guard (* gaps 8)))
         (define j (modulo i gaps))
         (vector-set! v j (+ (vector-ref v j) piece))
         (loop (- left piece) (add1 i) (add1 guard))))
     (vector->list v)]))

;; Space out a full line of prose so that it exactly fills the stick.
;; Returns a line, or #f if the words will not go into the measure at all --
;; in which case the caller puts one back and tries again.
(define (justify cv ws measure indent pressure g)
  (define n (length ws))
  (cond
    [(zero? n) #f]
    [(= n 1)
     (make-line ws '() indent measure 'prose
                #:justification "single word, quadded out" #:quadded? #t)]
    [else
     (define gaps (sub1 n))
     (define (per ws) (/ (- measure indent (content-width ws)) gaps))

     ;; Too tight to space at all: the compositor must find room in the words.
     (define-values (tight-ws tight-notes)
       (let loop ([ws ws] [notes '()] [rounds 0])
         (cond
           [(or (>= (per ws) FINEST-SPACE) (>= rounds 8)) (values ws notes)]
           [else
            (define need (exact-ceiling (* (- FINEST-SPACE (per ws)) gaps)))
            (define-values (new note) (squeeze cv ws g need))
            (if new (loop new (cons note notes) (add1 rounds)) (values ws notes))])))

     (cond
       [(< (per tight-ws) FINEST-SPACE) #f]     ; it will not go; caller must retry
       [else
        ;; So loose the line will gape: fill it out with fuller spellings
        ;; before resorting to great gouts of white between the words. Only
        ;; so far, though -- a compositor stretching three words has done his
        ;; part, and the rest of the white simply goes between them.
        (define loose-limit (if (>= pressure 0) EN-QUAD (* THICK 3/2)))
        (define-values (final-ws all-notes)
          (let loop ([ws tight-ws] [notes tight-notes] [rounds 0])
            (cond
              [(or (<= (per ws) loose-limit) (>= rounds 3)) (values ws notes)]
              [else
               (define need (exact-floor (* (- (per ws) loose-limit) gaps)))
               (define-values (new note) (stretch cv ws g need))
               (if new (loop new (cons note notes) (add1 rounds)) (values ws notes))])))

        ;; A fuller spelling the line cannot afford is not one the compositor
        ;; can use. `stretch' is asked for `need' units and may hand back more
        ;; -- there is no spelling of an arbitrary length, so it overshoots --
        ;; and nothing checked the result. Squeezing has always been bounded,
        ;; by re-testing `per' every round and giving up at FINEST-SPACE; stretching
        ;; was not, so a line filled out with longer forms could come back
        ;; wider than the measure and reach `make-line' with nowhere to go.
        ;;
        ;; It took the whole Folio to find: the words have to be long enough
        ;; that one fuller spelling overruns a 16-em column, and Hamlet's
        ;; "tragical-comical-historical-pastoral" is where it happens.
        ;; `historical-pastoral' became `hiſtorical-paſtoralle' and the line
        ;; overhung by three units, which is one hair space.
        ;;
        ;; Reverting to the squeezed forms is the rule this pipeline is built
        ;; on: habit proposes and the measure disposes. It is not a clamp on
        ;; the arithmetic, it is the compositor declining a spelling he has no
        ;; room for.
        (define fitted-ws (if (< (per final-ws) FINEST-SPACE) tight-ws final-ws))
        (define white (- measure indent (content-width fitted-ws)))
        (define spaces (apportion white gaps))
        ;; Moxon's account of justifying is quantised: the compositor sets with
        ;; one space between words, and if the line will not fill he "puts a
        ;; Space more between every Word", and if still not, another -- "So
        ;; that here is now three Spaces, and strictly, good Workmanship will
        ;; not allow more" (ii. 214-15). Three thick spaces make an em, so a
        ;; gap wider than an em is beyond what he would own to, and has a name:
        ;; "These wide Whites are by Compositers (in way of Scandal) call'd
        ;; Pidgeon-holes."
        (define pigeon? (> (per fitted-ws) EM-QUAD))
        (define note
          (string-append
           (if pigeon? "pigeon-holes — " "")
           (describe-space (exact-round (per fitted-ws)))
           (if (or (null? all-notes) (eq? fitted-ws tight-ws)) ""
               (string-append "; " (string-join (reverse all-notes) "; ")))))
        (make-line fitted-ws spaces indent measure 'prose #:justification note)])]))

(define (content-width ws) (for/sum ([w (in-list ws)]) (word-width w)))

;; The widest space in the box that still lets the line into the stick.
(define (fitting-space ws room)
  (define gaps (max 0 (sub1 (length ws))))
  (cond
    [(zero? gaps) NORMAL-SPACE]
    [else (max FINEST-SPACE (min NORMAL-SPACE (quotient (- room (content-width ws)) gaps)))]))

(define (quad-out ws measure indent kind)
  (define space (fitting-space ws (- measure indent)))
  (define gaps (max 0 (sub1 (length ws))))
  (make-line ws (make-list gaps space) indent measure kind
             #:quadded? #t
             #:justification
             (if (and (< space NORMAL-SPACE) (positive? gaps))
                 (format "quadded out, spaced with ~a" (describe-space space))
                 "quadded out")))

(define (range-right ws measure kind)
  (define space (fitting-space ws (- measure EM-QUAD)))
  (define gaps (max 0 (sub1 (length ws))))
  (define content (+ (content-width ws) (* space gaps)))
  (define indent (max 0 (min (max EM-QUAD (- measure content)) (- measure content))))
  (make-line ws (make-list gaps space) indent measure kind))

;; ---------------------------------------------------------------------------
;; Reading the copy
;; ---------------------------------------------------------------------------

;; The misreading rates in the profiles were set by eye, and are certainly too
;; high for the same reason the foul-case rate was: a printed page carries far
;; fewer errors than one imagines. The Q/F comparison bounds it loosely --
;; differences of several letters run at about 4 per thousand words, and most
;; of those are spelling variants rather than misreadings -- so this scales the
;; profiles down. It is a weaker calibration than the foul-case one and should
;; be treated as such.
(define MISREAD-SCALE 0.2)

(define (read-copy c text)
  (define prof (comp-profile c))
  (define-values (pairs errors)
    (misread (string-split text) (comp-rng c)
             (* MISREAD-SCALE (profile-misread-rate prof))
             (* MISREAD-SCALE (profile-memorial-rate prof))))
  (for ([e (in-list errors)])
    (add-event! c (make-event 'copy
                              (format "~a: ~s for ~s" (misreading-note e)
                                      (misreading-reading e)
                                      (misreading-original e))
                              #:compositor (profile-name prof)
                              #:before (misreading-original e)
                              #:after (misreading-reading e))))
  pairs)

;; ---------------------------------------------------------------------------
;; Prose
;; ---------------------------------------------------------------------------

;; Fill the stick, line by line, and justify each one exactly.
;;
;; The compositor fills greedily and then asks whether one more word might be
;; pinched in. He finds out by trying it: the trial is a fresh line built from
;; fresh words, and if it will not lift he simply keeps the other one.
;; Break a word across two lines with a hyphen.
;;
;; The division is made after a vowel where one can be found, which is roughly
;; the rule the manuals give and entirely the rule compositors followed when
;; the manuals were not to hand. Both halves keep the copy-word they came
;; from, so nothing is lost to the record by dividing.
;; Can this stand as the beginning of a syllable?
;;
;; A vowel can; a single consonant before a vowel can; and so can the handful
;; of consonant pairs English admits at the head of one. Anything else -- `rt',
;; `mp', `ct' -- cannot, and a word must not be broken so as to leave it.
(define ONSETS
  '("bl" "br" "ch" "cl" "cr" "dr" "dw" "fl" "fr" "gl" "gn" "gr" "kn" "ph"
    "pl" "pr" "qu" "sc" "sh" "sk" "sl" "sm" "sn" "sp" "sq" "st" "sw" "th"
    "tr" "tw" "wh" "wr" "sch" "scr" "shr" "spl" "spr" "str" "thr"))

(define (vowel? ch) (and (memv (char-downcase ch) '(#\a #\e #\i #\o #\u #\y)) #t))

(define (syllable-start? s)
  (define t (string-downcase (strip-conventions s)))
  (define n (string-length t))
  (cond
    [(zero? n) #f]
    [(vowel? (string-ref t 0)) #t]
    [(= n 1) #f]
    [(vowel? (string-ref t 1)) #t]                       ; consonant + vowel
    [(and (>= n 3) (member (substring t 0 3) ONSETS)) #t]
    [(member (substring t 0 2) ONSETS) #t]
    [else #f]))

(define (divide c w room)
  (define cv (comp-conventions c))
  (define text (word-final w))
  (define n (string-length text))
  (cond
    [(< n 5) (values #f #f)]
    [else
     ;; and nothing shorter than three letters after it either, so the search
     ;; for a cut begins three from the end rather than two
     (let try ([cut (- n 3)])
       (cond
         ;; Nothing shorter than three letters before the hyphen. A compositor
         ;; with less room than that does not set `co- / mmons'; he turns the
         ;; whole word over to the next line and lets this one run short.
         [(< cut 3) (values #f #f)]
         [else
          (define head-text (string-append (substring text 0 cut) "-"))
          (cond
            [(> (width-of-word (apply-conventions cv head-text)) room)
             (try (sub1 cut))]
            ;; A word breaks at a syllable, and where the syllable falls is a
            ;; property of what comes *after* the cut, not before it. The old
            ;; rule asked only that the head end in a vowel, which let
            ;; `libertie' break as `libe- / rtie' -- a fragment no compositor
            ;; ever set, since `rt' cannot begin an English syllable. Asking
            ;; instead that the tail begin as a syllable does begin gives
            ;; `liber- / tie', and `diminu- / tion', and `ſpo- / ken'.
            [(not (and (regexp-match? #px"[aeiouyAEIOUY]" (substring text 0 cut))
                       (syllable-start? (substring text cut))))
             (try (sub1 cut))]
            [else
             (define head (make-word c (cons (word-copy w) head-text)))
             (define tail (make-word c (cons (word-copy w) (substring text cut))))
             (add-event! c (make-event
                            'justification
                            (format "~a divided as ~a / ~a"
                                    (word-copy w) head-text (substring text cut))
                            #:compositor (profile-name (comp-profile c))))
             (values (struct-copy word head
                                  [causes (list "word divided at the end of the line")])
                     (struct-copy word tail
                                  [causes (list "second half of a divided word")]))])])) ]))

(define (set-prose c text spec pressure
                   #:first-indent? [first-indent? #t]
                   #:lead [lead '()])
  (define cv (comp-conventions c))
  (define prof (comp-profile c))
  (define g (comp-rng c))
  (define measure (page-spec-measure spec))
  (define made
    (append lead (for/list ([p (in-list (read-copy c text))]) (make-word c p))))

  (let loop ([rest made] [indent (if first-indent? (page-spec-prose-indent spec) 0)]
             [out '()])
    (cond
      [(null? rest) (reverse out)]
      [else
       (define room (- measure indent))
       ;; greedy fill
       ;; Fill at the NORMAL space, not the finest one.
       ;;
       ;; This was hair spaces, and it was wrong in a way no internal test
       ;; could see. A compositor fills his stick expecting an ordinary word
       ;; space between the words; only when the line then refuses to justify
       ;; does he go finer. Filling at the hair space crams in a word that
       ;; does not really fit, and every line then has to be squeezed --
       ;; which silently reverted the man's own spellings, since `doe' shrinks
       ;; to `do'. Setting the whole of Much Ado that way drove the long forms
       ;; *below* the level in the copy, when the real Folio has them far
       ;; above it. Moxon has it the other way round: one space, and a second
       ;; and third put in where the line falls short (ii. 214-15).
       (define-values (span0 rest0)
         (let fill ([xs rest] [acc '()] [width 0])
           (cond
             [(null? xs) (values (reverse acc) '())]
             [else
              (define extra (+ (word-width (car xs))
                               (if (null? acc) 0 NORMAL-SPACE)))
              (if (and (pair? acc) (> (+ width extra) room))
                  (values (reverse acc) xs)
                  (fill (cdr xs) (cons (car xs) acc) (+ width extra)))])))
       ;; a single word wider than the whole measure still has to go somewhere
       (define span (if (null? span0) (list (car rest)) span0))
       (define remaining (if (null? span0) (cdr rest) rest0))
       (define last? (null? remaining))

       ;; How much white is left once the line is filled at ordinary spacing.
       (define slack
         (- room (content-width span)
            (* NORMAL-SPACE (max 0 (sub1 (length span))))))

       ;; Divide the next word into the line.
       ;;
       ;; Moxon says a line ends "with a Word or a Syllable and a Division"
       ;; -- division is one of the two normal ways to end a line, not a last
       ;; resort. It had been a last resort here, firing only for a word wider
       ;; than the entire measure, so the simulation never divided at all
       ;; while the Folio divides on about one line in twenty. A compositor
       ;; who cannot divide must pad instead, and the padding fell on his
       ;; spellings.
       ;; The coefficient is calibrated, not chosen: the Folio divides on
       ;; 5.1 lines in a hundred across these five scenes of Much Ado (74
       ;; divisions in 1,449 lines of type), and the quarto on 5.6.
       (define split
         (and (not last?)
              (> slack THICK)
              (< (rnd g) (* 1.5 (profile-contracts prof)))
              (let-values ([(h t) (divide c (car remaining) (- slack NORMAL-SPACE))])
                (and h (cons h t)))))

       (cond
         [split
          (define line (justify cv (append span (list (car split)))
                                measure indent pressure (comp-rng c)))
          (if line
              (loop (cons (cdr split) (cdr remaining)) 0 (cons line out))
              (loop remaining 0
                    (cons (or (justify cv span measure indent pressure (comp-rng c))
                              (quad-out span measure indent 'prose))
                          out)))]

         ;; would one more word go in, if the line were pinched?
         [(and (not last?)
               (< (rnd g) (min 0.95 (+ (profile-contracts prof) (* pressure 0.4))))
               (justify cv (append span (list (car remaining)))
                        measure indent pressure (comp-rng c)))
          => (lambda (line) (loop (cdr remaining) 0 (cons line out)))]

         [last?
          (reverse (cons (quad-out span measure indent 'prose) out))]

         [else
          ;; drop a word at a time until the line justifies. The greedy fill
          ;; makes this succeed at once in all but pathological cases.
          (let retry ([span span] [back '()])
            (define line (justify cv span measure indent pressure (comp-rng c)))
            (cond
              [line (loop (append back remaining) 0 (cons line out))]
              [(> (length span) 1)
               (retry (take span (sub1 (length span)))
                      (cons (last span) back))]
              [else (loop (append back remaining) 0
                          (cons (quad-out span measure indent 'prose) out))]))])])))

;; ---------------------------------------------------------------------------
;; Verse
;; ---------------------------------------------------------------------------

;; A verse line is one line of type, quadded out; if it will not go in it is
;; squeezed, and if it still will not go in it is turned over.
;; `first-indent?' is the line that carries the speech prefix.
;;
;; The Folio indents it by a quad and sets the rest of the speech flush, which
;; is plain on any plate: on Lear 295 `Lear. Returne to her? and fifty men
;; dismiss'd?' stands in from the margin and the five lines under it do not.
;; This had the indent on the prose path only, and a speech in verse -- which
;; is three-quarters of the book -- came out flush, so the reader could not see
;; where one speech ended and the next began except by the prefix itself.
;;
;; The indented line is also genuinely narrower, so it turns over sooner. That
;; is not a side effect to be worked around: it is why the Folio turns over on
;; prefix lines far more often than on any other.
(define (set-verse c text spec pressure #:lead [lead '()]
                   #:first-indent? [first-indent? #f])
  (define cv (comp-conventions c))
  (define measure (page-spec-measure spec))
  (define indent (+ (page-spec-verse-indent spec)
                    (if first-indent? (page-spec-prose-indent spec) 0)))
  (define room (- measure indent))
  (define made0
    (append lead (for/list ([p (in-list (read-copy c text))]) (make-word c p))))
  (define gaps (max 0 (sub1 (length made0))))

  ;; The compositor's first resort is thinner spaces; only when the finest
  ;; space in the box will not save him does he begin altering words.
  (define-values (made notes)
    (let loop ([ws made0] [notes '()] [rounds 0])
      (define needed (+ (content-width ws) (* FINEST-SPACE gaps)))
      (cond
        [(or (<= needed room) (>= rounds 10)) (values ws notes)]
        [else
         (define-values (new note) (squeeze cv ws (comp-rng c) (- needed room)))
         (if new (loop new (cons note notes) (add1 rounds)) (values ws notes))])))

  (define needed (+ (content-width made) (* FINEST-SPACE gaps)))
  (cond
    [(<= needed room)
     (define line (quad-out made measure indent 'verse))
     (list (if (null? notes)
               line
               (struct-copy set-line line
                            [justification
                             (string-append "squeezed into the measure: "
                                            (string-join (reverse notes) "; "))])))]
    [else
     ;; The tail is turned over on to the next line, ranged to the right so
     ;; that the reader can see it is not a new verse line. A very long line
     ;; may be turned over more than once.
     (add-event! c (make-event
                    'justification
                    (format "verse line turned over (~a em over the measure)"
                            (real->decimal-string (ems (- needed room)) 2))
                    #:compositor (profile-name (comp-profile c))))
     (let loop ([rest made] [first? #t] [out '()])
       (cond
         [(null? rest) (reverse out)]
         [else
          ;; only the first line is indented; a turn-over is ranged right
          ;; against the full measure and has the whole of it to fill.
          (define line-room (if first? room (- measure (page-spec-verse-indent spec))))
          (define span
            (let fill ([xs rest] [acc '()] [width 0])
              (cond
                [(null? xs) (reverse acc)]
                [else
                 (define extra (+ (word-width (car xs))
                                  (if (null? acc) 0 THIN)))
                 (if (and (pair? acc) (> (+ width extra) line-room))
                     (reverse acc)
                     (fill (cdr xs) (cons (car xs) acc) (+ width extra)))])))
          (define span* (if (null? span) (list (car rest)) span))
          (define line
            (if first?
                (struct-copy set-line (quad-out span* measure indent 'verse)
                             [justification
                              "line too long for the measure; turned over"])
                (struct-copy set-line (range-right span* measure 'verse)
                             [turned-over? #t]
                             [justification "turn-over, ranged to the right"])))
          (loop (drop rest (length span*)) #f (cons line out))]))]))

;; ---------------------------------------------------------------------------
;; The other furniture
;; ---------------------------------------------------------------------------

(define (set-stage-direction c text spec)
  (define measure (page-spec-measure spec))
  (define ws (for/list ([p (in-list (read-copy c text))])
               (make-word c p #:italic? #t)))
  (define content (+ (content-width ws) (* NORMAL-SPACE (max 0 (sub1 (length ws))))))
  (cond
    [(<= content (- measure EM-QUAD))
     (list (struct-copy set-line
                        (make-line ws (make-list (max 0 (sub1 (length ws))) NORMAL-SPACE)
                                   (max 0 (- measure content)) measure 'stage
                                   #:italic? #t #:quadded? #t)
                        [justification "direction ranged right in italic"]))]
    [else
     (define sub (page-spec (page-spec-measure spec) (page-spec-lines spec)
                            (page-spec-verse-indent spec) 0))
     (for/list ([l (in-list (set-prose c text sub 0.0 #:first-indent? #f))])
       (struct-copy set-line l
                    [kind 'stage] [italic? #t]
                    [words (for/list ([w (in-list (set-line-words l))])
                             (struct-copy word w [italic? #t]))]))]))

;; A head is set in capitals and centred, and broken over as many lines as the
;; measure requires -- capitals are wide, and a title very soon outruns the
;; stick.
(define (set-heading c text spec)
  (define measure (page-spec-measure spec))
  (define ws (for/list ([p (in-list (read-copy c text))])
               (make-word c (cons (string-upcase (car p)) (string-upcase (cdr p))))))
  (define rows
    (let loop ([xs ws] [cur '()] [width 0] [out '()])
      (cond
        [(null? xs) (reverse (if (null? cur) out (cons (reverse cur) out)))]
        [else
         (define extra (+ (word-width (car xs)) (if (null? cur) 0 EN-QUAD)))
         (if (and (pair? cur) (> (+ width extra) measure))
             (loop xs '() 0 (cons (reverse cur) out))
             (loop (cdr xs) (cons (car xs) cur) (+ width extra) out))])))
  (for/list ([row (in-list rows)])
    (define gaps (max 0 (sub1 (length row))))
    (define content (+ (content-width row) (* EN-QUAD gaps)))
    (make-line row (make-list gaps EN-QUAD)
               (max 0 (quotient (- measure content) 2)) measure 'heading
               #:quadded? #t #:justification "head, centred")))

;; A title-page line: centred, and left in the case it was given in.
;;
;; The difference from a head is not decoration. A head is a line of the text
;; and is set in capitals; a title-page is a piece of display work in which
;; every line is centred and the case is chosen line by line -- the title in
;; capitals, the imprint in lower case, the motto in italic. Blayney's
;; transcripts record the mixture down to the fount of each line ("Line 1 in
;; Titling fount 1; lines 3 and 6 (part) in Titling fount 3", Appendix II
;; no. 56), so upcasing everything would throw away the one thing the
;; transcripts are most careful about.
;;
;; The type is charged to the text case, which is wrong and is reported as
;; wrong: a real title-page was set from titling founts kept apart from the
;; body fount, and this program keeps one case. The error is about forty words
;; a book, all of them large.
;; A title-page line is centred inside a panel narrower than the text measure.
;; That is not a nicety: Blayney's transcripts break the Lear title-page after
;; "the life and", "his three", "and heire to the Earle of Gloſter, and his" --
;; lines of very unequal length, none of them reaching the measure the text is
;; set to. Display work was ranged by eye within the width of the ornament and
;; the rules, not run out to the stick.
(define TITLE-PANEL 0.9)

(define (set-centred c text spec #:italic? [italic? #f])
  (define measure (page-spec-measure spec))
  (define panel (inexact->exact (round (* TITLE-PANEL measure))))
  (define ws (for/list ([p (in-list (read-copy c text))])
               (define w (make-word c p))
               (if italic? (struct-copy word w [italic? #t]) w)))
  (define rows
    (let loop ([xs ws] [cur '()] [width 0] [out '()])
      (cond
        [(null? xs) (reverse (if (null? cur) out (cons (reverse cur) out)))]
        [else
         (define extra (+ (word-width (car xs)) (if (null? cur) 0 NORMAL-SPACE)))
         (if (and (pair? cur) (> (+ width extra) panel))
             (loop xs '() 0 (cons (reverse cur) out))
             (loop (cdr xs) (cons (car xs) cur) (+ width extra) out))])))
  (for/list ([row (in-list rows)])
    (define gaps (max 0 (sub1 (length row))))
    (define content (+ (content-width row) (* NORMAL-SPACE gaps)))
    (make-line row (make-list gaps NORMAL-SPACE)
               (max 0 (quotient (- measure content) 2)) measure 'centred
               #:quadded? #t #:italic? italic?
               #:justification "title-page line, centred")))

;; Prefixes are abbreviated to whatever the line can spare, which is why the
;; same speaker is Ham., Ha. and Hamlet. within a page -- and why prefix forms
;; are themselves compositorial evidence. The cut is made after a consonant:
;; Ros. not Rose., Qu. not Quee., which is how the Folio's forms actually look.
(define (speech-prefix c name pressure)
  (define g (comp-rng c))
  (define n0 (cond [(<= pressure 0) 4] [(> pressure 0.6) 2] [else 3]))
  (define n (if (< (rnd g) 0.18) (min (string-length name) (+ n0 2)) n0))
  (define cut (substring name 0 (max 2 (min (string-length name) n))))
  (define trimmed
    (if (string=? cut name)
        cut
        (let loop ([s cut])
          (if (and (> (string-length s) 2)
                   (memv (char-downcase (string-ref s (sub1 (string-length s))))
                         '(#\a #\e #\i #\o #\u)))
              (loop (substring s 0 (sub1 (string-length s))))
              s))))
  (define wd (make-word c (string-append trimmed ".") #:italic? #t))
  (struct-copy word wd [causes (list "speech prefix abbreviated")]))

;; ---------------------------------------------------------------------------
;; Picking the sorts
;; ---------------------------------------------------------------------------

(define (pick-line! c l page lineno)
  (define prof (comp-profile c))
  (define tc (comp-case c))
  (define new-words
    (for/list ([w (in-list (set-line-words l))] [wi (in-naturals)])
      (define pieces '())
      ;; A long s followed by t, h, i or another long s is one sort in an
      ;; English fount, not two, and the compositor reaches for the ligature
      ;; when the box has one. It prints as its two letters either way -- the
      ;; page is the same; the box that emptied is not. When the ligature box
      ;; is empty he sets the letters singly, which is what Okes's men did.
      (define composed (word-composed w))
      (define skip (box -1))
      (define printed
        (apply string-append
               (for/list ([ch (in-string composed)] [ci (in-naturals)])
                 (cond
                   [(= ci (unbox skip)) ""]
                   [(and (char=? ch #\ſ) (< (add1 ci) (string-length composed))
                         (take-ligature! tc (string-ref composed (add1 ci))))
                    => (lambda (lig)
                         (set-box! skip (add1 ci))
                         (hash-ref LIGATURE-PRINTS lig ""))]
                   [else
                 (define d (pick! tc ch #:careless (profile-care prof)))
                 (when (draw-piece d)
                   (set! pieces (cons (cons ci (draw-piece d)) pieces))
                   (note-recurrence! tc (draw-piece d)
                                     (list page lineno wi ci)))
                 (when (and (draw-event d) (not (eq? (draw-event d) 'distinctive)))
                   (add-event!
                    c (make-event (case (draw-event d)
                                    [(shortage wrong-fount cannibalized
                                      blank-for-proof) 'shift]
                                    ;; Its own kind, because it is not an
                                    ;; error: the word reads correctly and the
                                    ;; corrector has nothing to mark. It is
                                    ;; evidence, and press.rkt must leave it
                                    ;; alone.
                                    [(inverted) 'inversion]
                                    [else 'accident])
                                  (draw-detail d)
                                  #:page page #:line lineno #:word wi
                                  #:compositor (profile-name prof)
                                  #:before (string (draw-wanted d))
                                  #:after (draw-got d))))
                    (draw-got d)]))))
      ;; The case is the last hand on the word: after this, `printed' and
      ;; `pieces' are what stood in the forme, and nothing may write them again.
      (struct-copy word (at-stage w 'picked 'pick-line!)
                   [printed printed] [pieces (reverse pieces)])))
  ;; And the white. A gap is metal too -- an em quad, an en, a thick, a thin --
  ;; picked from its own box like any other sort, and it can run out. Until now
  ;; the program treated the spacing as arithmetic and drew nothing for it,
  ;; which made space-metal the one part of the forme that could never be
  ;; short. Blayney makes it the hinge of the whole _Lear_ reconstruction: a
  ;; play is short lines and quadded-out ends, and "what _Lear_ used in the
  ;; quantities most unprecedented ... was space-metal".
  (for ([gap (in-list (cons (set-line-indent l) (set-line-spaces l)))]
        #:when (> gap 0))
    (define-values (pieces short?) (take-space! tc gap))
    ;; Recorded against the page so that it goes back to the boxes when the
    ;; forme is distributed, exactly as the letters do.
    (note-white! tc page pieces)
    (when short?
      (add-event! c (make-event 'shift
                                "space-metal wanting; the white made up of smaller pieces"
                                #:page page #:line lineno
                                #:compositor (profile-name prof)))))
  (struct-copy set-line l [words new-words]))

(module+ test
  (require rackunit)

  ;; One property, one writer. The stages of a word are a chronology and no
  ;; stage may write a field a later one owns -- which is checked rather than
  ;; hoped for, because the failure is silent: `revise' rewrites `printed', so
  ;; revising a word after the case had supplied its metal would undo every
  ;; foul case and every forced substitution in it and leave no trace.
  (let ()
    (define cv* (conventions #t #t #t #t #t 1600))
    (define w0 (word "composed" "composed" "compos'd" "compos'd"
                     "compos'd" "compos'd" 100 '() #f '() 'set))
    (check-equal? (word-stage (revise cv* w0 "composed" "justification: x"))
                  'fitted
                  "a word straight from the frame may be fitted")
    (define picked (struct-copy word w0 [stage 'picked] [printed "cōpoſ'd"]))
    (check-exn #rx"may not write a word that has reached"
               (lambda () (revise cv* picked "composed" "justification: x"))
               "but one the case has already set may not be")
    (check-exn #rx"unknown stage"
               (lambda () (at-stage w0 'imposed 'test))))

  (define cv (conventions #t #t #t #t #t 1600))
  (define (fresh [name "B"] [seed 1623])
    (make-comp (hash-ref PROFILES name)
               (make-type-case #:rng (make-rng seed))
               cv (make-rng seed)))

  (define spec (page-spec (* 21 UNITS-PER-EM) 38 0 EM-QUAD))

  ;; No line may overhang the measure. `make-line' enforces it, so a run that
  ;; produces one raises rather than printing something unlockable.
  (define c (fresh))
  (define copy-text
    (string-append
     "That if you be honest and fair, your honesty should admit "
     "no discourse to your beauty. Could beauty have better "
     "commerce than with honesty?"))
  (define prose (set-prose c copy-text spec 0.0))
  (check-true (>= (length prose) 3) "prose breaks into several lines")

  ;; Nothing is lost between copy and stick.
  ;;
  ;; Asserted as the copy coming back, not as a count of 24. A divided word is
  ;; two pieces carrying one `word-copy' between them -- "ſho-" and "vld" are
  ;; both `should' -- so a raw count of what stands in the stick reads 25 the
  ;; moment the compositor divides anything, and reads it as a loss when it is
  ;; the opposite. That count stood while the normal space was a third of an em
  ;; and broke on Moxon's quarter, which divides oftener: the test was measuring
  ;; the space-ladder and calling it the copy.
  ;;
  ;; Dropping the continuations and rejoining says what was meant, and says it
  ;; in a form no ladder can move: the same words, in the same order, all of
  ;; them. It is also strictly stronger -- a count of 24 would survive two words
  ;; swapping places, and this does not.
  (define (continuation? w)
    (and (member "second half of a divided word" (word-causes w)) #t))
  (define standing
    (for*/list ([l (in-list prose)]
                [w (in-list (set-line-words l))]
                #:unless (continuation? w))
      (word-copy w)))
  (check-equal? (string-join standing " ") copy-text
                "every word of the copy is standing in type, in order")
  (for ([l (in-list prose)])
    (check-true (<= (line-set-width l) (page-spec-measure spec))
                (format "line overhangs: ~s" (line-text l))))

  ;; Every justified line but the last fills the measure to within a hair.
  ;;
  ;; Not exactly, and the difference is the point. Exact filling needs spaces
  ;; of arbitrary width, and this test passed for as long as `apportion' handed
  ;; out single units of 1/120 em -- a body no founder ever cast. Once the
  ;; white had to be made of real pieces, 86% of the gaps it had been producing
  ;; turned out to be widths no combination of em, en, thick, middle, thin and
  ;; hair could make. The line now fills to within less than the finest body in
  ;; the case, which is as exactly as a line can be filled, and the residue is
  ;; taken up by the pressure of the lock-up as it was in a chase.
  (for ([l (in-list (drop-right prose 1))])
    (define short (- (page-spec-measure spec) (line-set-width l)))
    (check-true (and (>= short 0) (< short FINEST-SPACE))
                (format "line off the measure by ~a of 1/~a em: ~s"
                        short UNITS-PER-EM (line-text l))))

  ;; Verse turned over rather than overhanging.
  (define c2 (fresh "A"))
  (define verse
    (set-verse c2 (string-append "And thus the native hue of resolution is "
                                 "sicklied over with the pale cast of thought")
               spec 0.0))
  (check-true (>= (length verse) 2) "a long verse line is turned over")
  (for ([l (in-list verse)])
    (check-true (<= (line-set-width l) (page-spec-measure spec))))

  ;; Trying a word and rejecting it leaves the originals untouched. This is
  ;; the bug class that the Python snapshot/restore existed to prevent.
  (define c3 (fresh))
  (define w1 (make-word c3 "cannot"))
  (define w2 (revise cv w1 "canot" "justification: double n reduced"))
  (check-equal? (word-final w1) "cannot" "the original word is unchanged")
  (check-equal? (word-final w2) "canot")
  (check-true (< (word-width w2) (word-width w1)))
  (check-equal? (word-causes w1) '())

  ;; Squeezing returns a new list and does not touch the old one.
  (define ws (list (make-word c3 "and") (make-word c3 "the") (make-word c3 "cannot")))
  (define-values (ws2 note) (squeeze cv ws (comp-rng c3) 1))
  (check-not-false ws2)
  (check-equal? (map word-final ws) '("and" "the" "cannot"))
  (check-false (equal? (map word-final ws) (map word-final ws2)))

  ;; A speech prefix is cut after a consonant -- asserted as the property, not
  ;; as one string. The cut length has a deliberate 18% long branch, so testing
  ;; a single draw against "Qu." was testing the seed: it broke the moment
  ;; anything upstream touched the random stream, and the value it then gave
  ;; ("Queen.") was perfectly correct behaviour.
  (for ([name (in-list '("Queen" "Rosencrantz" "Horatio" "Ophelia" "Laertes"))])
    (for ([i (in-range 12)])
      (define p (word-final (speech-prefix c3 name (* 0.1 i))))
      (check-true (string-suffix? p ".") "a prefix ends in a point")
      (define stem (substring p 0 (sub1 (string-length p))))
      (check-true (string-prefix? name stem) "and is a cut of the name")
      ;; ... unless cutting to a consonant would leave fewer than two letters,
      ;; which is the floor the trimming loop enforces. `Queen' cuts to `Que',
      ;; loses the e, and stops at `Qu' rather than going on to `Q'.
      (when (and (< (string-length stem) (string-length name))
                 (> (string-length stem) 2))
        (check-false (memv (char-downcase (string-ref stem (sub1 (string-length stem))))
                           '(#\a #\e #\i #\o #\u))
                     "a shortened prefix is cut after a consonant"))))

  ;; A head too wide for the measure is broken, not overhung.
  (define heads (set-heading c3 "The Tragedie of Hamlet Prince of Denmarke" spec))
  (check-true (>= (length heads) 2))
  (for ([l (in-list heads)])
    (check-true (<= (line-set-width l) (page-spec-measure spec)))))
