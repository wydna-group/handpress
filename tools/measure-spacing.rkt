#lang racket/base
;;; What the space-ladder does to a book, in the two quantities a real book can
;;; be measured for.
;;;
;;; Both of these decided the ladder in `metrics.rkt', and neither is visible
;;; in the report, so without this they had to be recomputed by hand every time
;;; the question came up -- which is how the 13.2% figure came to be quoted
;;; against a sample nobody could reproduce.
;;;
;;;   internal space   the white between words as a share of the type area.
;;;                    Blayney's ten 20-line samples off _Lear_ give about 9%
;;;                    (Roadmap §4).
;;;
;;;   word division    divisions per 100 lines. Measured off the whole Norton
;;;                    Facsimile, 790 plates and 101,006 lines: 2.03 for the
;;;                    book, but 6.41 for the three prose plays and 0.40 for the
;;;                    verse ones, because verse turns over where prose divides.
;;;                    **Compare against the row that matches the sample.** A
;;;                    prose sample judged against the whole-book 2.03 will look
;;;                    three times too loose, and the single-sample 5.1 this was
;;;                    calibrated on for months was 2.5x the book for the same
;;;                    reason.
;;;
;;; A fresh book per seed, deliberately. `run-press' wears the type it prints
;;; from, so a book reused across seeds accumulates damage and the later runs
;;; are not draws from the same distribution as the earlier ones -- which is a
;;; live trap, having already made one test in `press.rkt' depend on the order
;;; its assertions were written in.
;;;
;;;   racket tools/measure-spacing.rkt [samples/ado/_all-q1600.txt]

(require racket/file racket/list racket/math racket/string racket/cmdline
         "../metrics.rkt" "../book.rkt" "../compositor.rkt"
         "../imposition.rkt" "../deviation.rkt" "../copytext.rkt")

(define SEEDS '(5 6 7 8))

(define (mean xs) (/ (apply + xs) (length xs)))
(define (d2 x) (real->decimal-string x 2))
(define (d3 x) (real->decimal-string x 3))

;; Internal space as a share of the type area, and the mean gap that makes it.
;; Blank lines carry no gaps and are skipped; the denominator is the width
;; actually set, so a quadded-out last line contributes its quads to neither.
(define (space-share b)
  (for*/fold ([sp 0] [tot 0] [gaps 0] #:result (values sp tot gaps))
             ([pg (in-list (book-pages b))]
              [col (in-list (page-columns pg))]
              [l (in-list col)]
              #:unless (null? (set-line-words l)))
    (values (+ sp (apply + (set-line-spaces l)))
            (+ tot (line-set-width l))
            (+ gaps (length (set-line-spaces l))))))

(define (report txt fmt-name fmt)
  (printf "\n~a\n" fmt-name)
  (define rows
    (for/list ([seed (in-list SEEDS)])
      (define house (make-house #:fmt fmt #:compositors '("A" "B") #:seed seed))
      ;; One book for the spacing, a second for the deviation counts, because
      ;; `deviation-counts' is taken over a book that has not been to press.
      (define b (set-book house txt 'prose))
      (define-values (sp tot gaps) (space-share b))
      (define counts (deviation-counts b))
      (list seed
            (* 100.0 (/ sp tot))
            (ems (/ sp (max 1 gaps)))
            (* 100.0 (/ (hash-ref counts 'divided) (hash-ref counts 'lines)))
            (hash-ref counts 'lines))))
  (printf "  seed   internal space   mean gap   div/100 lines   lines\n")
  (for ([r (in-list rows)])
    (printf "  ~a      ~a%           ~a em      ~a            ~a\n"
            (first r) (d2 (second r)) (d3 (third r)) (d2 (fourth r)) (fifth r)))
  (printf "  mean   ~a%           ~a em      ~a\n"
          (d2 (mean (map second rows)))
          (d3 (mean (map third rows)))
          (d2 (mean (map fourth rows))))
  rows)

(module+ main
  (define file
    (command-line #:args ([f "samples/ado/_all-q1600.txt"]) f))
  (define txt (file->string file))
  (printf "~a\n" file)
  (printf "ladder ~a em   normal ~a em   finest ~a em\n"
          (map (lambda (u) (d3 (ems u))) SPACE-LADDER)
          (d3 (ems NORMAL-SPACE))
          (d3 (ems FINEST-SPACE)))
  (define q (report txt "quarto" QUARTO))
  (define o (report txt "octavo" OCTAVO))
  (printf "\nagainst the measurements\n")
  (printf "  internal space   ~a%  here, ~a% off _Lear_ (Blayney)\n"
          (d2 (mean (map second (append q o)))) "9.00")
  (printf "  div/100 lines    ~a  here, ~a off the Folio's prose plays (Norton)\n"
          (d2 (mean (map fourth (append q o)))) "6.41")
  (printf "\nThe sample above is prose, so 6.41 is its row and not the whole\n")
  (printf "book's 2.03. Neither figure is a target to tune to: the residual is\n")
  (printf "§5's, and what it should buy is about 0.6 em a line.\n"))
