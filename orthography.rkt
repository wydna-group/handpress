#lang racket/base
;;; Spelling: the compositor's habit, and the compositor's necessity.
;;;
;;; Two quite different forces act on the spelling of a printed page, and the
;;; whole difficulty of compositor analysis lies in telling them apart.
;;;
;;; The first is *habit*. A man who has spelt `doe' since his apprenticeship
;;; will go on spelling it `doe' whatever his copy says. This is the evidence
;;; Thomas Satchell used on _Macbeth_ in 1920 (TLS, 3 June), which Willoughby
;;; extended and Hinman built the Folio's compositor stints upon:
;;;
;;;     Compositor A:  doe  goe  here   griefe/grieue  Traytor  young
;;;     Compositor B:  do   go   heere  greefe/greeue  Traitor  yong
;;;
;;; The split is emphatically *not* full forms against short ones. Hinman
;;; gives each man a section under exactly these headings -- "'Do', 'go', and
;;; 'heere': Compositor B" and "'Doe', 'goe', 'here', and other spellings:
;;; Compositor A" (i. 182-3) -- and it is the crossed pattern that gives the
;;; test its power.
;;;
;;; The second force is *necessity*. The line must fill the measure exactly.
;;; A compositor short of room writes `do' and `&' and `y-e'; one with room to
;;; spare writes `doe' and `and' and `the'. So every spelling on a crowded
;;; page is suspect as evidence of habit -- a point Hinman presses against his
;;; own method at i. 186-7.

(require racket/string racket/list racket/match "metrics.rkt" "lexicon.rkt")

;; The gate every produced spelling passes through.
;;
;; The devices below are rules, and a rule will cheerfully produce `theere' or
;; `manne' if nothing stops it -- neither occurs once in 24,000 words of Q1600
;; and F1623, nor in Mulcaster's table of 1582. They are not spellings; they
;; are artefacts of an unchecked rule.
;;
;; So a form is refused when it has no warrant *and the word it came from
;; does*. That proviso matters: proper names, and the many words no corpus of
;; this size will contain, are left to the rules as before, because absence of
;; evidence about `Benedicke' is not evidence about `Benedicke'. Where the
;; base word is known, though, its variants are knowable too, and a form
;; nobody ever set is refused.
;; Signs are not spellings, and a word list cannot vouch for them. The
;; ampersand, the stroke over a vowel standing for a following nasal, the
;; superscript letters of `wᶜʰ' -- these are marks the trade made, not
;; spellings of English words, and no corpus of words will contain them. Only
;; forms written out in letters are the lexicon's business.
(define (spelling? s)
  (regexp-match? #px"^[A-Za-zſ']+$" s))

(define (warranted? produced base)
  (define group (map car (variants-of base)))
  (cond
    ;; signs are not the lexicon's business
    [(not (spelling? produced)) #t]
    ;; Where the corpus knows this word's spellings, the produced form must be
    ;; one of them. Merely being *a* word is not enough: `not' and `note' are
    ;; both English, and a device that turns one into the other has changed
    ;; the reading, not the spelling. This is the same trap as `her' for
    ;; `here', and the variant groups are what avoid it.
    ;; and it must be a form somebody really used, not one the corpus happens
    ;; to contain once or twice: see `plausible?'
    [(pair? group)
     (and (member (string-downcase produced) group)
          (plausible? produced)
          #t)]
    ;; A word the corpus knows, with no variants recorded, was set one way
    ;; only. Then any alteration is wrong, and it is not enough that the
    ;; result happens to be some other English word -- that is exactly how
    ;; `not' came to be set as `note'.
    [(attested? base) #f]
    ;; Otherwise the corpus has nothing to say, so the weaker test applies and
    ;; the rules keep their old freedom. With a lexicon of a few thousand
    ;; forms that is most words; with a corpus behind it, few.
    [else (or (sanctioned? produced) (not (sanctioned? base)))]))

(provide (struct-out variant) (struct-out conventions)
         SPELLING-TESTS SPELLING-PATTERNS
         head-form preferred pattern-form pattern-witness
         contractions expansions
         SCRIBAL-RATES scribal-rate tilde-chance BREVIGRAPH-SHARE
         apply-conventions strip-conventions modernise modernise-word
         apply-uv apply-ij apply-long-s apply-ligatures
         split-point match-case)

;; ---------------------------------------------------------------------------
;; Habit: the test words
;; ---------------------------------------------------------------------------

