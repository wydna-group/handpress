#lang racket/base
;;; Cancels: a leaf cut out and another pasted to the stub.
;;;
;;; WHY THIS MODULE DOES NOT MODEL THE REASON.
;;;
;;; The obvious objection to simulating cancels is that they happen for reasons
;;; outside any simulation -- the Privy Council took exception to Eastward Ho,
;;; and no amount of modelling a printing house will produce that. McKerrow
;;; gets there first and makes the decision for us:
;;;
;;;   "Into the purpose of these cancels we need not enter. There may have been
;;;   in the original print something so grossly incorrect that it was too much
;;;   for even the easy-going printer of the day -- or for the author; or, as
;;;   often in early times, there may have been something that the authorities
;;;   found objectionable. **The point at present is the aid that bibliography
;;;   gives us in detecting them.**" (p. 223)
;;;
;;; So the cause is a parameter and the trace is a simulation. That is not a
;;; retreat: the trace is the whole of what a bibliographer has, and it is the
;;; only part that can be got right or wrong.
;;;
;;; THE MECHANISM, which is fully modelled.
;;;
;;;   "As a rule, when it was desired to cancel a leaf, this was cut out,
;;;   leaving a stub of paper to which the new leaf could be pasted." (p. 223)
;;;
;;; The replacement is printed wherever there is room, and the room is the
;;; white paper at the end of a sheet -- the same economy that puts the
;;; preliminaries there. McKerrow: "there is always a possibility that spare
;;; leaves at the end of a book were used to print matter that was to be bound
;;; elsewhere in it, **such as titles or cancels**" (p. 156). Gaskell has the
;;; instruction in so many words, from Rousseau's publisher Marc-Michel Rey,
;;; who "wrote to encourage the author to use up the blank leaves of final
;;; sheets for printing cancels".
;;;
;;; THE DETECTION, which is what the analysis half has to earn. McKerrow's own
;;; checklist (p. 224) -- "a cancel should always be suspected if":
;;;
;;;   1. the type or manner of setting, of the headline, pagination, signature
;;;      or text, differs from the rest of the book
;;;   2. there is a larger or smaller number of lines to the page, or the
;;;      lines are longer or shorter
;;;   3. the leaf is signed where leaves in similar positions are not -- "in an
;;;      octavo in which as a rule only the first four or five leaves of each
;;;      gathering were signed we found one signed F7, we might at once guess
;;;      that it was a cancel"
;;;   4. the paper appears to be different
;;;   5. a volume- or part-signature occurs on a leaf other than the first of a
;;;      gathering
;;;   6. in books printed with press figures, two different figures in what
;;;      should be the same forme
;;;
;;; Five of the six are modelled here. The fourth is paper, and paper is not
;;; modelled at all yet -- see the watermark entry in the roadmap, and Bowers's
;;; use of exactly this test to prove the cut-out preliminaries of Sandys's
;;; Ovid.
;;;
;;; AND THE COUNSEL OF CAUTION, from Bowers: "It may be taken as an axiom that
;;; no blank not interrupting continuous text would be torn by the printer for
;;; excision." A cancel is a deliberate act on a printed leaf. Blanks stay.

(require racket/list racket/string "rng.rkt")

(provide (struct-out cancel) (struct-out cancel-plan)
         plan-cancels cancel-cause-label mckerrow-signs cancel-note
         CANCEL-CAUSES EXTERNAL-CAUSES)

