#lang racket/base
;;; What the bibliographer could actually see.
;;;
;;; `typecase.rkt' decides which pieces of type are *distinctive* -- which
;;; ones carry an injury at all. That is a fact about the metal. Whether a
;;; distinctive piece can be *identified*, repeatedly and with confidence,
;;; across the pages it prints in, is a different fact, about the man with the
;;; collating machine, and it is settled here.
;;;
;;; Keeping the two apart matters more than it looks. Until this module
;;; existed the analysis was handed every distinctive piece in the fount,
;;; perfectly labelled and with every one of its appearances known -- which is
;;; not evidence, it is the answer. Hinman had no such thing, and the whole
;;; point of grading type-recurrence inference against the truth (roadmap §1)
;;; is lost if the analyst is given the truth to start from.
;;;
;;; How far apart the two are is measurable, and the measurement is the reason
;;; this module is here. At the default fount condition the model puts 27.2
;;; distinctive types on a folio page (± 1.2 over five seeds). Blayney counts
;;; Hinman's actual harvest from the Folio _Lear_: "314 appearances of
;;; distinctive types in the pages of Lear, which gives a density of
;;; approximately 23 per forme, or 11-12 per page" (i. 96). So the metal is
;;; roughly twice as informative as the man -- and it is the man's figure that
;;; every published type-recurrence argument rests on.
;;;
;;; Note which way that cuts before reading on. The gap is *not* evidence that
;;; the fount is too battered: `CONDITIONS` in typecase.rkt says how much of
;;; the metal is damaged, and Hinman's 11-12 is a count of what one man could
;;; identify. Two different quantities, and the honest fix is to model the
;;; difference rather than to adjust the fount until the two happen to agree.
;;; Adjusting the fount would have been the tidier-looking change and it would
;;; have made the type case wrong to make a report right.
;;;
;;; Hinman states the difference himself, at length (i. 54-6), and most of what
;;; he says is a rule rather than a rate. Two of his rules are encoded here
;;; exactly as he gives them, with no free parameter:
;;;
;;;   The vulnerable ascenders. "Types of certain sorts, indeed, are often
;;;   similarly damaged, since these sorts are especially vulnerable to injury
;;;   of a particular kind: the ascenders of the lower-case letters 'b', 'd',
;;;   and 'h', for example, are so frequently bent or broken that such defects
;;;   in these letters are practically useless as means of identifying
;;;   individual types."
;;;
;;;   Confusable pieces. "a type that is certainly unique in one part of the
;;;   book, and so is useful there, may later become useless through the
;;;   appearance of a similarly deformed type. Or two or more distinctive
;;;   types may be valueless as evidence because defective in so nearly the
;;;   same way that they cannot always be clearly distinguished from each
;;;   other."
;;;
;;; The second is the interesting one, because it is the reason evidence does
;;; not simply scale with decay. A fouler fount holds more distinctive pieces
;;; and also more pieces damaged alike, so past some point further battering
;;; buys nothing. Nothing had to be assumed to get that: it falls out of
;;; counting the model's own pieces.
;;;
;;; Both rules turn on being able to tell one injury from another, and there
;;; is exactly one free parameter here: `discrimination', the finest
;;; difference in an injury an investigator can reliably see. It is stated
;;; against `sort-piece-severity', which is a rank on [0,1) rather than a
;;; measurement, so it reads as a percentile: at 0.15 he can separate two
;;; injuries a seventh of the range apart and no closer.
;;;
;;; One parameter, because Hinman's two remaining observations are the same
;;; observation. If injuries closer together than d cannot be told apart, then
;;; (1) an injury slighter than d cannot be told from no injury at all, which
;;; is his "some defective types have in fact no practical value as evidence
;;; because their imperfections are so slight"; and (2) two pieces of a sort
;;; whose injuries fall within d of each other cannot be told from one
;;; another, which is his pair "defective in so nearly the same way that they
;;; cannot always be clearly distinguished". A floor and a collision rule out
;;; of one quantity, rather than two knobs that could be traded off against
;;; each other.
;;;
;;; This replaced a first attempt that keyed confusability on the sort and the
;;; damage *name* alone. It was wrong, and measurably: `damage-vocabulary' has
;;; ten names for injuries that Hinman says are "almost infinitely various",
;;; so the common sorts collided wholesale and the rule threw away 220 of 325
;;; pieces by itself -- taking a folio to 8 types a page when Hinman's own
;;; harvest was 11-12, before any other loss was applied. The strength of the
;;; rule was a fact about the length of a list in this file. What decides
;;; whether two injuries are confusable has to be how far apart they are.
;;;
;;; `discrimination' is calibrated, not guessed -- see DISCRIMINATION-NOTE for
;;; what that does and does not license.

(require racket/list racket/set racket/string "typecase.rkt" "imposition.rkt")

(provide recurrence-evidence
         (struct-out evidence)
         evidence-by-page identifiable-pieces
         confusable? too-slight? vulnerable-ascender?
         turner-table (struct-out turner-pair) true-first-forme
         DEFAULT-DISCRIMINATION DISCRIMINATION-NOTE current-discrimination)

;; ---------------------------------------------------------------------------
;; Hinman's two rules
;; ---------------------------------------------------------------------------

;; b, d and h take bent or broken ascenders so often that the injury does not
;; single a piece out. Our damage vocabulary spells that injury three ways:
;; `bent' (which any sort can take), and `chipped' and `cracked-stem', both of
;; which are drawn only for sorts with an ascender.
(define VULNERABLE-SORTS (string->list "bdh"))
(define ASCENDER-INJURIES '(bent chipped cracked-stem))

(define (vulnerable-ascender? p)
  (and (memv (sort-piece-char p) VULNERABLE-SORTS)
       (memq (sort-piece-damage p) ASCENDER-INJURIES)
       #t))

;; An injury slighter than the investigator can resolve is no injury to him:
;; the piece prints like any other of its sort. Hinman: "Some defective types
;; have in fact no practical value as evidence because their imperfections are
;; so slight."
(define (too-slight? p d) (< (sort-piece-severity p) d))

;; Two pieces are confusable when they are the same sort, injured in the same
;; way, and injured to within `d' of the same degree. All three have to hold:
;; a nicked `e' is not mistaken for a nicked `o', nor for a battered `e', nor
;; for an `e' nicked far harder.
;;
;; Note what this does as a fount decays. More pieces in the same sort means
;; they crowd the severity range and more of them fall within `d' of a
;; neighbour, so evidence does not scale with damage -- past a point, further
;; battering destroys more evidence than it creates. Nothing was assumed to
;; get that; it falls out of counting the model's own pieces, and it is a
;; prediction roadmap §1 can test at any fount condition.
(define (confusable? p q d)
  (and (not (eq? p q))
       (char=? (sort-piece-char p) (sort-piece-char q))
       (eq? (sort-piece-damage p) (sort-piece-damage q))
       (< (abs (- (sort-piece-severity p) (sort-piece-severity q))) d)))