(define JAGGARD-TESTS
  (hash
   ;; The six Hinman actually rests his attributions on (i. 182-5). He notes
   ;; that do, go and heere "alone usually provide all the evidence that is
   ;; needed" to tell A's work from B's.
   ;;
   ;; C and D are given only these three, and deliberately so. Hinman: "no
   ;; attempt will be made to define the spelling preferences of any of these
   ;; men except as regards 'do', 'go', and 'here'" (i. 193 n.). Inventing
   ;; values for them in the other tests would be manufacturing evidence.
   ;;
   ;; Note what the columns do here. C is A's man for do and go but B's for
   ;; heere (i. 194). D agrees with A on all three -- so no spelling test can
   ;; separate A from D at all. Hinman separated them by the *case*: D is the
   ;; man who brought case z into use in quire K (i. 196).
   ;;              A          B         C          D
   "do"      (hash "A" "doe"  "B" "do"  "C" "doe"  "D" "doe")
   "go"      (hash "A" "goe"  "B" "go"  "C" "goe"  "D" "goe")
   "here"    (hash "A" "here" "B" "heere" "C" "heere" "D" "here")
   ;; A fourth test Hinman uses in the same way as the three above, and one
   ;; that also separates C from B: "'howre' is an A spelling, B almost
   ;; invariably using 'houre'", and two howre spellings in a disputed page
   ;; "make C the likelier of the two even here, since B characteristically
   ;; spells this word 'houre'".
   "hour"    (hash "A" "howre" "B" "houre" "C" "howre")
   "grief"   (hash "A" "griefe"   "B" "greefe")
   "grieve"  (hash "A" "grieve"   "B" "greeve")
   "traitor" (hash "A" "traytor"  "B" "traitor")
   "young"   (hash "A" "young"    "B" "yong")
   ;; Weaker: from Satchell's fuller Macbeth list as reported by later
   ;; writers, not among the discriminants Hinman himself leans on. Kept
   ;; because they thicken the evidence, but they should be the first things
   ;; deleted if this is used for anything but demonstration.
   "cousin"  (hash "A" "cousin"   "B" "cosin")
   "afraid"  (hash "A" "affraid"  "B" "afraid")
   "either"  (hash "A" "eyther"   "B" "either")
   "eternal" (hash "A" "eternall" "B" "eternal")
   "dear"    (hash "A" "deare"    "B" "deere")
   "cries"   (hash "A" "cryes"    "B" "cries")
   "fury"    (hash "A" "furie"    "B" "fury")
   "filthy"  (hash "A" "filthie"  "B" "filthy")
   "country" (hash "A" "countrey" "B" "country")))

;; ---------------------------------------------------------------------------
;; A second house
;; ---------------------------------------------------------------------------
;; Everything above is Jaggard's shop in 1621-3. These are Nicholas Okes's
;; men, from Blayney, _The Texts of King Lear and their Origins_, i, ch. 5 and
;; the table of compositorial spellings at i. 161-2. Okes's Q1 Lear was set by
;; two hands: B did sheets B-G and most of H alone, C four short stints in
;; H-L amounting to some 455 lines.
;;
;; Note what happens when you put the two houses side by side. Okes's B sets
;; doe, goe and here; Jaggard's B sets do, go and heere. The letters are house
;; labels, not identities, and a profile is meaningless without its shop
;; attached -- which is why these are separate keys rather than more columns
;; in the table above.
(define OKES-TESTS
  (hash
   "do"     (hash "OkesB" "doe"  "OkesC" "do")
   "go"     (hash "OkesB" "goe"  "OkesC" "go")
   "here"   (hash "OkesB" "here" "OkesC" "heere")))

;; The two houses merged into one table of tests. A head-word may be shared
;; (do, go, here are discriminants in both shops) while the forms belong to
;; different men, so the columns simply accumulate.
(define SPELLING-TESTS
  (for/fold ([h JAGGARD-TESTS]) ([(head forms) (in-hash OKES-TESTS)])
    (hash-set h head
              (for/fold ([m (hash-ref h head (hash))]) ([(k v) (in-hash forms)])
                (hash-set m k v)))))

;; Any attested variant maps back to its head-word.
(define heads
  (for*/fold ([h (hash)])
             ([(head forms) (in-hash SPELLING-TESTS)])
    (for/fold ([h (hash-set h head head)]) ([(who form) (in-hash forms)])
      (hash-set h (string-downcase form) head))))

