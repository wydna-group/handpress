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
;;; Two facts, both Hinman's: the corrector generally worked *without the
;;; copy*, so he catches foul case readily and misreadings hardly at all; and
;;; he sometimes made it worse, introducing a reading that is neither the
;;; author's nor the compositor's.
;;;
;;; And one from Carter: a proof pulled and mended *before* the run leaves no
;;; variant at all. So the catalogue of press variants, however many copies
;;; are collated, records only the corrections made too late.

(require racket/list racket/string racket/math
         "compositor.rkt" "book.rkt" "rng.rkt")

(provide (struct-out pvariant) (struct-out forme-state)
         (struct-out printed-copy) (struct-out press-run)
         run-press copy-reading-map collate run-variants
         forme-state-corrected?)

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
(struct printed-copy (name states) #:transparent)

(struct press-run (states copies events silent-readings edition) #:transparent)

(define (run-variants r)
  (append* (for/list ([(k s) (in-hash (press-run-states r))])
             (forme-state-variants s))))

(define (sophisticate word g)
  (define low (string-downcase (string-trim word ".,;:!?" #:repeat? #t)))
  (cond
    [(hash-has-key? sophistications low)
     (string-replace word low (hash-ref sophistications low))]
    [(and (> (string-length low) 4) (string-suffix? low "e"))
     (string-replace word low (substring low 0 (sub1 (string-length low))))]
    [(> (string-length low) 3) (string-replace word low (string-append low "e"))]
    [else #f]))

(define (run-press b
                   #:copies [copies 4]
                   #:seed [seed 1623]
                   #:proof-rate [proof-rate 0.6]
                   #:catches-accident [catches-accident 0.75]
                   #:catches-misreading [catches-misreading 0.10]
                   #:sophisticates [sophisticates 0.16]
                   #:first-proof [first-proof 0.0]
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

       (for ([p (in-list pages)])
         (for ([e (in-list (hash-ref events-by-page (page-sig p) '()))])
           (define w (locate p e))
           (define threshold
             (if (eq? (event-kind e) 'accident) catches-accident catches-misreading))
           (when (and w (< (rnd g) threshold)
                      (not (string=? (word-printed w) (word-composed w))))
             (set! variants
                   (cons (pvariant forme-name (page-sig p) (event-line e)
                                   (event-word e) (word-printed w) (word-composed w)
                                   (format "literal corrected at press (~a)"
                                           (event-detail e)))
                         variants))))

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

  (define made
    (for/list ([i (in-range copies)])
      (printed-copy
       (format "Copy ~a" (integer->char (+ (char->integer #\A) i)))
       (for/hash ([(name s) (in-hash states)])
         (values name
                 (and (forme-state-corrected? s)
                      (> (rnd g) (forme-state-fraction-uncorrected s))))))))

  (press-run states made (reverse log) silent-readings edition))

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
  (define long-sample
    (apply string-append
           (for/list ([i (in-range 8)])
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
