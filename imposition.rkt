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
         (struct-out running-title) (struct-out skeleton) (struct-out type-rule)
         (struct-out cast-off-segment) (struct-out sig-series) (struct-out sig-run)
         FOLIO FOLIO-IN-SIXES QUARTO OCTAVO FORMATS
         book-format-pages signature-letter page-refs signed-leaves
         sheet-scheme formes-for-gathering setting-order
         collation-formula cast-off make-skeletons title-for
         make-rule work-rule! rule-fingerprint rule-damage-kinds
         skeleton-rules-in-order rearrange-rules! BOX-POSITIONS
         page-ref-signature page-ref-signed page-ref-mark skeleton-add-use!
         SIG-LETTERS JAGGARD-LETTERS
         MAIN-SERIES LOWER-SERIES STAR-SERIES SYMBOL-SERIES PILCROW-SERIES
         PI-SERIES PRELIM-SERIES-CHOICES
         series-mark series-prints? make-main-series)

(define SIG-LETTERS "ABCDEFGHIKLMNOPQRSTVXYZ")  ; J, U and W are not used

;; "A rare variant used at the Jaggard house in early seventeenth-century
;; London was a 20-letter signature alphabet, omitting X, Y, and Z" (Gaskell
;; n. 33a). The house that printed the First Folio is the one this program
;; quotes oftenest, so it may as well be able to sign like it.
(define JAGGARD-LETTERS "ABCDEFGHIKLMNOPQRSTV")

