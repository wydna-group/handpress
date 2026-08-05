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
         render-page-html render-book-html html-escape
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
;; HTML
;; ---------------------------------------------------------------------------

(define (html-escape s)
  (for/fold ([s s]) ([pair (in-list '(("&" "&amp;") ("<" "&lt;") (">" "&gt;")
                                      ("\"" "&quot;")))])
    (string-replace s (car pair) (cadr pair))))

;; The stylesheet lives in xslt/facsimile.css and is read at run time, not
;; kept here.
;;
;; It used to exist twice: once in this string and once inside the XSLT, and
;; the two drifted until the TEI rendering had none of the page numbers,
;; deviation marks or unit grouping the direct one had grown. Two copies of a
;; stylesheet is one copy too many, and the second is always the stale one.
(define-runtime-path facsimile-css "xslt/facsimile.css")
(define-runtime-path facsimile-js "xslt/facsimile.js")
(define css (file->string facsimile-css))
(define js (file->string facsimile-js))

;; Uneven inking: a handpress page is never evenly black. Deterministic in the
;; word, so that redeploying the same book does not reshuffle the ink.
(define (ink text sig)
  (define h (for/fold ([a 7]) ([ch (in-string (string-append sig text))])
              (modulo (+ (* a 31) (char->integer ch)) 255)))
  (+ 0.80 (* (/ h 255.0) 0.20)))

