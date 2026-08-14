#lang racket/base
;; ---------------------------------------------------------------------------
;; The deviation vocabulary: one table, and everything else derived from it
;; ---------------------------------------------------------------------------
;; What can be said about a word -- what it is called, how it is described to a
;; reader, and how it is marked on the page -- was written down in five places:
;;
;;   * the <category> elements of the TEI taxonomy, in tei.rkt, as hand-built
;;     strings;
;;   * the cond in tei.rkt that decides which of them a word belongs to;
;;   * a second cond in deviation.rkt that decides what colour to give it;
;;   * the ana -> CSS class table in tei-html.rkt;
;;   * the .dev- rules in xslt/facsimile.css.
;;
;; Adding one category therefore meant editing four files and hoping. Worse,
;; the two conds had already drifted apart: deviation.rkt knew nothing of
;; forced substitutions, of places held for the proof, or of press variants, so
;; the same book coloured differently depending on which renderer drew it --
;; and .dev-divided had ended up a hundred and fifty lines from its siblings in
;; the stylesheet, sharing a colour with .dev-shift by accident rather than by
;; decision.
;;
;; This is the same fault the facsimile script records at its head, twice over:
;; "one copy is the maintained one and the other is not". So the vocabulary
;; lives here, as data with no dependencies, and the taxonomy, the class table,
;; the stylesheet rules and the legend are all generated from it. Adding a
;; category is adding a row.
;;
;; `classify' -- which row a given word belongs to -- is *not* here. It needs
;; the word structure and the type case, and putting it here would make this
;; module depend on half the program; it lives in deviation.rkt, which already
;; has both, and is used by every renderer rather than reimplemented in each.

(require racket/string racket/format)

(provide (struct-out deviation-kind)
         DEVIATION-KINDS kind-for kind-class ana->class-table
         taxonomy-categories deviation-css)

;; id      the xml:id in the taxonomy, and the ana pointer minus its hash
;; class   the CSS class the renderers put on the word, or #f for no mark
;; ink     "r,g,b" and the alpha and depth of the underline it prints
;; desc    what the category means, in a sentence, for the header and legend
(struct deviation-kind (id class ink alpha depth desc) #:transparent)

;; Order matters here only for the legend, which is read top to bottom: the
;; compositor's own doing first, then the case's, then the press's.
(define DEVIATION-KINDS
  (list
   (deviation-kind
    "copy" #f #f #f #f
    "Follows the copy the compositor received.")
   (deviation-kind
    "habit" "dev-habit" "70,100,50" ".26" "0.10"
    "The compositor's own spelling, against his copy.")
   (deviation-kind
    "justification" "dev-fit" "29,85,96" ".26" "0.10"
    "Altered so that the line would fill the measure exactly.")
   (deviation-kind
    "misreading" "dev-misread" "140,47,22" ".30" "0.10"
    "Misread from the copy: minims, secretary-hand confusions, memory.")
   ;; His pointing and his place are not his eye, and were coloured as though
   ;; they were. Both differ from the copy at the same stage as a misreading, so
   ;; `classify' sent all three to "misreading" -- the legend offered one filter
   ;; for three faults, and the tooltip said the compositor had misread a comma.
   (deviation-kind
    "pointing" "dev-pointing" "120,60,130" ".28" "0.10"
    (string-append "A stop dropped, changed, or set where the copy had none. "
                   "The pointing of a book is largely the compositor's, and "
                   "correcting it is the commonest thing a corrector did: two "
                   "of the twenty corrections on the one proof-corrected page "
                   "of the First Folio that survives."))
   (deviation-kind
    "omission" "dev-omitted" "60,80,140" ".32" "0.10"
    (string-append "A word in the copy that he never set. Hornschuch's first "
                   "mark. Neither surviving proof census shows one, because a "
                   "corrector can see the sense break but cannot supply the "
                   "word without the copy at his elbow — while Gascoigne's "
                   "fifty-one errata are half dropped words, being what got "
                   "out. The two bodies of evidence are taken at different "
                   "stages and disagree for that reason."))
   (deviation-kind
    "dittography" "dev-doubled" "95,45,105" ".32" "0.10"
    (string-append "A word or two set a second time: the eye left the copy and "
                   "came back to the first of two like words instead of the "
                   "second. Hornschuch's mark for anything redundant, to be "
                   "struck through — and the exact mirror of the eyeskip that "
                   "loses the passage instead, from which it takes its rate."))
   (deviation-kind
    "transposition" "dev-transposed" "150,70,40" ".30" "0.10"
    (string-append "Two words set the wrong way round. Hornschuch draws a mark "
                   "for it, and the program has had the fault at letter scale "
                   "from the beginning and not at word scale. Neither itemised "
                   "proof census shows one, so the rate is an ordering and not "
                   "a share: rarer than pointing, which both censuses do show."))
   (deviation-kind
    "spacing" "dev-spaced" "40,110,120" ".30" "0.10"
    (string-append "Two words run together where the space was left out, or a "
                   "space standing inside one word. Hornschuch's fourth and "
                   "sixth marks, and the commonest fault on that same proof "
                   "page: three of its twenty corrections, against pointing's "
                   "two — “onboth parts”, “farethee well”, “tro bled”."))
   (deviation-kind
    "resumption" "dev-resumed" "40,90,120" ".30" "0.11"
    (string-append "A word or two dropped or set twice where the compositor "
                   "took up his copy again after setting a page. McKerrow's "
                   "mechanism, and his proof that the catchword was set from "
                   "the manuscript: the catchword is right and the page it "
                   "faces is wrong."))
   (deviation-kind
    "division" "dev-divided" "120,110,95" ".35" "0.10"
    (string-append "Half of a word broken at the end of a line. Not a "
                   "corruption: the reading is the whole word, and the hyphen "
                   "is a fact about the line."))
   (deviation-kind
    "foul-case" "dev-accident" "176,110,20" ".30" "0.10"
    "A sort taken from an adjoining box of the case.")
   (deviation-kind
    "substitution" "dev-shift" "150,140,120" ".34" "0.09"
    (string-append "A different sort of the same letters, taken because the "
                   "box wanted was empty: f + fi for the ffi ligature, a round "
                   "s for a long. The reading is unaffected; the shop's supply "
                   "is not."))
   (deviation-kind
    "sort-wanting" "dev-wanting" "90,20,90" ".40" "0.12"
    (string-append "A type laid face down to hold a place, printing as a black "
                   "rectangle, because the sort was not in the house at all. To "
                   "be put right at proof: the forme cannot go to press as it "
                   "stands."))
   (deviation-kind
    "press-variant" "dev-variant" "150,120,20" ".34" "0.10"
    (string-append "The copies do not agree here, the forme having been altered "
                   "while the run went on, and no other cause accounts for the "
                   "word. What the copies read is in the apparatus."))
   (deviation-kind
    "house-style" #f #f #f #f
    "Imposed on the copy by the corrector before setting.")))

