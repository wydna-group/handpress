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
           "<div class=\"leaf plate~a\" data-leaf=\"~a\" data-sheet=\"~a\" data-forme=\"~a\"\n"
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
                         (if prelim? " prelim" ""))
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
      (row "Collation" (find ms 'collation))
      (row "Foliation" (find ms 'foliation))
      (row "Layout" (find ms 'layout))
      (row "Type" (find ms 'typeNote))
      (row "Support" (find ms 'support))
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
     (string-append
      "<div class=\"key\"><b>Departures from copy:</b>"
      (apply string-append
             (for/list ([c (in-list (kids tax 'category))]
                        #:when (hash-ref ANA-CLASS
                                         (string-append "#" (attr c '|xml:id| "")) #f))
               (format "<span><i class=\"~a\"></i>~a</span>"
                       (hash-ref ANA-CLASS (string-append "#" (attr c '|xml:id| "")))
                       (esc (text-of (find c 'catDesc))))))
      ;; Not "hover any word": about a fifth of them have anything to say, and
      ;; promising a history for all of them made the other four fifths look
      ;; broken. The marked ones are the ones that moved.
      "<span>The marked words carry their history; hover one to read it. "
      "The rest stand as the copy had them.</span>"
      "<button onclick=\"document.body.classList.toggle('plain')\">"
      "show the page plain</button></div>")]))

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
     (string-append
      "<div class=\"stats\"><h2>What the run came to</h2>"
      (if ext
          (format "<p>~a words, ~a lines, ~a pages.</p>"
                  (attr ext '|hp:words| "?") (attr ext '|hp:lines| "?")
                  (attr ext '|hp:pages| "?"))
          "")
      "<table><tr><th></th><th>count</th><th>of</th><th>rate</th></tr>"
      (apply string-append
             (for/list ([c (in-list (find-all st '|hp:count|))])
               (define applicable? (not (equal? (attr c '|hp:applicable|) "false")))
               (format "<tr><th>~a</th><td>~a</td><td>~a ~a</td><td>~a</td></tr>"
                       (esc (attr c '|hp:name| ""))
                       (esc (attr c '|hp:n| "0"))
                       (esc (attr c '|hp:of| "0"))
                       (esc (attr c '|hp:per| ""))
                       (if applicable?
                           (format "~a%" (esc (attr c '|hp:rate| "")))
                           "<i>cannot arise here</i>"))))
      "</table></div>")]))

;; ---------------------------------------------------------------------------
;; The whole document
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
   "</style></head>\n<body><div class=\"wrap\">\n"
   "<h1>" (esc title) "</h1>\n"
   (if (string=? lede "") "" (format "<p class=\"lede\">~a</p>\n" (esc lede)))
   (description->html hdr)
   (key->html hdr)
   UNIT-KEY
   "<script>" (file->string facsimile-js) "</script>\n"
   body
   (statistics->html hdr)
   "</div></body></html>\n"))

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
