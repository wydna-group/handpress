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

(require racket/list racket/string racket/set racket/runtime-path)

(provide (struct-out lexicon)
         load-lexicon current-lexicon
         attested? frequency variants-of
         commonest-form longer-forms-of shorter-forms-of
         lexicon-skeleton
         load-standard current-standard standard? sanctioned?
         modern-form current-word? undo-uv-ij)

(define-runtime-path default-lexicon-file "samples/ado-lexicon.rktd")
(define-runtime-path default-standard-file "samples/mulcaster.rktd")

;; `attested' maps a form to its count; `groups' maps a skeleton to the forms
;; sharing it, commonest first; `index' maps a form to its skeleton.
;; `modern' maps an old spelling to the one still current, where the corpus
;; records both. It is the same evidence read the other way: the group that
;; lets a compositor choose `heere' over `here' for a tight line also lets the
;; page be shown as `here' afterwards, which is all a modernised edition is.
;; `current' holds those attested forms that are still words today, which is
;; what lets u/v and i/j be undone. No positional rule can do it: in this
;; printing u and v are one letter, v written initially and u medially
;; whatever the sound, so `vpon' is `upon' while `very' is `very'. The only
;; way back is to try the swap and keep it if a real word comes out.
(struct lexicon (attested groups index modern current source) #:transparent)

(define EMPTY (lexicon (hash) (hash) (hash) (hash) (set) "none"))

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
     (define modern
       (for/hash ([p (in-list (section 'modern))])
         (values (car p) (cdr p))))
     (define current
       (for/set ([w (in-list (section 'current))] #:when (string? w))
         w))
     (lexicon attested groups index modern current (path->string path))]))

(define current-lexicon (make-parameter (load-lexicon)))

;; ---------------------------------------------------------------------------
;; The standard, as against the practice
;;
;; Mulcaster's General Table (1582) is the other half of the evidence, and it
;; answers a different question. The corpus records what compositors set; the
;; table records what the period held to be right. They disagree exactly where
;; one would hope: the table has `here' and `do' but not `heere', `doe',
;; `goe', `sinne', `downe' or `breake', every one of which the corpus attests
;; in quantity.
;;
;; So a form falls into one of three cases, and the third is the one that
;; matters:
;;
;;   in the table            the standard form, and what normalising aims at
;;   in the corpus only      a real variant, free for fitting a line
;;   in neither              not English -- never to be produced
;; ---------------------------------------------------------------------------

(define (load-standard [path default-standard-file])
  (cond
    [(not (file-exists? path)) (set)]
    [else
     (define data (with-input-from-file path read))
     (define words
       (cond [(and (list? data) (assq 'words data)) => (lambda (p) (cdr p))]
             [(list? data) data]
             [else '()]))
     (for/set ([w (in-list words)] #:when (string? w)) (string-downcase w))]))

(define current-standard (make-parameter (load-standard)))

(define (standard? w [st (current-standard)])
  (set-member? st (string-downcase w)))

;; Is there any warrant for this spelling at all?
;;
;; The gate the spelling devices pass through. A form the trade used or the
;; period approved may be set; one that appears in neither may not, because
;; the only thing that produced it was a rule.
(define (sanctioned? w [lx (current-lexicon)] [st (current-standard)])
  (or (attested? w lx) (standard? w st)))

(define (current-word? w [lx (current-lexicon)])
  (set-member? (lexicon-current lx) (string-downcase w)))

;; Undo the shared letters: v written for u, i written for j.
;;
;; Tried, not deduced. The swaps are applied and kept only if what comes out
;; is a word still in use, so `vpon' becomes `upon' and `iudge' becomes
;; `judge', while `very' and `it' are left alone because the swap would spoil
;; them. Where the corpus has never seen the word either way, nothing is done:
;; a guess here would be the same fault this program exists to remove.
(define (undo-uv-ij w [lx (current-lexicon)])
  (or (modern-form w lx) w))

;; The spelling still current, where the corpus records one. Case is carried
;; over from the form given, so `Heere' comes back `Here'.
(define (modern-form w [lx (current-lexicon)])
  (define hit (hash-ref (lexicon-modern lx) (string-downcase w) #f))
  (cond
    [(not hit) #f]
    [(and (> (string-length w) 0)
          (char-upper-case? (string-ref w 0))
          (> (string-length hit) 0))
     (string-append (string (char-upcase (string-ref hit 0)))
                    (substring hit 1))]
    [else hit]))

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
               "her is a different word from here, not a spelling of it")

  ;; Reading the setting the other way. u and v are one letter here, v written
  ;; initially and u medially whatever the sound, so no positional rule can
  ;; undo it -- the swap is tried and kept only if a word comes out.
  (parameterize ([current-lexicon lx])
    (check-equal? (undo-uv-ij "vpon") "upon")
    (check-equal? (undo-uv-ij "haue") "have")
    (check-equal? (undo-uv-ij "very") "very" "the swap would spoil this one")
    (check-equal? (undo-uv-ij "Vrsley") "Vrsley"
                  "a name the corpus does not know is left alone")
    ;; and the spelling itself, where both forms are recorded
    (check-equal? (modern-form "heere") "here")
    (check-equal? (modern-form "Heere") "Here" "case is carried over")
    (check-false (modern-form "here") "already current")))
