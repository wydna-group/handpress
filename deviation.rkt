#lang racket/base

;;; Every way the printed page can depart from its copy, counted.
;;;
;;; The classification is not a list drawn up from reading; it is the shape of
;;; the process itself. A word passes through the house in stages, and this
;;; module records what each stage did to it:
;;;
;;;   copy      what the manuscript or printed exemplar said
;;;    |  the corrector marks up the copy         PREPARATION
;;;   read      what the compositor took it for
;;;    |  he misreads, or his eye slips           MISREADING
;;;   habit     what he would set left to himself
;;;    |  his own spelling preferences            HABIT
;;;   final     what the measure will allow
;;;    |  he lengthens or shortens to fit         FITTING
;;;   composed  what stands in the stick
;;;    |  the case betrays him                    ACCIDENT
;;;   printed   what the sheet shows
;;;    |  the reader mends some of it             CORRECTION
;;;
;;; Two further kinds are not properties of a word at all and are counted
;;; separately: what happens to a LINE (division, turning over, verse run on
;;; as prose) and what happens to a PAGE (crowding, spinning out, copy left
;;; out for want of room).
;;;
;;; The rates are observed, not configured. That distinction is the whole
;;; point of measuring them. A compositor does not decide to abbreviate three
;;; words in a thousand; he abbreviates when a line will not come out, and how
;;; often that happens depends on the measure he is setting to, the format, the
;;; accuracy of the casting off, and the words the author happened to use. Set
;;; the same copy in octavo instead of folio and every figure here moves,
;;; because a folio page holds four times the text of an octavo one and is cast
;;; off in quite different lengths.
;;;
;;; So this report says what a particular book turned out like. It is evidence
;;; about that run. Read across runs it shows which devices are forced by the
;;; measure and which are the man's own, which is the distinction Hinman warns
;;; cannot be made from a single book (i. 186-7).

(require racket/list racket/string racket/format racket/math
         "compositor.rkt" "book.rkt" "press.rkt" "imposition.rkt"
         (only-in "orthography.rkt" strip-conventions))

(provide deviation-report deviation-counts word-deviation)

