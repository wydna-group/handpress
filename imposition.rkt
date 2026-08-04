#lang racket/base
;;; Format, casting off, imposition, and the skeleton forme.
;;;
;;; A book is not printed page after page. It is printed sheet by sheet, and
;;; each side of each sheet carries several pages at once, arranged so that
;;; when the sheet is folded they fall into reading order. The unit of work is
;;; therefore the *forme*, not the page.
;;;
;;; Three consequences that the New Bibliography lives on: casting off (a
;;; house setting by formes must know in advance where the copy for each page
;;; begins); signatures and catchwords (instructions to the binder, set in the
;;; direction line); and the skeleton forme (running titles and furniture
;;; lifted from one printed-off forme to the next, each title carrying its own
;;; accumulating damage, so that a broken letter recurring at intervals tells
;;; you the order in which the sheets went to press -- Hinman's method).

(require racket/list racket/string racket/math
         "metrics.rkt" "copytext.rkt" "rng.rkt")

(provide (struct-out book-format) (struct-out page-ref) (struct-out forme)
         (struct-out running-title) (struct-out skeleton)
         (struct-out cast-off-segment)
         FOLIO FOLIO-IN-SIXES QUARTO OCTAVO FORMATS
         book-format-pages signature-letter page-refs signed-leaves
         sheet-scheme formes-for-gathering setting-order
         collation-formula cast-off make-skeletons title-for
         page-ref-signature page-ref-signed skeleton-add-use!)

(define SIG-LETTERS "ABCDEFGHIKLMNOPQRSTVXYZ")  ; J, U and W are not used

;; 0 -> A, 22 -> Z, 23 -> Aa, 46 -> Aaa ...
(define (signature-letter n)
  (define len (string-length SIG-LETTERS))
  (define-values (rep idx) (quotient/remainder n len))
  (make-string (add1 rep) (string-ref SIG-LETTERS idx)))

;; NB: not named `format' -- that is Racket's string formatter, and shadowing
;; it in a module this full of report text would be a slow-burning disaster.
(struct book-format (name symbol leaves sheets columns measure-ems lines)
  #:transparent)

(define (book-format-pages f) (* 2 (book-format-leaves f)))

(define FOLIO-IN-SIXES (book-format "folio in sixes" "2°" 6 3 2 16.0 66))
(define FOLIO          (book-format "folio"          "2°" 2 1 2 16.0 66))
(define QUARTO         (book-format "quarto"         "4°" 4 1 1 21.0 38))
(define OCTAVO         (book-format "octavo"         "8°" 8 1 1 16.0 30))

(define FORMATS
  (hash "folio" FOLIO "folio6" FOLIO-IN-SIXES "folio-in-sixes" FOLIO-IN-SIXES
        "quarto" QUARTO "octavo" OCTAVO))

;; ---------------------------------------------------------------------------
;; Where each page falls on the sheet
;; ---------------------------------------------------------------------------

;; Page numbers (1-based within the gathering) on each forme of each sheet.
;; Returns a list of (cons outer-pages inner-pages).
(define (sheet-scheme f)
  (cond
    [(> (book-format-sheets f) 1)
     ;; quired in sheets: sheet k holds leaves k and (leaves + 1 - k)
     (for/list ([k (in-range 1 (add1 (book-format-sheets f)))])
       (define a k)
       (define b (- (add1 (book-format-leaves f)) k))
       (cons (list (sub1 (* 2 a)) (* 2 b))        ; recto of a, verso of b
             (list (* 2 a) (sub1 (* 2 b)))))]     ; verso of a, recto of b
    [else
     ;; a single sheet folded: the standard imposition
     (define n (book-format-pages f))
     (define outer (for/list ([p (in-range 1 (add1 n))]
                              #:when (memv (modulo p 4) '(0 1))) p))
     (define inner (for/list ([p (in-range 1 (add1 n))]
                              #:unless (memv (modulo p 4) '(0 1))) p))
     (list (cons outer inner))]))

(struct page-ref (gathering leaf recto? number) #:transparent)

(define (page-ref-signature r)
  (format "~a~a~a" (signature-letter (page-ref-gathering r))
          (page-ref-leaf r) (if (page-ref-recto? r) "r" "v")))

;; What is actually printed in the direction line, if anything.
(define (page-ref-signed r)
  (cond
    [(not (page-ref-recto? r)) ""]
    [(= (page-ref-leaf r) 1) (signature-letter (page-ref-gathering r))]
    [else (format "~a~a" (signature-letter (page-ref-gathering r))
                  (page-ref-leaf r))]))

(define (page-refs f gathering)
  (for/list ([p (in-range 1 (add1 (book-format-pages f)))])
    (page-ref gathering (quotient (add1 p) 2) (odd? p) p)))

;; The first half of the leaves of a gathering carry a signature.
(define (signed-leaves f) (max 1 (quotient (book-format-leaves f) 2)))

;; ---------------------------------------------------------------------------
;; Formes
;; ---------------------------------------------------------------------------

(struct forme (gathering sheet side page-numbers [skeleton #:mutable]
                         [order #:mutable])
  #:transparent)

(define (forme-name fm)
  (format "~a sheet ~a ~a" (signature-letter (forme-gathering fm))
          (forme-sheet fm) (forme-side fm)))

(define (formes-for-gathering f gathering)
  (append*
   (for/list ([scheme (in-list (sheet-scheme f))] [i (in-naturals 1)])
     (list (forme gathering i "inner" (sort (cdr scheme) <) #f 0)
           (forme gathering i "outer" (sort (car scheme) <) #f 0)))))

;; The order in which the pages of a gathering are actually composed. Set
;; seriatim they go 1, 2, 3 ...; set by formes the house begins at the middle
;; of the gathering, where the casting off is least likely to have gone wrong
;; yet, and works outward.
(define (setting-order f gathering by-formes?)
  (cond
    [(not by-formes?) (for/list ([p (in-range 1 (add1 (book-format-pages f)))]) p)]
    [else
     (define all
       (append* (for/list ([fm (in-list (reverse (formes-for-gathering f gathering)))])
                  (forme-page-numbers fm))))
     (remove-duplicates all)]))

(define sups (hash #\0 "⁰" #\1 "¹" #\2 "²" #\3 "³" #\4 "⁴"
                   #\5 "⁵" #\6 "⁶" #\7 "⁷" #\8 "⁸" #\9 "⁹"))

(define (sup n)
  (apply string-append
         (for/list ([ch (in-string (number->string n))]) (hash-ref sups ch))))

;; The bibliographer's shorthand for the make-up of the book.
(define (collation-formula f gatherings)
  (cond
    [(<= gatherings 0) (format "~a: (no sheets)" (book-format-symbol f))]
    [else
     (define first (signature-letter 0))
     (define last (signature-letter (sub1 gatherings)))
     (define body
       (if (= gatherings 1)
           (format "~a~a" first (sup (book-format-leaves f)))
           (format "~a–~a~a" first last (sup (book-format-leaves f)))))
     (define total (* gatherings (book-format-leaves f)))
     (format "~a: ~a  [~a leaves; ~a pages]"
             (book-format-symbol f) body total (* 2 total))]))

;; ---------------------------------------------------------------------------
;; Casting off
;; ---------------------------------------------------------------------------

(struct cast-off-segment (page-index units estimated-lines note) #:transparent)

;; Measure the copy out into pages, imperfectly.
;;
;; Casting off was done "by counting words and by computation according to the
;; sizes of type and page" (Gaskell, p. 41) -- arithmetic, not eye. But the
;; arithmetic is only as good as the copy allows, and there the *kind* of copy
;; matters more than the skill of the man:
;;
;;   "Printed copy, or the manuscript of a poem or verse play, could easily be
;;   cast off with such accuracy that the exact contents of each type page
;;   could be predicted, but a prose manuscript could be cast off with fair
;;   accuracy by a skilled man, although this was much more difficult."
;;
;; So verse is measured almost exactly and prose is not, and the strain in a
;; miscast-off gathering falls where the prose is.
(define (cast-off units measure lines-per-page g [accuracy 0.93])
  ;; How reliably each kind of copy can be measured out beforehand.
  (define slip (hash 'verse 0.06 'heading 0.30 'stage 0.45 'prose 1.0))

  (define (estimate u)
    (define kind (copy-unit-kind u))
    (cond
      [(eq? kind 'blank) 1]
      [(eq? kind 'prefix) 0]
      [else
       (define text (copy-unit-text u))
       (define w (+ (width-of-word (string-replace text " " ""))
                    (* NORMAL-SPACE
                       (length (regexp-match* #px" " text)))))
       (cond
         [(eq? kind 'verse) (if (<= w measure) 1 2)]
         [else
          (define n (max 1 (exact-ceiling (/ w measure))))
          (if (eq? kind 'heading) (+ n 2) n)])]))

  (let loop ([us units] [current '()] [used 0] [segments '()])
    (cond
      [(null? us)
       (reverse (if (null? current)
                    segments
                    (cons (cast-off-segment (length segments)
                                            (reverse current) used "")
                          segments)))]
      [else
       (define u (car us))
       (define est0 (estimate u))
       (define est
         (if (> (rnd g) (- 1.0 (* (- 1.0 accuracy)
                                  (hash-ref slip (copy-unit-kind u) 1.0))))
             (max 0 (+ est0 (rnd-choice g '(-1 1))))
             est0))
       (cond
         [(and (> (+ used est) lines-per-page) (pair? current))
          (loop us '() 0
                (cons (cast-off-segment (length segments) (reverse current) used "")
                      segments))]
         [else (loop (cdr us) (cons u current) (+ used est) segments)])])))

;; ---------------------------------------------------------------------------
;; The skeleton
;; ---------------------------------------------------------------------------

(define damage-kinds
  (list "broken serif on the H" "battered e" "the t wanting its head"
        "a nicked o" "the r bent" "the comma turned"
        "the s worn to a smudge" "a raised space that prints"
        "the d chipped at the shoulder" "the initial T cracked"
        "a wrong-fount i" "the l bruised"))

(struct running-title (text damage identifier) #:transparent)

(define (title-fingerprint t)
  (if (null? (running-title-damage t))
      "no damage noted"
      (string-join (running-title-damage t) "; ")))

(struct skeleton (name titles [used-for #:mutable]) #:transparent)

(define (title-for sk position)
  (list-ref (skeleton-titles sk) (modulo position (length (skeleton-titles sk)))))

(define (skeleton-add-use! sk name)
  (set-skeleton-used-for! sk (append (skeleton-used-for sk) (list name))))

(define (make-skeletons count titles-each head g)
  (for/list ([s (in-range count)])
    (skeleton
     (format "Skeleton ~a" (make-string (add1 s) #\I))
     (for/list ([t (in-range titles-each)])
       (running-title head
                      (rnd-sample g damage-kinds (+ 1 (rnd-int g 3)))
                      (format "~a~a" (integer->char (+ (char->integer #\I) s))
                              (add1 t))))
     '())))

(provide title-fingerprint forme-name)

(module+ test
  (require rackunit)

  ;; Quarto imposition: outer forme carries pages 1, 4, 5, 8.
  (define q (car (sheet-scheme QUARTO)))
  (check-equal? (sort (car q) <) '(1 4 5 8))
  (check-equal? (sort (cdr q) <) '(2 3 6 7))

  ;; Octavo: outer 1,4,5,8,9,12,13,16.
  (define o (car (sheet-scheme OCTAVO)))
  (check-equal? (sort (car o) <) '(1 4 5 8 9 12 13 16))

  ;; Folio in sixes is quired in three sheets; the outermost carries the
  ;; first recto and the last verso.
  (define f6 (sheet-scheme FOLIO-IN-SIXES))
  (check-equal? (length f6) 3)
  (check-equal? (sort (car (first f6)) <) '(1 12))
  (check-equal? (sort (cdr (first f6)) <) '(2 11))
  (check-equal? (sort (car (third f6)) <) '(5 8))

  ;; The general rule for a quired gathering: the two pages of any forme
  ;; number to one more than twice the pages of a leaf-pair, so on every
  ;; sheet of every format the outer forme's pages sum to pages+1, as do
  ;; the inner's. This is what makes 1 and 12 fellows in a folio in sixes.
  (for ([fmt (in-list (list QUARTO OCTAVO FOLIO-IN-SIXES))])
    (define n (add1 (book-format-pages fmt)))
    (for ([s (in-list (sheet-scheme fmt))])
      (for ([forme (in-list (list (car s) (cdr s)))])
        (for ([p (in-list forme)])
          (check-not-false (memv (- n p) forme)
                           (format "~a: page ~a should share a forme with ~a"
                                   (book-format-name fmt) p (- n p)))))))

  ;; Setting by formes begins at the middle of the gathering and works
  ;; outward, so that a sheet can be printed and distributed before the next
  ;; is begun; setting seriatim follows the copy and holds the whole
  ;; gathering standing.
  (check-equal? (setting-order FOLIO-IN-SIXES 0 #t) '(5 8 6 7 3 10 4 9 1 12 2 11))
  (check-equal? (setting-order FOLIO-IN-SIXES 0 #f) '(1 2 3 4 5 6 7 8 9 10 11 12))

  ;; Every page of a gathering belongs to exactly one forme.
  (for ([fmt (in-list (list QUARTO OCTAVO FOLIO-IN-SIXES))])
    (define pages (append* (map forme-page-numbers (formes-for-gathering fmt 0))))
    (check-equal? (sort pages <)
                  (for/list ([p (in-range 1 (add1 (book-format-pages fmt)))]) p)
                  (format "~a covers every page once" (book-format-name fmt))))

  ;; Signatures: first half of the leaves, recto only.
  (define rs (page-refs QUARTO 1))
  (check-equal? (page-ref-signature (first rs)) "B1r")
  (check-equal? (page-ref-signature (second rs)) "B1v")
  (check-equal? (page-ref-signed (first rs)) "B")
  (check-equal? (page-ref-signed (third rs)) "B2")
  (check-equal? (page-ref-signed (second rs)) "" "versos are not signed")

  ;; J, U and W are skipped in the signature alphabet.
  (check-equal? (signature-letter 8) "I")
  (check-equal? (signature-letter 9) "K")
  (check-equal? (collation-formula QUARTO 2) "4°: A–B⁴  [8 leaves; 16 pages]")

  ;; Setting by formes visits every page exactly once, in a different order.
  (define so (setting-order QUARTO 0 #t))
  (check-equal? (sort so <) '(1 2 3 4 5 6 7 8))
  (check-false (equal? so '(1 2 3 4 5 6 7 8)))
  (check-equal? (setting-order QUARTO 0 #f) '(1 2 3 4 5 6 7 8)))
