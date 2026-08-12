#lang racket/base
;;; Type-body widths for a schematic seventeenth-century roman fount.
;;;
;;; In hand composition nothing is elastic. Every sort stands on a body of
;;; fixed width, and a line of type is *right* only when the sum of those
;;; bodies plus the spaces between them exactly fills the measure -- tight
;;; enough to lift, loose enough not to buckle. Everything the compositor does
;;; to a text at the end of a line follows from that one mechanical fact, so
;;; the widths have to be modelled before anything else.
;;;
;;; Widths are integers in units of 1/840 em, so that the common spaces divide
;;; evenly. Racket's exact rationals make the divisions honest: (u 1/3) is
;;; exactly 280, not 279.99999.
;;;
;;; 840 rather than 120, and the number is chosen to divide by seven. 120
;;; carries halves, thirds, quarters, fifths and eighths, which suits the
;;; ladder below -- a ladder that is Jacobi's of 1890. Moxon's fount has four
;;; spaces, not six, and his thin is "the seventh part of the Body"
;;; (Dictionary, p. 353), which 120 cannot express at all. 840 is the least
;;; number carrying halves, thirds, quarters, fifths, sixths, sevenths and
;;; eighths together, so Jacobi's ladder and Moxon's can both be stated exactly
;;; and compared without either being rounded to suit the other. Roadmap §4.

(require racket/math racket/list)

(provide UNITS-PER-EM
         EM-QUAD EN-QUAD THICK THIN
         SPACE-LADDER NORMAL-SPACE FINEST-SPACE
         width-of width-of-word ems describe-space space-bodies
         AVERAGE-LOWERCASE measure-in-characters)

(define UNITS-PER-EM 840)

(define (u em) (exact-round (* em UNITS-PER-EM)))

;; Spaces and quads, as they lie in the lower case.
(define EM-QUAD (u 1))
(define EN-QUAD (u 1/2))
;; Moxon's, not Jacobi's. "Besides Letters, there is to be Cast for a perfect
;; Fount (properly a Fund) Spaces Thick and Thin, n Quadrats, m Quadrats and
;; Quadrats" (p. 170) -- four bodies, where the six-rung ladder that stood here
;; is Jacobi's of 1890 and was being used for 1600. Davis & Carter: "Moxon knows
;; of only two spaces: the thick and the thin ... The present convention for the
;; thickness of spaces (thick, 3 to the em; mid, 4 to the em; thin, 5 to the em)
;; is of uncertain age", Jacobi giving them their present value.
;;
;; The thin is "the seventh part of the Body; though Founders make them
;; indifferently Thicker or Thinner" (Dictionary, p. 353). The thick is "one
;; quarter so thick as the Body is high" (p. 103); Davis & Carter derive a sixth
;; from his casting instructions, so Moxon supports 1/4 or 1/6 and the 1/3 that
;; stood here is outside both.
;;
;; Blayney's ruler agrees with his prose. Ten 20-line samples off _Lear_ give
;; about 9% internal space by area; this program gave 13.2% at a third of an em
;; and Moxon's quarter predicts 10.2%. Two sources, two methods, two centuries
;; apart, against the constant that was here. Roadmap §4 and §4a.
(define THICK (u 1/4))
(define THIN  (u 1/7))

;; Coarsest to finest; the compositor works down this list when a line will
;; not justify.
(define SPACE-LADDER (list EM-QUAD EN-QUAD THICK THIN))

;; The finest thing in the case, and a role rather than a body.
;;
;; `justify' works down the ladder and gives up here: below this width there is
;; no piece of metal to make the white out of, so the line will not go and the
;; compositor must respell, divide a word, or turn it over. Ten places in
;; `compositor.rkt' and one in `imposition.rkt' meant exactly that and said
;; HAIR, which was true only so long as the hair space was the last rung.
;;
;; Moxon's fount has no hair space at all -- four bodies, thick and thin and the
;; two quadrats, his thin being "the seventh part of the Body" -- so the floor
;; there is the thin at 1/7, near Jacobi's hair at 1/8 and not the same thing.
;; Naming the role separately is what lets the ladder change without ten call
;; sites quietly coming to mean something else. Roadmap §4.
(define FINEST-SPACE (last SPACE-LADDER))

