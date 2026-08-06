#lang racket/base
;;; The type-facsimile, built from the TEI file and from nothing else.
;;;
;;; There used to be two renderers. `render.rkt' built HTML from the book in
;;; memory and an XSLT stylesheet built it from the TEI, and because each knew
;;; things the other did not they drifted -- three separate bugs in one
;;; session: a stylesheet that existed twice and went stale in one copy, a
;;; script that existed in only one of them so the TEI rendering grew the
;;; buttons and none of the behaviour, and classes one path used that the other
;;; did not. A parity test caught none of it and eventually broke.
;;;
;;; The cure is not a better test. It is that the HTML has exactly one source,
;;; and the source is the file on disk. This module opens the .tei.xml that was
;;; just written and reads it back. If something is missing from the TEI it is
;;; missing from the facsimile, which is the property that keeps the TEI
;;; honest: two things were quietly absent from it until this was written, and
;;; the only reason they were never noticed is that the other renderer knew
;;; them anyway.
;;;
;;; Why not XSLT 2.0 and be rid of Racket here? Because what the stylesheet
;;; could not do was never really transformation. The statistics and the key
;;; are computations over counts and a join against a declared taxonomy; in
;;; XSLT 3.0 they would be a rewrite of code that already exists, and the
;;; processor would be a JRE this project otherwise does not need. Reading the
;;; TEI in the language the rest of the program is written in costs nothing and
;;; adds no dependency. The constraint that matters -- that the TEI is the
;;; single source of truth -- is about which way the data flows, not about
;;; which language does the walking.

(require racket/list racket/string racket/format racket/math xml
         racket/runtime-path racket/file
         "vocabulary.rkt")

(provide tei->html tei-file->html)

(define-runtime-path facsimile-css "xslt/facsimile.css")
(define-runtime-path facsimile-js "xslt/facsimile.js")

;; ---------------------------------------------------------------------------
;; Reading the tree
;; ---------------------------------------------------------------------------
;; Racket's `xml' is namespace-naive: it keeps `hp:x' as the literal symbol
;; |hp:x| rather than resolving the prefix. For this file that is a feature.
;; The prefixes are fixed by tei.rkt, there is exactly one foreign namespace,
;; and matching on the literal name is both simpler and faster than carrying a
;; namespace table about.

(define (tag e) (element-name e))

