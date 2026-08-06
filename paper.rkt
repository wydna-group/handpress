#lang racket/base
;;; The sheet, and what the folding makes of it.
;;;
;;; Format and size are two different things, and until this module existed the
;;; program modelled only the first. It knew that a quarto is a sheet folded
;;; twice and imposed accordingly; it did not know how big the sheet was, and
;;; so it did not know how big a leaf is. Everything downstream inherited the
;;; gap: the type page was computed from the type alone, nothing checked that
;;; it would fit on paper, and the facsimile drew a leaf as the type page plus
;;; a fixed margin -- which rendered a quarto at 1.99 tall to wide where
;;; Gaskell's own figures give 1.31.
;;;
;;; Gaskell, p. 68: "most of the printing paper of the sixteenth century was in
;;; the foolscap size range, which was considered the ordinary size, the shapes
;;; and sizes of books printed on it being determined by the folding. The
;;; ordinary size then increased gradually, and by the eighteenth century it
;;; was in the demy range." Foolscap is therefore the default here, and the
;;; period this program covers is the one in which that was true.
;;;
;;; What is deliberately *not* here: watermarks, countermarks, chain-lines, and
;;; the twinned moulds that make them evidence. Gaskell's Table 3 lists the
;;; sixteenth-century foolscap group as carrying the Strasbourg lily, the pot
;;; and the grapes indifferently, and warns (p. 68) that the marks "were not
;;; used exclusively for particular sizes, especially during the sixteenth
;;; century" -- so a mark does not give a size in this period, and pretending
;;; otherwise would be worse than silence. See the ROADMAP entry.

(require racket/math)

(provide (struct-out paper) (struct-out layout)
         PAPERS paper-named paper-names DEFAULT-PAPER
         paper-leaf paper-leaf-mm
         MM-PER-EM mm-of-ems type-page-mm leaf-layout MARGIN-CANON
         COLUMN-GUTTER-EMS)

;; Sheet dimensions in millimetres, always long edge first. `note' records
;; where the figure comes from, because a sheet size is a citation and not a
;; constant: the same name meant different paper in different countries and
;; different centuries, which is the whole difficulty of Gaskell's Table 3.
(struct paper (name long short note) #:transparent)

;; Gaskell, _A New Introduction to Bibliography_ (1972).
;;
;;   * foolscap and crown are read off Table 3 (pp. 73-5), taking the
;;     sixteenth-century French entry in each group, that being the paper an
;;     English shop of 1580-1640 was most likely to be buying.
;;   * pot, demy and royal are Key III's three representative sizes (p. 86),
;;     which is where his own tabulated leaf dimensions come from, so using
;;     them lets `paper-leaf' be checked against his arithmetic rather than
;;     only against itself. See the test submodule.
(define PAPERS
  (list
   (paper "foolscap" 420 320 "Gaskell Table 3, 16th cent. France, 42×32 cm")
   (paper "pot"      390 310 "Gaskell Key III, representative pot, 39.0×31.0 cm")
   (paper "crown"    450 350 "Gaskell Table 3, 16th cent. France, 45×35 cm")
   (paper "demy"     510 380 "Gaskell Key III, representative demy, 51.0×38.0 cm")
   (paper "royal"    600 460 "Gaskell Key III, representative royal, 60.0×46.0 cm")))

(define DEFAULT-PAPER (car PAPERS))

(define (paper-names) (map paper-name PAPERS))

(define (paper-named n)
  (for/or ([p (in-list PAPERS)])
    (and (string=? (paper-name p) n) p)))

;; A fold always halves whichever dimension is currently the longer, and the
;; leaf is the result stood upright. That one rule is the whole relationship
;; between format and size, and it is why the proportion alternates instead of
;; settling: from a foolscap sheet the folio is 1.52 tall to wide, the quarto
;; 1.31, the octavo 1.52 again. A folio and an octavo are nearly the same
;; shape and nothing like the same size; the quarto is the squat one.
;;
;; Returns (values height width) in millimetres, height first, as Gaskell's
;; tables give them.
(define (paper-leaf p folds)
  (let loop ([h (paper-long p)] [w (paper-short p)] [n folds])
    (cond
      [(zero? n) (values (max h w) (min h w))]
      [(>= h w) (loop (/ h 2) w (sub1 n))]
      [else     (loop h (/ w 2) (sub1 n))])))

