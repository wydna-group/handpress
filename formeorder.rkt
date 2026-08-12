#lang racket/base
;;; The order the formes of a quire were set, from the types alone.
;;;
;;; Roadmap §1, and Hinman's own method rather than one invented for him. Three
;;; inferences were built here before the book by the man who devised it was
;;; opened -- a weighted bump, spectral seriation, an alternating fit, all
;;; scoring at chance -- and every one of them was the wrong shape. He does not
;;; score orders at all (i. 76-81, section 3, "Order of Formes"):
;;;
;;;   "the second of two consecutive Folio formes was set before the first was
;;;   distributed, and hence THE TWO CANNOT ORDINARILY HAVE TYPES IN COMMON ...
;;;   any supposed order of formes in which the same types appear in consecutive
;;;   formes must be considered wrong, the more especially if, given some other
;;;   order, types do not so appear; and whenever there is ONLY ONE order in
;;;   which none of the types in the quire appear in consecutive formes, this
;;;   order may confidently be taken as the one actually followed." (i. 80)
;;;
;;; So sharing a type FORBIDS adjacency. The reading is whatever arrangement
;;; breaks no prohibition, and Hinman's confidence is explicitly conditional on
;;; there being exactly one -- which makes the size of the admissible set the
;;; thing to report, not a score. A quire of six formes has 720 arrangements and
;;; is enumerated outright; there is no search here.
;;;
;;; THE UNIT IS THE QUIRE. He orders six formes at a time, the quire being given
;;; by the signatures, and never poses the book-wide ordering the three failed
;;; attempts were trying to solve. That alone was most of what was wrong.
;;;
;;; TWO THINGS THIS DOES NOT DO, both his and both recorded rather than faked:
;;;
;;; - The direction. An admissible order reversed is admissible, and Hinman says
;;;   so: "this could be true of no other order save one -- the exact reverse of
;;;   the one shown". He resolves it by chaining quires (i. 81) -- the last forme
;;;   of the preceding quire shares type with one end of the next and not the
;;;   other -- so one anchor propagates through the book. Not built; everything
;;;   below is scored up to reversal and says so.
;;; - The exception. "In the initial quires of the Folio, and occasionally (but
;;;   very rarely) elsewhere, the same types do appear in consecutive formes --
;;;   but for special reasons which can be satisfactorily explained." Here such a
;;;   quire simply admits no order at all, and is counted as admitting none.

(require racket/list racket/set racket/string racket/format
         "book.rkt" "recurrence.rkt" "imposition.rkt")

(provide (struct-out quire-reading)
         forme-pieces quire-formes admissible-orders read-quires forme-order-report)

