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
         (only-in "orthography.rkt" strip-conventions)
         (only-in "copytext.rkt" current-copy-kind copy-kind-note))

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
                      "but a letter that really differs still is")

  ;; EVERY MECHANISM MUST NAME ITSELF IN THE APPARATUS, and three did not.
  ;;
  ;; The tooltip is the only place most readers meet the model, and for a while
  ;; it called a mis-pointed word and a dropped word "misreading" -- his eye
  ;; going wrong, which is a different fault at a different stage. The counts in
  ;; `deviation-counts' had told pointing apart since it was built, so the table
  ;; and the tooltip disagreed about the same word: one property, two decision
  ;; points, and the reader was told the wrong thing.
  ;;
  ;; Each row here is a mechanism the program actually has, with the note it must
  ;; produce. A new mechanism belongs in this list before it is built.
  (let ()
    (define (mk copy read printed [causes '()])
      (word copy read read read read printed 100 causes #f '() 'picked))
    (define (note . args) (word-deviation (apply mk args)))
    ;; want of metal, in its three forms -- none of them an error
    (check-regexp-match #rx"w box was empty" (note "works" "works" "vvorks"))
    (check-regexp-match #rx"laid face down" (note "is" "is" "i▮"))
    (check-regexp-match #rx"wrong-fount"
                        (note "Cassio!" "Cassio!" "Cassio!"
                              '("! wanting; a wrong-fount ! borrowed")))
    ;; the case going wrong, by either of Hornschuch's two causes
    (check-regexp-match #rx"foul case" (note "honourable" "honourable" "hanourable"))
    (check-regexp-match #rx"foul case" (note "semeth" "semeth" "femeth"))
    ;; his pointing, which is NOT his eye
    (check-regexp-match #rx"^pointing:" (note "peace," "peace" "peace"))
    (check-regexp-match #rx"^pointing:" (note "peace," "peace;" "peace;"))
    (check-false (regexp-match? #rx"misreading" (note "peace," "peace" "peace"))
                 "a stop is not a misreading")
    ;; his place, which is not his eye either
    (check-regexp-match
     #rx"dropped where he took up"
     (note "my brother" "brother" "brother"
           '("resumption: a word or two dropped where he took up again")))
    (check-regexp-match
     #rx"stands where the copy has nothing"
     (note "" "the" "the"
           '("resumption: a word or two repeated where he took up again")))
    ;; his hand on the spacing, Hornschuch's fourth and sixth marks
    (check-regexp-match #rx"^spacing:" (note "wisdom and" "wisdomand" "wisdomand"))
    ;; Simpson prints this one as `tro bled', which drops the u as well as
    ;; opening the word; the mechanism here only ever puts white in, so the
    ;; faithful form of his example is the word entire with a space in it.
    (check-regexp-match #rx"^spacing:" (note "troubled" "trou bled" "trou bled"))
    (check-false (regexp-match? #rx"misreading" (note "wisdom and" "wisdomand" "wisdomand"))
                 "a space left out is not a misreading")
    ;; his capitals, which are a habit too and Blayney's other marker
    (check-regexp-match #rx"^capital:"
                        (word-deviation
                         (word "king" "king" "King" "King" "King" "King"
                               100 '() #f '() 'picked)))
    (check-false (regexp-match? #rx"^habit:"
                                (word-deviation
                                 (word "king" "king" "King" "King" "King" "King"
                                       100 '() #f '() 'picked)))
                 "a capital is not a spelling")
    ;; his pointing as a HABIT, which is a choice and at another stage than
    ;; `mis-point' -- that one is his hand slipping, this one is the workman.
    (check-regexp-match #rx"heavy stop of his period"
                        (word-deviation
                         (word "praise;" "praise;" "praise:" "praise:" "praise:" "praise:"
                               100 '() #f '() 'picked)))
    (check-false (regexp-match? #rx"^habit:"
                                (word-deviation
                                 (word "praise;" "praise;" "praise:" "praise:" "praise:" "praise:"
                                       100 '() #f '() 'picked)))
                 "and it is not reported as his spelling")
    ;; a word he never set at all, Hornschuch's first mark. The page-join slip
    ;; writes the SAME shape -- copy longer than reading -- and is claimed above
    ;; by its cause, so these two must not take each other's words.
    (check-regexp-match #rx"^omission:" (note "my brother" "brother" "brother"))
    (check-false (regexp-match? #rx"misreading" (note "my brother" "brother" "brother"))
                 "a word passed over is not a misreading")
    (check-false (regexp-match? #rx"^omission:"
                                (note "my brother" "brother" "brother"
                                      '("resumption: a word or two dropped where he took up again")))
                 "and the page-join slip keeps its own name")
    ;; the eye doubling back, which is the eyeskip above run the other way.
    ;; An empty copy WITH a resumption cause is the page-join slip and is
    ;; claimed above; an empty copy without one is this.
    (check-regexp-match #rx"^dittography:" (note "" "againe" "againe"))
    (check-false (regexp-match? #rx"misreading" (note "" "againe" "againe"))
                 "a word set twice is not a misreading")
    (check-regexp-match #rx"took up again"
                        (note "" "the" "the"
                              '("resumption: a word or two repeated where he took up again"))
                        "and the page-join slip is still its own kind")
    ;; and two words turned round, which is his hand and not his eye either
    (check-regexp-match #rx"^transposition:" (note "of the" "the of" "the of"))
    (check-false (regexp-match? #rx"misreading" (note "of the" "the of" "the of"))
                 "a transposition is not a misreading")
    ;; and a real misreading is still one
    (check-regexp-match #rx"^misreading:" (note "tongues" "tongnes" "tongnes"))
    ;; A cause named by a branch must not be printed twice by the loop that
    ;; prints unclaimed ones.
    (check-equal?
     (length (regexp-match* #rx"took up again"
                            (note "my brother" "brother" "brother"
                                  '("resumption: a word or two dropped where he took up again"))))
     1 "each fault is named once")

    ;; THE NOTE OPENS WITH THE FAULT THE WORD IS COLOURED BY. A word carrying
    ;; several notes had them joined in the order the stages happened, while the
    ;; class is the most significant of them -- so a word underlined as want of
    ;; metal could open "habit:", and one underlined as a shift could open
    ;; "pointing:". The colour and the first words of the hover disagreed, which
    ;; is what a reader reports as a mislabelled tooltip.
    ;;
    ;; Both of these carry two faults at once, and each must lead with its own.
    (let* ([shifted (mk "courſe;" "courſe" "courſe" '())]
           ;; pointed AND set from an empty box: classed a substitution
           [shifted* (word "courſe;" "courſe" "courſe" "courſe" "courſe" "course"
                           100 '() #f '() 'picked)]
           [tip (word-deviation shifted*)])
      (check-equal? (classify shifted*) "substitution" "the class is the shift")
      (check-true (string-prefix? tip "the ")
                  (format "and the note opens with it, not with the pointing: ~s" tip))
      (check-true (regexp-match? #rx"pointing" tip)
                  "the other fault is still told, after it"))
    ;; And a word with only one fault is unaffected by the reordering.
    (check-true (string-prefix? (note "peace," "peace" "peace") "pointing:")
                "one fault, one note, unmoved")))

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
  ;; "resumption" is claimed too: the branch below names it, and without this it
  ;; would also fall through to the loop that prints unclaimed causes and appear
  ;; twice in one tooltip.
  (define claimed
    (for*/list ([stage (in-list '("misreading" "habit" "justification" "resumption"))]
                [d (in-list (devices-for stage))])
      (string-append stage ": " d)))
  ;; Each note is tagged with the class it belongs to, so that the one the word
  ;; is COLOURED by can be brought to the front below.
  (define notes*
    (append
     (if divide-note (list (cons "division" divide-note)) '())
     ;; COPY AGAINST READ IS THREE FAULTS, NOT ONE, and this said "misreading"
     ;; to all of them. A misreading is his eye going wrong on a word; a stop set
     ;; otherwise than the copy had it is his pointing; and a word dropped or
     ;; doubled where he took up the copy again is his place, not his eye. They
     ;; happen at the same stage and are told apart by what differs.
     ;;
     ;; The counts in `deviation-counts' have distinguished pointing since it was
     ;; built and this did not, so the table and the tooltip disagreed about the
     ;; same word -- one property, two decision points, and the reader hovering
     ;; over `peace' was told the compositor had misread it.
     (if (and (not divide-note) (d (word-copy w) (word-read w)))
         (list
          (cond
            ;; named by the mechanism itself, which knows which it was
            [(for/or ([c (in-list (word-causes w))])
               (and (string-prefix? c "resumption: ") (substring c 12)))
             => (lambda (what)
                  (cons "resumption"
                        (if (string=? (word-copy w) "")
                            (format "~a: “~a” stands where the copy has nothing"
                                    what (word-read w))
                            (format "~a: the copy read “~a”" what (word-copy w)))))]
            ;; Nothing in the copy answers it. The resumption branch above has
            ;; already claimed the page-join slip by its cause, so an empty copy
            ;; reaching here is the eye doubling back within the passage.
            [(equal? (word-copy w) "")
             (cons "dittography"
                   (format "dittography: “~a” is set a second time; the copy has nothing answering it"
                           (word-read w)))]
            [(dropped? (word-copy w) (word-read w))
             (cons "omission"
                   (format "omission: the copy read “~a” and he set only “~a”"
                           (word-copy w) (word-read w)))]
            [(transposed? (word-copy w) (word-read w))
             (cons "transposition"
                   (format "transposition: the copy read “~a” and he set it “~a”"
                           (word-copy w) (word-read w)))]
            [(spacing-only? (word-copy w) (word-read w))
             (cons "spacing"
                   (if (regexp-match? #px"\\s" (or (word-copy w) ""))
                       (format "spacing: the copy had “~a” and he ran it together as “~a”"
                               (word-copy w) (word-read w))
                       (format "spacing: a space set inside “~a”, printed “~a”"
                               (word-copy w) (word-read w))))]
            [(pointing-only? (word-copy w) (word-read w))
             (cons "pointing"
                   (format "pointing: the copy had “~a” and he set “~a”"
                           (word-copy w) (word-read w)))]
            [else
             (cons "misreading"
                   (staged "misreading"
                           (format "misreading: copy “~a” → read “~a”"
                                   (word-copy w) (word-read w))))]))
         '())
     (if (and (not (stages-cancel? w)) (recapitalised? (word-read w) (word-habit w)))
         (list (cons "capital"
                     (format "capital: he set “~a” where the copy had “~a”; the period gave the word one mid-sentence"
                             (word-habit w) (word-read w))))
         '())
     (if (and (not (stages-cancel? w)) (repointed? (word-read w) (word-habit w)))
         (list (cons "pointing-habit"
                     (format "pointing: he set “~a” where the copy pointed “~a”, the heavy stop of his period"
                             (word-habit w) (word-read w))))
         '())
     (if (and (not (stages-cancel? w)) (d (word-read w) (word-habit w))
              (not (repointed? (word-read w) (word-habit w)))
              (not (recapitalised? (word-read w) (word-habit w))))
         (list (cons "habit"
                     (staged "habit"
                             (format "habit: “~a” → “~a”"
                                     (word-read w) (word-habit w)))))
         '())
     (if (and (not (stages-cancel? w)) (d (word-habit w) (word-final w)))
         (list (cons "justification"
                     (staged "justification"
                             (format "justification: “~a” → “~a”"
                                     (word-habit w) (word-final w)))))
         '())
     ;; A box that was empty is not a box that was foul. See
     ;; `substitution-only?': the reading is untouched, and calling it foul case
     ;; produced notes like `foul case: "officers" set for "officers"'.
     (if (d (word-composed w) (word-printed w))
         (list (cond
                 [(placeholder? (word-printed w))
                  (cons "sort-wanting"
                        (format "no sort to set “~a” with: a type laid face down to hold the place, to be put right at proof"
                                (word-composed w)))]
                 [(substitution-only? (word-composed w) (word-printed w))
                  (cons "substitution"
                        (substitution-phrase (word-composed w) (word-printed w)))]
                 [else
                  (cons "foul-case"
                        (format "foul case: “~a” set for “~a”"
                                (word-printed w) (word-composed w)))]))
         '())
     ;; the device that did it, in the compositor's own terms, where no stage
     ;; above has already named it
     (for/list ([c (in-list (word-causes w))]
                #:unless (or (regexp-match? #rx"divid" c) (member c claimed)))
       (cons #f c))))

  ;; THE NOTE MUST OPEN WITH THE FAULT THE WORD IS COLOURED BY.
  ;;
  ;; A word can carry several notes, and they were joined in the order the
  ;; stages happened -- while the class is the single most significant of them,
  ;; chosen by `classify'. So a word underlined as want of metal could open
  ;; "habit: ...", and one underlined as a shift could open "pointing: ...":
  ;; the colour said one thing and the first words of the hover another. Some
  ;; forty of two thousand marked words in one book, and it is exactly what a
  ;; reader reports as a mislabelled tooltip -- the `VV' for `W' whose note
  ;; began with an earlier stage and read as though the substitution were the
  ;; misreading.
  ;;
  ;; The chronology is kept behind it, because which letters moved and in what
  ;; order is the thing worth knowing once the kind is settled.
  (define lead (classify w))
  (define notes
    (append (for/list ([n (in-list notes*)] #:when (equal? (car n) lead)) (cdr n))
            (for/list ([n (in-list notes*)] #:unless (equal? (car n) lead)) (cdr n))))
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
    ;; Three faults share this stage and must not share a colour: his place,
    ;; his pointing, and his eye. Asked in that order because the mechanism
    ;; names itself where it can, and the shape of the difference names it
    ;; where it cannot.
    [(for/or ([c (in-list (word-causes w))]) (string-prefix? c "resumption: "))
     "resumption"]
    [(and (equal? (word-copy w) "") (word-read w)
          (not (string=? (word-read w) "")))
     "dittography"]
    [(and (differ? (word-copy w) (word-read w))
          (dropped? (word-copy w) (word-read w)))
     "omission"]
    [(and (differ? (word-copy w) (word-read w))
          (transposed? (word-copy w) (word-read w)))
     "transposition"]
    [(and (differ? (word-copy w) (word-read w))
          (spacing-only? (word-copy w) (word-read w)))
     "spacing"]
    [(and (differ? (word-copy w) (word-read w))
          (pointing-only? (word-copy w) (word-read w)))
     "pointing"]
    [(differ? (word-copy w) (word-read w)) "misreading"]
    [(stages-cancel? w) (if variant? "press-variant" "copy")]
    [(and (differ? (word-read w) (word-habit w))
          (repointed? (word-read w) (word-habit w)))
     "pointing-habit"]
    [(and (differ? (word-read w) (word-habit w))
          (recapitalised? (word-read w) (word-habit w)))
     "capital"]
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

;; Do these two differ in their pointing and in nothing else?
(define (strip-stops s)
  (list->string (for/list ([ch (in-string s)] #:unless (memv ch STOPS)) ch)))

(define (pointing-only? a b)
  (and a b (string=? (strip-stops (string-downcase a))
                     (strip-stops (string-downcase b)))))

;; Told apart the same way pointing is: take the white out of both sides, and
;; if nothing is left of the difference then the difference was the white.
;;
;; `on both' against `onboth' and `troubled' against `tro bled' both answer
;; here, which is right -- they are one fault, the space in the wrong state, and
;; the corrector marks them with one pair of marks. It has to be asked BEFORE
;; misreading, because a word run together with its neighbour differs from the
;; copy and would otherwise be read as the compositor's eye slipping.
;;
;; A copy word never contains a space -- the copy is tokenised on white -- so a
;; space on the copy side is always this mechanism and never the text's own.
(define (spacing-only? a b)
  (and a b
       (not (string=? a b))
       (string=? (string-replace a " " "") (string-replace b " " ""))))

;; The same words, in the other order. Asked before misreading for the same
;; reason spacing is: two words turned round differ from the copy and would
;; otherwise be read as his eye slipping on both of them at once.
;;
;; Sorted rather than compared pairwise, so that it still answers if a longer
;; passage is ever turned round. It cannot collide with `spacing-only?' -- take
;; the white out of "of the" and "the of" and they still differ -- so the order
;; of the two questions is a matter of reading and not of correctness.
;; What he set stands at the end of what the copy had, and the copy had more.
;; A word passed over, held as one pair: copy "my brother", read "brother".
;;
;; Asked after the resumption branch, which writes the same shape for the word
;; lost where he took his place up again and claims it by its cause. Asked
;; before misreading, because a word short of the copy is not his eye going
;; wrong on the words that are there.
(define (dropped? a b)
  (and a b
       (not (string=? a b))
       (let ([wa (string-split a)] [wb (string-split b)])
         (and (pair? wb)
              (> (length wa) (length wb))
              (equal? wb (take-right wa (length wb)))))))

;; His pointing, not his spelling: the two forms differ only in which heavy
;; stop stands at the end. Told apart from the spelling habit by the shape of
;; the difference, the same way the read-stage kinds are told from an eye-slip.
;; A capital he gave the word, where the copy left it lower case. His habit as
;; much as his spelling is, and told apart from it the same way -- by the shape
;; of the difference, the two forms being the same letters in another case.
(define (recapitalised? a b)
  (and a b
       (not (string=? a b))
       (string=? (string-downcase a) (string-downcase b))))

(define (repointed? a b)
  (and a b
       (not (string=? a b))
       (= (string-length a) (string-length b))
       (let ([n (string-length a)])
         (and (positive? n)
              (string=? (substring a 0 (sub1 n)) (substring b 0 (sub1 n)))
              (memv (string-ref a (sub1 n)) '(#\; #\:))
              (memv (string-ref b (sub1 n)) '(#\; #\:))))))

(define (transposed? a b)
  (and a b
       (not (string=? a b))
       (let ([wa (string-split a)] [wb (string-split b)])
         (and (> (length wa) 1)
              (= (length wa) (length wb))
              (equal? (sort wa string<?) (sort wb string<?))))))

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

  ;; Which of the three the printed form is, or #f where it stands as composed.
  ;; The order matters and is `word-deviation''s: a placeholder is not a
  ;; substitution, and a substitution is not foul case.
  (define (printed-as w)
    (and (not (divided? w))
         (differs? (word-composed w) (word-printed w))
         (cond
           [(placeholder? (word-printed w)) 'wanting]
           [(substitution-only? (word-composed w) (word-printed w)) 'substituted]
           [else 'accident])))

  (define (count-printed-as k)
    (for/sum ([w (in-list words)]) (if (eq? (printed-as w) k) 1 0)))

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
   ;; A stop set otherwise than the copy had it is not a misreading of a word,
   ;; and lumping the two would hide the commonest thing a corrector did behind
   ;; the rarest. They are separated on the difference itself: strip the stops
   ;; from both sides and if nothing is left of the difference, it was pointing.
   'misreading (for/sum ([w (in-list words)])
                 (if (and (not (divided? w))
                          (differs? (word-copy w) (word-read w))
                          (not (pointing-only? (word-copy w) (word-read w)))
                          (not (spacing-only? (word-copy w) (word-read w)))
                          (not (transposed? (word-copy w) (word-read w)))
                          (not (dropped? (word-copy w) (word-read w)))
                          (not (equal? (word-copy w) "")))
                     1 0))
   'mis-pointed (for/sum ([w (in-list words)])
                  (if (and (not (divided? w))
                           (differs? (word-copy w) (word-read w))
                           (pointing-only? (word-copy w) (word-read w)))
                      1 0))
   'mis-spaced (for/sum ([w (in-list words)])
                 (if (and (not (divided? w))
                          (differs? (word-copy w) (word-read w))
                          (spacing-only? (word-copy w) (word-read w)))
                     1 0))
   'doubled (for/sum ([w (in-list words)])
              (if (and (not (divided? w))
                       (equal? (word-copy w) "")
                       (word-read w)
                       (not (string=? (word-read w) "")))
                  1 0))
   'omitted-word (for/sum ([w (in-list words)])
                   (if (and (not (divided? w))
                            (differs? (word-copy w) (word-read w))
                            (dropped? (word-copy w) (word-read w)))
                       1 0))
   'transposed (for/sum ([w (in-list words)])
                 (if (and (not (divided? w))
                          (differs? (word-copy w) (word-read w))
                          (transposed? (word-copy w) (word-read w)))
                     1 0))
   'recapitalised (for/sum ([w (in-list words)])
                    (if (and (not (stages-cancel? w))
                             (recapitalised? (word-read w) (word-habit w)))
                        1 0))
   'repointed (for/sum ([w (in-list words)])
                (if (and (not (stages-cancel? w))
                         (repointed? (word-read w) (word-habit w)))
                    1 0))
   'habit      (count-stage word-read word-habit)
   'fitting    (count-stage word-habit word-final)
   ;; THREE THINGS MAKE THE PRINTED WORD DIFFER FROM THE COMPOSED ONE, and only
   ;; one of them is an accident of the case. `word-deviation' in this same
   ;; module has told them apart since the day a note read
   ;; `foul case: "officers" set for "officers"'; this count did not, and rang
   ;; every one of them as foul case under a label naming foul case, turned
   ;; letters and wrong fount.
   ;;
   ;; Measured on Areopagitica at folio in sixes: 317 words differ and NINE are
   ;; accidents. The rest are the shift ladder -- overwhelmingly a sort laid
   ;; face down to hold the place, plus VV for W and the ligature inversions.
   ;; A thirty-five-fold over-count, and on the Folio it read 2,313 against 813
   ;; accident events logged in the same run.
   ;;
   ;; That matters beyond the label. Roadmap §12 wants the compositor's error
   ;; rate separated from the surviving one, and neither can be measured against
   ;; a row that is nine parts want of metal.
   ;;
   ;; **Third time in this program that a stage comparison has rung something
   ;; else as foul case** -- the lessons name the other two. The remedy is the
   ;; same each time and was already twelve lines above: ask which of the three
   ;; it is, with the predicates `typecase.rkt' exports for the purpose.
   ;;
   ;; This counts accidents VISIBLE IN THE PRINTED FORM, which is why it reads a
   ;; little under the accident events logged for the same run -- 6 against 9 on
   ;; the sample above. The difference is the turns that change nothing, an `o'
   ;; or an `s' put in upside down, which this module's own note calls "the turn
   ;; that changes nothing". That is the right population here: a corrector can
   ;; only catch what shows on the page, and §12 wants this row to be what he had
   ;; to work with.
   'accident   (count-printed-as 'accident)
   ;; A box that was empty, not a box that was foul: the sort was laid face down
   ;; to hold the place and the reading is untouched.
   'wanting    (count-printed-as 'wanting)
   ;; VV for W and the like -- the compositor's own remedy, not a mistake.
   'substituted (count-printed-as 'substituted)
   ;; ERRORS MADE AND ERRORS SURVIVING ARE DIFFERENT NUMBERS (Roadmap §12).
   ;;
   ;; Every rate in the calibration table was diffed out of a printed book -- the
   ;; _Much Ado_ quarto against the Folio set from it -- so each counts what got
   ;; PAST the corrector. The row above counts what the compositor did, which is
   ;; the larger population by whatever was caught at proof. One number has been
   ;; doing both jobs, and Simpson gives the size of that from the other end:
   ;; twenty corrections on the one proof-corrected page of the First Folio that
   ;; survives, against about two and a half correctable errors a page here.
   ;;
   ;; A caught error does not leave the edition. The forme was mended in the
   ;; middle of the run, so the sheets already worked off keep it: it survives in
   ;; `fraction-uncorrected' of the copies and is gone from the rest. What a
   ;; bibliographer diffing ONE copy would find is therefore the number made,
   ;; less the mended ones weighted by the share of the run that got the
   ;; correction, less the ones mended before the press began at all -- which
   ;; leave no variant and no trace, and are Carter's point.
   ;; The same words, sorted the second way. A word is counted under the grade
   ;; of the fault it is COLOURED by, so the four add up to the marked words and
   ;; not to more: a word carrying two faults costs the reader by its worst.
   'grade-cosmetic     (for/sum ([w (in-list words)])
                         (if (eq? (lambard-grade (classify w)) 'cosmetic) 1 0))
   'grade-orthographic (for/sum ([w (in-list words)])
                         (if (eq? (lambard-grade (classify w)) 'orthographic) 1 0))
   'grade-sense        (for/sum ([w (in-list words)])
                         (if (eq? (lambard-grade (classify w)) 'sense) 1 0))
   'grade-meaning      (for/sum ([w (in-list words)])
                         (if (eq? (lambard-grade (classify w)) 'meaning) 1 0))
   'accidents-mended
   (if r
       (+ (for*/sum ([(k s) (in-hash (press-run-states r))]
                     [v (in-list (forme-state-variants s))]
                     #:when (regexp-match? #rx"^literal corrected at press"
                                           (pvariant-note v)))
            (- 1.0 (forme-state-fraction-uncorrected s)))
          (for/sum ([(k s) (in-hash (press-run-states r))])
            (forme-state-silent s)))
       0.0)
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
   ;; The compositor mistaking the point at which he left off, between one page
   ;; and the next -- McKerrow's mechanism, counted from the events because a
   ;; dropped word leaves nothing on the page to count.
   'mis-resumed (for/sum ([e (in-list (book-events b))])
                  (if (eq? (event-kind e) 'resumption) 1 0))
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
          (format "his eye, not his judgement — reading ~a" (copy-kind-note (current-copy-kind))))
     (row "pointed otherwise than the copy" (g 'mis-pointed) n
          "a stop dropped, changed, or set where none stood; no source gives a rate")
     (row "spaced otherwise than the copy" (g 'mis-spaced) n
          "two words run together, or a space inside one; no source gives a rate")
     (row "a word passed over" (g 'omitted-word) n
          "Hornschuch's first mark; the errata give a ceiling and not a rate")
     (row "set a second time" (g 'doubled) n
          "the eye back to the first of two like words; the mirror of eyeskip, and its rate")
     (row "two words set the wrong way round" (g 'transposed) n
          "no source gives a rate; the censuses give an ordering — rarer than pointing")
     (row "the heavy stop set as the period sets it" (g 'repointed) n
          "a colon for a semicolon or the reverse; measured from 300 books, and dated")
     (row "given a capital he was not given" (g 'recapitalised) n
          "3,761 word-types the period capitalised mid-sentence, with each one's share")
     (row "respelt by habit" (g 'habit) n
          "what he sets left to himself")
     (row "habit given up for the measure" (g 'habit-suspended) n
          "he set the copy's spelling instead")
     (row "altered to fit the measure" (g 'fitting) n
          "forced by the line, not chosen")
     (row "accident of the case" (g 'accident) n
          "foul case, turned letter, wrong fount")
     ;; The two stages of that one quantity, directly under it because they
     ;; qualify it and nothing else. The calibration table has been conflating
     ;; them; see `accidents-mended' above and Roadmap §12.
     (if (and r (> (g 'accident) 0))
         (let* ([mended (g 'accidents-mended)]
                [surviving (max 0.0 (- (g 'accident) mended))])
           (string-append
            (row "    of those, mended at proof" (exact-round mended) n
                 "gone from the copies printed after the correction")
            "\n"
            (row "    left standing in one copy" (exact-round surviving) n
                 "what a diff against the copy-text would find")))
         "")
     ;; Split out rather than dropped: both used to be counted on the accident
     ;; row, and a reader who knew the old total would otherwise see it fall by
     ;; an order of magnitude with nothing to account for it. Neither is an
     ;; error -- the first is want of metal and the second the compositor's own
     ;; remedy.
     (row "set face down for want of a sort" (g 'wanting) n
          "a box that was empty, not a box that was foul")
     (row "a sort substituted for another" (g 'substituted) n
          "VV for W and the like; the reading is untouched")
     (row "corrected at press" (g 'variants) n
          "and so standing two ways")
     (row "long s, u for v, i for j" (g 'conventions) n
          "the house's conventions, not errors")
     ""
     (row "ANY departure from copy" (g 'any) n "")
     ""
     "    WHAT IT WOULD COST THE READER — LAMBARD'S FOUR GRADES"
     "      He sorts the errata to his Perambulation of Kent (1576) before"
     "      printing them, and prints only \"Suche therefore as be most"
     "      daungerous\". The grades are his; the counts are this book's."
     (row "blemish only the workmanship" (g 'grade-cosmetic) n
          "the reading is untouched — a wrong fount, a shift, a divided word")
     (row "offend against orthographie" (g 'grade-orthographic) n
          "not a word: the eye stops, so it is the EASIEST to catch")
     (row "shrewdly peruert the sense" (g 'grade-sense) n
          "a word, and the wrong one: reads as sense and hides in it")
     (row "vtterly euert his meaning" (g 'grade-meaning) n
          "the sense breaks — a word dropped, doubled, or lost at a join")
     "      Lambard's order is DANGER and a corrector's is DETECTABILITY, and"
     "      they part at both ends: the orthographic fault is the second least"
     "      dangerous and the easiest to see, the sense-perverting one the most"
     "      dangerous and among the hardest. Which is why the errata lists are"
     "      full of exactly what a proof census does not show."
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
     ;; McKerrow's slip, which is a fault of PAGES rather than of words: it
     ;; happens where the compositor returns to his copy, and the report has to
     ;; say so beside the count because no source gives a rate for it.
     (row "the compositor lost his place" (g 'mis-resumed) (g 'pages)
          "per 1000 pages — a word or two dropped or doubled at the join; no source gives a rate")
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
              "long s and u/v outweigh every deliberate change")

  ;; A BOX THAT WAS EMPTY IS NOT A BOX THAT WAS FOUL, and this count used to say
  ;; it was. Three things make the printed word differ from the composed one --
  ;; foul case, a sort laid face down for want of metal, and a substitution like
  ;; VV for W -- and `'accident' rang all three under a label naming foul case,
  ;; turned letters and wrong fount. On Areopagitica it read 317 where nine
  ;; accidents were logged; on the Folio, 2,313 against 813.
  ;;
  ;; `word-deviation' in this module has told them apart for a long time, and the
  ;; comment beside it records the note that forced it -- `foul case: "officers"
  ;; set for "officers"'. The count did not, which is one property with two
  ;; decision points. **Third time a stage comparison in this program has rung
  ;; something else as foul case**, so it is pinned here rather than left to the
  ;; next reader's arithmetic.
  ;;
  ;; Asserted as an ordering and a bound, not as values: the point is that the
  ;; three are separated and that accidents are the rare one, which no seed can
  ;; reverse.
  ;; Ordering only. This carried a second assertion that foul case was under a
  ;; quarter of the other two together -- a ratio computed from SIX TO ELEVEN
  ;; events on this sample, and fitted to Areopagitica where it is 0.03 while on
  ;; this text it runs 0.30 to 0.50 by format. It broke the day a mechanism
  ;; altered a word or two on two pages in a hundred, which is all it takes when
  ;; the denominator is ten.
  ;;
  ;; **Three events is not a rate** -- written into this project's rules earlier
  ;; the same day, and violated here by the person who wrote it. The ordering is
  ;; the claim that matters and it holds at every format: want of metal is
  ;; commoner than foul case, and the two are counted apart.
  (check-true (> (hash-ref f 'wanting) (hash-ref f 'accident))
              "want of metal is commoner than foul case, and is counted apart")
  ;; And the row must stay in the same country as the accident events logged for
  ;; the same run. It sits a little under them because a turned `o' prints as an
  ;; `o' and never reaches the page, which is the population a corrector sees.
  (let* ([b (set-book (make-house #:fmt FOLIO-IN-SIXES #:compositors '("A" "B")
                                  #:seed 5)
                      txt 'prose)]
         [logged (for/sum ([e (in-list (book-events b))])
                   (if (eq? (event-kind e) 'accident) 1 0))]
         [counted (hash-ref (deviation-counts b) 'accident)])
    (check-true (<= counted logged)
                "no more accidents are reported than the run recorded")
    (check-true (>= counted (* 0.4 logged))
                "and not an order of magnitude fewer, which is what a lumped count hid")))