(define (kind-for id)
  (for/or ([k (in-list DEVIATION-KINDS)])
    (and (string=? (deviation-kind-id k) id) k)))

;; "" rather than #f, since every caller is building a class attribute.
(define (kind-class id)
  (define k (kind-for id))
  (or (and k (deviation-kind-class k)) ""))

;; "#foul-case" -> "dev-accident", for a renderer reading ana off the file.
(define (ana->class-table)
  (for/hash ([k (in-list DEVIATION-KINDS)]
             #:when (deviation-kind-class k))
    (values (string-append "#" (deviation-kind-id k))
            (deviation-kind-class k))))

(define (taxonomy-categories [indent "          "])
  (string-join
   (for/list ([k (in-list DEVIATION-KINDS)])
     (format "~a<category xml:id=\"~a\"><catDesc>~a</catDesc></category>"
             indent (deviation-kind-id k) (deviation-kind-desc k)))
   "\n"))

;; The marks themselves. Faint by design: the page should read as a page first,
;; and give up its apparatus to attention rather than force it on the eye.
;; `body.plain' takes every one of them off at once, which is what the button
;; under the page does -- and which used to be a hand-kept list that a new
;; category could be left out of.
(define (deviation-css)
  (define marked
    (for/list ([k (in-list DEVIATION-KINDS)] #:when (deviation-kind-class k)) k))
  (string-join
   (append
    (list "/* Generated from DEVIATION-KINDS in vocabulary.rkt -- do not edit"
          "   here; a rule written by hand will be overwritten. */")
    (for/list ([k (in-list marked)])
      (format ".~a { box-shadow: inset 0 -~aem 0 rgba(~a,~a); }"
              (deviation-kind-class k) (deviation-kind-depth k)
              (deviation-kind-ink k) (deviation-kind-alpha k)))
    (list (format "body.plain ~a { box-shadow: none; }"
                  (string-join
                   (for/list ([k (in-list marked)])
                     (format ".~a" (deviation-kind-class k)))
                   ", body.plain ")))
    ;; One switch per kind, so a reader can take the apparatus down to the one
    ;; thing being looked for. Ten kinds marked at once is an apparatus nobody
    ;; can read, and it is the complaint every printed apparatus attracts; a
    ;; screen can simply turn them off, which is what the LDLT viewer calls
    ;; filtering the types of variant reading. Generated here with everything
    ;; else, or a kind added later would appear in the filter list and refuse
    ;; to switch.
    (list "")
    (for/list ([k (in-list marked)])
      (format "body.hide-~a .~a { box-shadow: none; }"
              (deviation-kind-class k) (deviation-kind-class k))))
   "\n"))

(module+ test
  (require rackunit racket/list)
  ;; The point of the table is that these cannot come apart, so the check is
  ;; that they have not.
  (define ids (map deviation-kind-id DEVIATION-KINDS))
  (check-equal? (length ids) (length (remove-duplicates ids)) "ids are distinct")
  (define classes (filter values (map deviation-kind-class DEVIATION-KINDS)))
  (check-equal? (length classes) (length (remove-duplicates classes))
                "no two kinds share a class, which .dev-divided and .dev-shift did")
  (define css (deviation-css))
  (for ([k (in-list DEVIATION-KINDS)])
    (define c (deviation-kind-class k))
    (when c
      (check-true (regexp-match? (regexp (string-append "\\." c " \\{")) css)
                  (format "~a is styled" c))
      (check-true (regexp-match? (regexp (string-append "body\\.plain[^\n]*\\." c)) css)
                  (format "~a is taken off by `show the page plain'" c))
      (check-equal? (hash-ref (ana->class-table) (string-append "#" (deviation-kind-id k)) #f)
                    c
                    (format "~a is reachable from its ana pointer" (deviation-kind-id k)))))
  ;; and a kind with no class must not be styled or claimed by the renderer
  (for ([k (in-list DEVIATION-KINDS)] #:unless (deviation-kind-class k))
    (check-false (hash-ref (ana->class-table) (string-append "#" (deviation-kind-id k)) #f)
                 (format "~a is deliberately unmarked" (deviation-kind-id k))))
  ;; every category the header declares carries a description
  (for ([k (in-list DEVIATION-KINDS)])
    (check-true (> (string-length (deviation-kind-desc k)) 20)
                (format "~a is described to a reader" (deviation-kind-id k))))
  (check-true (regexp-match? #rx"<category xml:id=\"foul-case\">" (taxonomy-categories))))
