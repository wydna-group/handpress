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

(require racket/string racket/list racket/match "metrics.rkt")

(provide (struct-out variant) (struct-out conventions)
         SPELLING-TESTS SPELLING-PATTERNS
         head-form preferred pattern-form pattern-witness
         contractions expansions
         apply-conventions strip-conventions
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
   (list "final -ie for -y"
         #px"^(?i:(.{2,}?[bcdfghjklmnpqrstvwxz])(ie|y))$"
         (hash "A" "ie" "B" "y"))
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
(define (pattern-witness word)
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
            (for/list ([(k v) (in-hash forms)] #:when (string=? v ending)) k))
          ;; A form that several workmen would all have set is no evidence of
          ;; any of them. The elided ending is a habit of the house as much as
          ;; of the man, so it must not be counted as a discriminant.
          (if (= 1 (length whos)) (values name (car whos)) (values #f #f))]
         [else (loop (cdr ps))])])))

;; ---------------------------------------------------------------------------
;; Necessity: the ladder of contractions and expansions
;; ---------------------------------------------------------------------------

;; An alternative form, with what it costs or saves.
(struct variant (form delta device) #:transparent)

(define scribal
  (hash "the" "yᵉ" "that" "yᵗ" "which" "wᶜʰ" "with" "wᵗʰ"
        "your" "yᵒʳ" "our" "oᵘʳ" "sir" "ſʳ"))

(define tilde
  (hash #\a #\ā #\e #\ē #\i #\ī #\o #\ō #\u #\ū
        #\A #\Ā #\E #\Ē #\I #\Ī #\O #\Ō #\U #\Ū))

;; Words whose full form the trade kept in stock for stretching a line.
(define long-forms
  (hash "be" "bee" "we" "wee" "me" "mee" "he" "hee" "she" "shee"
        "do" "doe" "go" "goe" "so" "soe" "no" "noe"
        "to" "too" "by" "bye" "here" "heere"
        "there" "theere" "where" "wheere" "only" "onely"
        "sun" "sunne" "run" "runne" "sin" "sinne" "won" "wonne"
        "man" "manne" "some" "somme" "well" "welle" "will" "wille"
        "king" "kinge" "thing" "thinge" "such" "suche" "much" "muche"
        "old" "olde" "cold" "colde" "bold" "bolde" "wild" "wilde"
        "him" "himme" "them" "themme" "when" "whenne"))

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
(define (contractions word #:scribal? [scribal? #f])
  (define-values (core tail) (split-point word))
  (define base (w word))
  (define lcore (string-downcase core))
  (define (add form device) (variant form (- (w form) base) device))
  (sort
   (filter values
    (list
     ;; 1. the scribal abbreviations, inherited from the manuscript hand.
     ;;    Off unless the house is one that used them; see `conventions'.
     (and scribal? (hash-has-key? scribal lcore)
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
     (and scribal? (tilde-contraction core tail add))))
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
  (define (add form device) (variant form (- (w form) base) device))
  (sort
   (filter values
    (list
     (and (string=? core "&") (add (string-append "and" tail) "and for &"))
     (and (hash-has-key? long-forms lcore)
          (add (string-append (match-case core (hash-ref long-forms lcore)) tail)
               (format "full form ~a" (hash-ref long-forms lcore))))
     ;; terminal -e added to a word ending in a consonant
     (and (> len 2)
          (memv (string-ref lcore (sub1 len)) (string->list "bdfgklmnprstvz"))
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
(struct conventions (long-s? uv? ij? ligatures? [scribal? #:auto])
  #:transparent #:auto-value #f)

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
  (check-false (for/or ([v (in-list (contractions "Enter" #:scribal? #t))])
                 (regexp-match? #px"^[ĀĒĪŌŪ]" (variant-form v))))
  ;; ... and not before g, where n belongs to a digraph ...
  (check-false (for/or ([v (in-list (contractions "King" #:scribal? #t))])
                 (regexp-match? #px"ī" (variant-form v))))
  ;; ... but it does apply to a final nasal.
  (check-not-false (for/or ([v (in-list (contractions "them" #:scribal? #t))])
                     (string=? (variant-form v) "thē")))
  ;; The ampersand is not a scribal sign and stays available: the Folio has
  ;; fourteen of them in the same twelve thousand words.
  (check-not-false (for/or ([v (in-list (contractions "and"))])
                     (string=? (variant-form v) "&")))

  ;; Patterns
  (let-values ([(form rule) (pattern-form "beauty" "A")])
    (check-equal? form "beautie"))
  (let-values ([(form rule) (pattern-form "beauty" "B")])
    (check-false form "B already agrees"))
  (let-values ([(rule who) (pattern-witness "beautie")])
    (check-equal? who "A"))
  (let-values ([(rule who) (pattern-witness "my")])
    (check-false who "too short to be evidence")))
