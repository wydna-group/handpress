#lang info

(define collection "handpress")
(define version "1.0")
(define pkg-desc
  "A simulation of hand-press composition, and of the New Bibliography run back over the result")
(define pkg-authors '("kantbot@hotmail.com"))
(define license 'MIT)

(define deps '("base"))
(define build-deps '("scribble-lib" "racket-doc" "rackunit-lib" "scribble-doc"))

(define scribblings '(("scribblings/handpress.scrbl" (multi-page))))

;; The Python helpers build the lexicon and fetch the corpus; they are not
;; Racket modules and nothing here requires them. Named so that `raco setup'
;; does not walk them looking for one.
(define compile-omit-paths '("tools"))
(define test-omit-paths '("tools"))
