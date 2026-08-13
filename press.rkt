#lang racket/base
;;; At press: proof-correction in the middle of the run, and its consequences.
;;;
;;; The press does not stop for a proof. A forme is made ready, the run
;;; begins, and a proof-sheet is pulled and read while the pressmen carry on.
;;; When the corrector sends his marked proof back the forme is unlocked, the
;;; faulty letters are replaced, and the run continues. The sheets already
;;; printed are not thrown away -- paper was the largest cost in the shop --
;;; so they go into the heap with the rest.
;;;
;;; Every corrected forme therefore exists in two states, and since the heaps
;;; were gathered at random when the book was made up, no two copies of the
;;; edition need agree.
;;;
;;; How the corrector worked is a question with two answers, and this module
;;; used to give only one of them.
;;;
;;; Moxon describes the proper method: the master-printer appoints someone
;;; "well skill'd in true and quick Reading, to Read the Copy" aloud while the
;;; corrector follows the proof. On that method the copy is present throughout
;;; and a misreading is as catchable as a turned letter.
;;;
;;; Hinman found the Folio was not corrected that way. Its variants are mostly
;;; obvious blunders, and "the copy was in all probability seldom if ever used
;;; to correct perfectly obvious mistakes that could easily enough, in the
;;; light provided by the immediate context, be made to yield sense". But
;;; seldom is not never, and he can point to the corrections that prove it: a
;;; two-line speech restored on d5 that "cannot have been restored save by
;;; reference to the copy", and a line on vv3 bearing no resemblance to what
;;; it replaced.
;;;
;;; So the corrector here works from sense, and now and then calls for the
;;; copy. The distinction matters because the two methods fail differently:
;;; sense catches foul case and leaves a plausible misreading standing, while
;;; the copy catches the omission that sense cannot even see.
;;;
;;; Hinman also noticed the consequence of a scare. Having consulted the copy
;;; and discovered a considerable omission, the reader grew "somewhat more
;;; careful ... at least for a time" -- so a serious catch raises vigilance,
;;; and the vigilance decays.
;;;
;;; And he sometimes made it worse, introducing a reading that is neither the
;;; author's nor the compositor's: at one place a compositor's error was
;;; rightly noticed and then "corrected" to something plausible and wrong.
;;;
;;; And one from Carter: a proof pulled and mended *before* the run leaves no
;;; variant at all. So the catalogue of press variants, however many copies
;;; are collated, records only the corrections made too late.

(require racket/list racket/string racket/math racket/set
         "compositor.rkt" "book.rkt" "imposition.rkt" "binding.rkt" "cancels.rkt"
         "rng.rkt" "lexicon.rkt"
         (only-in "orthography.rkt" split-point))

(provide (struct-out pvariant) (struct-out forme-state)
         (struct-out printed-copy) (struct-out press-run)
         run-press copy-reading-map collate run-variants
         forme-state-corrected? book-quires
         variant-groupings greg-consistent? HEAP-TRAVEL-BOUND PROOF-RATE)

;; Plausible sophistications: what a corrector puts in when he decides a
;; perfectly good reading must be wrong.
(define sophistications
  (hash "thou" "you" "vnto" "to" "whiles" "while"
        "betwixt" "between" "burthen" "burden" "murther" "murder"
        "vilde" "vile" "moe" "more" "shew" "show"))

;; The drying rack, in Moxon's own units (pp. 311-12).
;;
;; He offers three sizes for a doubling -- a quire, half a quire, or "about
;; seventeen Sheets, more or less" -- and a quire in his warehouse is 24 or 25,
;; so 12 to 25 is his span and seventeen is his middle. Nothing here is
;; interpolated between his figures. The handful is "several Doublings over one
;; another (perhaps three or four)".
(define DOUBLING-MIN 12)
(define DOUBLING-MAX 25)
(define HANDFUL-MIN 3)
(define HANDFUL-MAX 4)

;; The furthest a sheet can be carried from where it was printed. A doubling
;; only moves among the handful taken down with it, so the bound is the span of
;; a handful and NOT a function of `heap-disorder' at all -- the rate governs
;; how many sheets move, never how far. 75 by construction; 70 is the furthest
;; observed over 40 heaps of 750 sheets.
;;
;; This is exported because it is the number a report has to print beside
;; Greg's condition. A collation whose copies stand further apart than this in
;; the heap cannot detect the disorder at any rate whatever, so "HOLDS" from
;; such a collation means the test could not fire rather than that the
;; warehouse kept its order.
(define HEAP-TRAVEL-BOUND (* (sub1 HANDFUL-MAX) DOUBLING-MAX))

;; How often a forme is proofed at all. The arithmetic that gets from Hinman's
;; count of formes CORRECTED to this rate of formes PROOFED is spelt out at the
;; keyword argument below; it is named here because main.rkt needs the same
;; default and a second literal is a second place for it to drift.
(define PROOF-RATE 0.224)

(struct pvariant (forme page line word uncorrected corrected note) #:transparent)

(struct forme-state (forme proofed? fraction-uncorrected variants silent)
  #:transparent)

(define (forme-state-corrected? s)
  (and (forme-state-proofed? s) (pair? (forme-state-variants s))))

;; One physical copy of the book, made up from the heaps.
;; `states' maps forme-name -> #t if this copy has the corrected state.
(struct printed-copy (name states binding) #:transparent)

;; The gatherings as they reach the warehouse table, with the count of leaves
;; that actually carry a signature -- taken from what was set, not from what
;; was intended, because the whole use of the figure is that a gathering with
;; nothing in its direction line is the one the binder puts in backwards.
(define (book-quires b)
  (for/list ([plan (in-list (book-plans b))])
    (define ps (for/list ([p (in-list (book-pages b))]
                          #:when (= (page-ref-gathering (page-pref p))
                                    (gathering-plan-place plan)))
                 p))
    (quire (series-mark (gathering-plan-series plan) (gathering-plan-index plan))
           (gathering-plan-leaves plan)
           (for/sum ([p (in-list ps)])
             (if (string=? (page-signature p) "") 0 1)))))