;; The same, rounded to whole millimetres for report and record. The exact
;; rationals are kept by `paper-leaf' so that three folds of an odd sheet do
;; not accumulate a rounding error the way 0.5 mm at each fold would.
(define (paper-leaf-mm p folds)
  (define-values (h w) (paper-leaf p folds))
  (values (exact-round h) (exact-round w)))

;; ---------------------------------------------------------------------------
;; The type page on the leaf
;;
;; The paper gives a leaf; the type gives a rectangle of print; the margins are
;; what is left. Keeping that subtraction here rather than in the report means
;; the description, the TEI and the facsimile all read one answer instead of
;; three, which is the rule this project keeps relearning.
;; ---------------------------------------------------------------------------

;; A printer's pica em is 4.2175 mm, and the Folio's type is pica set solid, so
;; a 20-line measurement -- the standard way of identifying a fount before
;; foundries could be named -- follows directly from the body size.
(define MM-PER-EM 4.2175)

(define (mm-of-ems x) (* x MM-PER-EM))

;; The furniture standing between two columns of type. It is inside the type
;; page, not outside it: a bibliographer measuring a two-column folio measures
;; from the left edge of the first column to the right edge of the second, and
;; the gutter is part of what he measures.
(define COLUMN-GUTTER-EMS 2.2)

;; The printed rectangle: `lines' deep, and across, the columns with their
;; gutters between them.
(define (type-page-mm lines measure-ems columns)
  (values (mm-of-ems lines)
          (mm-of-ems (+ (* measure-ems columns)
                        (* COLUMN-GUTTER-EMS (max 0 (sub1 columns)))))))

