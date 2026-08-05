#lang racket/base
;;; At press: proof-correction in the middle of the run, and its consequences.
;;;
;;; The press does not stop for a proof. A forme is made ready, the run
;;; begins, and a proof-sheet is pulled and read while the pressmen carry on.
;;; When the corrector sends his marked proof back the forme is unlocked, the
;;; faulty letters are replaced, and the run continues. The sheets already
;;; printed are not thrown away -- paper was the largest cost in the shop --
;;; so they go into the heap with the rest.
;;;
;;; Every corrected forme therefore exists in two states, and since the heaps
;;; were gathered at random when the book was made up, no two copies of the
;;; edition need agree.
;;;
;;; How the corrector worked is a question with two answers, and this module
;;; used to give only one of them.
;;;
;;; Moxon describes the proper method: the master-printer appoints someone
;;; "well skill'd in true and quick Reading, to Read the Copy" aloud while the
;;; corrector follows the proof. On that method the copy is present throughout
;;; and a misreading is as catchable as a turned letter.
;;;
;;; Hinman found the Folio was not corrected that way. Its variants are mostly
;;; obvious blunders, and "the copy was in all probability seldom if ever used
;;; to correct perfectly obvious mistakes that could easily enough, in the
;;; light provided by the immediate context, be made to yield sense". But
;;; seldom is not never, and he can point to the corrections that prove it: a
;;; two-line speech restored on d5 that "cannot have been restored save by
;;; reference to the copy", and a line on vv3 bearing no resemblance to what
;;; it replaced.
;;;
;;; So the corrector here works from sense, and now and then calls for the
;;; copy. The distinction matters because the two methods fail differently:
;;; sense catches foul case and leaves a plausible misreading standing, while
;;; the copy catches the omission that sense cannot even see.
;;;
;;; Hinman also noticed the consequence of a scare. Having consulted the copy
;;; and discovered a considerable omission, the reader grew "somewhat more
;;; careful ... at least for a time" -- so a serious catch raises vigilance,
;;; and the vigilance decays.
;;;
;;; And he sometimes made it worse, introducing a reading that is neither the
;;; author's nor the compositor's: at one place a compositor's error was
;;; rightly noticed and then "corrected" to something plausible and wrong.
;;;
;;; And one from Carter: a proof pulled and mended *before* the run leaves no
;;; variant at all. So the catalogue of press variants, however many copies
;;; are collated, records only the corrections made too late.

(require racket/list racket/string racket/math racket/set
         "compositor.rkt" "book.rkt" "imposition.rkt" "binding.rkt" "cancels.rkt"
         "rng.rkt" "lexicon.rkt"
         (only-in "orthography.rkt" split-point))

(provide (struct-out pvariant) (struct-out forme-state)
         (struct-out printed-copy) (struct-out press-run)
         run-press copy-reading-map collate run-variants
         forme-state-corrected? book-quires)

;; Plausible sophistications: what a corrector puts in when he decides a
;; perfectly good reading must be wrong.
(define sophistications
  (hash "thou" "you" "vnto" "to" "whiles" "while"
        "betwixt" "between" "burthen" "burden" "murther" "murder"
        "vilde" "vile" "moe" "more" "shew" "show"))

