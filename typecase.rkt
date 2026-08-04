#lang racket/base
;;; The pair of cases, the bill of type, and the accidents that follow.
;;;
;;; A compositor stands at a frame holding two cases. His hand goes to a box
;;; without his eye following it, which is why the *lay* of the case -- which
;;; box adjoins which -- is a bibliographical fact and not merely a fact about
;;; furniture. When a wrong letter is picked from an adjoining box the result
;;; is *foul case*, and because the lay was standard across the trade the
;;; resulting errors are predictable.
;;;
;;; Three further consequences are modelled here: turned letters (n and u are
;;; the same sort inverted); shortage of sorts, since type in a forme is
;;; locked up until that forme has been printed off and distributed; and the
;;; wrong-fount sort borrowed from another case when no shift will serve.

(require racket/list racket/math racket/string "rng.rkt")

(provide (struct-out draw) (struct-out tcase) (struct-out sort-piece)
         make-type-case pick! distribute! distribute-pieces! scarcest
         case-depletion take!
         ADJACENT TURNED-PAIRS FOUNT-SORTS
         LOWER-CASE-LEFT LOWER-CASE-RIGHT UPPER-CASE-LAY
         damage-vocabulary damage-for damage-phrase CONDITIONS batter!
         note-recurrence! sort-piece-note)

