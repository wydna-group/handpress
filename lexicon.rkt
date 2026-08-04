#lang racket/base

;;; The attestation lexicon: which spellings actually occur, and how often.
;;;
;;; This module exists because the program had no dictionary. Its spelling
;;; devices were generative rules -- strip a terminal e, double a consonant,
;;; add an e to fill out a line -- with nothing checking the result against a
;;; real book. Counted against the 24,000 words of Q1600 and F1623 in
;;; samples/ado, nine of the long forms it could produce (theere, wheere,
;;; manne, somme, welle, wille, himme, themme, whenne) do not occur once. They
;;; are not early modern spellings. They are what a rule produces when nothing
;;; validates it.
;;;
;;; So the direction of authority is inverted. The lexicon says what forms
;;; exist; the rules only choose among them. A device that can select but not
;;; invent cannot fabricate a spelling, however crowded the line.
;;;
;;; Two things are wanted of it, and they are different operations:
;;;
;;;   normalising  a rare copy form is moved toward the form the trade
;;;                generally used -- frequency decides
;;;   fitting      a longer or shorter form is wanted for the measure --
;;;                width decides, among the forms frequency allows
;;;
;;; Build a lexicon with tools/build-lexicon.py. The one bundled here is small,
;;; being drawn from the two Much Ado texts alone; it is enough to demonstrate
;;; the mechanism and too thin to be relied on. Point the builder at a slice of
;;; EEBO-TCP for a real one.

(require racket/list racket/string racket/runtime-path)

(provide (struct-out lexicon)
         load-lexicon current-lexicon
         attested? frequency variants-of
         commonest-form longer-forms-of shorter-forms-of
         lexicon-skeleton)

(define-runtime-path default-lexicon-file "samples/ado-lexicon.rktd")

;; `attested' maps a form to its count; `groups' maps a skeleton to the forms
;; sharing it, commonest first; `index' maps a form to its skeleton.
(struct lexicon (attested groups index source) #:transparent)

(define EMPTY (lexicon (hash) (hash) (hash) "none"))

;; The same reduction the builder applies, and it has to stay the same or the
;; index will not find its own groups. See tools/build-lexicon.py for why the
;; three-letter guard is there: without it `as' merges with `asse' and `at'
;; with `ate'.
(define (lexicon-skeleton w)
  (define s0 (string-downcase w))
  (define s1 (string-replace (string-replace s0 "v" "u") "j" "i"))
  (define collapsed
    (regexp-replace* #px"([a-z])\\1" s1 "\\1"))
  (define s2 (if (>= (string-length collapsed) 3) collapsed s1))
  (if (and (string-suffix? s2 "e") (>= (- (string-length s2) 1) 3))
      (substring s2 0 (sub1 (string-length s2)))
      s2))

(define (load-lexicon [path default-lexicon-file])
  (cond
    [(not (file-exists? path)) EMPTY]
    [else
     (define data (with-input-from-file path read))
     (define (section name)
       (cond [(assq name data) => cdr] [else '()]))
     (define attested
       (for/hash ([p (in-list (section 'attested))])
         (values (car p) (cdr p))))
     (define groups
       (for/hash ([g (in-list (section 'variants))])
         (values (car g) (cdr g))))
     (define index
       (for*/hash ([(k forms) (in-hash groups)] [f (in-list forms)])
         (values (car f) k)))
     (lexicon attested groups index (path->string path))]))

(define current-lexicon (make-parameter (load-lexicon)))

(define (attested? w [lx (current-lexicon)])
  (hash-has-key? (lexicon-attested lx) (string-downcase w)))

(define (frequency w [lx (current-lexicon)])
  (hash-ref (lexicon-attested lx) (string-downcase w) 0))

;; Every attested spelling of the same word, commonest first. The word itself
;; is included, so a caller can see where it stands among its fellows.
(define (variants-of w [lx (current-lexicon)])
  (define k (hash-ref (lexicon-index lx) (string-downcase w) #f))
  (if k (hash-ref (lexicon-groups lx) k '()) '()))

;; What the trade generally set for this word. This is the normalising move:
;; an odd copy spelling gives way to the common one.
(define (commonest-form w [lx (current-lexicon)])
  (define vs (variants-of w lx))
  (if (null? vs) #f (car (car vs))))

;; Attested spellings longer or shorter than the one in hand, for a line that
;; will not come out. Both return commonest first, so a compositor short of
;; room takes the likeliest form that helps rather than the most extravagant.
(define (longer-forms-of w [lx (current-lexicon)])
  (define n (string-length w))
  (for/list ([p (in-list (variants-of w lx))]
             #:when (> (string-length (car p)) n))
    (car p)))

(define (shorter-forms-of w [lx (current-lexicon)])
  (define n (string-length w))
  (for/list ([p (in-list (variants-of w lx))]
             #:when (< (string-length (car p)) n))
    (car p)))

(module+ test
  (require rackunit)

  (define lx (load-lexicon))

  ;; The bundled lexicon is small but must at least have loaded.
  (check-true (> (hash-count (lexicon-attested lx)) 1000)
              "the sample lexicon has forms in it")

  ;; The skeleton must group real variants and separate real words. The second
  ;; of those is the one that matters: a false merge hands the compositor a
  ;; different word, which is worse than leaving the spelling alone.
  (check-equal? (lexicon-skeleton "heere") (lexicon-skeleton "here"))
  (check-equal? (lexicon-skeleton "sinne") (lexicon-skeleton "sin"))
  (check-equal? (lexicon-skeleton "breake") (lexicon-skeleton "break"))
  (check-not-equal? (lexicon-skeleton "as") (lexicon-skeleton "asse"))
  (check-not-equal? (lexicon-skeleton "at") (lexicon-skeleton "ate"))

  ;; Forms the old rules could produce, and which do not exist.
  (for ([bad (in-list '("theere" "wheere" "manne" "somme" "welle"
                        "wille" "himme" "themme" "whenne"))])
    (check-false (attested? bad lx)
                 (format "~s is not an early modern spelling" bad)))

  ;; Forms they should produce, which do.
  (for ([good (in-list '("heere" "doe" "goe" "sinne" "beleeue" "downe"))])
    (check-true (attested? good lx) (format "~s is attested" good)))

  ;; Choosing among attested forms, in both directions.
  (check-not-false (member "heere" (longer-forms-of "here" lx)) "heere is longer")
  (check-not-false (member "here" (shorter-forms-of "heere" lx)) "here is shorter")
  (check-equal? (commonest-form "adoe" lx) "adoe" "the commoner of ado/adoe")

  ;; The grouping must not hand the compositor a different word. `her' and
  ;; `here' reduce to the same skeleton, and only the modern wordlist keeps
  ;; them apart -- which is why tools/build-lexicon.py wants one.
  (check-false (member "her" (map car (variants-of "here" lx)))
               "her is a different word from here, not a spelling of it"))