;; ---------------------------------------------------------------------------
;; The signature series
;; ---------------------------------------------------------------------------
;; A book may run through more than one series of signature marks, and the
;; reason is the order of work rather than any wish for variety. "The
;; preliminaries were not included in the main signature series of new books
;; **because it was usual to print them last**; reprints, however, sometimes
;; began the main signature series at the beginning of the preliminaries"
;; (Gaskell 8). McKerrow puts the same thing from the shop floor: "in composing
;; a new book from MS the normal course was to begin at the beginning of the
;; text and proceed straight on to the end, setting up the title-page and
;; preliminaries last" (p. 128).
;;
;; So the compositor reaching the end of his copy does not yet know how many
;; leaves the front matter will want, and cannot give it letters that would
;; collide with the text he has already signed. He gives it a series of its
;; own. The forms, in Gaskell's order of frequency (p. 52):
;;
;;   *  **  ***          "even commoner" than letters
;;   *  †  ‡  §          symbols "without logical order"
;;   a  b  c             main series A-, preliminaries a-: "always quite common"
;;   A  a  b  c          main series from B: "a characteristically English
;;                       habit ... to allow for a sheet of preliminaries
;;                       signed A"
;;
;; and, for leaves that carry no signature at all, McKerrow's π (p. 156),
;; "easily recalled by the p of 'preliminary'", adopted after him by Madan and
;; Greg. π is a citation mark only: nothing is set in the direction line, which
;; is the whole point of it.
;;
;; ¶ is not in Gaskell's list but is thick on the ground in Blayney's checklist
;; of one shop's output, where preliminary gatherings are signed ¶2, ¶4 and ¶8
;; (Appendix II, nos. 2, 20, 47, 62 among others), so it is here as a style of
;; its own rather than as one symbol among four.
(struct sig-series (name style alphabet) #:transparent)

(define (make-main-series [alphabet SIG-LETTERS])
  (sig-series "main" 'letters alphabet))

(define MAIN-SERIES    (make-main-series))
(define LOWER-SERIES   (sig-series "lower-case" 'lower SIG-LETTERS))
(define STAR-SERIES    (sig-series "asterisks"  'stars #f))
(define SYMBOL-SERIES  (sig-series "symbols"    'symbols #f))
(define PILCROW-SERIES (sig-series "pilcrow"    'pilcrow #f))
(define PI-SERIES      (sig-series "unsigned"   'pi #f))

;; What a house may choose for its preliminaries, in Gaskell's order.
(define PRELIM-SERIES-CHOICES
  (list STAR-SERIES SYMBOL-SERIES LOWER-SERIES PILCROW-SERIES
        MAIN-SERIES PI-SERIES))

(define SYMBOLS '("*" "†" "‡" "§"))

;; A run of the same mark repeated: * ** ***, ¶ ¶¶ ¶¶¶.
(define (repeated mark n)
  (apply string-append (for/list ([_ (in-range (add1 n))]) mark)))

;; 0 -> A, 22 -> Z, 23 -> Aa, 46 -> Aaa ...
(define (letters-mark alphabet n)
  (define len (string-length alphabet))
  (define-values (rep idx) (quotient/remainder n len))
  (make-string (add1 rep) (string-ref alphabet idx)))

(define (signature-letter n [alphabet SIG-LETTERS]) (letters-mark alphabet n))

;; The mark a bibliographer writes for the nth gathering of this series.
(define (series-mark s n)
  (case (sig-series-style s)
    [(letters) (letters-mark (or (sig-series-alphabet s) SIG-LETTERS) n)]
    [(lower)   (string-downcase
                (letters-mark (or (sig-series-alphabet s) SIG-LETTERS) n))]
    [(stars)   (repeated "*" n)]
    [(pilcrow) (repeated "¶" n)]
    [(symbols) (let-values ([(rep idx) (quotient/remainder n (length SYMBOLS))])
                 (repeated (list-ref SYMBOLS idx) rep))]
    [(pi)      (if (zero? n) "π" (format "~aπ" (add1 n)))]
    [else      (letters-mark SIG-LETTERS n)]))

;; Whether the mark is actually set in the direction line, or is only the
;; bibliographer's way of pointing at a leaf that carries nothing.
(define (series-prints? s) (not (eq? (sig-series-style s) 'pi)))

;; NB: not named `format' -- that is Racket's string formatter, and shadowing
;; it in a module this full of report text would be a slow-burning disaster.
;; `folds' is how many times the sheet is folded, and it is the one thing that
;; decides the size of a leaf. It is not the same as leaves per gathering and
;; must not be derived from it: folio in sixes is a *folio*, one fold, three
;; such sheets quired one inside another, so it has six leaves to the gathering
;; and the same leaf size as a plain folio. Deriving folds from leaves would
;; make it an octavo, which it emphatically is not. See paper.rkt.
(struct book-format (name symbol leaves sheets columns measure-ems lines folds)
  #:transparent)

(define (book-format-pages f) (* 2 (book-format-leaves f)))

;; The folio measure is Hinman's, measured off the First Folio itself (i. 35):
;; "The plays are all set in a type of which twenty lines measure about 83
;; millimetres; and since the horizontal measure of the type-column is also
;; about 83 mm., each ordinary Folio line may be said to contain 20 ems." He
;; gives the depth in the same breath -- "each full column contains sixty-six
;; lines plus a 'direction line' at its foot" -- and the direction line is the
;; skeleton's, carrying the catchword and signature, so 66 is the text.
;;
;; It was 16 ems, unsourced, and the error is not cosmetic. The plays are
;; chiefly verse and a pentameter runs about 18 ems, so at 16 a third of all
;; verse lines had to be turned over, each turn-over costing a second line of
;; type. Setting the whole Folio came out at 1,386 pages against the real
;; book's 908. Hinman is explicit that the ragged right is genuine -- "since
;; the plays are chiefly in verse, relatively few lines of the text proper
;; extend all the way to the right-hand margin of the column" -- so the white
;; is real and it is the measure that was wrong.
(define FOLIO-IN-SIXES (book-format "folio in sixes" "2°" 6 3 2 20.0 66 1))
(define FOLIO          (book-format "folio"          "2°" 2 1 2 20.0 66 1))
(define QUARTO         (book-format "quarto"         "4°" 4 1 1 21.0 38 2))
(define OCTAVO         (book-format "octavo"         "8°" 8 1 1 16.0 30 3))

(define FORMATS
  (hash "folio" FOLIO "folio6" FOLIO-IN-SIXES "folio-in-sixes" FOLIO-IN-SIXES
        "quarto" QUARTO "octavo" OCTAVO))

;; ---------------------------------------------------------------------------
;; Where each page falls on the sheet
;; ---------------------------------------------------------------------------

;; Page numbers (1-based within the gathering) on each forme of each sheet.
;; Returns a list of (cons outer-pages inner-pages). An empty inner means the
;; gathering was worked and turned: one forme did both sides.
(define (sheet-scheme f [leaves (book-format-leaves f)])
  (cond
    ;; A gathering shorter than the format's own is half a sheet, and was not
    ;; printed as one. Gaskell, p. 83: in half-sheet imposition "all the pages
    ;; for a half sheet were imposed in one forme; this forme was first printed
    ;; on one side of the whole sheet, then the heap of paper was turned (end
    ;; over end in quarto and octavo, side over side in duodecimo) and printed
    ;; from the same forme on the other side. Each printed sheet was then slit
    ;; in half to yield two copies of the same half sheet." One forme, one
    ;; pull per two copies -- which is why a two-leaf preliminary gathering is
    ;; so much cheaper than it looks, and why Blayney's shop used A2 for its
    ;; preliminaries oftener than any other arrangement.
    ;;
    ;; The method is only modelled where the short gathering really is half the
    ;; format, which is the case the program generates. Blayney's checklist has
    ;; stranger ones (A6 in a duodecimo, 12°: A6 B-N12 P6) that were got by
    ;; cutting, and those are not attempted here.
    [(and (= (book-format-sheets f) 1) (< leaves (book-format-leaves f)))
     (list (cons (for/list ([p (in-range 1 (add1 (* 2 leaves)))]) p) '()))]
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

;; `series' is the run of marks this gathering belongs to, and `index' its
;; place in that run. They are separate from `gathering', which stays the
;; position of the gathering in the finished book: the preliminaries are
;; gathering 0 of the book and gathering 0 of the star series at once, and
;; both facts are wanted.
(struct page-ref (gathering leaf recto? number series index) #:transparent)

(define (page-ref-mark r)
  (series-mark (page-ref-series r) (page-ref-index r)))

(define (page-ref-signature r)
  (format "~a~a~a" (page-ref-mark r)
          (page-ref-leaf r) (if (page-ref-recto? r) "r" "v")))

;; What is actually printed in the direction line, if anything.
(define (page-ref-signed r)
  (cond
    [(not (series-prints? (page-ref-series r))) ""]
    [(not (page-ref-recto? r)) ""]
    [(= (page-ref-leaf r) 1) (page-ref-mark r)]
    [else (format "~a~a" (page-ref-mark r) (page-ref-leaf r))]))

;; `overrides' lets single leaves of a gathering be signed from a different
;; series, which is not a curiosity but the commonest economy in the trade.
;;
;; McKerrow, p. 158: a printer whose text ends leaving two blank leaves in the
;; last sheet, and who has two leaves of preliminaries to print, "will as a
;; matter of course impose these preliminaries in the middle of his last sheet,
;; which may therefore run, as actually printed (supposing it to be in fours),
;; Z1, [*], *2, Z2, the two centre leaves being cut out to be used as
;; preliminaries." One sheet, four leaves, two signature series -- and the
;; middle two leaves carry * while their fellows carry Z.
;;
;; The map is from leaf position in the sheet to (list series index leaf), so
;; that the second leaf of sheet Z can be the first leaf of the star series.
(define (page-refs f gathering [series MAIN-SERIES] [index gathering]
                   #:leaves [leaves (book-format-leaves f)]
                   #:overrides [overrides (hash)])
  (for/list ([p (in-range 1 (add1 (* 2 leaves)))])
    (define leaf (quotient (add1 p) 2))
    (define o (hash-ref overrides leaf #f))
    (if o
        (page-ref gathering (third o) (odd? p) p (first o) (second o))
        (page-ref gathering leaf (odd? p) p series index))))

;; The first half of the leaves of a gathering carry a signature.
(define (signed-leaves f) (max 1 (quotient (book-format-leaves f) 2)))

;; ---------------------------------------------------------------------------
;; Formes
;; ---------------------------------------------------------------------------

(struct forme (gathering sheet side page-numbers [skeleton #:mutable]
                         [order #:mutable] mark)
  #:transparent)

;; Named by the mark the gathering carries, not by its place in the book: a
;; skeleton used for the preliminaries should say so.
(define (forme-name fm)
  (format "~a sheet ~a ~a" (forme-mark fm) (forme-sheet fm) (forme-side fm)))

(define (formes-for-gathering f gathering [series MAIN-SERIES] [index gathering]
                              #:leaves [leaves (book-format-leaves f)])
  (define mark (series-mark series index))
  (append*
   (for/list ([scheme (in-list (sheet-scheme f leaves))] [i (in-naturals 1)])
     (cond
       ;; worked and turned: a single forme prints both sides of the half sheet
       [(null? (cdr scheme))
        (list (forme gathering i "work and turn" (sort (car scheme) <) #f 0 mark))]
       [else
        (list (forme gathering i "inner" (sort (cdr scheme) <) #f 0 mark)
              (forme gathering i "outer" (sort (car scheme) <) #f 0 mark))]))))

;; The order in which the pages of a gathering are actually composed. Set
;; seriatim they go 1, 2, 3 ...; set by formes the house begins at the middle
;; of the gathering, where the casting off is least likely to have gone wrong
;; yet, and works outward.
(define (setting-order f gathering by-formes?
                       #:leaves [leaves (book-format-leaves f)])
  (cond
    [(not by-formes?) (for/list ([p (in-range 1 (add1 (* 2 leaves)))]) p)]
    [else
     (define all
       (append* (for/list ([fm (in-list (reverse (formes-for-gathering
                                                  f gathering #:leaves leaves)))])
                  (forme-page-numbers fm))))
     (remove-duplicates all)]))

(define sups (hash #\0 "⁰" #\1 "¹" #\2 "²" #\3 "³" #\4 "⁴"
                   #\5 "⁵" #\6 "⁶" #\7 "⁷" #\8 "⁸" #\9 "⁹"))

(define (sup n)
  (apply string-append
         (for/list ([ch (in-string (number->string n))]) (hash-ref sups ch))))

;; A stretch of consecutive gatherings signed from one series. `start' is the
;; place in the series where the stretch begins, so that a main series which
;; steps aside for the preliminaries and resumes at B can be described.
(struct sig-run (series start leaves) #:transparent)

;; One run, compressed the way a bibliographer writes it: consecutive
;; gatherings of the same extent become A–L⁴, a single one A⁴, and a change of
;; extent starts a new span. This is what turns eleven gatherings into
;; "A² B–L⁴", which is Blayney's own formula for the First Quarto of Lear.
(define (run->string run)
  (define s (sig-run-series run))
  (let span ([ls (sig-run-leaves run)] [i (sig-run-start run)] [out '()])
    (cond
      [(null? ls) (string-join (reverse out) " ")]
      [else
       (define n (car ls))
       (define same (let count ([xs ls] [k 0])
                      (if (and (pair? xs) (= (car xs) n)) (count (cdr xs) (add1 k)) k)))
       (define first-mark (series-mark s i))
       (define last-mark (series-mark s (+ i same -1)))
       (span (list-tail ls same) (+ i same)
             (cons (if (= same 1)
                       (format "~a~a" first-mark (sup n))
                       (format "~a–~a~a" first-mark last-mark (sup n)))
                   out))])))

;; The bibliographer's shorthand for the make-up of the book.
;;
;; Takes either a plain count of gatherings, for a book all in one series, or
;; a list of runs.
(define (collation-formula f runs)
  (define rs
    (if (list? runs)
        runs
        (list (sig-run MAIN-SERIES 0
                       (for/list ([_ (in-range runs)]) (book-format-leaves f))))))
  (define total (for*/sum ([r (in-list rs)] [n (in-list (sig-run-leaves r))]) n))
  (cond
    [(zero? total) (format "~a: (no sheets)" (book-format-symbol f))]
    [else
     (format "~a: ~a  [~a leaves; ~a pages]"
             (book-format-symbol f)
             (string-join (for/list ([r (in-list rs)] #:unless (null? (sig-run-leaves r)))
                            (run->string r))
                          " ")
             total (* 2 total))]))

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

  ;; A paragraph may be broken at the foot of a page, and must be, or every
  ;; page ends wherever its last paragraph happened to end and the rest is
  ;; white. Books do not look like that. The man casting off marks his copy at
  ;; a word in the middle of a paragraph exactly as readily as at its end.
  ;;
  ;; Only running prose breaks. A verse line is a line and cannot be halved; a
  ;; heading or a stage direction is a unit of its own.
  (define (splittable? u)
    (and (eq? (copy-unit-kind u) 'prose)
         (> (length (string-split (copy-unit-text u))) 12)))

  ;; Take as much of a paragraph as the room left on the page will hold,
  ;; measured the same way the rest of the casting off measures: by counting
  ;; and computing, not by setting it to see.
  (define (split-unit u room)
    (define ws (string-split (copy-unit-text u)))
    (let take ([rest ws] [head '()] [line 0.0] [lines 1])
      (cond
        [(null? rest) (values #f #f)]           ; it all fitted after all
        [else
         (define wd (width-of-word (car rest)))
         (define line* (if (zero? line) wd (+ line NORMAL-SPACE wd)))
         (define-values (l* n*)
           (if (> line* measure) (values wd (add1 lines)) (values line* lines)))
         (cond
           [(> n* room)
            (if (or (null? head) (< (length rest) 4))
                (values #f #f)                  ; not worth breaking
                (values (struct-copy copy-unit u
                                     [text (string-join (reverse head) " ")])
                        (struct-copy copy-unit u
                                     [text (string-join rest " ")])))]
           [else (take (cdr rest) (cons (car rest) head) l* n*)])])))

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
       ;; Where the boundary falls, and which way the error runs.
       ;;
       ;; This used to close a segment whenever the next unit would carry the
       ;; estimate past the page, so a page was never allotted more copy than
       ;; it held. The error could then only ever be short: measured across the
       ;; samples every page came out spun out or exact and none was crowded,
       ;; which made the omission branch, the report's count of dropped lines,
       ;; and the catchword mismatch all unreachable.
       ;;
       ;; Real casting off errs both ways. The man marking up the copy is
       ;; judging by eye and by count how much manuscript makes a page, and
       ;; when the surplus looks small he commits it -- and is sometimes wrong.
       ;; He is wrong oftener with prose than with verse, which is Gaskell's
       ;; point and the reason `slip' exists.
       (define over (- (+ used est) lines-per-page))
       ;; The bigger the surplus the likelier he is to see it, so the chance of
       ;; committing it falls away as it grows. A one-line overrun is easily
       ;; missed and gets absorbed by taking out a white line; the rare
       ;; four- or five-line misjudgement is what actually costs text, because
       ;; there is not that much white on the page to take out.
       (define misjudges?
         (and (> over 0) (<= over 6)
              (< (rnd g) (* 2.0 (- 1.0 accuracy)
                            (hash-ref slip (copy-unit-kind u) 1.0)
                            (/ 1.0 over)))))
       (cond
         ;; A paragraph longer than a page has to be broken even when the page
         ;; is empty, and this used to require `(pair? current)' -- so the
         ;; first paragraph of a page was never split, and a paragraph of two
         ;; hundred lines was cast off as one page of thirty-eight. Every book
         ;; whose copy has a long unbroken paragraph was measured wrong by the
         ;; difference, and it showed up here because a generated dedication is
         ;; one paragraph and would not grow past a single leaf however long it
         ;; was made.
         [(and (> over 0) (not misjudges?)
               (or (pair? current) (splittable? u)))
          ;; Fill the page with as much of this paragraph as it will take, and
          ;; carry the remainder to the next.
          (define room (- lines-per-page used))
          (define-values (head tail)
            (if (and (splittable? u) (>= room 2))
                (split-unit u room)
                (values #f #f)))
          (cond
            [head
             (loop (cons tail (cdr us)) '() 0
                   (cons (cast-off-segment (length segments)
                                           (reverse (cons head current))
                                           lines-per-page "")
                         segments))]
            [(pair? current)
             (loop us '() 0
                   (cons (cast-off-segment (length segments) (reverse current)
                                           used "")
                         segments))]
            ;; Nothing on the page and nothing to be done: a single unit that
            ;; will not divide takes its own page and overruns it. That is what
            ;; a heading or a verse line too long for the measure really does.
            [else (loop (cdr us) (cons u current) (+ used est) segments)])]
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

;; ---------------------------------------------------------------------------
;; Rules
;; ---------------------------------------------------------------------------
;; A rule is an object, not a line drawn on a page. It is a strip of brass or
;; cast metal, type-high so that it prints -- Blayney makes the distinction
;; against the furniture, which is not and does not (i. 124 n. 2) -- and cast
;; on a body of so many ems like any other sort; McKerrow infers the wide
;; spaces from exactly that, "ornaments and rules of several ems in length were
;; quite common" (p. 108). The Cambridge press bought them by the dozen from a
;; London joiner at about sixpence each (McKenzie i. 42).
;;
;; The Folio's page carries two kinds of rule and they behave differently,
;; which is the whole reason for modelling them:
;;
;;   BOX RULES frame the page. "Each page is surmounted by a headline and
;;   enclosed in a frame of 'box' rules. Five box rules appear, since one is
;;   used below as well as one above the headline. Although it is within the
;;   four rules that frame the page as a whole, therefore, the headline is
;;   nevertheless separated from the text proper by a rule" (Hinman i. 51).
;;   Five to a page, ten to a forme. They are part of the SKELETON: stripped
;;   from the wrought-off page and lifted to the next forme with the running
;;   titles, and Gaskell counts them among the skeleton's "regularly repeated
;;   rules or ornaments" (p. 109). A new set of box rules IS a new skeleton --
;;   Hinman treats the two as the same event at quire F (i. 44).
;;
;;   The CENTRE RULE divides the two columns and "belongs to the type-page
;;   proper rather than to its skeleton, and it was not removed from the
;;   type-page during stripping operations" (Hinman i. 130). It goes to the
;;   distributing case with the type it stands beside.
;;
;; Both take damage as they are worked, and both are therefore evidence of
;; order. Hinman names individual centre rules and follows them -- "the same
;; centre rule appears in both qq6 and rr3, and it shows [more damage in the
;; second]" (i. 148) -- exactly as he follows a distinctive type. What makes
;; the box rules more powerful still is that ten of them are in play at once:
;; "almost never, when rules took up new positions in a given forme, did they
;; resume exactly their former positions in some later forme. Hence a given
;; arrangement of rules serves to define a group of formes belonging to the
;; same printing sequence" (i. 148). The arrangement is the fingerprint, not
;; the individual rule.
(define rule-damage-kinds
  (list "nicked near the head" "bent at one end" "a break a third of the way down"
        "worn light in the middle" "the foot battered" "bruised at the corner"
        "printing heavy at one end" "a hair-line split"))

;; kind is 'head 'under-head 'foot 'left 'right -- the five of a box -- or
;; 'centre. `length' is in ems, since that is how a rule was bought and cast.
(struct type-rule (id kind length [damage #:mutable] [impressions #:mutable])
  #:transparent)

(define BOX-POSITIONS '(head under-head foot left right))

(define (make-rule id kind len g)
  ;; A rule out of the founder's is clean; it earns its imperfections at press.
  (type-rule id kind len (if (< (rnd g) 0.25) (list (rnd-choice g rule-damage-kinds)) '()) 0))

;; Ten rules to a forme, five to a page, and they are the skeleton's own.
(define (make-box-rules mark measure lines g)
  (for/list ([i (in-range 10)])
    (define kind (list-ref BOX-POSITIONS (modulo i 5)))
    (make-rule (format "~a~a" mark (add1 i)) kind
               (if (memq kind '(left right)) lines measure) g)))

;; Work a rule, and let it take its knocks.
;;
;; The rate is Hinman's, read off what he treats as remarkable. Centre rules
;; "take on new imperfections as time goes by", and for "fairly extreme
;; degeneration" he sends the reader to four pages in the *final* quire of the
;; Tragedies (i. 148) -- that is, extreme wear is worth a footnote at the end
;; of a book of some five hundred formes at 1,200 impressions each. A rule in
;; steady use is therefore in play for tens of thousands of impressions between
;; imperfections, not hundreds.
;;
;; One new defect per 25,000 impressions puts a well-used rule at two or three
;; by the end of a Folio and leaves most rules with one or none, which is what
;; makes the badly-worn ones worth Hinman's pointing at. The first rate here
;; was 250 times faster and every rule in the book reached the cap within ten
;; formes -- so every rule looked like every other rule, which destroys the one
;; property that makes them evidence.
(define IMPRESSIONS-PER-IMPERFECTION 25000)

(define (work-rule! r n g)
  (set-type-rule-impressions! r (+ (type-rule-impressions r) n))
  (when (and (< (length (type-rule-damage r)) 4)
             (< (rnd g) (/ n IMPRESSIONS-PER-IMPERFECTION)))
    ;; A rule cannot take the same injury twice; a second nick in the same
    ;; place is the same nick. Without this the record read "worn light in the
    ;; middle; worn light in the middle", which is not a fingerprint but a
    ;; stutter.
    (define fresh
      (filter (lambda (d) (not (member d (type-rule-damage r)))) rule-damage-kinds))
    (unless (null? fresh)
      (set-type-rule-damage! r (cons (rnd-choice g fresh) (type-rule-damage r))))))

(define (rule-fingerprint rs)
  (string-join (for/list ([r (in-list rs)]) (type-rule-id r)) " "))

(struct skeleton (name titles box-rules [arrangement #:mutable]
                       [used-for #:mutable]) #:transparent)

(define (title-for sk position)
  (list-ref (skeleton-titles sk) (modulo position (length (skeleton-titles sk)))))

;; The ten box rules in the order they stand in this forme. Made ready afresh,
;; they almost never go back where they were, so the order is re-drawn and the
;; new order marks a new group of formes.
(define (skeleton-rules-in-order sk)
  (for/list ([i (in-list (skeleton-arrangement sk))])
    (list-ref (skeleton-box-rules sk) i)))

(define (rearrange-rules! sk g)
  (set-skeleton-arrangement! sk (shuffle-list g (build-list 10 values))))

(define (shuffle-list g xs)
  (let loop ([v (list->vector xs)] [i (sub1 (vector-length (list->vector xs)))])
    (cond
      [(<= i 0) (vector->list v)]
      [else
       (define j (rnd-int g (add1 i)))
       (define t (vector-ref v i))
       (vector-set! v i (vector-ref v j))
       (vector-set! v j t)
       (loop v (sub1 i))])))

(define (skeleton-add-use! sk name)
  (set-skeleton-used-for! sk (append (skeleton-used-for sk) (list name))))

(define (make-skeletons count titles-each head g [measure 20] [lines 66])
  (for/list ([s (in-range count)])
    (define mark (integer->char (+ (char->integer #\I) s)))
    (skeleton
     (format "Skeleton ~a" (make-string (add1 s) #\I))
     (for/list ([t (in-range titles-each)])
       (running-title head
                      (rnd-sample g damage-kinds (+ 1 (rnd-int g 3)))
                      (format "~a~a" mark (add1 t))))
     (make-box-rules mark measure lines g)
     (build-list 10 values)
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

  ;; Casting off must be able to err in both directions.
  ;;
  ;; The rule used to close a segment before any unit that would carry the
  ;; estimate past the page, so a page could never be allotted more copy than
  ;; it held and every error ran short. That silently disabled the crowding
  ;; devices, the omission branch, and the catchword mismatch. A one-sided
  ;; error is not a small inaccuracy here; it removes a whole class of
  ;; evidence, so it is worth a test of its own.
  (let ()
    (define (segment-lengths acc seed)
      (define g (make-rng seed))
      (define units
        (for/list ([i (in-range 400)])
          (copy-unit 'prose (make-string 60 #\a) i #f)))
      (for/list ([s (in-list (cast-off units 2400 38 g acc))])
        (cast-off-segment-estimated-lines s)))
    (define ls (append (segment-lengths 0.75 1) (segment-lengths 0.75 2)))
    (check-true (for/or ([n (in-list ls)]) (> n 38))
                "some page is cast off long")
    (check-true (for/or ([n (in-list ls)]) (< n 38))
                "some page is cast off short"))

  ;; A paragraph longer than a page must be broken even when it begins the
  ;; page. This is the one case the splitting rule used to miss, because it
  ;; asked whether anything was already on the page before it would divide
  ;; anything: a single unit of two hundred lines came back as one segment of
  ;; two hundred, and the book was measured as one page where it wanted six.
  (let ()
    (define g (make-rng 5))
    (define long (copy-unit 'prose (string-join (for/list ([i 1200]) "word") " ") 0 #f))
    (define segs (cast-off (list long) 2400 38 g 1.0))
    (check-true (> (length segs) 1)
                "a long paragraph is divided over pages rather than crammed into one")
    ;; and no page is allotted more than a page will hold. The old rule gave
    ;; the whole paragraph to one segment, which this catches directly.
    (for ([s (in-list segs)])
      (check-true (<= (cast-off-segment-estimated-lines s) 38)
                  (format "no segment is allotted ~a lines for a 38-line page"
                          (cast-off-segment-estimated-lines s))))
    ;; and nothing is lost in the dividing
    (define words
      (for*/sum ([s (in-list segs)] [u (in-list (cast-off-segment-units s))])
        (length (string-split (copy-unit-text u)))))
    (check-equal? words 1200 "every word survives the division"))

  ;; A unit that cannot be divided -- a heading, a verse line -- still takes a
  ;; page rather than sending the loop round for ever on the same unit.
  (let ()
    (define g (make-rng 5))
    (define head (copy-unit 'heading (string-join (for/list ([i 400]) "WORD") " ") 0 #f))
    (define segs (cast-off (list head) 2400 38 g 1.0))
    (check-equal? (length segs) 1)
    (check-equal? (length (cast-off-segment-units (car segs))) 1))

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

  ;; The preliminary series, in Gaskell's four forms plus McKerrow's π.
  (check-equal? (for/list ([n 3]) (series-mark STAR-SERIES n)) '("*" "**" "***"))
  (check-equal? (for/list ([n 5]) (series-mark SYMBOL-SERIES n))
                '("*" "†" "‡" "§" "**"))
  (check-equal? (for/list ([n 3]) (series-mark PILCROW-SERIES n)) '("¶" "¶¶" "¶¶¶"))
  (check-equal? (for/list ([n 3]) (series-mark LOWER-SERIES n)) '("a" "b" "c"))
  (check-equal? (series-mark LOWER-SERIES 23) "aa")

  ;; π is a citation mark and nothing else: it stands for a leaf with no
  ;; signature on it, so it must never be set in the direction line.
  (check-equal? (series-mark PI-SERIES 0) "π")
  (check-true (series-prints? STAR-SERIES))
  (check-false (series-prints? PI-SERIES))
  (for ([r (in-list (page-refs QUARTO 0 PI-SERIES 0))])
    (check-equal? (page-ref-signed r) ""
                  "an unsigned leaf carries no signature"))
  (check-equal? (page-ref-signature (car (page-refs QUARTO 0 PI-SERIES 0))) "π1r")

  ;; Gaskell n. 33a: Jaggard omitted X, Y and Z, so his 20-letter alphabet
  ;; doubles three gatherings sooner than everyone else's.
  (check-equal? (signature-letter 20 JAGGARD-LETTERS) "AA")
  (check-equal? (signature-letter 20 SIG-LETTERS) "X")

  ;; A star gathering is signed like any other: *, *2, *3.
  (define stars (page-refs QUARTO 0 STAR-SERIES 1))
  (check-equal? (page-ref-signed (first stars)) "**")
  (check-equal? (page-ref-signed (third stars)) "**2")

  ;; Blayney's own formula for the First Quarto of Lear (Appendix II, no. 56):
  ;; a half-sheet of preliminaries, then the text from B.
  (check-equal? (collation-formula QUARTO (list (sig-run MAIN-SERIES 0 '(2 4 4 4 4 4 4 4 4 4 4))))
                "4°: A² B–L⁴  [42 leaves; 84 pages]")
  ;; The characteristically English habit: main series from B, preliminaries
  ;; A and a. Blayney no. 84 is 4°: A4 a2 B-H4.
  (check-equal? (collation-formula
                 QUARTO (list (sig-run MAIN-SERIES 0 '(4))
                              (sig-run LOWER-SERIES 0 '(2))
                              (sig-run MAIN-SERIES 1 '(4 4 4 4 4 4 4))))
                "4°: A⁴ a² B–H⁴  [34 leaves; 68 pages]")

  ;; Half-sheet imposition: a two-leaf gathering in quarto is one forme worked
  ;; and turned, not two. This is the commonest preliminary arrangement in
  ;; Blayney's checklist and it halves the formes the shop must find room for.
  (define half (formes-for-gathering QUARTO 0 MAIN-SERIES 0 #:leaves 2))
  (check-equal? (length half) 1)
  (check-equal? (forme-side (car half)) "work and turn")
  (check-equal? (forme-page-numbers (car half)) '(1 2 3 4))
  (check-equal? (length (formes-for-gathering QUARTO 0)) 2)

  ;; Setting by formes visits every page exactly once, in a different order.
  (define so (setting-order QUARTO 0 #t))
  (check-equal? (sort so <) '(1 2 3 4 5 6 7 8))
  (check-false (equal? so '(1 2 3 4 5 6 7 8)))
  (check-equal? (setting-order QUARTO 0 #f) '(1 2 3 4 5 6 7 8))

  ;; ---- Rules ----------------------------------------------------------
  ;; "Five box rules appear, since one is used below as well as one above the
  ;; headline" (Hinman i. 51), and ten to the forme -- he reads the ten as a
  ;; set: "all the formes showing exactly the same arrangement of their ten
  ;; box rules" (i. 148).
  (define gg (make-rng 4))
  (define sks (make-skeletons 2 4 "THE TRAGEDIE" gg 20 66))
  (define sk (car sks))
  (check-equal? (length (skeleton-box-rules sk)) 10)
  (check-equal? (length (remove-duplicates
                         (map type-rule-kind (skeleton-box-rules sk))))
                5)
  (check-equal? (sort (map symbol->string
                           (remove-duplicates
                            (map type-rule-kind (skeleton-box-rules sk))))
                      string<?)
                '("foot" "head" "left" "right" "under-head"))
  ;; Head and foot are cast to the measure; the sides run the depth of the page.
  (for ([r (in-list (skeleton-box-rules sk))])
    (check-equal? (type-rule-length r)
                  (if (memq (type-rule-kind r) '(left right)) 66 20)))
  ;; Every rule is a distinct object, and the two skeletons share none: a new
  ;; set of box rules IS a new skeleton (Hinman i. 44).
  (define ids (append (map type-rule-id (skeleton-box-rules (first sks)))
                      (map type-rule-id (skeleton-box-rules (second sks)))))
  (check-equal? (length (remove-duplicates ids)) 20)

  ;; The arrangement is the fingerprint, and re-laying the forme changes it.
  (define before (rule-fingerprint (skeleton-rules-in-order sk)))
  (rearrange-rules! sk gg)
  (check-not-equal? before (rule-fingerprint (skeleton-rules-in-order sk)))
  ;; but the rules themselves are the same ten pieces of brass
  (check-equal? (sort (string-split before) string<?)
                (sort (string-split (rule-fingerprint (skeleton-rules-in-order sk)))
                      string<?))

  ;; A rule takes its knocks slowly, and never the same knock twice. At
  ;; Hinman's rate a rule worked through a whole Folio -- some 500 formes at
  ;; 1,200 impressions, of which one rule sees a fraction -- picks up a
  ;; handful of imperfections, not a fresh one every forme.
  (define r0 (make-rule "T1" 'head 20 (make-rng 11)))
  (for ([_ (in-range 200)]) (work-rule! r0 1200 (make-rng 11)))
  (check-equal? (type-rule-impressions r0) 240000)
  (check-true (<= (length (type-rule-damage r0)) 4))
  (check-equal? (length (remove-duplicates (type-rule-damage r0)))
                (length (type-rule-damage r0))
                "a rule cannot take the same injury twice"))
