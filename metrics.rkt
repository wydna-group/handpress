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
;;; Widths are integers in units of 1/120 em, so that the common spaces divide
;;; evenly. Racket's exact rationals make the divisions honest: (u 1/3) is
;;; exactly 40, not 39.99999.

(require racket/math)

(provide UNITS-PER-EM
         EM-QUAD EN-QUAD THICK MIDDLE THIN HAIR
         SPACE-LADDER NORMAL-SPACE
         width-of width-of-word ems describe-space space-bodies
         AVERAGE-LOWERCASE measure-in-characters)

(define UNITS-PER-EM 120)

(define (u em) (exact-round (* em UNITS-PER-EM)))

;; Spaces and quads, as they lie in the lower case.
(define EM-QUAD (u 1))
(define EN-QUAD (u 1/2))
(define THICK   (u 1/3))
(define MIDDLE  (u 1/4))
(define THIN    (u 1/5))
(define HAIR    (u 1/8))

;; Coarsest to finest; the compositor works down this list when a line will
;; not justify.
(define SPACE-LADDER (list EM-QUAD EN-QUAD THICK MIDDLE THIN HAIR))

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
        MIDDLE  "middle space"
        THIN    "thin space"
        HAIR    "hair space"))

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
   ;; figures were cast on an en body so that tables would range
   #\0 0.50 #\1 0.50 #\2 0.50 #\3 0.50 #\4 0.50
   #\5 0.50 #\6 0.50 #\7 0.50 #\8 0.50 #\9 0.50
   ;; points and marks
   #\. 0.28 #\, 0.28 #\; 0.28 #\: 0.28 #\! 0.30 #\? 0.44
   #\' 0.20 #\’ 0.20 #\- 0.33 #\— 1.00
   #\( 0.33 #\) 0.33 #\[ 0.33 #\] 0.33
   #\& 0.72 #\¶ 0.50 #\§ 0.50 #\* 0.44 #\/ 0.28
   ;; vowels with the tilde, standing for a following nasal
   #\ā 0.45 #\ē 0.44 #\ī 0.28 #\ō 0.50 #\ū 0.50
   #\Ā 0.68 #\Ē 0.60 #\Ī 0.33 #\Ō 0.74 #\Ū 0.72
   ;; superior letters used in the scribal abbreviations y-e, w-ch
   #\ᵉ 0.24 #\ᵗ 0.20 #\ᶜ 0.24 #\ʰ 0.26 #\ˢ 0.22 #\ʳ 0.22))

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
  (check-equal? EM-QUAD 120)
  (check-equal? EN-QUAD 60)
  (check-equal? THICK 40)
  (check-equal? MIDDLE 30)
  (check-equal? THIN 24)
  (check-equal? HAIR 15)
  (check-equal? (* 3 THICK) EM-QUAD)
  (check-equal? (* 2 EN-QUAD) EM-QUAD)
  ;; A long s is narrower than a short one -- which is why the conventions of
  ;; the case have to be applied before any width is computed.
  (check-true (< (width-of #\ſ) (width-of #\s)))
  (check-equal? (width-of-word "") 0)
  (check-true (> (measure-in-characters (* 21 UNITS-PER-EM)) 30))
  (check-equal? (describe-space THICK) "thick space"))
