#lang racket/base
;;; Seeded randomness, kept explicit.
;;;
;;; Each workman carries his own generator, so that a run is reproducible and
;;; one man's luck does not perturb another's. Racket's generators are
;;; first-class values, which suits the model: the randomness belongs to the
;;; compositor, not to the program.

(require racket/list racket/math)

(provide make-rng rnd rnd-int rnd-choice rnd-sample rnd-beta rnd-uniform)

(define (make-rng seed)
  (define g (make-pseudo-random-generator))
  (parameterize ([current-pseudo-random-generator g])
    (random-seed (bitwise-and (abs seed) #x7FFFFFF)))
  g)

;; A real in [0,1).
(define (rnd g) (random g))

;; An integer in [0,n).
(define (rnd-int g n) (random (max 1 n) g))

(define (rnd-uniform g lo hi) (+ lo (* (- hi lo) (rnd g))))

(define (rnd-choice g xs)
  (if (null? xs) #f (list-ref xs (rnd-int g (length xs)))))

;; k distinct elements, or all of them if there are fewer.
(define (rnd-sample g xs k)
  (let loop ([pool xs] [k (min k (length xs))] [acc '()])
    (cond
      [(or (zero? k) (null? pool)) (reverse acc)]
      [else
       (define i (rnd-int g (length pool)))
       (loop (append (take pool i) (drop pool (add1 i)))
             (sub1 k)
             (cons (list-ref pool i) acc))])))

;; A crude beta variate as a ratio of gamma-ish sums. Used only to shape how
;; much of a press run was worked off before the marked proof came back, where
;; the shape matters and the tail does not.
(define (rnd-beta g a b)
  (define (gamma-ish k)
    (for/sum ([_ (in-range (max 1 (exact-round k)))])
      (- (log (max 1e-12 (rnd g))))))
  (define x (gamma-ish a))
  (define y (gamma-ish b))
  (if (zero? (+ x y)) 0.0 (/ x (+ x y))))