(define (attr e name [default #f])
  (or (for/or ([a (in-list (element-attributes e))])
        (and (eq? (attribute-name a) name) (attribute-value a)))
      default))

(define (kids e [name #f])
  (for/list ([c (in-list (element-content e))]
             #:when (and (element? c) (or (not name) (eq? (tag c) name))))
    c))

(define (kid e name) (let ([ks (kids e name)]) (and (pair? ks) (car ks))))

;; First descendant with this tag, depth first.
(define (find e name)
  (cond
    [(and (element? e) (eq? (tag e) name)) e]
    [(element? e) (for/or ([c (in-list (element-content e))]) (find c name))]
    [else #f]))

(define (find-all e name)
  (cond
    [(not (element? e)) '()]
    [(eq? (tag e) name) (list e)]
    [else (append* (for/list ([c (in-list (element-content e))]) (find-all c name)))]))

(define ENTITIES (hash 'amp "&" 'lt "<" 'gt ">" 'quot "\"" 'apos "'"))

(define (text-of x)
  (cond
    [(pcdata? x) (pcdata-string x)]
    [(entity? x)
     (define t (entity-text x))
     (if (symbol? t) (hash-ref ENTITIES t "") (string (integer->char t)))]
    [(element? x) (apply string-append (map text-of (element-content x)))]
    [else ""]))

;; ---------------------------------------------------------------------------
;; Writing HTML
;; ---------------------------------------------------------------------------

(define (esc s)
  (for/fold ([s (if (string? s) s (format "~a" s))])
            ([p (in-list '(("&" "&amp;") ("<" "&lt;") (">" "&gt;")
                           ("\"" "&quot;")))])
    (string-replace s (car p) (cadr p))))

;; Uneven inking. A handpress page is never evenly black, and this is
;; deterministic in the word so that re-rendering the same file does not
;; reshuffle the ink.
(define (ink text sig)
  (define h (for/fold ([a 7]) ([ch (in-string (string-append sig text))])
              (modulo (+ (* a 31) (char->integer ch)) 255)))
  (+ 0.80 (* (/ h 255.0) 0.20)))

;; ana="#habit" -> the class the stylesheet knows. Division is not a
;; corruption and gets its own colour; copy and house-style are not departures
;; from the copy at all and get none.
;; Built from the one table, so a category cannot exist in the file and be
;; unknown to the page that renders it -- which is how the last four were added.
(define ANA-CLASS (ana->class-table))

;; ---------------------------------------------------------------------------
;; One word
;; ---------------------------------------------------------------------------

;; What stood in the forme, and what a modern reader would call it. The TEI
;; keeps both halves of a <choice> precisely so that this does not have to
;; guess: <orig>/<abbr>/<sic> is what printed, <reg>/<expan>/<corr> is the
;; reading. hp:glyph overrides both, because it is the form as actually set --
;; long s, u for v, i for j -- of which the element content is the reading.
(define (word-forms w)
  (define ch (kid w 'choice))
  (define app (kid w 'app))
  (define-values (printed reading)
    (cond
      [ch
       (define first-branch (and (pair? (kids ch)) (car (kids ch))))
       (define second-branch (and (> (length (kids ch)) 1) (cadr (kids ch))))
       (values (if first-branch (text-of first-branch) (text-of ch))
               (if second-branch (text-of second-branch) (text-of ch)))]
      [app
       (define rs (kids app 'rdg))
       (values (if (pair? rs) (text-of (car rs)) (text-of app))
               (if (pair? rs) (text-of (car rs)) (text-of app)))]
      [else (let ([t (text-of w)]) (values t t))]))
  (values (or (attr w '|hp:glyph|) printed) reading))

;; hp:sorts="3:t51:bent;7:t42:worn" -> index -> (id . damage)
(define (sorts-of w)
  (define raw (attr w '|hp:sorts| ""))
  (for/hash ([spec (in-list (string-split raw ";"))]
             #:when (= 3 (length (string-split spec ":"))))
    (define parts (string-split spec ":"))
    (values (string->number (first parts)) (cons (second parts) (third parts)))))

;; Wrap the characters set from an individually identifiable piece, so that the
;; damage is on the page and not merely in the record. Each defect gets its own
;; treatment in the stylesheet: a bent sort leans, a worn one prints faint.
(define (mark-damage text sorts damage-names)
  (cond
    [(zero? (hash-count sorts)) (esc text)]
    [else
     (apply string-append
            (for/list ([c (in-string text)] [i (in-naturals)])
              (define s (hash-ref sorts i #f))
              (if s
                  (format "<span class=\"dmg ~a\" title=\"~a (~a)\">~a</span>"
                          (esc (cdr s))
                          (esc (hash-ref damage-names (cdr s) (cdr s)))
                          (esc (car s))
                          (esc (string c)))
                  (esc (string c)))))]))

;; Ring the letter the case got wrong. A turned letter and a foul-case letter
;; are both single characters differing between what was composed and what
;; printed, so they can be found by comparing the two -- and an `n' standing
;; for a `u' is invisible in a transcript and obvious on the page.
(define (mark-accident body printed composed)
  (cond
    ;; `composed' is present only where the case actually erred. Comparing
    ;; against the *reading* instead would ring every long s and every u-for-v:
    ;; on Areopagitica that was 3,629 letters against the sixteen accidents the
    ;; file records, and it is the same mistake as the one that once reported
    ;; 1,048 accidents in a book with five. A comparison is only meaningful
    ;; between two forms that differ by one thing.
    [(or (not composed)
         (string=? printed composed)
         (not (= (string-length printed) (string-length composed)))
         (regexp-match? #rx"<" body))
     body]
    [else
     (apply string-append
            (for/list ([a (in-string composed)] [b (in-string printed)])
              (if (char=? a b)
                  (esc (string b))
                  (format "<span class=\"acc\" title=\"~a set for ~a\">~a</span>"
                          (esc (string b)) (esc (string a)) (esc (string b))))))]))

(define (word->html w sig damage-names)
  (define-values (printed reading) (word-forms w))
  (define ana (attr w 'ana ""))
  (define cls
    (string-join
     (filter (lambda (s) (not (string=? s "")))
             (list "w"
                   (if (equal? (attr w 'rend) "italic") "it" "")
                   (hash-ref ANA-CLASS ana "")))
     " "))
  (define sorts (sorts-of w))
  (define body
    (mark-accident (mark-damage printed sorts damage-names) printed
                   (attr w '|hp:composed|)))
  ;; The tooltip is the stage-by-stage account the file carries in hp:note --
  ;; "misreading: copy X -> read Y; habit: Y -> Z; justification: ..." -- not
  ;; the one-word class. The class names what kind of thing happened; the note
  ;; says which letters moved and which device moved them, and that is what a
  ;; reader hovering a word actually wants to know.
  (define title
    (or (attr w '|hp:note|)
        (cond
          [(or (string=? ana "") (string=? ana "#copy")) ""]
          [else (substring ana 1)])))
  (format "<span class=\"~a\"~a style=\"--x:~a;--w:~a;opacity:~a\">~a</span>"
          cls
          (if (string=? title "") "" (format " title=\"~a\"" (esc title)))
          (attr w '|hp:x| "0")
          (attr w '|hp:w| "0")
          (real->decimal-string (ink printed sig) 2)
          body))

;; ---------------------------------------------------------------------------
;; One page
;; ---------------------------------------------------------------------------
;; <lb/> is a milestone, so the words of a type line are its following
;; siblings, not its children. Grouping them is the one thing the XSLT could do
;; comfortably and it is no harder here.

(define (column->html col sig damage-names)
  (define measure (attr col '|hp:measure| "21.000"))
  (define lines
    (let loop ([cs (element-content (or (find col 'ab) col))]
               [current #f] [acc '()] [out '()])
      (define (flush)
        (if current
            (cons (format "<div class=\"tline\">~a</div>"
                          (apply string-append (reverse acc)))
                  out)
            out))
      (cond
        [(null? cs) (reverse (flush))]
        [(and (element? (car cs)) (eq? (tag (car cs)) 'lb))
         (loop (cdr cs) (car cs) '() (flush))]
        [(and (element? (car cs)) (eq? (tag (car cs)) 'w))
         (loop (cdr cs) current
               (cons (word->html (car cs) sig damage-names) acc) out)]
        [else (loop (cdr cs) current acc out)])))
  (format "<div class=\"col\" style=\"--m:~a\">~a</div>"
          measure (apply string-append lines)))

(define (fw-of page type)
  (for/or ([f (in-list (find-all page 'fw))])
    (and (equal? (attr f 'type) type) f)))

(define (folio-html page recto? want-recto?)
  (define f (fw-of page "pageNum"))
  (cond
    [(or (not f) (not (eq? recto? want-recto?))) ""]
    [else
     (define note (attr f '|hp:note| ""))
     (format "<span class=\"pageno~a\"~a>~a</span>"
             (if (string=? note "") "" " wrong")
             (if (string=? note "") "" (format " title=\"~a\"" (esc note)))
             (esc (text-of f)))]))

(define (page->html page lines-per-page damage-names [notes (hash)])
  (define sig (attr page 'n ""))
  (define recto? (regexp-match? #rx"r$" sig))
  (define cols (kids page 'div))
  (define measure
    (if (pair? cols) (attr (car cols) '|hp:measure| "21.000") "21.000"))
  (define pressure (or (string->number (attr page '|hp:pressure| "0")) 0.0))
  (define-values (tag-cls note)
    (cond [(> pressure 0.35) (values "crowd" " · crowded")]
          [(< pressure -0.35) (values "gape" " · spun out")]
          [else (values "" "")]))
  (define n-lines
    (for/fold ([m 0]) ([c (in-list cols)]) (max m (length (find-all c 'lb)))))
  (define head (let ([f (fw-of page "head")]) (if f (esc (text-of f)) "")))
  (define sig-fw (let ([f (fw-of page "sig")]) (if f (esc (text-of f)) "")))
  (define catch (let ([f (fw-of page "catch")]) (if f (esc (text-of f)) "")))
  (define leaf (attr page '|hp:leaf| ""))
  (define sheet (attr page '|hp:sheet| ""))
  (define forme (attr page '|hp:forme| ""))
  ;; Preliminary leaves are marked because nothing else on the page says so.
  ;; A book signed A for its front matter and B onward for its text is
  ;; indistinguishable, leaf by leaf, from one signed straight through; the
  ;; difference is in the order the formes went to press, and that is in the
  ;; file rather than on the paper.
  (define prelim? (string=? (attr page '|hp:role| "text") "prelim"))
  (define series (attr page '|hp:series| "main"))
  (define comp (string-replace (attr page 'resp "") "#comp" ""))
  ;; A leaf that was cut out and replaced, or one printed in a gathering it is
  ;; not bound in. Both are in the file; a facsimile that could not show them
  ;; would be showing a book that was not printed.
  (define leaf-note (hash-ref notes (string-append leaf "r")
                              (lambda () (hash-ref notes leaf #f))))
  (format (string-append
           "<div class=\"leaf plate~a\" id=\"pg-~a\" data-leaf=\"~a\" data-sheet=\"~a\" data-forme=\"~a\"\n"
           "     style=\"--m:~a;--cols:~a;--lines:~a\">\n"
           "  <div class=\"tag ~a\">sig. ~a &nbsp;·&nbsp; ~a &nbsp;·&nbsp; Compositor ~a~a~a</div>\n"
           "  <div class=\"unit\"><span data-unit=\"leaf\">leaf ~a</span>"
           "<span data-unit=\"sheet\">sheet ~a</span>"
           "<span data-unit=\"forme\">forme</span></div>\n"
           "  <div class=\"headline\">\n"
           "    <span class=\"fol left\">~a</span>\n"
           "    <span class=\"runhead\">~a</span>\n"
           "    <span class=\"fol right\">~a</span>\n"
           "  </div>\n"
           "  <div class=\"rule\"></div>\n"
           "  <div class=\"cols\">~a</div>\n"
           "  <div class=\"direction\"><span>~a</span><span>~a</span></div>\n"
           "</div>")
          ;; A gathering is a whole sheet and must be completed, so a book whose
          ;; text runs out partway through its last one ends in blank leaves.
          ;; That is a fact about folding paper, not a failure, and saying so
          ;; keeps it from looking like one.
          (string-append (if (zero? n-lines) " blankleaf" "")
                         (if prelim? " prelim" "")
                         ;; The spine is on a recto's left and a verso's right,
                         ;; so which margin is the narrow one changes sides.
                         ;; The two pages of an opening lean towards each other.
                         (if recto? " recto" " verso"))
          (esc sig)
          (esc leaf) (esc sheet) (esc forme)
          measure (max 1 (length cols))
          ;; The *declared* lines to the page, not this page's own count. Every
          ;; leaf of a book is the same size; a page with less on it is not a
          ;; smaller page but the same page with white at the foot, which is
          ;; exactly what a spun-out page looks like and what the casting-off
          ;; report is talking about. Taking the max let a page carrying one
          ;; extra <lb> milestone grow taller than its fellows -- 1043px
          ;; against 1020px, which is visible and wrong.
          (if (> lines-per-page 0) lines-per-page n-lines)
          tag-cls (esc sig) (esc forme) (esc comp) note
          (string-append
           (if prelim?
               (format " &nbsp;·&nbsp; <span class=\"prelim\" title=\"Preliminary matter: set after the text and printed last, so it takes a signature series of its own (here: ~a). Gaskell, p. 8; McKerrow, p. 128.\">preliminary</span>"
                       (esc series))
               "")
           (if leaf-note
               (format " &nbsp;·&nbsp; <span class=\"leafnote\" title=\"~a\">~a</span>"
                       (esc (cdr leaf-note)) (esc (car leaf-note)))
               ""))
          (esc leaf) (esc sheet)
          (folio-html page recto? #f)
          head
          (folio-html page recto? #t)
          (apply string-append
                 (for/list ([c (in-list cols)]) (column->html c sig damage-names)))
          sig-fw catch))

;; ---------------------------------------------------------------------------
;; The header: description, key, statistics
;; ---------------------------------------------------------------------------

;; The size of a leaf, read off the file rather than assumed by the stylesheet.
;;
;; Before this, the CSS built a leaf out of the type page plus eleven ems of
;; margin it had chosen itself, and so drew a quarto at 1.99 tall to wide where
;; the paper gives 1.31. The stylesheet was deciding the size of the paper. Now
;; the sheet decides it, the TEI carries it, and the stylesheet only scales it:
;; one millimetre is drawn `--mm' pixels wide and everything follows.
(define (dimensions-of ms kind)
  (for/or ([d (in-list (find-all ms 'dimensions))])
    (and (string=? (attr d 'type "") kind)
         (let ([h (find d 'height)] [w (find d 'width)])
           (and h w
                (let ([hn (string->number (text-of h))]
                      [wn (string->number (text-of w))])
                  (and hn wn (cons hn wn))))))))

(define (leaf-vars hdr)
  (define ms (find hdr 'msDesc))
  (define leaf (and ms (dimensions-of ms "leaf")))
  (define lay (and ms (find ms 'layout)))
  (cond
    [(not (and leaf lay)) ""]
    [else
     (define (m k) (or (string->number (attr lay k "")) 0))
     (format " style=\"--leaf-h:~a;--leaf-w:~a;--mi:~a;--mh:~a;--mo:~a;--mt:~a;--gut:~a\""
             (car leaf) (cdr leaf)
             (m '|hp:inner|) (m '|hp:head|) (m '|hp:outer|) (m '|hp:tail|)
             (or (string->number (attr lay '|hp:gutter| "")) 2.2))]))

;; The Bowers description is already in the TEI's own vocabulary for physical
;; make-up, so this is a rendering of <msDesc> and not a second computation of
;; it. That is the difference the whole change turns on.
(define (description->html hdr)
  (define ms (find hdr 'msDesc))
  (cond
    [(not ms) ""]
    [else
     (define (row label e)
       (if e (format "<tr><th>~a</th><td>~a</td></tr>" label (esc (text-of e))) ""))
     (string-append
      "<div class=\"desc\"><h2>Bibliographical description</h2><table>"
      ;; Paper first: the sheet is what the book is made of, and the format is
      ;; a fact about how it was folded rather than a size in its own right.
      (row "Paper" (find ms 'support))
      (row "Collation" (find ms 'collation))
      (row "Foliation" (find ms 'foliation))
      (row "Layout" (find ms 'layout))
      (row "Type" (find ms 'typeNote))
      (apply string-append
             (for/list ([n (in-list (find-all ms 'additions))])
               (row "Additions" n)))
      "</table><p class=\"deskey\">After the form of Bowers, "
      "<i>Principles of Bibliographical Description</i> (1949).</p></div>")]))

;; The key is built from the taxonomy the file declares, so a category added to
;; tei.rkt appears here without anything else being touched. It used to be a
;; hand-written list in two places, which is how one of them came to be missing
;; a colour.
(define (key->html hdr)
  (define tax
    (for/or ([t (in-list (find-all hdr 'taxonomy))])
      (and (equal? (attr t '|xml:id|) "hp.causes") t)))
  (cond
    [(not tax) ""]
    [else
     ;; Not a legend but a filter. A book of this length carries thousands of
     ;; marked words in ten kinds at once, and the eye cannot separate them --
     ;; which is the complaint every apparatus in print has, and the one thing a
     ;; screen can actually fix. The LDLT viewer calls it "filtering types of
     ;; variant readings to limit apparatus entries on screen"; here each kind
     ;; can simply be switched off, so a reader who wants to see only what the
     ;; case got wrong can have exactly that page.
     (string-append
      "<div class=\"key filters\"><b>Departures from copy</b>"
      "<span class=\"hint\">click a kind to hide it; the marked words carry "
      "their history, and the rest stand as the copy had them</span>"
      (apply string-append
             (for/list ([c (in-list (kids tax 'category))]
                        #:when (hash-ref ANA-CLASS
                                         (string-append "#" (attr c '|xml:id| "")) #f))
               (define cls (hash-ref ANA-CLASS (string-append "#" (attr c '|xml:id| ""))))
               (format (string-append
                        "<label class=\"filter on\" data-cls=\"~a\">"
                        "<input type=\"checkbox\" checked><i class=\"~a\"></i>"
                        "<span class=\"cnt\" data-count-for=\"~a\"></span>~a</label>")
                       cls cls cls (esc (text-of (find c 'catDesc))))))
      "<button type=\"button\" data-toggle=\"plain\">show the page plain</button>"
      "</div>")]))

(define UNIT-KEY
  (string-append
   "<div class=\"key\"><b>The units a page belongs to:</b>"
   "<span><i class=\"u1\"></i>leaf — the two sides of one piece of paper, "
   "facing away from each other</span>"
   "<span><i class=\"u2\"></i>sheet — everything printed on one sheet, "
   "scattered through the gathering</span>"
   "<span><i class=\"u3\"></i>forme — the pages locked up and inked "
   "together</span>"
   "<span>Hover the buttons above any page to light up the rest of its "
   "unit.</span></div>"))

;; The counts, read out of <hp:statistics> rather than recomputed. A rate over
;; an empty denominator is printed as such and not as 0.00, because the file
;; says which it is and a table that flattened the distinction would be
;; throwing away the one thing that makes the zero readable.
(define (statistics->html hdr)
  (define st (find hdr '|hp:statistics|))
  (cond
    [(not st) ""]
    [else
     (define ext (find st '|hp:extent|))
     ;; The counts, as a bar chart and a table at once. A rate is a comparison
     ;; and a column of numbers does not compare; the bar does, and costs
     ;; nothing but a CSS width. The categories are the same ones the page is
     ;; marked in, and carry the same colours, so the table and the book agree.
     (define counts (find-all st '|hp:count|))
     (define top
       (for/fold ([m 0.0]) ([c (in-list counts)])
         (max m (or (string->number (attr c '|hp:rate| "0")) 0.0))))
     (string-append
      "<div class=\"stats\"><h2>What the run came to</h2>"
      (if ext
          (format (string-append
                   "<p class=\"extent\"><b>~a</b> words · <b>~a</b> lines · "
                   "<b>~a</b> pages</p>")
                  (attr ext '|hp:words| "?") (attr ext '|hp:lines| "?")
                  (attr ext '|hp:pages| "?"))
          "")
      "<table class=\"counts\"><thead><tr><th></th><th>count</th>"
      "<th>out of</th><th>rate</th><th class=\"barh\"></th></tr></thead><tbody>"
      (apply string-append
             (for/list ([c (in-list counts)])
               (define applicable? (not (equal? (attr c '|hp:applicable|) "false")))
               (define rate (or (string->number (attr c '|hp:rate| "0")) 0.0))
               (define cls (hash-ref ANA-CLASS (attr c 'ana "") ""))
               (format (string-append
                        "<tr~a><th>~a~a</th><td>~a</td>"
                        "<td>~a ~a</td><td>~a</td>"
                        "<td class=\"bar\"><span style=\"--w:~a%\"~a></span></td></tr>")
                       (if applicable? "" " class=\"na\"")
                       ;; A swatch only where the measure is one of the marked
                       ;; kinds. An empty <i> rendered as a stray dash beside
                       ;; every other row.
                       (if (string=? cls "") "" (format "<i class=\"~a\"></i>" cls))
                       (esc (attr c '|hp:name| ""))
                       (esc (attr c '|hp:n| "0"))
                       (esc (attr c '|hp:of| "0"))
                       (esc (attr c '|hp:per| ""))
                       (if applicable?
                           (format "~a%" (esc (attr c '|hp:rate| "")))
                           "<i>cannot arise here</i>")
                       (if (and applicable? (> top 0))
                           (real->decimal-string (* 100.0 (/ rate top)) 1)
                           "0")
                       (if (string=? cls "") "" (format " class=\"~a\"" cls)))))
      "</tbody></table>"
      ;; Careful with the wording: a test counts the phrase this table uses for
      ;; an empty denominator against the number of such measures in the file,
      ;; so repeating it in the prose would break the correspondence it checks.
      "<p class=\"deskey\">Every figure is read out of the file rather than "
      "recomputed, and a rate over an empty denominator is said in words "
      "instead of being printed as <i>0.00</i>. The two are different "
      "findings — a measure that did not happen, and one that could not "
      "— and a table that flattened them would throw away the only thing "
      "that makes the zero readable.</p></div>")]))

;; ---------------------------------------------------------------------------
;; The whole document
;; ---------------------------------------------------------------------------
;; The bird's-eye views
;; ---------------------------------------------------------------------------
;; Two things a long book needs that a scroll cannot give: somewhere to see the
;; whole of it at once, and a picture of how the paper is folded. Both are made
;; from what the file already carries -- every page div knows its forme, its
;; sheet, its leaf, its compositor and how hard it was to fill -- and neither
;; existed, so a hundred and twenty leaves could only be got at by scrolling and
;; the collation was a formula and nothing else.
;;
;; The map is Manicule's: "a colour-coded bar providing a bird's-eye
;; visualisation by page categories". The quire diagram is what VisColl does for
;; manuscripts, and it is worth more here than there, because this program knows
;; which leaves are conjugate rather than having to infer it.

(define (gathering-of sig)
  (define m (regexp-match #px"^(.*?)([0-9]+)[rv]?$" sig))
  (if m (cadr m) sig))

(define (leaf-number sig)
  (define m (regexp-match #px"([0-9]+)[rv]?$" sig))
  (if m (string->number (caddr (list 0 0 (cadr m)))) 1))

;; One tick per page, in the order they stand in the book: the shape of the
;; whole run at a glance, and a way to get to any leaf without scrolling.
(define (map->html pages)
  (define n (length pages))
  (cond
    [(zero? n) ""]
    [else
     (string-append
      "<div class=\"mapbar\" id=\"mapbar\"><div class=\"maprow\">"
      (apply string-append
             (for/list ([p (in-list pages)])
               (define sig (attr p 'n ""))
               (define pressure (or (string->number (attr p '|hp:pressure| "0")) 0.0))
               (format (string-append
                        "<a class=\"tick ~a\" href=\"#pg-~a\" data-sig=\"~a\""
                        " data-forme=\"~a\" data-comp=\"~a\""
                        " style=\"--p:~a\" title=\"~a — ~a, ~a\"></a>")
                       (if (equal? (attr p '|hp:role| "text") "prelim") "prelim" "text")
                       (esc sig) (esc sig)
                       (esc (attr p '|hp:forme| "")) (esc (attr p 'resp ""))
                       (real->decimal-string (min 1.0 (max 0.0 pressure)) 2)
                       (esc sig) (esc (attr p '|hp:forme| ""))
                       (esc (string-append "set by "
                                           (regexp-replace #rx"^#comp" (attr p 'resp "") ""))))))
      "</div><div class=\"maplegend\"><span>every page in the book, in order; "
      "the darker the tick the harder the page was to fill. "
      "Preliminaries are ruled above.</span></div></div>")]))

;; The paper, folded. Each gathering is drawn as its leaves, with the conjugate
;; pairs bracketed: in a quarto 1 is conjugate with 4 and 2 with 3, which is why
;; cutting one leaf out loosens another halfway across the book.
(define (quires->html pages leaf-notes)
  (define by-gathering
    (for/fold ([h (hash)] [order '()] #:result (cons h (reverse order)))
              ([p (in-list pages)])
      (define leaf (attr p '|hp:leaf| (attr p 'n "")))
      (define g (gathering-of leaf))
      (values (hash-update h g (lambda (ls) (if (member leaf ls) ls (cons leaf ls))) '())
              (if (hash-has-key? h g) order (cons g order)))))
  (define h (car by-gathering))
  (define order (cdr by-gathering))
  (cond
    [(null? order) ""]
    [else
     (string-append
      "<div class=\"quires\">"
      (apply string-append
             (for/list ([g (in-list order)])
               (define leaves (reverse (hash-ref h g '())))
               (define k (length leaves))
               (string-append
                "<figure class=\"quire\"><figcaption>" (esc g)
                (format "<span>~a leaves</span></figcaption>" k)
                ;; The sheet drawn as it folds. Each leaf is a rule; the arc on
                ;; the left joins it to its conjugate, so the nesting of the
                ;; folds is visible rather than asserted -- 1 with 4 outermost,
                ;; 2 with 3 inside it. That is what makes a cancel legible: cut
                ;; leaf 2 out and the arc shows you that leaf 3 is what comes
                ;; loose, halfway across the gathering from it.
                (let* ([row 15] [top 9] [spine 34] [right 104]
                       [h (+ (* k row) 6)])
                  (string-append
                   (format "<svg class=\"fold-diagram\" viewBox=\"0 0 ~a ~a\" width=\"~a\" height=\"~a\" role=\"img\">"
                           right h right h)
                   ;; the arcs, widest pair first so the narrow ones draw over
                   (apply string-append
                          (for/list ([i (in-range 1 (add1 (quotient k 2)))])
                            (define y1 (+ top (* row (sub1 i))))
                            (define y2 (+ top (* row (- k i))))
                            (define bulge (- spine 4 (* 5 (sub1 i))))
                            (format "<path class=\"arc\" d=\"M ~a ~a C ~a ~a ~a ~a ~a ~a\"/>"
                                    spine y1 bulge y1 bulge y2 spine y2)))
                   (apply string-append
                          (for/list ([lf (in-list leaves)] [i (in-naturals 1)])
                            (define note (hash-ref leaf-notes lf #f))
                            (define conj (- (add1 k) i))
                            (define y (+ top (* row (sub1 i))))
                            (format
                             (string-append
                              "<g class=\"fold~a\" data-leaf=\"~a\" data-conj=\"~a\">"
                              "<title>~a</title>"
                              "<text x=\"~a\" y=\"~a\">~a</text>"
                              "<line x1=\"~a\" y1=\"~a\" x2=\"~a\" y2=\"~a\"/>"
                              "<rect x=\"~a\" y=\"~a\" width=\"~a\" height=\"~a\" fill=\"transparent\"/>"
                              "</g>")
                             (if note " marked" "")
                             (esc lf) conj
                             (esc (if note
                                      (format "~a — ~a" (car note) (cdr note))
                                      (format "leaf ~a of ~a; conjugate with leaf ~a"
                                              i k conj)))
                             (- spine 12) (+ y 3) i
                             spine y (- right 4) y
                             (- spine 16) (- y 6) (- right (- spine 16) 2) 13)))
                   "</svg>"))
                "</figure>")))
      "</div>"
      "<p class=\"deskey\">Each gathering is one sheet folded. The leaves "
      "bracketed together are conjugate — two halves of one piece of paper — "
      "so a leaf cut out leaves a stub, and its partner loose. Hover a leaf "
      "for what became of it.</p>")]))

;; The witnesses: the made-up copies, and what the binder did to each.
(define (witnesses->html hdr)
  (define ws (find-all hdr 'witness))
  (cond
    [(null? ws) ""]
    [else
     (string-append
      "<table class=\"wits\"><thead><tr><th>copy</th><th>gathered</th>"
      "<th>faults</th></tr></thead><tbody>"
      (apply string-append
             (for/list ([w (in-list ws)])
               (define faults (find-all w '|hp:fault|))
               ;; The witness's own words, without its faults' -- `text-of'
               ;; gathers every descendant, so the sewing order ran straight
               ;; into the note on the fault and read "... M N Otwo gatherings
               ;; sewn in the wrong order".
               (define own
                 (apply string-append
                        (for/list ([c (in-list (element-content w))] #:when (pcdata? c))
                          (pcdata-string c))))
               (format "<tr id=\"wit-~a\"><th>~a</th><td class=\"sew\">~a</td><td>~a</td></tr>"
                       (esc (attr w '|xml:id| ""))
                       (esc (car (regexp-split #rx"," (string-append own ","))))
                       (esc (let ([m (regexp-match #px"sewn as (.*)$" own)])
                              (if m (string-trim (cadr m)) "—")))
                       (if (null? faults)
                           "<span class=\"ok\">none</span>"
                           (string-join
                            (for/list ([f (in-list faults)])
                              (define caught? (equal? (attr f 'caught) "true"))
                              (format "<span class=\"fault~a\" title=\"~a\">~a~a</span>"
                                      (if caught? " caught" "")
                                      (esc (text-of f))
                                      (esc (attr f 'kind ""))
                                      (if caught? " — caught in the warehouse" "")))
                            " ")))))
      "</tbody></table>"
      "<p class=\"deskey\">No two copies are the same book. Each was gathered "
      "from the heaps in the order the sheets came off, so which state of a "
      "corrected forme a copy carries depends on where in the heap it lay.</p>")]))

;; ---------------------------------------------------------------------------

(define (tei->html doc #:lede [lede ""])
  (define root (document-element doc))
  (define hdr (find root 'teiHeader))
  (define title (let ([t (find hdr 'title)]) (if t (text-of t) "A book")))
  (define damage-names
    (let ([tax (for/or ([t (in-list (find-all hdr 'taxonomy))])
                 (and (equal? (attr t '|xml:id|) "hp.damage") t))])
      (if tax
          (for/hash ([c (in-list (kids tax 'category))])
            (values (attr c '|xml:id| "") (text-of (find c 'catDesc))))
          (hash))))
  ;; How many lines the page holds, taken from <note type="measure"> in the
  ;; bibl, which says it in those words. It was being read off <layout>, whose
  ;; wording is the bibliographer's -- "38 ll." -- so the regexp never matched,
  ;; the count fell back to whatever each page happened to carry, and the
  ;; leaves came out six different heights. A book has one page size.
  (define lines-per-page
    (or (for/or ([n (in-list (find-all hdr 'note))])
          (and (equal? (attr n 'type) "measure")
               (let ([m (regexp-match #px"([0-9]+) lines" (text-of n))])
                 (and m (string->number (cadr m))))))
        (let ([n (find hdr 'layout)])
          (and n (let ([m (regexp-match #px"([0-9]+) l" (text-of n))])
                   (and m (string->number (cadr m))))))
        0))
  (define pages
    (for/list ([d (in-list (find-all (find root 'body) 'div))]
               #:when (equal? (attr d 'type) "page"))
      d))
  ;; Bound as openings: a verso and the recto facing it. The first recto has no
  ;; verso before it and stands alone, which is why a book opens on a single
  ;; page and thereafter in pairs.
  ;; Cancels and excisions, keyed by the leaf they concern.
  (define leaf-notes
    (for/fold ([h (hash)])
              ([c (in-list (append (find-all hdr '|hp:cancel|)
                                   (find-all hdr '|hp:excision|)))])
      (cond
        [(equal? (attr c 'at #f)
                 (attr c 'at #f))
         (define at (attr c 'at #f))
         (define from (attr c 'from #f))
         (cond
           [at (hash-set h at
                         (cons "cancel"
                               (format "This leaf was cut out and replaced. ~a. The replacement was printed in ~a, and the leaf was pasted to the stub left behind. McKerrow, p. 223."
                                       (text-of c) (attr c 'printed-in "a half-sheet of its own"))))]
           [from
            (hash-set h (format "~a~a" (attr c 'bound-as "?") (attr c 'leaf "1"))
                      (cons "cut from the last sheet"
                            (format "Printed as leaf ~a of gathering ~a and cut out to be bound here, ~a. McKerrow, p. 158."
                                    (attr c 'leaf "?") (attr c 'from "?")
                                    (if (equal? (attr c 'conjugate "false") "true")
                                        "coming off as a conjugate fold"
                                        "coming off disjunct"))))]
           [else h])]
        [else h])))
  (define rendered
    (for/list ([p (in-list pages)])
      (cons (regexp-match? #rx"r$" (attr p 'n ""))
            (page->html p lines-per-page damage-names leaf-notes))))
  (define body
    (let loop ([ps rendered] [out '()])
      (cond
        [(null? ps) (apply string-append (reverse out))]
        [(and (not (car (car ps))) (pair? (cdr ps)) (car (cadr ps)))
         (loop (cddr ps)
               (cons (format "<div class=\"opening\">~a~a</div>"
                             (cdr (car ps)) (cdr (cadr ps)))
                     out))]
        [else
         (loop (cdr ps)
               (cons (format "<div class=\"opening\">~a</div>" (cdr (car ps)))
                     out))])))
  (string-append
   "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\">\n"
   "<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">\n"
   "<title>" (esc title) "</title><style>" (facsimile-stylesheet)
   "</style></head>\n<body>\n"
   ;; A masthead that stays put, because in a book of sixty leaves the title and
   ;; the collation are wanted at the foot as much as at the head.
   "<header class=\"masthead\"><div class=\"mh\">"
   "<h1>" (esc title) "</h1>"
   (if (string=? lede "") "" (format "<p class=\"lede\">~a</p>" (esc lede)))
   "</div><nav class=\"views\" id=\"views\">"
   "<button data-view=\"book\" class=\"on\">The book</button>"
   "<button data-view=\"makeup\">The make-up</button>"
   "<button data-view=\"evidence\">The evidence</button>"
   "<button data-view=\"copies\">The copies</button>"
   "</nav></header>\n"
   (format "<div class=\"wrap\"~a>\n" (leaf-vars hdr))

   ;; ---- the book -------------------------------------------------------
   "<section class=\"view on\" data-view=\"book\">"
   (map->html pages)
   (key->html hdr)
   UNIT-KEY
   body
   "</section>\n"

   ;; ---- the make-up ----------------------------------------------------
   "<section class=\"view\" data-view=\"makeup\">"
   "<h2>How the book is put together</h2>"
   (quires->html pages leaf-notes)
   (description->html hdr)
   "</section>\n"

   ;; ---- the evidence ---------------------------------------------------
   "<section class=\"view\" data-view=\"evidence\">"
   (statistics->html hdr)
   "</section>\n"

   ;; ---- the copies -----------------------------------------------------
   "<section class=\"view\" data-view=\"copies\">"
   "<h2>The copies made up from the heaps</h2>"
   (witnesses->html hdr)
   "</section>\n"

   "</div>\n<script>" (file->string facsimile-js) "</script>\n"
   "</body></html>\n"))

(define (tei-file->html path #:lede [lede ""])
  (tei->html (read-xml (open-input-string (file->string path))) #:lede lede))

;; The stylesheet as it is actually served: the hand-written layout, plus the
;; departure marks generated from the vocabulary. Both renderings use this, and
;; the XSLT path writes it out beside its HTML rather than copying the raw file
;; -- which would leave every departure on that page unmarked.
(define (facsimile-stylesheet)
  (string-append (file->string facsimile-css) "\n\n" (deviation-css) "\n"))

(define (facsimile-script) (file->string facsimile-js))

(provide facsimile-stylesheet facsimile-script)

(module+ test
  (require rackunit racket/runtime-path "book.rkt" "tei.rkt" "imposition.rkt")

  (define b (set-book (make-house #:fmt QUARTO #:seed 1623)
                      "King. And can you by no drift of conference\nGet from him why he puts on this confusion?\n"))
  (define x (book->tei b))
  (define html (tei->html (read-xml (open-input-string x))))

  (check-true (regexp-match? #px"<!doctype html>" html))
  (check-false (regexp-match? #px"src=\"https?:" html) "self-contained")

  ;; Everything the facsimile shows has to have come out of the file. If any of
  ;; these is missing, the TEI was incomplete and the old renderer was quietly
  ;; supplying the difference -- which is exactly the failure this replaces.
  (check-true (regexp-match? #px"class=\"leaf plate" html) "pages")
  (check-true (regexp-match? #px"class=\"tline\"" html) "type lines")
  (check-true (regexp-match? #px"class=\"w[ \"]" html) "words")
  (check-true (regexp-match? #px"--x:" html) "at computed positions")
  (check-true (regexp-match? #px"data-leaf=" html) "leaf and sheet grouping")
  (check-true (regexp-match? #px"Bibliographical description" html) "the description")
  (check-true (regexp-match? #px"What the run came to" html) "the statistics")
  (check-true (regexp-match? #px"Departures from copy" html) "the key")

  ;; The key is generated from the declared taxonomy, so it must name a
  ;; category that only exists there.
  (check-true (regexp-match? #px"dev-divided" html)
              "the key is built from the taxonomy, not hand-written")

  ;; A rate over an empty denominator is not shown as a number. Asserted as
  ;; the correspondence rather than against a category, because which measures
  ;; apply depends on whether the sample is verse -- and a table that turned
  ;; "cannot arise here" into 0.00 would be discarding the one thing that makes
  ;; the zero readable.
  (check-equal? (length (regexp-match* #px"cannot arise here" html))
                (length (regexp-match* #px"hp:applicable=\"false\"" x))
                "every inapplicable measure in the file says so in the table"))
