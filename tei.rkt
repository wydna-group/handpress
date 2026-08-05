#lang racket/base
;;; TEI P5 output.
;;;
;;; TEI already has a vocabulary for physical bibliography, and most projects
;;; never use it. <fw> is "forme work" -- the running titles, signatures and
;;; catchwords that are instructions to the binder rather than to the reader.
;;; <pb/>, <cb/> and <lb/> are the page, column and line of type. <lb break="no"/>
;;; is a word divided across a line. <choice> with <abbr>/<expan> is exactly a
;;; scribal contraction, and with <sic>/<corr> exactly a literal. And <app>
;;; with <rdg wit="..."> is a critical apparatus -- which is what a list of
;;; press variants across copies of one edition actually is.
;;;
;;; TWO DECISIONS WORTH ARGUING WITH.
;;;
;;; *Milestones, not containers.* Verse lines, speeches and typographic lines
;;; cut across one another constantly here: a turned-over verse line is one
;;; verse line across two type lines, and a prose paragraph runs over a page
;;; break. XML cannot nest overlapping hierarchies, and TEI's own answer is
;;; the milestone. So <lb/> is empty and the words are its siblings, and the
;;; verse/prose distinction is carried as an attribute rather than by wrapping
;;; each type line in <l>. The cost is that <l> does not appear; the benefit
;;; is that nothing is misrepresented and the XSLT can group by sibling axis,
;;; which XSLT 1.0 can actually do.
;;;
;;; *Geometry in a foreign namespace.* The whole point of this program is that
;;; the justification is the compositor's, not the browser's, so the computed
;;; position of every word has to survive into the output or the facsimile is
;;; a lie. But an em offset is process data, not text, and has no business
;;; wearing TEI semantics. It goes in the hp: namespace, which is the standard
;;; escape hatch, and a consumer who wants clean TEI can strip one namespace
;;; and lose nothing textual.

(require racket/list racket/string racket/math racket/format
         "metrics.rkt" "compositor.rkt" "book.rkt" "imposition.rkt"
         "press.rkt" "binding.rkt" "cancels.rkt" "corrector.rkt" "description.rkt"
         "pagination.rkt"
         (only-in "typecase.rkt" sort-piece-id sort-piece-damage damage-vocabulary)
         (only-in "deviation.rkt" deviation-counts word-deviation)
         (only-in "orthography.rkt" strip-conventions))

(provide book->tei HP-NS TEI-NS)

(define TEI-NS "http://www.tei-c.org/ns/1.0")
(define HP-NS "https://handpress.invalid/ns/1.0")

(define (esc s)
  (for/fold ([s (if (string? s) s (format "~a" s))])
            ([p (in-list '(("&" "&amp;") ("<" "&lt;") (">" "&gt;")
                           ("\"" "&quot;")))])
    (string-replace s (car p) (cadr p))))

(define (em x) (real->decimal-string (ems x) 3))

;; ---------------------------------------------------------------------------
;; Header
;; ---------------------------------------------------------------------------