;; Wrap the characters that were set from an individually identifiable piece
;; of type, so that the damage is on the page and not merely in the record.
;; Each kind of defect gets its own treatment: a bent sort leans, a worn one
;; prints faint, a clogged one prints thick.
(define (mark-damage text pieces)
  (define n (string-length text))
  (define at (for/hash ([p (in-list pieces)] #:when (< (car p) n))
               (values (car p) (cdr p))))
  (apply string-append
         (for/list ([ch (in-string text)] [i (in-naturals)])
           (define p (hash-ref at i #f))
           (if p
               (format "<span class=\"dmg ~a\" title=\"~a\">~a</span>"
                       (sort-piece-damage p)
                       (html-escape (sort-piece-note p))
                       (html-escape (string ch)))
               (html-escape (string ch))))))

;; Ring the letter the case got wrong.
;;
;; A turned letter and a foul-case letter are both single characters that
;; differ between what was composed and what printed, so they can be found by
;; comparing the two. Marking them matters: an `n' standing for a `u' is
;; invisible in a plain transcript and obvious on the page, and the whole
;; point of a type-facsimile is to show what the page showed.
(define (mark-accident body composed printed)
  (cond
    [(or (not composed) (not printed)
         (string=? composed printed)
         (not (= (string-length composed) (string-length printed)))
         (regexp-match? #rx"<" body))
     body]
    [else
     (apply string-append
            (for/list ([a (in-string composed)] [bch (in-string printed)])
              (if (char=? a bch)
                  (html-escape (string bch))
                  (format "<span class=\"acc\" title=\"~a set for ~a\">~a</span>"
                          (html-escape (string bch)) (html-escape (string a))
                          (html-escape (string bch))))))]))

(define (render-line-html l readings sig lineno)
  (cond
    [(null? (set-line-words l)) "<div class=\"tline\"></div>"]
    [else
     (define spaces (set-line-spaces l))
     (define spans
       (let loop ([ws (set-line-words l)] [i 0] [x (set-line-indent l)] [acc '()])
         (cond
           [(null? ws) (reverse acc)]
           [else
            (define w (car ws))
            (define text
              (or (and readings (hash-ref readings (list sig lineno i) #f))
                  (word-printed w)))
            (define dev (word-deviation w))
            (define cls
              (string-join
               (filter (lambda (s) (not (string=? s "")))
                       (list "w"
                             (if (or (word-italic? w) (set-line-italic? l)) "it" "")
                             (deviation-class w)))
               " "))
            (define body
              (mark-accident
               (if (null? (word-pieces w))
                   (html-escape text)
                   (mark-damage text (word-pieces w)))
               (word-composed w) text))
            (loop (cdr ws) (add1 i)
                  (+ x (word-width w) (if (< i (length spaces)) (list-ref spaces i) 0))
                  (cons (format "<span class=\"~a\"~a style=\"--x:~a;--w:~a;opacity:~a\">~a</span>"
                                cls
                                (if dev
                                    (format " title=\"~a\"" (html-escape dev))
                                    "")
                                (real->decimal-string (ems x) 3)
                                (real->decimal-string (ems (word-width w)) 3)
                                (real->decimal-string (ink text sig) 2)
                                body)
                        acc))])))
     (format "<div class=\"tline\">~a</div>" (apply string-append spans))]))

(define (render-page-html p columns [readings #f] [measure-ems 21.0]
                          [folio #f] [lines-per-page #f] [fmt-of-page QUARTO])
  (define lines (page-all-lines p))
  (define measure (if (pair? lines) (ems (set-line-measure (car lines))) measure-ems))
  (define cols
    (let loop ([cs (page-columns p)] [n 0] [out '()])
      (cond
        [(null? cs) (reverse out)]
        [else
         (define-values (rows n*)
           (for/fold ([acc '()] [k n] #:result (values (reverse acc) k))
                     ([l (in-list (car cs))])
             (values (cons (render-line-html l readings (page-sig p) (add1 k)) acc)
                     (add1 k))))
         (loop (cdr cs) n*
               (cons (format "<div class=\"col\" style=\"--m:~a\">~a</div>"
                             (real->decimal-string measure 2)
                             (apply string-append rows))
                     out))])))
  (define head (if (page-running-title p)
                   (html-escape (running-title-text (page-running-title p))) ""))
  (define-values (tag-cls note)
    (cond [(> (page-pressure p) 0.35) (values "crowd" " · crowded")]
          [(< (page-pressure p) -0.35) (values "gape" " · spun out")]
          [else (values "" "")]))
  ;; Every leaf is the same size, because every leaf of a book is. A page with
  ;; less on it is not a smaller page: it is the same page with white at the
  ;; foot, which is exactly what a spun-out page looks like and what the
  ;; casting-off report is talking about.
  (define n-lines
    (for/fold ([m 0]) ([c (in-list (page-columns p))]) (max m (length c))))
  ;; Which leaf and which sheet this page belongs to. The two are different
  ;; units and both matter: the leaf is what the reader turns, the sheet is
  ;; what the pressman printed. A quarto sheet makes four leaves, and its
  ;; eight pages are scattered through the gathering rather than consecutive.
  (define r (page-pref p))
  (define leaf-id (format "~a~a" (signature-letter (page-ref-gathering r))
                          (page-ref-leaf r)))
  ;; Which sheet of the gathering this leaf came off, which is not a matter of
  ;; counting leaves in twos. A quarto gathering is one sheet folded twice, so
  ;; all four of its leaves are the same piece of paper. A folio in sixes is
  ;; three sheets quired one inside another, so its outermost sheet is leaves
  ;; 1 and 6, the next 2 and 5, the innermost 3 and 4 -- pairs that are as far
  ;; apart in the book as they can be.
  (define n-leaves (book-format-leaves fmt-of-page))
  (define n-sheets (book-format-sheets fmt-of-page))
  (define leaf-n (page-ref-leaf r))
  (define sheet-id
    (format "~a~a" (signature-letter (page-ref-gathering r))
            (if (<= n-sheets 1)
                1
                (min leaf-n (- (add1 n-leaves) leaf-n)))))
  (format #<<HTML
<div class="leaf plate" data-leaf="~a" data-sheet="~a" data-forme="~a"
     style="--m:~a;--cols:~a;--lines:~a">
  <div class="tag ~a">sig. ~a &nbsp;·&nbsp; ~a &nbsp;·&nbsp; Compositor ~a~a</div>
  <div class="unit"><span data-unit="leaf">leaf ~a</span><span data-unit="sheet">sheet ~a</span><span data-unit="forme">forme</span></div>
  <div class="headline">
    <span class="fol left">~a</span>
    <span class="runhead">~a</span>
    <span class="fol right">~a</span>
  </div>
  <div class="rule"></div>
  <div class="cols">~a</div>
  <div class="direction"><span>~a</span><span>~a</span></div>
</div>
HTML
          leaf-id sheet-id (html-escape (page-forme-name p))
          (real->decimal-string measure 2) columns
          (or lines-per-page n-lines)
          tag-cls (html-escape (page-sig p)) (html-escape (page-forme-name p))
          (html-escape (page-compositor p)) note
          leaf-id sheet-id
          ;; The page number sits in the headline beside the running title,
          ;; verso to the left and recto to the right, because that is where
          ;; the type for it stood. Where the paging went wrong the number
          ;; shown is the wrong one, and it says so on hover.
          (folio-html folio (not (page-ref-recto? (page-pref p))))
          head
          (folio-html folio (page-ref-recto? (page-pref p)))
          (apply string-append cols)
          (html-escape (page-signature p)) (html-escape (page-catchword p))))

(define (folio-html f show?)
  (cond
    [(or (not f) (not show?)) ""]
    [(string=? (folio-number-printed f) "") ""]
    [else
     (define note (folio-number-note f))
     (format "<span class=\"pageno~a\"~a>~a</span>"
             (if (string=? note "") "" " wrong")
             (if (string=? note "")
                 ""
                 (format " title=\"~a — should be ~a\""
                         (html-escape note) (folio-number-want f)))
             (html-escape (folio-number-printed f)))]))

(define (render-book-html b [readings #f]
                          #:title [title "A book of the handpress era"]
                          #:lede [lede ""] #:extra [extra ""]
                          #:run [run #f])
  (define folios
    (for/hash ([f (in-list (book-paging b))]) (values (folio-number-sig f) f)))
  ;; Bound as openings: a verso and the recto facing it. The first recto has
  ;; no verso before it and stands alone, which is why a book opens on a
  ;; single page and thereafter in pairs.
  (define rendered
    (for/list ([p (in-list (book-pages b))])
      (cons (page-ref-recto? (page-pref p))
            (render-page-html p (book-format-columns (book-fmt b)) readings
                              (book-format-measure-ems (book-fmt b))
                              (hash-ref folios (page-sig p) #f)
                              (book-format-lines (book-fmt b))
                              (book-fmt b)))))
  (define pages
    (let loop ([ps rendered] [out '()])
      (cond
        [(null? ps) (apply string-append (reverse out))]
        [(and (car (car ps)) (pair? (cdr ps)) (not (car (cadr ps))))
         ;; a recto with its verso following is the wrong way round; the
         ;; opening is verso then recto, so a recto begins one only when
         ;; nothing precedes it
         (loop (cdr ps)
               (cons (format "<div class=\"opening\">~a</div>" (cdr (car ps))) out))]
        [(and (not (car (car ps))) (pair? (cdr ps)) (car (cadr ps)))
         (loop (cddr ps)
               (cons (format "<div class=\"opening\">~a~a</div>"
                             (cdr (car ps)) (cdr (cadr ps)))
                     out))]
        [else
         (loop (cdr ps)
               (cons (format "<div class=\"opening\">~a</div>" (cdr (car ps))) out))])))
  (format #<<HTML
<!doctype html>
<html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>~a</title><style>~a</style></head>
<body><div class="wrap">
<h1>~a</h1>
<p class="lede">~a</p>
~a
<div class="key">
  <b>Departures from copy:</b>
  <span><i class="k1"></i>misread</span>
  <span><i class="k2"></i>accident of the case</span>
  <span><i class="k3"></i>altered to fit the measure</span>
  <span><i class="k4"></i>the compositor's habit</span>
  <span>Hover any word for its history.</span>
  <button onclick="document.body.classList.toggle('plain')">show the page plain</button>
</div>
<div class="key">
  <b>The units a page belongs to:</b>
  <span><i class="u1"></i>leaf — the two sides of one piece of paper, facing away from each other</span>
  <span><i class="u2"></i>sheet — everything printed on one sheet, scattered through the gathering</span>
  <span><i class="u3"></i>forme — the pages locked up and inked together</span>
  <span>Hover the buttons above any page to light up the rest of its unit.</span>
</div>
<script>~a</script>
~a
~a
<div class="stats">
<h2>What the run came to</h2>
<pre>~a</pre>
<pre>~a</pre>
</div>
</div></body></html>
HTML
          (html-escape title) css (html-escape title) (html-escape lede)
          (description-html b run)
          js
          pages extra
          (html-escape (deviation-report b run))
          (html-escape (pagination-report (book-paging b)))))

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

  (define html (render-book-html b))
  (check-true (regexp-match? #px"<!doctype html>" html))
  (check-false (regexp-match? #px"src=\"https?:" html) "self-contained")
  (check-true (regexp-match? #px"prefers-color-scheme" html))
  (check-equal? (html-escape "a<b&c") "a&lt;b&amp;c"))
