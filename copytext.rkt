#lang racket/base
;;; The copy: what lies on the compositor's visorium, and how he misreads it.
;;;
;;; The copy-text is the thing the New Bibliography exists to reconstruct and
;;; can never see. Here we have the luxury of possessing it, which is the
;;; whole point of the exercise: everything the press does to it is recorded,
;;; so that the reconstruction can afterwards be scored against the truth.
;;;
;;; The misreadings modelled here are those the New Bibliographers assembled
;;; into a standing repertory of scribal and compositorial error: the minim
;;; confusions of the secretary hand, in which m, n, u, i and w are all built
;;; from the same downstrokes; the confusion of e with o and c with t;
;;; eyeskip over a repeated word; the substitution of a commoner phrase for a
;;; rarer one under the pressure of memory; and simple transposition.

(require racket/string racket/list racket/match racket/set "rng.rkt"
         (only-in "typecase.rkt" SHAPE-CONFUSIONS))

(provide (struct-out copy-unit) (struct-out misreading)
         COPY-KINDS current-copy-kind copy-kind-note copy-kind-scale
         parse-copy misread EDITORIAL abbreviate-prefix
         MINIM-CONFUSIONS HAND-CONFUSIONS MEMORIAL)

;; kind is one of 'verse 'prose 'prefix 'stage 'heading 'blank
(struct copy-unit (kind text index speaker) #:transparent)

(struct misreading (original reading kind note) #:transparent)

(define stage-rx
  #px"^(?:\\[|(?i:enter|exit|exeunt|manet|alarum|flourish|sennet|dies|aside|within)\\b)")

(define prefix-rx
  #px"^([A-Z][A-Za-z'’]{1,14}(?:\\s+[A-Z][a-z]{1,12})?)\\.\\s+(.*)$")

(define prefix-only-rx #px"^([A-Z][A-Z '’]{1,20})[.:]?\\s*$")

(define (stage-direction? line) (regexp-match? stage-rx line))

(define (looks-like-verse? line) (< (string-length line) 78))

;; ---------------------------------------------------------------------------
;; Editorial brackets
;; ---------------------------------------------------------------------------
;; A modern edition supplies its stage directions in square brackets, and puts
;; them wherever the sense wants them: on their own line, at the head of a
;; speech, in the middle of one. The Folio does none of this. Its directions
;; are set in italic on a line of their own or ranged right at the end of one,
;; and there is not a square bracket on the page -- the brackets are the
;; editor's apparatus, exactly like the underscores Gutenberg marks italic
;; with, and no compositor ever set either.
;;
;; This was reading only the whole-line case. A line beginning `[Aside.] I
;; must obey. His art is of such power,' matched the direction test on its
;; first character, so the ENTIRE verse line was set as a direction -- italic,
;; ranged right -- and the trailing bracket survived the trim to print as
;; `Afide.] I must obey ...'. 611 lines of the Folio went that way, with 350
;; more broken mid-line and 45 at the end. The visible stray bracket was the
;; small half of it.
;;
;; So the brackets are taken out here, before anything else looks at the line,
;; and each bracketed span becomes a direction in its own right. A span that
;; stands before any speech text is set above the line, and one that interrupts
;; or follows it below: the compositor cannot set a direction inside a line of
;; verse, and moving it off the line keeps the verse line whole, which
;; splitting it would not.
(define bracket-rx #px"\\[([^\\[\\]]*)\\]")

;; The speaker's name does not count as speech: in `ARIEL. [Aside.] I must
;; obey', the direction still stands at the head of the speech and belongs
;; above it, not below.
(define (only-a-prefix? s)
  (regexp-match? #px"^\\s*[A-Z][A-Za-z'’]{1,14}(?:\\s+[A-Z][a-z]{1,12})?\\.\\s*$" s))

;; -> (values text-without-directions directions-before directions-after)
(define (lift-directions line)
  (cond
    [(not (string-contains? line "[")) (values line '() '())]
    [else
     (define before '())
     (define after '())
     (define text
       (let loop ([s line] [out ""])
         (define m (regexp-match-positions bracket-rx s))
         (cond
           [(not m) (string-append out s)]
           [else
            (define head (string-append out (substring s 0 (caar m))))
            (define d (string-trim (substring s (car (cadr m)) (cdr (cadr m)))))
            (define seen-text?
              (and (non-empty-string? (string-trim head))
                   (not (only-a-prefix? head))))
            (unless (string=? d "")
              (if seen-text?
                  (set! after (cons d after))
                  (set! before (cons d before))))
            (loop (substring s (cdar m)) head)])))
     (values (string-trim (regexp-replace* #px"\\s{2,}" text " "))
             (reverse before) (reverse after))]))

;; Who actually speaks in this copy.
;;
;; A verse line may perfectly well read "Affront Ophelia. Her father and
;; myself," and look exactly like a speech prefix. What distinguishes a real
;; speaker is that he comes back: prefixes recur, and they recur in the stage
;; directions that bring the speaker on. One pass over the copy to collect
;; them, and the ambiguity disappears.
(define (find-speakers lines)
  (define counts (make-hash))
  (define named (make-hash))
  (for ([raw (in-list lines)])
    (define line (string-trim raw))
    (cond
      [(string=? line "") (void)]
      [(stage-direction? line)
       (for ([w (in-list (regexp-match* #px"[A-Z][a-z]{2,}" line))])
         (hash-set! named w #t))]
      [else
       (define m (regexp-match prefix-rx line))
       (when m (hash-update! counts (cadr m) add1 0))]))
  (for/set ([(name n) (in-hash counts)]
            #:when (or (>= n 2)
                       (hash-ref named (car (string-split name)) #f)))
    name))

(define (split-speech-prefix line [speakers #f])
  (define m1 (regexp-match prefix-only-rx line))
  (cond
    [(and m1 (string=? line (string-upcase line)))
     (values (string-titlecase (string-trim (cadr m1))) "")]
    [else
     (define m (regexp-match prefix-rx line))
     (cond
       [(not m) (values #f line)]
       [else
        (define name (cadr m))
        (define rest (caddr m))
        (cond
          [(and speakers (not (set-member? speakers name))) (values #f line)]
          [(and (<= (length (string-split name)) 2)
                (> (string-length rest) 0)
                (char-upper-case? (string-ref rest 0)))
           (values name rest)]
          [else (values #f line)])])]))

(define (sniff lines)
  (define body
    (filter (lambda (l) (and (not (string=? l ""))
                             (not (string-prefix? l "#"))))
            (map string-trim lines)))
  (cond
    [(null? body) 'prose]
    [else
     (define n (length body))
     (define prefixed
       (for/sum ([l (in-list body)])
         (define-values (p _r) (split-speech-prefix l))
         (if p 1 0)))
     (define shortish (for/sum ([l (in-list body)])
                        (if (< (string-length l) 62) 1 0)))
     (define capitalled (for/sum ([l (in-list body)])
                          (if (char-upper-case? (string-ref l 0)) 1 0)))
     (cond
       [(> prefixed (* n 0.12)) 'drama]
       [(and (> shortish (* n 0.8)) (> capitalled (* n 0.6))) 'verse]
       [else 'prose])]))

;; A long direction may be wrapped over two or three lines, leaving the `[' on
;; one and the `]' on another; taken a line at a time the second half prints as
;; `and Claudio.]'. Join them up before anything else reads the copy.
(define (close-brackets lines)
  (define (opens s)
    (- (length (regexp-match* #px"\\[" s)) (length (regexp-match* #px"\\]" s))))
  (let loop ([ls lines] [out '()])
    (cond
      [(null? ls) (reverse out)]
      [(<= (opens (car ls)) 0) (loop (cdr ls) (cons (car ls) out))]
      [else
       ;; take following lines until the bracket closes, but never across a
       ;; blank line and never more than three -- an unclosed bracket is
       ;; likelier to be a defect in the copy than a very long direction.
       (let take ([rest (cdr ls)] [acc (car ls)] [n 0])
         (cond
           [(or (null? rest) (= n 3) (string=? (string-trim (car rest)) ""))
            (loop (cdr ls) (cons (car ls) out))]
           [else
            (define joined (string-append acc " " (string-trim (car rest))))
            (if (<= (opens joined) 0)
                (loop (cdr rest) (cons joined out))
                (take (cdr rest) joined (add1 n)))]))])))

;; Break a plain text into the units a compositor would recognise.
(define (parse-copy text [kind 'auto])
  (define lines
    (close-brackets
     (string-split (string-replace (string-replace text "\r\n" "\n") "\r" "\n")
                   "\n" #:trim? #f)))
  (define k (if (eq? kind 'auto) (sniff lines) kind))
  (define speakers (find-speakers lines))

  (define units '())       ; reversed
  (define para '())        ; reversed

  (define (emit! kind text [speaker #f])
    (set! units (cons (copy-unit kind text (length units) speaker) units)))

  (define (flush!)
    (unless (null? para)
      (emit! 'prose (string-trim (string-join (reverse para) " ")))
      (set! para '())))

  (for ([raw (in-list lines)])
    (define line (string-trim raw #:left? #f))
    (define stripped (string-trim line))
    (cond
      [(string=? stripped "")
       (flush!)
       (when (and (pair? units) (not (eq? (copy-unit-kind (car units)) 'blank)))
         (emit! 'blank ""))]

      [(string-prefix? stripped "#")
       (flush!)
       (emit! 'heading (string-trim (string-trim stripped "#" #:right? #f)))]

      [else
       (define-values (body before after) (lift-directions stripped))
       (define (direction! d) (flush!) (emit! 'stage d))
       (for-each direction! before)
       (cond
         [(string=? body "") (void)]       ; the line was direction and nothing else

         [(stage-direction? body)
          (flush!)
          (emit! 'stage body)]

         [else
          (define-values (prefix rest) (split-speech-prefix body speakers))
          (cond
            [prefix
             (flush!)
             (emit! 'prefix prefix #f)
             (unless (string=? rest "")
               ;; A speech is not verse merely because it is a speech. Hamlet
               ;; abuses Ophelia in prose, and the compositor can see that as
               ;; well as we can: the line runs past where a verse line stops.
               (define verse? (and (memq k '(verse drama)) (looks-like-verse? rest)))
               (emit! (if verse? 'verse 'prose) rest prefix))]
            [(and (memq k '(verse drama)) (looks-like-verse? body))
             (flush!)
             (emit! 'verse body)]
            [else (set! para (cons body para))])])
       (for-each direction! after)]))

  (flush!)
  (mark-editorial-blanks (reverse units) k))

;; A blank line between two speeches is the editor's, not the copy's.
;;
;; The Folio sets a play solid. On Lear 295 `Lear. You? Did you?' follows
;; `Deferu'd much leffe aduancement.' with nothing between them, `Reg. I pray
;; you Father ...' follows that, and the two columns run sixty-six lines each
;; without a white line anywhere in them; the white and the rules come at
;; `Actus Tertius. Scena Prima.' and nowhere else. A modern edition puts a
;; blank line between speeches because a modern reader expects one, and the
;; reader of this program was setting every one of them as a white line of
;; quads -- a line of the page spent on each of the copy's paragraph breaks.
;;
;; The unit is still emitted, because it IS in the copy and the reader's job is
;; to say what the copy contains. It is marked instead, and `compose' declines
;; to set white for it. That keeps the decision where it belongs: the reader
;; reports, the compositor lays out.
;;
;; Only in dramatic copy, and only where no heading is next to it. A blank
;; between stanzas of a poem is the poet's and is set; so is the white round an
;; act heading, which `compose' supplies for itself in any case.
(define EDITORIAL "editorial break")

;; How a speaker's name is cut down to the prefix that stands at the head of his
;; line -- "Hamlet" to "Ham.", trailing vowels taken off so it does not break on
;; one. It lives here rather than in `compositor.rkt' because two stages need the
;; same answer and must not each have their own: the compositor sets the prefix,
;; and the man casting off has to allow room for it. While only the first of
;; those knew the rule, the casting off measured a verse line without the prefix
;; that would be set in front of it, and could not see the turn-overs the prefix
;; caused -- 156 of them in 1,110 speeches on a slice of the Folio. One property,
;; one decision point.
(define (abbreviate-prefix name [chars 4])
  (define cut (substring name 0 (max 2 (min (string-length name) chars))))
  (string-append
   (if (string=? cut name)
       cut
       (let loop ([s cut])
         (if (and (> (string-length s) 2)
                  (memv (char-downcase (string-ref s (sub1 (string-length s))))
                        '(#\a #\e #\i #\o #\u)))
             (loop (substring s 0 (sub1 (string-length s))))
             s)))
   "."))

(define (mark-editorial-blanks us k)
  (cond
    [(not (eq? k 'drama)) us]
    [else
     (define v (list->vector us))
     (define (kind-at i)
       (and (>= i 0) (< i (vector-length v)) (copy-unit-kind (vector-ref v i))))
     (for/list ([u (in-list us)] [i (in-naturals)])
       (cond
         [(and (eq? (copy-unit-kind u) 'blank)
               (not (eq? (kind-at (sub1 i)) 'heading))
               (not (eq? (kind-at (add1 i)) 'heading)))
          (struct-copy copy-unit u [speaker EDITORIAL])]
         [else u]))]))

;; ---------------------------------------------------------------------------
;; Misreading the copy
;; ---------------------------------------------------------------------------
;; In the secretary hand the minims -- the plain downstrokes that make up m,
;; n, u, i, v and w -- are undifferentiated, so that a word may be counted
;; wrong without being read wrong at all. This is the single most productive
;; source of error in the transmission of English printed drama, and the
;; standing justification for a great deal of emendation.

(define MINIM-CONFUSIONS
  '(("m" "in") ("in" "m") ("m" "ni") ("nn" "un") ("un" "nn")
    ("u" "n") ("n" "u") ("ui" "in") ("im" "un") ("w" "vv")
    ("m" "nn") ("nu" "un")))

;; Letters the secretary hand does not keep decently apart.
(define HAND-CONFUSIONS
  '(("e" "o") ("o" "e") ("c" "t") ("t" "c") ("c" "e") ("e" "c")
    ("f" "ſ") ("l" "b") ("h" "b") ("a" "o") ("y" "g") ("r" "s")))

;; ---------------------------------------------------------------------------
;; What the copy was
;; ---------------------------------------------------------------------------
;; Greg's classification, and the New Bibliography's own vocabulary: the copy a
;; compositor was handed was the author's **foul papers**, a scribe's **fair
;; copy**, or an earlier **printed** book. It decides what the eye can go wrong
;; at, which is a different question from how careless the man is.
;;
;; THE PROGRAM ALREADY ASSUMED ONE OF THESE AND NEVER SAID SO. Every misreading
;; here is a manuscript phenomenon -- minims miscounted, letters the secretary
;; hand does not keep apart -- and between them they carry 85% of the slips.
;; (ROADMAP §11 said the opposite, that "every misreading profile assumes
;; printed copy". It had it backwards.) Naming the assumption is most of what
;; this adds; the third mode is the new thing.
;;
;; **Setting from print is not easier manuscript, it is a different confusion
;; set.** No minim is miscounted in a printed exemplar, because type keeps its
;; strokes apart. What misleads a man reading type is what Hornschuch says
;; misleads him reaching into the case -- "letters similar in form elude the
;; printer", r/t, n/u, e/c, c/t, ſ/f -- and `SHAPE-CONFUSIONS' in typecase.rkt
;; is that list already, put there for foul case. One shape, two places it can
;; do harm.
;;
;; The RATES are an ordering and not a measurement. Nothing here says foul
;; papers yield so many times the errors of a fair copy; what the bibliographers
;; agree is the order -- an author's working draft is the hardest thing to set
;; from, a scribe's fair copy easier, print easiest. The multipliers below carry
;; that order and are knobs, and the report says so.
;; Hornschuch's shapes, in the pair form `apply-pair' wants. NOT a second copy
;; of the list: `SHAPE-CONFUSIONS' in typecase.rkt is the one place it is
;; written down, and this turns that hash into pairs. The same shapes mislead a
;; man reaching into the case and a man reading a printed page, which is why
;; one list serves both and why neither may drift from the other.
(define PRINT-CONFUSIONS
  (for*/list ([(from tos) (in-hash SHAPE-CONFUSIONS)]
              [to (in-list tos)])
    (list (string from) (string to))))

(define COPY-KINDS '(foul fair print))
(define COPY-KIND-SCALE (hash 'foul 1.5 'fair 1.0 'print 0.5))
(define current-copy-kind (make-parameter 'fair))

(define (copy-kind-scale) (hash-ref COPY-KIND-SCALE (current-copy-kind) 1.0))

(define (copy-kind-note k)
  (case k
    [(foul) "the author's foul papers, in his own hand"]
    [(fair) "a scribe's fair copy, in the secretary hand"]
    [(print) "an earlier printed book"]
    [else "copy of an unstated kind"]))

;; Commonplaces that swim up under the pressure of memory and displace the
;; rarer reading actually in the copy.
(define MEMORIAL
  (hash "sad" "poor" "poor" "sad" "great" "good" "good" "great"
        "thy" "the" "the" "thy" "a" "the" "this" "the" "these" "those"
        "shall" "will" "will" "shall" "doth" "does" "hath" "has"
        "mine" "my" "my" "mine" "and" "but" "but" "and"
        "life" "love" "love" "life" "heart" "head" "sword" "word"))

(define (apply-pair word pairs g)
  (define low (string-downcase word))
  (define candidates (filter (lambda (p) (string-contains? low (car p))) pairs))
  (cond
    [(null? candidates) #f]
    [else
     (define p (rnd-choice g candidates))
     (define idx (let loop ([i 0])
                   (cond [(> (+ i (string-length (car p))) (string-length low)) #f]
                         [(string=? (substring low i (+ i (string-length (car p))))
                                    (car p)) i]
                         [else (loop (add1 i))])))
     (and idx
          (string-append (substring word 0 idx)
                         (cadr p)
                         (substring word (+ idx (string-length (car p))))))]))

(define (transpose word g)
  (define n (string-length word))
  (and (>= n 4)
       (let ([i (+ 1 (rnd-int g (- n 3)))])
         (string-append (substring word 0 i)
                        (string (string-ref word (add1 i))
                                (string-ref word i))
                        (substring word (+ i 2))))))

;; Pass a line of copy through a fallible eye and a fallible memory.
;;
;; Returns (values pairs errors) where each pair is (cons copy-form read-form).
;; Keeping both is the whole point: the copy reading is what an editor is
;; trying to recover, and it is the one thing the printed page does not
;; contain.
(define (misread words g rate memorial-rate)
  (define errors '())
  (define (note! e) (set! errors (cons e errors)))

  (define pairs
    (for/list ([wd (in-list words)])
      (define cur wd)
      (cond
        [(< (string-length cur) 3) (cons wd cur)]
        [else
         (define slip
           (and (< (rnd g) (* rate (copy-kind-scale)))
                (let ([roll (rnd g)])
                  (cond
                    ;; Reading type. No minim is miscounted in a printed
                    ;; exemplar; what elude him are the shapes Hornschuch names.
                    [(eq? (current-copy-kind) 'print)
                     (if (< roll 0.85)
                         (let ([n (apply-pair cur PRINT-CONFUSIONS g)])
                           (and n (list n 'misreading
                                        "letters alike in the printed copy")))
                         (let ([n (transpose cur g)])
                           (and n (list n 'transposition
                                        "letters transposed in the stick"))))]
                    [(< roll 0.45)
                     (let ([n (apply-pair cur MINIM-CONFUSIONS g)])
                       (and n (list n 'minim "minims miscounted in the copy")))]
                    [(< roll 0.85)
                     (let ([n (apply-pair cur HAND-CONFUSIONS g)])
                       (and n (list n 'misreading
                                    "letters confused in the secretary hand")))]
                    [else
                     (let ([n (transpose cur g)])
                       (and n (list n 'transposition
                                    "letters transposed in the stick")))]))))
         (cond
           [(and slip (not (string=? (car slip) cur)))
            (note! (misreading wd (car slip) (cadr slip) (caddr slip)))
            (cons wd (car slip))]
           [else
            (define low (string-trim cur ".,;:!?" #:repeat? #t))
            (define lowd (string-downcase low))
            (cond
              [(and (hash-has-key? MEMORIAL lowd) (< (rnd g) memorial-rate))
               (define sub (hash-ref MEMORIAL lowd))
               (define new (if (string-contains? cur lowd)
                               (string-replace cur lowd sub)
                               sub))
               (note! (misreading wd new 'memorial
                                  "commoner word substituted from memory"))
               (cons wd new)]
              [else (cons wd cur)])])])))

  ;; Two like words near by, and the position of each. The eye can go wrong at
  ;; such a pair in either direction, so both slips below want the same search.
  (define (like-pair ps)
    (define v (list->vector ps))
    (define seen (make-hash))
    (let loop ([i 0])
      (cond
        [(>= i (vector-length v)) #f]
        [else
         (define cur (string-downcase (cdr (vector-ref v i))))
         (define j (hash-ref seen cur #f))
         (cond
           [(and j (> (- i j) 1) (<= (- i j) 4) (> (string-length cur) 2))
            (list v j i)]
           [else (hash-set! seen cur i) (loop (add1 i))])])))

  ;; eyeskip: the eye returns to the second of two like words near by, and
  ;; everything between them is lost without trace
  (define after-skip
    (cond
      [(and (> (length pairs) 6) (< (rnd g) (* rate 0.6)))
       (define hit (like-pair pairs))
       (cond
         [(not hit) pairs]
         [else
          (define v (first hit)) (define j (second hit)) (define i (third hit))
          (define dropped
            (string-join (for/list ([k (in-range (add1 j) (add1 i))])
                           (car (vector-ref v k))) " "))
          (note! (misreading dropped "" 'eyeskip
                             (format "eye returned to the second ~s"
                                     (cdr (vector-ref v i)))))
          (append (for/list ([k (in-range 0 (add1 j))]) (vector-ref v k))
                  (for/list ([k (in-range (add1 i) (vector-length v))])
                    (vector-ref v k)))])]
      [else pairs]))

  ;; DITTOGRAPHY: THE SAME SLIP, THE OTHER WAY. The eye leaves the copy and
  ;; comes back to the FIRST of the two like words instead of the second, and
  ;; the passage between them is set a second time. Hornschuch's mark for
  ;; anything redundant, to be struck through.
  ;;
  ;; It takes the rate of the mechanism it mirrors rather than one of its own.
  ;; Textual criticism has always treated the pair together -- haplography and
  ;; dittography -- and there is no reason an eye returning to the wrong one of
  ;; two like words should favour the earlier or the later. Asserting them equal
  ;; is a weaker claim than any number invented for the second would be.
  ;;
  ;; The repeated words are given an EMPTY copy, because nothing in the copy
  ;; answers them. That is not a convenience: `press.rkt' already strikes out
  ;; any word whose copy is empty -- it is how a word doubled at a page join is
  ;; mended -- so writing them this way makes them correctable at press without
  ;; the corrector needing to learn a new kind of fault.
  (define final
    (cond
      [(and (> (length after-skip) 6) (< (rnd g) (* rate 0.6)))
       (define hit (like-pair after-skip))
       (cond
         [(not hit) after-skip]
         [else
          (define v (first hit)) (define j (second hit)) (define i (third hit))
          (define again (for/list ([k (in-range (add1 j) (add1 i))])
                          (vector-ref v k)))
          (note! (misreading "" (string-join (map cdr again) " ") 'dittography
                             (format "eye returned to the first ~s"
                                     (cdr (vector-ref v i)))))
          (append (for/list ([k (in-range 0 (add1 i))]) (vector-ref v k))
                  (for/list ([q (in-list again)]) (cons "" (cdr q)))
                  (for/list ([k (in-range (add1 i) (vector-length v))])
                    (vector-ref v k)))])]
      [else after-skip]))

  (values final (reverse errors)))

(module+ test
  (require rackunit)

  ;; THE COPY DECIDES WHAT THE EYE CAN GO WRONG AT, and the claim is an
  ;; ORDERING: an author's foul papers are the hardest thing to set from, a
  ;; scribe's fair copy easier, an earlier printed book easiest. The
  ;; multipliers are knobs and no source gives them; the order is not.
  ;;
  ;; Asserted over several seeds because it was nearly asserted on one. Seed 5
  ;; happens to give foul and fair the same total exactly -- 32 apiece -- and
  ;; that coincidence cost most of an hour hunting a bug that was not there.
  ;; One seed is a test of the seed.
  (let ()
    (define ws (for/list ([i 4000]) (list-ref '("minim" "vnion" "sonne" "wonder"
                                                 "notion" "certaine" "reason")
                                              (modulo i 7))))
    (define (slips k seed)
      (parameterize ([current-copy-kind k])
        (define-values (_p errs) (misread ws (make-rng seed) 0.02 0.0))
        (length errs)))
    (define (total k) (for/sum ([s '(1 2 3 4 5)]) (slips k s)))
    (define foul (total 'foul))
    (define fair (total 'fair))
    (define prn  (total 'print))
    (check-true (> foul fair)
                (format "foul papers are hardest to set from (~a vs ~a)" foul fair))
    (check-true (> fair prn)
                (format "and print is easiest (~a vs ~a)" fair prn))
    ;; Print is not easier manuscript: no minim can be miscounted in type.
    (check-false
     (parameterize ([current-copy-kind 'print])
       (define-values (_p errs) (misread ws (make-rng 9) 0.05 0.0))
       (for/or ([e (in-list errs)]) (eq? (misreading-kind e) 'minim)))
     "no minim is miscounted in a printed exemplar")
    ;; And a hand still miscounts them.
    (check-true
     (parameterize ([current-copy-kind 'fair])
       (define-values (_p errs) (misread ws (make-rng 9) 0.05 0.0))
       (for/or ([e (in-list errs)]) (eq? (misreading-kind e) 'minim)))
     "but a secretary hand does"))

  (define drama "Enter King and Queen.\n\nKing. And can you by no drift\nGet from him why he puts on this confusion?\n\nQueen. Did he receive you well?\n\nKing. Affront Ophelia. Her father and myself,\nLawful espials, will bestow ourselves\n")
  (define us (parse-copy drama))
  (define kinds (map copy-unit-kind us))
  (check-not-false (memq 'stage kinds))
  (check-not-false (memq 'prefix kinds))
  (check-not-false (memq 'verse kinds))

  ;; "Affront Ophelia." looks exactly like a speech prefix but occurs once,
  ;; so it must not be taken for one.
  (check-false
   (for/or ([u (in-list us)])
     (and (eq? (copy-unit-kind u) 'prefix)
          (string-prefix? (copy-unit-text u) "Affront"))))
  ;; King and Queen recur or are named in the direction, so they are speakers.
  (define prefixes
    (for/list ([u (in-list us)] #:when (eq? (copy-unit-kind u) 'prefix))
      (copy-unit-text u)))
  (check-not-false (member "King" prefixes))
  (check-not-false (member "Queen" prefixes))

  ;; A modern edition's square brackets are apparatus, not copy: not one of
  ;; them appears in the Folio, and a direction inside one is a direction
  ;; wherever the editor put it. Nothing bracketed may reach the case.
  (define bracketed
    (parse-copy
     (string-append
      "Prospero. Come forth, I say.\n\n"
      "Ariel. All hail, great master, grave sir, hail.\n\n"
      "Ariel. [Aside.] I must obey. His art is of such power,\n"
      "It would controll my dam's god Setebos.\n\n"
      "Prospero. Free thee for this. [To Ferdinand.] A word, good sir.\n\n"
      "Miranda. Let's see your song. [Taking the letter.]\n\n"
      "[Dance. Then exeunt all but Don John, Borachio\nand Claudio.]\n")
     'drama))
  (check-false (for/or ([u (in-list bracketed)])
                 (regexp-match? #px"[][]" (copy-unit-text u))))
  (define staged
    (for/list ([u (in-list bracketed)] #:when (eq? (copy-unit-kind u) 'stage))
      (copy-unit-text u)))
  (check-equal? staged
                (list "Aside." "To Ferdinand." "Taking the letter."
                      "Dance. Then exeunt all but Don John, Borachio and Claudio."))
  ;; The verse line the direction was sitting in survives whole ...
  (check-not-false
   (for/or ([u (in-list bracketed)])
     (equal? (copy-unit-text u) "I must obey. His art is of such power,")))
  ;; ... and a direction at the head of a speech is set above the prefix, not
  ;; below the line: the speaker's name is not yet speech.
  (define ks (map copy-unit-kind bracketed))
  (check-equal? (take (drop ks 6) 3) '(stage prefix verse))

  ;; Misreading preserves the copy reading alongside what he took it for,
  ;; and never invents or loses a word except by recorded eyeskip.
  (define g (make-rng 7))
  (define words (string-split "the quick brown foxes leap over lazy hounds today"))
  (define-values (pairs errs) (misread words g 0.9 0.2))
  (define skipped
    (for/sum ([e (in-list errs)] #:when (eq? (misreading-kind e) 'eyeskip))
      (length (string-split (misreading-original e)))))
  (check-equal? (+ (length pairs) skipped) (length words))
  (check-equal? (map car pairs)
                (for/list ([wd (in-list words)]
                           #:when (member wd (map car pairs)))
                  wd)))
