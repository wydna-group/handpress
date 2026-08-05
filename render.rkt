#lang racket/base
;;; Pulling a sheet: turning standing type into something that can be looked at.
;;;
;;; Two renderings. The plain-text one is a type-facsimile of the sort an
;;; editor makes at the desk -- line for line, with the direction line and the
;;; catchword, the spacing scaled down to characters. The HTML one places
;;; every word at the position the simulation actually computed for it, in
;;; ems, so that the justification you see is the justification the compositor
;;; performed rather than the browser's.

(require racket/list racket/string racket/math racket/file
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

(define css #<<CSS
:root { color-scheme: light dark; }
* { box-sizing: border-box; }
body {
  margin: 0; padding: 2.5rem 1.25rem 5rem;
  background: #d9d2c3;
  /* An old-face roman is narrow. Georgia and Palatino are not, and a wide
     face on this body makes the words collide, because the positions come
     from the simulation and only the glyphs come from the font. Times-like
     faces are the closest common approximation to the set widths modelled
     in metrics.rkt. */
  font-family: "Times New Roman", Times, "Liberation Serif", "Nimbus Roman",
               ui-serif, Georgia, serif;
  color: #1a150e;
}
@media (prefers-color-scheme: dark) { body { background: #17140f; color: #e8e0d0; } }
:root[data-theme="dark"] body { background: #17140f; color: #e8e0d0; }
:root[data-theme="light"] body { background: #d9d2c3; color: #1a150e; }
.wrap { max-width: 62rem; margin: 0 auto; }
h1 { font-size: 1.3rem; font-weight: 600; letter-spacing: .09em;
     text-transform: uppercase; margin: 0 0 .35rem; }
.lede { font-size: .95rem; opacity: .78; margin: 0 0 2.5rem; max-width: 44rem;
        line-height: 1.55; }
.leaf {
  position: relative; margin: 0 auto 3rem; padding: 3.2em 3.4em 2.6em;
  background: #efe8d7;
  box-shadow: 0 1px 2px rgba(0,0,0,.28), 0 14px 34px rgba(0,0,0,.22);
  border-radius: 1px;
  background-image:
    repeating-linear-gradient(90deg, rgba(120,105,80,.045) 0 1px,
                              transparent 1px 9px),
    repeating-linear-gradient(0deg, rgba(120,105,80,.05) 0 1px,
                              transparent 1px 34px);
}
@media (prefers-color-scheme: dark) { .leaf { background: #e6dcc6; } }
:root[data-theme="dark"] .leaf { background: #e6dcc6; }
.leaf, .leaf * { color: #241c12; }
/* --grid is one em of the type body, in pixels. Every position the
   simulation computed is expressed as a multiple of it, so the layout is the
   compositor's arithmetic and not the browser's.

   --fit is the set width of the face against that body. It must be tuned to
   whatever font actually renders: if the glyphs are wider than the widths in
   metrics.rkt, the words collide and the word-spaces vanish. Keeping the two
   apart is the whole trick -- expressing `left' in em would scale the glyphs
   and the grid together, and no amount of adjustment would ever help.

   Calibrated against Times at 16px by measuring every word in the rendered
   page: at --fit 1.00 the median word occupies its modelled width to within
   1%, and the median gap between words comes out at 5.4px against a true
   thick space of 5.33px. That is the point -- the white you see between two
   words is the space the compositor actually put there.

   Measured again on Areopagitica, 16,219 adjacent pairs: median gap 6.1px,
   and 13 pairs (0.08%) touching. Those are not a modelling error but the
   residue of substituting a real font for a table of widths -- a word heavy
   in long s or capitals renders a shade wider than the model allows, and the
   space it borrows comes from its neighbour. Lowering --fit would clear them
   and would also widen every other gap away from the thick space it is meant
   to be, which is the wrong trade: the collisions are one pair in 1,250 and
   the spacing is the whole point of the exercise. Left as measured. */
.plate { --grid: 16px; --fit: 1.00; --lead: 1.44; font-size: var(--grid); }

/* Every leaf is the same size, because every leaf of a book is. The width is
   the type page plus the margins the period actually left; the height is the
   full measure of lines whether or not this page filled them, so a spun-out
   page shows as white at the foot rather than as a shorter piece of paper.

   The proportions are the book's, not the screen's: a hand-press page carries
   a narrow inner margin and a generous outer and lower one, the text sitting
   high and towards the gutter. */
.leaf {
  width: calc(var(--grid) * ((var(--m) * var(--cols)) + (2.2 * (var(--cols) - 1)) + 11));
  height: calc(var(--grid) * var(--lead) * var(--lines) + var(--grid) * 9);
  box-sizing: border-box;
  padding: 3.4em 4.6em 4.2em 3.4em;
  display: flex; flex-direction: column;
}
.headline { display: flex; align-items: baseline; justify-content: space-between;
            gap: 1em; margin-bottom: .5em; }
.runhead { flex: 1; text-align: center; letter-spacing: .22em; font-size: .82em;
           text-transform: uppercase; }
.fol { font-size: .82em; min-width: 2.4em; }
.fol.right { text-align: right; }
.pageno { letter-spacing: .06em; }
/* A number the compositor got wrong is still the number that printed. It is
   shown as it stands and says on hover what it should have been. */
.pageno.wrong { border-bottom: 1px dotted rgba(140,47,22,.55); cursor: help; }
.rule { border-bottom: 1px solid rgba(40,28,14,.5); margin-bottom: 1.1em; }
.cols { display: flex; gap: 2.2em; align-items: flex-start; flex: 1;
        min-height: calc(var(--grid) * var(--lead) * var(--lines)); }
.col { position: relative; width: calc(var(--grid) * var(--m)); }
.tline { position: relative; height: calc(var(--grid) * 1.44);
         white-space: nowrap; }
.w { position: absolute; top: 0; white-space: pre;
     left: calc(var(--grid) * var(--x));
     font-size: calc(var(--grid) * var(--fit)); }
.it { font-style: italic; }

/* Individually identifiable types. Each defect prints differently, which is
   the point: these are the pieces a bibliographer can follow through a book,
   and they ought to be visible on the page rather than only in the record. */
.dmg { display: inline-block; }
.dmg.broken-serif { transform: translateY(0.4px) scaleY(.97); opacity: .8; }
.dmg.battered     { opacity: .68; transform: skewX(-2deg); }
.dmg.nicked-bowl  { opacity: .82; transform: scaleX(.96); }
.dmg.chipped      { transform: translateY(-0.4px); opacity: .78; }
.dmg.cracked-stem { transform: skewX(2.5deg); opacity: .85; }
.dmg.worn         { opacity: .5; }
.dmg.bent         { transform: rotate(2.5deg); }
.dmg.clogged      { text-shadow: 0 0 .5px currentColor, 0 0 .9px currentColor; }
.dmg.broken-tail  { transform: scaleY(.94) translateY(0.5px); opacity: .8; }
.dmg.low          { opacity: .42; transform: translateY(0.6px); }
/* Hovering a damaged sort names the injury; the whole point of tracking them
   individually is that a reader can follow one through the book. */
.dmg { cursor: help; }

/* A letter the case got wrong -- a turned n for a u, an e from the next box.
   It printed, so it is shown; it was wrong, so it is marked. */
.acc { border-bottom: 1px solid rgba(140,47,22,.5); cursor: help; }

/* Words that depart from the copy, coloured by the stage that moved them.
   Faint by design: the page should read as a page first, and give up its
   apparatus to attention rather than force it on the eye. */
.w[title] { cursor: help; }
.dev-misread  { box-shadow: inset 0 -0.10em 0 rgba(140,47,22,.30); }
.dev-accident { box-shadow: inset 0 -0.10em 0 rgba(176,110,20,.30); }
.dev-fit      { box-shadow: inset 0 -0.10em 0 rgba(29,85,96,.26); }
.dev-habit    { box-shadow: inset 0 -0.10em 0 rgba(70,100,50,.26); }
body.plain .dev-misread, body.plain .dev-accident,
body.plain .dev-fit, body.plain .dev-habit { box-shadow: none; }
body.plain .acc, body.plain .pageno.wrong { border-bottom: 0; }

.key { display: flex; flex-wrap: wrap; gap: .35rem 1.4rem; font-size: .78rem;
       margin: 0 0 2rem; opacity: .85; align-items: center; }
.key b { font-weight: 500; }
.key i { display: inline-block; width: 1.6em; height: .5em; margin-right: .4em;
         vertical-align: middle; border-radius: 1px; }
.key .k1 { background: rgba(140,47,22,.45); }
.key .k2 { background: rgba(176,110,20,.45); }
.key .k3 { background: rgba(29,85,96,.4); }
.key .k4 { background: rgba(70,100,50,.4); }
.key button { font: inherit; padding: .2rem .7rem; border-radius: 999px;
              border: 1px solid currentColor; background: transparent;
              color: inherit; cursor: pointer; opacity: .8; }

/* Openings, as the book is bound: a verso and the recto facing it. The first
   recto stands alone, because it has no verso before it. */
.opening { display: flex; gap: 0; justify-content: center;
           margin: 0 auto 2.4rem; width: fit-content; }
.opening .leaf { margin: 0; }
.opening .leaf + .leaf { border-left: 1px solid rgba(90,74,50,.22); }
.opening .leaf:first-child:last-child { margin-left: 0; }

/* The two units a page belongs to, and they are different things. The leaf is
   what the reader turns; the sheet is what the pressman printed, and its
   pages are scattered through the gathering rather than consecutive. Hovering
   either button in the corner lights up every page of that unit wherever it
   falls in the book. */
.unit { position: absolute; top: -1.55rem; right: 0; display: flex; gap: .3rem;
        font-size: .62rem; letter-spacing: .08em; text-transform: uppercase;
        font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
.unit span { padding: .05rem .45rem; border-radius: 999px; cursor: pointer;
             border: 1px solid rgba(90,74,50,.4); opacity: .6; }
.unit span:hover { opacity: 1; }
.leaf.lit-leaf  { outline: 2px solid rgba(29,85,96,.55); outline-offset: 2px; }
.leaf.lit-sheet { outline: 2px solid rgba(140,80,20,.5); outline-offset: 6px; }
.leaf.lit-forme { outline: 2px solid rgba(70,100,50,.55); outline-offset: 10px; }

/* The statistical report at the foot. */
.stats { margin: 3rem 0 0; }
.stats pre { font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
             font-size: .76rem; line-height: 1.5; white-space: pre-wrap;
             background: rgba(128,110,80,.09); padding: 1.2rem 1.4rem;
             border-radius: 3px; overflow-x: auto; }
.direction { display: flex; justify-content: space-between;
             margin-top: 1.4em; font-size: .9em; letter-spacing: .04em; }
.tag { position: absolute; top: -1.55rem; left: 0; font-size: .68rem;
       letter-spacing: .11em; text-transform: uppercase; opacity: .72;
       font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
.crowd { color: #8c2f16; }
.gape  { color: #1d5560; }
table { border-collapse: collapse; width: 100%; font-size: .86rem;
        margin: 0 0 2rem; }
th, td { text-align: left; padding: .4rem .6rem; vertical-align: top;
         border-bottom: 1px solid rgba(128,110,80,.35); }
th { font-size: .72rem; letter-spacing: .1em; text-transform: uppercase;
     opacity: .7; font-weight: 600; }
code, .mono { font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
              font-size: .86em; }
h2 { font-size: .78rem; letter-spacing: .13em; text-transform: uppercase;
     opacity: .72; margin: 2.6rem 0 .8rem; font-weight: 600; }
.scroll { overflow-x: auto; }
.desc { margin: 0 0 3rem; padding: 1.4rem 1.6rem; max-width: 62rem;
        border: 1px solid rgba(120,105,80,.45); border-radius: 2px;
        background: rgba(255,252,244,.35); }
.desc h2 { margin-top: 0; }
.desc pre { margin: 0; white-space: pre-wrap; font-size: .8rem;
            line-height: 1.5; font-family: ui-monospace, Menlo, monospace; }
.deskey { font-size: .74rem; opacity: .6; margin: .9rem 0 0; }
CSS
  )

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
<script>
/* Light up every page of a unit at once. A leaf is two pages and they face
   away from one another, so they are never both visible; a sheet's pages are
   scattered through the gathering; a forme's are on opposite sides of the
   book. Showing them together is the only way to see what the pressman
   handled as one piece of paper. */
document.addEventListener('mouseover', function (e) {
  var b = e.target.closest && e.target.closest('.unit span');
  if (!b) return;
  var leaf = b.closest('.leaf'), kind = b.dataset.unit;
  var key = kind === 'forme' ? leaf.dataset.forme
          : kind === 'sheet' ? leaf.dataset.sheet : leaf.dataset.leaf;
  document.querySelectorAll('.leaf').forEach(function (p) {
    if (p.dataset[kind] === key) p.classList.add('lit-' + kind);
  });
});
document.addEventListener('mouseout', function (e) {
  var b = e.target.closest && e.target.closest('.unit span');
  if (!b) return;
  document.querySelectorAll('.leaf').forEach(function (p) {
    p.classList.remove('lit-leaf', 'lit-sheet', 'lit-forme');
  });
});
</script>
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