(struct pvariant (forme page line word uncorrected corrected note) #:transparent)

(struct forme-state (forme proofed? fraction-uncorrected variants silent)
  #:transparent)

(define (forme-state-corrected? s)
  (and (forme-state-proofed? s) (pair? (forme-state-variants s))))

;; One physical copy of the book, made up from the heaps.
;; `states' maps forme-name -> #t if this copy has the corrected state.
(struct printed-copy (name states binding) #:transparent)

;; The gatherings as they reach the warehouse table, with the count of leaves
;; that actually carry a signature -- taken from what was set, not from what
;; was intended, because the whole use of the figure is that a gathering with
;; nothing in its direction line is the one the binder puts in backwards.
(define (book-quires b)
  (for/list ([plan (in-list (book-plans b))])
    (define ps (for/list ([p (in-list (book-pages b))]
                          #:when (= (page-ref-gathering (page-pref p))
                                    (gathering-plan-place plan)))
                 p))
    (quire (series-mark (gathering-plan-series plan) (gathering-plan-index plan))
           (gathering-plan-leaves plan)
           (for/sum ([p (in-list ps)])
             (if (string=? (page-signature p) "") 0 1)))))

(struct press-run (states copies events silent-readings edition binding-error
                          cancels)
  #:transparent)

(define (run-variants r)
  (append* (for/list ([(k s) (in-hash (press-run-states r))])
             (forme-state-variants s))))

;; The corrector improving something that was not wrong.
;;
;; He must improve it into a spelling somebody used. This device was left
;; ungated when the compositor's were fixed, and it showed: it was turning
;; `begin' into `begine', `after' into `aftere' and `opinion' into `opinione',
;; and printing them in the list of press variants as though a real corrector
;; had made them. A reader who alters a word alters it towards a form he has
;; seen, not towards one no one ever set.
(define (sophisticate word g)
  (define low (string-downcase (string-trim word ".,;:!?" #:repeat? #t)))
  (define (ok form)
    (and form
         (not (string=? form word))
         (let-values ([(core _t) (split-point (string-downcase form))])
           (or (not (regexp-match? #px"^[a-zſ']+$" core))
               (plausible? core)))
         form))
  (or (and (hash-has-key? sophistications low)
           (ok (string-replace word low (hash-ref sophistications low))))
      (and (> (string-length low) 4) (string-suffix? low "e")
           (ok (string-replace word low (substring low 0 (sub1 (string-length low))))))
      (and (> (string-length low) 3)
           (ok (string-replace word low (string-append low "e"))))
      #f))

(define (run-press b
                   #:copies [copies 4]
                   #:seed [seed 1623]
                   #:proof-rate [proof-rate 0.6]
                   #:catches-accident [catches-accident 0.75]
                   #:catches-misreading [catches-misreading 0.10]
                   ;; How often the reader calls for the copy rather than
                   ;; working by sense alone. Low, because Hinman's Folio is
                   ;; the case being modelled and its correction was mostly
                   ;; done without it -- but not zero, because he can name the
                   ;; places where the copy must have been at the reader's
                   ;; elbow. Set it to 1.0 for a house following Moxon's
                   ;; method, where the copy is read aloud throughout.
                   #:consults-copy [consults-copy 0.12]
                   #:sophisticates [sophisticates 0.16]
                   #:first-proof [first-proof 0.0]
                   ;; Faults per gathering per copy at the folding and sewing.
                   ;; No source gives one; see binding.rkt, which says so at
                   ;; length and prints the disclaimer beside every fault.
                   #:binding-error [binding-error BINDING-ERROR-RATE]
                   ;; How often an error that survived the proof is thought
                   ;; worth cutting a leaf out for. Zero by default: a cancel
                   ;; is a deliberate and expensive act, and this program does
                   ;; not know how grave an error has to be before a shop
                   ;; committed it.
                   #:cancel-rate [cancel-rate 0.0]
                   ;; Leaves cancelled for reasons outside the simulation --
                   ;; the Privy Council, a withdrawn dedication. A count, not
                   ;; a model. See cancels.rkt.
                   #:cancels [external-cancels 0]
                   #:imprint-change? [imprint-change? #f]
                   #:edition [edition 750])
  (define g (make-rng (+ seed 99)))

  (define pages-by-forme (make-hash))
  (for ([p (in-list (book-pages b))])
    (hash-update! pages-by-forme (page-forme-name p)
                  (lambda (xs) (append xs (list p))) '()))

  ;; accidents are locatable in the standing type; misreadings are not
  (define events-by-page (make-hash))
  (for ([e (in-list (book-events b))])
    (when (and (not (string=? (event-page e) "")) (>= (event-word e) 0))
      (hash-update! events-by-page (event-page e)
                    (lambda (xs) (append xs (list e))) '())))

  (define states (make-hash))
  (define log '())
  (define silent-readings (make-hash))
  ;; raised when consulting the copy turns up a real corruption, and spent on
  ;; the next forme -- Hinman's reader, who grew more careful "at least for a
  ;; time" after finding a considerable omission
  (define vigilant (box #f))

  (define (locate p e)
    (define lines (page-all-lines p))
    (and (< (sub1 (event-line e)) (length lines))
         (let ([l (list-ref lines (sub1 (event-line e)))])
           (and (< (event-word e) (length (set-line-words l)))
                (list-ref (set-line-words l) (event-word e))))))

  (for ([(forme-name pages) (in-hash pages-by-forme)])
    ;; Proof-reading was not spread evenly. Hinman found it "in considerable
    ;; measure confined to some six or eight plays in one section of the book,
    ;; and especially to material set by a particular compositor" (i. 227) --
    ;; and the prentice hand E was proof-read as a matter of course.
    (define rate
      (if (for/or ([p (in-list pages)]) (string=? (page-compositor p) "E"))
          (min 0.97 (* proof-rate 1.9))
          proof-rate))

    (cond
      ;; A proof pulled and mended before the pressmen begin. The type is put
      ;; right and the edition is uniform, so the correction is invisible
      ;; afterwards -- it can only be counted here, where we are cheating.
      [(< (rnd g) first-proof)
       (define silent
         (for*/sum ([p (in-list pages)]
                    [e (in-list (hash-ref events-by-page (page-sig p) '()))]
                    #:when (eq? (event-kind e) 'accident))
           (define w (locate p e))
           (cond
             [(and w (< (rnd g) catches-accident))
              (hash-set! silent-readings
                         (list (page-sig p) (event-line e) (event-word e))
                         (word-composed w))
              1]
             [else 0])))
       (when (> silent 0)
         (set! log (cons (event 'press
                                (format "~a literal(s) mended before the run; no variant survives"
                                        silent)
                                (page-sig (car pages)) 0 -1 "" "" "")
                         log)))
       (hash-set! states forme-name (forme-state forme-name #t 1.0 '() silent))]

      [(not (< (rnd g) rate))
       (hash-set! states forme-name (forme-state forme-name #f 1.0 '() 0))]

      [else
       ;; How much of the run was worked off before the marked proof came
       ;; back. The press did not stop for it: at three or four impressions a
       ;; minute and fifteen to thirty minutes for the reader, some 60 to 120
       ;; sheets were printed before the corrected forme went back on.
       ;;
       ;; The proportion that represents depends entirely on the edition, and
       ;; here Hinman's Folio is atypical. His 1,200 gives 5 to 10 per cent;
       ;; but the Cambridge Press accounts for 1711-12 record editions of 400
       ;; (Peck), 600 (Theophrastus), 700 (Newton's Principia), 750 (Thirlby)
       ;; and 820 (Pycroft). At 400 the same 60 to 120 sheets are 15 to 30 per
       ;; cent of the whole. So the fraction is derived from the edition size
       ;; rather than fixed, with a tail for the times the reader was slow to
       ;; begin at all.
       (define early (rnd-uniform g 60.0 120.0))
       (define slow (if (< (rnd g) 0.15) (rnd-uniform g 1.5 4.0) 1.0))
       (define fraction (min 0.65 (/ (* early slow) (max 100 edition))))
       (define variants '())

       ;; Is the copy at the reader's elbow for this forme? `vigilant' carries
       ;; over from a forme where consulting it turned up something serious.
       (define with-copy?
         (or (unbox vigilant) (< (rnd g) consults-copy)))
       (set-box! vigilant #f)

       (for ([p (in-list pages)])
         (for ([e (in-list (hash-ref events-by-page (page-sig p) '()))])
           (define w (locate p e))
           (define threshold
             (cond
               ;; foul case and turned letters are visible on the page itself,
               ;; so the copy adds little
               [(eq? (event-kind e) 'accident) catches-accident]
               ;; a misreading yields sense and hides from a reader working by
               ;; sense. Against the copy, read aloud, it has nowhere to hide.
               [with-copy? (max catches-misreading 0.80)]
               [else catches-misreading]))
           ;; What the reader can put back depends on what he is reading
           ;; against. A literal is wrong on the page, so the standing type
           ;; shows it and the composed reading restores it. A misreading is
           ;; not wrong on the page at all -- it is wrong against the copy --
           ;; so only the copy can supply what should have stood there. This
           ;; is why a corrector working by sense leaves misreadings behind
           ;; however careful he is: he has nothing to catch them with.
           (define restored
             (and w
                  (cond
                    [(eq? (event-kind e) 'accident)
                     (and (not (string=? (word-printed w) (word-composed w)))
                          (word-composed w))]
                    [with-copy?
                     (and (word-copy w)
                          (not (string=? (word-printed w) (word-copy w)))
                          (word-copy w))]
                    [else #f])))
           (when (and restored (< (rnd g) threshold))
             ;; the scare: having found a real corruption against the copy,
             ;; the reader is more careful for a while
             (when (and with-copy? (eq? (event-kind e) 'copy) (< (rnd g) 0.5))
               (set-box! vigilant #t))
             (set! variants
                   (cons (pvariant forme-name (page-sig p) (event-line e)
                                   (event-word e) (word-printed w) restored
                                   (if (eq? (event-kind e) 'accident)
                                       (format "literal corrected at press (~a)"
                                               (event-detail e))
                                       (format "reading restored from the copy (~a)"
                                               (event-detail e))))
                         variants))))

         ;; Misreadings have to be found on the page rather than in the event
         ;; log. They are recorded at the moment the compositor reads his copy,
         ;; before the word is placed, so they carry no page, line or word and
         ;; the loop above never sees them -- which meant that until this was
         ;; noticed no misreading was correctable at press by any method, and
         ;; `catches-misreading' did nothing whatever.
         ;;
         ;; The word itself is evidence enough: the copy said one thing and the
         ;; compositor read another. Habitual respelling does not show here,
         ;; because habit acts after reading and leaves `read' alone.
         (when with-copy?
           (for ([l (in-list (page-all-lines p))] [li (in-naturals 1)])
             (for ([w (in-list (set-line-words l))] [wi (in-naturals)])
               ;; A divided word is not a misreading. Both halves keep the
               ;; whole word as their copy reading, so `pri-' and `nce' would
               ;; otherwise look like corruptions of `prince' and get
               ;; "restored" into a line that has no room for them.
               (when (and (word-copy w) (word-read w)
                          (not (ormap (lambda (c) (regexp-match? #rx"divided" c))
                                      (word-causes w)))
                          (not (string=? (word-copy w) (word-read w)))
                          (not (string=? (word-printed w) (word-copy w)))
                          (< (rnd g) (max catches-misreading 0.80)))
                 (when (< (rnd g) 0.5) (set-box! vigilant #t))
                 (set! variants
                       (cons (pvariant forme-name (page-sig p) li wi
                                       (word-printed w) (word-copy w)
                                       (format "reading restored from the copy: ~s for ~s"
                                               (word-copy w) (word-printed w)))
                             variants))))))

         ;; and now the corrector improves something that was not wrong
         (define lines (page-all-lines p))
         (when (and (< (rnd g) sophisticates) (pair? lines))
           (define li (rnd-int g (length lines)))
           (define l (list-ref lines li))
           (when (pair? (set-line-words l))
             (define wi (rnd-int g (length (set-line-words l))))
             (define w (list-ref (set-line-words l) wi))
             (define new (sophisticate (word-printed w) g))
             (when (and new (not (string=? new (word-printed w))))
               (set! variants
                     (cons (pvariant forme-name (page-sig p) (add1 li) wi
                                     (word-printed w) new
                                     (format "corrector's sophistication; the copy read ~s"
                                             (word-copy w)))
                           variants))))))

       (hash-set! states forme-name
                  (forme-state forme-name #t fraction (reverse variants) 0))]))

  ;; The sheets are gathered, collated, folded and sewn -- and every copy is
  ;; folded separately, so this is where the copies stop being interchangeable.
  (define quires (book-quires b))
  (define made
    (for/list ([i (in-range copies)])
      (define nm (format "Copy ~a" (integer->char (+ (char->integer #\A) i))))
      (printed-copy
       nm
       (for/hash ([(name s) (in-hash states)])
         (values name
                 (and (forme-state-corrected? s)
                      (> (rnd g) (forme-state-fraction-uncorrected s)))))
       (bind quires #:name nm #:rate binding-error
             #:rng (make-rng (+ seed 9001 (* 31 i)))))))

  ;; What was cut out and replaced. The errors offered as candidates are the
  ;; ones this run made itself and its own corrector let through, which is the
  ;; only cause that needs nothing supplied from outside.
  (define (leaf-of p)
    (define sig (page-sig p))
    (substring sig 0 (sub1 (string-length sig))))
  (define surviving
    (for*/list ([p (in-list (book-pages b))]
                [l (in-list (page-all-lines p))]
                [w (in-list (set-line-words l))]
                #:unless (string=? (word-composed w) (word-printed w)))
      (cons (leaf-of p) (format "the case gave ~s for ~s"
                                 (word-printed w) (word-composed w)))))
  ;; A cancellans is a leaf, so the white paper it can be printed on has to be
  ;; a leaf blank on both sides -- not merely a blank page, whose other side is
  ;; very likely printed. Named by the leaf, in the form a collation uses.
  (define blank-pages
    (for/set ([p (in-list (book-pages b))]
              #:when (for/and ([l (in-list (page-all-lines p))])
                       (null? (set-line-words l))))
      (page-sig p)))
  (define white
    (remove-duplicates
     (for/list ([p (in-list (book-pages b))]
                #:when (and (page-ref-recto? (page-pref p))
                            (set-member? blank-pages (page-sig p))
                            (set-member? blank-pages
                                         (string-append
                                          (substring (page-sig p) 0
                                                     (sub1 (string-length (page-sig p))))
                                          "v"))))
       (substring (page-sig p) 0 (sub1 (string-length (page-sig p)))))))
  (define cancels
    (plan-cancels (for/list ([p (in-list (book-pages b))])
                    (cons (leaf-of p)
                          (for/or ([l (in-list (page-all-lines p))])
                            (pair? (set-line-words l)))))
                  #:errors surviving
                  #:white white
                  #:rate cancel-rate
                  #:external external-cancels
                  #:imprint-change? imprint-change?
                  #:title-leaf (and (book-titlepage b)
                                    (pair? (book-pages b))
                                    (leaf-of (car (book-pages b))))
                  #:rng (make-rng (+ seed 7331))))

  (press-run states made (reverse log) silent-readings edition binding-error
             cancels))

;; The readings actually shown by one copy: the silent corrections, which
;; every copy has, plus whichever state of each variant forme it was made up
;; from.
(define (copy-reading-map pc r)
  (define out (hash-copy (press-run-silent-readings r)))
  (for ([(name corrected?) (in-hash (printed-copy-states pc))])
    (define s (hash-ref (press-run-states r) name #f))
    (when s
      (for ([v (in-list (forme-state-variants s))])
        (hash-set! out (list (pvariant-page v) (pvariant-line v) (pvariant-word v))
                   (if corrected? (pvariant-corrected v) (pvariant-uncorrected v))))))
  out)

;; Superimpose two copies and report where the page moves. This is what the
;; Hinman collator does mechanically.
(define (collate r a bcopy)
  (define ma (copy-reading-map a r))
  (define mb (copy-reading-map bcopy r))
  (define keys (remove-duplicates (append (hash-keys ma) (hash-keys mb))))
  (sort
   (for/list ([k (in-list keys)]
              #:unless (equal? (hash-ref ma k #f) (hash-ref mb k #f)))
     (list (format "~a, l.~a" (car k) (cadr k))
           (or (hash-ref ma k #f) "")
           (or (hash-ref mb k #f) "")))
   string<? #:key car))

(module+ test
  (require rackunit "imposition.rkt")

  (define sample
    (string-append
     "King. And can you by no drift of conference\n"
     "Get from him why he puts on this confusion,\n"
     "Grating so harshly all his days of quiet\n"
     "With turbulent and dangerous lunacy?\n\n"
     "Queen. Did he receive you well?\n"))

  (define b (set-book (make-house #:fmt QUARTO #:seed 1623) sample))
  (define r (run-press b #:copies 6 #:seed 1623 #:proof-rate 1.0))

  ;; The copy at the reader's elbow catches a different class of error.
  ;;
  ;; A misreading yields sense, so a reader working by sense alone has no
  ;; reason to stop at it; read against the copy it has nowhere to hide. Over
  ;; a long text the two methods should therefore mend a measurably different
  ;; number of readings, and it is the misreadings that move.
  ;; Misreadings are rare, so this asserts the invariant rather than a count:
  ;; a reader working by sense can never restore a copy reading, because he
  ;; has not got the copy. The prentice hand E misreads often enough to give
  ;; the other branch something to find.
  (let ()
    (define long-text
      (apply string-append (for/list ([i (in-range 60)]) sample)))
    (define bb (set-book (make-house #:fmt QUARTO #:seed 11 #:compositors '("E"))
                         long-text))
    (define (restorations consults)
      (define rr (run-press bb #:copies 2 #:seed 11 #:proof-rate 1.0
                            #:consults-copy consults))
      (for*/sum ([(nm s) (in-hash (press-run-states rr))]
                 [v (in-list (forme-state-variants s))]
                 #:when (regexp-match? #rx"restored from the copy"
                                       (pvariant-note v)))
        1))
    (check-equal? (restorations 0.0) 0
                  "a reader without the copy cannot restore a copy reading")
    (check-true (> (restorations 1.0) 0)
                "a reader with the copy at his elbow can"))

  ;; Every corrected forme was corrected early in the run, as the arithmetic
  ;; of a 1,200-sheet edition requires.
  (for ([(name s) (in-hash (press-run-states r))]
        #:when (forme-state-corrected? s))
    (check-true (< (forme-state-fraction-uncorrected s) 0.66)
                "uncorrected states are a minority of the edition"))

  ;; A copy is made up independently forme by forme, so two copies may differ.
  (check-equal? (length (press-run-copies r)) 6)

  ;; Collating a copy against itself finds nothing.
  (check-equal? (collate r (first (press-run-copies r)) (first (press-run-copies r)))
                '())

  ;; Corrections made before the run leave no variant to collate. Set by the
  ;; prentice hand, whose case is foul, so that there is something to correct.
  ;;
  ;; The sample has to be long enough for that to be reliable. At eight
  ;; repetitions it was about 250 words, and the prentice's measured rate of
  ;; 2 accidents per thousand words made the assertion below a coin-toss that
  ;; happened to land the right way for one seed. It failed the moment anything
  ;; upstream moved the random stream, which is a test of the seed and not of
  ;; the program. Sixty repetitions puts the expected count near forty.
  (define long-sample
    (apply string-append
           (for/list ([i (in-range 60)])
             (format "Ham. To be, or not to be, that is the question ~a,\nWhether tis nobler in the mind to suffer\nThe slings and arrows of outrageous fortune,\nOr to take arms against a sea of troubles.\n\n" i))))
  (define b2 (set-book (make-house #:fmt QUARTO #:seed 11 #:compositors '("E"))
                       long-sample))
  (check-true (> (for/sum ([e (in-list (book-events b2))]
                           #:when (eq? (event-kind e) 'accident)) 1)
                 0)
              "the prentice hand's case is foul enough to give us accidents")
  (define r2 (run-press b2 #:copies 4 #:seed 7 #:proof-rate 1.0 #:first-proof 1.0))
  (check-equal? (run-variants r2) '() "no variants when all proofing is early")
  (check-true (> (for/sum ([(k s) (in-hash (press-run-states r2))])
                   (forme-state-silent s))
                 0)
              "but corrections were nevertheless made")
  (check-equal? (collate r2 (first (press-run-copies r2)) (second (press-run-copies r2)))
                '() "and every copy agrees"))