;; formes  -- the quire's formes, in the order the press actually set them
;; orders  -- every admissible arrangement, counted up to reversal
;; unique? -- exactly one survived, which is Hinman's condition for confidence
;; right?  -- and it is the true one, up to reversal
(struct quire-reading (quire formes orders unique? right?) #:transparent)

;; forme name -> the identifiable pieces that printed in it
(define (forme-pieces b #:discrimination [d (current-discrimination)])
  (define by-page (evidence-by-page (recurrence-evidence (book-case b) #:discrimination d)))
  (for/fold ([h (hash)]) ([p (in-list (book-pages b))])
    (hash-update h (page-forme-name p)
                 (lambda (s) (set-union s (hash-ref by-page (page-sig p) (set))))
                 (set))))

;; quire -> its formes in the true setting order. The grouping is the analyst's
;; -- a quire is given by the signatures on the leaf -- but the order within it
;; is the answer, and is used only for grading.
(define (quire-formes b)
  (for/fold ([h (hash)]) ([fm (in-list (sort (book-formes b) < #:key forme-order))])
    (hash-update h (forme-gathering fm)
                 (lambda (xs) (append xs (list (forme-name fm)))) '())))

(define (shares? pieces a b)
  (positive? (set-count (set-intersect (hash-ref pieces a (set)) (hash-ref pieces b (set))))))

;; Every order in which no two adjacent formes share an identifiable type,
;; counted up to reversal because an order and its reverse are one reading.
;;
;; Enumerated rather than searched: a quire is six formes in folio and eight at
;; the outside, and the whole point of Hinman's criterion is that it is exact.
;; Guarded at nine so that an unusual gathering cannot set 300,000 permutations
;; going -- it returns #f there, which the report distinguishes from "none".
(define (admissible-orders formes pieces)
  (and (< (length formes) 9)
       (for/fold ([acc '()])
                 ([o (in-list (permutations formes))]
                  #:when (for/and ([x (in-list o)] [y (in-list (cdr o))])
                           (not (shares? pieces x y))))
         (if (ormap (lambda (k) (equal? k (reverse o))) acc) acc (cons o acc)))))

;; Every quire that can be put to the test: four formes at least, since two or
;; three cannot distinguish an order from its reverse, and every forme carrying
;; some identifiable type, since a forme with none is prohibited from nothing
;; and would make the admissible set large for want of evidence rather than
;; because the evidence is equivocal.
(define (read-quires b #:discrimination [d (current-discrimination)])
  (define pieces (forme-pieces b #:discrimination d))
  (for*/list ([(q formes) (in-hash (quire-formes b))]
              #:when (and (>= (length formes) 4)
                          (for/and ([f (in-list formes)])
                            (positive? (set-count (hash-ref pieces f (set)))))))
    (define os (admissible-orders formes pieces))
    (quire-reading q formes os
                   (and os (= 1 (length os)))
                   (and os (= 1 (length os))
                        (or (equal? (car os) formes) (equal? (car os) (reverse formes)))))))

;; ---------------------------------------------------------------------------

(define (forme-order-report b)
  (define rs (read-quires b))
  (define n (length rs))
  (define uniq (for/sum ([r (in-list rs)]) (if (quire-reading-unique? r) 1 0)))
  (define right (for/sum ([r (in-list rs)]) (if (quire-reading-right? r) 1 0)))
  (define none (for/sum ([r (in-list rs)])
                 (if (and (quire-reading-orders r) (null? (quire-reading-orders r))) 1 0)))
  (string-join
   (append
    (list "THE ORDER OF FORMES, FROM THE TYPES" ""
          "  Hinman's criterion, and his alone: \"the second of two consecutive"
          "  formes was set before the first was distributed, and hence the two"
          "  cannot ordinarily have types in common\" (i. 80). Sharing a type"
          "  therefore forbids adjacency, and the order of a quire is whatever"
          "  arrangement breaks no prohibition. He takes the reading as proved"
          "  only where ONE arrangement survives, so what is reported here is"
          "  the size of the admissible set and not a score."
          "")
    (if (zero? n)
        (list "  No quire can be put to the test. A quire needs four formes"
              "  before an order can be told from its reverse -- a quarto"
              "  gathering has two -- and every forme in it must carry some"
              "  identifiable type. That is a fact about this format and this"
              "  copy, not a failure of the method.")
        (append
         (list "  quire   formes   admissible orders   verdict")
         (for/list ([r (in-list (sort rs < #:key quire-reading-quire))])
           (define os (quire-reading-orders r))
           (format "  ~a ~a ~a ~a"
                   (~a (quire-reading-quire r) #:min-width 7)
                   (~a (length (quire-reading-formes r)) #:min-width 8)
                   (~a (cond [(not os) "not enumerated"]
                             [(null? os) "none"]
                             [else (number->string (length os))])
                       #:min-width 19)
                   (cond [(not os) "the gathering is too large to enumerate"]
                         [(null? os) "no order is admissible: types recur in"]
                         [(quire-reading-right? r) "one order, and it is the true one"]
                         [(quire-reading-unique? r) "one order, and it is WRONG"]
                         [else "not determined; too many survive"])))
         (list ""
               (format "  ~a of ~a quires determined; of those, ~a right."
                       uniq n right)
               (format "  Mean admissible orders: ~a."
                       (~r (/ (for/sum ([r (in-list rs)])
                                (if (quire-reading-orders r)
                                    (length (quire-reading-orders r)) 0))
                              (exact->inexact (max 1 n)))
                           #:precision 2))
               "")
         (if (zero? none) '()
             (list (format "  ~a quire~a admitted no order at all. Hinman knows the case:"
                           none (if (= 1 none) "" "s"))
                   "  in the initial quires \"and occasionally (but very rarely)"
                   "  elsewhere, the same types do appear in consecutive formes\","
                   "  for reasons he can explain. Here it means the shop"
                   "  distributed sooner than the criterion assumes."
                   ""))
         (list "  THE DIRECTION IS NOT DETERMINED HERE. An admissible order"
               "  reversed is admissible, and Hinman says so -- \"this could be"
               "  true of no other order save one, the exact reverse of the one"
               "  shown\". He settles it by chaining quires: the last forme of"
               "  the preceding quire has types in common with one end of the"
               "  next and not the other, so a single anchor carries through"
               "  the book. That is not built, and every figure above is"
               "  therefore scored up to reversal.")))
    (list ""))
   "\n"))

;; ---------------------------------------------------------------------------

(module+ test
  (require rackunit racket/file racket/runtime-path)

  ;; Adjacency is forbidden by sharing, and by nothing else.
  (let ()
    (define pieces (hash "a" (set 1 2) "b" (set 3) "c" (set 2 4) "d" (set 5)))
    ;; a and c share piece 2, so they may never sit next to each other
    (define os (admissible-orders '("a" "b" "c" "d") pieces))
    (check-true (andmap (lambda (o)
                          (for/and ([x (in-list o)] [y (in-list (cdr o))])
                            (not (and (member x '("a" "c")) (member y '("a" "c"))))))
                        os)
                "no admissible order puts two type-sharing formes together")
    (check-false (ormap (lambda (o) (equal? o '("a" "c" "b" "d"))) os)))

  ;; An order and its reverse are one reading, not two.
  (let ()
    (define pieces (hash "a" (set 1) "b" (set 2) "c" (set 3) "d" (set 4)))
    (define os (admissible-orders '("a" "b" "c" "d") pieces))
    (check-equal? (length os) 12
                  "24 arrangements of four formes, none prohibited, is 12 readings"))

  ;; A quire whose formes all share with all admits nothing -- which is the case
  ;; Hinman flags for the initial quires, and is not the same as "not tested".
  (let ()
    (define pieces (hash "a" (set 1) "b" (set 1) "c" (set 1) "d" (set 1)))
    (check-equal? (admissible-orders '("a" "b" "c" "d") pieces) '()))

  ;; The guard, so an odd gathering cannot set 300,000 permutations going.
  (check-false (admissible-orders (build-list 9 number->string) (hash)))

  ;; And the method on a real book. Folio in sixes gives quires of six formes,
  ;; which is Hinman's own case; the claim under test is his -- that where one
  ;; order survives it is the order actually followed.
  ;;
  ;; Asserted over seeds, not one: a single quire would be a test of the seed.
  (define-runtime-path copy "samples/areopagitica.txt")
  (let ()
    (define-values (det right)
      (for/fold ([d 0] [r 0]) ([seed (in-range 4)])
        (define b (set-book (make-house #:fmt FOLIO-IN-SIXES #:seed seed
                                        #:formes-standing 1)
                            (file->string copy)))
        (for/fold ([d d] [r r]) ([q (in-list (read-quires b))])
          (values (+ d (if (quire-reading-unique? q) 1 0))
                  (+ r (if (quire-reading-right? q) 1 0))))))
    (check-true (> det 0) "the criterion determines some quire")
    (check-equal? right det
                  "and where exactly one order survives, it is the true one")))
