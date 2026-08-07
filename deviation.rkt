#lang racket/base

;;; Every way the printed page can depart from its copy, counted.
;;;
;;; The classification is not a list drawn up from reading; it is the shape of
;;; the process itself. A word passes through the house in stages, and this
;;; module records what each stage did to it:
;;;
;;;   copy      what the manuscript or printed exemplar said
;;;    |  the corrector marks up the copy         PREPARATION
;;;   read      what the compositor took it for
;;;    |  he misreads, or his eye slips           MISREADING
;;;   habit     what he would set left to himself
;;;    |  his own spelling preferences            HABIT
;;;   final     what the measure will allow
;;;    |  he lengthens or shortens to fit         FITTING
;;;   composed  what stands in the stick
;;;    |  the case betrays him                    ACCIDENT
;;;   printed   what the sheet shows
;;;    |  the reader mends some of it             CORRECTION
;;;
;;; Two further kinds are not properties of a word at all and are counted
;;; separately: what happens to a LINE (division, turning over, verse run on
;;; as prose) and what happens to a PAGE (crowding, spinning out, copy left
;;; out for want of room).
;;;
;;; The rates are observed, not configured. That distinction is the whole
;;; point of measuring them. A compositor does not decide to abbreviate three
;;; words in a thousand; he abbreviates when a line will not come out, and how
;;; often that happens depends on the measure he is setting to, the format, the
;;; accuracy of the casting off, and the words the author happened to use. Set
;;; the same copy in octavo instead of folio and every figure here moves,
;;; because a folio page holds four times the text of an octavo one and is cast
;;; off in quite different lengths.
;;;
;;; So this report says what a particular book turned out like. It is evidence
;;; about that run. Read across runs it shows which devices are forced by the
;;; measure and which are the man's own, which is the distinction Hinman warns
;;; cannot be made from a single book (i. 186-7).

(require racket/list racket/string racket/format racket/math
         "compositor.rkt" "book.rkt" "press.rkt" "imposition.rkt"
         "vocabulary.rkt"
         (only-in "typecase.rkt" substitution-only? substitution-phrase placeholder?)
         (only-in "orthography.rkt" strip-conventions))

(provide deviation-report deviation-counts word-deviation)

;; What happened to this one word, in the order it happened, so that a reader
;; hovering over it is told which stage of the process put it there. Returns
;; #f for a word that stands exactly as the copy had it.

