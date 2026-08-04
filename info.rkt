#lang info

(define collection "handpress")
(define version "1.0")
(define pkg-desc
  "A simulation of hand-press composition, and of the New Bibliography run back over the result")

(define deps '("base" "rackunit-lib"))
(define build-deps '("scribble-lib" "racket-doc" "rackunit-lib"))

(define scribblings '(("scribblings/handpress.scrbl" ())))
