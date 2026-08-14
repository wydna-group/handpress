#lang racket/base
;;; The printing house: casting off, dividing the stints, and setting the book.
;;;
;;; This module is the shop floor. It takes a copy-text and a format, measures
;;; the copy out into pages, hands them to the workmen in the order the house
;;; would actually set them, and lets each man discover for himself that the
;;; casting off was wrong.
;;;
;;; That discovery is the interesting part. A compositor setting seriatim who
;;; finds he has overrun simply carries the surplus to the next page. A
;;; compositor setting by formes cannot: the next page of his copy belongs to
;;; a different forme and may already be standing in type. So he crowds --
;;; thinner spaces, more abbreviations, verse run together as prose, the white
;;; lines suppressed -- and if crowding will not do it, he leaves something
;;; out. Crowded and gaping pages are therefore not accidents of taste. They
;;; are the signature of setting by formes, and they mark the joins in the
;;; casting off.

(require racket/list racket/string racket/math
         "pagination.rkt" "metrics.rkt" "orthography.rkt" "typecase.rkt" "copytext.rkt"
         "corrector.rkt" "compositor.rkt" "imposition.rkt" "prelims.rkt"
         "titlepage.rkt" "paper.rkt" "rng.rkt")

(provide (struct-out page) (struct-out book) (struct-out house)
         (struct-out standing-type) (struct-out gathering-plan)
         make-house set-book house-layout book-layout
         page-sig page-all-lines page-text book-gatherings book-collation
         book-find-page book-runs plan-bound-leaves
         PRELIM-SCHEMES PRELIM-SCHEME-NAMES MIS-RESUME-RATE)