;; ---------------------------------------------------------------------------
;; Discrimination
;; ---------------------------------------------------------------------------

;; The finest difference between two injuries that an investigator can
;; reliably see, as a fraction of the range of injuries: at 0.26 he can
;; separate two injuries about a quarter of the range apart and no closer.
;;
;; Anchored on Hinman's own harvest. Blayney counts what Hinman actually got
;; out of the Folio _Lear_ -- "314 appearances of distinctive types in the
;; pages of Lear, which gives a density of approximately 23 per forme, or
;; 11-12 per page" (i. 96) -- and at 0.26 a folio at the default fount
;; condition yields 11.5 identifiable types a page (± 0.9 over five seeds,
;; areopagitica.txt, preliminary scheme pinned). That also sits inside
;; Hinman's own description of the harvest, "from eight or ten to well over a
;; score ... in almost every page of the Folio" (i. 56).
;;
;; **The quarto was a check and it used to pass; it no longer does.** Blayney
;; argues from the type-area that a quarto page at the same fount condition
;; would leave an investigator "no more than 5 or 6 types per page". At the old
;; 0.20 and the old 16-em folio the quarto gave 5.3 ± 0.5 and both fitted at
;; one value. With the folio measure corrected the folio needs 0.26 and the
;; quarto then reads about 4.3. See the note on DEFAULT-DISCRIMINATION: the
;; disagreement is evidence about the type-area ratio and is left in view.
;;
;; One anchor even so, and it is worth saying which end of the range it sits
;; at. This is the Folio: a worn pica in the largest house in London, examined
;; by the most careful practitioner the method has had, with eighty-odd copies
;; and a collating machine to compare them on. It is a *ceiling* on what a
;; bibliographer sees, not a typical value, and roadmap §4 records what
;; happened the last time a parameter here was anchored on Jaggard and treated
;; as ordinary. Blayney says as much of the field: most quarto investigators
;; "have used rather less evidence per forme than did Hinman."
;; **Re-anchored after the folio measure was corrected, and the first anchor
;; is a warning worth keeping.** This was 0.20, fitted when `FOLIO' carried an
;; unsourced 16-em measure. Hinman's own 20 ems put a quarter more type on the
;; page, so the same eye found a quarter more evidence on it: 14.1 identifiable
;; types a page against his 11-12, and 18.9 on the whole Folio, where the extra
;; came from a long book battering more type as it went. The parameter had not
;; changed and was no longer calibrated, because what it was calibrated
;; *against* had. A number fitted to one version of a model is not a
;; measurement of anything once that model moves; date the fit or it rots.
;;
;; 0.26 puts a folio at 11.5 a page, inside Hinman's 11-12.
;;
;; **The quarto check no longer passes at the same value, and that is left
;; standing.** At 0.26 a quarto gives about 4.3 where Blayney predicts 5-6.
;; The two agreed at 0.20 and no longer do, which says something about the
;; model rather than about the parameter: Blayney's reasoning is that a quarto
;; page holds "half (or somewhat less than half) the type-area of a folio
;; page", and ours holds 798 ems against the folio's 2,640 -- 30%, not half.
;; So either the quarto measure or the folio's is still wrong, and tuning
;; discrimination until both fit would bury the discrepancy that says so.
(define DEFAULT-DISCRIMINATION 0.26)

(define DISCRIMINATION-NOTE
  (string-append
   "discrimination is anchored on Hinman's Folio -- the best-equipped "
   "type-recurrence study there has been -- so it is a ceiling on what an "
   "investigator sees rather than a typical value."))

;; How good the investigator's eye is, for the length of one analysis. A
;; parameter rather than an argument threaded through the reports, because it
;; belongs to no one report: it describes the man reading the book, and the
;; whole analysis has to describe the same man or its sections will disagree
;; about what evidence exists. Nothing in the printing house may read it.
(define current-discrimination (make-parameter DEFAULT-DISCRIMINATION))

;; ---------------------------------------------------------------------------
;; The evidence a bibliographer would have
;; ---------------------------------------------------------------------------

;; `present'      -- distinctive pieces in the fount, by id
;; `identifiable' -- those an investigator can use, by id
;; `lost'         -- how many went each way, for the report
;; `places'       -- id -> list of places, filtered to the identifiable
(struct evidence (present identifiable lost places) #:transparent)

;; Which pieces the investigator can use. Every distinctive piece the case
;; ever held is considered, whether it printed or not, because the rules are
;; about the metal and the eye and not about where the piece happened to go.
;;
;; There is no random draw here at all, which is the point of putting severity
;; on the piece: the injury was dealt by the printing house and is part of the
;; book, and what the investigator makes of it is then a matter of rule. Two
;; investigators of equal discrimination looking at one book see exactly the
;; same evidence, and the same investigator looking at it twice sees it twice.
;; The alternative -- drawing his eyesight per piece as the analysis ran --
;; would have made the evidence shift whenever anything upstream in the
;; *printing* moved the RNG stream, which is the trap roadmap §4 records.
(define (identifiable-pieces pieces #:discrimination [d (current-discrimination)])
  ;; Group by sort and injury so confusability is checked among the pieces
  ;; that could possibly be confused, rather than against all of them. Only
  ;; pieces the investigator can see at all go in: a piece whose injury is
  ;; below his discrimination prints like a sound type, and a sound type is
  ;; not what anything is mistaken for. Letting the invisible ones confuse the
  ;; visible would have a swarm of near-perfect pieces destroying good
  ;; evidence, which is backwards.
  (define cells (make-hash))
  (for ([p (in-list pieces)] #:unless (too-slight? p d))
    (hash-update! cells (cons (sort-piece-char p) (sort-piece-damage p))
                  (lambda (xs) (cons p xs)) '()))
  (define lost-ascender 0)
  (define lost-slight 0)
  (define lost-confusable 0)
  (define keep
    (for/list ([p (in-list pieces)]
               #:when (cond
                        [(vulnerable-ascender? p)
                         (set! lost-ascender (add1 lost-ascender)) #f]
                        [(too-slight? p d)
                         (set! lost-slight (add1 lost-slight)) #f]
                        [(for/or ([q (in-list (hash-ref cells
                                                        (cons (sort-piece-char p)
                                                              (sort-piece-damage p))
                                                        '()))])
                           (confusable? p q d))
                         (set! lost-confusable (add1 lost-confusable)) #f]
                        [else #t]))
      p))
  (values keep
          (list (cons 'vulnerable-ascender lost-ascender)
                (cons 'too-slight lost-slight)
                (cons 'confusable lost-confusable))))

;; The whole filter, applied to a finished type case.
(define (recurrence-evidence tc #:discrimination [d (current-discrimination)])
  (define all (all-pieces tc))
  (define-values (keep lost) (identifiable-pieces all #:discrimination d))
  (define ids (for/set ([p (in-list keep)]) (sort-piece-id p)))
  (define rec (tcase-recurrence tc))
  (evidence (for/set ([p (in-list all)]) (sort-piece-id p))
            ids
            lost
            (for/hash ([(id places) (in-hash rec)] #:when (set-member? ids id))
              (values id places))))

;; ---------------------------------------------------------------------------
;; Turner's rule
;; ---------------------------------------------------------------------------
;; "in a quarto set by formes, type from the first forme of each sheet normally
;; reappears in both formes of the succeeding sheet, but type from the second
;; forme only in the second forme of the succeeding sheet" -- Turner, SB xviii
;; (1965), 258, quoted by Blayney i. 91.
;;
;; The mechanism is sound. A forme is distributed when it comes off the press,
;; so the forme finished first has its type back in the cases sooner and can
;; turn up anywhere in the next sheet; the forme finished second is distributed
;; later and its type can only reach whatever was still unset.
;;
;; Turner's *further* claim is the one worth testing: that "when type reappears
;; in this manner, composition cannot have been seriatim". Blayney calls this
;; "completely untrue" and gives the reason -- under seriatim setting "a
;; distribution after the third page will be evident in the fourth to seventh
;; pages ('both formes'), and a second distribution after the seventh page will
;; be evident in the eighth (the 'second forme' completed)". The same pattern,
;; from a different cause.
;;
;; This program knows which method it used, so the claim can be scored instead
;; of argued. And there is a real difference for it to find, which is what
;; makes the test worth running rather than a foregone conclusion: in a quarto
;; the outer forme holds pages 1, 4, 5, 8 and the inner 2, 3, 6, 7, so setting
;; by formes completes the OUTER first (it is set as a block, 1 4 5 8, then
;; 2 3 6 7) while setting seriatim completes the INNER first (its last page is
;; 7, the outer's is 8). The two methods really do finish different formes
;; first. Whether the recurrence evidence can see it is the question.
;;
;; Blayney's deeper objection is the one this module was built to make
;; measurable. The rule reads a *negative*: "type from the second forme only in
;; the second forme" is a claim about where type is absent, and "the failure to
;; detect B(i) evidence in certain pages has to be trusted to indicate that no
;; such evidence exists, whereas the absence of B(o) evidence has to be ascribed
;; to a failure to detect what is really present." An imperfect eye manufactures
;; absence. So the rule should decay as `discrimination' coarsens, and the run
;; can be done at any acuity to see how fast.