;; `at' is the signature of the leaf cut out (the cancellandum); `sheet' the
;; gathering the replacement (the cancellans) was printed in; `signs' the
;; marks of McKerrow's checklist that this particular cancel would show.
(struct cancel (at cause detail sheet conjugate? signs) #:transparent)

(struct cancel-plan (cancels notes) #:transparent)

;; ---------------------------------------------------------------------------
;; The three causes, and what each of them is worth
;; ---------------------------------------------------------------------------
;; Only the first is simulated in the strong sense -- the program made the
;; error itself, knows exactly what it was, and knows the corrector missed it.
;; The second is mechanical. The third is a number the user supplies, and is
;; labelled as such wherever it appears.
(define CANCEL-CAUSES '(error imprint external))

(define (cancel-cause-label c)
  (case c
    [(error) "an error found after the forme was printed off"]
    [(imprint) "a change in the imprint"]
    [(external) "a cause outside this simulation"]
    [else (format "~a" c)]))

;; What an external cancel is *for*, offered only as a label on a leaf the
;; user asked for. The program is not modelling any of these; it is naming
;; the kind of thing McKerrow means by "something that the authorities found
;; objectionable", so that a report does not have to pretend the leaf was
;; cancelled for a reason it can account for.
(define EXTERNAL-CAUSES
  '("matter the authorities found objectionable"
    "a dedication withdrawn or transferred"
    "a passage the author thought better of"
    "a patron's name altered"))

;; ---------------------------------------------------------------------------
;; The signs a cancel leaves
;; ---------------------------------------------------------------------------
;; McKerrow's checklist, as the properties of a particular cancellans. Which
;; of them show depends on how the leaf was reset and where it was printed,
;; and the point of computing them here rather than describing them in prose
;; is that the analysis half can then be scored on finding them.
(define (mckerrow-signs g #:in-text? [in-text? #t] #:cut-from [sheet #f])
  (define signs '())
  (define (add! s) (set! signs (cons s signs)))
  ;; 1. The setting differs. A leaf reset weeks later, from standing copy, by
  ;;    whoever was free, almost always shows it somewhere.
  (when (< (rnd g) 0.8) (add! 'setting))
  ;; 2. The depth differs. A compositor resetting one page to fit an existing
  ;;    opening is working to a target he did not set himself.
  (when (< (rnd g) 0.45) (add! 'depth))
  ;; 3. Signed where its fellows are not, which is the surest of them: the
  ;;    signature is there to tell the binder where the leaf goes, and on a
  ;;    cancel that is the whole point -- McKerrow, p. 93, the signature "may
  ;;    also serve, when found on a cancel leaf, to indicate where this leaf is
  ;;    to be placed, or for which original leaf it is to be substituted".
  (when (< (rnd g) 0.55) (add! 'anomalous-signature))
  ;; 5. A part-signature away from the first leaf of a gathering, which
  ;;    McKerrow says makes the leaf "almost certainly a cancel".
  (when (< (rnd g) 0.12) (add! 'part-signature))
  ;; 6. Press figures disagreeing within a forme. Rare here because press
  ;;    figures belong to the later hand press, but the mechanism is the same.
  (when (< (rnd g) 0.1) (add! 'press-figure))
  ;; 4 is the paper, and this program has none.
  (reverse signs))

(define SIGN-LABELS
  (hash 'setting "the setting of the headline, signature or text differs from the rest of the book"
        'depth "the page has a different number of lines, or the measure differs"
        'anomalous-signature "the leaf is signed where its fellows in that position are not"
        'part-signature "a part-signature stands on a leaf other than the first of its gathering"
        'press-figure "two press figures in what should be one forme"))

;; ---------------------------------------------------------------------------
;; Choosing the leaves
;; ---------------------------------------------------------------------------

;; Where the replacements can be printed. A cancellans is a leaf, and a leaf
;; has to come off a sheet: either the white paper left at the end of a
;; gathering, or a half-sheet worked for the purpose.
(define (where-printed g white-leaves)
  (if (pair? white-leaves)
      (cons 'spare (car white-leaves))
      (cons 'half-sheet #f)))

;; Plan the cancels for a book.
;;
;; `leaves' is the list of (signature . printed?) for every leaf, in order;
;; `errors' the readings that survived proof-correction, as (signature .
;; description), which is the endogenous cause and needs nothing invented;
;; `white' the signatures of leaves left white at the ends of gatherings, which
;; is where the replacements are printed.
(define (plan-cancels leaves
                      #:errors [errors '()]
                      #:white [white '()]
                      #:rate [rate 0.0]
                      #:external [external 0]
                      #:imprint-change? [imprint? #f]
                      #:title-leaf [title-leaf #f]
                      #:rng [g (make-rng 1)])
  (define printed (for/list ([l (in-list leaves)] #:when (cdr l)) (car l)))
  (define spare (box white))
  (define (take-spare!)
    (define w (unbox spare))
    (cond [(pair? w) (set-box! spare (cdr w)) (car w)] [else #f]))

  ;; Not every surviving error is worth cutting a leaf out for. Gaskell's
  ;; counter-example is a warning against assuming they had to be grave --
  ;; Baskerville's four-volume Ariosto of 1773 had sixty-six cancelled leaves,
  ;; "most of them correcting no more than a single letter" -- so this is a
  ;; rate rather than a severity test, and the rate is the user's.
  ;;
  ;; **The rate is per LEAF, not per error**, and the difference is the whole
  ;; of this comment. It used to be drawn once for every surviving error, which
  ;; is defensible on a quarto with a few dozen of them and absurd on a book
  ;; with thousands: the First Folio came out with 349 of its 511 leaves
  ;; cancelled, two in three, where the real Folio has essentially one famous
  ;; cancel. A parameter whose meaning changes with the length of the book is
  ;; not a parameter, and no reader of the flag could have guessed that 0.15
  ;; meant "nearly every leaf" here and "one leaf in eight" on a pamphlet.
  ;;
  ;; So: at most one cancel per leaf, drawn at `rate' among the leaves that
  ;; carry a surviving error at all. Cancelling a leaf replaces the whole leaf,
  ;; so a second draw on the same leaf could never have meant anything anyway.
  (define by-leaf (make-hash))
  (for ([e (in-list errors)])
    (unless (hash-has-key? by-leaf (car e)) (hash-set! by-leaf (car e) e)))
  (define from-errors
    (for/list ([leaf (in-list (sort (hash-keys by-leaf) string<?))]
               #:when (< (rnd g) rate))
      (define e (hash-ref by-leaf leaf))
      (define sheet (take-spare!))
      (cancel (car e) 'error (cdr e) sheet (and sheet #t) (mckerrow-signs g))))

  ;; A change of imprint: the same setting with one line altered, which is why
  ;; a cancel title is so much commoner than any other kind.
  (define from-imprint
    (cond
      [(and imprint? title-leaf)
       (list (cancel title-leaf 'imprint
                     "the bookseller's name altered in the imprint"
                     (take-spare!) #f (mckerrow-signs g)))]
      [else '()]))

  (define from-outside
    (for/list ([i (in-range external)])
      (define at (if (pair? printed) (rnd-choice g printed) "?"))
      (cancel at 'external (rnd-choice g EXTERNAL-CAUSES)
              (take-spare!) #f (mckerrow-signs g))))

  (define all (append from-imprint from-errors from-outside))
  (cancel-plan
   all
   (append
    (if (zero? external)
        '()
        (list (format "~a leaf~a ~a cancelled for a cause outside this simulation, because it was asked for. The program is not modelling why: McKerrow does not either — \"into the purpose of these cancels we need not enter\" (p. 223) — and a printing house cannot generate the Privy Council."
                      external (if (= 1 external) "" "s")
                      (if (= 1 external) "was" "were"))))
    (if (null? from-errors)
        '()
        (list (format "~a of them replace an error this program made itself and its corrector missed, which is the one cause that needs nothing invented: the run knows what the error was and knows the proof went by without it."
                      (length from-errors))))
    (if (for/or ([c (in-list all)]) (not (cancel-sheet c)))
        (list "Some replacements had no white paper to be printed on and cost a half-sheet of their own. That is the expensive case, and it is why a printer would rather find the room at the end of a gathering.")
        '()))))

;; What the report prints beside a cancel.
(define (cancel-note c)
  (string-append
   (format "~a cancelled — ~a (~a). " (cancel-at c) (cancel-detail c)
           (cancel-cause-label (cancel-cause c)))
   (if (cancel-sheet c)
       (format "The replacement was printed in the white paper of ~a" (cancel-sheet c))
       "The replacement cost a half-sheet of its own")
   ". The leaf was cut out, leaving a stub for the new one to be pasted to.\n"
   (if (null? (cancel-signs c))
       "        It shows none of McKerrow's marks, so nothing but the stub betrays it.\n"
       (apply string-append
              (for/list ([s (in-list (cancel-signs c))])
                (format "        · ~a\n" (hash-ref SIGN-LABELS s (lambda () (format "~a" s)))))))))

(module+ test
  (require rackunit)

  (define leaves (for/list ([i (in-range 40)])
                   (cons (format "~a~ar" (integer->char (+ 65 (quotient i 4)))
                                 (add1 (modulo i 4)))
                         #t)))

  ;; Nothing asked for, nothing invented.
  (define none (plan-cancels leaves #:rng (make-rng 1)))
  (check-equal? (cancel-plan-cancels none) '())
  (check-equal? (cancel-plan-notes none) '())

  ;; The endogenous cause: an error the program made and the corrector missed.
  ;; Nothing about it is supplied from outside.
  ;; Twenty errors, but on four leaves: `(modulo i 4)' puts five errors on each
  ;; of C1r-C4r. At rate 1.0 that is four cancels and not twenty, because a
  ;; cancel replaces the whole leaf and the second error on a leaf is mended by
  ;; the same act as the first.
  ;;
  ;; This check asserted 20 and so encoded the defect: the draw was made once
  ;; per error rather than once per leaf, which is defensible only while a book
  ;; has few enough errors that no leaf carries two. The First Folio carries
  ;; thousands, and came out with 349 of its 511 leaves cancelled.
  (define errs (for/list ([i 20]) (cons (format "C~ar" (add1 (modulo i 4)))
                                        "foul case: a turned n")))
  (define endo (plan-cancels leaves #:errors errs #:rate 1.0
                             #:white '("K4" "K3") #:rng (make-rng 2)))
  (check-equal? (length (cancel-plan-cancels endo)) 4
                "one cancel per leaf, however many errors stand on it")
  (check-equal? (length (remove-duplicates
                         (map cancel-at (cancel-plan-cancels endo))))
                (length (cancel-plan-cancels endo))
                "and no leaf is cancelled twice")
  (check-true (for/and ([c (in-list (cancel-plan-cancels endo))])
                (eq? (cancel-cause c) 'error)))
  ;; the first replacements go into the white paper, the rest cost a half-sheet
  (check-equal? (for/sum ([c (in-list (cancel-plan-cancels endo))])
                  (if (cancel-sheet c) 1 0))
                2)
  (check-true (for/or ([n (in-list (cancel-plan-notes endo))])
                (string-contains? n "cost a half-sheet")))

  ;; The external cause is admitted as a cause and named as unmodelled.
  (define ext (plan-cancels leaves #:external 2 #:rng (make-rng 3)))
  (check-equal? (length (cancel-plan-cancels ext)) 2)
  (check-true (for/and ([c (in-list (cancel-plan-cancels ext))])
                (eq? (cancel-cause c) 'external)))
  (check-true (for/or ([n (in-list (cancel-plan-notes ext))])
                (string-contains? n "outside this simulation")))
  (check-true (for/or ([n (in-list (cancel-plan-notes ext))])
                (string-contains? n "cannot generate the Privy Council")))

  ;; A cancel title, which is the commonest kind there is.
  (define imp (plan-cancels leaves #:imprint-change? #t #:title-leaf "*1r"
                            #:white '("K4") #:rng (make-rng 4)))
  (check-equal? (length (cancel-plan-cancels imp)) 1)
  (check-equal? (cancel-at (car (cancel-plan-cancels imp))) "*1r")
  (check-equal? (cancel-cause (car (cancel-plan-cancels imp))) 'imprint)
  (check-equal? (cancel-sheet (car (cancel-plan-cancels imp))) "K4")

  ;; Every one of McKerrow's five modelled marks can occur, and the sixth --
  ;; the paper -- deliberately cannot, because this program has no paper.
  (define seen
    (for*/fold ([s (hash)]) ([seed (in-range 80)])
      (for/fold ([s s]) ([sign (in-list (mckerrow-signs (make-rng seed)))])
        (hash-set s sign #t))))
  (for ([sign (in-list '(setting depth anomalous-signature part-signature press-figure))])
    (check-true (hash-ref seen sign #f) (format "~a occurs" sign)))
  (check-false (hash-ref seen 'paper #f)
               "the paper test is not claimed, because there is no paper to test")

  ;; The note says what was cut, why, where the replacement came from, and
  ;; what would betray it.
  (define note (cancel-note (car (cancel-plan-cancels imp))))
  (check-true (string-contains? note "*1r cancelled"))
  (check-true (string-contains? note "stub"))
  (check-true (string-contains? note "white paper of K4")))
