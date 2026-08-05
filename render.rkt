#lang racket/base
;;; Pulling a sheet: turning standing type into something that can be looked at.
;;;
;;; Two renderings. The plain-text one is a type-facsimile of the sort an
;;; editor makes at the desk -- line for line, with the direction line and the
;;; catchword, the spacing scaled down to characters. The HTML one places
;;; every word at the position the simulation actually computed for it, in
;;; ems, so that the justification you see is the justification the compositor
;;; performed rather than the browser's.

(require racket/list racket/string racket/math racket/file racket/runtime-path
         "metrics.rkt" "compositor.rkt" "book.rkt" "imposition.rkt" "press.rkt"
         "description.rkt" "typecase.rkt" "pagination.rkt"
         (only-in "deviation.rkt" word-deviation deviation-class deviation-report)
         (only-in "orthography.rkt" modernise))

(provide render-line-text render-page-text render-book-text
         show-modernised?)

;; ---------------------------------------------------------------------------
;; Plain text
;; ---------------------------------------------------------------------------

;; Whether the page is shown in the spelling it was set in, or in the reader's.
;;
;; This changes nothing about the setting: the line is as tight as it ever was
;; and the compositor still chose the longer form to fill it. Only the letters
;; the reader sees are different, which is the whole of what a modernised
;; edition offers -- and the reason the TEI keeps both halves of a <choice>.
(define show-modernised? (make-parameter #f))

(define (show s) (if (show-modernised?) (modernise s) s))

(define (render-line-text l chars [readings #f] [sig ""] [lineno 0])
  (cond
    [(null? (set-line-words l)) ""]
    [else
     (define scale (/ chars (exact->inexact (set-line-measure l))))
     (define spaces (set-line-spaces l))
     (define out (open-output-string))
     (let loop ([ws (set-line-words l)] [i 0] [x (set-line-indent l)] [len 0])
       (cond
         [(null? ws) (void)]
         [else
          (define w (car ws))
          (define text
            (show (or (and readings (hash-ref readings (list sig lineno i) #f))
                      (word-printed w))))
          (define col (exact-round (* x scale)))
          (define len*
            (cond
              [(< len col) (write-string (make-string (- col len) #\space) out) col]
              [(> len 0) (write-string " " out) (add1 len)]
              [else len]))
          (write-string text out)
          (loop (cdr ws) (add1 i)
                (+ x (word-width w) (if (< i (length spaces)) (list-ref spaces i) 0))
                (+ len* (string-length text)))]))
     (string-trim (get-output-string out) #:left? #f)]))

(define (centre s width)
  (define pad (max 0 (quotient (- width (string-length s)) 2)))
  (string-trim (string-append (make-string pad #\space) s) #:left? #f))

(define (render-page-text p columns [readings #f]
                          #:rule? [rule? #t] #:numbers? [numbers? #f]
                          #:measure-ems [measure-ems 21.0])
  (define lines (page-all-lines p))
  ;; a page with nothing on it still has the measure of its fellows
  (define measure
    (if (pair? lines)
        (set-line-measure (car lines))
        (exact-round (* measure-ems UNITS-PER-EM))))
  (define chars (measure-in-characters measure))

  (define rendered
    (let loop ([cols (page-columns p)] [n 0] [out '()])
      (cond
        [(null? cols) (reverse out)]
        [else
         (define-values (col n*)
           (for/fold ([acc '()] [k n] #:result (values (reverse acc) k))
                     ([l (in-list (car cols))])
             (define k* (add1 k))
             (define body (render-line-text l chars readings (page-sig p) k*))
             (values (cons (if (and numbers? (zero? (modulo k* 5)))
                               (string-append (pad-right body chars)
                                              (format "  ~a" k*))
                               body)
                           acc)
                     k*)))
         (loop (cdr cols) n* (cons col out))])))

  (define gutter "   ┆   ")
  (define-values (body-lines width)
    (cond
      [(> columns 1)
       (define height (apply max 0 (map length rendered)))
       (values
        (for/list ([i (in-range height)])
          (string-trim
           (string-join
            (for/list ([c (in-list rendered)])
              (pad-right (if (< i (length c)) (list-ref c i) "") chars))
            gutter)
           #:left? #f))
        (+ (* chars columns) (* (string-length gutter) (sub1 columns))))]
      [else
       (values (if (pair? rendered) (car rendered) '())
               (+ chars (if numbers? 6 0)))]))

  (define head (if (page-running-title p) (running-title-text (page-running-title p)) ""))
  (define parts
    (append
     (if (string=? head "") '() (list (centre head width)))
     (if rule? (list (make-string width #\─)) '())
     (list "")
     body-lines))

  ;; the direction line: signature at the left, catchword at the right
  (define sig (page-signature p))
  (define catch (page-catchword p))
  (string-join
   (append parts
           (if (and (string=? sig "") (string=? catch ""))
               '()
               (list ""
                     (string-trim
                      (string-append (pad-right sig (max 0 (- width (string-length catch))))
                                     catch)
                      #:left? #f))))
   "\n"))

(define (pad-right s n)
  (if (>= (string-length s) n) s (string-append s (make-string (- n (string-length s)) #\space))))

(define (render-book-text b [readings #f] #:numbers? [numbers? #f]
                          #:rule? [rule? #t] #:header? [header? #t])
  (string-join
   (append*
    (for/list ([p (in-list (book-pages b))])
      (append
       (if header?
           (list (format "╭─ sig. ~a  ~a, set by Compositor ~a~a"
                         (pad-right (page-sig p) 6) (page-forme-name p)
                         (page-compositor p) (strain-mark p))
                 "")
           '())
       (list (render-page-text p (book-format-columns (book-fmt b)) readings
                               #:rule? rule? #:numbers? numbers?
                               #:measure-ems (book-format-measure-ems (book-fmt b)))
             "" ""))))
   "\n"))

(define (strain-mark p)
  (cond [(> (page-pressure p) 0.35) "  ·crowded·"]
        [(< (page-pressure p) -0.35) "  ·spun out·"]
        [else ""]))

;; ---------------------------------------------------------------------------
;; HTML lived here
;; ---------------------------------------------------------------------------
;; It does not any more. `render-book-html' built a facsimile straight from the
;; book in memory, while an XSLT stylesheet built one from the TEI, and the two
;; drifted because each knew things the other did not -- a stylesheet that
;; existed twice and went stale in one copy, a script only one of them loaded,
;; classes only one of them emitted. A parity test caught none of it.
;;
;; The facsimile is now built in tei-html.rkt out of the .tei.xml file and
;; nothing else, so anything absent from the TEI is absent from the page. That
;; turned up two things the TEI had never carried -- the identity of the
;; damaged sorts, and the statistics -- which had gone unnoticed only because
;; the renderer that needed them held its own copy of the book.
;;
;; What remains here is the plain-text facsimile and the reading text, which
;; are transcripts rather than renderings and have no second implementation to
;; disagree with.

(module+ test
  (require rackunit "orthography.rkt" "typecase.rkt" "rng.rkt")

  (define b (set-book (make-house #:fmt QUARTO #:seed 1623)
                      "King. And can you by no drift of conference\nGet from him why he puts on this confusion?\n"))
  (define txt (render-book-text b))
  (check-true (> (string-length txt) 50))
  ;; The rendered line never runs past the measure in characters either.
  (define chars (measure-in-characters (* 21 UNITS-PER-EM)))
  (for* ([p (in-list (book-pages b))] [l (in-list (page-all-lines p))])
    (check-true (<= (string-length (render-line-text l chars)) (+ chars 4))
                (format "rendered line too long: ~s" (render-line-text l chars))))

  )