;; Inner : head : outer : tail.
;;
;; The type page does not sit in the middle of the leaf. It sits toward the
;; inner and upper corner, so that the two type pages of an opening read as one
;; block and the tail carries the weight. 2:3:4:6 is the proportion usually
;; given for that placement.
;;
;; This is a convention and not a measurement, and it is the one number in this
;; module that Gaskell does not supply. It is a house parameter for that
;; reason: a real book's margins are whatever the furniture and the trimming
;; made them, and if the simulation is ever calibrated against measured type
;; pages this is the first thing that should move.
(define MARGIN-CANON '(2 3 4 6))

(struct layout (leaf-h leaf-w type-h type-w inner head outer tail fits?)
  #:transparent)

;; Place a type page on a leaf. Margins come out in millimetres; `fits?' is
;; false when the type page is simply bigger than the paper, which is a fault
;; in the format -- a measure or a line count that no sheet of this size could
;; carry -- and is reported rather than clamped away.
(define (leaf-layout leaf-h leaf-w type-h type-w [canon MARGIN-CANON])
  (define-values (i-p h-p o-p t-p)
    (values (car canon) (cadr canon) (caddr canon) (cadddr canon)))
  (define across (- leaf-w type-w))
  (define down   (- leaf-h type-h))
  (define (share slack a b) (if (<= slack 0) 0 (* slack (/ a (+ a b)))))
  (layout leaf-h leaf-w type-h type-w
          (share across i-p o-p)
          (share down   h-p t-p)
          (share across o-p i-p)
          (share down   t-p h-p)
          (and (>= across 0) (>= down 0))))

(module+ test
  (require rackunit)

  ;; Gaskell's Key III (p. 86) tabulates the uncut leaf for each format from
  ;; three representative sheets. If the halving rule is right it must
  ;; reproduce that table exactly, and if it is wrong this is where it shows.
  (define (check-leaf name folds want-h want-w)
    (define-values (h w) (paper-leaf (paper-named name) folds))
    (check-= (exact->inexact h) want-h 0.001 (format "~a height, ~a folds" name folds))
    (check-= (exact->inexact w) want-w 0.001 (format "~a width, ~a folds" name folds)))

  ;; pot, 39.0 × 31.0 cm
  (check-leaf "pot" 1 310.0 195.0)
  (check-leaf "pot" 2 195.0 155.0)
  (check-leaf "pot" 3 155.0  97.5)
  ;; demy, 51.0 × 38.0 cm
  (check-leaf "demy" 1 380.0 255.0)
  (check-leaf "demy" 2 255.0 190.0)
  (check-leaf "demy" 3 190.0 127.5)
  ;; royal, 60.0 × 46.0 cm
  (check-leaf "royal" 1 460.0 300.0)
  (check-leaf "royal" 2 300.0 230.0)
  (check-leaf "royal" 3 230.0 150.0)

  ;; The unfolded sheet is the broadside, and is the sheet.
  (define-values (h0 w0) (paper-leaf (paper-named "pot") 0))
  (check-equal? (exact->inexact h0) 390.0)
  (check-equal? (exact->inexact w0) 310.0)

  ;; The proportion alternates rather than settling: folio and octavo are the
  ;; same shape, the quarto is squatter. This is the fact the renderer was
  ;; getting wrong, so it is asserted rather than left to the eye.
  (define (ratio name folds)
    (define-values (h w) (paper-leaf (paper-named name) folds))
    (exact->inexact (/ h w)))
  (check-= (ratio "foolscap" 1) (ratio "foolscap" 3) 0.001)
  (check-true (< (ratio "foolscap" 2) (ratio "foolscap" 1)))

  ;; Foolscap, the default, and the figures the facsimile has to hit.
  (check-leaf "foolscap" 1 320.0 210.0)
  (check-leaf "foolscap" 2 210.0 160.0)
  (check-leaf "foolscap" 3 160.0 105.0)

  (check-false (paper-named "elephant"))
  (check-equal? (paper-name DEFAULT-PAPER) "foolscap")

  ;; ---- the type page on the leaf ----------------------------------------

  ;; The quarto as the program sets it: 38 lines, 21 ems, one column.
  (define-values (th tw) (type-page-mm 38 21.0 1))
  (check-= th 160.3 0.1)
  (check-=  tw  88.6 0.1)

  ;; The First Folio's two columns of 66 lines, with the gutter between them
  ;; counted in: 16 + 2.2 + 16 ems across, not 32.
  (define-values (fh fw) (type-page-mm 66 16.0 2))
  (check-= fh 278.4 0.1)
  (check-= fw 144.2 0.1)
  ;; A single column has no gutter, so two columns of 16 ems are wider than one
  ;; of 32 by exactly the furniture standing between them.
  (define-values (_h1 w1) (type-page-mm 66 32.0 1))
  (check-= (- fw w1) (mm-of-ems COLUMN-GUTTER-EMS) 0.001)

  ;; A foolscap quarto: does the print fit the paper, and where does it sit?
  (define-values (qh qw) (paper-leaf (paper-named "foolscap") 2))
  (define L (leaf-layout qh qw th tw))
  (check-true (layout-fits? L))
  ;; The margins must account for exactly the paper that is not printed on.
  (check-= (+ (layout-inner L) (layout-type-w L) (layout-outer L))
           (exact->inexact qw) 0.001)
  (check-= (+ (layout-head L) (layout-type-h L) (layout-tail L))
           (exact->inexact qh) 0.001)
  ;; And they must fall in the order the canon puts them in.
  (check-true (< (layout-inner L) (layout-outer L)))
  (check-true (< (layout-head L)  (layout-tail L)))

  ;; A folio type page will not go on an octavo leaf, and the layout says so
  ;; rather than returning a negative margin.
  (define-values (oh ow) (paper-leaf (paper-named "foolscap") 3))
  (define bad (leaf-layout oh ow fh fw))
  (check-false (layout-fits? bad))
  (check-equal? (layout-inner bad) 0)
  (check-equal? (layout-head bad) 0))
