#lang racket/base

;;; Paging the book, and getting it wrong.
;;;
;;; The page number is not a property of the page. It is a piece of type in the
;;; headline, set beside the running title and lifted from forme to forme with
;;; the rest of the skeleton -- which is why Hinman finds page-number errors
;;; clustering with running-title and signature peculiarities, and why they can
;;; be used, like a damaged running title, as evidence of the order in which
;;; formes went to press.
;;;
;;; The First Folio is the standard example of how badly this could go. Its
;;; Tragedies run 1-76, then 79-82, then 81-98, then an unpaged leaf, then
;;; 109-56, and then 257-399: pages 77-78 skipped, 81-82 used twice, 99-100
;;; omitted, 101-8 and 157-256 never used at all. The Histories carry two
;;; separate sequences paged 69-100.
;;;
;;; Hinman's distinction is the useful one, and it is preserved here:
;;;
;;;   omission     a number, or a run of them, simply not used. The compositor
;;;                skipped ahead -- usually because he was setting by formes
;;;                and guessed how much lay between. These are the informative
;;;                ones: a gap says something about what was set when.
;;;
;;;   commission   a positive error, a wrong number set. Quire q of the Folio
;;;                has q1v paged 168 for 166, and q1 then paged 167 for 165 --
;;;                the mistake propagates forward until something corrects it,
;;;                because the next number is taken from the last.
;;;
;;; To which the sheets add two more that need no explanation: a leaf left
;;; unpaged, and a number whose digits were transposed or turned in the stick.

(require racket/list racket/string racket/math
         "rng.rkt" "imposition.rkt")

(provide (struct-out folio-number) paginate pagination-report
         pagination-errors)