(define (header b run names)
  (define resps
    (for/list ([n (in-list names)])
      (define p (hash-ref PROFILES n #f))
      (format "        <respStmt xml:id=\"comp~a\"><resp>composition</resp><name>Compositor ~a</name>~a</respStmt>"
              (esc n) (esc n)
              (if p (format "<note>~a</note>" (esc (profile-description p))) ""))))
  (define wits
    (if run
        (for/list ([pc (in-list (press-run-copies run))] [i (in-naturals)])
          ;; The binding is a fact about this copy and about no other, which
          ;; is the whole reason a witness list exists. A fault caught when
          ;; the book was collated never reached a reader and is recorded as
          ;; caught rather than omitted, because "no fault" and "a fault put
          ;; right in the warehouse" are different states of the same copy.
          (define bc (printed-copy-binding pc))
          (format "          <witness xml:id=\"~a\">~a, made up from the heaps and sewn as ~a~a</witness>"
                  (copy-id pc) (esc (printed-copy-name pc))
                  (esc (string-join
                        (for/list ([k (in-list (bound-copy-order bc))] [pos (in-naturals)])
                          (format "~a~a" (quire-mark (list-ref (book-quires b) k))
                                  (if (memv pos (bound-copy-inverted bc)) "↓" "")))
                        " "))
                  (apply string-append
                         (for/list ([f (in-list (bound-copy-faults bc))])
                           (format "<hp:fault kind=\"~a\" at=\"~a\" caught=\"~a\">~a</hp:fault>"
                                   (esc (format "~a" (fault-kind f))) (esc (fault-at f))
                                   (if (fault-caught? f) "true" "false")
                                   (esc (fault-note f)))))))
        '()))
  (string-join
   (append
    (list "  <teiHeader>"
          "    <fileDesc>"
          "      <titleStmt>"
          (format "        <title>~a</title>" (esc (book-title b))))
    resps
    (list "      </titleStmt>"
          "      <publicationStmt>"
          "        <p>Not published. Generated by handpress, a simulation of hand-press composition.</p>"
          "      </publicationStmt>"
          "      <sourceDesc>"
          "        <bibl>"
          (format "          <title>~a</title>" (esc (book-title b)))
          (format "          <extent>~a</extent>" (esc (book-collation b)))
          (format "          <note type=\"measure\">~a ems, ~a column(s), ~a lines to the page</note>"
                  (real->decimal-string (book-format-measure-ems (book-fmt b)) 0)
                  (book-format-columns (book-fmt b))
                  (* (book-format-lines (book-fmt b)) (book-format-columns (book-fmt b))))
          "        </bibl>")
    ;; The Bowers description, in TEI's own vocabulary for physical make-up.
    (list (description-tei-msdesc b run))
    ;; What was cut out of the book, and what was cut out to make it.
    ;;
    ;; Both belong in the file rather than in the report, because the facsimile
    ;; is built from the file and nothing else: a leaf the binder never saw and
    ;; a leaf that was printed in another gathering are facts about the book,
    ;; and a page that cannot show them is showing a book that was not printed.
    (cancels-tei b run)
    (excisions-tei b)
    (if (null? wits) '() (cons "        <listWit>" (append wits (list "        </listWit>"))))
    (list "      </sourceDesc>"
          "    </fileDesc>"
          "    <encodingDesc>"
          "      <classDecl>"
          "        <taxonomy xml:id=\"hp.causes\">"
          "          <category xml:id=\"copy\"><catDesc>Follows the copy the compositor received.</catDesc></category>"
          "          <category xml:id=\"habit\"><catDesc>The compositor's own spelling, against his copy.</catDesc></category>"
          "          <category xml:id=\"justification\"><catDesc>Altered so that the line would fill the measure exactly.</catDesc></category>"
          "          <category xml:id=\"misreading\"><catDesc>Misread from the copy: minims, secretary-hand confusions, memory.</catDesc></category>"
          "          <category xml:id=\"foul-case\"><catDesc>A sort taken from an adjoining box of the case.</catDesc></category>"
          "          <category xml:id=\"division\"><catDesc>Half of a word broken at the end of a line. Not a corruption: the reading is the whole word, and the hyphen is a fact about the line.</catDesc></category>"
          "          <category xml:id=\"house-style\"><catDesc>Imposed on the copy by the corrector before setting.</catDesc></category>"
          "        </taxonomy>"
          "        <taxonomy xml:id=\"hp.damage\">"
          (string-join
           (for/list ([row (in-list damage-vocabulary)])
             (format "          <category xml:id=\"~a\"><catDesc>~a</catDesc></category>"
                     (car row) (esc (cadr row))))
           "
")
          "        </taxonomy>"
          "      </classDecl>"
          "      <p>Type lines are milestones (<gi>lb</gi>), not containers, because verse lines, speeches and type lines overlap. Word positions are in the hp: namespace: they are process data, not text.</p>")
    ;; The counts, so that a reader of the file alone can check the rates
    ;; against the categories declared just above. These were computed for the
    ;; report and never written into the TEI, which made the TEI a transcript
    ;; rather than a record: it declared what the categories meant and never
    ;; said how often each occurred. A rendering built from it had to be told
    ;; the figures by some other route, and that other route was a second
    ;; renderer with its own copy of the book -- the whole reason there were
    ;; two of them.
    (list (statistics-tei b))
    (list "    </encodingDesc>")
    (if (null? (book-preparation b))
        '()
        (list "    <profileDesc>"
              (format "      <correction><p>The corrector made ~a alteration(s) to the copy before it reached the frames. These are house habits, not any workman's, and fall evenly across every stint.</p></correction>"
                      (length (book-preparation b)))
              "    </profileDesc>"))
    (list "  </teiHeader>"))
   "\n"))

;; The deviation counts, as declared data rather than as a printed table.
;;
;; Names are given as they come from `deviation-counts', with the denominator
;; each is a rate against, because a bare count of divisions means nothing
;; without knowing it is per line and not per word. The categories that
;; correspond to entries in the taxonomy above point at them, so a consumer can
;; join the two without knowing anything about this program.
(define STAT-DENOMINATORS
  (hash 'habit 'words 'fitting 'words 'misreading 'words 'accident 'words
        'conventions 'words 'prepared 'words 'any 'words 'variants 'words
        'expedient 'words
        'divided 'lines 'quadded 'lines 'omitted 'lines
        'turned-over 'verse-lines
        'crowded 'pages 'spun-out 'pages))

(define STAT-CATEGORY
  (hash 'habit "habit" 'fitting "justification" 'misreading "misreading"
        'accident "foul-case" 'conventions "copy" 'prepared "house-style"
        'divided "division"))

(define (statistics-tei b)
  (define c (deviation-counts b))
  (define (n k) (hash-ref c k 0))
  (string-join
   (append
    (list "      <hp:statistics>"
          (format "        <hp:extent hp:words=\"~a\" hp:lines=\"~a\" hp:verseLines=\"~a\" hp:pages=\"~a\"/>"
                  (n 'words) (n 'lines) (n 'verse-lines) (n 'pages)))
    (for/list ([k (in-list '(conventions prepared habit fitting misreading
                             accident expedient divided quadded omitted
                             turned-over crowded spun-out variants any))]
               #:when (hash-has-key? c k))
      (define den (hash-ref STAT-DENOMINATORS k 'words))
      (define d (n den))
      (format "        <hp:count hp:name=\"~a\" hp:n=\"~a\" hp:per=\"~a\" hp:of=\"~a\"~a~a/>"
              k (n k) den d
              (cond [(zero? d) " hp:rate=\"\" hp:applicable=\"false\""]
                    [else (format " hp:rate=\"~a\""
                                  (real->decimal-string
                                   (* 100.0 (/ (n k) (exact->inexact d))) 2))])
              (cond [(hash-ref STAT-CATEGORY k #f)
                     => (lambda (cat) (format " ana=\"#~a\"" cat))]
                    [else ""])))
    (list "      </hp:statistics>"))
   "\n"))

(define (copy-id pc)
  (string-downcase (string-replace (printed-copy-name pc) " " "")))

;; ---------------------------------------------------------------------------
;; Body
;; ---------------------------------------------------------------------------

;; (page-sig line word) -> list of (witness-id . reading)
(define (variant-index run)
  (define h (make-hash))
  (when run
    (for ([(name st) (in-hash (press-run-states run))])
      (for ([v (in-list (forme-state-variants st))])
        (define key (list (pvariant-page v) (pvariant-line v) (pvariant-word v)))
        (define corrected-in
          (for/list ([pc (in-list (press-run-copies run))]
                     #:when (hash-ref (printed-copy-states pc) name #f))
            (copy-id pc)))
        (define uncorrected-in
          (for/list ([pc (in-list (press-run-copies run))]
                     #:unless (hash-ref (printed-copy-states pc) name #f))
            (copy-id pc)))
        (hash-set! h key (list (cons uncorrected-in (pvariant-uncorrected v))
                               (cons corrected-in (pvariant-corrected v)))))))
  h)

(define (word->tei w x variants key)
  ;; The text carries the reading; the glyphs ride beside it.
  ;;
  ;; A long s is not a letter. It and the round s are one grapheme with
  ;; positional variants, like u and v, and which one stood in the stick is a
  ;; fact about the type rather than about the word. Encoding it in the text
  ;; makes the TEI unsearchable -- nothing matching "confession" will find
  ;; "confeſſion" -- and obliges every consumer to carry its own copy of
  ;; strip-conventions before it can compare anything. It also inflates the
  ;; statistics: the largest single class of "departure from copy" in this
  ;; program's own reports was the house conventions, which are not departures
  ;; of reading at all.
  ;;
  ;; So the element's content is the reading and hp:glyph records the form as
  ;; actually set, where the two differ. The facsimile renders hp:glyph and
  ;; looks identical; anything reading the text gets English.
  ;;
  ;; Only the long s and the ligatures are treated this way, because only they
  ;; can be undone by rule. Turning `haue' back into `have' cannot be done
  ;; without a dictionary -- see undo-uv-ij in lexicon.rkt -- so u/v and i/j
  ;; are left in the text for now, and the header says so.
  ;; The reading is not recovered from the set form; it is the form the
  ;; compositor had before the conventions were applied to it, and the word
  ;; record still holds it. That matters, because u and v cannot be undone by
  ;; rule -- `haue' is `have' and `vertue' is `virtue', and nothing about the
  ;; letters says which. Reversing them would need the lexicon and would still
  ;; guess; reading them off `final' is exact.
  (define set-form (word-printed w))
  (define reading (word-final w))
  ;; An accident of the case has no pre-conventions counterpart, since the
  ;; wrong sort was picked after the spelling was settled. Its long s can be
  ;; stripped mechanically; its u and v have to stand.
  ;; The accident test compares what printed against what was composed, both
  ;; as set. It must not be run against the reading: `haue' and `have' differ
  ;; by a convention, not by a wrong sort, and comparing those two classified
  ;; every u-for-v in the book as foul case -- 1,048 of them against 12 real
  ;; misreadings, where the measured rate is a quarter per thousand words.
  (define accident? (not (string=? set-form (word-composed w))))
  ;; For the apparatus, both members with the long s taken off, since that is
  ;; a glyph and not part of the reading either.
  (define printed (strip-conventions set-form))
  (define composed (strip-conventions (word-composed w)))
  (define just? (for/or ([c (in-list (word-causes w))])
                  (string-prefix? c "justification")))
  ;; Either half. The first is caused "word divided at the end of the line"
  ;; and the second "second half of a divided word", and matching only the
  ;; latter left every first half classified as a misreading.
  (define divided? (for/or ([c (in-list (word-causes w))])
                     (regexp-match? #rx"divid" c)))
  (define app (hash-ref variants key #f))
  (define ana
    (cond [app "#foul-case"]
          [accident? "#foul-case"]
          ;; Division before misreading, and before justification. Both halves
          ;; of a divided word carry the whole word as their copy reading, so
          ;; every comparison against it reports a change that never happened,
          ;; and this used to classify every hyphen in the book as a
          ;; misreading. The reading is not corrupt; the line is short.
          [divided? "#division"]
          [just? "#justification"]
          [(not (string=? (word-read w) (word-copy w))) "#misreading"]
          [(not (string=? (word-habit w) (word-read w))) "#habit"]
          [else "#copy"]))
  (define inner
    (cond
      ;; A press variant: the readings actually differ between copies, which
      ;; is what an apparatus is for.
      [app
       (string-append
        "<app>"
        (string-join
         (for/list ([r (in-list app)] #:unless (null? (car r)))
           (format "<rdg wit=\"~a\">~a</rdg>"
                   (string-join (for/list ([w (in-list (car r))]) (string-append "#" w)) " ")
                   (esc (cdr r))))
         "")
        "</app>")]
      ;; A literal: what was printed, and what the type should have read.
      [accident?
       (format "<choice><sic>~a</sic><corr>~a</corr></choice>" (esc printed) (esc composed))]
      ;; Altered for room. Which way it went matters: a shortened form is an
      ;; abbreviation and takes <abbr>/<expan>, but a *lengthened* one is not
      ;; an abbreviation at all and must not be labelled as one -- calling
      ;; "lorde" an abbreviation of "lord" is simply false, and the rendering
      ;; then tells the reader it was done to save space when it was done to
      ;; fill it. A fuller spelling is an orthographic variant: <orig>/<reg>.
      [(and just? (not (string=? (word-final w) (word-read w)))
            (< (string-length (word-final w)) (string-length (word-read w))))
       (format "<choice><abbr>~a</abbr><expan>~a</expan></choice>"
               (esc printed) (esc (word-read w)))]
      [(and just? (not (string=? (word-final w) (word-read w))))
       (format "<choice><orig>~a</orig><reg>~a</reg></choice>"
               (esc printed) (esc (word-read w)))]
      [else (esc reading)]))
  ;; Which individually identifiable pieces of type set this word, and where in
  ;; it they stood: "3:t177:bent to the right;7:t42:worn below the impression".
  ;;
  ;; This was in the HTML rendering and not in the TEI, which meant the TEI was
  ;; not in fact the whole record -- a facsimile built from it could not show
  ;; the damaged sorts, and a reader given the file could not follow a piece
  ;; from one forme to another. Since following a piece from one forme to
  ;; another is the entire method the program exists to test, that was the
  ;; wrong thing to leave out.
  ;;
  ;; An attribute rather than markup inside <w>, because the alternative is to
  ;; break the word into one element per character and the word is the unit
  ;; every other part of this file agrees on.
  (define sorts
    (for/list ([p (in-list (word-pieces w))])
      (format "~a:~a:~a" (car p) (sort-piece-id (cdr p))
              (sort-piece-damage (cdr p)))))
  (format "<w hp:x=\"~a\" hp:w=\"~a\" ana=\"~a\"~a~a~a~a~a>~a</w>"
          (em x) (em (word-width w)) ana
          (if (word-italic? w) " rend=\"italic\"" "")
          (if (string=? set-form reading)
              ""
              (format " hp:glyph=\"~a\"" (esc set-form)))
          (if (null? sorts)
              ""
              (format " hp:sorts=\"~a\"" (esc (string-join sorts ";"))))
          (if accident?
              (format " hp:composed=\"~a\"" (esc (word-composed w)))
              "")
          ;; The account of what happened to this word, stage by stage:
          ;; "misreading: copy X -> read Y; habit: Y -> Z; justification: ..."
          ;; ana gives the *class*, which is one word and cannot say which
          ;; letters moved or which device did it. The facsimile used to show
          ;; this on hover and lost it when the renderer began working from the
          ;; TEI, because the TEI had never carried it -- the same gap as the
          ;; damaged sorts and the statistics, found the same way.
          (let ([note (word-deviation w)])
            (if (and note (not (string=? note "")))
                (format " hp:note=\"~a\"" (esc note))
                ""))
          ;; The form as composed, given only when the case then got it wrong.
          ;;
          ;; Without this a renderer cannot show *which* letter the case
          ;; fouled, because the file holds the form as set and the reading,
          ;; and those differ by every long s and every u-for-v. Comparing them
          ;; rings 3,629 letters in a book with sixteen accidents in it -- the
          ;; same mistake, in a new place, as the one that once reported 1,048
          ;; accidents against a measured rate of five. So the composed form is
          ;; written out where it differs, and the comparison has two things to
          ;; compare that differ only by the case.
          inner))

(define (line->tei l n indent-x variants sig)
  (define spaces (set-line-spaces l))
  ;; The white, as metal. A gap is a piece of type like any other, and the file
  ;; recorded only where the words stood -- from which the *width* of a gap can
  ;; be worked out, but not what filled it. Named bodies rather than measures,
  ;; because that is what the compositor took out of the box: "thick thick hair
  ;; thick" is a line spaced with three thicks and a hair, and any consumer can
  ;; recover the width from the ladder declared in the header.
  ;;
  ;; One limitation, stated rather than hidden: these are the bodies the ladder
  ;; gives for the width. Where a box was empty the compositor made the same
  ;; white out of smaller pieces, and that substitution is recorded as an event
  ;; but not yet here.
  (define white
    (string-join
     (for*/list ([g (in-list (cons (set-line-indent l) spaces))]
                 #:when (> g 0)
                 [b (in-list (space-bodies g))])
       (string-replace (describe-space b) " " "-"))
     " "))
  (define lb
    (format "<lb n=\"~a\" hp:indent=\"~a\" hp:kind=\"~a\"~a~a~a/>"
            n (em (set-line-indent l)) (set-line-kind l)
            (if (string=? white "") "" (format " hp:white=\"~a\"" white))
            (if (set-line-turned-over? l) " hp:turned=\"true\"" "")
            ;; A word divided at the end of a line: TEI has an attribute for
            ;; precisely this, and it is almost never used.
            (if (for/or ([w (in-list (set-line-words l))])
                  (for/or ([c (in-list (word-causes w))])
                    (string-prefix? c "word divided")))
                " break=\"no\"" "")))
  (define ws
    (let loop ([ws (set-line-words l)] [i 0] [x (set-line-indent l)] [acc '()])
      (cond
        [(null? ws) (reverse acc)]
        [else
         (loop (cdr ws) (add1 i)
               (+ x (word-width (car ws))
                  (if (< i (length spaces)) (list-ref spaces i) 0))
               (cons (word->tei (car ws) x variants (list sig n i)) acc))])))
  (string-append "        " lb "\n"
                 (if (null? ws) "" (string-append "        " (string-join ws "") "\n"))))

;; The leaves cut out and replaced.
;;
;; The cause is recorded as the cause, including where it is `external' and the
;; program is not modelling it at all. McKerrow declines to model it too --
;; "into the purpose of these cancels we need not enter" (p. 223) -- and a file
;; that quietly dressed an unmodelled cause as a modelled one would be worse
;; than one that says which is which.
(define (cancels-tei b run)
  (define cs (if run (cancel-plan-cancels (press-run-cancels run)) '()))
  (cond
    [(null? cs) '()]
    [else
     (append
      (list "        <hp:cancels>")
      (for/list ([c (in-list cs)])
        (format (string-append
                 "          <hp:cancel at=\"~a\" cause=\"~a\" printed-in=\"~a\""
                 " conjugate=\"~a\" signs=\"~a\">~a</hp:cancel>")
                (esc (cancel-at c)) (esc (format "~a" (cancel-cause c)))
                (esc (or (cancel-sheet c) "a half-sheet of its own"))
                (if (cancel-conjugate? c) "true" "false")
                (esc (string-join (for/list ([s (in-list (cancel-signs c))])
                                    (format "~a" s)) " "))
                (esc (cancel-detail c))))
      (list "        </hp:cancels>"))]))

;; The leaves printed in one gathering and bound in another.
;;
;; McKerrow, p. 158: the preliminaries imposed "in the middle of his last
;; sheet, which may therefore run, as actually printed ... Z1, [*], *2, Z2, the
;; two centre leaves being cut out to be used as preliminaries." Whether the
;; cut pair came off as a fold or as singletons is the fact Bowers recovered
;; from the watermarks, so it is recorded even though the paper that would
;; betray it is not modelled yet.
(define (excisions-tei b)
  (define owners
    (for/list ([p (in-list (book-plans b))]
               #:when (pair? (gathering-plan-excised p)))
      p))
  (cond
    [(null? owners) '()]
    [else
     (append
      (list "        <hp:excisions>")
      (append*
       (for/list ([o (in-list owners)])
         (define view
           (for/or ([v (in-list (book-plans b))])
             (and (equal? (gathering-plan-shares v) (gathering-plan-place o)) v)))
         (for/list ([leaf (in-list (gathering-plan-excised o))])
           (format (string-append
                    "          <hp:excision from=\"~a\" leaf=\"~a\" bound-as=\"~a\""
                    " conjugate=\"~a\"/>")
                   (esc (series-mark (gathering-plan-series o)
                                     (gathering-plan-index o)))
                   leaf
                   (esc (if view
                            (series-mark (gathering-plan-series view)
                                         (gathering-plan-index view))
                            "?"))
                   (if (and view (gathering-plan-conjugate? view)) "true" "false")))))
      (list "        </hp:excisions>"))]))

(define (page->tei p fmt variants [folio #f] [role "text"])
  (define sig (page-sig p))
  (define rt (page-running-title p))
  (define cols
    (let loop ([cs (page-columns p)] [c 1] [n 0] [acc '()])
      (cond
        [(null? cs) (reverse acc)]
        [else
         (define measure
           (if (pair? (car cs))
               (em (set-line-measure (car (car cs))))
               (real->decimal-string (book-format-measure-ems fmt) 3)))
         (define-values (body n*)
           (for/fold ([body '()] [k n] #:result (values (reverse body) k))
                     ([l (in-list (car cs))])
             (values (cons (line->tei l (add1 k) 0 variants sig) body) (add1 k))))
         (loop (cdr cs) (add1 c) n*
               (cons (string-append
                      (format "      <div type=\"column\" n=\"~a\" hp:measure=\"~a\">\n        <cb n=\"~a\"/>\n        <ab>\n"
                              c measure c)
                      (apply string-append body)
                      "        </ab>\n      </div>\n")
                     acc))])))
  (string-append
   ;; The leaf and the sheet a page belongs to, resolved here rather than left
   ;; to the stylesheet. Which sheet a leaf came off is not arithmetic on leaf
   ;; numbers: a quarto gathering is one sheet folded twice, so all four of its
   ;; leaves are the same paper, while a folio in sixes is three sheets quired
   ;; one inside another, its outermost being leaves 1 and 6. XSLT 1.0 should
   ;; not have to know that, and the format is here.
   ;; `role' and `series' are what tells a reader of the file that a leaf is
   ;; preliminary matter, and there is nowhere else for that to live: the
   ;; signature alone will not say, because a book signed A for its front
   ;; matter and B onward for its text looks in the collation exactly like one
   ;; signed straight through from A.
   (format "    <div type=\"page\" n=\"~a\" resp=\"#comp~a\" hp:role=\"~a\" hp:series=\"~a\" hp:forme=\"~a\" hp:pressure=\"~a\" hp:leaf=\"~a\" hp:sheet=\"~a\">\n"
           (esc sig) (esc (page-compositor p)) (esc role)
           (esc (sig-series-name (page-ref-series (page-pref p))))
           (esc (page-forme-name p))
           (real->decimal-string (page-pressure p) 2)
           (esc (format "~a~a" (page-ref-mark (page-pref p))
                        (page-ref-leaf (page-pref p))))
           (esc (let* ([r (page-pref p)]
                       [n-leaves (book-format-leaves fmt)]
                       [leaf-n (page-ref-leaf r)])
                  (format "~a~a" (page-ref-mark r)
                          (if (<= (book-format-sheets fmt) 1)
                              1
                              (min leaf-n (- (add1 n-leaves) leaf-n)))))))
   (format "      <pb n=\"~a\" xml:id=\"pb-~a\"~a/>\n"
           (esc sig) (esc sig)
           (if rt (format " ed=\"~a\"" (esc (running-title-identifier rt))) ""))
   (if rt
       (format "      <fw type=\"head\" place=\"top-centre\" hp:damage=\"~a\">~a</fw>\n"
               (esc (title-fingerprint rt)) (esc (running-title-text rt)))
       "")
   ;; The page number is forme work like the running title and the signature:
   ;; a piece of type in the headline, carried from forme to forme with the
   ;; skeleton. Where the compositor set the wrong one, what printed is what
   ;; stands, and @n records the number it should have been.
   (if (and folio (not (string=? (folio-number-printed folio) "")))
       (format "      <fw type=\"pageNum\" place=\"top-~a\"~a>~a</fw>\n"
               (if (page-ref-recto? (page-pref p)) "right" "left")
               (if (string=? (folio-number-note folio) "")
                   ""
                   (format " n=\"~a\" hp:error=\"~a\""
                           (folio-number-want folio)
                           (esc (folio-number-note folio))))
               (esc (folio-number-printed folio)))
       "")
   (apply string-append cols)
   (if (string=? (page-signature p) "") ""
       (format "      <fw type=\"sig\" place=\"bot-left\">~a</fw>\n" (esc (page-signature p))))
   (if (string=? (page-catchword p) "") ""
       (format "      <fw type=\"catch\" place=\"bot-right\">~a</fw>\n" (esc (page-catchword p))))
   "    </div>\n"))

(define (book->tei b [run #f] [names '("A" "B")])
  (define variants (variant-index run))
  (string-append
   "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
   (format "<TEI xmlns=\"~a\" xmlns:hp=\"~a\">\n" TEI-NS HP-NS)
   (header b run names) "\n"
   "  <text>\n    <body>\n"
   (apply string-append
          (let ([folios (for/hash ([f (in-list (book-paging b))])
                          (values (folio-number-sig f) f))])
            (define roles
              (for/hash ([q (in-list (book-plans b))])
                (values (gathering-plan-place q)
                        (format "~a" (gathering-plan-role q)))))
            (for/list ([p (in-list (book-pages b))])
              (page->tei p (book-fmt b) variants
                         (hash-ref folios (page-sig p) #f)
                         (hash-ref roles (page-ref-gathering (page-pref p)) "text")))))
   "    </body>\n  </text>\n</TEI>\n"))

(module+ test
  (require rackunit racket/port xml)

  ;; Long enough to fill more than one page, or there is no catchword to find.
  (define b (set-book (make-house #:fmt QUARTO #:seed 1623)
                      (apply string-append
                             (for/list ([i (in-range 14)])
                               (string-append
                                "King. And can you by no drift of conference\n"
                                "Get from him why he puts on this confusion,\n"
                                "Grating so harshly all his days of quiet\n"
                                "With turbulent and dangerous lunacy?\n\n")))))
  (define r (run-press b #:copies 3 #:seed 1623 #:proof-rate 1.0))
  (define x (book->tei b r))

  ;; Well-formed, and parseable by a real XML reader.
  (check-not-exn (lambda () (read-xml (open-input-string x))))
  (check-true (regexp-match? #px"<TEI xmlns=\"http://www.tei-c.org/ns/1.0\"" x))
  (check-true (regexp-match? #px"xmlns:hp=" x))

  ;; The vocabulary that matters is actually used.
  (check-true (regexp-match? #px"<fw type=\"sig\"" x) "signatures are forme work")
  (check-true (regexp-match? #px"<fw type=\"catch\"" x) "so are catchwords")
  (check-true (regexp-match? #px"<lb n=" x) "type lines are milestones")
  (check-true (regexp-match? #px"<respStmt" x) "compositors are responsible parties")
  (check-true (regexp-match? #px"<taxonomy" x) "causes are a declared taxonomy")

  ;; The TEI has to be the whole record, or a rendering built from it needs a
  ;; second source and there are two renderers again. Two things were missing.
  ;; The white is metal and is recorded as metal. Without it the file said
  ;; where every word stood and nothing about what held them apart, which is
  ;; four pieces of type in every five words.
  (check-true (regexp-match? #px"hp:white=\"[a-z-]+( [a-z-]+)*\"" x)
              "the space-metal of each line is named, body by body")
  (check-true (regexp-match? #px"hp:white=\"[^\"]*thick-space" x)
              "and the normal word space is the commonest of them")

  (check-true (regexp-match? #px"<hp:statistics>" x)
              "the counts are in the file, not only in the printed report")
  (check-true (regexp-match? #px"hp:count hp:name=\"habit\"[^/]*ana=\"#habit\"" x)
              "and each count points at the taxonomy category it belongs to")
  ;; A rate of zero over a denominator of zero is not a rate. The report learned
  ;; to say so; the file has to say so too, or a consumer reads the bare 0.00
  ;; and cannot tell `did not happen' from `could not happen here'.
  ;; Asserted as the invariant rather than against one category, because
  ;; whether turn-over applies depends on whether the sample is verse -- which
  ;; is the very confusion this is meant to prevent.
  (check-equal? (for/list ([m (in-list (regexp-match* #px"<hp:count[^/]*/>" x))]
                           #:when (regexp-match? #px"hp:of=\"0\"" m)
                           #:unless (regexp-match? #px"hp:applicable=\"false\"" m))
                  m)
                '()
                "a measurement over an empty denominator says it does not apply")

  ;; The reading and the glyphs are separable, which is the point of the
  ;; exercise: a long s is a fact about the type, not about the word, and a
  ;; search for an English word should find it.
  (check-false (regexp-match? #px"<w[^>]*>[^<]*ſ" x)
               "no long s stands in the text of a word")
  (check-true (regexp-match? #px"hp:glyph=\"[^\"]*ſ" x)
              "it is recorded beside the reading instead")
  ;; and the two must still describe the same word
  ;; Only the plain words: one whose content is a <choice> or an <app> has
  ;; the reading inside the nested element, not as bare text.
  (let ([pairs (regexp-match* #px"<w[^>]*hp:glyph=\"([^\"]+)\"[^>]*>([^<>]+)</w>"
                              x #:match-select values)])
    (check-true (pair? pairs) "some word carries both a reading and its glyphs")
    (for ([p (in-list pairs)])
      (check-equal? (strip-conventions (cadr p)) (caddr p)
                    "the glyphs reduce to the reading")))
  (check-true (regexp-match? #px"ana=\"#" x) "and every word points into it")

  ;; Escaping is already proved by read-xml above: an unescaped & from the
  ;; text (the compositor sets a great many ampersands) would fail the parse.

  ;; Word count in the TEI matches the type.
  (define in-type
    (for*/sum ([p (in-list (book-pages b))] [l (in-list (page-all-lines p))])
      (length (set-line-words l))))
  (check-equal? (length (regexp-match* #px"<w " x)) in-type))
