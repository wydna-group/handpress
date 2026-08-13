#lang racket/base
;;; What the casting-off estimator predicts, against what the compositor sets.
;;;
;;; This exists because a probe written to answer that question disagreed with
;;; the report eightfold and stalled Roadmap §5 for a session. The report was
;;; right: the record in the TEI carries `hp:pressure' per page, and counting it
;;; reproduces the report's crowded and spun-out figures exactly. What the probe
;;; got wrong is not recoverable -- it was never committed -- which is the whole
;;; argument for this file existing instead.
;;;
;;; Two measurements, and the second is the one with no page-boundary confound:
;;;
;;;   per page    `overflow' is (composed lines - capacity), recorded as
;;;               `page-pressure' scaled by 3/capacity and zeroed inside a
;;;               dead band of +/-2 lines. At --cast-off 1.0 the deliberate
;;;               error is off, so what remains is estimator bias alone.
;;;
;;;   per unit    the estimator's prediction for one copy unit against the
;;;               lines the compositor actually sets from it. The prediction
;;;               comes from the REAL `cast-off', called on a single unit with
;;;               a page too deep to close a segment early, so nothing is
;;;               replicated here and this cannot drift from the code it
;;;               measures.
;;;
;;; The bound to read the per-page figure against is Blayney on _Lear_, p. 30 --
;;; "the page-depth is almost entirely consistent" -- said in the paragraph
;;; whose purpose is to say how badly that book was printed. It is a bound and
;;; not a rate; no source gives a rate.
;;;
;;;   racket tools/measure-castoff.rkt [samples/areopagitica.txt] [--kind prose]

(require racket/file racket/list racket/math racket/string racket/cmdline
         "../metrics.rkt" "../book.rkt" "../compositor.rkt"
         "../imposition.rkt" "../copytext.rkt" "../rng.rkt" "../typecase.rkt" "../orthography.rkt" "../import.rkt")