;; The compositor went out and came back. His habit shortened `cōposed' to
;; `cōpos'd', the line then wanted filling and the ending was written out
;; again, so the form he set is the form he read -- and the note described a
;; journey with no destination:
;;
;;   habit: “cōposed” → “cōpos'd”; justification: “cōpos'd” → “cōposed”
;;
;; The page shows `cōpoſed', agreeing with the copy in every letter. There is
;; no evidence on it of either stage, and no bibliographer could recover one,
;; so the record must not assert what cannot be observed -- any more than it
;; may ring a u-for-v as an accident. Five words of one quarto did this, each
;; marked on the page and counted among the justifications.
;;
;; The simulation is left to do it: two passes over a word is what the model
;; is, the width the line ends at is real, and the outcome on paper is exactly
;; the outcome of never having contracted at all. It is the *reporting* that
;; was claiming more than the page holds.
(define (stages-cancel? w)
  (and (word-read w) (word-habit w) (word-final w)
       (not (string=? (word-read w) (word-habit w)))
       (string=? (word-read w) (word-final w))))

(provide stages-cancel?)

(module+ test
  (require rackunit (only-in "compositor.rkt" [word mk-word]))
  (define (w* read habit final)
    (mk-word read read habit final final final 0
             (list "justification: -ed written out for -'d") #f '() 'picked))
  (check-true (stages-cancel? (w* "composed" "compos'd" "composed"))
              "contracted, then written out again: the page shows the copy's form")
  (check-false (stages-cancel? (w* "composed" "compos'd" "compos'd"))
               "the contraction stood")
  (check-false (stages-cancel? (w* "composed" "composed" "composed"))
               "nothing happened at all")
  (check-false (word-deviation (w* "composed" "compos'd" "composed"))
               "and it is reported as no departure")
  (check-equal? (deviation-class (w* "composed" "compos'd" "composed")) ""
                "and nothing is coloured on the page")

  ;; A capital set V for U is the fount, not a corruption, and must not be
  ;; reported as copy X -> printed Y.
  ;; The conventions are applied on the way from `final' to the metal, so both
  ;; `composed' and `printed' carry them: setting them apart would exercise the
  ;; foul-case branch instead of the one under test.
  (define (set-as copy printed)
    (mk-word copy copy copy copy printed printed 0 '() #f '() 'picked))
  (check-regexp-match #rx"conventions of the case"
                      (word-deviation (set-as "PICTURE" "PICTVRE")))
  (check-regexp-match #rx"no capital U"
                      (word-deviation (set-as "PICTURE" "PICTVRE")))
  (check-regexp-match #rx"^copy" (word-deviation (set-as "PICTURE" "PICTORE"))
                      "but a letter that really differs still is"))

(define (word-deviation w)
  (define (d a b) (and a b (not (string=? a b))))
  ;; A divided word is not a corrupt one. Both halves carry the whole word as
  ;; their copy reading, so every comparison against `copy' reports a change
  ;; that never happened -- and the first version of this said `misread' over
  ;; every hyphen in the book. Division is a fact about the line, not the
  ;; reading, and it is named as such.
  (define divide-note
    (for/or ([c (in-list (word-causes w))])
      (and (regexp-match? #rx"divid" c)
           (format "division: ~a of “~a”"
                   (if (regexp-match? #rx"second half" c) "second half" "first half")
                   (word-copy w)))))
  ;; The devices arrive with their stage already on the front --
  ;; "justification: terminal -e added" -- so appending them after the
  ;; transformation note said "justification" twice in one tooltip, 242 times
  ;; in one book: `justification: "most" -> "moste"; justification: terminal -e
  ;; added'. The device belongs *inside* the note for its own stage, and only
  ;; the ones that match no stage are left to stand on their own.
  (define (devices-for stage)
    (for/list ([c (in-list (word-causes w))]
               #:when (string-prefix? c (string-append stage ": ")))
      (substring c (+ 2 (string-length stage)))))
  (define (staged stage note)
    (define ds (devices-for stage))
    (if (null? ds) note (format "~a (~a)" note (string-join ds ", "))))
  (define claimed
    (for*/list ([stage (in-list '("misreading" "habit" "justification"))]
                [d (in-list (devices-for stage))])
      (string-append stage ": " d)))
  (define notes
    (append
     (if divide-note (list divide-note) '())
     (if (and (not divide-note) (d (word-copy w) (word-read w)))
         (list (staged "misreading"
                       (format "misreading: copy “~a” → read “~a”"
                               (word-copy w) (word-read w))))
         '())
     (if (and (not (stages-cancel? w)) (d (word-read w) (word-habit w)))
         (list (staged "habit"
                       (format "habit: “~a” → “~a”" (word-read w) (word-habit w))))
         '())
     (if (and (not (stages-cancel? w)) (d (word-habit w) (word-final w)))
         (list (staged "justification"
                       (format "justification: “~a” → “~a”"
                               (word-habit w) (word-final w))))
         '())
     ;; A box that was empty is not a box that was foul. See
     ;; `substitution-only?': the reading is untouched, and calling it foul case
     ;; produced notes like `foul case: "officers" set for "officers"'.
     (if (d (word-composed w) (word-printed w))
         (list (cond
                 [(placeholder? (word-printed w))
                  (format "no sort to set “~a” with: a type laid face down to hold the place, to be put right at proof"
                          (word-composed w))]
                 [(substitution-only? (word-composed w) (word-printed w))
                  (substitution-phrase (word-composed w) (word-printed w))]
                 [else
                  (format "foul case: “~a” set for “~a”"
                          (word-printed w) (word-composed w))]))
         '())
     ;; the device that did it, in the compositor's own terms, where no stage
     ;; above has already named it
     (for/list ([c (in-list (word-causes w))]
                #:unless (or (regexp-match? #rx"divid" c) (member c claimed)))
       c)))
  (cond
    [(pair? notes) (string-join notes "; ")]
    ;; This branch is for a difference nothing above accounts for, so the
    ;; comparison has to have *all* the conventions taken off both sides --
    ;; u/v and i/j as well as the long s and the ligatures, since
    ;; `strip-conventions' does only the two that can be undone by rule. With
    ;; them left in, PICTVRE was reported as `copy "PICTURE" -> printed
    ;; "PICTVRE"', which reads like a corruption and is the fount doing exactly
    ;; what it should.
    [(and (not divide-note)
          (d (fold-conventions (word-copy w)) (fold-conventions (word-printed w))))
     (format "copy “~a” → printed “~a”" (word-copy w) (word-printed w))]
    [(d (word-copy w) (word-printed w))
     (conventions-shown (word-copy w) (word-printed w))]
    [else #f]))

;; Every convention folded away, so that two settings differing only by them
;; compare equal. Not a reading -- `haue' and `vertue' both fold to the same
;; shape as forms they are not -- which is why this is used only to ask whether
;; anything *else* differs, and never to recover a word.
(define (fold-conventions s)
  (regexp-replaces (strip-conventions s)
                   '((#rx"[uv]" "v") (#rx"[UV]" "V")
                     (#rx"[ij]" "i") (#rx"[IJ]" "I"))))

;; Name the conventions this word actually shows, rather than reciting all of
;; them at every word that shows any.
;;
;; This is much the commonest note in a book -- 1,468 words of one quarto, 61%
;; of every tooltip in it -- and it read "conventions of the house: long s, u
;; for v, i for j" on all of them, which tells a reader nothing whatever about
;; the word under the cursor. Two of the three cannot be seen by looking at the
;; printed form alone, since u, v, i and j all exist in both alphabets, so the
;; copy and the setting are compared and the direction named.
(define (conventions-shown copy printed)
  (define (either a b set) (and (memv a set) (memv b set) (not (char=? a b))))
  ;; The capitals are a separate rule and want a separate sentence: the lower
  ;; case sets v at the head and u within, but the capital V does duty for both
  ;; letters wherever it stands, so "v for u, at the head" would be wrong of
  ;; PICTVRE, where the U is medial.
  (define uv
    (for/or ([a (in-string copy)] [b (in-string printed)])
      (cond [(and (char=? a #\U) (char=? b #\V))
             "V for U, the fount having no capital U"]
            [(and (char=? a #\u) (char=? b #\v)) "v for u, at the head"]
            [(and (char=? a #\v) (char=? b #\u)) "u for v, within"]
            [(and (memv a '(#\u #\U)) (memv b '(#\v #\V))) "v for u"]
            [(and (memv a '(#\v #\V)) (memv b '(#\u #\U))) "u for v"]
            [else #f])))
  (define ij
    (for/or ([a (in-string copy)] [b (in-string printed)])
      (and (either a b '(#\i #\I #\j #\J)) "i doing duty for j")))
  (define parts
    (filter values
            (list (and (regexp-match? #rx"ſ" printed) "the long s")
                  (and (regexp-match? #px"[ﬀﬁﬂﬃﬄ]" printed) "a ligature")
                  uv ij)))
  (if (null? parts)
      "the conventions of the case"
      (string-append "the conventions of the case: " (string-join parts ", "))))

;; What kind of thing happened to this word: the one place the question is
;; answered.
;;
;; There were two of these, and they had drifted. The TEI's cond knew about
;; forced substitutions, places held for the proof and press variants; the one
;; that chose a colour for the page knew none of them, and tested divided-ness
;; before misreading where the other tested it after. So the same book came out
;; marked differently depending on which renderer drew it, and every category
;; added since had been added to one of them.
;;
;; `variant?' is whether the copies disagree here, which only a caller holding
;; the whole press run can know; a renderer working from a single made-up copy
;; passes #f and simply never sees that category.
;;
;; The order is the order of certainty. A hole left for the proof is the
;; plainest fact about a word and outranks everything, including the apparatus,
;; because such a word is corrected during the run by construction and would
;; otherwise be labelled by the correction rather than by the hole. Then the
;; errors of the case, then the facts about the line, then the compositor's own
;; choices, and last the bare disagreement between copies, which is not a cause
;; at all and is only what remains when no cause answers.
(define (classify w [variant? #f])
  (define set-form (word-printed w))
  (define composed (word-composed w))
  (define (differ? a b) (and a b (not (string=? a b))))
  (define wanting? (placeholder? set-form))
  (define shifted?
    (and (not wanting?) (differ? composed set-form)
         (substitution-only? composed set-form)))
  (cond
    [wanting? "sort-wanting"]
    [(and (differ? composed set-form) (not shifted?)) "foul-case"]
    [shifted? "substitution"]
    [(divided? w) "division"]
    [(for/or ([c (in-list (word-causes w))]) (string-prefix? c "justification"))
     (if (stages-cancel? w) (if variant? "press-variant" "copy") "justification")]
    [(differ? (word-copy w) (word-read w)) "misreading"]
    [(stages-cancel? w) (if variant? "press-variant" "copy")]
    [(differ? (word-read w) (word-habit w)) "habit"]
    [variant? "press-variant"]
    [else "copy"]))

(provide classify)

;; Which of the stages to colour it by, for the page itself.
(define (deviation-class w) (kind-class (classify w)))

(provide deviation-class)

(define (pct n d) (if (zero? d) 0.0 (* 100.0 (/ (exact->inexact n) d))))
(define (per-1000 n d) (if (zero? d) 0.0 (* 1000.0 (/ (exact->inexact n) d))))

;; A divided word keeps the whole word as its copy reading in both halves, so
;; it disagrees with every later stage without anything having gone wrong.
(define (divided? w)
  (ormap (lambda (c) (regexp-match? #rx"divid" c)) (word-causes w)))

(define (differs? a b)
  (and a b (not (string=? (string-downcase a) (string-downcase b)))))

(define (deviation-counts b [r #f])
  (define words
    (for*/list ([p (in-list (book-pages b))]
                [l (in-list (page-all-lines p))]
                [w (in-list (set-line-words l))])
      w))
  (define lines
    (for*/list ([p (in-list (book-pages b))]
                [l (in-list (page-all-lines p))])
      l))
  (define n (length words))

  (define (count-stage from to)
    (for/sum ([w (in-list words)])
      (if (and (not (divided? w)) (differs? (from w) (to w))) 1 0)))

  (define (lines-with rx)
    (for/sum ([l (in-list lines)])
      (if (ormap (lambda (w) (ormap (lambda (c) (regexp-match? rx c))
                                    (word-causes w)))
                 (set-line-words l))
          1 0)))

  (hash
   'words n
   'lines (length lines)
   'pages (length (book-pages b))
   ;; the stages
   'misreading (count-stage word-copy word-read)
   'habit      (count-stage word-read word-habit)
   'fitting    (count-stage word-habit word-final)
   'accident   (count-stage word-composed word-printed)
   ;; any departure at all, word by word
   'any (for/sum ([w (in-list words)])
          (if (and (not (divided? w)) (differs? (word-copy w) (word-printed w)))
              1 0))
   ;; what happened to lines
   'divided   (for/sum ([w (in-list words)])
                (if (ormap (lambda (c) (regexp-match? #rx"divided at" c))
                           (word-causes w)) 1 0))
   'turned-over (for/sum ([l (in-list lines)])
                  (if (set-line-turned-over? l) 1 0))
   ;; Only a verse line can be turned over: prose that overruns is simply
   ;; wrapped. So a book with no verse in it cannot show the device, and a
   ;; zero here would mean nothing at all -- which is how the author came to
   ;; record it as a dead mechanism in the roadmap when it was merely
   ;; inapplicable to every text he had tried.
   'verse-lines (for/sum ([l (in-list lines)])
                  (if (eq? (set-line-kind l) 'verse) 1 0))
   'quadded     (for/sum ([l (in-list lines)]) (if (set-line-quadded? l) 1 0))
   ;; Lines on which the compositor had to do something to the words to make
   ;; the measure come out -- not merely lines that were spaced. Every line in
   ;; a justified setting is spaced, so counting those told us the line count
   ;; back and nothing else.
   ;; Habits given up because the line wanted the copy's spelling after all.
   ;; The cheapest thing the compositor can do to a word, and it has to be
   ;; counted here or it becomes another mechanism that is silently dead: its
   ;; whole effect is to leave the word agreeing with copy, so nothing else in
   ;; the report or the facsimile can distinguish it from never having happened.
   'habit-suspended (for/sum ([w (in-list words)])
                      (if (ormap (lambda (c) (regexp-match? #rx"habit not applied" c))
                                 (word-causes w))
                          1 0))
   'expedient (for/sum ([l (in-list lines)])
                (if (for/or ([w (in-list (set-line-words l))])
                      (and (not (divided? w))
                           (differs? (word-habit w) (word-final w))))
                    1 0))
   ;; Purely conventional differences: long s, u for v, i for j. These are not
   ;; errors and not choices, but they are far the commonest way the print
   ;; departs from its copy, and without them the arithmetic below does not
   ;; add up.
   'conventions (for/sum ([w (in-list words)])
                  (if (and (not (divided? w))
                           (differs? (word-copy w) (word-printed w))
                           (not (differs? (strip-conventions (word-copy w))
                                          (strip-conventions (word-printed w)))))
                      1 0))
   ;; what happened to pages
   'crowded   (for/sum ([p (in-list (book-pages b))])
                (if (> (page-pressure p) 0) 1 0))
   'spun-out  (for/sum ([p (in-list (book-pages b))])
                (if (< (page-pressure p) 0) 1 0))
   'omitted   (for/sum ([p (in-list (book-pages b))]) (length (page-omitted p)))
   ;; before the compositor, and after him
   'prepared  (length (book-preparation b))
   'variants  (if r
                  (for*/sum ([(nm s) (in-hash (press-run-states r))]
                             [v (in-list (forme-state-variants s))])
                    1)
                  0)))

(define (row label n base [note ""])
  (format "    ~a ~a ~a  ~a"
          (~a label #:min-width 34)
          (~a (number->string n) #:min-width 7 #:align 'right)
          (~a (real->decimal-string (per-1000 n base) 2)
              #:min-width 8 #:align 'right)
          note))

(define (deviation-report b [r #f])
  (define c (deviation-counts b r))
  (define (g k) (hash-ref c k 0))
  (define n (g 'words))
  (define fmt (book-fmt b))

  (string-join
   (append
    (list
     "HOW FAR THE PRINT HAS MOVED FROM ITS COPY"
     ""
     "  Every figure below is an outcome, not a setting. A compositor does"
     "  not decide to abbreviate so many words in a thousand; he abbreviates"
     "  when a line will not come out, and how often that happens depends on"
     "  the measure, the format, the casting off, and the words the author"
     "  happened to use. The same copy set in another format gives other"
     "  numbers throughout."
     ""
     (format "  ~a: ~a ems x ~a column(s) x ~a lines = ~a ems of text to the page"
             (book-format-name fmt)
             (real->decimal-string (book-format-measure-ems fmt) 0)
             (book-format-columns fmt)
             (book-format-lines fmt)
             (exact-round (* (book-format-measure-ems fmt)
                             (book-format-columns fmt)
                             (book-format-lines fmt))))
     (format "  ~a words, ~a lines, ~a pages"
             n (g 'lines) (g 'pages))
     ""
     (format "    ~a ~a ~a"
             (~a "" #:min-width 34)
             (~a "count" #:min-width 7 #:align 'right)
             (~a "per 1000" #:min-width 8 #:align 'right))
     "    THE STAGES A WORD PASSES THROUGH"
     (row "copy marked up by the corrector" (g 'prepared) n
          "before the compositor saw it")
     (row "misread from the copy" (g 'misreading) n
          "his eye, not his judgement")
     (row "respelt by habit" (g 'habit) n
          "what he sets left to himself")
     (row "habit given up for the measure" (g 'habit-suspended) n
          "he set the copy's spelling instead")
     (row "altered to fit the measure" (g 'fitting) n
          "forced by the line, not chosen")
     (row "accident of the case" (g 'accident) n
          "foul case, turned letter, wrong fount")
     (row "corrected at press" (g 'variants) n
          "and so standing two ways")
     (row "long s, u for v, i for j" (g 'conventions) n
          "the house's conventions, not errors")
     ""
     (row "ANY departure from copy" (g 'any) n "")
     (format "    ~a of the text stands exactly as the copy had it"
             (string-append (real->decimal-string (- 100.0 (pct (g 'any) n)) 1) "%"))
     ""
     "    WHAT WAS DONE TO LINES"
     (row "needing an expedient to come out" (g 'expedient) (g 'lines)
          "per 1000 lines")
     (row "a word divided at the end" (g 'divided) (g 'lines) "per 1000 lines")
     (if (zero? (g 'verse-lines))
         (format "    ~a ~a ~a  ~a"
                 (~a "turned over or under" #:min-width 34)
                 (~a "—" #:min-width 7 #:align 'right)
                 (~a "—" #:min-width 8 #:align 'right)
                 "no verse in this book; only a verse line turns over")
         (row "turned over or under" (g 'turned-over) (g 'verse-lines)
              "per 1000 verse lines"))
     (row "quadded out" (g 'quadded) (g 'lines) "per 1000 lines")
     ""
     "    WHAT WAS DONE TO PAGES"
     (row "crowded" (g 'crowded) (g 'pages) "per 1000 pages")
     (row "spun out" (g 'spun-out) (g 'pages) "per 1000 pages")
     (row "lines of copy dropped" (g 'omitted) (g 'pages) "per 1000 pages")
     ;; All three of these are consequences of the casting off, and the
     ;; casting off is much more accurate on verse than on prose: the man
     ;; marking up the copy counts verse lines and estimates prose. That is
     ;; Gaskell's point and it is in `slip' in imposition.rkt -- 0.06 for
     ;; verse against 1.0 for prose. So a book of verse plays reports noughts
     ;; here, and the nought means "this copy could hardly produce one",
     ;; not "the mechanism is dead".
     ;;
     ;; It has to be said out loud. A bare 0.00 is exactly the reading that
     ;; once had a live mechanism written off as dead in this program, and
     ;; three of the four figures above sit at nought on the First Folio while
     ;; the same code on prose copy gives 109 crowded pages and 406 dropped
     ;; lines per thousand.
     ;; Gate on the omission branch and on the copy being chiefly verse. Not
     ;; on `crowded' being nought as well: the Folio crowds two pages in a
     ;; thousand, which is the same story rather than a different one, and
     ;; requiring both to be nought meant the note never appeared on the very
     ;; book it was written for.
     (if (and (zero? (g 'omitted))
              (> (g 'verse-lines) (* 4 (- (g 'lines) (g 'verse-lines)))))
         (format
          (string-append
           "\n    No copy was dropped and ~a crowded, and on a book of verse\n"
           "    that is what to expect rather than a mechanism failing to fire:\n"
           "    verse is cast off by counting lines and prose by judging them,\n"
           "    so the estimate is some sixteen times tighter here than it\n"
           "    would be on prose (imposition.rkt, `slip'). The same code on\n"
           "    prose copy at the same accuracy crowds 109 pages in a thousand\n"
           "    and drops 406 lines in a thousand.")
          (case (g 'crowded)
            [(0) "nothing was"]
            [(1) "one page was"]
            [else (format "~a pages were" (g 'crowded))]))
         "")
     "")
    (list
     "  The two rates worth comparing are habit and fitting. Habit is the"
     "  man; fitting is the measure. Where fitting is the larger, the page is"
     "  reporting the width of the stick rather than the workman, and any"
     "  attribution drawn from its spelling is reading the furniture. This is"
     "  Hinman's own caveat about his method (i. 186-7), and it is the one"
     "  quantity a real book cannot supply, because in a real book the two"
     "  are already mixed."))
   "\n"))

(module+ test
  (require rackunit racket/file racket/runtime-path "copytext.rkt")

  (define-runtime-path ado "samples/ado/_all-q1600.txt")
  (define txt (file->string ado))

  (define (counts-for fmt)
    (deviation-counts
     (set-book (make-house #:fmt fmt #:compositors '("A" "B") #:seed 5) txt 'prose)))

  (define f (counts-for FOLIO-IN-SIXES))
  (define q (counts-for QUARTO))
  (define o (counts-for OCTAVO))

  ;; The same copy makes very different books. A folio page holds 2112 ems
  ;; against an octavo's 480, so the octavo takes four times the pages and is
  ;; cast off four times as often.
  (check-true (> (hash-ref o 'pages) (* 3 (hash-ref f 'pages)))
              "octavo takes far more pages than folio")

  ;; And the rates follow the format rather than being fixed. The quarto's
  ;; 21-em measure leaves room and its fitting rate is the lowest of the
  ;; three; the narrower folio column and octavo page force the compositor's
  ;; hand oftener. That the numbers move at all with the format is the whole
  ;; reason for measuring per run.
  ;;
  ;; The ordering of habit against fitting is deliberately not asserted. It
  ;; used to be -- fitting exceeded habit in folio -- until the spelling
  ;; devices were gated on the lexicon, which cut fitting by some sixty per
  ;; cent because most of what the program had been calling justification was
  ;; unattested forms. What survives is a lower bound: the lexicon holds a few
  ;; thousand forms, so many real variants are unknown to it too, and the
  ;; figure should rise again when a corpus is behind it.
  (define (rate h k) (/ (exact->inexact (hash-ref h k)) (hash-ref h 'words)))
  (check-true (< (rate q 'fitting) (rate o 'fitting))
              "the wide quarto measure forces fewer alterations than the octavo")
  (check-true (> (- (apply max (map (lambda (h) (rate h 'fitting)) (list f q o)))
                    (apply min (map (lambda (h) (rate h 'fitting)) (list f q o))))
                 0.001)
              "the fitting rate is a property of the run, not a constant")

  ;; A narrower measure divides more words -- but not measurably on *this*
  ;; sample, and the assertion that it did was false before it was brittle.
  ;;
  ;; Averaged over four seeds this text gives the quarto 0.063 divisions per
  ;; line against the octavo's 0.056: the wrong way round. The test passed only
  ;; because seed 5 happened to land 0.0704 against 0.0711, a margin of one
  ;; per cent, and seed 6 reversed it by a factor of two. Gating the scribal
  ;; signs moved the random stream and it fell over, which is how it came to
  ;; light.
  ;;
  ;; The physical claim is sound; the sample cannot show it. _Much Ado_ is
  ;; drama, and dividing needs a long word meeting a line-end -- but a page of
  ;; dialogue is mostly short speeches, so most of its line-ends are the ends of
  ;; speeches, where there is nothing to divide. On continuous prose the effect
  ;; is plain and survives every seed: _Areopagitica_ gives 0.19 divisions per
  ;; line in octavo against 0.13 in quarto.
  ;;
  ;; So what is asserted here is what this sample can support -- that division
  ;; happens at all, at a rate near the 5.1 per hundred lines measured from the
  ;; Folio -- and the format comparison waits for a prose sample in the
  ;; repository to test it against.
  (define (div h) (/ (exact->inexact (hash-ref h 'divided)) (hash-ref h 'lines)))
  (check-true (< 0.02 (div q) 0.12)
              "the quarto divides at something near the Folio's 5 per 100 lines")
  (check-true (< 0.02 (div o) 0.12) "and so does the octavo")

  ;; Most of the difference between print and copy is neither error nor
  ;; choice but the house's conventions, and a report that did not say so
  ;; would leave the arithmetic unexplained.
  (check-true (> (hash-ref f 'conventions) (hash-ref f 'fitting))
              "long s and u/v outweigh every deliberate change"))
