#lang racket/base
;;; What concurrent production does to Hinman's forme-order criterion.
;;;
;;;     racket tools/measure-concurrency.rkt [seeds]
;;;
;;; Roadmap §8. The question is McKenzie's: he says a shop worked several books
;;; at once and that the resulting patterns are "of such an unpredictable
;;; complexity ... that no amount of inference from what we think of as
;;; bibliographical evidence could ever have led to their reconstruction"
;;; (Printers of the Mind, SB 22 (1969), p. 7). This scores that against a truth
;;; the simulator holds and a library cannot.
;;;
;;; THE INSTRUMENT IS HINMAN'S OWN and it is already built. He does not score
;;; orders; he prohibits them (i. 80): "the second of two consecutive Folio
;;; formes was set before the first was distributed, and hence THE TWO CANNOT
;;; ORDINARILY HAVE TYPES IN COMMON ... whenever there is ONLY ONE order in
;;; which none of the types in the quire appear in consecutive formes, this
;;; order may confidently be taken as the one actually followed."
;;;
;;; So the criterion has two failure modes and they mean opposite things, which
;;; is why they are counted apart here:
;;;
;;;   NONE ADMISSIBLE   shared type forbids every arrangement, so the true order
;;;                     is excluded along with the rest. The analyst concludes
;;;                     the quire is impossible.
;;;   SEVERAL           the prohibitions are too few to single one out. The
;;;                     analyst concludes nothing, and knows he has concluded
;;;                     nothing.
;;;
;;; A report that added them together would say "the inference got worse" and
;;; hide which way.
;;;
;;; THE CONTROL IS THE SHOP WITH ONE JOB, not the ordinary single-book path, so
;;; that the only thing varying between arms is the other work in the house.
;;; `shop.rkt' has a test pinning those two to the same type on every page.
;;;
;;; Scored across seeds and never within one: a seed names a run of the random
;;; stream, and interleaving consumes the shared case's stream in a different
;;; order, so a per-seed difference would be mostly re-randomisation.
;;;
;;; FOLIO IN SIXES, because a quarto gathering has two formes and the criterion
;;; wants four before it can tell an order from its reverse. Run in quarto it
;;; reads zero in every arm, which is the instrument never being asked rather
;;; than the inference failing -- and this file exists partly because that zero
;;; was nearly reported as a collapse.

(require racket/list racket/file racket/math racket/set racket/runtime-path
         "../shop.rkt" "../book.rkt" "../formeorder.rkt" "../imposition.rkt")

(define-runtime-path copy-file "../samples/areopagitica.txt")
(define txt (file->string copy-file))

(define SEEDS
  (let ([a (current-command-line-arguments)])
    (if (zero? (vector-length a))
        '(1 2 3 5 8 13 21 34)
        (for/list ([i (in-range (string->number (vector-ref a 0)))]) (add1 i)))))

(define (build seed #:scale [scale 1.0] #:ballast [ballast '()]
               #:shared-ceiling? [ceil? #t])
  (define h (make-house #:fmt FOLIO-IN-SIXES #:seed seed
                        #:compositors '("A" "B") #:case-scale scale))
  (shop-result-book
   (run-shop (make-shop h txt 'prose #:ballast ballast
                        #:shared-ceiling? ceil?))))

;; Hinman's premise, counted directly: how often do two formes set one after the
;; other actually have type in common? He says they cannot ordinarily.
(define (adjacent-sharing b)
  (define pieces (forme-pieces b))
  (define order (map forme-name (sort (book-formes b) < #:key forme-order)))
  (define pairs (for/list ([a (in-list order)] [c (in-list (cdr order))]) (cons a c)))
  (values (for/sum ([p (in-list pairs)])
            (if (positive? (set-count
                            (set-intersect (hash-ref pieces (car p) (set))
                                           (hash-ref pieces (cdr p) (set)))))
                1 0))
          (length pairs)))

(define (verdicts b)
  (for/list ([q (in-list (read-quires b))])
    (define os (quire-reading-orders q))
    (cond [(not os) 'too-big]
          [(null? os) 'none]
          [(= 1 (length os)) (if (quire-reading-right? q) 'right 'wrong)]
          [else 'several])))

(define (arm label mk)
  (define vs '())
  (define shared 0)
  (define pairs 0)
  (for ([sd (in-list SEEDS)])
    (define b (mk sd))
    (set! vs (append vs (verdicts b)))
    (define-values (s n) (adjacent-sharing b))
    (set! shared (+ shared s))
    (set! pairs (+ pairs n)))
  (define (n k) (length (filter (lambda (x) (eq? x k)) vs)))
  (printf "~a\n" label)
  (printf "    consecutive formes sharing type   ~a of ~a (~a%)\n"
          shared pairs (if (zero? pairs) 0 (exact-round (* 100.0 (/ shared pairs)))))
  (printf "    quires the criterion could judge  ~a\n" (length vs))
  (printf "      none admissible (truth excluded)  ~a\n" (n 'none))
  (printf "      one, and RIGHT                    ~a\n" (n 'right))
  (printf "      one, and wrong                    ~a\n" (n 'wrong))
  (printf "      several                           ~a\n\n" (n 'several)))

(printf "\nHINMAN'S FORME-ORDER CRITERION UNDER CONCURRENT PRODUCTION\n")
(printf "~a seeds, folio in sixes, two compositors.\n\n" (length SEEDS))

(arm "1. one book alone, full fount -- the control"
     (lambda (sd) (build sd)))
(arm "2. one book, fount at three quarters"
     (lambda (sd) (build sd #:scale 0.75)))
(arm "3. one book, fount at a half"
     (lambda (sd) (build sd #:scale 0.5)))
(arm "4. eight sheets of other work; case shared, metal NOT pooled"
     (lambda (sd) (build sd #:ballast '(8) #:shared-ceiling? #f)))
(arm "5. eight sheets of other work, sharing the house's metal"
     (lambda (sd) (build sd #:ballast '(8))))
(arm "6. forty-six sheets of other work, sharing the house's metal"
     (lambda (sd) (build sd #:ballast '(20 12 8 6))))

(printf "Read arms 4 and 5 together. They differ only in whether the other work's\n")
(printf "standing type counts against the house's fount, and that is the whole of\n")
(printf "the effect: type travelling out to another job and back leaves the\n")
(printf "criterion standing, and the same job holding metal destroys it.\n")
