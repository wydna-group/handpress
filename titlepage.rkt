#lang racket/base
;;; The title-page, generated.
;;;
;;; A title-page is preliminary matter and was set like the rest of it, so a
;;; program that supplies one by hand is cheating at the part of the book most
;;; worth simulating: the imprint is the single most formulaic thing a
;;; hand-press book contains, and formulae can be measured.
;;;
;;; The measurements here are Blayney's Appendix II, a checklist of about
;;; ninety books from one London shop between 1604 and 1609, each with a
;;; substantive transcript of its title-page. Counted over those transcripts:
;;;
;;;   the printer is named                 58 of 81   (72%)
;;;   ... and abbreviated to initials      19 of 50   (38%)
;;;   the place line is "LONDON,"          45 of 60
;;;   ... "AT LONDON" or "At London"        9 of 60
;;;   ... "Imprinted at London by"          6 of 60
;;;   a shop is given at all               40 of 81
;;;   ... "and are to be sold at ..."      20 of 40
;;;   ... "dwelling in ..."                20 of 40
;;;   ... naming a sign                    15 of 40
;;;   the date is set with the figures
;;;   spaced apart -- 1 6 0 8.             about half
;;;
;;; The paradigm, which is also the reason this program exists, is no. 56:
;;;
;;;   M. William Shak-ſpeare: | HIS | True Chronicle Hiſtorie of the life and |
;;;   death of King Lear and his three | Daughters. | With the vnfortunate life
;;;   of Edgar, ſonne | and heire to the Earle of Gloſter, and his | ſullen and
;;;   aſſumed humor of | Tom of Bedlam : | As it was played before the Kings
;;;   Maieſtie at Whitehall vpon | S. Stephans night in Chriſtmas Hollidayes. |
;;;   By his Maieſties ſeruants playing vſually at the Gloabe | on the
;;;   Bancke-ſide. | [Device McKerrow 316] | LONDON, | Printed for Nathaniel
;;;   Butter, and are to be ſold at his ſhop in Pauls | Church-yard at the ſigne
;;;   of the Pide Bull neere | S. Auſtins Gate. 1 6 08.
;;;
;;; Blayney notes that the Lear title-page was "the first part of the book to
;;; be set", then distributed -- so a generated title-page has to be settable
;;; first and printable last, which is the awkward case for the type
;;; accounting and is why this module produces copy rather than a page.

(require racket/list racket/string racket/format
         "copytext.rkt" "rng.rkt")

(provide (struct-out imprint) (struct-out titlepage)
         make-titlepage titlepage-units titlepage-transcript
         PRINTERS PUBLISHERS SHOP-SIGNS SHOP-STREETS
         period-year-form)

;; ---------------------------------------------------------------------------
;; The trade
;; ---------------------------------------------------------------------------
;; Real names, from the imprints in Blayney's checklist and from the Stationers
;; named in his text. Inventing plausible ones would put a fictitious printer
;; into an otherwise documented trade, which is the sort of thing this program
;; is supposed to make harder rather than easier.

(define PRINTERS
  '("Nicholas Okes" "George Snowdon" "Lionell Snowdon" "Iohn Windet"
    "Edward Allde" "George Eld" "William Hall" "William White"
    "Richard Bradock" "Robert Raworth" "Felix Kingston" "Simon Stafford"
    "William Iaggard" "Thomas Purfoot" "George Purslowe" "William Stansby"
    "Iohn Harison" "Henry Ballard" "Thomas Haviland" "Iohn Okes"))

(define PUBLISHERS
  '("Nathaniel Butter" "Iohn Busby" "William Welby" "Roger Iackson"
    "Clement Knight" "Simon Waterson" "Walter Burre" "Francis Burton"
    "Richard Sergier" "Leonard Becket" "Bartholomew Sutton" "Iohn Browne"
    "George Potter" "Ioseph Harison" "Iohn Orphinstrange"
    "Christopher Pursett" "Thomas Thorpe" "Edward Blount"))

;; Shop signs, as transcribed. A London bookshop was found by its sign, not by
;; a number, and the sign is the part of an imprint a modern reader least
;; expects and a period one most relied on.
(define SHOP-SIGNS
  '("the Pide Bull" "the Gray-hound" "the white Grayhound" "the Holy Lambe"
    "the Crowne" "the Greene Dragon" "the Byble" "Marie Magdalens Head"
    "the Hand" "the Angell" "the Bell" "the Foxe" "the Rose"
    "the Blacke Beare" "the Tygers Head"))