;; Does this signature belong to the series its sheet is named for? "A1r" is
;; native to "A sheet 1"; "*1r" printed in the white paper of "H sheet 1" is
;; not native to it.
(define (native-leaf? sig sheet)
  (define mark (car (string-split sheet)))
  (string-prefix? sig mark))

;; `counts' maps (from-side . to-side) to the number of distinct identifiable
;; pieces shared. `first-forme' is the side the rule names as set first, or #f
;; where the evidence does not separate them. `pattern?' is Turner's condition:
;; one forme's type in both formes of the next sheet, the other's in one only.
(struct turner-pair (from to counts first-forme pattern?) #:transparent)

;; `pages' is (list signature sheet-key side), in the order the sheets were
;; printed. The bibliographer has all three without knowing anything about the
;; setting: a signature is on the leaf, and which pages share a forme follows
;; from the format and the fold.
(define (turner-table ev pages)
  (define by-page (evidence-by-page ev))
  (define tbl (make-hash))
  (define first-seen (make-hash))
  (for ([p (in-list pages)] [i (in-naturals)])
    (define sh (second p))
    ;; A leaf signed outside its sheet's own series was printed in that sheet's
    ;; white paper and cut out, so it says nothing about when the sheet was
    ;; worked. Only a sheet's *native* leaves date it.
    ;;
    ;; This is not fastidiousness. `book-pages' is in binding order and the
    ;; preliminaries are printed last and bound first, so the raw order of a
    ;; quarto whose prelims were cut from the last sheet reads H, A, B ... G --
    ;; which produced a confident table for the pair "H -> A", a sheet printed
    ;; last against one printed first, and quietly dropped the real G -> H.
    ;; Turner's rule is about *succeeding* sheets and nothing else.
    (when (native-leaf? (first p) sh)
      (hash-update! first-seen sh (lambda (j) (min j i)) i))
    (hash-update! tbl (cons sh (third p))
                  (lambda (s) (set-union s (hash-ref by-page (first p) (set))))
                  (set)))
  (define sheets
    (sort (hash-keys first-seen) < #:key (lambda (sh) (hash-ref first-seen sh))))
  (define (sides-of sh)
    (sort (for/list ([k (in-hash-keys tbl)] #:when (equal? (car k) sh)) (cdr k))
          string<?))
  (for/list ([a (in-list sheets)] [b (in-list (if (null? sheets) '() (cdr sheets)))]
             ;; A sheet worked and turned has one forme, so there is no pair of
             ;; formes to compare and the rule cannot speak. Excluded rather
             ;; than counted as a failure: it is not evidence either way.
             #:when (and (= 2 (length (sides-of a))) (= 2 (length (sides-of b)))))
    (define from-sides (sides-of a))
    (define to-sides (sides-of b))
    (define counts
      (for*/hash ([f (in-list from-sides)] [t (in-list to-sides)])
        (values (cons f t)
                (set-count (set-intersect (hash-ref tbl (cons a f) (set))
                                          (hash-ref tbl (cons b t) (set)))))))
    (define (reach f)
      (for/sum ([t (in-list to-sides)]) (if (> (hash-ref counts (cons f t) 0) 0) 1 0)))
    (define spread (for/list ([f (in-list from-sides)]) (cons f (reach f))))
    (define both (for/list ([s (in-list spread)] #:when (= 2 (cdr s))) (car s)))
    (define one  (for/list ([s (in-list spread)] #:when (= 1 (cdr s))) (car s)))
    ;; Turner's pattern proper: exactly one forme reaching both, exactly one
    ;; reaching a single forme. Anything else -- both reaching both, both
    ;; reaching one, either reaching none -- is evidence that does not speak,
    ;; and is reported as such rather than forced into a verdict.
    (define pattern? (and (= 1 (length both)) (= 1 (length one))))
    (turner-pair a b counts (and pattern? (car both)) pattern?)))

;; THE ANSWER KEY, and it is not evidence. This reads the imposition scheme and
;; the setting method, which together are precisely what the rule above is
;; trying to find out. It is here so that the rule can be scored, and nothing
;; that models a bibliographer may call it.
;;
;; A forme is distributed when it comes off the press, so the one that finishes
;; first is the one whose LAST page comes first in the setting order. That is
;; what makes the two methods differ: set by formes the outer goes 1 4 5 8 as a
;; block and is done at position 4; set seriatim the inner's last page is 7 and
;; the outer's is 8, so the inner is done first.
;; The answer is a fact about a SHEET, and it used to be asked of a gathering.
;; A quarto gathering is one sheet, so `(= 2 (length done))' held and the guard
;; was invisible; a folio in sixes is three sheets quired one within another, so
;; `done' had six entries, the guard failed, and this returned #f for the whole
;; format. Nothing downstream tested for that, so `turner-report' scored every
;; pattern against #f, printed a hard `0 of 37 times', and put the false itself
;; on the page as "the #f forme". A rule that cannot be scored read as a rule
;; that is always wrong -- which is this project's own lesson about a bare zero,
;; arriving in the one place that had no test.
(define (true-first-forme fmt by-formes? [gathering 0])
  (define order (setting-order fmt gathering by-formes?))
  (define pos (for/hash ([p (in-list order)] [i (in-naturals)]) (values p i)))
  ;; A forme is distributed when it comes off the press, so it finishes with its
  ;; last page.
  (define (finished fm)
    (apply max (for/list ([p (in-list (forme-page-numbers fm))])
                 (hash-ref pos p 0))))
  (define by-sheet (make-hash))
  (for ([fm (in-list (formes-for-gathering fmt gathering))])
    (hash-update! by-sheet (forme-sheet fm)
                  (lambda (l) (cons (cons (forme-side fm) (finished fm)) l))
                  '()))
  ;; A sheet worked and turned has one forme and no order to have; it is left
  ;; out rather than counted. Where the sheets of a gathering disagree there is
  ;; no single answer for the book and the honest return is #f, which the report
  ;; now handles.
  (define answers
    (for/list ([(_ sides) (in-hash by-sheet)] #:when (= 2 (length sides)))
      (car (argmin cdr sides))))
  (and (pair? answers)
       (for/and ([a (in-list answers)]) (equal? a (car answers)))
       (car answers)))

;; page signature -> the identifiable types visible on it. A type setting more
;; than once in one page counts once: what the investigator has is a list of
;; which types are where, and the same piece twice on a page tells him no more
;; about the order of the formes than once does.
(define (evidence-by-page ev)
  (define h (make-hash))
  (for* ([(id places) (in-hash (evidence-places ev))]
         [pl (in-list places)])
    (hash-update! h (car pl) (lambda (s) (set-add s id)) (set)))
  h)

(module+ test
  (require rackunit)

  ;; Hinman's ascender rule, and its edges. A bent `b' is useless; a bent `e'
  ;; is not, because `e' has no ascender to be the ordinary casualty; and a
  ;; `b' damaged some other way is still good evidence -- it is the *pairing*
  ;; of those sorts with that injury he rules out, not either alone.
  (check-true  (vulnerable-ascender? (sort-piece "t1" #\b 'bent 0.9)))
  (check-true  (vulnerable-ascender? (sort-piece "t2" #\h 'cracked-stem 0.9)))
  (check-true  (vulnerable-ascender? (sort-piece "t3" #\d 'chipped 0.9)))
  (check-false (vulnerable-ascender? (sort-piece "t4" #\e 'bent 0.9))
               "e takes no ascender injury; nothing ordinary about it")
  (check-false (vulnerable-ascender? (sort-piece "t5" #\b 'nicked-bowl 0.9))
               "a nicked bowl on a b is still a distinctive b")
  (check-false (vulnerable-ascender? (sort-piece "t6" #\k 'bent 0.9))
               "k has an ascender but is not one of the three Hinman names")

  ;; Two pieces of a sort damaged the same way and to nearly the same degree
  ;; take each other out. The third is the same injury far harder, and stands.
  (let-values ([(keep lost)
                (identifiable-pieces
                 (list (sort-piece "a1" #\e 'battered 0.50)
                       (sort-piece "a2" #\e 'battered 0.54)
                       (sort-piece "a3" #\e 'battered 0.90))
                 #:discrimination 0.1)])
    (check-equal? (map sort-piece-id keep) '("a3")
                  "the near pair cancel; the odd one stands")
    (check-equal? (cdr (assq 'confusable lost)) 2))

  ;; The same three pieces under a sharper eye: 0.04 apart is now separable
  ;; and all three survive. The rule is about how far apart the injuries are,
  ;; not about how many of them share a name.
  (let-values ([(keep _l)
                (identifiable-pieces
                 (list (sort-piece "a1" #\e 'battered 0.50)
                       (sort-piece "a2" #\e 'battered 0.54)
                       (sort-piece "a3" #\e 'battered 0.90))
                 #:discrimination 0.02)])
    (check-equal? (length keep) 3))

  ;; All three parts of the confusability key are load-bearing: same degree
  ;; but a different sort, or a different injury, is not a confusion.
  (let-values ([(keep lost)
                (identifiable-pieces
                 (list (sort-piece "b1" #\e 'battered 0.50)
                       (sort-piece "b2" #\o 'battered 0.50)
                       (sort-piece "b3" #\e 'worn 0.50))
                 #:discrimination 0.1)])
    (check-equal? (length keep) 3)
    (check-equal? (cdr (assq 'confusable lost)) 0))

  ;; A piece too slight to see does not take a good one down with it. Without
  ;; this, a swarm of near-perfect pieces would destroy the best evidence in
  ;; the fount, which is backwards.
  (let-values ([(keep lost)
                (identifiable-pieces
                 (list (sort-piece "c1" #\e 'battered 0.02)
                       (sort-piece "c2" #\e 'battered 0.09))
                 #:discrimination 0.1)])
    (check-equal? keep '() "both below the threshold")
    (check-equal? (cdr (assq 'too-slight lost)) 2)
    (check-equal? (cdr (assq 'confusable lost)) 0
                  "counted as slight, not as confusable"))
  (let-values ([(keep _l)
                (identifiable-pieces
                 (list (sort-piece "c3" #\e 'battered 0.05)
                       (sort-piece "c4" #\e 'battered 0.12))
                 #:discrimination 0.1)])
    (check-equal? (map sort-piece-id keep) '("c4")
                  "the invisible piece does not confuse the visible one"))

  ;; Twenty sorts and the ten injuries: two hundred cells, one piece in each,
  ;; all severe. The sorts deliberately exclude b, d and h, so no rule can
  ;; fire and the whole two hundred survive.
  (define SAFE-SORTS (string->list "acefgijklmnopqrstuvw"))
  (define ALL-DAMAGE (map car damage-vocabulary))
  (define sample
    (for/list ([i (in-range 200)])
      (sort-piece (format "s~a" i) (list-ref SAFE-SORTS (modulo i 20))
                  (list-ref ALL-DAMAGE (quotient i 20)) 0.8)))
  (let-values ([(keep _l) (identifiable-pieces sample #:discrimination 0.1)])
    (check-equal? (length keep) 200 "nothing to confuse and nothing too slight"))
  (let-values ([(keep _l) (identifiable-pieces sample #:discrimination 0.9)])
    (check-equal? keep '() "an eye this blunt sees 0.8 as no injury at all"))

  ;; Nothing here is drawn, so the same book read twice reads the same. This
  ;; is what keeps the evidence from moving when something unrelated upstream
  ;; in the printing shifts the RNG stream.
  (let-values ([(k1 _1) (identifiable-pieces sample #:discrimination 0.1)]
               [(k2 _2) (identifiable-pieces sample #:discrimination 0.1)])
    (check-equal? (map sort-piece-id k1) (map sort-piece-id k2)))

  ;; Confusion rises with the number of pieces in a sort, which is the point
  ;; of the rule: battering a fount past some point stops buying evidence,
  ;; because the new injuries crowd the ones already there. Severities are
  ;; spread evenly so the effect is the crowding and not a lucky draw.
  (define (confused n)
    (define ps (for/list ([i (in-range n)])
                 (sort-piece (format "x~a" i) #\e 'battered
                             (+ 0.2 (* 0.8 (/ i (exact->inexact n)))))))
    (define-values (_k lost) (identifiable-pieces ps #:discrimination 0.1))
    (exact->inexact (/ (cdr (assq 'confusable lost)) n)))
  (check-equal? (confused 5) 0.0
                "0.16 apart in one sort: every one of them separable")
  (check-true (> (confused 40) 0.9)
              "0.02 apart: the sort is a crowd and almost none of it is evidence")

  ;; --- Turner's rule ------------------------------------------------------

  ;; Build an evidence record directly: `places' is id -> list of (sig ...),
  ;; which is all `turner-table' reads.
  (define (ev-of places)
    (define ids (list->set (hash-keys places)))
    (evidence ids ids '() places))
  (define (place . sigs) (for/list ([s (in-list sigs)]) (list s 0 0 0)))

  ;; Turner's pattern exactly: type from A-outer in both formes of B, type
  ;; from A-inner in B-inner only. The outer is named as set first.
  (define PAGES
    (list (list "A1r" "A sheet 1" "outer") (list "A1v" "A sheet 1" "inner")
          (list "B1r" "B sheet 1" "outer") (list "B1v" "B sheet 1" "inner")))
  (let* ([ev (ev-of (hash "t1" (place "A1r" "B1r" "B1v")
                          "t2" (place "A1v" "B1v")))]
         [tbl (turner-table ev PAGES)])
    (check-equal? (length tbl) 1)
    (check-true (turner-pair-pattern? (car tbl)))
    (check-equal? (turner-pair-first-forme (car tbl)) "outer"))

  ;; Both formes reaching both formes is not Turner's pattern, and must not be
  ;; forced into a verdict: it is evidence that does not speak.
  (let* ([ev (ev-of (hash "t1" (place "A1r" "B1r" "B1v")
                          "t2" (place "A1v" "B1r" "B1v")))]
         [tbl (turner-table ev PAGES)])
    (check-false (turner-pair-pattern? (car tbl)))
    (check-false (turner-pair-first-forme (car tbl))))

  ;; Neither forme reaching the next sheet is likewise silent, not a verdict.
  (let* ([ev (ev-of (hash "t1" (place "A1r") "t2" (place "A1v")))]
         [tbl (turner-table ev PAGES)])
    (check-false (turner-pair-pattern? (car tbl))))

  ;; The sheets must be paired in the order they were PRINTED. A preliminary
  ;; leaf cut from the white paper of the last sheet is bound first, so the
  ;; raw page order reads H, A, B -- and pairing H with A compares the sheet
  ;; printed last against the one printed first. The rule is about succeeding
  ;; sheets, so H belongs at the end.
  (define BOUND
    (list (list "*1r" "H sheet 1" "outer") (list "*1v" "H sheet 1" "inner")
          (list "A1r" "A sheet 1" "outer") (list "A1v" "A sheet 1" "inner")
          (list "B1r" "B sheet 1" "outer") (list "B1v" "B sheet 1" "inner")
          (list "H1r" "H sheet 1" "outer") (list "H1v" "H sheet 1" "inner")))
  (let* ([ev (ev-of (hash "t1" (place "A1r" "B1r" "B1v")))]
         [tbl (turner-table ev BOUND)])
    (check-equal? (map (lambda (tp) (cons (turner-pair-from tp) (turner-pair-to tp)))
                       tbl)
                  '(("A sheet 1" . "B sheet 1") ("B sheet 1" . "H sheet 1"))
                  "H is printed last however early it is bound"))

  ;; THE ANSWER KEY ITSELF. It had no test, and for as long as it had none it
  ;; returned #f at every format whose gathering is more than one sheet -- so
  ;; `turner-report' scored the rule against a false, printed "0 of 37 times",
  ;; and set the word "#f" in the report. The rule is about a sheet, and a
  ;; folio in sixes has three of them quired one within another.
  ;;
  ;; Set by formes the house works outward from the middle, 5 8 / 6 7 / 3 10 /
  ;; 4 9 / 1 12 / 2 11, so every sheet's outer forme finishes before its inner.
  ;; Set seriatim the pages go 1 .. 12, and the outer of each sheet holds the
  ;; LAST page of the two -- 12, 10, 8 -- so the inner finishes first. That
  ;; reversal is the whole reason the key can score the rule at all.
  (check-equal? (true-first-forme FOLIO-IN-SIXES #t) "outer"
                "folio in sixes, by formes: the outer of each sheet is done first")
  (check-equal? (true-first-forme FOLIO-IN-SIXES #f) "inner"
                "folio in sixes, seriatim: the inner of each sheet is done first")
  ;; And the quarto, the format Turner states the rule for, is unmoved by the
  ;; change: one sheet to the gathering, which is the case that always worked.
  (check-equal? (true-first-forme QUARTO #t) "outer")
  (check-equal? (true-first-forme QUARTO #f) "inner")
  ;; Never the false again, at any format the program can set.
  (for ([f (in-list (list FOLIO FOLIO-IN-SIXES QUARTO OCTAVO))])
    (for ([by-formes? (in-list '(#t #f))])
      (check-true (string? (true-first-forme f by-formes?))
                  (format "~a has an answer to score against"
                          (book-format-name f))))))