(struct press-run (states copies events silent-readings edition binding-error
                          cancels perfecting heap-disorder cancel-rate)
  #:transparent)

(define (run-variants r)
  (append* (for/list ([(k s) (in-hash (press-run-states r))])
             (forme-state-variants s))))

;; The corrector improving something that was not wrong.
;;
;; He must improve it into a spelling somebody used. This device was left
;; ungated when the compositor's were fixed, and it showed: it was turning
;; `begin' into `begine', `after' into `aftere' and `opinion' into `opinione',
;; and printing them in the list of press variants as though a real corrector
;; had made them. A reader who alters a word alters it towards a form he has
;; seen, not towards one no one ever set.
(define (sophisticate word g)
  (define low (string-downcase (string-trim word ".,;:!?" #:repeat? #t)))
  (define (ok form)
    (and form
         (not (string=? form word))
         (let-values ([(core _t) (split-point (string-downcase form))])
           (or (not (regexp-match? #px"^[a-zſ']+$" core))
               (plausible? core)))
         form))
  (or (and (hash-has-key? sophistications low)
           (ok (string-replace word low (hash-ref sophistications low))))
      (and (> (string-length low) 4) (string-suffix? low "e")
           (ok (string-replace word low (substring low 0 (sub1 (string-length low))))))
      (and (> (string-length low) 3)
           (ok (string-replace word low (string-append low "e"))))
      #f))

(define (run-press b
                   #:copies [copies 4]
                   #:seed [seed 1623]
                   ;; How often a forme is proofed at all.
                   ;;
                   ;; Measured, not guessed, and the measurement is Hinman's
                   ;; own summary of the whole Folio (Norton Facsimile,
                   ;; Introduction, p. xx). He looked for press variants across
                   ;; some eighty Folger copies and found "just over 500" --
                   ;; against the ten thousand there would have been had every
                   ;; page been corrected as thoroughly as the two surviving
                   ;; marked proofs. They fall out very unevenly: about seventy
                   ;; in the whole of the Comedies, in 29 of more than 300
                   ;; pages; about seventy in the Histories, in 31 of 262; and
                   ;; some 370 in the Tragedies, half of them in the seventy-odd
                   ;; pages set by Compositor E.
                   ;;
                   ;; That is roughly a hundred variant formes in about 450 --
                   ;; call it a fifth. This was 0.6, which put 258 formes of 511
                   ;; into a corrected state on the whole Folio, two and a half
                   ;; times what Hinman found, and 1,035 press variants against
                   ;; his 500. Not far enough out to look wrong on a quarto,
                   ;; which is why it survived: it took the whole book to show.
                   ;;
                   ;; The unevenness is the more interesting half and is
                   ;; already modelled -- E's formes are proofed 1.9 times as
                   ;; often, because Hinman's shop reviewed the work of a man
                   ;; "evidently expected to make many errors". What was wrong
                   ;; was the base rate under it.
                   ;; 0.28 was still a fifth too many, and for a reason worth
                   ;; naming: THIS IS THE RATE FORMES ARE PROOFED, and Hinman's
                   ;; hundred-in-450 is a count of formes CORRECTED. They are
                   ;; not the same number. 86% of proofed formes turn out to
                   ;; have something worth altering, and E's formes are proofed
                   ;; 1.9 times as often, which lifts the effective rate from
                   ;; the nominal 28.0% to 32.3%. The two together delivered
                   ;; 137 corrected formes of 493 -- 27.8% against Hinman's
                   ;; 22.2% -- and 773 press variants against his "just over
                   ;; 500".
                   ;;
                   ;; It has been wrong since it was set: the previous full
                   ;; Folio gave 144 of 510, the same 28%. It went unnoticed
                   ;; because a second error cancelled it. Variants per
                   ;; corrected forme were 3.90 against Hinman's 5.00, so the
                   ;; product landed near 500 by accident. Setting a white line
                   ;; between speeches was what held that figure down; with the
                   ;; page set solid it is 5.64, and the compensation went with
                   ;; it.
                   ;;
                   ;; 0.224 is the base that puts corrected formes at 22.2%
                   ;; once both are accounted for. Two wrongs stop making a
                   ;; right, which is the only reason the arithmetic is spelt
                   ;; out here rather than the number simply changed.
                   #:proof-rate [proof-rate PROOF-RATE]
                   #:catches-accident [catches-accident 0.75]
                   #:catches-misreading [catches-misreading 0.10]
                   ;; How often the reader calls for the copy rather than
                   ;; working by sense alone. Low, because Hinman's Folio is
                   ;; the case being modelled and its correction was mostly
                   ;; done without it -- but not zero, because he can name the
                   ;; places where the copy must have been at the reader's
                   ;; elbow. Set it to 1.0 for a house following Moxon's
                   ;; method, where the copy is read aloud throughout.
                   #:consults-copy [consults-copy 0.12]
                   #:sophisticates [sophisticates 0.16]
                   #:first-proof [first-proof 0.0]
                   ;; Faults per gathering per copy at the folding and sewing.
                   ;; No source gives one; see binding.rkt, which says so at
                   ;; length and prints the disclaimer beside every fault.
                   #:binding-error [binding-error BINDING-ERROR-RATE]
                   ;; How often an error that survived the proof is thought
                   ;; worth cutting a leaf out for. Zero by default: a cancel
                   ;; is a deliberate and expensive act, and this program does
                   ;; not know how grave an error has to be before a shop
                   ;; committed it.
                   #:cancel-rate [cancel-rate 0.0]
                   ;; Leaves cancelled for reasons outside the simulation --
                   ;; the Privy Council, a withdrawn dedication. A count, not
                   ;; a model. See cancels.rkt.
                   #:cancels [external-cancels 0]
                   #:imprint-change? [imprint-change? #f]
                   ;; How much of the heap's order the drying and piling
                   ;; destroy. 0 is Gaskell's "case of remarkable regularity";
                   ;; 1 is the independent draw this program used to make. No
                   ;; source gives a value -- Gaskell only says the order was
                   ;; likely but "not certain" to survive.
                   #:heap-disorder [heap-disorder 0.15]
                   #:edition [edition 750])
  (define g (make-rng (+ seed 99)))

  (define pages-by-forme (make-hash))
  (for ([p (in-list (book-pages b))])
    (hash-update! pages-by-forme (page-forme-name p)
                  (lambda (xs) (append xs (list p))) '()))

  ;; accidents are locatable in the standing type; misreadings are not
  (define events-by-page (make-hash))
  (for ([e (in-list (book-events b))])
    (when (and (not (string=? (event-page e) "")) (>= (event-word e) 0))
      (hash-update! events-by-page (event-page e)
                    (lambda (xs) (append xs (list e))) '())))

  (define states (make-hash))
  (define log '())
  (define silent-readings (make-hash))
  ;; raised when consulting the copy turns up a real corruption, and spent on
  ;; the next forme -- Hinman's reader, who grew more careful "at least for a
  ;; time" after finding a considerable omission
  (define vigilant (box #f))

  (define (locate p e)
    (define lines (page-all-lines p))
    (and (< (sub1 (event-line e)) (length lines))
         (let ([l (list-ref lines (sub1 (event-line e)))])
           (and (< (event-word e) (length (set-line-words l)))
                (list-ref (set-line-words l) (event-word e))))))

  (for ([(forme-name pages) (in-hash pages-by-forme)])
    ;; The rules are worked as the type is. A rule is a long thin strip under
    ;; the platen for the whole edition, and it takes its knocks there: Hinman
    ;; follows individual centre rules by their degeneration, and names three
    ;; of the worst in the last quire of the Tragedies (i. 148). The box rules
    ;; take the same wear plus the handling of being stripped off and re-laid
    ;; every few formes, which is where the type beside them gets displaced.
    (for* ([p (in-list pages)]
           [r (in-list (cons (page-centre-rule p) (page-box-rules p)))]
           #:when r)
      (work-rule! r edition g))

    ;; Proof-reading was not spread evenly. Hinman found it "in considerable
    ;; measure confined to some six or eight plays in one section of the book,
    ;; and especially to material set by a particular compositor" (i. 227) --
    ;; and the prentice hand E was proof-read as a matter of course.
    (define rate
      (if (for/or ([p (in-list pages)]) (string=? (page-compositor p) "E"))
          (min 0.97 (* proof-rate 1.9))
          proof-rate))

    (cond
      ;; A proof pulled and mended before the pressmen begin. The type is put
      ;; right and the edition is uniform, so the correction is invisible
      ;; afterwards -- it can only be counted here, where we are cheating.
      [(< (rnd g) first-proof)
       (define silent
         (for*/sum ([p (in-list pages)]
                    [e (in-list (hash-ref events-by-page (page-sig p) '()))]
                    #:when (eq? (event-kind e) 'accident))
           (define w (locate p e))
           (cond
             [(and w (< (rnd g) catches-accident))
              (hash-set! silent-readings
                         (list (page-sig p) (event-line e) (event-word e))
                         (word-composed w))
              1]
             [else 0])))
       (when (> silent 0)
         (set! log (cons (event 'press
                                (format "~a literal(s) mended before the run; no variant survives"
                                        silent)
                                (page-sig (car pages)) 0 -1 "" "" "")
                         log)))
       (hash-set! states forme-name (forme-state forme-name #t 1.0 '() silent))]

      [(not (< (rnd g) rate))
       (hash-set! states forme-name (forme-state forme-name #f 1.0 '() 0))]

      [else
       ;; How much of the run was worked off before the marked proof came
       ;; back. The press did not stop for it: at three or four impressions a
       ;; minute and fifteen to thirty minutes for the reader, some 60 to 120
       ;; sheets were printed before the corrected forme went back on.
       ;;
       ;; The proportion that represents depends entirely on the edition, and
       ;; here Hinman's Folio is atypical. His 1,200 gives 5 to 10 per cent;
       ;; but the Cambridge Press accounts for 1711-12 record editions of 400
       ;; (Peck), 600 (Theophrastus), 700 (Newton's Principia), 750 (Thirlby)
       ;; and 820 (Pycroft). At 400 the same 60 to 120 sheets are 15 to 30 per
       ;; cent of the whole. So the fraction is derived from the edition size
       ;; rather than fixed, with a tail for the times the reader was slow to
       ;; begin at all.
       (define early (rnd-uniform g 60.0 120.0))
       (define slow (if (< (rnd g) 0.15) (rnd-uniform g 1.5 4.0) 1.0))
       (define fraction (min 0.65 (/ (* early slow) (max 100 edition))))
       (define variants '())

       ;; Is the copy at the reader's elbow for this forme? `vigilant' carries
       ;; over from a forme where consulting it turned up something serious.
       (define with-copy?
         (or (unbox vigilant) (< (rnd g) consults-copy)))
       (set-box! vigilant #f)

       (for ([p (in-list pages)])
         (for ([e (in-list (hash-ref events-by-page (page-sig p) '()))])
           (define w (locate p e))
           (define threshold
             (cond
               ;; foul case and turned letters are visible on the page itself,
               ;; so the copy adds little
               [(eq? (event-kind e) 'accident) catches-accident]
               ;; a misreading yields sense and hides from a reader working by
               ;; sense. Against the copy, read aloud, it has nowhere to hide.
               [with-copy? (max catches-misreading 0.80)]
               [else catches-misreading]))
           ;; What the reader can put back depends on what he is reading
           ;; against. A literal is wrong on the page, so the standing type
           ;; shows it and the composed reading restores it. A misreading is
           ;; not wrong on the page at all -- it is wrong against the copy --
           ;; so only the copy can supply what should have stood there. This
           ;; is why a corrector working by sense leaves misreadings behind
           ;; however careful he is: he has nothing to catch them with.
           (define restored
             (and w
                  (cond
                    [(eq? (event-kind e) 'accident)
                     (and (not (string=? (word-printed w) (word-composed w)))
                          (word-composed w))]
                    [with-copy?
                     (and (word-copy w)
                          (not (string=? (word-printed w) (word-copy w)))
                          (word-copy w))]
                    [else #f])))
           (when (and restored (< (rnd g) threshold))
             ;; the scare: having found a real corruption against the copy,
             ;; the reader is more careful for a while
             (when (and with-copy? (eq? (event-kind e) 'copy) (< (rnd g) 0.5))
               (set-box! vigilant #t))
             (set! variants
                   (cons (pvariant forme-name (page-sig p) (event-line e)
                                   (event-word e) (word-printed w) restored
                                   (if (eq? (event-kind e) 'accident)
                                       (format "literal corrected at press (~a)"
                                               (event-detail e))
                                       (format "reading restored from the copy (~a)"
                                               (event-detail e))))
                         variants))))

         ;; Misreadings have to be found on the page rather than in the event
         ;; log. They are recorded at the moment the compositor reads his copy,
         ;; before the word is placed, so they carry no page, line or word and
         ;; the loop above never sees them -- which meant that until this was
         ;; noticed no misreading was correctable at press by any method, and
         ;; `catches-misreading' did nothing whatever.
         ;;
         ;; The word itself is evidence enough: the copy said one thing and the
         ;; compositor read another. Habitual respelling does not show here,
         ;; because habit acts after reading and leaves `read' alone.
         (when with-copy?
           (for ([l (in-list (page-all-lines p))] [li (in-naturals 1)])
             (for ([w (in-list (set-line-words l))] [wi (in-naturals)])
               ;; A divided word is not a misreading. Both halves keep the
               ;; whole word as their copy reading, so `pri-' and `nce' would
               ;; otherwise look like corruptions of `prince' and get
               ;; "restored" into a line that has no room for them.
               (when (and (word-copy w) (word-read w)
                          (not (ormap (lambda (c) (regexp-match? #rx"divided" c))
                                      (word-causes w)))
                          (not (string=? (word-copy w) (word-read w)))
                          (not (string=? (word-printed w) (word-copy w)))
                          (< (rnd g) (max catches-misreading 0.80)))
                 (when (< (rnd g) 0.5) (set-box! vigilant #t))
                 (set! variants
                       (cons (pvariant forme-name (page-sig p) li wi
                                       (word-printed w) (word-copy w)
                                       (format "reading restored from the copy: ~s for ~s"
                                               (word-copy w) (word-printed w)))
                             variants))))))

         ;; and now the corrector improves something that was not wrong
         (define lines (page-all-lines p))
         (when (and (< (rnd g) sophisticates) (pair? lines))
           (define li (rnd-int g (length lines)))
           (define l (list-ref lines li))
           (when (pair? (set-line-words l))
             (define wi (rnd-int g (length (set-line-words l))))
             (define w (list-ref (set-line-words l) wi))
             (define new (sophisticate (word-printed w) g))
             (when (and new (not (string=? new (word-printed w))))
               (set! variants
                     (cons (pvariant forme-name (page-sig p) (add1 li) wi
                                     (word-printed w) new
                                     (format "corrector's sophistication; the copy read ~s"
                                             (word-copy w)))
                           variants))))))

       (hash-set! states forme-name
                  (forme-state forme-name #t fraction (reverse variants) 0))]))

  ;; The sheets are gathered, collated, folded and sewn -- and every copy is
  ;; folded separately, so this is where the copies stop being interchangeable.
  (define quires (book-quires b))
  ;; ------------------------------------------------------------------
  ;; The heaps, and the copies gathered from them
  ;; ------------------------------------------------------------------
  ;; This used to draw each forme's state independently for each copy, which
  ;; made a copy a random handful of corrected and uncorrected sheets. Gaskell
  ;; describes something quite different, and much more useful (pp. 143-4):
  ;;
  ;;   "the sheets were gathered from the top of each heap in the reverse of
  ;;   the printing order, so that the first book to be gathered contained the
  ;;   last printed sheets, and so on through the heaps until the early
  ;;   impressions were used for the last copies to be gathered."
  ;;
  ;; -- for a sheet perfected inner forme first. And for one perfected outer
  ;; forme first the heap "had to be turned over to show the first page of the
  ;; signature, which brought the first-printed sheet to the top. This heap was
  ;; then gathered in the printing order, so that the copies that were gathered
  ;; first contained early impressions of this particular gathering."
  ;;
  ;; So a copy is not a random draw of states. It is a *systematic* one: the
  ;; copies lie in the order they were gathered, each sheet's proof-correction
  ;; divides that order at the point the corrected proof came back, and which
  ;; side of the division is corrected depends on which forme of that sheet was
  ;; perfected first. Two sheets perfected the same way agree; two perfected
  ;; opposite ways are exactly complementary.
  ;;
  ;; That matters far beyond tidiness, and Greg says why. His calculus assumes
  ;; simple transcription -- one parent to a witness -- and warns that if "the
  ;; grouping is throughout random or if inconsistent forms are of frequent
  ;; occurrence, the relationship of the manuscripts cannot be accounted for on
  ;; the hypothesis of simple transcription; some sort of conflation has
  ;; somewhere to be assumed" (p. 43). A made-up copy of a printed edition IS
  ;; conflation by construction: it descends from no other copy, but is
  ;; assembled from as many heaps as there are sheets. Drawn independently, the
  ;; groupings would be random and the calculus would return nothing but
  ;; "conflation". Gathered as Gaskell describes, the groupings are constant --
  ;; and constant *up to complementation*, which is precisely the condition
  ;; Greg lays down for consistency: "given any two constant groups, either
  ;; these or their complements are either mutually exclusive or one wholly
  ;; includes the other" (p. 12).
  ;;
  ;; Which means the pattern of press variants across a handful of collated
  ;; copies should reveal, for every sheet, which of its formes went to press
  ;; first. That is a real bibliographical inference with a right answer, and
  ;; this program knows the answer.
  ;;
  ;; What is NOT claimed is the regularity. Gaskell hypothesises "a case of
  ;; remarkable regularity" and hedges it in the same breath: after drying,
  ;; "the chances were that ... the sheets would be in the same order as before,
  ;; although this was not certain to happen". `heap-disorder' is how much of
  ;; the order the drying and piling destroy -- 0 for Gaskell's ideal case. It
  ;; is a knob, and no source gives its value.
  ;;
  ;; But Moxon gives the *grain*, and this code used to get it wrong. It drew
  ;; `ordered?' independently for every copy and every sheet, so a single sheet
  ;; could lose its place in the heap on its own -- white noise. Moxon watched
  ;; the work (pp. 311-12) and it is not what happens. The heap goes up to the
  ;; drying racks in DOUBLINGS: the warehouse-keeper "doubles over so much of
  ;; the Heap as he thinks good, perhaps about a Quire, or half a Quire, or
  ;; about seventeen Sheets, more or less". It comes down a handful at a time:
  ;; he "slides several Doublings over one another (perhaps three or four)" and
  ;; lays them back on the heap.
  ;;
  ;; Two consequences, both structural rather than matters of rate. Order is
  ;; preserved INSIDE a doubling, always. And a doubling can only be laid back
  ;; out of order among the few handled with it. **A sheet never travels alone,
  ;; and it never travels far.**
  (define n-copies (max 1 copies))

  ;; The heap is as deep as the edition, not as deep as the copies anybody
  ;; collates: a doubling is seventeen of the sheets that were printed, and
  ;; four collated copies of a 750-sheet impression are 187 sheets apart in it.
  ;; Getting this wrong would measure the doublings in the wrong unit and make
  ;; the grain look far coarser than it is.
  (define heap-size (max n-copies edition))

  ;; The order the sheets lie in after drying, given the order they went up in.
  ;; `disorder' is the chance that one handful of doublings is laid back out of
  ;; order among themselves; within a doubling nothing moves at any value.
  (define (dry-heap laid-up disorder rg)
    (define doublings
      (let loop ([xs laid-up] [acc '()])
        (cond
          [(null? xs) (reverse acc)]
          [else
           (define len (min (length xs)
                            (+ DOUBLING-MIN
                               (rnd-int rg (add1 (- DOUBLING-MAX DOUBLING-MIN))))))
           (loop (drop xs len) (cons (take xs len) acc))])))
    (define laid-back
      (let loop ([ds doublings] [acc '()])
        (cond
          [(null? ds) (reverse acc)]
          [else
           (define k (min (length ds)
                          (+ HANDFUL-MIN
                             (rnd-int rg (add1 (- HANDFUL-MAX HANDFUL-MIN))))))
           (define handful (take ds k))
           (loop (drop ds k)
                 (cons (if (< (rnd rg) disorder) (rnd-sample rg handful k) handful)
                       acc))])))
    (append* (append* laid-back)))

  ;; Which forme of each sheet was perfected first. Gaskell's example supposes
  ;; every sheet was inner-first; a real shop was not so tidy.
  (define inner-first
    (for/hash ([name (in-hash-keys states)])
      (values name (< (rnd (make-rng (+ seed 4409 (equal-hash-code name)))) 0.5))))

  ;; One heap per sheet, dried and piled on its own, so the order each forme's
  ;; variant divides is that heap's and not the book's. Built once per forme:
  ;; every copy gathered from a heap sees the same order, which is the whole
  ;; difference between this and the per-copy draw it replaces.
  (define heaps (make-hash))
  (define (heap-for name)
    (hash-ref!
     heaps name
     (lambda ()
       ;; the printing positions as they lie after drying
       (define dried
         (dry-heap (range heap-size) heap-disorder
                   (make-rng (+ seed 5171 (equal-hash-code name)))))
       ;; and then gathered from the top -- reverse of the printing order for a
       ;; sheet perfected inner forme first, printing order for outer-first
       (list->vector (if (hash-ref inner-first name #t) (reverse dried) dried)))))

  ;; Copy i of the ones made up stands at this depth in the gathering order.
  ;; The copies are spread through the impression rather than taken off the
  ;; front of it, which is what a bibliographer collating a handful of
  ;; surviving copies has.
  (define (gathering-depth i) (quotient (* i heap-size) n-copies))

  ;; A, B ... Z, AA, AB ... which is the way a bibliographer runs out of
  ;; letters and the way this program already signs its gatherings.
  ;;
  ;; It used to be `(integer->char (+ 65 i))', which is fine for the four
  ;; copies anybody collates by hand and silently wrong past twenty-six: copy
  ;; 27 was named "Copy [", copy 28 "Copy \" -- not a legal filename on
  ;; Windows -- and copy 33 came out "Copy a", which after `string-downcase'
  ;; is the same file as copy A and overwrote it. An edition is 1,200 copies,
  ;; and Hinman collated far more than twenty-six.
  (define (copy-letters i)
    (let loop ([n i] [acc '()])
      (define ch (integer->char (+ (char->integer #\A) (remainder n 26))))
      (if (< n 26)
          (list->string (cons ch acc))
          (loop (sub1 (quotient n 26)) (cons ch acc)))))

  (define made
    (for/list ([i (in-range copies)])
      (define nm (format "Copy ~a" (copy-letters i)))
      (printed-copy
       nm
       (for/hash ([(name s) (in-hash states)])
         (define uncorrected (forme-state-fraction-uncorrected s))
         ;; This copy reaches into the heap at the depth it was gathered from,
         ;; and takes whichever sheet the drying rack left there. `pos' is that
         ;; sheet's place in the order it was PRINTED, which is what the proof
         ;; divides: everything worked off before the marked proof came back is
         ;; uncorrected, whatever order it was piled in afterwards.
         (define pos (vector-ref (heap-for name) (gathering-depth i)))
         (values name
                 (and (forme-state-corrected? s)
                      (>= (/ (add1 pos) heap-size) uncorrected))))
       (bind quires #:name nm #:rate binding-error
             #:rng (make-rng (+ seed 9001 (* 31 i)))))))

  ;; What was cut out and replaced. The errors offered as candidates are the
  ;; ones this run made itself and its own corrector let through, which is the
  ;; only cause that needs nothing supplied from outside.
  (define (leaf-of p)
    (define sig (page-sig p))
    (substring sig 0 (sub1 (string-length sig))))
  (define surviving
    (for*/list ([p (in-list (book-pages b))]
                [l (in-list (page-all-lines p))]
                [w (in-list (set-line-words l))]
                #:unless (string=? (word-composed w) (word-printed w)))
      (cons (leaf-of p) (format "the case gave ~s for ~s"
                                 (word-printed w) (word-composed w)))))
  ;; A cancellans is a leaf, so the white paper it can be printed on has to be
  ;; a leaf blank on both sides -- not merely a blank page, whose other side is
  ;; very likely printed. Named by the leaf, in the form a collation uses.
  (define blank-pages
    (for/set ([p (in-list (book-pages b))]
              #:when (for/and ([l (in-list (page-all-lines p))])
                       (null? (set-line-words l))))
      (page-sig p)))
  (define white
    (remove-duplicates
     (for/list ([p (in-list (book-pages b))]
                #:when (and (page-ref-recto? (page-pref p))
                            (set-member? blank-pages (page-sig p))
                            (set-member? blank-pages
                                         (string-append
                                          (substring (page-sig p) 0
                                                     (sub1 (string-length (page-sig p))))
                                          "v"))))
       (substring (page-sig p) 0 (sub1 (string-length (page-sig p)))))))
  (define cancels
    (plan-cancels (for/list ([p (in-list (book-pages b))])
                    (cons (leaf-of p)
                          (for/or ([l (in-list (page-all-lines p))])
                            (pair? (set-line-words l)))))
                  #:errors surviving
                  #:white white
                  #:rate cancel-rate
                  #:external external-cancels
                  #:imprint-change? imprint-change?
                  #:title-leaf (and (book-titlepage b)
                                    (pair? (book-pages b))
                                    (leaf-of (car (book-pages b))))
                  #:rng (make-rng (+ seed 7331))))

  ;; The cancel rate is kept because the report has to say *why* no leaf was
  ;; cancelled. Nought cancels at rate 0.00 means the run was never asked to
  ;; consider one; nought at 0.15 means it considered and declined. Those are
  ;; different facts and a bare "No leaf was cancelled" tells them apart for
  ;; nobody.
  (press-run states made (reverse log) silent-readings edition binding-error
             cancels inner-first heap-disorder cancel-rate))

;; The readings actually shown by one copy: the silent corrections, which
;; every copy has, plus whichever state of each variant forme it was made up
;; from.
(define (copy-reading-map pc r)
  (define out (hash-copy (press-run-silent-readings r)))
  (for ([(name corrected?) (in-hash (printed-copy-states pc))])
    (define s (hash-ref (press-run-states r) name #f))
    (when s
      (for ([v (in-list (forme-state-variants s))])
        (hash-set! out (list (pvariant-page v) (pvariant-line v) (pvariant-word v))
                   (if corrected? (pvariant-corrected v) (pvariant-uncorrected v))))))
  out)

;; Superimpose two copies and report where the page moves. This is what the
;; Hinman collator does mechanically.
(define (collate r a bcopy)
  (define ma (copy-reading-map a r))
  (define mb (copy-reading-map bcopy r))
  (define keys (remove-duplicates (append (hash-keys ma) (hash-keys mb))))
  (sort
   (for/list ([k (in-list keys)]
              #:unless (equal? (hash-ref ma k #f) (hash-ref mb k #f)))
     (list (format "~a, l.~a" (car k) (cadr k))
           (or (hash-ref ma k #f) "")
           (or (hash-ref mb k #f) "")))
   string<? #:key car))

(module+ test
  (require rackunit "imposition.rkt" racket/file racket/runtime-path)

  ;; A committed sample, reached relative to this module rather than to the
  ;; working directory. It used to read `areopagitica.txt' from
  ;; (current-directory), which is gitignored -- so this test, which is the one
  ;; that measures the whole Gaskell-and-Greg result, passed here and threw on
  ;; every clean checkout. The package build service found it within a day of
  ;; publication, which is exactly what a process per module is for.
  (define-runtime-path greg-sample "samples/ado/_all-q1600.txt")

  ;; Gaskell's mechanism, tested by Greg's rule, at Moxon's grain.
  ;;
  ;; Gathered from the tops of the heaps in signature order (pp. 143-4), every
  ;; press variant divides the copies at a point in one linear order, so any
  ;; two groupings are nested or disjoint and Greg's consistency condition
  ;; (p. 12) holds.
  ;;
  ;; The point is not that the ideal case passes. It is that the failure is
  ;; diagnostic: Greg says that where "the grouping is throughout random or if
  ;; inconsistent forms are of frequent occurrence ... some sort of conflation
  ;; has somewhere to be assumed" (p. 43), and a copy made up from heaps is
  ;; conflation by construction. So the consistency of the groupings measures
  ;; how far the warehouse preserved the order of printing -- which is a real
  ;; bibliographical inference, and one this program knows the truth of.
  ;;
  ;; What this asserted before Moxon's doublings were modelled was that a high
  ;; `heap-disorder' makes the condition fail on ten copies. It does not, and
  ;; the reason is the whole finding: a sheet moves only among the doublings
  ;; handled with it -- 26 sheets on average and never past 70 -- so ten copies
  ;; of a 750-sheet impression, 75 sheets apart in the heap, straddle the
  ;; disorder without ever sampling inside it. **The condition is blind to a
  ;; disorder finer than the spacing of the copies collated**, which is a
  ;; sharper statement than the old one and the opposite of a small-sample
  ;; effect: the sample is not too small, it is too sparse.
  ;;
  ;; Each call sets the book again, at half a second a call, and that is not an
  ;; extravagance. `run-press' wears the type it prints from: twenty-five runs
  ;; over one book leave it with twenty-five impressions' worth of damage, and
  ;; damage is precisely what `variant-groupings' keys on. One book shared by
  ;; the calls below made this block's result depend on the order they were
  ;; written in -- the sparse rate read 1.0 when it ran first and 0.96 when it
  ;; ran third, off the same model and the same seeds. So the loop was not
  ;; twenty-five draws from one distribution; it was one press working the same
  ;; forme twenty-five times, and its later runs had more to see than its first.
  (let ()
    ;; A rate over 25 runs, not one seed. Runs offering fewer than three
    ;; groupings cannot exercise the condition and are not counted.
    (define (consistent-share disorder #:copies [copies 10])
      (define book
        (set-book (make-house #:fmt QUARTO #:seed 21)
                  (file->string greg-sample)))
      (define-values (ok n)
        (for/fold ([ok 0] [n 0]) ([seed (in-range 25)])
          (define r (run-press book #:copies copies #:seed seed #:proof-rate 1.0
                              #:heap-disorder disorder))
          (define g (variant-groupings r))
          (if (< (hash-count g) 3)
              (values ok n)
              (values (+ ok (if (greg-consistent? g) 1 0)) (add1 n)))))
      (if (zero? n) 1.0 (/ ok (exact->inexact n))))

    ;; Gaskell's "case of remarkable regularity" -- nothing moved, so every
    ;; grouping is a prefix or suffix of one order. This one is asserted
    ;; exactly, because with nothing moved it is structural and not statistical:
    ;; no amount of accumulated damage makes a prefix stop being a prefix.
    (check-equal? (consistent-share 0.0) 1.0
                  "heaps gathered in order satisfy Greg's consistency rule")
    (define dense-ordered (consistent-share 0.0 #:copies 60))
    (check-equal? dense-ordered 1.0
                  "and however many copies are collated")

    ;; Sparse collation: the disorder is there and cannot be seen.
    ;;
    ;; A bound, not a value. This read exactly 1.0 for as long as the book was
    ;; shared, which made it a test of where the line stood in the block; run on
    ;; its own type it reads 1.0 over 25 seeds and 0.98 over 200, the drift being
    ;; the wear the loop itself puts on. What is asserted is blindness, and
    ;; blindness against the 0.04 the dense case gives is not a matter of the
    ;; third decimal place.
    (define sparse (consistent-share 1.0))
    (check-true (> sparse 0.9)
                (format "ten copies are too far apart in the heap to sample the disorder: ~a"
                        sparse))

    ;; Dense enough to reach inside a handful of doublings, and it shows.
    ;; Assert the ordering of the rates rather than their values: what is
    ;; being tested is that the detector responds to the disorder, and
    ;; pinning the numbers would make this a test of the seed sequence.
    (define dense-slack (consistent-share 0.15 #:copies 60))
    (define dense-shuffled (consistent-share 1.0 #:copies 60))
    (check-true (< dense-shuffled 0.25)
                (format "sixty copies do sample it: ~a" dense-shuffled))
    (check-true (< dense-shuffled dense-slack dense-ordered)
                (format "and the more the warehouse lost, the less consistent: ~a ~a ~a"
                        dense-ordered dense-slack dense-shuffled))
    ;; And the sparse rate is not merely above a bound but in a different
    ;; regime from the dense one. Stated as a comparison so that it cannot be
    ;; satisfied by both sides drifting together.
    (check-true (> sparse (* 3 dense-shuffled))
                (format "blind at ten copies, seeing at sixty: ~a against ~a"
                        sparse dense-shuffled)))

  (define sample
    (string-append
     "King. And can you by no drift of conference\n"
     "Get from him why he puts on this confusion,\n"
     "Grating so harshly all his days of quiet\n"
     "With turbulent and dangerous lunacy?\n\n"
     "Queen. Did he receive you well?\n"))

  (define b (set-book (make-house #:fmt QUARTO #:seed 1623) sample))
  (define r (run-press b #:copies 6 #:seed 1623 #:proof-rate 1.0))

  ;; The copy at the reader's elbow catches a different class of error.
  ;;
  ;; A misreading yields sense, so a reader working by sense alone has no
  ;; reason to stop at it; read against the copy it has nowhere to hide. Over
  ;; a long text the two methods should therefore mend a measurably different
  ;; number of readings, and it is the misreadings that move.
  ;; Misreadings are rare, so this asserts the invariant rather than a count:
  ;; a reader working by sense can never restore a copy reading, because he
  ;; has not got the copy. The prentice hand E misreads often enough to give
  ;; the other branch something to find.
  (let ()
    (define long-text
      (apply string-append (for/list ([i (in-range 60)]) sample)))
    (define bb (set-book (make-house #:fmt QUARTO #:seed 11 #:compositors '("E"))
                         long-text))
    (define (restorations consults)
      (define rr (run-press bb #:copies 2 #:seed 11 #:proof-rate 1.0
                            #:consults-copy consults))
      (for*/sum ([(nm s) (in-hash (press-run-states rr))]
                 [v (in-list (forme-state-variants s))]
                 #:when (regexp-match? #rx"restored from the copy"
                                       (pvariant-note v)))
        1))
    (check-equal? (restorations 0.0) 0
                  "a reader without the copy cannot restore a copy reading")
    (check-true (> (restorations 1.0) 0)
                "a reader with the copy at his elbow can"))

  ;; Every corrected forme was corrected early in the run, as the arithmetic
  ;; of a 1,200-sheet edition requires.
  (for ([(name s) (in-hash (press-run-states r))]
        #:when (forme-state-corrected? s))
    (check-true (< (forme-state-fraction-uncorrected s) 0.66)
                "uncorrected states are a minority of the edition"))

  ;; A copy is made up independently forme by forme, so two copies may differ.
  (check-equal? (length (press-run-copies r)) 6)

  ;; Collating a copy against itself finds nothing.
  (check-equal? (collate r (first (press-run-copies r)) (first (press-run-copies r)))
                '())

  ;; Corrections made before the run leave no variant to collate. Set by the
  ;; prentice hand, whose case is foul, so that there is something to correct.
  ;;
  ;; The sample has to be long enough for that to be reliable. At eight
  ;; repetitions it was about 250 words, and the prentice's measured rate of
  ;; 2 accidents per thousand words made the assertion below a coin-toss that
  ;; happened to land the right way for one seed. It failed the moment anything
  ;; upstream moved the random stream, which is a test of the seed and not of
  ;; the program. Sixty repetitions puts the expected count near forty.
  (define long-sample
    (apply string-append
           (for/list ([i (in-range 60)])
             (format "Ham. To be, or not to be, that is the question ~a,\nWhether tis nobler in the mind to suffer\nThe slings and arrows of outrageous fortune,\nOr to take arms against a sea of troubles.\n\n" i))))
  (define b2 (set-book (make-house #:fmt QUARTO #:seed 11 #:compositors '("E"))
                       long-sample))
  (check-true (> (for/sum ([e (in-list (book-events b2))]
                           #:when (eq? (event-kind e) 'accident)) 1)
                 0)
              "the prentice hand's case is foul enough to give us accidents")
  (define r2 (run-press b2 #:copies 4 #:seed 7 #:proof-rate 1.0 #:first-proof 1.0))
  (check-equal? (run-variants r2) '() "no variants when all proofing is early")
  (check-true (> (for/sum ([(k s) (in-hash (press-run-states r2))])
                   (forme-state-silent s))
                 0)
              "but corrections were nevertheless made")
  (check-equal? (collate r2 (first (press-run-copies r2)) (second (press-run-copies r2)))
                '() "and every copy agrees"))

;; ---------------------------------------------------------------------------
;; The groupings, in Greg's sense
;; ---------------------------------------------------------------------------
;; A press variant divides the collated copies into two groups -- those with
;; the corrected state of that forme and those with the uncorrected. That is
;; exactly Greg's "fundamental grouping", the kind that "divide the manuscripts
;; into two groups only" and which alone he regards as fundamental (p. 11).
;;
;; Returns forme-name -> the set of copy names showing the corrected state.
(define (variant-groupings r)
  (for/hash ([name (in-hash-keys (press-run-states r))]
             #:when (forme-state-corrected? (hash-ref (press-run-states r) name)))
    (values name
            (for/list ([pc (in-list (press-run-copies r))]
                       #:when (hash-ref (printed-copy-states pc) name #f))
              (printed-copy-name pc)))))

;; Greg's test for consistency, applied to those groupings.
;;
;;   "for fundamental groupings they appear to be satisfied if, and only if,
;;   given any two constant groups, either these or their complements are
;;   either mutually exclusive or one wholly includes the other. ... The rule
;;   comes to this, that while one or more manuscripts may pass from one side
;;   of a grouping to the other without rendering it inconsistent, those on
;;   opposite sides must not exchange places." (p. 12)
;;
;; Gathered as Gaskell describes, every grouping is a prefix or a suffix of one
;; linear order, so any two are nested or disjoint and the test passes. Drawn
;; independently, they cross and it fails. The test is therefore a detector for
;; the very thing this module was getting wrong.
(define (greg-consistent? groups)
  (define gs (for/list ([(k v) (in-hash groups)] #:unless (null? v)) (list->set v)))
  (for*/and ([a (in-list gs)] [b (in-list gs)])
    (or (set-empty? (set-intersect a b))          ; mutually exclusive
        (subset? a b) (subset? b a)               ; one includes the other
        ;; or the same holds of their complements
        (let ([all (for/fold ([u (set)]) ([g (in-list gs)]) (set-union u g))])
          (let ([a* (set-subtract all a)] [b* (set-subtract all b)])
            (or (set-empty? (set-intersect a* b*))
                (subset? a* b*) (subset? b* a*)))))))