(define SHOP-STREETS
  '("Pauls Church-yard" "Pater noster Row" "Fleetstreet neere the Conduit"
    "Saint Dunstanes Church-yard in Fleete-streete" "Holborne neere Staple Inne"
    "the Old Bailey" "Cornehill neere the Exchange" "Cheapeside"))

;; Not a shop but the printing house itself, which some imprints give instead.
;; Okes was "dwelling neere Holborne bridge", and two years later "at the
;; ſigne of the Hand" (Blayney i, p. 26).
(define HOUSE-PLACES
  '("neere Holborne bridge" "in Aldersgate streete" "neere Christ Church"
    "in the Blackfriers" "without Cripplegate"))

;; ---------------------------------------------------------------------------

(struct imprint (place printer printer-form publisher shop street sign year
                       spaced-date?)
  #:transparent)

;; `claims' are the lines between the title and the imprint: what the book is
;; and where it was played, "Newly enlarged", "Seene and allowed by publike
;; authoritie". `motto' is the scripture or tag set in italic above the device.
(struct titlepage (title author claims motto device imp) #:transparent)

;; ---------------------------------------------------------------------------
;; The date
;; ---------------------------------------------------------------------------
;; About half the dates in the checklist are set with the figures spaced
;; apart: 1 6 0 5, 16 0 5, 1 6 07, 1 6 0 8. This is not an OCR artefact -- the
;; spacing varies within a single shop and within a single year, and Blayney
;; twice discusses the space between the period and the date as evidence for
;; the order of the states of a title-page (Appendix II, notes to no. 54).
;;
;; It is quadding: the last line of an imprint is short, and the figures were
;; spread to fill it. Which means the spaces are metal, and this program will
;; charge for them.
(define (period-year-form year spaced?)
  (define digits (number->string year))
  (cond
    [(not spaced?) (string-append digits ".")]
    [else
     ;; The observed forms space some of the figures and not others -- "16 0 5"
     ;; and "1 6 08" both occur -- because the compositor was filling a line,
     ;; not applying a rule.
     (string-append (string-join (map string (string->list digits)) " ") ".")]))

;; ---------------------------------------------------------------------------
;; Making one
;; ---------------------------------------------------------------------------

(define (make-titlepage #:title title
                        #:author [author #f]
                        #:year [year 1608]
                        #:printer [printer #f]
                        #:publisher [publisher #f]
                        #:claims [claims '()]
                        #:motto [motto #f]
                        #:rng [g (make-rng 1608)])
  (define pr (or printer (rnd-choice g PRINTERS)))
  (define pu (or publisher (rnd-choice g PUBLISHERS)))
  (define names? (< (rnd g) 0.72))          ; 58 of 81 name the printer
  (define form (if (< (rnd g) 0.38) 'initials 'full))   ; 19 of 50
  (define place
    (let ([r (rnd g)])
      (cond [(< r 0.75) "LONDON,"]
            [(< r 0.90) "AT LONDON,"]
            [else "Imprinted at London"])))
  ;; A book the printer published himself: no bookseller in the imprint, and
  ;; the address, if there is one, is the printing house. "LONDON, | Printed
  ;; by Nicholas Okes, dwelling neere Holborne bridge. 1609."
  ;;
  ;; Never where a bookseller was named on the command line. Asking for an
  ;; imprint and being given one without the name in it is a bug, not a
  ;; simulation of the trade.
  (define self? (and (not publisher) (< (rnd g) 0.1)))
  (define shop? (< (rnd g) 0.49))           ; 40 of 81 give a shop
  (define sold? (< (rnd g) 0.5))            ; sold at / dwelling in -- 20 / 20
  (define sign? (< (rnd g) 0.375))          ; 15 of 40 name a sign
  (titlepage
   title author claims motto
   ;; A device between the title and the imprint. Fifty-five of the checklist's
   ;; entries record one, and nothing else fills that part of the page.
   (< (rnd g) 0.65)
   (imprint place (if self? pr (and names? pr)) form (and (not self?) pu)
            (if self? #f (and shop? sold?))
            (cond [self? (and shop? (rnd-choice g HOUSE-PLACES))]
                  [shop? (rnd-choice g SHOP-STREETS)]
                  [else #f])
            (and shop? (not self?) sign? (rnd-choice g SHOP-SIGNS))
            year (< (rnd g) 0.5))))

(define (initials name)
  (string-join (for/list ([part (in-list (string-split name))])
                 (format "~a." (substring part 0 1)))
               " "))

;; The imprint as one line of copy, in the shop's own grammar.
;;
;; Two things the transcripts settle that guesswork gets wrong. The address is
;; the *bookseller's*, not the printer's -- "Printed by N. O. for Roger
;; Iackson, dwelling in Fleetstreet neere to the Conduit" is Jackson's shop --
;; and "dwelling in" and "and are to be sold at his shop in" are two ways of
;; saying the same thing, which is why they come out twenty and twenty. An
;; address belongs to the printer only where there is no bookseller to own it:
;; "Printed by Nicholas Okes, dwelling neere Holborne bridge. 1609."
;;
;; And "Imprinted at London by X" is a place line and an imprint in one
;; sentence, not a place line with an imprint under it.
(define (imprint-line im)
  (define printer (imprint-printer im))
  (define named
    (and printer
         (if (eq? (imprint-printer-form im) 'initials)
             (initials printer)
             printer)))
  (define run-on? (string=? (imprint-place im) "Imprinted at London"))
  (define opening
    (cond
      [(and named (imprint-publisher im))
       (format "~a ~a for ~a" (if run-on? "by" "Printed by") named
               (imprint-publisher im))]
      [named (format "~a ~a" (if run-on? "by" "Printed by") named)]
      [else (format "~a ~a" (if run-on? "for" "Printed for")
                    (imprint-publisher im))]))
  (define where
    (cond
      [(not (imprint-street im)) ""]
      [(not (imprint-publisher im)) (format ", dwelling ~a" (imprint-street im))]
      [(imprint-shop im)
       (format ", and are to be sold at his shop in ~a~a"
               (imprint-street im)
               (if (imprint-sign im)
                   (format ", at the signe of ~a" (imprint-sign im))
                   ""))]
      [else
       (format ", dwelling in ~a~a" (imprint-street im)
               (if (imprint-sign im)
                   (format " at the signe of ~a" (imprint-sign im))
                   ""))]))
  (string-append opening where "."
                 (if (imprint-spaced-date? im)
                     ""
                     (string-append
                      " " (period-year-form (imprint-year im) #f)))))

;; The date, where it is set apart.
;;
;; A date whose figures are spaced -- 1 6 0 5, 16 0 5 -- is a date quadded out
;; to fill a line, which is why it is spaced at all; so it goes on a line of
;; its own, as it does in the transcripts that read "... at the ſigne of the
;; Crowne. | 16 0 5". A tight date runs on at the end of the imprint. The rule
;; is a rule of thumb rather than a finding: Blayney has both spaced dates run
;; on ("S. Auſtins Gate. 1 6 08.") and tight ones set apart. What it is really
;; for is that a compositor did not divide a date between two lines, and
;; leaving the spaced figures inside the imprint let this program do so.
(define (imprint-date-line im)
  (and (imprint-spaced-date? im)
       (period-year-form (imprint-year im) #t)))

;; ---------------------------------------------------------------------------
;; As copy
;; ---------------------------------------------------------------------------
;; The title-page is handed back as copy units, not as a page, for two
;; reasons. It must go through the same compositor as everything else, so that
;; its spelling, its long s and its accidents are his and not the program's;
;; and it must be settable at a moment of the run's choosing, because Blayney
;; found the Lear title-page was set first and printed last.

(define (unit kind text index [style #f]) (copy-unit kind text index style))

(define (titlepage-units tp [start 0])
  (define im (titlepage-imp tp))
  (define lines
    (append
     (list (list 'heading (titlepage-title tp) #f))
     (if (titlepage-author tp)
         (list (list 'centred (titlepage-author tp) #f))
         '())
     (for/list ([c (in-list (titlepage-claims tp))]) (list 'centred c #f))
     (if (titlepage-motto tp)
         (list (list 'centred (titlepage-motto tp) "italic"))
         '())
     (if (titlepage-device tp) (list (list 'rule "" #f)) '())
     ;; "Imprinted at London by George Snowdon, for Clement Knight" is one
     ;; sentence and was set as one; the other forms put the place on a line
     ;; of its own above the imprint.
     (if (string=? (imprint-place im) "Imprinted at London")
         (list (list 'centred (format "~a ~a" (imprint-place im) (imprint-line im)) #f))
         (list (list 'centred (imprint-place im) #f)
               (list 'centred (imprint-line im) #f)))
     (if (imprint-date-line im)
         (list (list 'centred (imprint-date-line im) #f))
         '())))
  (for/list ([l (in-list lines)] [i (in-naturals start)])
    (unit (first l) (second l) i (third l))))

;; What a bibliographer would write down, with | for the line-ends of the
;; setting -- the form Blayney's checklist uses.
(define (titlepage-transcript tp)
  (define im (titlepage-imp tp))
  (string-join
   (filter values
           (append
            (list (titlepage-title tp) (titlepage-author tp))
            (titlepage-claims tp)
            (list (titlepage-motto tp)
                  (and (titlepage-device tp) "[Device]"))
            (if (string=? (imprint-place im) "Imprinted at London")
                (list (format "~a ~a" (imprint-place im) (imprint-line im)))
                (list (imprint-place im) (imprint-line im)))
            (if (imprint-date-line im) (list (imprint-date-line im)) '())))
   " | "))

(module+ test
  (require rackunit)

  ;; The date, quadded out and not.
  (check-equal? (period-year-form 1608 #f) "1608.")
  (check-equal? (period-year-form 1608 #t) "1 6 0 8.")

  (check-equal? (initials "Nicholas Okes") "N. O.")
  (check-equal? (initials "George Snowdon") "G. S.")

  ;; Every imprint the generator can produce has a place, a publisher and a
  ;; date, in that order, and reads as one of the shop's own formulae.
  (for ([seed (in-range 60)])
    (define tp (make-titlepage #:title "THE TRAGEDIE OF HAMLET"
                               #:author "By William Shakespeare"
                               #:year 1608
                               #:rng (make-rng seed)))
    (define t (titlepage-transcript tp))
    (check-true (regexp-match? #px"(?:LONDON|London)" t)
                (format "seed ~a has a place line: ~a" seed t))
    (check-true (regexp-match? #px"(?:Printed|Imprinted)(?: at London)? (?:by|for) [A-Z]" t)
                (format "seed ~a has an imprint: ~a" seed t))
    (check-true (regexp-match? #px"1 ?6 ?0 ?8\\." t)
                (format "seed ~a is dated: ~a" seed t))
    ;; A shop clause, when there is one, always says where.
    (when (regexp-match? #px"are to be sold" t)
      (check-true (regexp-match? #px"at his shop in \\S" t)
                  (format "seed ~a says where the shop is: ~a" seed t))))

  ;; The measured shares come out. 200 draws is enough for a 72% rate to sit
  ;; clear of a half and of unanimity, which is all that is claimed.
  (define named
    (for/sum ([seed (in-range 200)])
      (if (imprint-printer (titlepage-imp
                            (make-titlepage #:title "T" #:rng (make-rng seed))))
          1 0)))
  (check-true (< 120 named 168)
              (format "the printer is named on about 72% of them, not ~a of 200"
                      named))

  ;; Copy, not a page: the units go through the compositor like anything else,
  ;; and the title is a head while the imprint is a centred line.
  (define tp (make-titlepage #:title "THE HISTORY OF KING LEAR"
                             #:author "By M. William Shak-speare"
                             #:claims '("As it was played before the Kings Maiestie")
                             #:year 1608 #:rng (make-rng 3)))
  (define us (titlepage-units tp))
  (check-equal? (copy-unit-kind (first us)) 'heading)
  (check-equal? (copy-unit-text (first us)) "THE HISTORY OF KING LEAR")
  (check-true (for/or ([u (in-list us)])
                (and (eq? (copy-unit-kind u) 'centred)
                     (regexp-match? #px"^(?:LONDON|AT LONDON|Imprinted at London)"
                                    (copy-unit-text u))))
              "the place line is a centred line of its own")
  (check-true (for/or ([u (in-list us)])
                (regexp-match? #px"1 ?6 ?0 ?8" (copy-unit-text u)))
              "the date is in the copy")
  ;; indices run on from where they are told to
  (check-equal? (map copy-unit-index (titlepage-units tp 40))
                (for/list ([i (in-range 40 (+ 40 (length us)))]) i))

  ;; A motto is set in italic, and nothing else is.
  (define mt (make-titlepage #:title "T" #:motto "Iames. 4. 3." #:rng (make-rng 9)))
  (check-equal? (for/list ([u (in-list (titlepage-units mt))]
                           #:when (equal? (copy-unit-speaker u) "italic"))
                  (copy-unit-text u))
                '("Iames. 4. 3.")))