;; ---------------------------------------------------------------------------
;; The lay of the case
;; ---------------------------------------------------------------------------
;; The divided lay, English pattern, after Gaskell, _A New Introduction to
;; Bibliography_, fig. 23 (reproducing Smith, _The Printer's Grammar_, 1755);
;; see also Gaskell, 'The lay of the case', SB xxii (1969), 125-42.
;;
;; The essential thing is that the lower case is *divided*: two blocks with a
;; gap between them. Sorts in the left block do not adjoin sorts in the right,
;; so the two are separate grids and no adjacency is generated across the
;; division. This matters -- e and i are not neighbours, though a single
;; undivided grid would make them so.

(define LOWER-CASE-LEFT
  '((#\& #\b #\c #\d #\e)
    (#\ﬄ #\l #\m #\n #\h)
    (#\j #\z #\v #\u #\t)
    (#\x #f  #f  #f  #f)))

(define LOWER-CASE-RIGHT
  '((#\s #f  #\? #\! #\;)
    (#\i #\ſ #\f #\g #\ﬂ)
    (#\o #\y #\p #\q #\w)
    (#\a #\r #\, #\: #\.)))

;; The upper case. Note where J and U sit: both were late additions to the
;; alphabet and were given odd boxes after Z rather than a place in the run,
;; which is one reason i/j and u/v ride together in early printing.
(define UPPER-CASE-LAY
  '((#\A #\B #\C #\D #\E #\F #\G)
    (#\H #\I #\K #\L #\M #\N #\O)
    (#\P #\Q #\R #\S #\T #\V #\W)
    (#\X #\Y #\Z #\Æ #\J #\U #\Œ)
    (#\1 #\2 #\3 #\4 #\5 #\6 #\7)
    (#\8 #\9 #\0 #\¶ #\§ #\* #\—)))

(define (build-adjacency . lays)
  (define h (make-hash))
  (for ([lay (in-list lays)])
    (define rows (list->vector (map list->vector lay)))
    (for ([r (in-range (vector-length rows))])
      (define row (vector-ref rows r))
      (for ([c (in-range (vector-length row))])
        (define box (vector-ref row c))
        (when box
          (for ([d (in-list '((0 -1) (0 1) (-1 0) (1 0)))])
            (define rr (+ r (car d)))
            (define cc (+ c (cadr d)))
            (when (and (>= rr 0) (< rr (vector-length rows)))
              (define orow (vector-ref rows rr))
              (when (and (>= cc 0) (< cc (vector-length orow)))
                (define other (vector-ref orow cc))
                (when other
                  (hash-update! h box (lambda (xs) (cons other xs)) '())))))))))
  h)

;; sort -> adjoining sorts. The three grids are passed separately so that no
;; adjacency is generated across the division of the lower case, or between
;; the two cases.
(define ADJACENT
  (build-adjacency LOWER-CASE-LEFT LOWER-CASE-RIGHT UPPER-CASE-LAY))

(define LIGATURES (string->list "ﬀﬁﬂﬃﬄ"))

;; Foul case puts a letter where a letter belongs. A hand that strays one box
;; takes another letter; it does not return with a ligature in place of a mark
;; of punctuation.
(define (same-kind? a b)
  (cond
    [(or (memv a LIGATURES) (memv b LIGATURES)) #f]
    [(not (eq? (char-alphabetic? a) (char-alphabetic? b))) #f]
    [(char-alphabetic? a) (eq? (char-upper-case? a) (char-upper-case? b))]
    [else #t]))

;; Sorts that are one another inverted. A turned sort prints as its partner.
(define TURNED-PAIRS
  (hash #\n #\u  #\u #\n
        #\b #\q  #\q #\b
        #\d #\p  #\p #\d
        #\6 #\9  #\9 #\6))

;; The compositor's shifts when a box is empty, in order of preference.
(define SUBSTITUTIONS
  (hash #\W '("VV") #\w '("vv")
        #\ſ '("s")
        #\ﬀ '("ff") #\ﬁ '("fi") #\ﬂ '("fl") #\ﬃ '("ffi") #\ﬄ '("ffl")
        #\J '("I") #\U '("V") #\j '("i") #\u '("v")
        #\ā '("am") #\ē '("em") #\ō '("om") #\ū '("um")
        #\Ā '("Am") #\Ē '("Em") #\Ō '("Om") #\Ū '("Um")))

;; ---------------------------------------------------------------------------
;; The bill of type
;; ---------------------------------------------------------------------------
;; Anchored on the eighteenth-century 'full bill' Gaskell gives (p. 37): 3,000
;; m, 7,000 a, 12,000 e, 400 x, 800 A. The rest are interpolated on those
;; proportions, adjusted for the letters as they are *printed* rather than as
;; they are spelt today: under the conventions of the case u does duty for v
;; inside a word and i for j throughout, so an English fount carries far more
;; u and i, and very little v or j, than modern frequencies suggest. The long
;; s takes most of the work of the short.

(define lower-bill
  (hash #\e 12000 #\t 9000 #\a 7000 #\o 8000 #\i 8400 #\n 8000
        #\ſ 6500 #\s 3500 #\h 6400 #\r 6200 #\d 4400 #\l 4000
        #\c 3000 #\u 4200 #\m 3000 #\w 2400 #\f 2300 #\g 2000
        #\y 2000 #\p 1900 #\b 1600 #\v 600 #\k 800 #\x 400
        #\j 60 #\q 150 #\z 100
        #\ﬀ 400 #\ﬁ 500 #\ﬂ 300 #\ﬃ 120 #\ﬄ 100
        #\. 2000 #\, 3000 #\; 700 #\: 900 #\? 400 #\! 200
        #\' 500 #\- 600 #\( 200 #\) 200
        #\ā 60 #\ē 120 #\ī 40 #\ō 60 #\ū 40
        #\Ā 20 #\Ē 30 #\Ī 15 #\Ō 20 #\Ū 15
        #\ᵉ 80 #\ᵗ 60 #\ᶜ 40 #\ʰ 40 #\ˢ 30 #\ʳ 30))

(define upper-bill
  (hash #\A 800 #\B 500 #\C 600 #\D 500 #\E 600 #\F 450 #\G 400
        #\H 500 #\I 900 #\K 250 #\L 500 #\M 600 #\N 500 #\O 600
        #\P 450 #\Q 200 #\R 450 #\S 700 #\T 800 #\V 400 #\W 240
        #\X 120 #\Y 250 #\Z 80 #\J 90 #\U 120
        #\& 300 #\— 200 #\¶ 60 #\§ 60 #\* 80
        #\0 200 #\1 250 #\2 220 #\3 200 #\4 180
        #\5 180 #\6 170 #\7 170 #\8 170 #\9 170))

;; ---------------------------------------------------------------------------
;; Reach: why foul case is not uniform across the alphabet
;; ---------------------------------------------------------------------------
;; Moxon describes the lower case as "devided into four several sizes of
;; Boxes ... The reason of these different sizes of Boxes is, That the biggest
;; Boxes may be disposed nearest the Compositers hand, because the English
;; Language, and consequently all English Coppy runs most upon such and such
;; Sorts" (_Mechanick Exercises_, i. 21).
;;
;; So the sorts used most often sit in the largest boxes directly under the
;; hand, and the rare sorts in small boxes further off. A hand going to a
;; small distant box is likelier to come back with the wrong sort than one
;; dropping into the great e box under the fingers. Foul case is therefore
;; commoner in the rare sorts and in the capitals, and this is the documented
;; reason why -- not a guess about carelessness.
;;
;; The upper case compounds it: it stands beyond the lower, and all ninety-
;; eight of its boxes are of one size, so a capital has neither the size nor
;; the nearness that a common lower-case sort enjoys. Moxon notes the frame is
;; built with a declivity expressly so that "the farther Boxes of the
;; Upper-Case are more ready and easie to come at than if they lay flat",
;; which mitigates the reach without abolishing it.

(define (sort-weight ch)
  (or (hash-ref lower-bill ch #f) (hash-ref upper-bill ch #f) 100))

(define max-bill-weight
  (apply max (append (hash-values lower-bill) (hash-values upper-bill))))

;; 1.0 for the commonest sorts; up to about 3 for the rarest and for capitals.
(define (reach-factor ch)
  (define size (expt (/ max-bill-weight (sort-weight ch)) 0.22))
  (define far (if (hash-has-key? upper-bill ch) 1.35 1.0))
  (min 4.0 (* size far)))

;; Sorts in a fount as the founder delivered it.
;;
;; A useful anchor: Jaggard printed the whole of the First Folio from a worn
;; fount of pica that "can have weighed no more than about 90 kg. (200 lb.)"
;; (Gaskell, p. 38, calculating from Hinman), and 100,000 pieces of pica run
;; to about 180 kg. So the Folio was set from roughly 50,000 sorts.
(define FOUNT-SORTS 60000)

(define total-weight
  (+ (for/sum ([(k v) (in-hash lower-bill)]) v)
     (for/sum ([(k v) (in-hash upper-bill)]) v)))

;; ---------------------------------------------------------------------------
;; The case itself
;; ---------------------------------------------------------------------------
;; The boxes are genuinely mutable: sorts leave the case when picked and come
;; back when a forme is distributed. Modelling that with a persistent hash
;; would be a lie about the world, so this is one of the few places the port
;; keeps state.

;; ---------------------------------------------------------------------------
;; Individual types, and their damage
;; ---------------------------------------------------------------------------
;; This is the part of Hinman that a bag of counts cannot express. He did not
;; work from proportions of letters; he identified some six hundred individual
;; pieces of type by their damage and followed each one through the book. A
;; particular battered 'e' turning up in two formes proves those formes drew
;; on the same case, and the order in which such types reappear gives the
;; order of printing. None of that is available unless a sort has an identity.
;;
;; So the common sorts stay as counts -- there is nothing to be learnt from an
;; undamaged 'e' -- and the damaged ones are individuals with a number, a
;; defect, and a history. That is exactly the division Hinman worked with.
;;
;; The defects are keyed to letter anatomy rather than invented per letter: a
;; serif can only break where there is a serif, a bowl can only be nicked on a
;; letter that has one. The vocabulary is compiled from the kinds of damage
;; Hinman illustrates (i, figs. 2-16): broken serifs, battered faces, nicked
;; bowls, chipped shoulders, cracked stems, types worn below the impression.

(struct sort-piece (id char damage) #:transparent)

(define (sort-piece-note p)
  (format "~a (~a)" (damage-phrase (sort-piece-damage p)) (sort-piece-id p)))

(define with-bowl (string->list "abdegopqABDOPQR69"))
(define with-serif (string->list "abcdefhijklmnprtuvwxyzABCDEFGHIJKLMNPRTUVWXYZ"))
(define with-ascender (string->list "bdfhklABCDEFGHIJKLMNOPQRSTUVWXYZ"))
(define with-descender (string->list "gjpqyQ"))

(define damage-vocabulary
  (list
   (list 'broken-serif  "a broken serif"        with-serif)
   (list 'battered      "battered in the face"  #f)
   (list 'nicked-bowl   "a nicked bowl"         with-bowl)
   (list 'chipped       "chipped at the shoulder" with-ascender)
   (list 'cracked-stem  "a cracked stem"        with-ascender)
   (list 'worn          "worn below the impression" #f)
   (list 'bent          "bent to the right"     #f)
   (list 'clogged       "clogged with ink and printing thick" #f)
   (list 'broken-tail   "the tail broken away"  with-descender)
   (list 'low           "standing low and printing faint" #f)))

(define (damage-for ch g)
  (define eligible
    (filter (lambda (d) (or (not (third d)) (memv ch (third d))))
            damage-vocabulary))
  (if (null? eligible) 'battered (first (rnd-choice g eligible))))

(define (damage-phrase d)
  (or (for/or ([row (in-list damage-vocabulary)])
        (and (eq? (first row) d) (second row)))
      (symbol->string d)))

;; How much of the fount is distinctive. A newly cast fount has almost nothing
;; to identify; one that has been through many books has a great deal, which
;; is why the Folio -- set from a worn pica -- was tractable to Hinman at all.
(define CONDITIONS
  (hash 'new 0.002 'used 0.010 'worn 0.030 'foul 0.070))

(struct draw (wanted got event detail piece) #:transparent)

;; `distinctive' holds the individually identifiable pieces, box by box.
;; `recurrence' records where each of them printed: id -> list of places.
;; `initial' is the bill as it stood when the cases were laid, and `low' the
;; fewest of each sort ever left in the box. The pair is the whole answer to
;; the question of how much type a gathering eats: a sort whose low-water mark
;; is near its bill was never in danger, and one that touches nought is a sort
;; the house was short of, which is why `w' comes to be set as `VV'.
(struct tcase (boxes initial low exhausted distributed foulness turn-rate rng
                     distinctive recurrence counter)
  #:transparent)

;; Every sort that leaves a box leaves it through here, so the low-water mark
;; cannot drift out of step with the stock.
(define (take! tc ch [n 1])
  (define boxes (tcase-boxes tc))
  (when (hash-has-key? boxes ch)
    (define left (- (hash-ref boxes ch 0) n))
    (hash-set! boxes ch left)
    (when (< left (hash-ref (tcase-low tc) ch +inf.0))
      (hash-set! (tcase-low tc) ch left))))

(define (make-type-case #:scale [scale 1.0]
                        ;; Calibrated, at last, against a real book rather
                        ;; than against an impression of one.
                        ;;
                        ;; Diffing Q1600 against F1623 across five scenes of
                        ;; Much Ado -- 11,990 words -- turns up two one-letter
                        ;; substitutions between adjoining boxes of the case
                        ;; (Leonato/Leonata, twice) and one turned letter
                        ;; (tongues/tongnes). That is 0.25 accidents per
                        ;; thousand words. The old rates gave 11.6, forty-six
                        ;; times too many, and made every page look like a
                        ;; ruin. Early printing is far cleaner than its
                        ;; reputation.
                        ;;
                        ;; The rates below allow rather more than the observed
                        ;; figure, because the comparison can only see errors
                        ;; that changed a word into a different string, that
                        ;; escaped the corrector, and that stand in the one
                        ;; copy transcribed. It cannot see an error shared by
                        ;; both books or one that happens to make a plausible
                        ;; spelling.
                        #:foulness [foulness 0.00012]
                        #:turn-rate [turn-rate 0.00006]
                        #:condition [condition 'used]
                        #:rng [rng (make-rng 1)])
  (define boxes (make-hash))
  (for ([bill (in-list (list lower-bill upper-bill))])
    (for ([(ch n) (in-hash bill)])
      (hash-set! boxes ch
                 (max 2 (exact-round (/ (* n scale FOUNT-SORTS) total-weight))))))

  ;; Draw the distinctive types out of the sound ones.
  (define rate (if (real? condition) condition (hash-ref CONDITIONS condition 0.010)))
  (define distinctive (make-hash))
  (define counter (box 0))
  (for ([(ch n) (in-hash boxes)])
    (define k (exact-round (* n rate)))
    (when (> k 0)
      (hash-set! boxes ch (- n k))
      (hash-set! distinctive ch
                 (for/list ([i (in-range k)])
                   (set-box! counter (add1 (unbox counter)))
                   (sort-piece (format "t~a" (unbox counter)) ch
                               (damage-for ch rng))))))
  (tcase boxes (hash-copy boxes) (hash-copy boxes) (make-hash) (make-hash)
         foulness turn-rate rng distinctive (make-hash) counter))

;; Types are battered at press as well as in the case. A sound sort may become
;; distinctive part-way through a book, which is why Hinman could date some
;; formes by the *first* appearance of a particular injury.
(define (batter! tc n)
  (define g (tcase-rng tc))
  (for ([i (in-range n)])
    (define chs (hash-keys (tcase-boxes tc)))
    (unless (null? chs)
      (define ch (rnd-choice g chs))
      (when (> (hash-ref (tcase-boxes tc) ch 0) 1)
        (hash-update! (tcase-boxes tc) ch sub1)
        (set-box! (tcase-counter tc) (add1 (unbox (tcase-counter tc))))
        (hash-update! (tcase-distinctive tc) ch
                      (lambda (xs)
                        (cons (sort-piece (format "t~a" (unbox (tcase-counter tc)))
                                          ch (damage-for ch g))
                              xs))
                      '())))))

(define (bump! h k) (hash-update! h k add1 0))

;; Take one sort from the case, with all that may go wrong. `careless` scales
;; this compositor's proneness to foul case; an apprentice's stint is
;; measurably dirtier than a journeyman's.
(define (pick! tc ch #:careless [careless 1.0])
  (define boxes (tcase-boxes tc))
  (define g (tcase-rng tc))
  (cond
    [(or (char=? ch #\space) (not (hash-has-key? boxes ch)))
     (draw ch (string ch) #f "" #f)]

    [(<= (hash-ref boxes ch 0) 0)
     (bump! (tcase-exhausted tc) ch)
     (define shift
       (for/or ([s (in-list (hash-ref SUBSTITUTIONS ch '()))])
         (and (for/and ([c (in-string s)]) (> (hash-ref boxes c 1) 0)) s)))
     (cond
       [shift
        (for ([c (in-string shift)]) (take! tc c))
        (draw ch shift 'shortage
              (format "~a wanting; ~a set in its room" ch shift) #f)]
       [else
        ;; No shift will serve, so the sort is borrowed from another fount
        ;; standing in the shop. The reading is right and the letter wrong --
        ;; a wrong-fount sort, and a gift to the bibliographer, since it dates
        ;; the page against the shop's other work.
        (draw ch (string ch) 'wrong-fount
              (format "~a wanting; a wrong-fount ~a borrowed" ch ch) #f)])]

    [else
     ;; Is a distinctive piece taken this time? Its chance is its share of the
     ;; box, so a nearly-sound fount yields them rarely and a battered one
     ;; often. This is the draw Hinman's whole method depends on.
     (define pieces (hash-ref (tcase-distinctive tc) ch '()))
     (define sound (hash-ref boxes ch 0))
     (define piece
       (and (pair? pieces)
            (< (rnd g) (/ (length pieces) (max 1 (+ sound (length pieces)))))
            (rnd-choice g pieces)))
     (cond
       [piece
        (hash-set! (tcase-distinctive tc) ch (remq piece pieces))
        (draw ch (string ch) 'distinctive (sort-piece-note piece) piece)]
       [else (pick-sound! tc ch careless)])]))

(define (pick-sound! tc ch careless)
  (define boxes (tcase-boxes tc))
  (define g (tcase-rng tc))
  (let ()
     (take! tc ch)
     (define neighbours
       (filter (lambda (n) (same-kind? ch n)) (hash-ref ADJACENT ch '())))
     (cond
       [(and (pair? neighbours)
             (< (rnd g) (* (tcase-foulness tc) careless (reach-factor ch)))
             (let ([wrong (rnd-choice g neighbours)])
               (and (> (hash-ref boxes wrong 0) 0) wrong)))
        => (lambda (wrong)
             (take! tc wrong)
             (hash-update! boxes ch add1)   ; the right sort went back
             (draw ch (string wrong) 'foul-case
                   (format "~a for ~a (adjoining box)" wrong ch) #f))]
       [(and (hash-has-key? TURNED-PAIRS ch)
             (< (rnd g) (tcase-turn-rate tc)))
        (define t (hash-ref TURNED-PAIRS ch))
        (draw ch (string t) 'turned
              (format "turned ~a, printing as ~a" ch t) #f)]
       [else (draw ch (string ch) #f "" #f)])))

;; Return a printed-off forme to the case.
(define (distribute! tc text)
  (define boxes (tcase-boxes tc))
  (for ([ch (in-string text)])
    (when (hash-has-key? boxes ch)
      (hash-update! boxes ch add1)
      (bump! (tcase-distributed tc) ch))))

;; The distinctive pieces go back into their own boxes, whence they may be
;; picked again for a later forme. That second appearance is the evidence.
(define (distribute-pieces! tc pieces)
  (for ([p (in-list pieces)])
    (hash-update! (tcase-distinctive tc) (sort-piece-char p)
                  (lambda (xs) (cons p xs)) '())
    ;; it was counted as a sound sort by distribute!, so give that back
    (take! tc (sort-piece-char p))))

;; How near the cases came to running dry. Reported per sort as the fewest
;; ever left in the box, against the bill it started with.
(define (case-depletion tc)
  (for/list ([(ch n) (in-hash (tcase-initial tc))]
             #:when (> n 0))
    (define low (hash-ref (tcase-low tc) ch n))
    (list ch n (max 0 low) (- 1.0 (/ (max 0.0 (exact->inexact low)) n)))))

;; Where a given piece has printed, in order.
(define (note-recurrence! tc piece place)
  (hash-update! (tcase-recurrence tc) (sort-piece-id piece)
                (lambda (xs) (append xs (list place))) '()))

(define (scarcest tc [n 8])
  (take (sort (hash->list (tcase-boxes tc)) < #:key cdr)
        (min n (hash-count (tcase-boxes tc)))))

(module+ test
  (require rackunit)
  ;; Adjacencies that the English divided lay does produce ...
  (check-not-false (memv #\h (hash-ref ADJACENT #\n)) "n adjoins h")
  (check-not-false (memv #\m (hash-ref ADJACENT #\n)) "n adjoins m")
  (check-not-false (memv #\ſ (hash-ref ADJACENT #\i)) "i adjoins long s")
  (check-not-false (memv #\q (hash-ref ADJACENT #\p)) "p adjoins q")
  ;; ... and one it does not. e and i sit in opposite halves of the divided
  ;; lower case, so no hand straying one box turns e into i.
  (check-false (memv #\i (hash-ref ADJACENT #\e))
               "e and i are in different halves of the case")
  ;; Foul case never crosses kinds.
  (check-false (same-kind? #\a #\.))
  (check-false (same-kind? #\? #\ﬄ))
  (check-true (same-kind? #\n #\h))

  ;; Moxon's principle: the biggest boxes hold the commonest sorts and sit
  ;; nearest the hand, so a rare sort is likelier to be fouled than e.
  (check-equal? (reach-factor #\e) 1.0 "the commonest sort is the easiest box")
  (check-true (> (reach-factor #\z) (reach-factor #\e)))
  (check-true (> (reach-factor #\x) (reach-factor #\a)))
  ;; and a capital is worse still: small box, and further off
  (check-true (> (reach-factor #\W) (reach-factor #\w)))
  (check-true (<= (reach-factor #\z) 4.0) "capped")

  (define tc (make-type-case #:rng (make-rng 1623)))
  ;; W is the scarce sort, which is why VV appears in early books.
  (check-true (< (hash-ref (tcase-boxes tc) #\W)
                 (hash-ref (tcase-boxes tc) #\e)))
  ;; Emptying the W box forces the shift.
  (hash-set! (tcase-boxes tc) #\W 0)
  (define d (pick! tc #\W))
  (check-equal? (draw-got d) "VV")
  (check-equal? (draw-event d) 'shortage))