(define SEEDS '(5 6 7 8))

(define (mean xs) (if (null? xs) 0.0 (exact->inexact (/ (apply + xs) (length xs)))))
(define (d2 x) (real->decimal-string x 2))
(define (pct n d) (if (zero? d) "0.0" (real->decimal-string (* 100.0 (/ n d)) 1)))

;; ---------------------------------------------------------------------------
;; Per page: the residual the report counts
;; ---------------------------------------------------------------------------

;; `page-pressure' is 3*overflow/capacity, clamped, and forced to zero inside a
;; dead band of |overflow| <= 2. Invert it to get the overflow back in lines.
(define (page-overflow p capacity)
  (* (page-pressure p) (/ capacity 3.0)))

(define (per-page txt kind fmt accuracy)
  (define capacity (* (book-format-lines fmt) (book-format-columns fmt)))
  (for/list ([seed (in-list SEEDS)])
    (define h (make-house #:fmt fmt #:compositors '("A" "B") #:seed seed
                          #:cast-off-accuracy accuracy))
    (define b (set-book h txt kind))
    (define ps (book-pages b))
    (define ovs (map (lambda (p) (page-overflow p capacity)) ps))
    (define miscast (filter (lambda (x) (not (zero? x))) ovs))
    (list seed (length ps)
          (length (filter positive? ovs))      ; crowded, as deviation.rkt counts
          (length (filter negative? ovs))      ; spun out, ditto
          (mean miscast)
          (for/sum ([p (in-list ps)]) (length (page-omitted p))))))

;; ---------------------------------------------------------------------------
;; Per unit: the estimator against the frame, with no page boundary in the way
;; ---------------------------------------------------------------------------

;; The real estimator, obtained rather than reimplemented: one unit, a page deep
;; enough that the segment cannot close early, and accuracy 1.0 so no slip is
;; drawn. What comes back is `estimate' applied to that unit and nothing else.
;; The pending prefix is fed in as the prefix unit it really is, so that whatever
;; `cast-off' does with one is what is measured. A prefix estimates 0 itself, so
;; the segment total is still this unit's estimate -- plus whatever room the
;; casting off now allows for the prefix, which is the thing under test.
(define (estimate-of u measure-ems [pending #f])
  (define g (make-rng 1))
  (define us (if pending
                 (list (copy-unit 'prefix pending 0 #f) u)
                 (list u)))
  (define segs (cast-off us (exact-round (* measure-ems UNITS-PER-EM))
                         100000 g 1.0))
  (if (null? segs) 0 (cast-off-segment-estimated-lines (car segs))))

;; What the compositor actually sets from that unit, at ease.
;;
;; This has to agree with `compose' in book.rkt about what a unit costs the
;; page, not merely with the setting routine it calls. A heading is the case
;; that catches it: `set-heading' returns the heading, and `compose' puts a
;; white line above and below it, so the depth a heading takes is n+2 -- which
;; is exactly the estimator's `(+ n 2)'. Measured against `set-heading' alone
;; the estimator reads 100% over on every heading in the book, and that is the
;; probe being wrong rather than a finding. It is written out here because a
;; first run of this tool reported it as one.
;;
;; A prefix costs no line of its own, but it is not free. `compose' holds it and
;; hands it to the next verse or prose unit as `lead', where it goes on the
;; front of that unit's first line -- so "Ham." is what pushes "To be, or not to
;; be" over the measure and turns it over. Measured without the lead the verse
;; branch read 1.24% OVER on the Folio, where 30,059 of its 89,168 verse units
;; carry a prefix. That is the same fault as the heading above, found the same
;; way and after the same wrong conclusion: this probe has to agree with
;; `compose' about what a unit costs the page, not with the setting routine
;; `compose' happens to call.
(define (actual-of c u spec pending)
  (define k (copy-unit-kind u))
  (define text (copy-unit-text u))
  (define lead (if pending (list (speech-prefix c pending 0.0)) '()))
  (case k
    [(blank) (if (equal? (copy-unit-speaker u) EDITORIAL) 0 1)]
    [(prefix) 0]
    [(verse) (length (set-verse c text spec 0.0 #:lead lead
                                #:first-indent? (pair? lead)))]
    [(stage) (length (set-stage-direction c text spec))]
    [(heading) (+ 2 (length (set-heading c text spec)))]
    [else (length (set-prose c text spec 0.0 #:first-indent? #t #:lead lead))]))

(define (per-unit txt kind fmt)
  (define units (parse-copy txt kind))
  (define spec (page-spec (exact-round (* (book-format-measure-ems fmt) UNITS-PER-EM))
                          (book-format-lines fmt) 0 EM-QUAD))
  ;; A case of its own, so picking sorts for the trial cannot deplete anything
  ;; that a later measurement reads. Nothing here goes to press.
  (define c (make-comp (hash-ref PROFILES "A")
                       (make-type-case #:rng (make-rng 12))
                       (conventions #t #t #t #t #t 1600)
                       (make-rng 11)))
  ;; Walked in order and carrying the pending prefix, exactly as `compose' does,
  ;; because the cost of a prefix falls on the unit after it.
  ;;
  ;; `led' counts the units that carry one, and `cost' the lines that exist only
  ;; because of it -- the same unit set with the prefix and without, differenced.
  ;; The estimator gives a prefix 0 and measures the verse line's own text, so
  ;; every one of those lines is invisible to the casting off.
  (define by-kind (make-hash))
  (define led 0)
  (define cost 0)
  (let walk ([us units] [pending #f])
    (unless (null? us)
      (define u (car us))
      (define k (copy-unit-kind u))
      (define e (estimate-of u (book-format-measure-ems fmt) pending))
      (define a (actual-of c u spec pending))
      (when (and pending (memq k '(verse prose)))
        (set! led (add1 led))
        (set! cost (+ cost (- a (actual-of c u spec #f)))))
      (hash-update! by-kind k (lambda (l) (cons (cons e a) l)) '())
      (walk (cdr us)
            (cond [(eq? k 'prefix) (copy-unit-text u)]
                  [(memq k '(verse prose)) #f]
                  [else pending]))))
  (values by-kind led cost))

;; ---------------------------------------------------------------------------

(define (report-page txt kind fmt fmt-name)
  (printf "\n~a, per page -- what the report counts\n" fmt-name)
  (printf "  cast-off   pages   crowded    spun out   mean overflow   dropped\n")
  (for ([acc (in-list '(1.0 0.93))])
    (define rows (per-page txt kind fmt acc))
    (define pages (for/sum ([r rows]) (second r)))
    (define cr (for/sum ([r rows]) (third r)))
    (define sp (for/sum ([r rows]) (fourth r)))
    (define dr (for/sum ([r rows]) (sixth r)))
    (printf "  ~a       ~a     ~a (~a%)   ~a (~a%)   ~a lines      ~a\n"
            (d2 acc) pages
            cr (pct cr pages) sp (pct sp pages)
            (d2 (mean (map fifth rows))) dr))
  (printf "  At 1.00 the deliberate error is off, so what is left is the\n")
  (printf "  estimator's own bias. Blayney's bound is \"almost entirely\n")
  (printf "  consistent\" -- it is a bound, not a rate.\n"))

(define (report-unit txt kind fmt fmt-name)
  (printf "\n~a, per unit -- the estimator against the frame\n" fmt-name)
  (define-values (by-kind led cost) (per-unit txt kind fmt))
  (printf "  kind      units   est lines   set lines   bias/unit   bias/100 lines set\n")
  (for ([k (in-list '(verse prose heading stage blank prefix))])
    (define ps (hash-ref by-kind k '()))
    (unless (null? ps)
      (define e (for/sum ([p ps]) (car p)))
      (define a (for/sum ([p ps]) (cdr p)))
      (printf "  ~a~a   ~a   ~a   ~a    ~a      ~a\n"
              k (make-string (max 0 (- 8 (string-length (symbol->string k)))) #\space)
              (~r5 (length ps)) (~r5 e) (~r5 a)
              (d2 (/ (- e a) (max 1 (length ps))))
              (d2 (* 100.0 (/ (- e a) (max 1 a)))))))
  (printf "  A negative bias means the estimator allots the page MORE copy than\n")
  (printf "  the compositor can set in it, which comes out as a crowded page.\n")
  (printf "\n  Of those units ~a carry a speech prefix, and the prefix is worth ~a\n"
          led cost)
  (printf "  line(s) at the frame -- the same copy set with it and without,\n")
  (printf "  differenced. The casting off scored a prefix at nought and measured\n")
  (printf "  the verse line's own text, so every one of those lines was invisible\n")
  (printf "  to it; `estimate' now allows the room, and the verse row above is\n")
  (printf "  what that is worth. Watch this against the verse bias: if the two\n")
  (printf "  ever disagree in size, the allowance has stopped matching the frame.\n"))

(define (~r5 n) (let ([s (number->string n)])
                  (string-append (make-string (max 0 (- 5 (string-length s))) #\space) s)))

(module+ main
  (define kind 'prose)
  (define file
    (command-line
     #:once-each
     [("--kind") k "verse, prose or drama" (set! kind (string->symbol k))]
     #:args ([f "samples/areopagitica.txt"]) f))
  ;; Through `import.rkt', so the Folio copy can be measured at its own format
  ;; from the same TEI the standard hard case is run on. A plain sample still
  ;; reads as plain text, which is what `read-source' does with one.
  (define txt (source-text (read-source file)))
  (printf "~a  (--kind ~a)\n" file kind)
  (printf "ladder ~a em   normal ~a em   finest ~a em\n"
          (map (lambda (u) (real->decimal-string (ems u) 3)) SPACE-LADDER)
          (real->decimal-string (ems NORMAL-SPACE) 3)
          (real->decimal-string (ems FINEST-SPACE) 3))
  (report-page txt kind FOLIO-IN-SIXES "folio in sixes")
  (report-unit txt kind FOLIO-IN-SIXES "folio in sixes"))
