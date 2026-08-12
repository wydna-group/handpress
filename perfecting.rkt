#lang racket/base
;;; Recovering the perfecting order from the press variants.
;;;
;;; Roadmap §2, and the exam the heaps opened. Gaskell's mechanism (pp. 143-4)
;;; says which forme of a sheet went to press first is legible in the made-up
;;; copies. The heaps are gathered from the top: for a sheet perfected inner
;;; forme first, "in the reverse of the printing order, so that the first book
;;; to be gathered contained the last printed sheets"; for one perfected outer
;;; forme first the heap "had to be turned over ... This heap was then gathered
;;; in the printing order".
;;;
;;; The corrected sheets are the ones printed after the marked proof came back,
;;; so they are at the END of the printing order. Put the two together:
;;;
;;;   inner forme perfected first  ->  the corrected copies are gathered FIRST
;;;                                    -- a PREFIX of the gathering order
;;;   outer forme perfected first  ->  the corrected copies are gathered LAST
;;;                                    -- a SUFFIX of it
;;;
;;; That is the whole inference, and the program knows the answer, so it can be
;;; scored. What follows is the part that is not obvious.
;;;
;;; WHAT THE ANALYST IS NOT GIVEN. A real bibliographer has copies from
;;; libraries, in no order at all. He does not know which was gathered first,
;;; and "prefix or suffix?" is unanswerable until he does. In this program the
;;; copies are named A, B, C ... in the order they were gathered, so sorting
;;; them by name would hand the analyst the answer -- exactly the fault
;;; `recurrence.rkt' exists to prevent on the type side. Nothing here reads a
;;; copy's name or its position in any list. The order is reconstructed from
;;; the set-structure of the groupings alone, and there is a test that feeds
;;; the copies in scrambled and checks the answer does not move.
;;;
;;; HOW THE ORDER COMES BACK. Greg's consistency condition is what makes it
;;; possible: gathered as Gaskell describes, every grouping is a prefix or a
;;; suffix of one linear order, so any two are nested or disjoint (Calculus of
;;; Variants, p. 12). Two prefixes are always nested. A prefix and a suffix are
;;; never nested -- they are disjoint if they do not meet, and between them
;;; cover every copy if they overlap. So "nested" and "not nested" sort the
;;; groupings into two classes, and within a class they agree about which end
;;; of the book is which. Orient one class as prefixes, complement the other,
;;; count how many prefixes hold each copy, and the copy held by the most is
;;; the one gathered first.
;;;
;;; AND WHY IT CANNOT BE FINISHED. Which class to call the prefixes is a free
;;; choice. Taking the other one reverses the recovered order and turns every
;;; inner into an outer, in one stroke, across the whole book -- and the
;;; evidence is exactly as consistent either way. **The perfecting order is
;;; recoverable from press variants only up to a single global flip.** One
;;; fact from outside settles the lot: one sheet whose printing order is known
;;; some other way (type recurrence, §1), or the assumption that the shop
;;; perfected mostly one way. Gaskell's own example supposes inner-first
;;; throughout, which would do it -- but that is an assumption imported, not a
;;; reading of the evidence, and this module declines to make it silently.
;;;
;;; If the groupings fall into several classes that never meet, each flips on
;;; its own and the ambiguity is 2^n rather than 2. That is reported too.

(require racket/list racket/set racket/string racket/format
         "press.rkt")

(provide (struct-out perfecting-inference)
         infer-perfecting perfecting-score perfecting-report chance-floor)

;; order      : the copies in the recovered gathering order, up to reversal
;; ranks      : copy -> how many prefixes hold it; equal ranks are copies no
;;              variant separates, which is a real limit and not a tie-break
;; called     : forme -> 'inner | 'outer, under the direction chosen below
;; components : how many independently flippable classes of groupings, so the
;;              reading is one of 2^components and never fewer than 2
;; divisions  : the groupings that divided the copies at all
(struct perfecting-inference (order ranks called components divisions)
  #:transparent)

;; ---------------------------------------------------------------------------
;; The inference
;; ---------------------------------------------------------------------------
;; `groups' is forme -> the copies showing the CORRECTED state, which is what
;; `variant-groupings' returns and is what collation gives you. `copies' is
;; every copy on the table, including any that turned out to differ nowhere.
(define (infer-perfecting groups copies)
  (define U (list->set copies))
  (define n (set-count U))

  ;; A grouping holding every copy, or none, divides nothing and is not
  ;; evidence about an order. Greg says the same of a group comprising all the
  ;; manuscripts: it "tells us nothing".
  (define divisions
    (for/list ([f (in-list (sort (hash-keys groups) string<?))]
               #:when (let ([k (set-count (set-intersect U (list->set (hash-ref groups f))))])
                        (and (positive? k) (< k n))))
      (cons f (set-intersect U (list->set (hash-ref groups f))))))
  (define names (map car divisions))
  (define sets (make-hash divisions))

  ;; Same end of the book, or opposite ends? Two prefixes are nested; a prefix
  ;; and a suffix are disjoint or jointly exhaustive. With both sets non-empty
  ;; and neither the whole, the two cases cannot both hold.
  (define (relation a b)
    (define A (hash-ref sets a))
    (define B (hash-ref sets b))
    (cond
      [(or (subset? A B) (subset? B A)) 'same]
      [(or (set-empty? (set-intersect A B)) (set=? (set-union A B) U)) 'opposite]
      [else #f]))                      ; the groupings cross: Greg's condition
                                       ; has failed and neither reading is open

  ;; Two-colour the groupings. The colour is not "inner" and "outer" yet --
  ;; it is only "these agree with each other", and which colour means which is
  ;; the choice the evidence does not make.
  (define colour (make-hash))
  (define components 0)
  (for ([f (in-list names)])
    (unless (hash-has-key? colour f)
      (set! components (add1 components))
      (hash-set! colour f 0)
      (let walk ([frontier (list f)])
        (define next
          (for*/fold ([acc '()]) ([x (in-list frontier)] [y (in-list names)])
            (define r (and (not (hash-has-key? colour y)) (relation x y)))
            (cond
              [(not r) acc]
              [else (hash-set! colour y (if (eq? r 'same)
                                            (hash-ref colour x)
                                            (- 1 (hash-ref colour x))))
                    (cons y acc)])))
        (unless (null? next) (walk next)))))

  ;; Orient every grouping to the same end and count. A copy held by more of
  ;; the prefixes stands earlier in the gathering.
  (define (prefix-of f)
    (if (zero? (hash-ref colour f 0))
        (hash-ref sets f)
        (set-subtract U (hash-ref sets f))))
  (define ranks
    (for/hash ([c (in-set U)])
      (values c (for/sum ([f (in-list names)])
                  (if (set-member? (prefix-of f) c) 1 0)))))

  ;; Sorted on the rank alone. `set->list' has no order worth relying on and
  ;; the copies' names are never consulted, so copies of equal rank come out
  ;; in whatever order they come out in -- which is honest, because no variant
  ;; distinguishes them.
  (define order (sort (set->list U) > #:key (lambda (c) (hash-ref ranks c))))

  ;; And the reading. Corrected copies gathered first means the inner forme
  ;; was perfected first; gathered last means the outer.
  (define called
    (for/hash ([f (in-list names)])
      (values f (if (zero? (hash-ref colour f 0)) 'inner 'outer))))

  (perfecting-inference order ranks called components (length names)))

;; ---------------------------------------------------------------------------
;; Scoring it against what the press actually did
;; ---------------------------------------------------------------------------
;; Returns the count right under the direction as called, the count right
;; under the flip, and how many were judged at all. The better of the two is
;; the score the method can claim ONLY with an external fact to fix the
;; direction; the report says so rather than quietly reporting the maximum.
;; What "sorted into the right two classes" scores for nothing.
;;
;; The metric takes the better of the two directions, so its chance level is
;; NOT a coin: on n formes it is E[max(X, n-X)]/n for X binomial(n, 1/2) --
;; 0.75 on two, 0.64 on eight, and still 0.53 on two hundred. It approaches a
;; half far more slowly than one expects.
;;
;; Scored against a shuffled truth on the Much Ado quarto the control came out
;; at 66.5%, which is ABOVE this function at eight formes and not a
;; contradiction: that figure pools runs of differing length, and a run
;; offering one forme scores 100% for nothing. Pooling a ratio over samples of
;; unequal size is its own small trap, and the floor is therefore computed per
;; run from the formes that run actually judged.
;;
;; It is computed and printed beside every score because this project has been
;; caught before by a figure quoted without the thing it should be compared to.
(define (chance-floor n)
  (define (choose n k)
    (for/fold ([acc 1]) ([i (in-range k)]) (/ (* acc (- n i)) (add1 i))))
  (if (zero? n)
      0.0
      (exact->inexact
       (/ (for/sum ([k (in-range (add1 n))])
            (* (/ (choose n k) (expt 2 n)) (max k (- n k))))
          n))))

(define (perfecting-score inf truth)
  (define called (perfecting-inference-called inf))
  (define judged (hash-count called))
  (define as-called
    (for/sum ([(f side) (in-hash called)])
      (if (eq? (eq? side 'inner) (hash-ref truth f #t)) 1 0)))
  (values as-called (- judged as-called) judged))

;; ---------------------------------------------------------------------------
;; The report
;; ---------------------------------------------------------------------------
(define (pad s n) (~a s #:min-width n))

(define (perfecting-report r)
  (define groups (variant-groupings r))
  (define copies (map printed-copy-name (press-run-copies r)))
  (define inf (infer-perfecting groups copies))
  (define truth (press-run-perfecting r))
  (define-values (as-called flipped judged) (perfecting-score inf truth))
  (define n (length copies))
  (define spacing (max 1 (quotient (press-run-edition r) (max 1 n))))
  (string-join
   (append
    (list "THE PERFECTING ORDER, INFERRED" ""
          "  Which forme of each sheet went to press first, read off the"
          "  press variants alone. Gaskell (pp. 143-4): a sheet perfected"
          "  inner forme first is gathered in reverse of the printing order,"
          "  so its corrected sheets -- the ones worked off after the proof"
          "  came back -- are gathered FIRST. Perfected outer forme first,"
          "  they are gathered last."
          ""
          "  The analyst is given the groupings and nothing else. He is not"
          "  given the order the copies were gathered in; that is recovered"
          "  from the way the groupings nest, which is Greg's condition doing"
          "  a job rather than being tested."
          "")
    (cond
      [(zero? judged)
       (list "  No forme divided the copies, so there is no grouping to read."
             "  That is a fact about this run -- nothing was corrected at"
             "  press, or every copy shows the same state -- and not a"
             "  failure of the method.")]
      [else
       (append
        (list (format "  ~a forme~a judged of ~a corrected."
                      judged (if (= 1 judged) "" "s") (hash-count groups))
              ""
              ;; How finely the copies can be ordered at all. A variant forme
              ;; cuts the gathering in one place, so j of them yield at most
              ;; j+1 distinguishable positions however many copies are on the
              ;; table. Printing a flat list here would have implied an order
              ;; among copies nothing separates -- 24 copies and one variant
              ;; read out as "Q A R B S C ...", which is the arbitrary order
              ;; of a tie dressed up as a finding.
              "  Recovered gathering order, first-gathered leftmost. Copies"
              "  no variant separates share a place and are bracketed:"
              (string-append
               "    "
               (let* ([rk (perfecting-inference-ranks inf)]
                      [classes (sort (group-by (lambda (c) (hash-ref rk c))
                                               (perfecting-inference-order inf))
                                     > #:key (lambda (g) (hash-ref rk (car g))))]
                      [shown (take classes (min 6 (length classes)))])
                 (string-append
                  (string-join
                   (for/list ([g (in-list shown)])
                     (format "[~a]"
                             (let ([ns (sort (map (lambda (c) (string-replace c "Copy " ""))
                                                  g) string<?)])
                               (if (> (length ns) 6)
                                   (format "~a … ~a of them"
                                           (string-join (take ns 4) " ") (length ns))
                                   (string-join ns " ")))))
                   " ")
                  (if (> (length classes) 6) " …" ""))))
              (format "  ~a place~a distinguished among ~a copies; ~a variant~a"
                      (length (remove-duplicates
                               (map (lambda (c)
                                      (hash-ref (perfecting-inference-ranks inf) c))
                                    (perfecting-inference-order inf))))
                      (if (= 1 (length (remove-duplicates
                                        (map (lambda (c)
                                               (hash-ref (perfecting-inference-ranks inf) c))
                                             (perfecting-inference-order inf)))))
                          "" "s")
                      n judged (if (= 1 judged) "" "s"))
              (format "  can never distinguish more than ~a." (add1 judged))
              "")
        (list "  forme                        called    truly")
        (for/list ([f (in-list (sort (hash-keys (perfecting-inference-called inf))
                                     string<?))])
          (format "  ~a ~a ~a" (pad f 28)
                  (pad (symbol->string (hash-ref (perfecting-inference-called inf) f)) 9)
                  (if (hash-ref truth f #t) "inner" "outer")))
        (list ""
              (format "  Right as called: ~a of ~a. Under the flip: ~a of ~a."
                      as-called judged flipped judged)
              ""
              ;; The finding, and the reason the number above must not be
              ;; quoted on its own.
              "  BUT THE DIRECTION IS NOT IN THE EVIDENCE. Calling one class"
              "  of groupings the prefixes is a free choice; taking the other"
              "  reverses the recovered order and turns every inner into an"
              "  outer at a stroke. Both readings satisfy Greg's condition"
              "  equally. So the method sorts the sheets into two classes"
              "  correctly and cannot say which class is which."
              ""
              (format "  Sorted into the right two classes: ~a of ~a (~a%)."
                      (max as-called flipped) judged
                      (~r (* 100.0 (/ (max as-called flipped) judged)) #:precision 0))
              (format "  For nothing, the same metric scores ~a%: taking the"
                      (~r (* 100.0 (chance-floor judged)) #:precision 0))
              (format "  better of two directions on ~a formes is not a coin."
                      judged)
              (format "  Number of readings the evidence permits: 2^~a."
                      (perfecting-inference-components inf))
              ""
              "  One fact from outside settles all of them together: a single"
              "  sheet whose printing order is known from the type recurrence,"
              "  or the assumption that the shop perfected mostly one way."
              "  Gaskell's example supposes inner-first throughout, which"
              "  would serve -- but that is imported, not read, and it is not"
              "  assumed here."
              ""
              ;; §3's warning, made concrete for this run.
              (if (> spacing 75)
                  (string-append
                   (format "  Note also that these ~a copies stand about ~a sheets\n" n spacing)
                   "  apart in the heap, and a sheet is carried at most 75. The\n"
                   "  groupings are therefore undisturbed by the drying rack, and\n"
                   "  the score above is the method's best case rather than its\n"
                   "  ordinary one.")
                  (format
                   (string-append
                    "  These ~a copies stand about ~a sheets apart in the heap,\n"
                    "  inside the ~a a sheet can travel, so the groupings carry\n"
                    "  the warehouse's disorder and the score above is earned\n"
                    "  against it.")
                   n spacing 75))))])
    (list ""))
   "\n"))

;; ---------------------------------------------------------------------------

(module+ test
  (require rackunit racket/file racket/runtime-path
           "book.rkt" "imposition.rkt")

  ;; Same sample the heaps are tested on, and for the same reason: it is
  ;; committed, so this runs on a clean checkout.
  (define-runtime-path perfecting-sample "samples/ado/_all-q1600.txt")
  (define book (set-book (make-house #:fmt QUARTO #:seed 21)
                         (file->string perfecting-sample)))

  (define (run-of seed #:copies [copies 24] #:disorder [d 0.15])
    (run-press book #:copies copies #:seed seed #:proof-rate 1.0
               #:heap-disorder d))
  (define (infer-of r)
    (infer-perfecting (variant-groupings r)
                      (map printed-copy-name (press-run-copies r))))

  ;; THE INFERENCE MUST NOT READ THE ANSWER.
  ;;
  ;; The copies are named A, B, C ... in the order they were gathered, so any
  ;; dependence on the order they are handed in -- or on the names -- would be
  ;; the analyst being given the truth. Feeding them scrambled must change
  ;; nothing. This is the guard `recurrence.rkt' exists to provide on the type
  ;; side and the one thing here that would silently invalidate every score.
  (let ()
    (define r (run-of 3))
    (define names (map printed-copy-name (press-run-copies r)))
    (define groups (variant-groupings r))
    (define base (perfecting-inference-called (infer-perfecting groups names)))
    (for ([t (in-range 8)])
      (check-equal? (perfecting-inference-called
                     (infer-perfecting groups (shuffle names)))
                    base
                    "the reading must not depend on the order the copies arrive in")))

  ;; The partition is recovered, and recovered whole. Over 20 runs every forme
  ;; is called rightly or every forme is called backwards; a run that got some
  ;; right and some wrong would mean the method degrades gracefully, and it
  ;; does not -- it has exactly one thing it can get wrong.
  ;;
  ;; Asserted over 20 seeds rather than one, because a single seed here would
  ;; be a test of the seed.
  (let ()
    (define-values (whole judged-runs)
      (for/fold ([whole 0] [n 0]) ([seed (in-range 20)])
        (define r (run-of seed))
        (define-values (ac fl j) (perfecting-score (infer-of r)
                                                   (press-run-perfecting r)))
        (if (zero? j)
            (values whole n)
            (values (+ whole (if (or (= ac j) (zero? ac)) 1 0)) (add1 n)))))
    (check-true (> judged-runs 10) "the sample must actually offer groupings")
    (check-equal? whole judged-runs
                  "every forme called rightly, or every one backwards -- never a mixture"))

  ;; AND THE DIRECTION IS A COIN, which is the report's central claim and would
  ;; be a lie if the code leant either way. Both outcomes must occur.
  (let ()
    (define-values (right wrong)
      (for/fold ([r+ 0] [w 0]) ([seed (in-range 40)])
        (define r (run-of seed))
        (define-values (ac fl j) (perfecting-score (infer-of r)
                                                   (press-run-perfecting r)))
        (cond [(zero? j) (values r+ w)]
              [(= ac j) (values (add1 r+) w)]
              [(zero? ac) (values r+ (add1 w))]
              [else (values r+ w)])))
    (check-true (> right 5) (format "called rightly in ~a of 40 runs" right))
    (check-true (> wrong 5) (format "called backwards in ~a of 40 runs" wrong)))

  ;; The chance floor is not a coin and the report must not print one. Taking
  ;; the better of two directions on n formes scores E[max(X, n-X)]/n.
  (check-= (chance-floor 1) 1.0 1e-9)
  (check-= (chance-floor 2) 0.75 1e-9)
  (check-true (< 0.63 (chance-floor 8) 0.65)
              "eight formes: 0.64 for nothing, not the half one would guess")
  (check-true (< 0.52 (chance-floor 200) 0.54)
              "and two hundred formes is still 0.53 -- it falls very slowly")
  (check-true (< (chance-floor 200) (chance-floor 8))
              "but it does fall as the book lengthens")

  ;; A grouping that holds every copy, or none, divides nothing. Greg says the
  ;; same of a group comprising all the manuscripts: it "tells us nothing".
  (let ()
    (define inf (infer-perfecting (hash "all" '("Copy A" "Copy B")
                                        "none" '())
                                  '("Copy A" "Copy B")))
    (check-equal? (perfecting-inference-divisions inf) 0)
    (check-equal? (hash-count (perfecting-inference-called inf)) 0))

  ;; Copies no variant separates share a place. One variant cuts 24 copies in
  ;; two and cannot order them further, however many copies are on the table.
  (let ()
    (define inf (infer-perfecting (hash "F sheet 1 inner" '("Copy A" "Copy B"))
                                  '("Copy A" "Copy B" "Copy C" "Copy D")))
    (check-equal? (length (remove-duplicates
                           (hash-values (perfecting-inference-ranks inf))))
                  2
                  "one variant distinguishes two places, not four")))
