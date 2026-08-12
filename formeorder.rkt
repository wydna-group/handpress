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
;;; THE DIRECTION is settled by chaining quires (i. 81) and `chain-quires' does
;;; it: the last forme of one quire was set immediately before the first forme of
;;; the next, so the prohibition reaches across the boundary and an end that
;;; shares type with the previous quire's last forme cannot be this quire's
;;; first. IT NEVER FIRES HERE, and the reason is a fact about this simulation
;;; rather than about the method -- see below.
;;;
;;; THE EXCEPTION he allows: "In the initial quires of the Folio, and
;;; occasionally (but very rarely) elsewhere, the same types do appear in
;;; consecutive formes -- but for special reasons which can be satisfactorily
;;; explained." Such a quire admits no order at all and is counted as admitting
;;; none rather than as undetermined.
;;;
;;; AND THE PREMISE IS ONLY PARTLY TRUE OF THIS SHOP, which is the most useful
;;; thing the criterion has found. Hinman's whole method rests on consecutive
;;; formes not sharing type. Measured here, consecutive formes share about 40%
;;; of the time (offset 1 is empty in 54 of 91 pairs at one forme standing), and
;;; at a quire boundary the last forme of one quire shares six to ten
;;; identifiable types with the first forme of the next -- so both ends of the
;;; following quire are ruled out, the link is ambiguous, and it says nothing in
;;; 24 boundaries of 24.
;;;
;;; The cause is in `book.rkt': distribution fires on the type ceiling as well as
;;; on the count of formes standing, so a forme can go back to the case early and
;;; its type reach the very next forme. Hinman's Folio shop evidently did not do
;;; that. Which cuts the opposite way to every other correction in this project:
;;; the simulation is making his method look WORSE than it was, and a shop that
;;; honoured the premise would determine more quires than the 50-80% below.

(require racket/list racket/set racket/string racket/format
         "book.rkt" "recurrence.rkt" "imposition.rkt")

(provide (struct-out quire-reading) (struct-out quire-link)
         forme-pieces quire-formes admissible-orders read-quires chain-quires
         forme-order-report)

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
;;
;; `forme-order' IS NOT THAT ORDER, and the reverse of it is. The counter is
;; assigned by walking `formes-for-gathering' forwards, while the pages are set
;; in `setting-order', which is built from that same list REVERSED
;; (imposition.rkt) -- so for a folio in sixes `forme-order' 0 is the inner forme
;; of the inner sheet, holding pages 2 and 11, and the pages actually set first
;; are 5 and 8, which belong to `forme-order' 5.
;;
;; Reversing per gathering costs the grading nothing, since the criterion is
;; scored up to reversal and a reversed truth is as right as an unreversed one --
;; which is exactly why the 26-of-26 above survived the error unscathed and the
;; error survived three sessions. What it did break is everything that reads an
;; END of a quire: `chain-quires' took the last forme by `forme-order', which is
;; the FIRST forme set, and compared it with the next quire across a gap of five
;; formes rather than none. Six to ten shared types is what the profile predicts
;; at that distance; the link was not failing, it was being asked the wrong pair.
;;
;; The counter itself is left alone here on purpose. It also drives the skeleton
;; cycle in `book.rkt', so renumbering it would move which skeleton went with
;; which forme and change the running-title evidence. That is a separate change
;; and belongs with a separate measurement.
(define (quire-formes b)
  (for/fold ([h (hash)]) ([fm (in-list (sort (book-formes b) > #:key forme-order))])
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
;; Hinman's cross-quire link, which fixes the direction
;; ---------------------------------------------------------------------------
;; The last forme of one quire was set immediately before the first forme of the
;; next, so the same prohibition reaches across the boundary. Hinman (i. 81):
;;
;;   "the last forme of the preceding quire has types in common with Gg1:6ᵛ but
;;   not with Gg3ᵛ:4. So Gg1:6ᵛ cannot have been the first forme of its quire,
;;   though Gg3ᵛ:4 can have."
;;
;; An end of a quire that shares type with the previous quire's last forme
;; cannot be that quire's first forme, so it must be its last -- and the quire's
;; direction is settled. It fires only when exactly one end shares: if neither
;; does the link is silent, and if both do the criterion has been violated
;; somewhere and it says nothing rather than guessing.
;;
;; What this settles is a quire's direction RELATIVE to its neighbour. Chained
;; along the book it orients every quire against the first, and the direction of
;; the first is not in the type evidence -- one global flip survives, exactly as
;; it does for the press variants in perfecting.rkt. There it needed a fact from
;; outside; here the fact is the uncontroversial one that a book was set roughly
;; front to back, and the signatures give that order.
(struct quire-link (from to fired? right?) #:transparent)

;; `qs' are readings in the order the quires were gathered, which the analyst
;; has from the signatures. Only quires the criterion determined can be linked.
(define (chain-quires qs pieces)
  (define determined (filter quire-reading-unique? qs))
  (for/list ([a (in-list determined)] [b (in-list (if (null? determined) '() (cdr determined)))])
    (define last-of-a (last (quire-reading-formes a)))
    (define ends (list (first (quire-reading-formes b)) (last (quire-reading-formes b))))
    ;; the true first forme of b is (first ends); the link is right when it
    ;; rules out the OTHER end and leaves this one standing
    (define shares-first? (shares? pieces last-of-a (first ends)))
    (define shares-last? (shares? pieces last-of-a (second ends)))
    (define fired? (not (eq? shares-first? shares-last?)))
    (quire-link (quire-reading-quire a) (quire-reading-quire b)
                fired?
                (and fired? shares-last? (not shares-first?)))))

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
         (let* ([pieces (forme-pieces b)]
                [ls (chain-quires (sort rs < #:key quire-reading-quire) pieces)]
                [fired (filter quire-link-fired? ls)]
                [ok (filter quire-link-right? ls)])
           (append
            (list "  THE DIRECTION, by Hinman's link across the boundary. The last"
                  "  forme of one quire was set immediately before the first forme"
                  "  of the next, so the same prohibition reaches between them: an"
                  "  end sharing type with the previous quire's last forme cannot"
                  "  be this quire's first (i. 81)."
                  "")
            (if (null? ls)
                (list "  No two determined quires stand next to each other, so there"
                      "  is no boundary to read. Every order above is up to reversal.")
                (append
                 (for/list ([l (in-list ls)])
                   (format "    ~a into ~a: ~a"
                           (quire-link-from l) (quire-link-to l)
                           (cond [(quire-link-right? l) "direction fixed, and rightly"]
                                 [(quire-link-fired? l) "direction fixed, and WRONGLY"]
                                 [else "silent; both ends alike"])))
                 (list ""
                       (format "  ~a of ~a boundaries spoke; ~a of those were right."
                               (length fired) (length ls) (length ok))
                       ""
                       "  That orients each quire against its neighbour, and chained"
                       "  along the book it orients them all against the first. The"
                       "  direction of the FIRST is not in the type evidence, so one"
                       "  flip survives -- the same residue perfecting.rkt reports"
                       "  for the press variants. Here the fact that settles it is"
                       "  the uncontroversial one that a book was set roughly front"
                       "  to back, and the signatures supply that.")))))))
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
