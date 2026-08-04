#lang racket/base
;;; The printing house: casting off, dividing the stints, and setting the book.
;;;
;;; This module is the shop floor. It takes a copy-text and a format, measures
;;; the copy out into pages, hands them to the workmen in the order the house
;;; would actually set them, and lets each man discover for himself that the
;;; casting off was wrong.
;;;
;;; That discovery is the interesting part. A compositor setting seriatim who
;;; finds he has overrun simply carries the surplus to the next page. A
;;; compositor setting by formes cannot: the next page of his copy belongs to
;;; a different forme and may already be standing in type. So he crowds --
;;; thinner spaces, more abbreviations, verse run together as prose, the white
;;; lines suppressed -- and if crowding will not do it, he leaves something
;;; out. Crowded and gaping pages are therefore not accidents of taste. They
;;; are the signature of setting by formes, and they mark the joins in the
;;; casting off.

(require racket/list racket/string racket/math
         "metrics.rkt" "orthography.rkt" "typecase.rkt" "copytext.rkt"
         "corrector.rkt" "compositor.rkt" "imposition.rkt" "rng.rkt")

(provide (struct-out page) (struct-out book) (struct-out house)
         (struct-out standing-type)
         make-house set-book
         page-sig page-all-lines page-text book-gatherings book-collation
         book-find-page)