(define (head-form word) (hash-ref heads (string-downcase word) #f))

(define (match-case model form)
  (cond
    [(and (> (string-length model) 1)
          (string=? model (string-upcase model))
          (regexp-match? #px"[A-Z]" model))
     (string-upcase form)]
    [(and (> (string-length model) 0)
          (char-upper-case? (string-ref model 0)))
     (string-append (string (char-upcase (string-ref form 0)))
                    (substring form 1))]
    [else form]))

;; The form this workman would set for `word', or #f if it is not a test word
;; or he already agrees with the copy.
;;
;; The punctuation has to come off first. Real copy is full of "do," and
;; "here." and "goe?", and looking the whole token up in the table of head
;; forms finds nothing -- so the man's habit silently failed to apply to every
;; test word that happened to end a clause. On a modern-spelt sample with
;; sparse punctuation that is invisible; on an actual quarto it suppressed
;; most of the evidence the whole program is about.
(define (preferred word prefs)
  (define-values (core tail) (split-point word))
  (define head (head-form core))
  (and head
       (let ([form (hash-ref prefs head #f)])
         (and form
              (not (string-ci=? form core))
              (string-append (match-case core form) tail)))))

;; ---------------------------------------------------------------------------
;; Habit: the spelling patterns
;; ---------------------------------------------------------------------------
;; Single test words are scarce -- a page may not contain one -- so these
;; patterns thicken the evidence: A's older -ie for a final -y and his doubled
;; final -ll against B's modernised forms.
;;
;; A caution. These are an extrapolation from the -ie/-y items in Satchell's
;; list, not something Hinman demonstrates. His own data run both ways on i/y
;; within a word: A sets Traytor against B's Traitor, but A sets Ulisses and
;; Troian against B's Ulysses and Troyan (i. 185). Treat them as a device for
;; making the simulation legible at short lengths, not as a finding.
;;
;; Both patterns are also justification devices -- -ie is wider than -y, -ll
;; than -l -- so they are contaminated evidence by construction. That is the
;; point: it is what makes the recovered attribution wrong where it is wrong.

(define SPELLING-PATTERNS
  (list
   ;; Okes's C has a real preference here and his fellow B has none, which is
   ;; the whole point of Blayney's tabulation. C set -ie 57% of the time
   ;; overall and 64% in unjustified lines; B's totals were 173 : 147, which
   ;; looks like a weak -ie preference until it is broken down and turns out to
   ;; be two opposite preferences imposed on him from outside -- justification
   ;; pushing him toward the longer form, and the level of the 'y' box pushing
   ;; him off it. "C preferred -ie, while B's practice was extremely
   ;; inconsistent. B preferred -ie in justified lines and may possibly have had
   ;; a preference for -y in unjustified text. But he was so prone to the
   ;; influence of several factors, especially that of type-supply, that one
   ;; could hardly use this group of spellings as a reliable discriminant"
   ;; (Blayney, i. 176).
   ;;
   ;; So B is deliberately absent from this table. He is not indifferent by
   ;; oversight: giving him an entry would assert a habit that Blayney spent
   ;; four pages showing he did not have, and the two mechanisms that in fact
   ;; governed him -- `adjust' in compositor.rkt and `supply-factor' in
   ;; typecase.rkt -- are both already in the program.
   (list "final -ie for -y"
         #px"^(?i:(.{2,}?[bcdfghjklmnpqrstvwxz])(ie|y))$"
         (hash "A" "ie" "B" "y" "OkesC" "ie"))
   (list "final -ll for -l"
         #px"^(?i:(.{3,}?[aeiou])(ll|l))$"
         (hash "A" "ll" "B" "l"))
   ;; Okes's B sets -our where C sets -or: "the spellings 'conquerour' and
   ;; 'labour' ... strongly support ... compositor B" (Blayney, i. 159), and
   ;; C's speech at L1v25 contains "'do' and four -or endings" (i. 160).
   (list "final -our for -or"
         #px"^(?i:(.{3,}?)(our|or))$"
         (hash "OkesB" "our" "OkesC" "or"))
   ;; The elided ending is a habit before it is ever a convenience. Jaggard's
   ;; men elide heavily -- the Folio has eight times the quarto's apostrophes
   ;; -- while Okes's C "refused five opportunities to use an apostrophe"
   ;; where his fellow B would have taken them (Blayney, i. 159). So it is
   ;; compositorial on both sides of the evidence, and belongs with habit
   ;; rather than with justification, where it fired far too seldom.
   (list "elided -'d for -ed"
         #px"^(?i:(.{2,}?[^tdaeiou])('d|ed))$"
         (hash "A" "'d" "B" "'d" "OkesB" "'d" "OkesC" "ed"))))

;; The form this workman's habits give a word governed by a pattern.
;; Returns (values form rule-name) or (values #f #f).
(define (pattern-form word style)
  (cond
    [(not style) (values #f #f)]
    [else
     (define-values (core tail) (split-point word))
     (let loop ([ps SPELLING-PATTERNS])
       (cond
         [(null? ps) (values #f #f)]
         [else
          (match-define (list name rx forms) (car ps))
          (define m (regexp-match rx core))
          (define want (hash-ref forms style #f))
          (cond
            [(and m want (not (string-ci=? (caddr m) want)))
             (values (string-append (cadr m) want tail) name)]
            [m (values #f #f)]
            [else (loop (cdr ps))])]))]))

;; Which workman's habit this form testifies to, if any.
;; Returns (values rule-name who) or (values #f #f).
;;
;; `names' is the crew actually at the frames. It matters, and leaving it out
;; was a bug that lay quiet until Okes's C was given his -ie preference: with
;; the whole table in scope, two men anywhere in it agreeing on a form killed
;; that form as evidence, even when the two had never stood in the same shop.
;; A and OkesC both set -ie, but a book is set by one crew, and in a house of A
;; and B the -ie ending discriminates perfectly. The word-tests in analysis.rkt
;; had always scoped themselves this way; this did not, and so quietly
;; discarded evidence as more compositors were added to the table -- the
;; opposite of what adding evidence should do.
(define (pattern-witness word [names #f])
  (define-values (core tail) (split-point word))
  (let loop ([ps SPELLING-PATTERNS])
    (cond
      [(null? ps) (values #f #f)]
      [else
       (match-define (list name rx forms) (car ps))
       (define m (regexp-match rx core))
       (cond
         [m
          (define ending (string-downcase (caddr m)))
          (define whos
            (for/list ([(k v) (in-hash forms)]
                       #:when (and (string=? v ending)
                                   (or (not names) (member k names))))
              k))
          ;; A form that several of *these* workmen would all have set is no
          ;; evidence of any of them. The elided ending is a habit of the house
          ;; as much as of the man, so it must not be counted as a discriminant.
          (if (= 1 (length whos)) (values name (car whos)) (values #f #f))]
         [else (loop (cdr ps))])])))

;; ---------------------------------------------------------------------------
;; Necessity: the ladder of contractions and expansions
;; ---------------------------------------------------------------------------

;; An alternative form, with what it costs or saves.
(struct variant (form delta device) #:transparent)

;; ---------------------------------------------------------------------------
;; How often the scribal signs were actually set
;; ---------------------------------------------------------------------------
;; These were guessed from two data points -- four tilde vowels in a quarto of
;; 1600, none in F1623 -- and the guess was wrong in both directions at once.
;; Counting them properly in the 5,287 EEBO-TCP books of `corpus/texts' gives
;; the rates below, per 1,000 words, as the median English book of its decade.
;; The median and not the mean: the distribution is fiercely skewed, 13% of
;; English books carry no tilde at all and 11% carry more than five per
;; thousand, so a pooled average describes almost no actual book.
;;
;;     decade    tilde   ampersand        (medians, 32.4M words, 573 books)
;;     1580s      2.99      5.45
;;     1590s      1.34      3.11
;;     1600s      1.01      3.18
;;     1610s      0.54      2.36
;;     1620s      0.21      1.92
;;     1630s      0.19      1.47
;;
;; So the practice dies away across exactly the period this program covers,
;; which is why no single rate was ever going to be right, and why F1623 having
;; none is unremarkable rather than evidence: the 1620s median is 0.21 and an
;; eighth of books have none.
;;
;; The three things lumped together here as `scribal' turn out to have three
;; different histories:
;;
;;   * The ampersand crossed over from the hand completely and is ordinary
;;     printing. No gate: the corpus rate and the program's are within a factor
;;     of two, which for this project counts as agreement.
;;   * The tilde crossed over and stayed productive -- 4,922 distinct marked
;;     forms in 365 books, from `thē' and `frō' down a very long tail to
;;     `iudgemēt' and `strēgth' -- but its frequency collapsed. It is a rule,
;;     correctly modelled, running about ten times too fast.
;;   * The superscript brevigraphs did NOT cross over. `yᵗ', `wᶜʰ', `yᵉ' and
;;     their fellows are a habit of the manuscript hand which the printing
;;     house very nearly refused. Measured across 6.4M words of English: `yt'
;;     5.5 per million words, `wth' 0.2, `yor' 0.3, and the true þᵗ ligature
;;     (which TCP writes `{that}') 0.8 per million. The program was setting
;;     them at 6.6 per thousand -- something like nine hundred times the rate
;;     of a real printed book.
;;
;; (TCP does render the flattened forms rather than silently expanding them,
;; which is what makes the near-zero count evidence rather than an artefact --
;; `ye', `yt', `wth' and `yor' all appear as text. `ye' is excluded from the
;; figures above because it is far commoner as the pronoun.)
;; Tildes per thousand words, median English book of the decade.
(define SCRIBAL-RATES
  (hash 1580 2.99 1590 1.34 1600 1.01 1610 0.54 1620 0.21 1630 0.19))

(define (scribal-rate year)
  (hash-ref SCRIBAL-RATES (max 1580 (min 1630 (* 10 (quotient year 10)))) 0.19))

;; With the device offered at every opportunity -- which is how it stood -- the
;; program set 6.09 tildes per thousand words of _Areopagitica_. That is the
;; ungated rate, and the ratio of the wanted rate to it is how often the
;; compositor may reach for the sign at all.
;;
;; This is a calibration, not a derivation, and it is worth being plain about
;; why it has to be. The design principle here is that a compositor "does not
;; decide to abbreviate so many words in a thousand; he abbreviates when a line
;; will not come out" -- so the rate is an outcome, and there is no rate to set.
;; What can be set is whether the sign is in his repertoire at all, and the
;; corpus fixes that by working backwards from the outcome it must produce.
(define UNGATED-TILDE-RATE 6.09)

(define (tilde-chance year) (min 1.0 (/ (scribal-rate year) UNGATED-TILDE-RATE)))

;; A superscript brevigraph against a tilde: about 0.007 per thousand words
;; against 1.4, averaged over the period. This keeps `yᵗ' the rarity it was
;; rather than a house style.
(define BREVIGRAPH-SHARE 0.005)

(define scribal
  (hash "the" "yᵉ" "that" "yᵗ" "which" "wᶜʰ" "with" "wᵗʰ"
        "your" "yᵒʳ" "our" "oᵘʳ" "sir" "ſʳ"))

(define tilde
  (hash #\a #\ā #\e #\ē #\i #\ī #\o #\ō #\u #\ū
        #\A #\Ā #\E #\Ē #\I #\Ī #\O #\Ō #\U #\Ū))

;; Words whose full form the trade kept in stock for stretching a line.
;;
;; This program has no dictionary. That is a real limitation and it showed up
;; here first. The list was originally built by analogy -- bee, wee, mee are
;; genuine, so manne, somme, welle, wille, himme, themme, theere, wheere and
;; whenne were coined to match. Counted against the 24,000 words of Q1600 and
;; F1623 in samples/ado, not one of those nine occurs. They are not early
;; modern spellings at all; they are what a rule produces when nothing checks
;; the result against a real book.
;;
;; Every form kept below is attested in that corpus. The counts are from it.
(define long-forms
  (hash "be" "bee"        ; 5
        "we" "wee"        ; 8
        "me" "mee"        ; 25
        "he" "hee"        ; 33
        "she" "shee"      ; 44
        "do" "doe"        ; 48
        "go" "goe"        ; 26
        "to" "too"        ; 51
        "here" "heere"    ; 19
        "only" "onely"    ; 12
        "sun" "sunne"     ; 4
        "run" "runne"     ; 2
        "sin" "sinne"     ; 12
        "won" "wonne"     ; 2
        "wild" "wilde"))  ; 2

;; Genuine period spellings that had gone out of use in printed drama by 1600:
;; none of these occurs in the sample either, but unlike the nine above they
;; are real, and would be right for copy of the 1580s or earlier. Absence from
;; 24,000 words is not proof a form never existed, so they are kept and
;; excluded rather than deleted.
(define archaic-long-forms
  (hash "so" "soe" "no" "noe" "by" "bye"
        "king" "kinge" "thing" "thinge"
        "such" "suche" "much" "muche"
        "old" "olde" "cold" "colde" "bold" "bolde"))

(define short-forms
  (for/hash ([(k v) (in-hash long-forms)]) (values v k)))

(define split-rx #px"^(.*?)([.,;:!?)'’\"\\]]*)$")

;; Separate a word from any punctuation clinging to its end.
(define (split-point word)
  (define m (regexp-match split-rx word))
  (cond
    [(or (not m) (string=? (cadr m) "")) (values word "")]
    [else (values (cadr m) (caddr m))]))

(define (w s) (width-of-word s))

;; Every way of making this word narrower.
(define (contractions word #:tilde? [tilde? #f] #:brevigraph? [brev? #f])
  (define-values (core tail) (split-point word))
  (define base (w word))
  (define lcore (string-downcase core))
  ;; Whatever a device builds, it wears the case of the word it came from.
  ;; The devices that *append* letters -- a terminal e, a doubled consonant --
  ;; assembled them from `core' directly and always in lower case, so HONOUR
  ;; came back HONOURe. Passing every produced form through match-case fixes
  ;; all of them at once rather than one device at a time.
  (define (add form device)
    (define-values (fcore ftail) (split-point form))
    (define cased (string-append (match-case core fcore) ftail))
    (define-values (ccore _t) (split-point cased))
    (and (warranted? ccore core)
         (variant cased (- (w cased) base) device)))
  (sort
   (filter values
    (list
     ;; 1. the scribal abbreviations, inherited from the manuscript hand.
     ;;    Off unless the house is one that used them; see `conventions'.
     (and brev? (hash-has-key? scribal lcore)
          (add (string-append (match-case core (hash-ref scribal lcore)) tail)
               (format "~a contracted to ~a" core (hash-ref scribal lcore))))
     ;; 2. the ampersand
     (and (string=? lcore "and") (add (string-append "&" tail) "& for and"))
     ;; 3. terminal -e struck off, only where the double vowel makes it
     ;;    plainly optional. The period's habit ran the other way: there was
     ;;    far more room to add a final -e than to take one away, and that
     ;;    asymmetry is why crowded pages abbreviate while gaping pages merely
     ;;    look generous.
     (and (string-suffix? lcore "ee") (> (string-length lcore) 2)
          (add (string-append (substring core 0 (sub1 (string-length core))) tail)
               "terminal -e struck off"))
     ;; 4. the short form of a word kept in both
     (and (hash-has-key? short-forms lcore)
          (add (string-append (match-case core (hash-ref short-forms lcore)) tail)
               (format "short form ~a" (hash-ref short-forms lcore))))
     ;; 5. -y for -ie: the counterpart of the expansion below, and the reason
     ;;    a crowded page set by A can be mistaken for a page set by B
     (and (string-suffix? lcore "ie") (> (string-length lcore) 4)
          (add (string-append (substring core 0 (- (string-length core) 2)) "y" tail)
               "-y for -ie"))

     ;; 5b. the elided ending: rul'd for ruled.
     ;;
     ;; This is the English contraction the trade actually used, and the one
     ;; the program was missing while it invented scribal signs instead. Across
     ;; five scenes of Much Ado the Folio has 114 medial apostrophes against
     ;; the quarto's 14, turning some thirty -ed endings into -'d. R. G. White
     ;; noticed the practice without counting it: the Folio is "carefully
     ;; printed for the day, even as to punctuation, contracted syllables, and
     ;; capital letters" (Furness, Variorum, p. 293).
     ;;
     ;; Not after t or d, where the ending is a syllable that must be sounded:
     ;; `wanted' and `ended' do not elide.
     (and (string-suffix? lcore "ed") (> (string-length lcore) 4)
          (not (memv (string-ref lcore (- (string-length lcore) 3))
                     '(#\t #\d #\e #\a #\i #\o #\u)))
          (add (string-append (substring core 0 (- (string-length core) 2)) "'d" tail)
               "elided -'d for -ed"))
     ;; 6. a doubled consonant reduced
     (let ([m (regexp-match-positions #px"([bdfglmnprst])\\1" lcore)])
       (and m (> (string-length lcore) 3)
            (let ([i (caar m)])
              (add (string-append (substring core 0 i)
                                  (substring core (add1 i)) tail)
                   (format "double ~a reduced" (string-ref lcore i))))))
     ;; 7. the tilde: a stroke over the vowel standing for a following nasal.
     ;;    Never over the first letter, and not before g or k where n belongs
     ;;    to a digraph and the abbreviation would be unreadable.
     (and tilde? (tilde-contraction core tail add))))
   < #:key variant-delta))

(define (tilde-contraction core tail add)
  (define n (string-length core))
  (let loop ([i (sub1 n)])
    (cond
      [(< i 2) #f]
      [else
       (define ch (string-ref core i))
       (define prev (string-ref core (sub1 i)))
       (define nxt (and (< (add1 i) n) (string-ref core (add1 i))))
       (cond
         [(and (memv ch '(#\m #\n))
               (hash-has-key? tilde prev)
               (not (and nxt (or (memv nxt '(#\g #\k))
                                 (memv (char-downcase nxt)
                                       '(#\a #\e #\i #\o #\u))))))
          (add (string-append (substring core 0 (sub1 i))
                              (string (hash-ref tilde prev))
                              (substring core (add1 i)) tail)
               (format "tilde for ~a" ch))]
         [else (loop (sub1 i))])])))

;; Every way of making this word wider.
(define (expansions word)
  (define-values (core tail) (split-point word))
  (define base (w word))
  (define lcore (string-downcase core))
  (define len (string-length lcore))
  ;; Whatever a device builds, it wears the case of the word it came from.
  ;; The devices that *append* letters -- a terminal e, a doubled consonant --
  ;; assembled them from `core' directly and always in lower case, so HONOUR
  ;; came back HONOURe. Passing every produced form through match-case fixes
  ;; all of them at once rather than one device at a time.
  (define (add form device)
    (define-values (fcore ftail) (split-point form))
    (define cased (string-append (match-case core fcore) ftail))
    (define-values (ccore _t) (split-point cased))
    (and (warranted? ccore core)
         (variant cased (- (w cased) base) device)))
  (sort
   (filter values
    (list
     (and (string=? core "&") (add (string-append "and" tail) "and for &"))
     (and (hash-has-key? long-forms lcore)
          (add (string-append (match-case core (hash-ref long-forms lcore)) tail)
               (format "full form ~a" (hash-ref long-forms lcore))))
     ;; Terminal -e added to a word ending in a consonant.
     ;;
     ;; Not after s. Mulcaster's rule is that the terminal E lengthens the
     ;; vowel before it -- his own example is mad and made -- and a final s is
     ;; almost always a plural or a possessive, where there is no vowel to
     ;; lengthen and no such form ever stood. Left in, this device turned
     ;; `marks' into `markse', `wars' into `warse' and `man's' into `man'se',
     ;; and since the long s is medial in all three the page then showed
     ;; `markſe' and `warſe'. Nothing of the kind was ever set.
     (and (> len 2)
          (memv (string-ref lcore (sub1 len)) (string->list "bdfgklmnprtvz"))
          (not (hash-has-key? long-forms lcore))
          (add (string-append core "e" tail) "terminal -e added"))
     ;; -all for -al, -ll for -l
     (and (string-suffix? lcore "l") (not (string-suffix? lcore "ll")) (> len 3)
          (add (string-append core "l" tail) "-ll for -l"))
     ;; the ending written out again: ruled for rul'd
     (and (string-suffix? lcore "'d") (> len 3)
          (add (string-append (substring core 0 (- (string-length core) 2)) "ed" tail)
               "-ed written out for -'d"))
     ;; -ie for -y
     (and (string-suffix? lcore "y") (> len 3)
          (not (memv (string-ref lcore (- len 2)) (string->list "aeiou")))
          (add (string-append (substring core 0 (sub1 (string-length core)))
                              "ie" tail)
               "-ie for -y"))))
   > #:key variant-delta))

;; ---------------------------------------------------------------------------
;; The conventions of the case: long s, u/v, i/j
;; ---------------------------------------------------------------------------
;; These are not spellings but typographical conventions, applied as the sorts
;; are picked. They are therefore no evidence at all of the copy behind the
;; page, and must be stripped before any spelling test is run -- a distinction
;; it is easy to lose sight of when reading a facsimile.

;; v initially, u medially: vpon, haue, loue, neuer.
(define (apply-uv word)
  (define n (string-length word))
  (list->string
   (for/list ([ch (in-string word)] [i (in-naturals)])
     (define prev-letter?
       (and (> i 0) (char-alphabetic? (string-ref word (sub1 i)))))
     (cond
       [(and (char=? ch #\u) (not prev-letter?)) #\v]
       [(and (char=? ch #\U) (not prev-letter?)) #\V]
       [(and (char=? ch #\v) prev-letter?) #\u]
       [(and (char=? ch #\V) prev-letter?) #\u]
       [else ch]))))

;; i does duty for j: Iohn, iustice, ioy.
(define (apply-ij word)
  (string-replace (string-replace word "j" "i") "J" "I"))

(define (apply-ligatures word)
  (for/fold ([s word])
            ([pair (in-list '(("ffl" "ﬄ") ("ffi" "ﬃ") ("ff" "ﬀ")
                              ("fi" "ﬁ") ("fl" "ﬂ")))])
    (string-replace s (car pair) (cadr pair))))

;; Long s except at the end of a word, and except the second of a final ss.
(define (apply-long-s word)
  (define cs (list->vector (string->list word)))
  (define n (vector-length cs))
  (define last
    (for/last ([i (in-range n)] #:when (char-alphabetic? (vector-ref cs i))) i))
  (for ([i (in-range n)])
    (when (char=? (vector-ref cs i) #\s)
      (unless (or (equal? i last)
                  (and (< (add1 i) n)
                       (memv (vector-ref cs (add1 i)) '(#\' #\’))))
        (vector-set! cs i #\ſ))))
  (list->string (vector->list cs)))

;; Which of the house conventions this book observes.
;;
;; `scribal?' governs the tilde over a vowel and the y-e / w-ch contractions
;; inherited from the manuscript hand. They belong here as a possibility, but
;; they should be OFF for an English dramatic text of 1623, and the reason is
;; a count rather than an opinion: across five scenes of Much Ado, the quarto
;; of 1600 has four tilde vowels in twelve thousand words and the Folio has
;; NONE -- no tilde, no y-e, no w-ch. The ampersand is another matter: the
;; Folio has fourteen. So the trade did contract, but by the ampersand and by
;; the fuller-or-shorter spelling, not by the scribal signs, which had gone
;; out of English printing well before Jaggard.
;; `year' is the date of the impression. It is here because three of the
;; conventions are not fixed points but slopes: the tilde dies away across the
;; period (see SCRIBAL-RATES), and u/v and i/j "had largely given way to the
;; modern practice by 1640" (Blayney, i. 145). A convention without a date is a
;; convention asserted to be timeless, and none of these is.
(struct conventions (long-s? uv? ij? ligatures? scribal? year) #:transparent)

;; ---------------------------------------------------------------------------
;; Reading the setting the other way
;;
;; A modernised edition does not undo the printing. It shows the same setting
;; in a spelling the reader has: the compositor still chose `heere' for a tight
;; line, and the line is still tight, but the page can be read as `here'. The
;; two are the same text differently presented, which is exactly what the TEI
;; <choice> of <orig> and <reg> encodes, and this produces the <reg> half.
;;
;; Three things are undone, in order:
;;
;;   the letter-forms   long s, u for v, i for j, the ligatures
;;   the spelling       heere for here, where the corpus records both
;;   the elisions       rul'd for ruled, which no lexicon will hold
;;
;; What cannot be undone is left alone, and silently: a word the corpus has
;; never seen keeps whatever the compositor gave it, because guessing would be
;; the same fault this program has spent its life removing.
;; ---------------------------------------------------------------------------

(define (modernise-word word)
  (define plain (strip-conventions word))
  (define-values (core0 tail) (split-point plain))
  (define core (undo-uv-ij core0))
  (define lifted (or (modern-form core) core))
  ;; -'d for -ed is a contraction, not a spelling, so no variant group will
  ;; record it; the apostrophe is simply filled back in.
  (define opened
    (cond
      [(regexp-match #px"^(.*[^aeiouAEIOU])'d$" lifted)
       => (lambda (m) (string-append (cadr m) "ed"))]
      [else lifted]))
  (string-append opened tail))

(define (modernise s)
  (regexp-replace* #px"[A-Za-zſ'’ﬀﬁﬂﬃﬄ]+" s
                   (lambda (w) (modernise-word w))))

(define (apply-conventions cv word)
  (let* ([s word]
         [s (if (conventions-uv? cv) (apply-uv s) s)]
         [s (if (conventions-ij? cv) (apply-ij s) s)]
         [s (if (conventions-ligatures? cv) (apply-ligatures s) s)]
         [s (if (conventions-long-s? cv) (apply-long-s s) s)])
    s))

;; Undo the conventions, to recover a form fit for a spelling test.
(define (strip-conventions word)
  (for/fold ([s word])
            ([pair (in-list '(("ſ" "s") ("ﬄ" "ffl") ("ﬃ" "ffi")
                              ("ﬀ" "ff") ("ﬁ" "fi") ("ﬂ" "fl")))])
    (string-replace s (car pair) (cadr pair))))

(module+ test
  (require rackunit)

  ;; The crossed pattern is the whole point of the test.
  (check-equal? (hash-ref (hash-ref SPELLING-TESTS "do") "A") "doe")
  (check-equal? (hash-ref (hash-ref SPELLING-TESTS "here") "A") "here")
  (check-equal? (hash-ref (hash-ref SPELLING-TESTS "here") "B") "heere")

  (check-equal? (head-form "heere") "here")
  (check-equal? (head-form "elephant") #f)
  (check-equal? (preferred "do" (hash "do" "doe")) "doe")
  (check-equal? (preferred "doe" (hash "do" "doe")) #f "already agrees")
  (check-equal? (preferred "Do" (hash "do" "doe")) "Doe" "case is kept")

  ;; Conventions of the case
  (check-equal? (apply-uv "upon") "vpon")
  (check-equal? (apply-uv "haue") "haue")
  (check-equal? (apply-uv "love") "loue")
  (check-equal? (apply-uv "very") "very")
  (check-equal? (apply-ij "joy") "ioy")
  (check-equal? (apply-long-s "sinnes") "ſinnes")
  ;; A final ss prints as long-s followed by short: confeſs, not confeſſ.
  (check-equal? (apply-long-s "confess") "confeſs")
  (check-equal? (apply-long-s "is") "is" "a final s stays short")
  (check-equal? (strip-conventions "confeſſion") "confession")

  ;; Splitting a word from its punctuation
  (let-values ([(c t) (split-point "lord,")])
    (check-equal? c "lord") (check-equal? t ","))
  (let-values ([(c t) (split-point "lord")])
    (check-equal? c "lord") (check-equal? t ""))

  ;; Contractions must actually be narrower, expansions actually wider.
  (for ([word (in-list '("and" "the" "that" "cannot" "bee" "beautie"))])
    (for ([v (in-list (contractions word))])
      (check-true (< (variant-delta v) 1)
                  (format "~a -> ~a should not widen" word (variant-form v)))))
  (for ([word (in-list '("&" "be" "lord" "eternal" "beauty"))])
    (for ([v (in-list (expansions word))])
      (check-true (> (variant-delta v) -1)
                  (format "~a -> ~a should not narrow" word (variant-form v)))))

  (check-equal? (variant-form (car (expansions "&"))) "and")
  ;; The scribal signs are off unless the house is one that used them. The
  ;; Folio has none in twelve thousand words, so this is the right default.
  (check-false (for/or ([v (in-list (contractions "them"))])
                 (string=? (variant-form v) "thē"))
               "no tilde unless asked for")
  (check-false (for/or ([v (in-list (contractions "the"))])
                 (regexp-match? #px"yᵉ" (variant-form v)))
               "no y-e unless asked for")
  ;; With them enabled, the rules still hold: never on the first letter ...
  (check-false (for/or ([v (in-list (contractions "Enter" #:tilde? #t #:brevigraph? #t))])
                 (regexp-match? #px"^[ĀĒĪŌŪ]" (variant-form v))))
  ;; ... and not before g, where n belongs to a digraph ...
  (check-false (for/or ([v (in-list (contractions "King" #:tilde? #t #:brevigraph? #t))])
                 (regexp-match? #px"ī" (variant-form v))))
  ;; ... but it does apply to a final nasal.
  (check-not-false (for/or ([v (in-list (contractions "them" #:tilde? #t #:brevigraph? #t))])
                     (string=? (variant-form v) "thē")))
  ;; The gate. A device may only produce a spelling somebody actually used or
  ;; the period approved; the nine forms below are neither, and were invented
  ;; by rule. Nothing here should be able to reach the compositor's stick.
  (for ([bad (in-list '("theere" "wheere" "manne" "somme" "welle"
                        "wille" "himme" "themme" "whenne"))])
    (define from (regexp-replace #px"(e|m|l)\\1?e?$" bad "\\1"))
    (check-false
     (for/or ([v (in-list (append (expansions from) (contractions from)))])
       (string=? (string-downcase (variant-form v)) bad))
     (format "no device may produce ~s" bad)))

  ;; But signs are not spellings, and no word list can vouch for them. The
  ;; ampersand and the stroke standing for a nasal must survive the gate.
  (check-not-false (for/or ([v (in-list (contractions "them" #:tilde? #t #:brevigraph? #t))])
                     (string=? (variant-form v) "thē"))
                   "the nasal stroke is a sign, not a spelling")

  ;; The ampersand is not a scribal sign and stays available: the Folio has
  ;; fourteen of them in the same twelve thousand words.
  (check-not-false (for/or ([v (in-list (contractions "and"))])
                     (string=? (variant-form v) "&")))

  ;; Patterns
  (let-values ([(form rule) (pattern-form "beauty" "A")])
    (check-equal? form "beautie"))
  (let-values ([(form rule) (pattern-form "beauty" "B")])
    (check-false form "B already agrees"))
  ;; Scoped to a crew, -ie discriminates: A sets it and B does not.
  (let-values ([(rule who) (pattern-witness "beautie" '("A" "B"))])
    (check-equal? who "A"))
  ;; Put two men who both set -ie at the same frames and it stops being
  ;; evidence, which is the whole purpose of the check.
  (let-values ([(rule who) (pattern-witness "beautie" '("A" "OkesC"))])
    (check-false who "both these men set -ie, so it names neither"))
  ;; And a man who is not in the shop cannot spoil the evidence of one who is.
  (let-values ([(rule who) (pattern-witness "beautie" '("OkesC" "OkesB"))])
    (check-equal? who "OkesC"))
  (let-values ([(rule who) (pattern-witness "my")])
    (check-false who "too short to be evidence"))

  ;; The dated scribal rates, measured from 5,287 EEBO-TCP books. What matters
  ;; is not the individual figures but that the thing has a slope at all: the
  ;; practice falls away by a factor of fifteen across the period the program
  ;; covers, so no single rate could ever have been right.
  (check-true (> (scribal-rate 1585) (scribal-rate 1605) (scribal-rate 1635))
              "the tilde dies away across the period")
  (check-= (scribal-rate 1585) 2.99 0.001)
  (check-= (scribal-rate 1635) 0.19 0.001)
  (check-equal? (scribal-rate 1500) (scribal-rate 1580) "flat below the range")
  (check-equal? (scribal-rate 1700) (scribal-rate 1630) "and flat above it")

  ;; The gate is a probability, so it must stay one.
  (check-true (< 0 (tilde-chance 1585) 1.0))
  (check-true (< (tilde-chance 1635) (tilde-chance 1585)))

  ;; The two devices are gated apart, because they had different fates. The
  ;; tilde crossed over from the hand into print; `y-t' and `w-ch' did not.
  (check-true (< BREVIGRAPH-SHARE 0.05)
              "a brevigraph is a small fraction of an already rare thing")
  (check-not-false (for/or ([v (in-list (contractions "them" #:tilde? #t))])
                     (regexp-match? #rx"[āēīōū]" (variant-form v)))
                   "the tilde is offered when allowed")
  (check-false (for/or ([v (in-list (contractions "them" #:tilde? #f))])
                 (regexp-match? #rx"[āēīōū]" (variant-form v)))
               "and withheld when not")
  (check-not-false (for/or ([v (in-list (contractions "that" #:brevigraph? #t))])
                     (string=? (variant-form v) "yᵗ"))
                   "the brevigraph likewise")
  (check-false (for/or ([v (in-list (contractions "that" #:brevigraph? #f))])
                 (string=? (variant-form v) "yᵗ"))))