;; What happened to this one word, in the order it happened, so that a reader
;; hovering over it is told which stage of the process put it there. Returns
;; #f for a word that stands exactly as the copy had it.
(define (word-deviation w)
  (define (d a b) (and a b (not (string=? a b))))
  ;; A divided word is not a corrupt one. Both halves carry the whole word as
  ;; their copy reading, so every comparison against `copy' reports a change
  ;; that never happened -- and the first version of this said `misread' over
  ;; every hyphen in the book. Division is a fact about the line, not the
  ;; reading, and it is named as such.
  (define divide-note
    (for/or ([c (in-list (word-causes w))])
      (and (regexp-match? #rx"divid" c)
           (format "division: ~a of “~a”"
                   (if (regexp-match? #rx"second half" c) "second half" "first half")
                   (word-copy w)))))
  (define notes
    (append
     (if divide-note (list divide-note) '())
     (if (and (not divide-note) (d (word-copy w) (word-read w)))
         (list (format "misreading: copy “~a” → read “~a”"
                       (word-copy w) (word-read w)))
         '())
     (if (d (word-read w) (word-habit w))
         (list (format "habit: “~a” → “~a”" (word-read w) (word-habit w))) '())
     (if (d (word-habit w) (word-final w))
         (list (format "justification: “~a” → “~a”" (word-habit w) (word-final w)))
         '())
     (if (d (word-composed w) (word-printed w))
         (list (format "foul case: “~a” set for “~a”"
                       (word-printed w) (word-composed w)))
         '())
     ;; the device that did it, in the compositor's own terms
     (for/list ([c (in-list (word-causes w))]
                #:unless (regexp-match? #rx"divid" c))
       c)))
  (cond
    [(pair? notes) (string-join notes "; ")]
    [(and (not divide-note)
          (d (strip-conventions (word-copy w)) (strip-conventions (word-printed w))))
     (format "copy “~a” → printed “~a”" (word-copy w) (word-printed w))]
    [(d (word-copy w) (word-printed w))
     "conventions of the house: long s, u for v, i for j"]
    [else #f]))

;; Which of the stages to colour it by, for the page itself.
(define (deviation-class w)
  (cond
    ;; division first, or a hyphenated word is coloured as a corruption
    [(divided? w) "dev-divided"]
    [(and (word-copy w) (word-read w)
          (not (string=? (word-copy w) (word-read w)))) "dev-misread"]
    [(and (word-composed w) (word-printed w)
          (not (string=? (word-composed w) (word-printed w)))) "dev-accident"]
    [(and (word-habit w) (word-final w)
          (not (string=? (word-habit w) (word-final w)))) "dev-fit"]
    [(and (word-read w) (word-habit w)
          (not (string=? (word-read w) (word-habit w)))) "dev-habit"]
    [else ""]))

(provide deviation-class)

(define (pct n d) (if (zero? d) 0.0 (* 100.0 (/ (exact->inexact n) d))))
(define (per-1000 n d) (if (zero? d) 0.0 (* 1000.0 (/ (exact->inexact n) d))))

;; A divided word keeps the whole word as its copy reading in both halves, so
;; it disagrees with every later stage without anything having gone wrong.
(define (divided? w)
  (ormap (lambda (c) (regexp-match? #rx"divid" c)) (word-causes w)))

(define (differs? a b)
  (and a b (not (string=? (string-downcase a) (string-downcase b)))))

(define (deviation-counts b [r #f])
  (define words
    (for*/list ([p (in-list (book-pages b))]
                [l (in-list (page-all-lines p))]
                [w (in-list (set-line-words l))])
      w))
  (define lines
    (for*/list ([p (in-list (book-pages b))]
                [l (in-list (page-all-lines p))])
      l))
  (define n (length words))

  (define (count-stage from to)
    (for/sum ([w (in-list words)])
      (if (and (not (divided? w)) (differs? (from w) (to w))) 1 0)))

  (define (lines-with rx)
    (for/sum ([l (in-list lines)])
      (if (ormap (lambda (w) (ormap (lambda (c) (regexp-match? rx c))
                                    (word-causes w)))
                 (set-line-words l))
          1 0)))

  (hash
   'words n
   'lines (length lines)
   'pages (length (book-pages b))
   ;; the stages
   'misreading (count-stage word-copy word-read)
   'habit      (count-stage word-read word-habit)
   'fitting    (count-stage word-habit word-final)
   'accident   (count-stage word-composed word-printed)
   ;; any departure at all, word by word
   'any (for/sum ([w (in-list words)])
          (if (and (not (divided? w)) (differs? (word-copy w) (word-printed w)))
              1 0))
   ;; what happened to lines
   'divided   (for/sum ([w (in-list words)])
                (if (ormap (lambda (c) (regexp-match? #rx"divided at" c))
                           (word-causes w)) 1 0))
   'turned-over (for/sum ([l (in-list lines)])
                  (if (set-line-turned-over? l) 1 0))
   ;; Only a verse line can be turned over: prose that overruns is simply
   ;; wrapped. So a book with no verse in it cannot show the device, and a
   ;; zero here would mean nothing at all -- which is how the author came to
   ;; record it as a dead mechanism in the roadmap when it was merely
   ;; inapplicable to every text he had tried.
   'verse-lines (for/sum ([l (in-list lines)])
                  (if (eq? (set-line-kind l) 'verse) 1 0))
   'quadded     (for/sum ([l (in-list lines)]) (if (set-line-quadded? l) 1 0))
   ;; Lines on which the compositor had to do something to the words to make
   ;; the measure come out -- not merely lines that were spaced. Every line in
   ;; a justified setting is spaced, so counting those told us the line count
   ;; back and nothing else.
   'expedient (for/sum ([l (in-list lines)])
                (if (for/or ([w (in-list (set-line-words l))])
                      (and (not (divided? w))
                           (differs? (word-habit w) (word-final w))))
                    1 0))
   ;; Purely conventional differences: long s, u for v, i for j. These are not
   ;; errors and not choices, but they are far the commonest way the print
   ;; departs from its copy, and without them the arithmetic below does not
   ;; add up.
   'conventions (for/sum ([w (in-list words)])
                  (if (and (not (divided? w))
                           (differs? (word-copy w) (word-printed w))
                           (not (differs? (strip-conventions (word-copy w))
                                          (strip-conventions (word-printed w)))))
                      1 0))
   ;; what happened to pages
   'crowded   (for/sum ([p (in-list (book-pages b))])
                (if (> (page-pressure p) 0) 1 0))
   'spun-out  (for/sum ([p (in-list (book-pages b))])
                (if (< (page-pressure p) 0) 1 0))
   'omitted   (for/sum ([p (in-list (book-pages b))]) (length (page-omitted p)))
   ;; before the compositor, and after him
   'prepared  (length (book-preparation b))
   'variants  (if r
                  (for*/sum ([(nm s) (in-hash (press-run-states r))]
                             [v (in-list (forme-state-variants s))])
                    1)
                  0)))

(define (row label n base [note ""])
  (format "    ~a ~a ~a  ~a"
          (~a label #:min-width 34)
          (~a (number->string n) #:min-width 7 #:align 'right)
          (~a (real->decimal-string (per-1000 n base) 2)
              #:min-width 8 #:align 'right)
          note))

(define (deviation-report b [r #f])
  (define c (deviation-counts b r))
  (define (g k) (hash-ref c k 0))
  (define n (g 'words))
  (define fmt (book-fmt b))

  (string-join
   (append
    (list
     "HOW FAR THE PRINT HAS MOVED FROM ITS COPY"
     ""
     "  Every figure below is an outcome, not a setting. A compositor does"
     "  not decide to abbreviate so many words in a thousand; he abbreviates"
     "  when a line will not come out, and how often that happens depends on"
     "  the measure, the format, the casting off, and the words the author"
     "  happened to use. The same copy set in another format gives other"
     "  numbers throughout."
     ""
     (format "  ~a: ~a ems x ~a column(s) x ~a lines = ~a ems of text to the page"
             (book-format-name fmt)
             (real->decimal-string (book-format-measure-ems fmt) 0)
             (book-format-columns fmt)
             (book-format-lines fmt)
             (exact-round (* (book-format-measure-ems fmt)
                             (book-format-columns fmt)
                             (book-format-lines fmt))))
     (format "  ~a words, ~a lines, ~a pages"
             n (g 'lines) (g 'pages))
     ""
     (format "    ~a ~a ~a"
             (~a "" #:min-width 34)
             (~a "count" #:min-width 7 #:align 'right)
             (~a "per 1000" #:min-width 8 #:align 'right))
     "    THE STAGES A WORD PASSES THROUGH"
     (row "copy marked up by the corrector" (g 'prepared) n
          "before the compositor saw it")
     (row "misread from the copy" (g 'misreading) n
          "his eye, not his judgement")
     (row "respelt by habit" (g 'habit) n
          "what he sets left to himself")
     (row "altered to fit the measure" (g 'fitting) n
          "forced by the line, not chosen")
     (row "accident of the case" (g 'accident) n
          "foul case, turned letter, wrong fount")
     (row "corrected at press" (g 'variants) n
          "and so standing two ways")
     (row "long s, u for v, i for j" (g 'conventions) n
          "the house's conventions, not errors")
     ""
     (row "ANY departure from copy" (g 'any) n "")
     (format "    ~a of the text stands exactly as the copy had it"
             (string-append (real->decimal-string (- 100.0 (pct (g 'any) n)) 1) "%"))
     ""
     "    WHAT WAS DONE TO LINES"
     (row "needing an expedient to come out" (g 'expedient) (g 'lines)
          "per 1000 lines")
     (row "a word divided at the end" (g 'divided) (g 'lines) "per 1000 lines")
     (if (zero? (g 'verse-lines))
         (format "    ~a ~a ~a  ~a"
                 (~a "turned over or under" #:min-width 34)
                 (~a "—" #:min-width 7 #:align 'right)
                 (~a "—" #:min-width 8 #:align 'right)
                 "no verse in this book; only a verse line turns over")
         (row "turned over or under" (g 'turned-over) (g 'verse-lines)
              "per 1000 verse lines"))
     (row "quadded out" (g 'quadded) (g 'lines) "per 1000 lines")
     ""
     "    WHAT WAS DONE TO PAGES"
     (row "crowded" (g 'crowded) (g 'pages) "per 1000 pages")
     (row "spun out" (g 'spun-out) (g 'pages) "per 1000 pages")
     (row "lines of copy dropped" (g 'omitted) (g 'pages) "per 1000 pages")
     "")
    (list
     "  The two rates worth comparing are habit and fitting. Habit is the"
     "  man; fitting is the measure. Where fitting is the larger, the page is"
     "  reporting the width of the stick rather than the workman, and any"
     "  attribution drawn from its spelling is reading the furniture. This is"
     "  Hinman's own caveat about his method (i. 186-7), and it is the one"
     "  quantity a real book cannot supply, because in a real book the two"
     "  are already mixed."))
   "\n"))

(module+ test
  (require rackunit racket/file racket/runtime-path "copytext.rkt")

  (define-runtime-path ado "samples/ado/_all-q1600.txt")
  (define txt (file->string ado))

  (define (counts-for fmt)
    (deviation-counts
     (set-book (make-house #:fmt fmt #:compositors '("A" "B") #:seed 5) txt 'prose)))

  (define f (counts-for FOLIO-IN-SIXES))
  (define q (counts-for QUARTO))
  (define o (counts-for OCTAVO))

  ;; The same copy makes very different books. A folio page holds 2112 ems
  ;; against an octavo's 480, so the octavo takes four times the pages and is
  ;; cast off four times as often.
  (check-true (> (hash-ref o 'pages) (* 3 (hash-ref f 'pages)))
              "octavo takes far more pages than folio")

  ;; And the rates follow the format rather than being fixed. The quarto's
  ;; 21-em measure leaves room and its fitting rate is the lowest of the
  ;; three; the narrower folio column and octavo page force the compositor's
  ;; hand oftener. That the numbers move at all with the format is the whole
  ;; reason for measuring per run.
  ;;
  ;; The ordering of habit against fitting is deliberately not asserted. It
  ;; used to be -- fitting exceeded habit in folio -- until the spelling
  ;; devices were gated on the lexicon, which cut fitting by some sixty per
  ;; cent because most of what the program had been calling justification was
  ;; unattested forms. What survives is a lower bound: the lexicon holds a few
  ;; thousand forms, so many real variants are unknown to it too, and the
  ;; figure should rise again when a corpus is behind it.
  (define (rate h k) (/ (exact->inexact (hash-ref h k)) (hash-ref h 'words)))
  (check-true (< (rate q 'fitting) (rate o 'fitting))
              "the wide quarto measure forces fewer alterations than the octavo")
  (check-true (> (- (apply max (map (lambda (h) (rate h 'fitting)) (list f q o)))
                    (apply min (map (lambda (h) (rate h 'fitting)) (list f q o))))
                 0.001)
              "the fitting rate is a property of the run, not a constant")

  ;; A narrower measure divides more words.
  (define (div h) (/ (exact->inexact (hash-ref h 'divided)) (hash-ref h 'lines)))
  (check-true (> (div o) (div q))
              "the 16-em octavo divides oftener than the 21-em quarto")

  ;; Most of the difference between print and copy is neither error nor
  ;; choice but the house's conventions, and a report that did not say so
  ;; would leave the arithmetic unexplained.
  (check-true (> (hash-ref f 'conventions) (hash-ref f 'fitting))
              "long s and u/v outweigh every deliberate change"))