;; `printed' is what stands in the headline; `want' is what should have. They
;; differ only where something went wrong, and `note' says what.
(struct folio-number (sig want printed note) #:transparent)

(define (transpose-digits s g)
  (cond
    [(< (string-length s) 2) s]
    [else
     (define i (rnd-int g (sub1 (string-length s))))
     (string-append (substring s 0 i)
                    (string (string-ref s (add1 i)))
                    (string (string-ref s i))
                    (substring s (+ i 2)))]))

;; Turned type in a number reads as another number: 6 upside down is 9, and 9
;; is 6. This is the numeral equivalent of the turned letter, and no rarer.
(define (turn-digit s g)
  (define ps (for/list ([c (in-string s)] [i (in-naturals)]
                        #:when (memv c '(#\6 #\9)))
               i))
  (cond
    [(null? ps) s]
    [else
     (define i (rnd-choice g ps))
     (string-append (substring s 0 i)
                    (if (char=? (string-ref s i) #\6) "9" "6")
                    (substring s (add1 i)))]))

;; Number a run of leaves, imperfectly.
;;
;; `rate' scales every kind of mishap at once; at 0 the book is paged
;; correctly throughout, which no hand-press book of any length ever was.
;; `recto-only?' pages the rectos alone, as many books of the period do.
(define (paginate refs
                  #:start [start 1]
                  #:rate [rate 0.04]
                  #:recto-only? [recto-only? #f]
                  #:rng [g (make-rng 1623)])
  (let loop ([rs refs] [next start] [out '()])
    (cond
      [(null? rs) (reverse out)]
      [else
       (define r (car rs))
       (define sig (page-ref-signature r))
       (cond
         ;; a leaf that carries no number at all
         [(or (and recto-only? (not (page-ref-recto? r)))
              (< (rnd g) (* rate 0.25)))
          (loop (cdr rs) (add1 next)
                (cons (folio-number sig next "" "unpaged") out))]
         [else
          (define roll (rnd g))
          (cond
            ;; OMISSION: the compositor jumps ahead, having cast off badly or
            ;; guessed at what lay between. The numbers skipped are never used.
            [(< roll (* rate 0.30))
             (define gap (add1 (rnd-int g 3)))
             (loop (cdr rs) (+ next gap 1)
                   (cons (folio-number sig next (number->string next)
                                       (format "~a number(s) skipped after this"
                                               gap))
                         out))]
            ;; REPETITION: he goes back over ground already numbered, and a
            ;; run of pages carries numbers used once before.
            [(< roll (* rate 0.45))
             (define back (add1 (rnd-int g 2)))
             (define shown (max 1 (- next back)))
             (loop (cdr rs) (add1 shown)
                   (cons (folio-number sig next (number->string shown)
                                       "a number already used")
                         out))]
            ;; COMMISSION: a wrong number, which the next page then follows,
            ;; because a compositor takes his number from the last one set and
            ;; not from a count of the leaves.
            [(< roll (* rate 0.65))
             (define wrong (+ next (rnd-choice g '(-2 -1 1 2))))
             (loop (cdr rs) (add1 wrong)
                   (cons (folio-number sig next (number->string (max 1 wrong))
                                       "wrong number set; the error carries on")
                         out))]
            ;; the digits transposed in the stick
            [(< roll (* rate 0.85))
             (define t (transpose-digits (number->string next) g))
             (loop (cdr rs) (add1 next)
                   (cons (folio-number sig next t
                                       (if (string=? t (number->string next))
                                           ""
                                           "digits transposed"))
                         out))]
            ;; a turned 6 or 9
            [(< roll rate)
             (define t (turn-digit (number->string next) g))
             (loop (cdr rs) (add1 next)
                   (cons (folio-number sig next t
                                       (if (string=? t (number->string next))
                                           ""
                                           "a turned figure: 6 for 9, or 9 for 6"))
                         out))]
            [else
             (loop (cdr rs) (add1 next)
                   (cons (folio-number sig next (number->string next) "") out))])])])))

(define (pagination-errors ns)
  (filter (lambda (n) (not (string=? (folio-number-note n) ""))) ns))

;; What the sequence looks like written out, in the manner of a collation:
;; runs of consecutive numbers, with the breaks named.
(define (pagination-summary ns)
  (define shown
    (for/list ([n (in-list ns)] #:unless (string=? (folio-number-printed n) ""))
      (string->number (folio-number-printed n))))
  (define nums (filter values shown))
  (cond
    [(null? nums) "unpaged throughout"]
    [else
     (let loop ([xs (cdr nums)] [from (car nums)] [prev (car nums)] [runs '()])
       (cond
         [(null? xs)
          (string-join
           (reverse (cons (if (= from prev)
                              (number->string from)
                              (format "~a-~a" from prev))
                          runs))
           ", ")]
         [(= (car xs) (add1 prev)) (loop (cdr xs) from (car xs) runs)]
         [else
          (loop (cdr xs) (car xs) (car xs)
                (cons (if (= from prev)
                          (number->string from)
                          (format "~a-~a" from prev))
                      runs))]))]))

(define (pagination-report ns)
  (define bad (pagination-errors ns))
  (define unpaged (filter (lambda (n) (string=? (folio-number-printed n) "")) ns))
  (string-join
   (append
    (list "THE PAGING, AND WHERE IT FAILS"
          ""
          "  The page number is a piece of type in the headline, set beside"
          "  the running title and carried from forme to forme with the rest"
          "  of the skeleton. So its errors keep company with the running"
          "  titles and the signatures, and like them they can be evidence of"
          "  the order in which the formes were worked."
          ""
          (format "  Paged: ~a" (pagination-summary ns))
          ""
          ;; Pages, not leaves. `paginate' is handed one page-ref per page and
          ;; numbers both sides unless `recto-only?' is set, which is the
          ;; difference between pagination and foliation. Calling the result
          ;; leaves put 63 of them in a 32-leaf quarto, which is not a number
          ;; any book could have.
          (format "  ~a ~a numbered, ~a unnumbered, ~a error(s)"
                  (- (length ns) (length unpaged))
                  (if (for/or ([n (in-list ns)])
                        (string-suffix? (folio-number-sig n) "v"))
                      "pages" "leaves")
                  (length unpaged) (length bad))
          "")
    (if (null? bad)
        (list "  The paging is correct throughout, which for a book of any"
              "  length would itself be remarkable.")
        (for/list ([n (in-list (take bad (min 14 (length bad))))])
          (format "    ~a  ~a for ~a   ~a"
                  (~sig (folio-number-sig n))
                  (~num (if (string=? (folio-number-printed n) "")
                            "—" (folio-number-printed n)))
                  (~num (number->string (folio-number-want n)))
                  (folio-number-note n))))
    (list ""
          "  Hinman's distinction is worth keeping. A number simply not used"
          "  is an error of omission, and those are the informative ones: the"
          "  gap says something about what had been set when. A wrong number"
          "  set is an error of commission, and it propagates, because the"
          "  next number is taken from the last one set rather than from any"
          "  count of the leaves."))
   "\n"))

(define (~sig s) (string-append s (make-string (max 0 (- 8 (string-length s))) #\space)))
(define (~num s) (string-append (make-string (max 0 (- 5 (string-length s))) #\space) s))

(module+ test
  (require rackunit)

  ;; A correctly paged book, to show the machinery is not inventing trouble.
  (define clean (paginate (page-refs QUARTO 0) #:rate 0.0 #:rng (make-rng 1)))
  (check-equal? (map folio-number-printed clean) '("1" "2" "3" "4" "5" "6" "7" "8"))
  (check-equal? (pagination-errors clean) '())

  ;; and a badly paged one
  (define refs (append* (for/list ([g (in-range 12)]) (page-refs QUARTO g))))
  (define bad (paginate refs #:rate 0.25 #:rng (make-rng 7)))
  (check-true (> (length (pagination-errors bad)) 0) "errors occur")

  ;; An error of commission carries forward: the page after a wrong number
  ;; follows it rather than returning to the true count. This is why one slip
  ;; in quire q of the Folio put every following number out by two.
  (let* ([ns (paginate refs #:rate 0.5 #:rng (make-rng 3))]
         [commissions (for/list ([n (in-list ns)]
                                 #:when (regexp-match? #rx"carries on"
                                                       (folio-number-note n)))
                        n)])
    (when (pair? commissions)
      (define i (for/first ([n (in-list ns)] [j (in-naturals)]
                            #:when (eq? n (car commissions)))
                  j))
      (when (< (add1 i) (length ns))
        (define after (list-ref ns (add1 i)))
        (check-not-equal? (folio-number-want after)
                          (add1 (folio-number-want (car commissions)))
                          "the count does not silently repair itself"))))

  ;; Turned figures read as other figures, which is the numeral's version of
  ;; the turned letter. Which of the two turns is a matter of the draw, so the
  ;; property is asserted rather than one outcome of it.
  (let ([t (turn-digit "169" (make-rng 1))])
    (check-not-equal? t "169" "a 6 or a 9 was turned")
    (check-not-false (member t '("199" "166")) "and turned into the other figure"))
  (check-equal? (turn-digit "1234" (make-rng 1)) "1234"
                "a number with no 6 or 9 cannot be turned")

  (let ([t (transpose-digits "123" (make-rng 2))])
    (check-not-equal? t "123" "two figures changed places")
    (check-equal? (sort (string->list t) char<?) '(#\1 #\2 #\3)
                  "and the same figures are still there")))
