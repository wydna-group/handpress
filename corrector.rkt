#lang racket/base
;;; The man between the author and the compositor.
;;;
;;; There is a person in the transmission chain that a simulation built out of
;;; compositors and presses leaves out entirely, and his omission quietly
;;; flatters every spelling test ever run.
;;;
;;; Before copy went to the frames it was commonly *prepared*: "read through,
;;; corrected, and annotated -- probably by the corrector if the house was
;;; large enough to employ one" (Gaskell, p. 40). The marks survive. Harry
;;; Carter, describing the copy for Sprat's _History of the Royal Society_,
;;; notes that it is "rich in crosses to indicate page-endings, ticks changing
;;; capitals to small letters and vice versa, and brackets for
;;; paragraph-breaks", and that in the printed book "the compositors departed
;;; a good deal from the copy in spelling and the use of capitals. There seem
;;; to be the beginnings of a 'house style'" (foreword to Simpson,
;;; _Proof-Reading_, repr. 1970, p. x).
;;;
;;; The consequence for compositor analysis is uncomfortable. A spelling that
;;; differs from the author's manuscript may be the compositor's habit, or the
;;; measure, or a misreading -- or it may have been written into the copy by
;;; the corrector before any compositor saw it, in which case it is evidence
;;; of the house and not of the man, and it will be found impartially in every
;;; stint.

(require racket/string racket/list "copytext.rkt" "rng.rkt")

(provide (struct-out change) (struct-out corrector)
         make-corrector prepare-copy)

;; Words after which the house liked to see a substantive capitalised.
(define determiners
  (list "the" "a" "an" "his" "her" "my" "thy" "your" "our"
        "their" "this" "that" "these" "those" "no" "with"))

;; Forms the house preferred, imposed on the copy before setting. These are
;; house habits, not any workman's, so they appear evenly across all stints --
;; which is precisely what makes them dangerous as compositorial evidence.
(define house-forms
  (hash "murder" "murther" "murders" "murthers" "murdered" "murthered"
        "burden" "burthen" "further" "farther" "show" "shew"
        "shows" "shewes" "showed" "shewed" "vile" "vilde"
        "public" "publick" "music" "musick" "tragic" "tragick"
        "honor" "honour" "color" "colour" "labor" "labour"))

(struct change (unit before after kind) #:transparent)

(struct corrector (rng capitals house-spelling active?) #:transparent)

(define (make-corrector #:rng [g (make-rng 3)]
                        #:capitals [capitals 0.22]
                        #:house-spelling [hs 0.70]
                        #:active? [active? #t])
  (corrector g capitals hs active?))

(define word-rx #px"^([A-Za-z']+)(.*)$")

(define (match-case model form)
  (if (and (> (string-length model) 0) (char-upper-case? (string-ref model 0)))
      (string-append (string (char-upcase (string-ref form 0))) (substring form 1))
      form))

;; Prepare copy to house style before it reaches the frames.
;; Returns (values prepared-units changes).
(define (prepare-copy cr units)
  (cond
    [(not (corrector-active? cr)) (values units '())]
    [else
     (define g (corrector-rng cr))
     (define changes '())
     (define out
       (for/list ([u (in-list units)])
         (cond
           [(memq (copy-unit-kind u) '(blank prefix heading)) u]
           [else
            (define words (string-split (copy-unit-text u)))
            (define new
              (for/list ([w (in-list words)] [i (in-naturals)])
                (define m (regexp-match word-rx w))
                (cond
                  [(not m) w]
                  [else
                   (define core (cadr m))
                   (define tail (caddr m))
                   (define low (string-downcase core))
                   (cond
                     [(and (hash-has-key? house-forms low)
                           (< (rnd g) (corrector-house-spelling cr)))
                      (define n (string-append
                                 (match-case core (hash-ref house-forms low)) tail))
                      (set! changes (cons (change (copy-unit-index u) w n
                                                  'house-spelling) changes))
                      n]
                     [(and (> i 0)
                           (string=? core (string-downcase core))
                           (> (string-length core) 3)
                           (member (string-downcase
                                    (string-trim (list-ref words (sub1 i))
                                                 #px"[.,;:]" #:repeat? #t))
                                   determiners)
                           (< (rnd g) (corrector-capitals cr)))
                      (define n (string-append
                                 (string (char-upcase (string-ref core 0)))
                                 (substring core 1) tail))
                      (set! changes (cons (change (copy-unit-index u) w n
                                                  'capital) changes))
                      n]
                     [else w])])))
            (copy-unit (copy-unit-kind u) (string-join new " ")
                       (copy-unit-index u) (copy-unit-speaker u))])))
     (values out (reverse changes))]))

(module+ test
  (require rackunit)
  (define units (parse-copy "The murder of the sad king in the great hall.\n"))
  (define cr (make-corrector #:rng (make-rng 5) #:capitals 1.0 #:house-spelling 1.0))
  (define-values (prepared changes) (prepare-copy cr units))
  (define text (string-join (for/list ([u (in-list prepared)]
                                       #:unless (eq? (copy-unit-kind u) 'blank))
                              (copy-unit-text u)) " "))
  ;; The house imposes its own spelling before any compositor sees the copy.
  (check-true (regexp-match? #px"murther" text))
  ;; And capitalises substantives after a determiner.
  (check-true (regexp-match? #px"Sad|King|Great|Hall" text))
  (check-true (> (length changes) 0))
  ;; Word count is never altered by preparation.
  (check-equal?
   (for/sum ([u (in-list prepared)]) (length (string-split (copy-unit-text u))))
   (for/sum ([u (in-list units)]) (length (string-split (copy-unit-text u)))))
  ;; Switched off, it is the identity.
  (define off (make-corrector #:active? #f))
  (define-values (same none) (prepare-copy off units))
  (check-equal? same units)
  (check-equal? none '()))