;; The field is `pref', not `ref': `page-ref' is already the struct that names
;; a leaf and side in imposition.rkt, and two bindings of that name in one
;; module is a morning wasted.
;; `box-rules' are the five that frame this page and `centre-rule' the one that
;; divides its columns. They are objects in the forme and not decoration on a
;; page: see the note on rules in imposition.rkt. The two are held separately
;; because they belong to different things and go different ways at
;; distribution -- the box rules are stripped off with the skeleton and lifted
;; to the next forme, the centre rule stays with the type and goes to the case
;; with it (Hinman i. 130).
(struct page (pref columns compositor running-title catchword signature
                   pressure cast-off-note forme-name omitted
                   box-rules centre-rule)
  #:transparent)

(define (page-sig p) (page-ref-signature (page-pref p)))

(define (page-all-lines p) (append* (page-columns p)))

(define (page-text p)
  (string-join (map line-text (page-all-lines p)) "\n"))

;; `paper' travels with the book because a leaf has no size without it, and
;; every consumer downstream -- the description, the TEI, the facsimile -- has
;; a book and not a house to hand.
(struct book (pages formes skeletons fmt paper events stints case title
                    copy-units authors-copy preparation standing paging
                    plans division titlepage prelim-scheme moved-to-end
                    cut-from-last-sheet?)
  #:transparent)

;; The leaf, and where the type page sits on it. Computed here, once.
(define (book-layout b)
  (define fmt (book-fmt b))
  (define-values (lh lw) (paper-leaf (book-paper b) (book-format-folds fmt)))
  (define-values (th tw) (type-page-mm (book-format-lines fmt)
                                       (book-format-measure-ems fmt)
                                       (book-format-columns fmt)))
  (leaf-layout lh lw th tw))

;; The high-water mark of standing type, and the page-by-page ledger behind it.
(struct standing-type (peak-sorts peak-pages ledger by-formes?) #:transparent)

(define (book-gatherings b)
  (add1 (for/fold ([m -1]) ([p (in-list (book-pages b))])
          (max m (page-ref-gathering (page-pref p))))))

(define (book-runs b) (plans->runs (book-plans b)))

(define (book-collation b)
  (collation-formula (book-fmt b) (book-runs b)))

(define (book-find-page b sig)
  (for/or ([p (in-list (book-pages b))]) (and (string=? (page-sig p) sig) p)))

;; ---------------------------------------------------------------------------
;; The house
;; ---------------------------------------------------------------------------

(struct house (fmt paper compositor-names seed by-formes? conventions case-scale
                   cast-off-accuracy n-skeletons formes-standing
                   prepare-copy? title profiles condition stint-sheets
                   paging-error find-prelims? titlepage? book-title author
                   printer publisher sig-alphabet prelim-style mis-resume cast-off-method)
  #:transparent)

;; The leaf this house's paper and format make, and where the type page sits on
;; it. One computation, so that the report, the TEI and the facsimile cannot
;; disagree about the size of a page.
(define (house-layout h)
  (define fmt (house-fmt h))
  (define-values (lh lw) (paper-leaf (house-paper h) (book-format-folds fmt)))
  (define-values (th tw) (type-page-mm (book-format-lines fmt)
                                       (book-format-measure-ems fmt)
                                       (book-format-columns fmt)))
  (leaf-layout lh lw th tw))

(define (make-house #:fmt [fmt QUARTO]
                    ;; The sheet the shop buys. Format says how often it was
                    ;; folded; this says how big it was before anyone folded
                    ;; it, and the two together are the only thing that gives
                    ;; a leaf a size. Foolscap by default: Gaskell, p. 68, has
                    ;; the sixteenth century's ordinary printing paper in that
                    ;; range, and that is this program's period.
                    #:paper [paper DEFAULT-PAPER]
                    #:compositors [names '("A" "B")]
                    #:seed [seed 1623]
                    #:by-formes? [by-formes? #t]
                    #:conventions [cv (conventions #t #t #t #t #t 1600)]
                    #:case-scale [case-scale 1.0]
                    #:cast-off-accuracy [acc 0.93]
                    #:skeletons [nsk 2]
                    #:formes-standing [standing 2]
                    #:prepare-copy? [prep? #t]
                    #:title [title "THE HISTORY"]
                    ;; so that a workman can be driven with figures derived
                    ;; from a real book rather than from the built-in guesses
                    #:profiles [profiles PROFILES]
                    ;; new | used | worn | foul, or a number: how much of the
                    ;; fount is individually identifiable by its damage
                    #:condition [condition 'used]
                    ;; Mean length of a compositor's stint, in sheets.
                    ;;
                    ;; This program used to change compositors every forme, a
                    ;; tidy alternation that the one shop whose records survive
                    ;; flatly contradicts. McKenzie: when two or more men
                    ;; worked on a book "they did not work together setting
                    ;; sheet and sheet about. What usually happened was that
                    ;; one took over where the other left off and then composed
                    ;; as many sheets as the master found convenient or as
                    ;; other commitments allowed" (i. 107).
                    ;;
                    ;; His quarto Virgil shows the shape: Bertram set A-E,
                    ;; Crownfield F-3G, Michaelis 3H-3Z, Bertram again to 4F,
                    ;; Delie a single sheet at 4G, Crownfield from 4H, Bertram
                    ;; finishing. Long blocks, with the occasional single sheet
                    ;; dropped in where a man was free.
                    ;;
                    ;; Left at #f the length follows the size of the shop,
                    ;; which is Gaskell's rule (p. 41) and the thing that
                    ;; reconciles the authorities. Where there were "no more
                    ;; than two or three" compositors the tendency was for a
                    ;; man to concentrate on particular books "and to set at
                    ;; least whole sheets or whole formes" -- McKenzie's
                    ;; Cambridge, and long stints. Where there were more, the
                    ;; copy went out in small "takings" or "takes" "to whoever
                    ;; was ready for them", so that "the setting of sheets,
                    ;; formes, and even individual pages were on occasion
                    ;; shared". A big house really does approach the rapid
                    ;; alternation this program used to do unconditionally.
                    #:stint-sheets [stint #f]
                    ;; how freely the paging goes wrong; no hand-press
                    ;; book of any length was numbered correctly
                    #:paging-error [paging-error 0.04]
                    ;; Whether to fall back on the heading vocabulary when
                    ;; the copy declares nothing. **Off by default, and
                    ;; experimental.**
                    ;;
                    ;; The division was a decision taken in the shop and cannot
                    ;; be recovered from the words. Worse, the vocabulary that
                    ;; tries is period-bound -- it looks for "to the right
                    ;; honourable" and "the epistle dedicatorie" -- so it is
                    ;; useless on the modern copy people will actually bring,
                    ;; and it fails on early copy too whenever the front matter
                    ;; carries no heading, which is common. Aylett's Peace with
                    ;; her Foure Garders opens with fourteen lines of
                    ;; dedicatory verse under no heading at all.
                    ;;
                    ;; What replaces it is import.rkt: read what the document
                    ;; says about itself, and where it says nothing, give the
                    ;; book no preliminaries. See prelims.rkt.
                    #:find-prelims? [find-prelims? #f]
                    #:titlepage? [titlepage? #t]
                    ;; The title as it is to be set on the title-page, which is
                    ;; not the running title: "M. William Shak-speare: HIS True
                    ;; Chronicle Historie ..." against "King Lear".
                    #:book-title [book-title #f]
                    #:author [author #f]
                    #:printer [printer #f]
                    #:publisher [publisher #f]
                    ;; Gaskell n. 33a: Jaggard signed from a 20-letter
                    ;; alphabet, everyone else from 23.
                    #:sig-alphabet [alphabet SIG-LETTERS]
                    ;; How the preliminaries are signed: one of the names in
                    ;; PRELIM-SCHEMES, or #f to draw one. A house normally
                    ;; signed its front matter the same way every time; the
                    ;; mixture is what you see across a trade, not within a
                    ;; shop.
                    #:prelim-style [prelim-style #f]
                    ;; How often the compositor mistakes the point at which he
                    ;; left off, between one page and the next. McKerrow gives
                    ;; the mechanism and calls it a "comparative frequency",
                    ;; which is not a number -- **no source gives a rate**.
                    #:mis-resume [mis-resume MIS-RESUME-RATE]
                    ;; `pages' is Smith's, the safest way, error bounded at one
                    ;; page. `breaks' is Moxon's, settled only at a break, and
                    ;; Smith's crowding devices do not fire under it at all.
                    #:cast-off-method [cast-off-method 'pages])
  (house fmt paper names seed by-formes? cv case-scale acc nsk
         (max 1 standing) prep? title profiles condition
         (cond
           [stint (max 1 stint)]
           [(<= (length names) 3) 4]     ; whole sheets at a time
           [(<= (length names) 5) 2]
           [else 1])                     ; takes, shared about
         paging-error find-prelims? titlepage? book-title author
         printer publisher alphabet prelim-style mis-resume cast-off-method))

;; How often the compositor mistakes the point at which he left off, per page.
;; **No source gives a rate.** McKerrow says "comparative frequency" and names
;; five books for the repetition case; that is a demonstration that it happened,
;; not a measurement of how often. Set low enough that a Folio shows it a few
;; dozen times, and disclaimed wherever it is counted.
(define MIS-RESUME-RATE 0.02)

(define (house-spec h)
  (page-spec (exact-round (* (book-format-measure-ems (house-fmt h)) UNITS-PER-EM))
             (book-format-lines (house-fmt h))
             0 EM-QUAD))

(define (house-capacity h)
  (* (book-format-lines (house-fmt h)) (book-format-columns (house-fmt h))))

;; ---------------------------------------------------------------------------
;; Composing a page
;; ---------------------------------------------------------------------------

(define (white-line spec)
  (make-line '() '() 0 (page-spec-measure spec) 'blank
             #:justification "white line"))

;; Lay out a segment of copy at a given pressure. No type is picked here, so a
;; trial costs nothing but time.
(define (compose c units spec pressure)
  (define crowded? (> pressure 0.35))
  (define prof (comp-profile c))
  (let loop ([us units] [pending #f] [run-on '()] [out '()])
    (define (flush-run-on out)
      (if (null? run-on)
          out
          (append (reverse (set-prose c (string-join (reverse run-on) " ")
                                      spec pressure #:first-indent? #f))
                  out)))
    (cond
      [(null? us) (reverse (flush-run-on out))]
      [else
       (define u (car us))
       (define rest (cdr us))
       (case (copy-unit-kind u)
         ;; A white line is a line of quads and costs a line of the page. The
         ;; compositor sets one where the copy asks for a space; he does not
         ;; set one merely because the editor of a modern text put a blank line
         ;; between two speeches. The Folio sets a play solid -- sixty-six
         ;; lines to the column with no white in them, the white kept for the
         ;; act divisions -- and this was spending a line on every speech.
         [(blank)
          (define o (flush-run-on out))
          (loop rest pending '()
                (if (or crowded? (equal? (copy-unit-speaker u) EDITORIAL))
                    o
                    (cons (white-line spec) o)))]

         [(heading)
          (define o (flush-run-on out))
          (define head (reverse (set-heading c (copy-unit-text u) spec)))
          (loop rest pending '()
                (if crowded?
                    (append head o)
                    (cons (white-line spec)
                          (append head (cons (white-line spec) o)))))]

         [(stage)
          (define o (flush-run-on out))
          (loop rest pending '()
                (append (reverse (set-stage-direction c (copy-unit-text u) spec)) o))]

         ;; A title-page line. The `speaker' slot carries the style, which is
         ;; a squeeze -- copy-unit has no room for one -- but the alternative
         ;; was a kind per case and a kind per fount.
         [(centred)
          (define o (flush-run-on out))
          (loop rest pending '()
                (append (reverse (set-centred c (copy-unit-text u) spec
                                              #:italic? (equal? (copy-unit-speaker u)
                                                                "italic")))
                        o))]

         ;; A rule, a device or a plain white line of the title-page: nothing
         ;; is set, but the depth is taken up.
         [(rule)
          (define o (flush-run-on out))
          (loop rest pending '() (cons (white-line spec) o))]

         [(prefix)
          (loop rest (copy-unit-text u) run-on (flush-run-on out))]

         [(verse)
          (define lead (if pending (list (speech-prefix c pending pressure)) '()))
          (cond
            [(and crowded? (profile-normalises-verse? prof) (null? lead)
                  (< (rnd (comp-rng c)) 0.7))
             (loop rest #f (cons (copy-unit-text u) run-on) out)]
            [else
             (define o (flush-run-on out))
             (loop rest #f '()
                   ;; A verse speech arrives one line to a copy-unit, so unlike
                   ;; prose only the line actually carrying the prefix is the
                   ;; first line of a speech, and only that one is indented.
                   (append (reverse (set-verse c (copy-unit-text u) spec pressure
                                               #:lead lead
                                               #:first-indent? (pair? lead)))
                           o))])]

         [else
          (define lead (if pending (list (speech-prefix c pending pressure)) '()))
          (define o (flush-run-on out))
          (loop rest #f '()
                ;; The line carrying the speaker is indented and the turnovers
                ;; under it are not, which is how the Folio sets a speech and
                ;; is plain on any plate of it. This read `(null? lead)',
                ;; suppressing the indent on exactly the line that should have
                ;; had it and indenting only the speeches with no prefix.
                (append (reverse (set-prose c (copy-unit-text u) spec pressure
                                            #:first-indent? #t
                                            #:lead lead))
                        o))])])))

;; Bring the page to its depth.
;;
;; White lines are the compositor's coarse adjustment and the first thing he
;; touches: they come out when he is crowded and go in when he is short. Only
;; when the white is gone does the difficulty become visible in the text.
;;
;; A page need not come out to the exact depth of its fellows. Gaskell notes
;; books cast off imperfectly and set by formes in which one side of the sheet
;; has pages of regular length and the other "pages of irregular length ...
;; which had to be made to fit with what had already been set and printed". So
;; a line or two over or under is simply allowed to stand.
(define (fit-page c lines capacity spec by-formes? sig)
  (define slack 2)
  (define (drop-white ls n)
    (let loop ([ls ls] [n n] [out '()])
      (cond
        [(null? ls) (reverse out)]
        [(and (> n 0) (eq? (set-line-kind (car ls)) 'blank))
         (loop (cdr ls) (sub1 n) out)]
        [else (loop (cdr ls) n (cons (car ls) out))])))

  (define n (length lines))
  (cond
    [(and (> n capacity) (<= n (+ capacity slack))) (values lines '() '())]

    [(> n capacity)
     (define trimmed (drop-white lines (- n capacity)))
     (define taken (- n (length trimmed)))
     (when (> taken 0)
       (add-event! c (make-ev 'justification
                              (format "~a white line(s) taken out to save room" taken)
                              sig (comp-profile c))))
     (cond
       [(<= (length trimmed) capacity) (values trimmed '() '())]
       [by-formes?
        ;; There is nowhere to put it. The page belongs to a forme, and the
        ;; copy for the next page belongs to another forme already cast off,
        ;; perhaps already standing in type. So the compositor leaves the
        ;; surplus out and says nothing. This is one of the ways text
        ;; disappears from printed plays.
        (define surplus (- (length trimmed) capacity))
        (add-event! c (make-ev 'justification
                               (format "~a line(s) of copy omitted for want of room"
                                       surplus)
                               sig (comp-profile c)))
        (values (take trimmed capacity) '()
                (for/list ([l (in-list (drop trimmed capacity))]
                           #:unless (null? (set-line-words l)))
                  (line-text l)))]
       [else (values (take trimmed capacity) (drop trimmed capacity) '())])]

    [(< n (sub1 capacity))
     ;; Spin it out: an extra white line wherever there is already one, which
     ;; is where the eye will not resent it.
     (define need (- capacity n))
     (define-values (out added)
       (for/fold ([out '()] [added 0]) ([l (in-list lines)])
         (if (and (eq? (set-line-kind l) 'blank) (< added need))
             (values (cons (white-line spec) (cons l out)) (add1 added))
             (values (cons l out) added))))
     (when (> added 0)
       (add-event! c (make-ev 'justification
                              (format "~a white line(s) put in to fill the page" added)
                              sig (comp-profile c))))
     (values (take (reverse out) (min capacity (length out))) '() '())]

    [else (values lines '() '())]))

(define (make-ev kind detail sig prof)
  (event kind detail sig 0 -1 (profile-name prof) "" ""))

(define (split-columns lines columns per-column)
  (if (<= columns 1)
      (list lines)
      (for/list ([c (in-range columns)])
        (define from (min (length lines) (* c per-column)))
        (define to (min (length lines) (* (add1 c) per-column)))
        (take (drop lines from) (- to from)))))

;; ---------------------------------------------------------------------------
;; The plan of the book
;; ---------------------------------------------------------------------------

;; How many gatherings a stretch of front matter wants, and of what extent.
;; A short one is half a sheet, worked and turned: A2 is the commonest
;; preliminary arrangement in Blayney's checklist by a wide margin, and it is
;; half the paper and half the formes of a full gathering.
(define (leaves-for fmt half-leaves n-pages)
  (define pages-per (book-format-pages fmt))
  (let loop ([left n-pages] [out '()])
    (cond
      [(<= left 0) (reverse out)]
      [(<= left (* 2 half-leaves)) (reverse (cons half-leaves out))]
      [else (loop (- left pages-per) (cons (book-format-leaves fmt) out))])))

;; One gathering, before anything is set in it: which series signs it, where it
;; sits in that series, how many leaves it has, and which pages of copy it is
;; to hold. `place' is its position in the finished book; the order in which
;; the plans are worked is a different order, because the preliminaries are
;; printed last.
;; `excised' names the leaves of this gathering that were printed with it and
;; then cut out, to be bound somewhere else. `shares' is the other side of the
;; same fact: a plan that is a view of leaves belonging physically to another
;; gathering, and which therefore has no formes and no presswork of its own.
;; `overrides' signs individual leaves from a different series.
(struct gathering-plan (role series index leaves segments place
                             excised shares overrides conjugate?)
  #:transparent)

(define (plan leaves segments place role series index
              #:excised [excised '()] #:shares [shares #f]
              #:overrides [overrides (hash)] #:conjugate? [conj? #t])
  (gathering-plan role series index leaves segments place
                  excised shares overrides conj?))

;; What the binder ends with, which is not what the pressman printed.
(define (plan-bound-leaves p)
  (- (gathering-plan-leaves p) (length (gathering-plan-excised p))))

;; How the preliminaries are signed.
;;
;; Gaskell gives the forms in order of frequency (p. 52) but gives no numbers,
;; and neither does McKerrow. **The ordering below is his; the weights are
;; not.** They are a guess at the shape of a distribution whose order alone is
;; attested, and nothing in this program should be read as evidence for them.
;;
;;   stars       *  **  ***      "even commoner" than letters
;;   english     A a b, text from B -- "a characteristically English habit
;;               ... to allow for a sheet of preliminaries signed A"
;;   lower       a b c, text from A -- "always quite common"
;;   symbols     *  †  ‡  §      "without logical order"
;;   continuous  no separate series at all: Gaskell's reprints, which
;;               "sometimes began the main signature series at the beginning
;;               of the preliminaries" because the extent was already known
;;   unsigned    nothing set at all; McKerrow's π in the collation
;; ¶ is not in Gaskell's list but is thick on the ground in Blayney's checklist
;; of one shop's output, where preliminary gatherings are signed ¶2, ¶4 and ¶8;
;; it is here as a style of its own rather than as one symbol among four.
(define PRELIM-SCHEMES
  '((stars 0.28) (english 0.23) (lower 0.17) (symbols 0.09)
    (pilcrow 0.09) (continuous 0.08) (unsigned 0.06)))

(define PRELIM-SCHEME-NAMES (map car PRELIM-SCHEMES))

(define (choose-prelim-scheme g n-gatherings leaves [forced #f])
  ;; A house that always signs its preliminaries the same way is the ordinary
  ;; case; the mixture is what you get looking across a trade rather than
  ;; within a shop. So the choice can be fixed, and `auto' means draw it.
  (when (and forced (not (memq forced PRELIM-SCHEME-NAMES)))
    (error 'choose-prelim-scheme "unknown preliminary signature style: ~a" forced))
  (define r (rnd g))
  (define pick
    (or forced
        (let loop ([ss PRELIM-SCHEMES] [acc 0.0])
          (cond
            [(null? ss) 'stars]
            [(< r (+ acc (cadr (car ss)))) (car (car ss))]
            [else (loop (cdr ss) (+ acc (cadr (car ss))))]))))
  ;; An unsigned series is only credible for a leaf or two. Nobody left eight
  ;; leaves unsigned and expected a binder to fold them right.
  ;; Asked for outright, an unsigned series is given even where it is unwise:
  ;; the user is entitled to make a book that is hard to bind, and the binding
  ;; report will show what it costs.
  (if (and (eq? pick 'unsigned) (not forced)
           (or (> n-gatherings 1) (> (apply + leaves) 2)))
      'stars
      pick))

;; Turn the extents into plans, and settle the signatures.
;;
;; The overflow case is McKerrow's, and it is the one worth getting right. Of
;; the two editions of the Masque of the Gentlemen of Gray's Inn he writes that
;; the first collates "?, A4, a4, B-E4, F2", and that "even from the make-up
;; alone we might guess that Ed. 1 is the earlier, for the work itself begins
;; on B1 and this is preceded by A and a, **the latter signature strongly
;; suggesting that the preliminary matter was more than the printer had
;; expected and allowed for**" (p. 182).
;;
;; So the second preliminary series is not a style. It is a misjudgement, made
;; visible: the house allowed one sheet signed A, the front matter would not go
;; in it, and the overflow had to be signed something else. This program knows
;; whether the overflow happened, which means the inference McKerrow draws from
;; the collation can be scored against the truth.
(define (make-plans fmt g front-leaves front-segs body-gatherings text-segs
                    alphabet [forced-scheme #f])
  (define main (make-main-series alphabet))
  (define pages-per (book-format-pages fmt))
  (define n-front (length front-leaves))
  (define scheme
    (if (zero? n-front)
        'none
        (choose-prelim-scheme g n-front front-leaves forced-scheme)))

  ;; (series . index) for each preliminary gathering, and where the text starts
  ;; in the main series.
  (define-values (front-series text-start)
    (case scheme
      [(none)       (values '() 0)]
      [(stars)      (values (for/list ([i n-front]) (cons STAR-SERIES i)) 0)]
      [(symbols)    (values (for/list ([i n-front]) (cons SYMBOL-SERIES i)) 0)]
      [(pilcrow)    (values (for/list ([i n-front]) (cons PILCROW-SERIES i)) 0)]
      [(lower)      (values (for/list ([i n-front]) (cons LOWER-SERIES i)) 0)]
      [(unsigned)   (values (for/list ([i n-front]) (cons PI-SERIES i)) 0)]
      [(continuous) (values (for/list ([i n-front]) (cons main i)) n-front)]
      [(english)
       ;; one sheet signed A was allowed for; anything past it is the overflow
       (values (cons (cons main 0)
                     (for/list ([i (in-range (sub1 n-front))])
                       (cons LOWER-SERIES i)))
               1)]))

  ;; Hand each plan its slice of the cast-off copy.
  (define front-plans
    (let loop ([ls front-leaves] [ss front-series] [segs front-segs]
               [place 0] [out '()])
      (cond
        [(null? ls) (reverse out)]
        [else
         (define n (* 2 (car ls)))
         (loop (cdr ls) (cdr ss) (drop segs (min n (length segs))) (add1 place)
               (cons (plan (car ls) (take segs (min n (length segs))) place
                           'prelim (car (car ss)) (cdr (car ss)))
                     out))])))
  (define text-plans
    (let loop ([k 0] [segs text-segs] [out '()])
      (cond
        [(>= k body-gatherings) (reverse out)]
        [else
         (loop (add1 k) (drop segs (min pages-per (length segs)))
               (cons (plan (book-format-leaves fmt)
                           (take segs (min pages-per (length segs)))
                           (+ n-front k) 'text main (+ text-start k))
                     out))])))
  (values front-plans text-plans scheme))

;; ---------------------------------------------------------------------------
;; The last sheet
;; ---------------------------------------------------------------------------
;; The economy that governs the end of every book, and the reason a
;; bibliographer is told to work the collation backwards.
;;
;;   "as it costs practically as much to print part of a sheet as a complete
;;   one, it was always to the printer's interest to make up a complete sheet
;;   whenever he could." (McKerrow, p. 159)
;;
;; So a text that stops two leaves short of the end of its last sheet, in a
;; house that has two leaves of preliminaries still to print, does not print a
;; separate half-sheet and leave two leaves white. It prints the preliminaries
;; in the white leaves and cuts them out:
;;
;;   "he will as a matter of course impose these preliminaries in the middle of
;;   his last sheet, which may therefore run, as actually printed (supposing it
;;   to be in fours), Z1, [*], *2, Z2, the two centre leaves being cut out to be
;;   used as preliminaries. Such a book will be described as *2, A-Y4, Z2,
;;   quite correctly." (p. 158-9)
;;
;; And where the preliminaries are a single title-leaf: "the printer would be
;; quite likely to print it Z1, Z2, Z3, [-], cutting off his last leaf to form
;; the title."
;;
;; McKerrow's own reason for pressing the point is that the alternative makes
;; bibliographers record leaves that never existed -- "*1 and Z4 wanting,
;; probably blanks, thus inventing two blank leaves which in fact never
;; existed." This program was doing precisely that: it always gave the
;; preliminaries a sheet of their own and left the tail of the text white.
;;
;; Two things keep it honest. It is a tendency and not a law -- "we must not
;; assume that a printer would in every case economize his labour and paper in
;; this fashion: it might sometimes have been more convenient to have the two
;; extra leaves as covers or end-papers" -- and Bowers puts the same caution
;; the other way about: "Even when normal printing practice might lead one to
;; expect economical machining without blanks, it is dangerous, lacking proof,
;; to assume their absence."
(define CUT-OUT-SHARE 0.75)

;; Fold the preliminaries into the white leaves of the last text sheet, where
;; they will go and where the house chooses to do it. Returns the plans
;; rearranged, or #f if the economy does not apply.
(define (cut-from-last-sheet fmt g front-plans text-plans)
  (define last-text (and (pair? text-plans) (last text-plans)))
  (define n-front-leaves (for/sum ([p (in-list front-plans)]) (gathering-plan-leaves p)))
  ;; The white leaves at the tail of the last text gathering: pages with no
  ;; copy in them.
  (define white
    (and last-text
         (let ([segs (gathering-plan-segments last-text)])
           (let count ([xs (reverse segs)] [k 0])
             (if (and (pair? xs) (null? (cast-off-segment-units (car xs))))
                 (count (cdr xs) (add1 k))
                 k)))))
  (define white-leaves (and white (quotient white 2)))
  (cond
    [(or (not last-text) (null? front-plans)) #f]
    [(< white-leaves n-front-leaves) #f]
    ;; the house may still prefer the two spare leaves as covers or endpapers
    [(> (rnd g) CUT-OUT-SHARE) #f]
    [else
     (define total (book-format-leaves fmt))
     ;; The centre of the sheet, which is where McKerrow says they go: in a
     ;; quarto in fours the middle two leaves are a conjugate pair, so the
     ;; preliminaries come off as a fold and their fellows Z1.Z2 stay one.
     ;; Where the count will not centre -- a single leaf, or an odd number --
     ;; they are cut from the tail instead and come off disjunct, which is the
     ;; case Bowers proved from the watermarks of Sandys's Ovid.
     (define centred?
       (and (even? n-front-leaves)
            (even? (- total n-front-leaves))
            (<= n-front-leaves (- total 2))))
     (define first-cut
       (if centred?
           (add1 (quotient (- total n-front-leaves) 2))
           (add1 (- total n-front-leaves))))
     (define cut-leaves
       (for/list ([i (in-range n-front-leaves)]) (+ first-cut i)))
     ;; Which series signs each cut leaf, and its number in that series.
     (define overrides
       (let loop ([ps front-plans] [cuts cut-leaves] [h (hash)])
         (cond
           [(null? ps) h]
           [else
            (define p (car ps))
            (loop (cdr ps) (drop cuts (gathering-plan-leaves p))
                  (for/fold ([h h]) ([leaf (in-range (gathering-plan-leaves p))])
                    (hash-set h (list-ref cuts leaf)
                              (list (gathering-plan-series p)
                                    (gathering-plan-index p)
                                    (add1 leaf)))))])))
     ;; The preliminary copy goes into the white pages, in place.
     (define front-segs (append* (map gathering-plan-segments front-plans)))
     (define pages-of-cut
       (append* (for/list ([leaf (in-list cut-leaves)])
                  (list (sub1 (* 2 leaf)) (* 2 leaf)))))
     (define filled
       (let ([v (list->vector (gathering-plan-segments last-text))])
         (for ([page (in-list pages-of-cut)] [s (in-list front-segs)])
           (when (<= page (vector-length v))
             (vector-set! v (sub1 page) s)))
         (vector->list v)))
     (define new-last
       (struct-copy gathering-plan last-text
                    [segments filled]
                    [excised cut-leaves]
                    [overrides overrides]))
     ;; The preliminary plans become views: bound first, printed with sheet Z,
     ;; and owning no formes of their own.
     (define views
       (for/list ([p (in-list front-plans)])
         (struct-copy gathering-plan p
                      [segments '()]
                      [shares (gathering-plan-place last-text)]
                      [conjugate? centred?])))
     (list views
           (append (drop-right text-plans 1) (list new-last)))]))

;; The collation formula, built from the plans in the order they are bound.
;; A gathering is described by the leaves it *keeps*, not the leaves it was
;; printed with, which is what makes McKerrow's example come out as Z².
(define (plans->runs ps)
  (let loop ([ps ps] [out '()])
    (cond
      [(null? ps) (reverse out)]
      [else
       (define s (gathering-plan-series (car ps)))
       (define same
         (let count ([xs ps] [k 0])
           (if (and (pair? xs)
                    (eq? (gathering-plan-series (car xs)) s)
                    (= (gathering-plan-index (car xs))
                       (+ (gathering-plan-index (car ps)) k)))
               (count (cdr xs) (add1 k))
               k)))
       (loop (list-tail ps same)
             (cons (sig-run s (gathering-plan-index (car ps))
                            (for/list ([p (in-list (take ps same))])
                              (plan-bound-leaves p)))
                   out))])))

;; ---------------------------------------------------------------------------
;; Setting the book
;; ---------------------------------------------------------------------------

(define (set-book h copy [copy-kind 'auto])
  (define authors-copy (parse-copy copy copy-kind))
  (define cr (make-corrector #:rng (make-rng (+ (house-seed h) 3))
                             #:active? (house-prepare-copy? h)))
  ;; The copy is prepared to house style before it reaches the frames, so what
  ;; the compositor sets from is already not what the author wrote.
  (define-values (units prepared) (prepare-copy cr authors-copy))

  (define fmt (house-fmt h))
  (define spec (house-spec h))
  (define capacity (house-capacity h))
  (define g (make-rng (house-seed h)))
  (define tc (make-type-case #:scale (house-case-scale h)
                             #:condition (house-condition h)
                             #:rng (make-rng (+ (house-seed h) 1))))
  (define men
    (for/hash ([name (in-list (house-compositor-names h))] [i (in-naturals)])
      (values name
              (make-comp (hash-ref (house-profiles h) name
                                   (lambda ()
                                     (profile name (hash) 1.0 0.01 0.006 0.5
                                              #f 0.85 #f "an unknown workman")))
                         tc (house-conventions h)
                         (make-rng (+ (house-seed h) (* 7 i)))))))
  (define order (house-compositor-names h))

  ;; How many leaves of a gathering each man signs.
  ;;
  ;; Signing is the compositor's own act, not the imposer's: McKerrow finds
  ;; that the men "normally finished a page of work at a time, adding catchword
  ;; and signature (if necessary) before proceeding to the next one". And the
  ;; count was not fixed -- "there cannot be said to have been in early times
  ;; any definite practice ... we may have anything from the first two to every
  ;; leaf". Hinman saw the same inconsistency at Jaggard's, where in a quarto
  ;; one man might sign the first two leaves and another the first three.
  ;;
  ;; So the practice varies by the man. Which man signed how many, neither
  ;; source says, and assigning particular counts to Hinman's A and B would be
  ;; manufacturing evidence of exactly the kind this program is supposed to
  ;; test. The count is therefore drawn per workman from the run's seed: the
  ;; phenomenon is attested, the attribution is not.
  (define signs-for
    (for/hash ([name (in-list order)] [i (in-naturals)])
      (define base (signed-leaves fmt))
      (define gg (make-rng (+ (house-seed h) 3001 (* 13 i))))
      (values name
              (max 1 (min (book-format-leaves fmt)
                          (+ base (if (< (rnd gg) 0.4) 1 0)))))))

  ;; -------------------------------------------------------------------------
  ;; What goes in front, and what is printed last
  ;; -------------------------------------------------------------------------
  ;; "In composing a new book from MS the normal course was to begin at the
  ;; beginning of the text and proceed straight on to the end, setting up the
  ;; title-page and preliminaries last" (McKerrow, p. 128), and the separate
  ;; signature series exists because of it: the man who has already signed his
  ;; text A to L cannot give the front matter letters without collision, so he
  ;; gives it a series of its own.
  ;;
  ;; Everything below follows from that order. The body is cast off and set
  ;; first; what room is left at the back of the last sheet is then known; and
  ;; only then is it settled how the front matter is to be signed, how many
  ;; leaves it wants, and whether any of it goes to the back instead.
  (define measure (page-spec-measure spec))
  (define acc (house-cast-off-accuracy h))
  (define meth (house-cast-off-method h))
  (define pages-per (book-format-pages fmt))
  (define half-leaves (max 1 (quotient (book-format-leaves fmt) 2)))

  (define div (divide-copy units #:guess? (house-find-prelims? h)))
  (define tp
    (and (house-titlepage? h)
         (make-titlepage #:title (or (house-book-title h) (house-title h))
                         #:author (house-author h)
                         #:year (conventions-year (house-conventions h))
                         #:printer (house-printer h)
                         #:publisher (house-publisher h)
                         #:rng (make-rng (+ (house-seed h) 7717)))))

  ;; The Table and the errata are the matter that can go either way. McKerrow:
  ;; Tottel's Treatise of Moral Philosophy has its Table among the
  ;; preliminaries; East reprinting it "found he had room for the Table in the
  ;; last gathering of the book and placed it there" (p. 78). Which side it
  ;; falls on is decided below, by how much room the body happens to leave.
  (define-values (movable settled)
    (partition (lambda (b) (memq (prelim-block-kind b) MIGRATORY-KINDS))
               (division-prelims div)))

  (define body-segs0 (cast-off (division-body div) measure capacity g acc #:method meth))
  (define n-body (length body-segs0))
  (define body-gatherings
    (max 1 (quotient (+ n-body (sub1 pages-per)) pages-per)))
  (define spare (- (* body-gatherings pages-per) n-body))

  (define moving-copy (append* (map prelim-block-units movable)))
  (define moving-segs
    (if (null? moving-copy) '() (cast-off moving-copy measure capacity g acc #:method meth)))

  (define (front-with blocks)
    (define copy (append (if tp (titlepage-units tp) '())
                         (append* (map prelim-block-units blocks))))
    (if (null? copy) '() (cast-off copy measure capacity g acc #:method meth)))

  ;; Whether the Table goes to the back is decided by two questions, in this
  ;; order, and neither of them is a coin.
  ;;
  ;; Is there room? "He then found he had room for the Table in the last
  ;; gathering of the book and placed it there" (McKerrow, p. 78). Nobody
  ;; printed a whole extra sheet at the back to avoid printing one at the
  ;; front, so it must fit in the white leaves the text has already left.
  ;;
  ;; And does moving it save anything? Paper was the largest cost in the shop,
  ;; and the saving is in leaves: East's preliminaries went from a gathering to
  ;; half a one by the move. Where the front matter would take the same number
  ;; of leaves either way there is nothing to be got by moving it, and it stays
  ;; where it is -- which is Tottel's edition, with the same Table in front.
  ;;
  ;; So the rule is arithmetic on the two make-ups rather than a rate. That
  ;; matters: a rate here would be invented, and this one is not.
  (define front-leaves-with (leaves-for fmt half-leaves (length (front-with (division-prelims div)))))
  (define front-leaves-without (leaves-for fmt half-leaves (length (front-with settled))))
  (define room? (<= (length moving-segs) spare))
  (define saves? (< (apply + front-leaves-without) (apply + front-leaves-with)))
  (define moved? (and (pair? moving-segs) room? saves?))
  ;; Recorded either way. A report that says nothing when the matter stayed in
  ;; front cannot tell "there was none to move" from "there was, and it did
  ;; not", and the second is the more interesting fact of the two.
  (define migration
    (and (pair? moving-segs)
         (list (map prelim-block-kind movable) moved?
               (cond [moved? 'moved]
                     [(not room?) 'no-room]
                     [else 'no-saving]))))

  (define front-segs (front-with (if moved? settled (division-prelims div))))

  ;; The body's own pages, with the moved matter after them and white paper
  ;; after that.
  (define text-segs
    (let* ([with-moved (append body-segs0 (if moved? moving-segs '()))]
           [n (length with-moved)])
      (append with-moved
              (for/list ([i (in-range (- (* body-gatherings pages-per) n))])
                (cast-off-segment (+ n i) '() 0 "blank")))))

  (define front-leaves (leaves-for fmt half-leaves (length front-segs)))

  (define front-padded
    (let ([want (for/sum ([l (in-list front-leaves)]) (* 2 l))]
          [n (length front-segs)])
      (append front-segs
              (for/list ([i (in-range (- want n))])
                (cast-off-segment (+ n i) '() 0 "blank")))))

  (define-values (front-plans0 text-plans0 prelim-scheme)
    (make-plans fmt g front-leaves front-padded body-gatherings text-segs
                (house-sig-alphabet h) (house-prelim-style h)))
  ;; McKerrow's economy: where the text stops short of the end of its last
  ;; sheet and the preliminaries will fit in the white leaves, they are printed
  ;; there and cut out, rather than costing a sheet of their own.
  (define cut (cut-from-last-sheet fmt g front-plans0 text-plans0))
  (define front-plans (if cut (first cut) front-plans0))
  (define text-plans (if cut (second cut) text-plans0))
  (define cut-out? (and cut #t))

  ;; Reading order for the finished book; printing order for the shop. A plan
  ;; that shares another gathering's sheet is not worked on its own: its pages
  ;; are set and printed with the sheet it was cut from.
  (define plans (append front-plans text-plans))
  (define printing-plans
    (filter (lambda (p) (not (gathering-plan-shares p)))
            (append text-plans front-plans)))

  (define skeletons
    (make-skeletons (house-n-skeletons h)
                    (max 2 (quotient (book-format-pages fmt) 2))
                    (house-title h) g
                    (book-format-measure-ems fmt) (book-format-lines fmt)))

  (define all-formes '())
  (define pages (make-hash))
  (define stint-log '())
  (define forme-counter 0)
  (define forme-pages (make-hash))
  (define standing '())

  ;; The ledger of standing type. A page cannot be distributed until the whole
  ;; forme it belongs to is at press, and in a folio in sixes the outer forme
  ;; of the first sheet holds pages 1 and 12 -- eleven pages apart in the copy.
  ;; So a house setting seriatim must keep the best part of a gathering
  ;; standing before it can print anything at all, while a house setting by
  ;; formes from the middle outward can print and distribute a sheet at a time.
  ;; That difference is arithmetic about the practice, not evidence of it:
  ;; McKenzie found setting by formes "was followed occasionally but was
  ;; certainly not normal" (i. 115). This counts what it would have saved.
  ;; Who is at the frame, forme by forme.
  ;;
  ;; Not a rotation. A man takes over where the last left off and sets as many
  ;; sheets as the master finds convenient, so the plan is a run of long
  ;; contiguous blocks with the occasional single sheet where somebody was
  ;; briefly free. The boundaries fall where the shop's other commitments put
  ;; them, which is why McKenzie says the compositorial pattern within a book
  ;; "will rarely have any internal significance" (i. 107) -- it records the
  ;; house's other work, not anything about this book.
  (define stint-plan (make-hash))
  (define plan-filled (box 0))
  (define plan-last (box -1))
  (define (man-for-forme i)
    (cond
      [(= (length order) 1) (car order)]
      [else
       (let extend ()
         (when (>= i (unbox plan-filled))
           ;; a stint is a whole number of sheets: mostly several, now and then
           ;; a single one, as Delie set only 4G of the quarto Virgil
           (define sheets
             (if (< (rnd g) 0.18)
                 1
                 (max 1 (exact-round (* 2 (house-stint-sheets h)
                                        (rnd-beta g 2.0 2.0))))))
           (define len (* 2 sheets))     ; two formes to a sheet
           ;; the man who takes over is whoever is free, not the next in turn
           (define pick
             (let loop ()
               (define k (rnd-int g (length order)))
               (if (= k (unbox plan-last)) (loop) k)))
           (for ([j (in-range (unbox plan-filled) (+ (unbox plan-filled) len))])
             (hash-set! stint-plan j (list-ref order pick)))
           (set-box! plan-filled (+ (unbox plan-filled) len))
           (set-box! plan-last pick)
           (extend)))
       (hash-ref stint-plan i)]))

  (define standing-sorts 0)
  (define peak-sorts 0)
  (define peak-pages 0)
  (define pages-standing 0)
  (define ledger '())
  (define (sorts-in pg)
    (for/sum ([ch (in-string (page-text pg))])
      (if (char-whitespace? ch) 0 1)))

  ;; How much type the house can leave standing before the cases are too thin
  ;; to set from.
  ;;
  ;; A forme count alone is the wrong governor, because the binding constraint
  ;; was never the number of formes but the weight of metal. Blayney on Okes:
  ;; "When the tied pages of two formes were kept intact, what was left would
  ;; not have overflowed a normal pair of cases" (i. 94) -- and, on the limit
  ;; of that, "Okes did not own enough type to allow sixteen pages of _Lear_
  ;; (which uses less type per page than Okes's 'normal' pica quartos) to stand
  ;; without having their margins cannibalized for capitals" (i. 111).
  ;;
  ;; So the shop distributes when it runs short, not only when a forme count is
  ;; exceeded, and a house whose fount is small distributes oftener. Without
  ;; this the small fount that Blayney measured produced a shop with nothing
  ;; left in its boxes, borrowing wrong-fount sorts by the hundred, which is
  ;; not what his books show. Two thirds is a judgement about how thin a pair
  ;; of cases may get and still be worked; that the ceiling exists is not.
  (define type-ceiling
    (* 2/3 (for/sum ([(ch n) (in-hash (tcase-initial tc))]) n)))

  ;; The gatherings are worked in printing order, not in reading order: the
  ;; text from A (or B) to the end, and the preliminaries after it. Everything
  ;; that depends on the order of work therefore falls out right without being
  ;; told -- the skeletons reach the title-page last, the cases are at their
  ;; thinnest in the middle of the text rather than at the front, and the type
  ;; of the last text sheet is still standing when the first prelim page is set.
  (for ([plan (in-list printing-plans)])
    (define gathering (gathering-plan-place plan))
    (define leaves (gathering-plan-leaves plan))
    (define refs
      (for/hash ([r (in-list (page-refs fmt gathering
                                        (gathering-plan-series plan)
                                        (gathering-plan-index plan)
                                        #:leaves leaves
                                        #:overrides (gathering-plan-overrides plan)))])
        (values (page-ref-number r) r)))
    (define formes
      (formes-for-gathering fmt gathering (gathering-plan-series plan)
                            (gathering-plan-index plan) #:leaves leaves))
    (define page->forme
      (for*/hash ([fm (in-list formes)] [p (in-list (forme-page-numbers fm))])
        (values p fm)))

    ;; NUMBERED IN THE ORDER THEY ARE SET, which is `formes' reversed.
    ;; `setting-order' hands out the pages of the LAST forme in this list first
    ;; (imposition.rkt, "from the inside out"), so walking `formes' forwards
    ;; here numbered every gathering inside out -- forme-order 0 being the last
    ;; forme composed. Three things read the counter as a setting order and two
    ;; of them were wrong for it: the compositor's turn, which decides who meets
    ;; the thin case and so which man's spelling the type supply governs, and
    ;; the skeleton's wear, which decides the order the running-title damage
    ;; appears in. The preliminaries assertion below was unharmed, comparing
    ;; whole gatherings rather than formes within one.
    (for ([fm (in-list (reverse formes))])
      (define sk (list-ref skeletons (modulo forme-counter (length skeletons))))
      (define sk*
        (if (and (> (length skeletons) 1) (< (rnd g) 0.12))
            (list-ref skeletons (modulo (add1 forme-counter) (length skeletons)))
            sk))
      (set-forme-skeleton! fm sk*)
      (set-forme-order! fm forme-counter)
      (skeleton-add-use! sk* (forme-name fm))
      (set! forme-counter (add1 forme-counter)))
    (set! all-formes (append all-formes formes))

    (let page-loop ([ps (setting-order fmt gathering (house-by-formes? h)
                                       #:leaves leaves)]
                    [pos 0] [carry '()])
      (unless (null? ps)
        (define page-no (car ps))
        (define seg-index (sub1 page-no))
        (cond
          ;; A page of the format's scheme that this gathering has no copy
          ;; for. SKIP it and go on -- this stopped the loop dead, and the
          ;; rest of the gathering was never set.
          ;;
          ;; It could only bite on a gathering shorter than the format's full
          ;; scheme, which in practice means every preliminary gathering:
          ;; `formes-for-gathering' hands back the whole twelve-page folio
          ;; scheme whatever #:leaves it is given, so a three-leaf preliminary
          ;; gathering is set in the order 5 8 6 7 3 10 4 9 1 12 2 11, and the
          ;; second entry -- page 8, which has no segment -- ended it. Page 5
          ;; was composed and the other five were not, so the First Folio's
          ;; preliminaries came out as a single leaf, and that leaf was blank
          ;; because segment 5 is one of the empty ones.
          [(>= seg-index (length (gathering-plan-segments plan)))
           (page-loop (cdr ps) (add1 pos) carry)]
          [else
           (define seg (list-ref (gathering-plan-segments plan) seg-index))
           (define r (hash-ref refs page-no))
           (define fm (hash-ref page->forme page-no))
           ;; The stint plan is indexed by forme when the house sets by formes,
           ;; and by sheet-worth-of-pages when it sets seriatim; either way a
           ;; man holds on for several sheets together.
           (define man
             (hash-ref men
                       (man-for-forme
                        (if (house-by-formes? h)
                            (forme-order fm)
                            (+ (* gathering (book-format-pages fmt)) pos)))))
           (define units-for-page (append carry (cast-off-segment-units seg)))
           (define-values (pg leftover)
             (set-page h man units-for-page r fm spec capacity
                       (min leaves
                            (hash-ref signs-for (profile-name (comp-profile man))
                                      (signed-leaves fmt)))))
           (hash-set! pages (cons gathering page-no) pg)
           (set! stint-log (cons (cons (profile-name (comp-profile man))
                                       (page-ref-signature r))
                                 stint-log))

           ;; When a forme is finished it goes to press; when the house has
           ;; more formes standing than it can afford, the oldest is printed
           ;; off and its type distributed back into the cases.
           (hash-update! forme-pages (forme-name fm)
                         (lambda (xs) (append xs (list pg))) '())

           ;; the page is now standing in type and stays so until its forme
           ;; is printed off
           (set! standing-sorts (+ standing-sorts (sorts-in pg)))
           (set! pages-standing (add1 pages-standing))
           (when (> standing-sorts peak-sorts)
             (set! peak-sorts standing-sorts)
             (set! peak-pages pages-standing))
           (set! ledger (cons (list (page-ref-signature r) page-no
                                    pages-standing standing-sorts)
                              ledger))

           (when (= (length (hash-ref forme-pages (forme-name fm)))
                    (length (forme-page-numbers fm)))
             (set! standing (append standing (list (forme-name fm)))))

           ;; Checked after every page, not only when a forme is made up. The
           ;; cases run thinnest in the middle of setting a forme -- that is
           ;; where the peak always falls -- so a check that only fires on
           ;; completion never sees the moment the shop actually feels.
           (let dist ()
             (when (and (pair? standing)
                        (or (> (length standing) (house-formes-standing h))
                            (> standing-sorts type-ceiling)))
                 (define printed (car standing))
                 (set! standing (cdr standing))
                 (for ([p (in-list (hash-ref forme-pages printed '()))])
                   (set! standing-sorts (- standing-sorts (sorts-in p)))
                   (set! pages-standing (sub1 pages-standing))
                   (distribute! tc (page-text p))
                   (distribute-space! tc (page-sig p))
                   ;; the identifiable types go back to their own boxes and
                   ;; may be picked again for a later forme
                   (distribute-pieces!
                    tc (for*/list ([l (in-list (page-all-lines p))]
                                   [w (in-list (set-line-words l))]
                                   [pr (in-list (word-pieces w))])
                         (cdr pr))))
                 ;; and a few sound sorts are battered at press each time.
                 ;; Named with the forme that was on the press, because a
                 ;; piece whose injury is first seen in a known forme dates
                 ;; every appearance it makes afterwards.
                 (batter! tc 2 #:at printed)
                 (dist)))

           (page-loop (cdr ps) (add1 pos)
                      (if (house-by-formes? h) '() leftover))]))))

  ;; Read in the order the binder will fold them, which puts back in front the
  ;; matter that was set last -- and, where the preliminaries were cut out of
  ;; the last sheet, moves those leaves from the end of the book to its front.
  (define (pages-of pl)
    (define place (or (gathering-plan-shares pl) (gathering-plan-place pl)))
    (define owner
      (for/or ([q (in-list plans)])
        (and (= (gathering-plan-place q) place) (not (gathering-plan-shares q)) q)))
    (define wanted
      (cond
        ;; a view: only the leaves that were cut out of the sheet it shares
        [(gathering-plan-shares pl)
         (append* (for/list ([leaf (in-list (gathering-plan-excised
                                             (or owner pl)))])
                    (list (sub1 (* 2 leaf)) (* 2 leaf))))]
        ;; a real gathering: everything except what was cut out of it
        [else
         (for/list ([p (in-range 1 (add1 (* 2 (gathering-plan-leaves pl))))]
                    #:unless (memv (quotient (add1 p) 2) (gathering-plan-excised pl)))
           p)]))
    (for/list ([p (in-list wanted)]
               #:when (hash-has-key? pages (cons place p)))
      (hash-ref pages (cons place p))))
  (define ordered (append* (map pages-of plans)))

  (define with-catchwords (add-catchwords ordered (house-conventions h)))
  (define with-titles
    (add-running-titles with-catchwords all-formes fmt g (house-formes-standing h)))

  ;; The paging is set last because it belongs to the headline rather than to
  ;; the text: a piece of type beside the running title, carried from forme to
  ;; forme with the skeleton, and going wrong in the ways it does for that
  ;; reason. See pagination.rkt.
  (define paging
    (paginate (for/list ([p (in-list with-titles)]) (page-pref p))
              #:rate (house-paging-error h)
              #:rng (make-rng (+ (house-seed h) 5501))))

  (book with-titles all-formes skeletons fmt (house-paper h)
        (append* (for/list ([name (in-list order)])
                   (comp-event-list (hash-ref men name))))
        (compress-stints (reverse stint-log))
        tc (house-title h) units authors-copy prepared
        (standing-type peak-sorts peak-pages (reverse ledger)
                       (house-by-formes? h))
        paging plans div tp prelim-scheme migration cut-out?))

;; ---------------------------------------------------------------------------

;; MIS-RESUMING: the compositor loses his place between pages.
;;
;; McKerrow's mechanism, and the one this program has never had (Roadmap §5,
;; §12). He is explaining why a catchword can be right while the page it faces
;; is wrong: "the compositor having **mistaken the point at which he left off
;; and consequently omitted or repeated a word or two**" -- the catchword was
;; set from the manuscript and is therefore correct, and the fault is in the
;; page. That is his proof that catchwords come from the copy.
;;
;; So the PLACE is his and only the rate is invented. It happens where he
;; returns to the copy after setting a page away from it, which is the head of
;; the next page -- not spread evenly through the text, which is what a bare
;; rate per word would have given.
;;
;; Both directions, and together, because they are one slip: he resumes a word
;; early and repeats, or a word late and drops. McKerrow's proof (1) is the
;; repetition case, "the last line or the last few words of one page being
;; repeated at the beginning of the next", and he names five books.
;;
;; The dropped or doubled words are carried on `word-copy' of the word that
;; stands at the join, so that the corrector's existing scan against the copy
;; finds them and mends them into a press variant -- which is the whole point of
;; building this: it is a fault that CHANGES A READING, where the two mechanisms
;; added before it could not, by construction, move the variant count at all.
;;
;; **No source gives a rate.** "Comparative frequency" is McKerrow's phrase, and
;; it is not a number; `--mis-resume' is a knob and the report says so.
(define (mis-resume-units units g rate)
  (define (first-text-index)
    (for/first ([u (in-list units)] [i (in-naturals)]
                #:when (and (memq (copy-unit-kind u) '(prose verse))
                            (> (length (string-split (copy-unit-text u))) 3)))
      i))
  (define i (first-text-index))
  (cond
    [(or (not i) (>= (rnd g) rate)) (values units #f)]
    [else
     (define u (list-ref units i))
     (define ws (string-split (copy-unit-text u)))
     ;; A word or two, as he says.
     (define n (if (< (rnd g) 0.7) 1 2))
     (define drop? (< (rnd g) 0.5))
     (define-values (text* note)
       (if drop?
           (values (string-join (list-tail ws n) " ")
                   (cons 'dropped (string-join (take ws n) " ")))
           (values (string-join (append (take ws n) ws) " ")
                   (cons 'repeated (string-join (take ws n) " ")))))
     (values (list-set units i (struct-copy copy-unit u [text text*]))
             note)]))

;; Write the mis-resumption onto the first word of the page, and log it.
;;
;; For a DROPPED word the copy read "my brother" where the print has "brother",
;; so the word's `copy' carries both and the corrector restores the pair. For a
;; REPEATED one the print has a word the copy has not, so its `copy' is empty and
;; the corrector strikes it out. Either way the existing scan in `press.rkt'
;; against `word-copy' finds it, which is why no new machinery is needed at press.
(define (mark-slip picked slip man sig)
  (define kind (car slip))
  (define words (cdr slip))
  (define done? #f)
  (define out
    (for/list ([l (in-list picked)] [li (in-naturals 1)])
      (cond
        [(or done? (null? (set-line-words l))) l]
        [else
         (set! done? #t)
         (define ws (set-line-words l))
         (define w (car ws))
         (add-event! man (make-ev 'resumption
                                  (format "~a at the head of the page: ~s"
                                          (if (eq? kind 'dropped)
                                              "a word or two dropped"
                                              "a word or two repeated")
                                          words)
                                  sig (comp-profile man)))
         ;; The cause is what names it in the apparatus. Without it the tooltip
         ;; falls through to the misreading branch and calls a dropped word an
         ;; eye-slip, which is a different fault at a different stage.
         (struct-copy set-line l
                      [words (cons (struct-copy word w
                                                [copy (if (eq? kind 'dropped)
                                                          (string-append words " "
                                                                         (or (word-copy w) ""))
                                                          "")]
                                                [causes
                                                 (append (word-causes w)
                                                         (list (format "resumption: a word or two ~a where he took up again"
                                                                       kind)))])
                                   (cdr ws))])])))
  out)

(define (set-page h man units0 r fm spec capacity signs)
  (define sig (page-ref-signature r))
  (define-values (units slip)
    (mis-resume-units units0 (comp-rng man) (house-mis-resume h)))
  (define has-copy?
    (for/or ([u (in-list units)]) (not (eq? (copy-unit-kind u) 'blank))))

  ;; A trial setting, to find out whether the casting off was any good. It
  ;; costs no type, because the sorts are not picked until the page is settled.
  (define mark (length (unbox (comp-events man))))
  (define trial (compose man units spec 0.0))
  (set-box! (comp-events man)
            (list-tail (unbox (comp-events man))
                       (- (length (unbox (comp-events man))) mark)))

  (define overflow (- (length trial) capacity))
  (define pressure0
    (if (zero? capacity) 0.0 (max -1.0 (min 1.5 (* 3.0 (/ overflow (exact->inexact capacity)))))))
  ;; HOW BADLY THE PAGE WAS CAST OFF is one thing; WHETHER HE CROWDED IT is
  ;; another, and they must not be the same number. `pressure' is the record --
  ;; the report counts a page crowded or spun out by it, and a regime that
  ;; forced it to nought would report a book cast off perfectly when it had
  ;; merely been set at ease.
  (define pressure (if (or (<= (abs overflow) 2) (not has-copy?)) 0.0 pressure0))

  ;; SMITH'S CONDITION, and the sharpest difference between the regimes: the
  ;; crowding devices are used "when Copy is cast off close, and the Pages
  ;; marked off ... but THIS PRECAUTION NEED NOT BE TAKEN where Copy is cast off
  ;; the other way." So under `breaks' he neither drives out nor gets in: the
  ;; page is composed at ease and the misjudgement shows as white at the foot or
  ;; as copy lost, never as crowding.
  (define worked-at
    (if (eq? (house-cast-off-method h) 'breaks) 0.0 pressure))

  (define note
    (cond
      [(> overflow 2)
       (format "copy cast off short by about ~a lines; the page is crowded" overflow)]
      [(< overflow -2)
       (format "copy cast off long by about ~a lines; the page is spun out"
               (- overflow))]
      [else ""]))

  (define lines0 (compose man units spec worked-at))
  (unless (zero? pressure)
    (add-event! man (make-ev 'justification
                             (format "~a (pressure ~a)"
                                     (if (string=? note "") "page reset to fit" note)
                                     (real->decimal-string pressure 2))
                             sig (comp-profile man))))

  (define-values (lines leftover omitted)
    (fit-page man lines0 capacity spec (house-by-formes? h) sig))

  ;; pick the sorts for what actually stands in the forme
  (define picked0
    (for/list ([l (in-list lines)] [i (in-naturals 1)])
      (pick-line! man l sig i)))

  ;; Put the slip on the record. The word standing at the join carries what the
  ;; copy actually read, which is what the corrector compares against -- a
  ;; dropped word shows as copy longer than print, a repeated one as copy
  ;; shorter. Nothing about the metal changes; the line is already set and this
  ;; only says what it ought to have been.
  (define picked (if slip (mark-slip picked0 slip man sig) picked0))

  (values (page r
                (split-columns picked (book-format-columns (house-fmt h))
                               (book-format-lines (house-fmt h)))
                (profile-name (comp-profile man))
                #f ""
                (if (and (page-ref-recto? r)
                         (<= (page-ref-leaf r) signs))
                    (page-ref-signed r) "")
                pressure note (forme-name fm) omitted
                ;; The rules are put to the page when the forme is made ready,
                ;; which is after composition; see `with-titles'.
                '() #f)
          (if (null? leftover) '() (leftover-units man units spec capacity))))

;; Which units of copy did not fit, for carrying to the next page when the
;; house is setting seriatim. Composing a unit at a time to find the cut is
;; wasteful but exact, and the trial is rolled back so that it leaves no trace
;; in the record of composition.
(define (leftover-units c units spec capacity)
  (define mark (length (unbox (comp-events c))))
  (define result
    (let loop ([us units] [taken 0])
      (cond
        [(null? us) '()]
        [else
         (define n (length (compose c (list (car us)) spec 0.0)))
         (if (> (+ taken n) capacity) us (loop (cdr us) (+ taken n)))])))
  (define evs (unbox (comp-events c)))
  (set-box! (comp-events c) (list-tail evs (- (length evs) mark)))
  result)

;; The catchword is taken from the copy, not from the next page.
;;
;; This matters, and getting it the other way round made a whole class of
;; evidence impossible. The compositor finished a page, looked at his copy for
;; the word that came next, and set it in the direction line -- before the next
;; page existed. McKerrow's proof is the mismatches: we find "a correct
;; catchword in cases where the opening words of the next page are wrong, owing
;; to the compositor having mistaken the point at which he left off and
;; consequently omitted or repeated a word or two. The catchword must therefore
;; have been taken from the MS."
;;
;; Hence his editorial rule: where a catchword disagrees with the page it
;; faces, "the reading of the former may well be given the preference, for it
;; was the earlier set up". The catchword can be the better witness to the copy
;; than the text it points at.
;;
;; Taking it from the next page's first printed word, as this did, guarantees
;; they always agree -- so the simulation could never produce the disagreement,
;; and the description's rule about bracketing a catchword that does not answer
;; was unreachable code.
;; THE CATCHWORD COMES FROM THE COPY, WHICH IS THE WHOLE OF McKERROW'S POINT.
;;
;; He uses it to prove the catchword was set from the manuscript rather than
;; from the standing type of the next page: "the comparative frequency with
;; which we find a correct catchword in cases where the opening words of the
;; next page are wrong, owing to the compositor having mistaken the point at
;; which he left off and consequently omitted or repeated a word or two". The
;; catchword is RIGHT and the page it faces is WRONG.
;;
;; This had a fallback to `from-page' -- the next page's actual first printed
;; word -- for every page that dropped no copy, which is to say nearly all of
;; them. So the catchword was copied from the page it faces and could not
;; disagree with it, and the only route to a disagreement was a page overflowing
;; its cast-off allocation. §5 of the roadmap named that as a defect; building
;; the mis-resumption mechanism did not fix it, because the slip moved the page's
;; opening and the catchword together.
;;
;; Three sources for it now, in the order the compositor would have them:
;;
;;   from-copy   the next page dropped whole lines, so the copy's next word is
;;               the first of what was dropped
;;   from-slip   he mis-resumed and dropped a word or two. The word standing at
;;               the join carries what the copy read there, so the catchword is
;;               the first of THOSE -- set in type, since a catchword is type
;;               and the comparison downstream is against a printed form
;;   from-page   nothing went wrong, and the two agree by construction
(define (add-catchwords pages cv)
  (for/list ([p (in-list pages)] [i (in-naturals)])
    (cond
      [(>= (add1 i) (length pages)) p]
      [else
       (define nxt (list-ref pages (add1 i)))
       (define from-copy
         (for/or ([t (in-list (page-omitted nxt))])
           (define ws (string-split t))
           (and (pair? ws) (car ws))))
       (define first-word
         (for/or ([l (in-list (page-all-lines nxt))])
           (and (pair? (set-line-words l)) (car (set-line-words l)))))
       (define from-slip
         (and first-word
              (ormap (lambda (c)
                       (string-prefix? c "resumption: a word or two dropped"))
                     (word-causes first-word))
              (word-copy first-word)
              (let ([ws (string-split (word-copy first-word))])
                (and (pair? ws) (apply-conventions cv (car ws))))))
       (define from-page (and first-word (word-printed first-word)))
       (struct-copy page p
                    [catchword (or from-copy from-slip from-page "")])])))

;; Making ready: the running titles, the box rules and the centre rule are all
;; put to the composed type here, because none of them is the compositor's
;; work. He sets the text; the forme is dressed at the imposing stone.
(define (add-running-titles pages formes fmt g standing)
  (define by-key
    (for*/hash ([fm (in-list formes)] [p (in-list (forme-page-numbers fm))])
      (values (cons (forme-gathering fm) p) fm)))
  (define counters (make-hash))
  ;; The house's stock of centre rules. A centre rule goes to the case with the
  ;; type it stood beside and comes back with the next page set from that case,
  ;; so the number in play is the number of pages that can stand at once --
  ;; which is why Hinman finds that "additional centre rules now appear" at
  ;; quire F, in the same breath as the larger stock of type (i. 44). A shop
  ;; with few of them uses each oftener, and each accordingly shows its damage
  ;; sooner and in more places: that recurrence is the evidence.
  (define n-centre (max 4 (* standing (book-format-columns fmt))))
  (define centre-rules
    (for/list ([i (in-range n-centre)])
      (make-rule (format "C~a" (add1 i)) 'centre (book-format-lines fmt) g)))
  ;; How many formes a given arrangement of the ten box rules survives. Hinman:
  ;; "almost never, when rules took up new positions in a given forme, did they
  ;; resume exactly their former positions in some later forme", and an
  ;; arrangement holds "for a few formes before being succeeded by a new
  ;; arrangement" (i. 148).
  (define since-rearrange (make-hash))
  (define page-no (box 0))
  ;; The play now being set. A heading line on a page is the start of one, and
  ;; every page after it carries that name until the next heading.
  (define current-head (box ""))
  (for/list ([p (in-list pages)])
    (for ([l (in-list (page-all-lines p))]
          #:when (eq? (set-line-kind l) 'heading))
      (define txt (string-upcase (line-text l)))
      (unless (string=? (string-trim txt) "")
        (set-box! current-head txt)))
    (define r (page-pref p))
    (define fm (hash-ref by-key (cons (page-ref-gathering r) (page-ref-number r)) #f))
    (cond
      [(or (not fm) (not (forme-skeleton fm))) p]
      [else
       (define sk (forme-skeleton fm))
       (define k (hash-ref counters (skeleton-name sk) 0))
       (hash-set! counters (skeleton-name sk) (add1 k))
       (define t (title-for sk k))
       ;; The head-line names the play, not the book.
       ;;
       ;; `title-for' hands back the skeleton's title, whose *damage* is the
       ;; evidence -- a chipped d recurring across formes is how a skeleton is
       ;; identified, and that must travel unchanged. But its TEXT is a fact
       ;; about what is being printed: a shop reaching the end of one play and
       ;; starting the next resets the words while the type of the head-line
       ;; goes on being the same battered type.
       ;;
       ;; This printed the book's one global title on every page. On a single
       ;; play nobody notices; on the Folio it put THE HISTORY over all 1,020
       ;; pages where the real book has The Tempest, then The Two Gentlemen of
       ;; Verona, and so on. Comparing our page against the Norton plate is
       ;; what showed it.
       ;; The box rules come with the skeleton, and are re-laid every few
       ;; formes. Five to a page: the first page of a forme takes the first
       ;; five of the arrangement and the second the other five, so that the
       ;; ten of a forme are a set and change together, which is the unit
       ;; Hinman actually reads.
       (define n (hash-ref since-rearrange (skeleton-name sk) 0))
       (when (>= n 6)
         (rearrange-rules! sk g)
         (hash-set! since-rearrange (skeleton-name sk) 0))
       (hash-update! since-rearrange (skeleton-name sk) add1 0)
       (define ten (skeleton-rules-in-order sk))
       (define five (if (even? k) (take ten 5) (drop ten 5)))
       (set-box! page-no (add1 (unbox page-no)))
       (struct-copy page p
                    [box-rules five]
                    ;; Only a page set in more than one column has a centre
                    ;; rule; a quarto has nothing between columns to divide.
                    [centre-rule
                     (and (> (book-format-columns fmt) 1)
                          (list-ref centre-rules
                                    (modulo (unbox page-no) n-centre)))]
                    [running-title
                     (if (string=? (unbox current-head) "")
                         t
                         (struct-copy running-title t
                                      [text (unbox current-head)]))])])))

(define (compress-stints log)
  (let loop ([xs log] [out '()])
    (cond
      [(null? xs) (reverse out)]
      [(and (pair? out) (string=? (car (car out)) (car (car xs))))
       (loop (cdr xs) (cons (list (car (car out)) (cadr (car out)) (cdr (car xs)))
                            (cdr out)))]
      [else (loop (cdr xs) (cons (list (car (car xs)) (cdr (car xs)) (cdr (car xs)))
                                 out))])))

(module+ test
  (require rackunit racket/file racket/runtime-path)

  (define-runtime-path ado-sample "samples/ado/_all-q1600.txt")

  ;; The chain from a mis-cast page to a catchword that does not answer.
  ;;
  ;; Each link here was unreachable until the casting off was made to err in
  ;; both directions: no page was ever over-full, so no copy was dropped, so
  ;; the catchword always agreed with the page it faced. McKerrow's diagnostic
  ;; -- "a correct catchword in cases where the opening words of the next page
  ;; are wrong" -- could not occur. This pins all three.
  (let ()
    (define txt (file->string ado-sample))
    ;; Badly cast off. Since a paragraph may now be broken at the foot of a
    ;; page, the pages fill and the strain has to be worse before anything is
    ;; actually lost -- which is right, and is why this asks for 0.45 where it
    ;; used to ask for 0.6.
    (define b (set-book (make-house #:fmt QUARTO #:compositors '("A" "B")
                                    #:seed 1 #:cast-off-accuracy 0.45)
                        txt 'prose))
    (define ps (book-pages b))
    ;; MIS-RESUMING, McKerrow's mechanism. Asserted at a rate that guarantees it
    ;; fires, because the default is a knob with no source and a test of it at
    ;; the default would be a test of the seed.
    ;;
    ;; What is pinned is the shape, not the count: the slip lands where he
    ;; returns to the copy, both directions occur, and the word standing at the
    ;; join carries what the copy read -- which is the whole reason this can
    ;; become a press variant where the two mechanisms built before it could not.
    (let* ([bb (set-book (make-house #:fmt QUARTO #:compositors '("A" "B")
                                     #:seed 3 #:mis-resume 0.9)
                         txt 'prose)]
           [evs (filter (lambda (e) (eq? (event-kind e) 'resumption))
                        (book-events bb))])
      (check-true (> (length evs) 3) "he loses his place, at a rate that says he must")
      (check-true (for/or ([e (in-list evs)])
                    (regexp-match? #rx"dropped" (event-detail e)))
                  "a word or two dropped")
      (check-true (for/or ([e (in-list evs)])
                    (regexp-match? #rx"repeated" (event-detail e)))
                  "and a word or two repeated: one slip, two directions")
      ;; The evidence has to be on the page, or the corrector can never see it.
      (check-true
       (for*/or ([p (in-list (book-pages bb))]
                 [l (in-list (page-all-lines p))]
                 [w (in-list (set-line-words l))])
         (and (word-copy w) (word-read w)
              (not (string=? (word-copy w) (word-read w)))))
       "the word at the join says what the copy read"))
    ;; And nothing happens when the knob is shut.
    (check-equal?
     (for/sum ([e (in-list (book-events
                            (set-book (make-house #:fmt QUARTO #:seed 3
                                                  #:mis-resume 0.0)
                                      txt 'prose)))])
       (if (eq? (event-kind e) 'resumption) 1 0))
     0 "at nought he never loses his place")

    ;; McKERROW'S DIAGNOSTIC, which is the point of building the slip at all:
    ;; a CORRECT catchword facing a page whose opening words are wrong. It is
    ;; his proof that the catchword was set from the manuscript.
    ;;
    ;; `add-catchwords' used to fall back to the next page's actual first
    ;; printed word whenever no copy had been dropped, so the catchword was
    ;; copied from the page it faces and could not disagree with it. The only
    ;; route to a disagreement was a page overflowing its cast-off allocation --
    ;; a symptom of a different defect, as §5 says. Asserted with the casting
    ;; off PERFECT, so nothing but the slip can produce it.
    (let* ([bb (set-book (make-house #:fmt QUARTO #:compositors '("A" "B")
                                     #:seed 3 #:cast-off-accuracy 1.0
                                     #:mis-resume 0.9)
                         txt 'prose)]
           [ps (book-pages bb)]
           [bad (for/sum ([p (in-list ps)] [n (in-list (cdr ps))])
                  (define opens
                    (for/or ([l (in-list (page-all-lines n))])
                      (and (pair? (set-line-words l))
                           (word-printed (car (set-line-words l))))))
                  (if (and opens (not (string=? (page-catchword p) ""))
                           (not (string=? (page-catchword p) opens)))
                      1 0))])
      (check-true (> bad 0)
                  "a right catchword faces a wrong page, with the casting off perfect"))
    ;; And with no slip and perfect casting off, every catchword answers.
    (let* ([bb (set-book (make-house #:fmt QUARTO #:compositors '("A" "B")
                                     #:seed 3 #:cast-off-accuracy 1.0
                                     #:mis-resume 0.0)
                         txt 'prose)]
           [ps (book-pages bb)]
           [bad (for/sum ([p (in-list ps)] [n (in-list (cdr ps))])
                  (define opens
                    (for/or ([l (in-list (page-all-lines n))])
                      (and (pair? (set-line-words l))
                           (word-printed (car (set-line-words l))))))
                  (if (and opens (not (string=? (page-catchword p) ""))
                           (not (string=? (page-catchword p) opens)))
                      1 0))])
      (check-equal? bad 0 "and nothing goes wrong when nothing went wrong"))

    (check-true (for/or ([p (in-list ps)]) (> (page-pressure p) 0))
                "some page is crowded")
    (check-true (for/or ([p (in-list ps)]) (< (page-pressure p) 0))
                "some page is spun out")
    ;; Omission is rare even under bad casting off -- so asking one run for it
    ;; is asking the seed, not the program. Scanned over several instead.
    ;;
    ;; IT GOT RARER, AND ON PURPOSE. These two checks ran at accuracy 0.45 and
    ;; both failed the day `estimate' was made to allow room for the speech
    ;; prefix it had been scoring at nought. That is the effect ROADMAP §5
    ;; predicted in writing before the change: "a mechanism that can only fire
    ;; as a side-effect of a bug will read as healthy while the bug lasts and
    ;; vanish when it is fixed." The omission branch was firing off a systematic
    ;; over-allotment of about four per cent, not off the deliberate error these
    ;; checks name -- so they were passing for the wrong reason.
    ;;
    ;; Measured over 24 seeds after the change, seeds dropping copy: 3 at 0.45,
    ;; 4 at 0.30, 3 at 0.20, 7 at 0.10, 5 at 0.00 -- and the count of seeds with
    ;; a failed catchword is identical at every one of those, which is the same
    ;; single fact seen twice that §5 already records. At accuracy 0.0, the
    ;; worst casting off there is, seeds 0, 5 and 8 all fire: three independent
    ;; hits in nine, which is a test of the program rather than of a seed.
    ;;
    ;; The rate is now McKerrow's "as occasionally happens" rather than the two
    ;; thirds of a book it was, and the mechanism is still reachable -- which is
    ;; what these checks exist to guarantee.
    (check-true
     (for/or ([seed (in-range 9)])
       (define bb (set-book (make-house #:fmt QUARTO #:compositors '("A" "B")
                                        #:seed seed #:cast-off-accuracy 0.0)
                            txt 'prose))
       (for/or ([p (in-list (book-pages bb))]) (pair? (page-omitted p))))
     "copy is dropped where the page will not hold it")
    (check-true
     (for/or ([seed (in-range 9)])
       (define pp (book-pages (set-book (make-house #:fmt QUARTO
                                                    #:compositors '("A" "B")
                                                    #:seed seed
                                                    #:cast-off-accuracy 0.0)
                                        txt 'prose)))
       (for/or ([p (in-list pp)] [n (in-list (cdr pp))])
         (define opens
           (for/or ([l (in-list (page-all-lines n))])
             (and (pair? (set-line-words l))
                  (word-printed (car (set-line-words l))))))
         (and opens (not (string=? (page-catchword p) ""))
              (not (string=? (page-catchword p) opens)))))
     "a catchword does not answer the page it faces"))

  (define sample
    (string-append
     "Enter King and Queen.\n\n"
     "King. And can you by no drift of conference\n"
     "Get from him why he puts on this confusion,\n"
     "Grating so harshly all his days of quiet\n"
     "With turbulent and dangerous lunacy?\n\n"
     "Queen. Did he receive you well?\n\n"
     "King. Most like a gentleman, and with much forcing of his disposition, "
     "niggard of question, but of our demands most free in his reply.\n"))

  (define h (make-house #:fmt QUARTO #:compositors '("A" "B") #:seed 1623))
  (define b (set-book h sample))

  (check-true (> (length (book-pages b)) 0))
  ;; A title-page is preliminary matter, so a book that has one is no longer
  ;; A-Z straight through: it opens with a half-sheet in whatever series the
  ;; house signs its front matter with, and the text follows in the main.
  (check-regexp-match #px"^4°: " (book-collation b))
  ;; The text is in the main series. Its *extent* is not asserted, because a
  ;; gathering whose white leaves were used for the preliminaries and cut out
  ;; is bound short: this sample comes out 4°: *² A², which is McKerrow's
  ;; *2, A-Y4, Z2 in miniature.
  (check-regexp-match #px"A[¹²³⁴⁵⁶⁷⁸]" (book-collation b))

  ;; A house that sets no title-page and looks for no preliminaries is the
  ;; book this program used to make, and still makes: one series, from A.
  (define plain
    (set-book (make-house #:fmt QUARTO #:compositors '("A" "B") #:seed 1623
                          #:titlepage? #f #:find-prelims? #f)
              sample))
  (check-regexp-match #px"^4°: A⁴" (book-collation plain))
  (check-equal? (length (book-runs plain)) 1)

  ;; Every leaf the collation claims is a leaf the book actually has.
  ;;
  ;; A gathering shorter than the format's own scheme -- which is what a
  ;; preliminary gathering nearly always is -- used to lose all but its first
  ;; page. `formes-for-gathering' hands back the whole twelve-page folio
  ;; scheme whatever #:leaves it is given, so a three-leaf preliminary
  ;; gathering was set in the order 5 8 6 7 3 10 4 9 1 12 2 11, and the second
  ;; entry, page 8, had no segment; the loop answered `(void)' and stopped
  ;; instead of skipping. The First Folio's preliminaries came out as one
  ;; blank leaf -- no dedication, no epistles, no commendatory verses, no
  ;; Catalogue -- while the collation went on saying a³ and the report went on
  ;; counting all eight declared divisions.
  ;;
  ;; It is checked against the collation because that is the statement a
  ;; reader trusts, and because nothing else noticed for as long as it stood.
  (for ([bk (in-list (list b plain))])
    (define claimed
      (for/sum ([r (in-list (book-runs bk))])
        (* 2 (apply + (sig-run-leaves r)))))
    (check-equal? (length (book-pages bk)) claimed
                  "the book has every page its collation claims"))

  ;; The preliminaries are printed last and bound first, which is the whole
  ;; point of their having a series of their own. Both must hold at once.
  (let* ([prelim (filter (lambda (p) (eq? (gathering-plan-role p) 'prelim))
                         (book-plans b))]
         [text (filter (lambda (p) (eq? (gathering-plan-role p) 'text))
                       (book-plans b))])
    (check-true (pair? prelim) "the title-page made a preliminary gathering")
    (check-true (< (gathering-plan-place (car prelim))
                   (gathering-plan-place (car text)))
                "the preliminaries are bound in front")
    ;; and the first page of the finished book is the title-page
    (check-equal? (page-sig (car (book-pages b)))
                  (format "~a1r" (series-mark (gathering-plan-series (car prelim))
                                              (gathering-plan-index (car prelim))))))

  ;; East's case: a Table that goes to the back because the front matter is
  ;; a leaf shorter without it and the last sheet has the white paper to take
  ;; it. Worth a test of its own, because it is a branch that fires on the
  ;; arithmetic of two make-ups and would otherwise be invisible when it
  ;; stopped firing -- which is how four mechanisms in this program have died.
  ;; The copy DECLARES its divisions, which is how a real document reaches the
  ;; press now: a TEI type, a LaTeX \frontmatter, a Word style or a Pandoc div,
  ;; carried through by import.rkt as a marker on the heading. The heading
  ;; vocabulary is not used here, and is off by default.
  (let* ([rep (lambda (s n) (apply string-append (for/list ([i (in-range n)]) s)))]
         [copy (string-append
                "# [dedication] The Epistle Dedicatorie\n\n"
                (rep "To the Right Honourable the Lords and Commons of England, my very good Lords, whose favour hath emboldened this small labour to seek the light. " 40)
                "\n\n# [contents] A Table of the principall matters\n\n"
                (rep "Of the licencing of bookes, page 1. Of the ancient practise of Athens, page 3. " 20)
                "\n\n# THE FIRST BOOKE\n\n"
                (rep "Now began the day to breake, and the shepheards to stirre, and the flockes to feede, and the birds to sing in every bush about them. " 300))]
         [eb (set-book (make-house #:fmt QUARTO #:seed 3) copy)]
         [m (book-moved-to-end eb)])
    (check-true (and m #t) "there was matter that could have moved")
    (check-true (second m) "the Table went to the back, as East's did")
    (check-equal? (first m) '(contents))
    ;; and it is really at the back: no preliminary gathering holds it
    (check-false (for/or ([p (in-list (book-plans eb))])
                   (and (eq? (gathering-plan-role p) 'prelim)
                        (for*/or ([s (in-list (gathering-plan-segments p))]
                                  [u (in-list (cast-off-segment-units s))])
                          (regexp-match? #px"licencing of bookes"
                                         (copy-unit-text u)))))
                "the Table is not among the preliminaries")
    (check-true (for/or ([p (in-list (book-plans eb))])
                  (and (eq? (gathering-plan-role p) 'text)
                       (for*/or ([s (in-list (gathering-plan-segments p))]
                                 [u (in-list (cast-off-segment-units s))])
                         (regexp-match? #px"licencing of bookes"
                                        (copy-unit-text u)))))
                "the Table is in the last gathering of the text"))

  ;; The forme that carries the title-page went to press after every forme of
  ;; the text, because it was set after them.
  (let ([front (for/list ([fm (in-list (book-formes b))]
                          #:when (equal? (forme-mark fm)
                                         (series-mark
                                          (gathering-plan-series (car (book-plans b)))
                                          (gathering-plan-index (car (book-plans b))))))
                 (forme-order fm))]
        [rest (for/list ([fm (in-list (book-formes b))]
                         #:unless (equal? (forme-mark fm)
                                          (series-mark
                                           (gathering-plan-series (car (book-plans b)))
                                           (gathering-plan-index (car (book-plans b))))))
                (forme-order fm))])
    ;; Either the preliminaries had formes of their own, and those were the
    ;; last to press; or they had none at all, because they were printed in
    ;; the white leaves of the last sheet and cut out -- which is the same
    ;; fact about the order of work, arrived at more cheaply.
    (cond
      [(pair? front)
       (check-true (> (apply min front) (apply max rest))
                   "the preliminaries were the last thing set")]
      [else
       (check-true (book-cut-from-last-sheet? b)
                   "preliminaries with no formes of their own were cut from the last sheet")]))

  ;; McKerrow's economy, end to end. A book whose text stops short of the end
  ;; of its last sheet does not pay for a preliminary half-sheet: the
  ;; preliminaries go in the white leaves and are cut out, and the collation
  ;; then shows the last gathering short by exactly the leaves that went.
  (let scan ([seed 0])
    (cond
      [(> seed 40) (fail "no seed in 40 cut the preliminaries from the last sheet")]
      [else
       (define cb (set-book (make-house #:fmt QUARTO #:seed seed) sample))
       (cond
         [(not (book-cut-from-last-sheet? cb)) (scan (add1 seed))]
         [else
          (define ps (book-plans cb))
          (define views (filter gathering-plan-shares ps))
          (define owners (filter (lambda (p) (pair? (gathering-plan-excised p))) ps))
          (check-true (pair? views) "the preliminaries became a view of another sheet")
          (check-true (pair? owners) "some gathering had leaves cut out of it")
          ;; the leaves cut out are exactly the leaves the view claims
          (check-equal? (for/sum ([v (in-list views)]) (gathering-plan-leaves v))
                        (for/sum ([o (in-list owners)]) (length (gathering-plan-excised o))))
          ;; the sheet was printed whole and is bound short
          (define owner (car owners))
          (check-equal? (plan-bound-leaves owner)
                        (- (gathering-plan-leaves owner)
                           (length (gathering-plan-excised owner))))
          (check-true (< (plan-bound-leaves owner) (gathering-plan-leaves owner)))
          ;; and the cut leaves are bound at the front, signed in their own
          ;; series, exactly as McKerrow's *2, A-Y4, Z2
          (check-equal? (page-sig (car (book-pages cb)))
                        (format "~a1r" (series-mark (gathering-plan-series (car views))
                                                    (gathering-plan-index (car views)))))
          (check-regexp-match #px"^4°: " (book-collation cb))])]))

  ;; No line anywhere overhangs its measure. `make-line' would have raised,
  ;; so reaching here at all is the check; assert it explicitly anyway.
  (for* ([p (in-list (book-pages b))] [l (in-list (page-all-lines p))])
    (check-true (<= (line-set-width l) (set-line-measure l))))

  ;; Every word of the prepared copy is standing in type, or accounted for.
  (define wanted
    (for*/fold ([h (hash)]) ([u (in-list (book-copy-units b))]
                             #:unless (memq (copy-unit-kind u) '(blank prefix))
                             [w (in-list (string-split (copy-unit-text u)))])
      (hash-update h w add1 0)))
  (define got
    (for*/fold ([h (hash)]) ([p (in-list (book-pages b))]
                             [l (in-list (page-all-lines p))]
                             [w (in-list (set-line-words l))]
                             #:unless (for/or ([c (in-list (word-causes w))])
                                        (regexp-match? #px"prefix|second half" c)))
      (hash-update h (word-copy w) add1 0)))
  (define eyeskipped
    (for/sum ([e (in-list (book-events b))]
              #:when (and (eq? (event-kind e) 'copy)
                          (regexp-match? #px"eye returned" (event-detail e))))
      (length (string-split (event-before e)))))
  (define dropped
    (for*/sum ([p (in-list (book-pages b))] [t (in-list (page-omitted p))])
      (length (string-split t))))
  (define missing
    (for/sum ([(w n) (in-hash wanted)])
      (max 0 (- n (hash-ref got w 0)))))
  (check-equal? (- missing eyeskipped dropped) 0
                "every word is in type or explained by a recorded event")

  ;; Catchwords match the first word of the following page.
  (for ([p (in-list (book-pages b))] [i (in-naturals)]
        #:when (< (add1 i) (length (book-pages b))))
    (define nxt (list-ref (book-pages b) (add1 i)))
    (define first-word
      (for/or ([l (in-list (page-all-lines nxt))])
        (and (pair? (set-line-words l)) (word-printed (car (set-line-words l))))))
    (when (and first-word (not (string=? (page-catchword p) "")))
      (check-equal? (page-catchword p) first-word
                    (format "catchword on ~a" (page-sig p))))))
