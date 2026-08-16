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
         "../shop.rkt" "../book.rkt" "../formeorder.rkt" "../imposition.rkt"
         "../recurrence.rkt" "../analysis.rkt")

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

;; ---------------------------------------------------------------------------
;; The other instruments
;; ---------------------------------------------------------------------------
;; Hinman's criterion is not the only inference in the report that scores itself
;; against a truth, and one arm collapsing says nothing about the others. Turner
;; reads the same type evidence and should move with it; attribution reads
;; SPELLINGS and has no reason to, until the crew is shared. Reporting the
;; forme-order collapse alone would invite the reading that "the analysis" fails,
;; when what has been shown is that one inference does.

(define (turner-score b)
  (define tbl (turner-table (recurrence-evidence (book-case b) #:job (book-job b))
                            (page-views b)))
  (define truth (true-first-forme (book-fmt b) (book-by-formes? b)))
  (define fired (filter turner-pair-pattern? tbl))
  (values (length fired)
          (for/sum ([tp (in-list fired)])
            (if (equal? (turner-pair-first-forme tp) truth) 1 0))))

(define (attribution-score b)
  (define ev (spelling-evidence b '("A" "B")))
  (define judged (filter (lambda (e) (not (string=? (page-evidence-verdict e) "?"))) ev))
  (values (length judged) (length (filter resolved? judged))))

(printf "\n\nTHE OTHER SCORED INFERENCES, same arms\n\n")
(define (both label mk)
  (define tf 0) (define tr 0) (define aj 0) (define ar 0)
  (define sg 0) (define st 0) (define sok 0)
  (for ([sd (in-list SEEDS)])
    (define b (mk sd))
    (define-values (f r) (turner-score b))
    (define-values (j k) (attribution-score b))
    (define-values (got used) (skeleton-recovery b))
    (set! tf (+ tf f)) (set! tr (+ tr r)) (set! aj (+ aj j)) (set! ar (+ ar k))
    (set! sg (+ sg got)) (set! st (+ st used))
    (when (= got used) (set! sok (add1 sok))))
  (printf "~a\n" label)
  (printf "    Turner's rule fired ~a, named the first forme rightly ~a (~a%)\n"
          tf tr (if (zero? tf) 0 (exact-round (* 100.0 (/ tr tf)))))
  (printf "    attribution judged ~a pages, resolved ~a (~a%)\n"
          aj ar (if (zero? aj) 0 (exact-round (* 100.0 (/ ar aj)))))
  (printf "    skeletons recovered ~a where the house used ~a; agreed on ~a of ~a books\n\n"
          sg st sok (length SEEDS)))

(both "1. one book alone -- the control" (lambda (sd) (build sd)))
(both "3. one book, fount at a half" (lambda (sd) (build sd #:scale 0.5)))
(both "5. eight sheets of other work, sharing the house's metal"
      (lambda (sd) (build sd #:ballast '(8))))
(both "6. forty-six sheets of other work, sharing the house's metal"
      (lambda (sd) (build sd #:ballast '(20 12 8 6))))

(printf "THE OBJECTION DOES NOT FALL EQUALLY ON ALL BIBLIOGRAPHICAL EVIDENCE, and\n")
(printf "that is the result worth carrying away from this file.\n\n")
(printf "  Everything built on the MOVEMENT OF METAL collapses together: Hinman's\n")
(printf "  criterion excludes the true order, and Turner's rule stops firing at\n")
(printf "  all. Both read where a piece of type has been, and under shortage it\n")
(printf "  has been somewhere the rule assumes it cannot have been.\n\n")
(printf "  Everything built on a WORKMAN'S HABITS sits still. Attribution reads\n")
(printf "  spellings and does not move -- not under other work in the house, and\n")
(printf "  not under a fount halved either, though `supply-factor' lets a thin\n")
(printf "  case push a man's spelling about. It was worth testing directly: if\n")
(printf "  shortage made two men spell alike it would degrade without the crew\n")
(printf "  being shared at all. It does not; if anything it helps.\n\n")
(printf "  The skeletons are a third case and a warning. They read running\n")
(printf "  titles rather than type, do not move under any arm here, and are\n")
(printf "  already wrong in the control at this format -- recovering about two\n")
(printf "  and a half times the skeletons the house used in folio in sixes,\n")
(printf "  where quarto recovers them exactly. That is a defect this sweep\n")
(printf "  found and did not cause, and it is not a concurrency result.\n")
