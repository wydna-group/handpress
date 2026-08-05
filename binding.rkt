#lang racket/base
;;; Gathering, folding and sewing -- and getting it wrong.
;;;
;;; This is the one stage at which the *book* diverges from the *printing*.
;;; Everything before it is the same for every copy of an impression; from
;;; here on the copies are individuals, and a bibliographer describing one of
;;; them has to tell the faults of the copy from the faults of the edition.
;;;
;;; Two hands, in two places. The warehouseman gathers, in the printing house:
;;;
;;;   "When the heaps of all the sheets of a book had been dried and piled
;;;   together again, they were set out in signature order on a long table,
;;;   with the first recto pages upwards and to the near side. Then the
;;;   gatherer, still probably the warehouseman, took off the top copy of the
;;;   last sheet of the book and then walked along the line of sheets, taking
;;;   off one copy of each in turn, until he had gathered a complete copy of
;;;   the book in sheets. This book was knocked smooth at the edges and laid
;;;   down ... The books were then collated to ensure that each was made up
;;;   correctly, and they were finally folded in half ..., pressed, and baled
;;;   up for delivery or storage." (Gaskell, pp. 143-4)
;;;
;;; The binder folds and sews, later and elsewhere. Between them they can drop
;;; a sheet, take two, put one in backwards, or sew them out of order -- and
;;; the whole apparatus of signatures exists to stop exactly two of those:
;;;
;;;   "It was necessary, when assembling the sheets of a book, to get them the
;;;   right way up and in the right order; and to this end each sheet was
;;;   signed on the first page with a letter of the alphabet so that they could
;;;   readily be arranged in alphabetical order; similar signatures were also
;;;   placed on the rectos of a few leaves after the first of each sheet in
;;;   order to help the binder with his folding." (Gaskell, p. 79)
;;;
;;; That sentence is the design of this module. The *kinds* of fault come from
;;; the sources; so does the fact that signing prevents two of them and that
;;; the made-up books were collated before they went out. What does not come
;;; from the sources is any number at all.
;;;
;;; **NEITHER GASKELL NOR MCKERROW GIVES AN ERROR RATE.** McKerrow gives the
;;; detection -- how to tell a cancel from "a leaf that has at some time been
;;; loose, and in rebinding has been stuck in at a wrong level" (fig. 21) --
;;; and the kinds, and no frequency. Every rate this program has ever guessed
;;; has turned out wrong by an order of magnitude, so BINDING-ERROR-RATE is an
;;; explicit parameter carrying no authority whatever, and the report says so
;;; wherever it reports a fault. It is a knob, not a finding.

(require racket/list racket/string "rng.rkt")

(provide (struct-out quire) (struct-out fault) (struct-out bound-copy)
         bind BINDING-ERROR-RATE FAULT-KINDS fault-kind-label
         bound-copy-perfect? binding-note)