;; The field is `pref', not `ref': `page-ref' is already the struct that names
;; a leaf and side in imposition.rkt, and two bindings of that name in one
;; module is a morning wasted.
(struct page (pref columns compositor running-title catchword signature
                   pressure cast-off-note forme-name omitted)
  #:transparent)

(define (page-sig p) (page-ref-signature (page-pref p)))

(define (page-all-lines p) (append* (page-columns p)))

(define (page-text p)
  (string-join (map line-text (page-all-lines p)) "\n"))

(struct book (pages formes skeletons fmt events stints case title
                    copy-units authors-copy preparation standing)
  #:transparent)

;; The high-water mark of standing type, and the page-by-page ledger behind it.
(struct standing-type (peak-sorts peak-pages ledger by-formes?) #:transparent)

(define (book-gatherings b)
  (add1 (for/fold ([m -1]) ([p (in-list (book-pages b))])
          (max m (page-ref-gathering (page-pref p))))))

(define (book-collation b)
  (collation-formula (book-fmt b) (book-gatherings b)))

(define (book-find-page b sig)
  (for/or ([p (in-list (book-pages b))]) (and (string=? (page-sig p) sig) p)))

;; ---------------------------------------------------------------------------
;; The house
;; ---------------------------------------------------------------------------

(struct house (fmt compositor-names seed by-formes? conventions case-scale
                   cast-off-accuracy n-skeletons formes-standing
                   prepare-copy? title profiles condition stint-sheets)
  #:transparent)

(define (make-house #:fmt [fmt QUARTO]
                    #:compositors [names '("A" "B")]
                    #:seed [seed 1623]
                    #:by-formes? [by-formes? #t]
                    #:conventions [cv (conventions #t #t #t #t)]
                    #:case-scale [case-scale 1.0]
                    #:cast-off-accuracy [acc 0.93]
                    #:skeletons [nsk 2]
                    #:formes-standing [standing 2]
                    #:prepare-copy? [prep? #t]
                    #:title [title "THE HISTORY"]
                    ;; so that a workman can be driven with figures derived
                    ;; from a real book rather than from the built-in guesses
                    #:profiles [profiles PROFILES]
                    ;; new | used | worn | foul, or a number: how much of the
                    ;; fount is individually identifiable by its damage
                    #:condition [condition 'used]
                    ;; Mean length of a compositor's stint, in sheets.
                    ;;
                    ;; This program used to change compositors every forme, a
                    ;; tidy alternation that the one shop whose records survive
                    ;; flatly contradicts. McKenzie: when two or more men
                    ;; worked on a book "they did not work together setting
                    ;; sheet and sheet about. What usually happened was that
                    ;; one took over where the other left off and then composed
                    ;; as many sheets as the master found convenient or as
                    ;; other commitments allowed" (i. 107).
                    ;;
                    ;; His quarto Virgil shows the shape: Bertram set A-E,
                    ;; Crownfield F-3G, Michaelis 3H-3Z, Bertram again to 4F,
                    ;; Delie a single sheet at 4G, Crownfield from 4H, Bertram
                    ;; finishing. Long blocks, with the occasional single sheet
                    ;; dropped in where a man was free.
                    ;;
                    ;; Left at #f the length follows the size of the shop,
                    ;; which is Gaskell's rule (p. 41) and the thing that
                    ;; reconciles the authorities. Where there were "no more
                    ;; than two or three" compositors the tendency was for a
                    ;; man to concentrate on particular books "and to set at
                    ;; least whole sheets or whole formes" -- McKenzie's
                    ;; Cambridge, and long stints. Where there were more, the
                    ;; copy went out in small "takings" or "takes" "to whoever
                    ;; was ready for them", so that "the setting of sheets,
                    ;; formes, and even individual pages were on occasion
                    ;; shared". A big house really does approach the rapid
                    ;; alternation this program used to do unconditionally.
                    #:stint-sheets [stint #f])
  (house fmt names seed by-formes? cv case-scale acc nsk
         (max 1 standing) prep? title profiles condition
         (cond
           [stint (max 1 stint)]
           [(<= (length names) 3) 4]     ; whole sheets at a time
           [(<= (length names) 5) 2]
           [else 1])))                   ; takes, shared about

(define (house-spec h)
  (page-spec (exact-round (* (book-format-measure-ems (house-fmt h)) UNITS-PER-EM))
             (book-format-lines (house-fmt h))
             0 EM-QUAD))

(define (house-capacity h)
  (* (book-format-lines (house-fmt h)) (book-format-columns (house-fmt h))))

;; ---------------------------------------------------------------------------
;; Composing a page
;; ---------------------------------------------------------------------------

(define (white-line spec)
  (make-line '() '() 0 (page-spec-measure spec) 'blank
             #:justification "white line"))

;; Lay out a segment of copy at a given pressure. No type is picked here, so a
;; trial costs nothing but time.
(define (compose c units spec pressure)
  (define crowded? (> pressure 0.35))
  (define prof (comp-profile c))
  (let loop ([us units] [pending #f] [run-on '()] [out '()])
    (define (flush-run-on out)
      (if (null? run-on)
          out
          (append (reverse (set-prose c (string-join (reverse run-on) " ")
                                      spec pressure #:first-indent? #f))
                  out)))
    (cond
      [(null? us) (reverse (flush-run-on out))]
      [else
       (define u (car us))
       (define rest (cdr us))
       (case (copy-unit-kind u)
         [(blank)
          (define o (flush-run-on out))
          (loop rest pending '()
                (if crowded? o (cons (white-line spec) o)))]

         [(heading)
          (define o (flush-run-on out))
          (define head (reverse (set-heading c (copy-unit-text u) spec)))
          (loop rest pending '()
                (if crowded?
                    (append head o)
                    (cons (white-line spec)
                          (append head (cons (white-line spec) o)))))]

         [(stage)
          (define o (flush-run-on out))
          (loop rest pending '()
                (append (reverse (set-stage-direction c (copy-unit-text u) spec)) o))]

         [(prefix)
          (loop rest (copy-unit-text u) run-on (flush-run-on out))]

         [(verse)
          (define lead (if pending (list (speech-prefix c pending pressure)) '()))
          (cond
            [(and crowded? (profile-normalises-verse? prof) (null? lead)
                  (< (rnd (comp-rng c)) 0.7))
             (loop rest #f (cons (copy-unit-text u) run-on) out)]
            [else
             (define o (flush-run-on out))
             (loop rest #f '()
                   (append (reverse (set-verse c (copy-unit-text u) spec pressure
                                               #:lead lead))
                           o))])]

         [else
          (define lead (if pending (list (speech-prefix c pending pressure)) '()))
          (define o (flush-run-on out))
          (loop rest #f '()
                (append (reverse (set-prose c (copy-unit-text u) spec pressure
                                            #:first-indent? (null? lead)
                                            #:lead lead))
                        o))])])))

;; Bring the page to its depth.
;;
;; White lines are the compositor's coarse adjustment and the first thing he
;; touches: they come out when he is crowded and go in when he is short. Only
;; when the white is gone does the difficulty become visible in the text.
;;
;; A page need not come out to the exact depth of its fellows. Gaskell notes
;; books cast off imperfectly and set by formes in which one side of the sheet
;; has pages of regular length and the other "pages of irregular length ...
;; which had to be made to fit with what had already been set and printed". So
;; a line or two over or under is simply allowed to stand.
(define (fit-page c lines capacity spec by-formes? sig)
  (define slack 2)
  (define (drop-white ls n)
    (let loop ([ls ls] [n n] [out '()])
      (cond
        [(null? ls) (reverse out)]
        [(and (> n 0) (eq? (set-line-kind (car ls)) 'blank))
         (loop (cdr ls) (sub1 n) out)]
        [else (loop (cdr ls) n (cons (car ls) out))])))

  (define n (length lines))
  (cond
    [(and (> n capacity) (<= n (+ capacity slack))) (values lines '() '())]

    [(> n capacity)
     (define trimmed (drop-white lines (- n capacity)))
     (define taken (- n (length trimmed)))
     (when (> taken 0)
       (add-event! c (make-ev 'justification
                              (format "~a white line(s) taken out to save room" taken)
                              sig (comp-profile c))))
     (cond
       [(<= (length trimmed) capacity) (values trimmed '() '())]
       [by-formes?
        ;; There is nowhere to put it. The page belongs to a forme, and the
        ;; copy for the next page belongs to another forme already cast off,
        ;; perhaps already standing in type. So the compositor leaves the
        ;; surplus out and says nothing. This is one of the ways text
        ;; disappears from printed plays.
        (define surplus (- (length trimmed) capacity))
        (add-event! c (make-ev 'justification
                               (format "~a line(s) of copy omitted for want of room"
                                       surplus)
                               sig (comp-profile c)))
        (values (take trimmed capacity) '()
                (for/list ([l (in-list (drop trimmed capacity))]
                           #:unless (null? (set-line-words l)))
                  (line-text l)))]
       [else (values (take trimmed capacity) (drop trimmed capacity) '())])]

    [(< n (sub1 capacity))
     ;; Spin it out: an extra white line wherever there is already one, which
     ;; is where the eye will not resent it.
     (define need (- capacity n))
     (define-values (out added)
       (for/fold ([out '()] [added 0]) ([l (in-list lines)])
         (if (and (eq? (set-line-kind l) 'blank) (< added need))
             (values (cons (white-line spec) (cons l out)) (add1 added))
             (values (cons l out) added))))
     (when (> added 0)
       (add-event! c (make-ev 'justification
                              (format "~a white line(s) put in to fill the page" added)
                              sig (comp-profile c))))
     (values (take (reverse out) (min capacity (length out))) '() '())]

    [else (values lines '() '())]))

(define (make-ev kind detail sig prof)
  (event kind detail sig 0 -1 (profile-name prof) "" ""))

(define (split-columns lines columns per-column)
  (if (<= columns 1)
      (list lines)
      (for/list ([c (in-range columns)])
        (define from (min (length lines) (* c per-column)))
        (define to (min (length lines) (* (add1 c) per-column)))
        (take (drop lines from) (- to from)))))

;; ---------------------------------------------------------------------------
;; Setting the book
;; ---------------------------------------------------------------------------

(define (set-book h copy [copy-kind 'auto])
  (define authors-copy (parse-copy copy copy-kind))
  (define cr (make-corrector #:rng (make-rng (+ (house-seed h) 3))
                             #:active? (house-prepare-copy? h)))
  ;; The copy is prepared to house style before it reaches the frames, so what
  ;; the compositor sets from is already not what the author wrote.
  (define-values (units prepared) (prepare-copy cr authors-copy))

  (define fmt (house-fmt h))
  (define spec (house-spec h))
  (define capacity (house-capacity h))
  (define g (make-rng (house-seed h)))
  (define tc (make-type-case #:scale (house-case-scale h)
                             #:condition (house-condition h)
                             #:rng (make-rng (+ (house-seed h) 1))))
  (define men
    (for/hash ([name (in-list (house-compositor-names h))] [i (in-naturals)])
      (values name
              (make-comp (hash-ref (house-profiles h) name
                                   (lambda ()
                                     (profile name (hash) 1.0 0.01 0.006 0.5
                                              #f 0.85 #f "an unknown workman")))
                         tc (house-conventions h)
                         (make-rng (+ (house-seed h) (* 7 i)))))))
  (define order (house-compositor-names h))

  ;; How many leaves of a gathering each man signs.
  ;;
  ;; Signing is the compositor's own act, not the imposer's: McKerrow finds
  ;; that the men "normally finished a page of work at a time, adding catchword
  ;; and signature (if necessary) before proceeding to the next one". And the
  ;; count was not fixed -- "there cannot be said to have been in early times
  ;; any definite practice ... we may have anything from the first two to every
  ;; leaf". Hinman saw the same inconsistency at Jaggard's, where in a quarto
  ;; one man might sign the first two leaves and another the first three.
  ;;
  ;; So the practice varies by the man. Which man signed how many, neither
  ;; source says, and assigning particular counts to Hinman's A and B would be
  ;; manufacturing evidence of exactly the kind this program is supposed to
  ;; test. The count is therefore drawn per workman from the run's seed: the
  ;; phenomenon is attested, the attribution is not.
  (define signs-for
    (for/hash ([name (in-list order)] [i (in-naturals)])
      (define base (signed-leaves fmt))
      (define gg (make-rng (+ (house-seed h) 3001 (* 13 i))))
      (values name
              (max 1 (min (book-format-leaves fmt)
                          (+ base (if (< (rnd gg) 0.4) 1 0)))))))

  (define segments0
    (cast-off units (page-spec-measure spec) capacity g (house-cast-off-accuracy h)))
  (define n-pages (length segments0))
  (define gatherings
    (max 1 (quotient (+ n-pages (sub1 (book-format-pages fmt)))
                     (book-format-pages fmt))))
  (define segments
    (append segments0
            (for/list ([i (in-range (- (* gatherings (book-format-pages fmt))
                                       n-pages))])
              (cast-off-segment (+ n-pages i) '() 0 "blank"))))

  (define skeletons
    (make-skeletons (house-n-skeletons h)
                    (max 2 (quotient (book-format-pages fmt) 2))
                    (house-title h) g))

  (define all-formes '())
  (define pages (make-hash))
  (define stint-log '())
  (define forme-counter 0)
  (define forme-pages (make-hash))
  (define standing '())

  ;; The ledger of standing type. A page cannot be distributed until the whole
  ;; forme it belongs to is at press, and in a folio in sixes the outer forme
  ;; of the first sheet holds pages 1 and 12 -- eleven pages apart in the copy.
  ;; So a house setting seriatim must keep the best part of a gathering
  ;; standing before it can print anything at all, while a house setting by
  ;; formes from the middle outward can print and distribute a sheet at a time.
  ;; That difference is arithmetic about the practice, not evidence of it:
  ;; McKenzie found setting by formes "was followed occasionally but was
  ;; certainly not normal" (i. 115). This counts what it would have saved.
  ;; Who is at the frame, forme by forme.
  ;;
  ;; Not a rotation. A man takes over where the last left off and sets as many
  ;; sheets as the master finds convenient, so the plan is a run of long
  ;; contiguous blocks with the occasional single sheet where somebody was
  ;; briefly free. The boundaries fall where the shop's other commitments put
  ;; them, which is why McKenzie says the compositorial pattern within a book
  ;; "will rarely have any internal significance" (i. 107) -- it records the
  ;; house's other work, not anything about this book.
  (define stint-plan (make-hash))
  (define plan-filled (box 0))
  (define plan-last (box -1))
  (define (man-for-forme i)
    (cond
      [(= (length order) 1) (car order)]
      [else
       (let extend ()
         (when (>= i (unbox plan-filled))
           ;; a stint is a whole number of sheets: mostly several, now and then
           ;; a single one, as Delie set only 4G of the quarto Virgil
           (define sheets
             (if (< (rnd g) 0.18)
                 1
                 (max 1 (exact-round (* 2 (house-stint-sheets h)
                                        (rnd-beta g 2.0 2.0))))))
           (define len (* 2 sheets))     ; two formes to a sheet
           ;; the man who takes over is whoever is free, not the next in turn
           (define pick
             (let loop ()
               (define k (rnd-int g (length order)))
               (if (= k (unbox plan-last)) (loop) k)))
           (for ([j (in-range (unbox plan-filled) (+ (unbox plan-filled) len))])
             (hash-set! stint-plan j (list-ref order pick)))
           (set-box! plan-filled (+ (unbox plan-filled) len))
           (set-box! plan-last pick)
           (extend)))
       (hash-ref stint-plan i)]))

  (define standing-sorts 0)
  (define peak-sorts 0)
  (define peak-pages 0)
  (define pages-standing 0)
  (define ledger '())
  (define (sorts-in pg)
    (for/sum ([ch (in-string (page-text pg))])
      (if (char-whitespace? ch) 0 1)))

  (for ([gathering (in-range gatherings)])
    (define refs
      (for/hash ([r (in-list (page-refs fmt gathering))])
        (values (page-ref-number r) r)))
    (define formes (formes-for-gathering fmt gathering))
    (define page->forme
      (for*/hash ([fm (in-list formes)] [p (in-list (forme-page-numbers fm))])
        (values p fm)))

    (for ([fm (in-list formes)])
      (define sk (list-ref skeletons (modulo forme-counter (length skeletons))))
      (define sk*
        (if (and (> (length skeletons) 1) (< (rnd g) 0.12))
            (list-ref skeletons (modulo (add1 forme-counter) (length skeletons)))
            sk))
      (set-forme-skeleton! fm sk*)
      (set-forme-order! fm forme-counter)
      (skeleton-add-use! sk* (forme-name fm))
      (set! forme-counter (add1 forme-counter)))
    (set! all-formes (append all-formes formes))

    (let page-loop ([ps (setting-order fmt gathering (house-by-formes? h))]
                    [pos 0] [carry '()])
      (unless (null? ps)
        (define page-no (car ps))
        (define seg-index (+ (* gathering (book-format-pages fmt)) (sub1 page-no)))
        (cond
          [(>= seg-index (length segments)) (void)]
          [else
           (define seg (list-ref segments seg-index))
           (define r (hash-ref refs page-no))
           (define fm (hash-ref page->forme page-no))
           ;; The stint plan is indexed by forme when the house sets by formes,
           ;; and by sheet-worth-of-pages when it sets seriatim; either way a
           ;; man holds on for several sheets together.
           (define man
             (hash-ref men
                       (man-for-forme
                        (if (house-by-formes? h)
                            (forme-order fm)
                            (+ (* gathering (book-format-pages fmt)) pos)))))
           (define units-for-page (append carry (cast-off-segment-units seg)))
           (define-values (pg leftover)
             (set-page h man units-for-page r fm spec capacity
                       (hash-ref signs-for (profile-name (comp-profile man))
                                 (signed-leaves fmt))))
           (hash-set! pages (cons gathering page-no) pg)
           (set! stint-log (cons (cons (profile-name (comp-profile man))
                                       (page-ref-signature r))
                                 stint-log))

           ;; When a forme is finished it goes to press; when the house has
           ;; more formes standing than it can afford, the oldest is printed
           ;; off and its type distributed back into the cases.
           (hash-update! forme-pages (forme-name fm)
                         (lambda (xs) (append xs (list pg))) '())

           ;; the page is now standing in type and stays so until its forme
           ;; is printed off
           (set! standing-sorts (+ standing-sorts (sorts-in pg)))
           (set! pages-standing (add1 pages-standing))
           (when (> standing-sorts peak-sorts)
             (set! peak-sorts standing-sorts)
             (set! peak-pages pages-standing))
           (set! ledger (cons (list (page-ref-signature r) page-no
                                    pages-standing standing-sorts)
                              ledger))

           (when (= (length (hash-ref forme-pages (forme-name fm)))
                    (length (forme-page-numbers fm)))
             (set! standing (append standing (list (forme-name fm))))
             (let dist ()
               (when (> (length standing) (house-formes-standing h))
                 (define printed (car standing))
                 (set! standing (cdr standing))
                 (for ([p (in-list (hash-ref forme-pages printed '()))])
                   (set! standing-sorts (- standing-sorts (sorts-in p)))
                   (set! pages-standing (sub1 pages-standing))
                   (distribute! tc (page-text p))
                   ;; the identifiable types go back to their own boxes and
                   ;; may be picked again for a later forme
                   (distribute-pieces!
                    tc (for*/list ([l (in-list (page-all-lines p))]
                                   [w (in-list (set-line-words l))]
                                   [pr (in-list (word-pieces w))])
                         (cdr pr))))
                 ;; and a few sound sorts are battered at press each time
                 (batter! tc 2)
                 (dist))))

           (page-loop (cdr ps) (add1 pos)
                      (if (house-by-formes? h) '() leftover))]))))

  (define ordered
    (for*/list ([gathering (in-range gatherings)]
                [p (in-range 1 (add1 (book-format-pages fmt)))]
                #:when (hash-has-key? pages (cons gathering p)))
      (hash-ref pages (cons gathering p))))

  (define with-catchwords (add-catchwords ordered))
  (define with-titles (add-running-titles with-catchwords all-formes fmt))

  (book with-titles all-formes skeletons fmt
        (append* (for/list ([name (in-list order)])
                   (comp-event-list (hash-ref men name))))
        (compress-stints (reverse stint-log))
        tc (house-title h) units authors-copy prepared
        (standing-type peak-sorts peak-pages (reverse ledger)
                       (house-by-formes? h))))

;; ---------------------------------------------------------------------------

(define (set-page h man units r fm spec capacity signs)
  (define sig (page-ref-signature r))
  (define has-copy?
    (for/or ([u (in-list units)]) (not (eq? (copy-unit-kind u) 'blank))))

  ;; A trial setting, to find out whether the casting off was any good. It
  ;; costs no type, because the sorts are not picked until the page is settled.
  (define mark (length (unbox (comp-events man))))
  (define trial (compose man units spec 0.0))
  (set-box! (comp-events man)
            (list-tail (unbox (comp-events man))
                       (- (length (unbox (comp-events man))) mark)))

  (define overflow (- (length trial) capacity))
  (define pressure0
    (if (zero? capacity) 0.0 (max -1.0 (min 1.5 (* 3.0 (/ overflow (exact->inexact capacity)))))))
  (define pressure (if (or (<= (abs overflow) 2) (not has-copy?)) 0.0 pressure0))

  (define note
    (cond
      [(> overflow 2)
       (format "copy cast off short by about ~a lines; the page is crowded" overflow)]
      [(< overflow -2)
       (format "copy cast off long by about ~a lines; the page is spun out"
               (- overflow))]
      [else ""]))

  (define lines0 (compose man units spec pressure))
  (unless (zero? pressure)
    (add-event! man (make-ev 'justification
                             (format "~a (pressure ~a)"
                                     (if (string=? note "") "page reset to fit" note)
                                     (real->decimal-string pressure 2))
                             sig (comp-profile man))))

  (define-values (lines leftover omitted)
    (fit-page man lines0 capacity spec (house-by-formes? h) sig))

  ;; pick the sorts for what actually stands in the forme
  (define picked
    (for/list ([l (in-list lines)] [i (in-naturals 1)])
      (pick-line! man l sig i)))

  (values (page r
                (split-columns picked (book-format-columns (house-fmt h))
                               (book-format-lines (house-fmt h)))
                (profile-name (comp-profile man))
                #f ""
                (if (and (page-ref-recto? r)
                         (<= (page-ref-leaf r) signs))
                    (page-ref-signed r) "")
                pressure note (forme-name fm) omitted)
          (if (null? leftover) '() (leftover-units man units spec capacity))))

;; Which units of copy did not fit, for carrying to the next page when the
;; house is setting seriatim. Composing a unit at a time to find the cut is
;; wasteful but exact, and the trial is rolled back so that it leaves no trace
;; in the record of composition.
(define (leftover-units c units spec capacity)
  (define mark (length (unbox (comp-events c))))
  (define result
    (let loop ([us units] [taken 0])
      (cond
        [(null? us) '()]
        [else
         (define n (length (compose c (list (car us)) spec 0.0)))
         (if (> (+ taken n) capacity) us (loop (cdr us) (+ taken n)))])))
  (define evs (unbox (comp-events c)))
  (set-box! (comp-events c) (list-tail evs (- (length evs) mark)))
  result)

(define (add-catchwords pages)
  (for/list ([p (in-list pages)] [i (in-naturals)])
    (cond
      [(>= (add1 i) (length pages)) p]
      [else
       (define nxt (list-ref pages (add1 i)))
       (define first-word
         (for/or ([l (in-list (page-all-lines nxt))])
           (and (pair? (set-line-words l))
                (word-printed (car (set-line-words l))))))
       (struct-copy page p [catchword (or first-word "")])])))

(define (add-running-titles pages formes fmt)
  (define by-key
    (for*/hash ([fm (in-list formes)] [p (in-list (forme-page-numbers fm))])
      (values (cons (forme-gathering fm) p) fm)))
  (define counters (make-hash))
  (for/list ([p (in-list pages)])
    (define r (page-pref p))
    (define fm (hash-ref by-key (cons (page-ref-gathering r) (page-ref-number r)) #f))
    (cond
      [(or (not fm) (not (forme-skeleton fm))) p]
      [else
       (define sk (forme-skeleton fm))
       (define k (hash-ref counters (skeleton-name sk) 0))
       (hash-set! counters (skeleton-name sk) (add1 k))
       (struct-copy page p [running-title (title-for sk k)])])))

(define (compress-stints log)
  (let loop ([xs log] [out '()])
    (cond
      [(null? xs) (reverse out)]
      [(and (pair? out) (string=? (car (car out)) (car (car xs))))
       (loop (cdr xs) (cons (list (car (car out)) (cadr (car out)) (cdr (car xs)))
                            (cdr out)))]
      [else (loop (cdr xs) (cons (list (car (car xs)) (cdr (car xs)) (cdr (car xs)))
                                 out))])))

(module+ test
  (require rackunit)

  (define sample
    (string-append
     "Enter King and Queen.\n\n"
     "King. And can you by no drift of conference\n"
     "Get from him why he puts on this confusion,\n"
     "Grating so harshly all his days of quiet\n"
     "With turbulent and dangerous lunacy?\n\n"
     "Queen. Did he receive you well?\n\n"
     "King. Most like a gentleman, and with much forcing of his disposition, "
     "niggard of question, but of our demands most free in his reply.\n"))

  (define h (make-house #:fmt QUARTO #:compositors '("A" "B") #:seed 1623))
  (define b (set-book h sample))

  (check-true (> (length (book-pages b)) 0))
  (check-regexp-match #px"^4°: A⁴" (book-collation b))

  ;; No line anywhere overhangs its measure. `make-line' would have raised,
  ;; so reaching here at all is the check; assert it explicitly anyway.
  (for* ([p (in-list (book-pages b))] [l (in-list (page-all-lines p))])
    (check-true (<= (line-set-width l) (set-line-measure l))))

  ;; Every word of the prepared copy is standing in type, or accounted for.
  (define wanted
    (for*/fold ([h (hash)]) ([u (in-list (book-copy-units b))]
                             #:unless (memq (copy-unit-kind u) '(blank prefix))
                             [w (in-list (string-split (copy-unit-text u)))])
      (hash-update h w add1 0)))
  (define got
    (for*/fold ([h (hash)]) ([p (in-list (book-pages b))]
                             [l (in-list (page-all-lines p))]
                             [w (in-list (set-line-words l))]
                             #:unless (for/or ([c (in-list (word-causes w))])
                                        (regexp-match? #px"prefix|second half" c)))
      (hash-update h (word-copy w) add1 0)))
  (define eyeskipped
    (for/sum ([e (in-list (book-events b))]
              #:when (and (eq? (event-kind e) 'copy)
                          (regexp-match? #px"eye returned" (event-detail e))))
      (length (string-split (event-before e)))))
  (define dropped
    (for*/sum ([p (in-list (book-pages b))] [t (in-list (page-omitted p))])
      (length (string-split t))))
  (define missing
    (for/sum ([(w n) (in-hash wanted)])
      (max 0 (- n (hash-ref got w 0)))))
  (check-equal? (- missing eyeskipped dropped) 0
                "every word is in type or explained by a recorded event")

  ;; Catchwords match the first word of the following page.
  (for ([p (in-list (book-pages b))] [i (in-naturals)]
        #:when (< (add1 i) (length (book-pages b))))
    (define nxt (list-ref (book-pages b) (add1 i)))
    (define first-word
      (for/or ([l (in-list (page-all-lines nxt))])
        (and (pair? (set-line-words l)) (word-printed (car (set-line-words l))))))
    (when (and first-word (not (string=? (page-catchword p) "")))
      (check-equal? (page-catchword p) first-word
                    (format "catchword on ~a" (page-sig p))))))