;; The pieces of metal that make up a gap of this width, largest first. There
;; is no space narrower than a hair, so a width the ladder cannot reach leaves
;; a remainder -- under a tenth of an em, taken up by the pressure of the
;; lock-up as it was in the chase.
(define (space-bodies units)
  (let loop ([left units] [bs SPACE-LADDER] [out '()])
    (cond
      [(or (<= left 0) (null? bs)) (reverse out)]
      [(> (car bs) left) (loop left (cdr bs) out)]
      [else (loop (- left (car bs)) bs (cons (car bs) out))])))

(define space-names
  (hash EM-QUAD "em quad"
        EN-QUAD "en quad"
        THICK   "thick space"
        THIN    "thin space"))

;; The normal word space of the house. Wider and the line is loose; narrower
;; and it is squeezed.
(define NORMAL-SPACE THICK)

;; Widths in ems: an old-face roman, rounded. Exactness is beside the point,
;; proportion is not.
(define em-widths
  (hash
   ;; lower case
   #\a 0.45 #\b 0.50 #\c 0.44 #\d 0.50 #\e 0.44 #\f 0.33
   #\g 0.45 #\h 0.50 #\i 0.28 #\j 0.28 #\k 0.48 #\l 0.28
   #\m 0.78 #\n 0.50 #\o 0.50 #\p 0.50 #\q 0.50 #\r 0.35
   #\s 0.39 #\t 0.33 #\u 0.50 #\v 0.45 #\w 0.70 #\x 0.45
   #\y 0.45 #\z 0.40
   ;; the long s and the ligatures that live with it
   #\ſ 0.30
   #\ﬀ 0.60 #\ﬁ 0.55 #\ﬂ 0.55 #\ﬃ 0.85 #\ﬄ 0.85
   ;; capitals
   #\A 0.68 #\B 0.62 #\C 0.67 #\D 0.70 #\E 0.60 #\F 0.55
   #\G 0.72 #\H 0.72 #\I 0.33 #\J 0.40 #\K 0.70 #\L 0.55
   #\M 0.89 #\N 0.72 #\O 0.74 #\P 0.58 #\Q 0.74 #\R 0.64
   #\S 0.55 #\T 0.61 #\U 0.72 #\V 0.68 #\W 0.95 #\X 0.68
   #\Y 0.65 #\Z 0.58
   ;; The figures did not range, and saying they did was reading a later
   ;; convention back into the wrong century. Ranging (tabular) figures, all
   ;; cast on one body so columns would line up, belong to the eighteenth
   ;; century and after. A sixteenth-century fount had old-style figures of
   ;; differing widths, and two independent sources say so: Blokland's calliper
   ;; measurements of Garamont / Van den Keere's Moyen Canon Romain at the
   ;; Museum Plantin-Moretus (appendix a5.5), where the ten figures run from
   ;; 3.37 to 5.53 mm -- a spread of 64% -- and Marini's IM Fell English, a
   ;; faithful digitisation of the seventeenth-century Oxford types, whose
   ;; figures are old-style and plainly of differing widths.
   ;;
   ;; His millimetres are scaled so the mean stays exactly 0.50, the en body
   ;; these used to sit on. So the setting density is unchanged and what has
   ;; been adopted is the shape of the distribution and not its size -- which
   ;; matters, because he measured a display fount and before Benton's
   ;; pantograph every size was cut separately. The 7 being the widest of them
   ;; is his measurement, not a slip.
   #\0 0.59 #\1 0.39 #\2 0.48 #\3 0.43 #\4 0.51
   #\5 0.42 #\6 0.54 #\7 0.65 #\8 0.50 #\9 0.49
   ;; points and marks
   #\. 0.28 #\, 0.28 #\; 0.28 #\: 0.28 #\! 0.30 #\? 0.44
   #\' 0.20 #\’ 0.20 #\- 0.33 #\— 1.00
   #\( 0.33 #\) 0.33 #\[ 0.33 #\] 0.33
   #\& 0.72 #\¶ 0.50 #\§ 0.50 #\* 0.44 #\/ 0.28
   ;; vowels with the tilde, standing for a following nasal
   #\ā 0.45 #\ē 0.44 #\ī 0.28 #\ō 0.50 #\ū 0.50
   #\Ā 0.68 #\Ē 0.60 #\Ī 0.33 #\Ō 0.74 #\Ū 0.72
   ;; superior letters used in the scribal abbreviations y-e, w-ch
   #\ᵉ 0.24 #\ᵗ 0.20 #\ᶜ 0.24 #\ʰ 0.26 #\ˢ 0.22 #\ʳ 0.22
   ;; The foot of a sort set face down -- the compositor's placeholder for a
   ;; letter he has not got (typecase.rkt). It stands on an en body like any
   ;; other spare sort, and the width is stated here rather than left to fall
   ;; through to the default, because the character has to be drawn at exactly
   ;; this width and both ends of that have to agree. It had fallen through,
   ;; and the facsimile drew U+25AE at whatever the rendering face gave it --
   ;; 0.97 em in Times, nearly double the body -- which was the single largest
   ;; cause of type printing outside the measure.
   #\▮ 0.50))

(define widths
  (for/hash ([(ch em) (in-hash em-widths)])
    (values ch (u em))))

;; Anything not in the bill stands on an en body.
(define DEFAULT-WIDTH EN-QUAD)

(define (width-of ch) (hash-ref widths ch DEFAULT-WIDTH))

(define (width-of-word s)
  (for/sum ([ch (in-string s)]) (width-of ch)))

(define (ems units) (exact->inexact (/ units UNITS-PER-EM)))

;; Name the nearest space in the case, for the record of composition.
(define (describe-space units)
  (cond
    [(<= units 0) "no space"]
    [else
     (define best
       (for/fold ([best (car SPACE-LADDER)]) ([s (in-list SPACE-LADDER)])
         (if (< (abs (- s units)) (abs (- best units))) s best)))
     (cond
       [(<= (abs (- best units)) 2) (hash-ref space-names best)]
       [(> units EM-QUAD) (format "~a em (quads)" (real->decimal-string (ems units) 2))]
       [else (format "~a em" (real->decimal-string (ems units) 2))])]))

;; Mean width of a lower-case sort, used only to turn a measure in ems into a
;; plausible number of characters for the plain-text facsimile.
(define AVERAGE-LOWERCASE
  (/ (for/sum ([ch (in-string "abcdefghijklmnopqrstuvwxyz")])
       (hash-ref em-widths ch))
     26.0))

(define (measure-in-characters measure-units)
  (exact-round (/ (ems measure-units) (+ AVERAGE-LOWERCASE 0.06))))

(module+ test
  (require rackunit)
  ;; The spaces must divide the em exactly; this is the whole reason for
  ;; working in 1/120 em rather than in floating point.
  ;;
  ;; Asserted as the property, not as six literals. It was six literals, and
  ;; they had to be rewritten to change the unit -- which turns a test of the
  ;; arithmetic into a test of one arbitrary denominator, and would have to be
  ;; rewritten again for the next one.
  (check-equal? EM-QUAD UNITS-PER-EM)
  (check-equal? (* 2 EN-QUAD) EM-QUAD)
  (check-equal? (* 4 THICK) EM-QUAD "Moxon's thick is a quarter of the em")
  (check-equal? (* 7 THIN) EM-QUAD "and his thin a seventh")
  (check-equal? (length SPACE-LADDER) 4 "four bodies, as his fount has")
  ;; And the unit must carry a seventh, which 120 could not. Moxon's thin is
  ;; "the seventh part of the Body", so a unit unable to express one cannot
  ;; state his fount at all, let alone compare it with the one in use.
  (check-equal? (* 7 (quotient UNITS-PER-EM 7)) UNITS-PER-EM
                "the em divides by seven, so Moxon's thin is expressible")
  (check-equal? (* 6 (quotient UNITS-PER-EM 6)) UNITS-PER-EM
                "and by six, for Davis & Carter's reading of his thick")
  ;; A long s is narrower than a short one -- which is why the conventions of
  ;; the case have to be applied before any width is computed.
  (check-true (< (width-of #\ſ) (width-of #\s)))
  (check-equal? (width-of-word "") 0)
  ;; The figures do not range: they are old-style and of differing widths, and
  ;; a test that only checked their mean would pass on the uniform en bodies
  ;; this replaced. Both facts are asserted.
  (let ([figs (for/list ([c (in-string "0123456789")]) (width-of c))])
    (check-true (> (- (apply max figs) (apply min figs)) (u 0.2))
                "the figures are not all one width")
    (check-= (/ (apply + figs) 10.0) EN-QUAD 0.5
             "but they still average the en body they used to sit on"))
  (check-true (> (measure-in-characters (* 21 UNITS-PER-EM)) 30))
  (check-equal? (describe-space THICK) "thick space"))