;; A gathering as it reaches the binder: what it is signed with, how many
;; leaves it has, and how many of those leaves carry a signature. `signed' is
;; the count of leaves with something in the direction line; it is zero for an
;; unsigned (π) gathering, and that zero is the only thing in this module that
;; changes a probability for a reason a source gives.
(struct quire (mark leaves signed) #:transparent)

(define (quire-unsigned? q) (zero? (quire-signed q)))

;; kind is one of 'transposed 'inverted 'omitted 'duplicated 'misplaced-leaf
(struct fault (kind at note caught?) #:transparent)

;; `order' is the sequence of quire indices as actually bound, and may repeat
;; or omit; `inverted' the positions bound the wrong way up.
(struct bound-copy (name order inverted faults) #:transparent)

(define FAULT-KINDS '(transposed inverted omitted duplicated misplaced-leaf))

(define FAULT-LABELS
  (hash 'transposed "two gatherings sewn in the wrong order"
        'inverted "a gathering folded and sewn the wrong way up"
        'omitted "a gathering wanting"
        'duplicated "a gathering bound in twice"
        'misplaced-leaf "a loose leaf refixed at the wrong level"))

(define (fault-kind-label k) (hash-ref FAULT-LABELS k (lambda () (format "~a" k))))

;; ---------------------------------------------------------------------------
;; The numbers, and what they are worth
;; ---------------------------------------------------------------------------
;; Faults per gathering per copy, before the collation check. There is no
;; source for this figure and none is claimed: it is set where a book of
;; twenty gatherings goes wrong about once in five copies before checking, and
;; much less often after, which produces a visible but unusual fault. Change
;; it freely; nothing here depends on its being right.
(define BINDING-ERROR-RATE 0.01)

;; Which fault, given that one has happened. Also unsourced. The ordering is
;; the only part with any claim on it: transposition and inversion are the two
;; the signatures were invented against, so they should be the two the binder
;; was most prone to.
(define FAULT-SHARES
  '((transposed 0.34) (inverted 0.26) (omitted 0.15)
    (duplicated 0.10) (misplaced-leaf 0.15)))

;; How much likelier an unsigned gathering is to be put in wrong. This is a
;; number, so it is a guess -- but the *relation* is Gaskell's: the signature
;; exists "to get them the right way up and in the right order", and a
;; gathering with nothing in its direction line offers the binder no help with
;; either. A preliminary series signed π is therefore the most misbindable
;; thing in a book, which is a consequence worth being able to see.
(define UNSIGNED-PENALTY 4.0)

;; And how well the warehouse's own check catches what has happened. "The
;; books were then collated to ensure that each was made up correctly"
;; (Gaskell, p. 144) -- so most gross faults never left the house, which is
;; why misbound copies are uncommon and not unknown. A missing or doubled
;; gathering is found by running a thumb down the signatures; a transposition
;; is found the same way; an inverted gathering is found by eye. All three
;; checks are the signatures again, so all three fail on an unsigned quire.
(define CAUGHT
  (hash 'omitted 0.9 'duplicated 0.85 'transposed 0.8
        'inverted 0.7 'misplaced-leaf 0.15))

(define (pick-kind g)
  (define r (rnd g))
  (let loop ([ks FAULT-SHARES] [acc 0.0])
    (cond
      [(null? ks) 'transposed]
      [(< r (+ acc (cadr (car ks)))) (car (car ks))]
      [else (loop (cdr ks) (+ acc (cadr (car ks))))])))

;; ---------------------------------------------------------------------------
;; Binding one copy
;; ---------------------------------------------------------------------------

(define (bind quires
              #:name [name "Copy"]
              #:rate [rate BINDING-ERROR-RATE]
              #:collate? [collate? #t]
              #:rng [g (make-rng 1)])
  (define n (length quires))
  (define qs (list->vector quires))
  (define order (build-list n values))
  (define inverted '())
  (define faults '())

  (define (mark-at i)
    (if (< i n) (quire-mark (vector-ref qs i)) "?"))

  ;; One roll per gathering, as it is picked off its heap.
  (for ([i (in-range n)])
    (define q (vector-ref qs i))
    (define chance
      (* rate (if (quire-unsigned? q) UNSIGNED-PENALTY 1.0)))
    (when (< (rnd g) chance)
      (define kind (pick-kind g))
      (define caught?
        (and collate?
             (< (rnd g)
                (* (hash-ref CAUGHT kind 0.5)
                   ;; the check is the signatures too, so it fails where they
                   ;; are missing
                   (if (quire-unsigned? q) 0.25 1.0)))))
      (set! faults
            (cons (fault kind (quire-mark q)
                         (format "~a (~a)" (fault-kind-label kind)
                                 (if (quire-unsigned? q)
                                     "the gathering carries no signature"
                                     (format "signed ~a" (quire-mark q))))
                         caught?)
                  faults))
      (unless caught?
        (case kind
          [(transposed)
           (define j (min (sub1 n) (add1 i)))
           (unless (= i j)
             (set! order (swap order i j)))]
          [(inverted) (set! inverted (cons i inverted))]
          [(omitted) (set! order (remove i order))]
          [(duplicated)
           (define at (or (index-of order i) 0))
           (set! order (append (take order (add1 at)) (list i)
                               (drop order (add1 at))))]
          [(misplaced-leaf) (void)]))))   ; a leaf, not a gathering: order stands

  (bound-copy name order (sort inverted <) (reverse faults)))

(define (swap xs i j)
  (define a (index-of xs i))
  (define b (index-of xs j))
  (cond
    [(or (not a) (not b)) xs]
    [else
     (for/list ([x (in-list xs)] [k (in-naturals)])
       (cond [(= k a) (list-ref xs b)] [(= k b) (list-ref xs a)] [else x]))]))

;; A copy that left the warehouse right. Faults that were caught do not count,
;; because they were put right before the book was baled up.
(define (bound-copy-perfect? bc)
  (for/and ([f (in-list (bound-copy-faults bc))]) (fault-caught? f)))

;; What the report must say beside any fault it prints.
(define (binding-note rate)
  (format
   (string-append
    "Binding faults are generated at ~a per gathering per copy. **No source "
    "consulted gives a rate.** Gaskell and McKerrow give the kinds of fault "
    "and the fact that made-up books were collated before they went out; "
    "neither gives a frequency, so this figure is a parameter and not a "
    "finding. What is not invented is the shape: signatures existed \"to get "
    "them the right way up and in the right order\" (Gaskell, p. 79), so an "
    "unsigned gathering is ~a× likelier to go in wrong here, and the "
    "warehouse's own check -- which is also the signatures -- misses it "
    "oftener.")
   (real->decimal-string rate 3) (real->decimal-string UNSIGNED-PENALTY 1)))

(module+ test
  (require rackunit)

  (define (quires n [signed 2])
    (for/list ([i (in-range n)])
      (quire (string (integer->char (+ (char->integer #\A) i))) 4 signed)))

  ;; A binder who makes no mistakes returns the book as it was gathered.
  (define clean (bind (quires 12) #:rate 0.0 #:rng (make-rng 1)))
  (check-equal? (bound-copy-order clean) (build-list 12 values))
  (check-equal? (bound-copy-faults clean) '())
  (check-true (bound-copy-perfect? clean))

  ;; With the check off and a high rate, every kind of fault the sources
  ;; describe can occur. A rate of zero would make the whole mechanism dead
  ;; and nothing would notice, which has happened four times in this program.
  (define seen
    (for*/fold ([s (hash)]) ([seed (in-range 60)])
      (for/fold ([s s]) ([f (in-list (bound-copy-faults
                                      (bind (quires 20) #:rate 0.25
                                            #:collate? #f
                                            #:rng (make-rng seed))))])
        (hash-set s (fault-kind f) #t))))
  (for ([k (in-list FAULT-KINDS)])
    (check-true (hash-ref seen k #f) (format "~a occurs" k)))

  ;; An omitted gathering really is gone, and a duplicated one really is twice
  ;; over: the fault list and the order must agree, or the report describes a
  ;; book that was not bound.
  (for ([seed (in-range 40)])
    (define bc (bind (quires 20) #:rate 0.25 #:collate? #f #:rng (make-rng seed)))
    (define kept (bound-copy-order bc))
    (define omitted
      (for/sum ([f (in-list (bound-copy-faults bc))])
        (if (eq? (fault-kind f) 'omitted) 1 0)))
    (define dup
      (for/sum ([f (in-list (bound-copy-faults bc))])
        (if (eq? (fault-kind f) 'duplicated) 1 0)))
    (check-equal? (length kept) (+ 20 dup (- omitted))
                  (format "seed ~a: the sewn order matches the faults" seed)))

  ;; The collation check catches most of what happens, so a checked book is
  ;; usually right and an unchecked one usually is not.
  (define (bad-share collate?)
    (/ (for/sum ([seed (in-range 200)])
         (if (bound-copy-perfect?
              (bind (quires 20) #:rate 0.05 #:collate? collate?
                    #:rng (make-rng seed)))
             0 1))
       200.0))
  (check-true (< (bad-share #t) (bad-share #f))
              "collating before baling up catches faults")

  ;; Gaskell's own reason for signatures, as a consequence: an unsigned
  ;; gathering goes in wrong oftener, and is put right less often when it does.
  (define (faults-of signed)
    (for/sum ([seed (in-range 300)])
      (length (bound-copy-faults
               (bind (list (quire "π" 2 signed)) #:rate 0.05
                     #:rng (make-rng seed))))))
  (check-true (> (faults-of 0) (* 2 (faults-of 2)))
              "an unsigned gathering is the most misbindable thing in a book")

  ;; And the note says out loud that the rate has no authority.
  (check-true (regexp-match? #px"No source consulted gives a rate"
                             (binding-note 0.01))))
