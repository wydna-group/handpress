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
         case-depletion take! replenish! inversion-boost cannibalize!
         supply-factor box-fraction
         ADJACENT TURNED-PAIRS INVERSION-RATES FOUNT-SORTS
         LONG-S-LIGATURES LIGATURE-PRINTS take-ligature!
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

;; ---------------------------------------------------------------------------
;; The turn that changes nothing
;; ---------------------------------------------------------------------------
;; The pairs above are the turns a *reader* notices, because they hand him a
;; different letter. There is a second and commoner kind that no reader notices
;; and no corrector marks, and it is worth far more to the bibliographer.
;;
;; Short s set upside down is still short s. It leans the wrong way and its
;; terminals sit wrong, so it can be picked out of a photograph three centuries
;; later, but the word reads correctly and the proof passes. Blayney measured
;; the rate in _King Lear_: "Before sheet L, 's' had been set the right way up
;; 2,332 times; on only 16 occasions was it inverted", and elsewhere "the rate
;; in the rest of the book is approximately 1 in 150" (i. 140-1).
;;
;; Blayney is careful about the cause, and rejects the obvious one: "The mere
;; fact that the letter looks fairly similar either way up can hardly account
;; for the frequency of the error, since a compositor does not usually decide
;; which way up to set a type by looking at the face. Types were cast with a
;; nick in the lower edge of the shank, and it is easy enough to detect an
;; inverted type in the stick by the way in which it interrupts the groove
;; formed by the lined-up nicks." The face-symmetry explains why the error
;; *survives* -- nobody catches it -- not why it is made.
;;
;; So this is deliberately not a rule about symmetrical letters. It is one
;; measured rate for one sort, which is all anybody has measured.
(define INVERSION-RATES (hash #\s (/ 1.0 150)))

;; ---------------------------------------------------------------------------
;; The long-s ligatures
;; ---------------------------------------------------------------------------
;; ſt, ſh, ſi and ſſ were cast as single sorts, and in an English fount they
;; were the commonest ligatures of all. A compositor setting `ſhould' reaches
;; for one piece of metal, not two -- unless that box is empty, in which case
;; he sets the two letters separately and nobody but a bibliographer can tell.
;;
;; That is the whole reason to model them: the page looks the same either way,
;; but the boxes that empty are different, and a shortage of ſt is a fact about
;; the fount that shows up in the recurrence evidence.
;;
;; ſh, ſi and ſſ have no Unicode characters. They are given private-use
;; codepoints for the box and print as their two letters, so nothing outside
;; this module ever sees them.
(define LONG-S-LIGATURES
  (hash #\t #\ﬅ #\h #\uE000 #\i #\uE001 #\ſ #\uE002))

(define LIGATURE-PRINTS
  (hash #\ﬅ "ſt" #\uE000 "ſh" #\uE001 "ſi" #\uE002 "ſſ"))

;; Take a long-s ligature for `ſ' followed by `next', if the fount has one and
;; the box is not empty. Returns the sort drawn, or #f -- in which case the
;; caller sets the two letters singly, which is what Okes's men did with the
;; three-letter ligatures he was short of.
(define (take-ligature! tc next)
  (define lig (hash-ref LONG-S-LIGATURES next #f))
  (and lig
       (hash-has-key? (tcase-boxes tc) lig)
       (> (hash-ref (tcase-boxes tc) lig 0) 0)
       (begin (take! tc lig) lig)))

;; The compositor's shifts when a box is empty, in order of preference.
;;
;; The three-letter ligatures break in two stages, not one. Okes owned about
;; eight of them all told, and Blayney observes that "his compositors often set
;; such letter-groups with a single type followed by a two-letter ligature"
;; (i. 147) -- so ffi is set f + fi before it is set f + f + i, because the
;; two-letter ligature is the thing he actually had.
(define SUBSTITUTIONS
  (hash #\W '("VV") #\w '("vv")
        #\ſ '("s")
        #\ﬀ '("ff") #\ﬁ '("fi") #\ﬂ '("fl")
        #\ﬃ '("fﬁ" "ffi") #\ﬄ '("fﬂ" "ffl")
        #\J '("I") #\U '("V") #\j '("i") #\u '("v")
        #\ā '("am") #\ē '("em") #\ō '("om") #\ū '("um")
        #\Ā '("Am") #\Ē '("Em") #\Ō '("Om") #\Ū '("Um")))

;; ---------------------------------------------------------------------------
;; The bill of type
;; ---------------------------------------------------------------------------
;; This was interpolated from the eighteenth-century full bill Gaskell gives
;; (p. 37) until Blayney supplied something far better: a sort-by-sort count of
;; the type actually used in an English quarto of 1608.
;;
;; Working from type-recurrence, Blayney tabulated how many of every sort stood
;; in type before each distribution during the printing of _King Lear_ Q1, and
;; set the maxima against a quarter of Smith's 'standard' bill (_The Printer's
;; Grammar_, 1755) and against van den Keere's own registre for the roman he
;; supplied to Plantin in 1571 (i. 145-7, table at 146). Three columns, one of
;; them measured from a real English book of the right decade:
;;
;;        Lear  Smith/4   vdK          Lear  Smith/4   vdK
;;   a    1479    1750    1250    p     301     400     650
;;   b     270     400     375    q      23     150     320
;;   c     361     600     642    r    1230    1250     788
;;   d     766    1000     658    long-s 343     600     969
;;   e    2907    3000    1879    s     540     750     450
;;   f     384     500     240    t    1606    1750    1281
;;   g     367     400     260    u     812     750    1274
;;   h    1275    1500     266    v      80     250     250
;;   i    1046    1500    1875    w     469     400       -
;;   k     218     250      27    x      15     100     144
;;   l     770     750     736    y     500     400     148
;;   m     576     750     850    &      10     100     160
;;   n    1174    1500    1269
;;   o    1588    1500    1317   total 19116   22550   18324
;;
;; A bill is a fount proportioned to 3,000 m; Smith's quarter-bill weighed
;; 125-150 lb. Blayney concludes that the roman used for _Lear_ "is unlikely to
;; have been much more than 120 lb, and may well have been less" (i. 147-8),
;; against a net total of 21,953 types.
;;
;; The figures below are Blayney's Lear maxima, which are a lower bound on the
;; fount rather than the fount itself, lifted in the four places he says they
;; must be:
;;
;;   * the rare sorts. Okes surely owned more q, x and z than _Lear_ ever put
;;     in type at once; demand never tested the supply. Raised toward Smith.
;;   * the capitals. "The figures for capitals differ greatly between Okes and
;;     Smith, and van den Keere's totals are far closer to those from _Lear_"
;;     (i. 147) -- so Blayney rules a *tenth* of Smith's bill the right yardstick
;;     for 1607, not a quarter. Each capital is the greater of the Lear figure
;;     and Smith/10. An early fount carries about a third of the capitals an
;;     eighteenth-century one does, relative to lower case.
;;   * I and W. Lear's I is inflated by cannibalization and by the first-person
;;     pronoun of dialogue; W was probably bought during the printing, its
;;     earlier total being 41-4.
;;   * the long s, which reads far too low at 343 until one notices where the
;;     rest of it went. Okes's fount had separate sorts for the long-s
;;     ligatures, and they are counted separately: ſt at 200 is his commonest
;;     ligature by a wide margin, then ſh at 83 and ſi at 48. This program has
;;     no ſt sort, so their work falls back on the plain long s and the box has
;;     to be big enough to do it -- 745 rather than 343. The alternative is to
;;     model ſt and ſh as sorts in their own right, which is the right answer
;;     and is on the roadmap.
;;
;; Points get the same treatment: Lear's 1,395 against Smith's 2,775, because
;; "eighteenth-century orthography demanded far more capitals and punctuation
;; sorts than were normally used in earlier periods" (i. 145). The old bill here
;; carried better than twice the punctuation a 1608 fount held.

(define lower-bill
  (hash #\e 2907 #\t 1606 #\o 1588 #\a 1479 #\r 1230 #\h 1275
        #\n 1174 #\i 1046 #\u 812  #\l 770  #\d 766  #\ſ 343
        #\m 576  #\s 540  #\y 500  #\w 469  #\f 384  #\g 367
        #\c 361  #\p 301  #\b 270  #\k 218  #\v 80   #\q 60
        #\x 40   #\z 30   #\j 8
        ;; Blayney, i. 147: "The _Lear_ maxima for ligatures are all lower than
        ;; Smith's figures, most noticeably in the case of three-letter
        ;; ligatures. I do not believe that the 8 shown in the table constituted
        ;; Okes's entire stock, but it is evident that he owned very few. The
        ;; fact that his compositors often set such letter-groups with a single
        ;; type followed by a two-letter ligature could be the cause of the low
        ;; apparent total, but is more likely to be the result of a shortage."
        ;; Hence the three-letter ligatures are scarce and SUBSTITUTIONS breaks
        ;; them the way his men did.
        #\ﬀ 18 #\ﬁ 48 #\ﬂ 71 #\ﬃ 8 #\ﬄ 6
        ;; The long-s ligatures, which are sorts in their own right and were
        ;; the commonest ligatures an English fount held. Blayney's counts for
        ;; _Lear_: ſt 200 -- more than ﬀ, ﬁ and ﬂ together -- then ſh 83 and
        ;; ſi 48. Until now the program had no such sorts, so their work fell
        ;; back on the plain long s and its box had to be inflated from the
        ;; measured 343 to 745 to carry it. With the ligatures present, ſ
        ;; returns to what Blayney actually counted.
        ;;
        ;; Only ſt has a Unicode character (U+FB05). The others are given
        ;; private-use codepoints, which never reach the page: a ligature draws
        ;; from its own box and prints as its two letters, because what matters
        ;; bibliographically is which box emptied, not whether the two letters
        ;; were kerned together in the face.
        #\ﬅ 200 #\uE000 83 #\uE001 48 #\uE002 60
        ;; Points, from van den Keere's registre rather than from Lear, and for
        ;; a reason Blayney gives: "Early printers evidently considered many
        ;; roman and italic points to be interchangeable (with each other and to
        ;; some extent with textura), and it may have been usual for printers to
        ;; treat punctuation as Okes treated it - as the common property of all
        ;; founts of the same body-size. Okes's stock of roman punctuation sorts
        ;; was lower than suggested either by Smith or by van den Keere. His new
        ;; roman stock was even lower, for it is evident that some of the
        ;; Snowdons' roman points were still in use" (i. 147).
        ;;
        ;; So the Lear column undercounts these worse than any other part of the
        ;; table: it is one fount's share of a stock the whole house drew on.
        ;; The compositor reaches into a box holding all the pica commas in the
        ;; shop, and van den Keere's figures for a real 1571 fount are the
        ;; nearest thing to that total.
        #\. 386 #\, 612 #\; 109 #\: 126 #\? 30 #\! 12
        #\' 54  #\- 257 #\( 19  #\) 50
        ;; Not in Blayney's table: the fount would have carried a few of these
        ;; and no more. A house with fifteen tilde vowels cannot set many.
        #\ā 12 #\ē 20 #\ī 8 #\ō 12 #\ū 8
        #\Ā 4  #\Ē 6  #\Ī 3 #\Ō 4  #\Ū 3
        #\ᵉ 16 #\ᵗ 12 #\ᶜ 8 #\ʰ 8 #\ˢ 6 #\ʳ 6))

;; The greater of Lear's measured maximum and a tenth of Smith's bill; see
;; above. J and U are near-absent by the conventions of the case, not by
;; accident of supply.
(define upper-bill
  (hash #\A 80  #\B 50  #\C 60  #\D 50  #\E 80  #\F 50  #\G 60
        #\H 60  #\I 160 #\K 50  #\L 50  #\M 50  #\N 60  #\O 60
        #\P 60  #\Q 30  #\R 60  #\S 60  #\T 107 #\V 50  #\W 63
        #\X 20  #\Y 50  #\Z 20  #\J 6   #\U 8
        #\& 40  #\— 30 #\¶ 10 #\§ 10 #\* 14
        #\0 30 #\1 40 #\2 34 #\3 30 #\4 28
        #\5 28 #\6 26 #\7 26 #\8 26 #\9 26))

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
;; This stood at 60,000 on the strength of one anchor at the top of the trade:
;; Jaggard printed the whole of the First Folio from a worn pica that "can have
;; weighed no more than about 90 kg. (200 lb.)" (Gaskell, p. 38, calculating
;; from Hinman), which at about 180 kg per 100,000 pieces makes roughly 50,000
;; sorts. But that is the largest printing house in London working in folio,
;; and it was the wrong end of the trade to calibrate a quarto on.
;;
;; Blayney counted the other end. Nicholas Okes set the whole of _King Lear_ Q1
;; from a fount whose net total was 21,953 types, weighing "unlikely to have
;; been much more than 120 lb, and may well have been less" (i. 147-8) -- about
;; a quarter of a bill. He "did not own a very large stock of type. It can be
;; estimated that his books of 1607-8 could have been printed with a minimum of
;; about 120 lb each of his most frequently-used founts. He may, of course,
;; have owned more than the bare minimum, but many of his books testify to
;; local shortages of one sort or another, and it seems unlikely that he would
;; have owned much more than he used" (i. 94).
;;
;; So the default is now the small quarto house, not the great folio house, and
;; the case runs short because Okes's case ran short. Pass --case-scale 2.3 for
;; something on Jaggard's footing.
(define FOUNT-SORTS 22000)

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
;; `inverted' holds any batch of new type lately added to a box that was cast
;; from a badly-struck matrix: ch -> (vector remaining multiplier). See
;; `replenish!'.
(struct tcase (boxes initial low exhausted distributed foulness turn-rate rng
                     distinctive recurrence counter inverted replenished
                     cannibalized blanks)
  #:transparent)

;; Every sort that leaves a box leaves it through here, so the low-water mark
;; cannot drift out of step with the stock -- and so a defective batch is used
;; up by being set, which is what makes it a dated marker rather than a
;; permanent property of the fount.
(define (take! tc ch [n 1])
  (define boxes (tcase-boxes tc))
  (when (hash-has-key? boxes ch)
    (define left (- (hash-ref boxes ch 0) n))
    (hash-set! boxes ch left)
    (when (< left (hash-ref (tcase-low tc) ch +inf.0))
      (hash-set! (tcase-low tc) ch left)))
  (define batch (hash-ref (tcase-inverted tc) ch #f))
  (when (and batch (> (vector-ref batch 0) 0))
    (vector-set! batch 0 (- (vector-ref batch 0) n))))

;; How much likelier this sort is to stand inverted just now: 1.0 unless a
;; defective batch is in the box and not yet used up.
(define (inversion-boost tc ch)
  (define batch (hash-ref (tcase-inverted tc) ch #f))
  (if (and batch (> (vector-ref batch 0) 0)) (vector-ref batch 1) 1.0))

;; ---------------------------------------------------------------------------
;; Replenishment
;; ---------------------------------------------------------------------------
;; A box that runs dry is not simply a box that stays dry. The master sends to
;; the founder, and the sorts come back. Hinman caught Jaggard doing it -- new
;; type added to the 'a' and 'u' boxes towards the end of 1622 (i. 86-9) -- and
;; Blayney caught Okes doing it in the middle of a sheet.
;;
;; What makes Okes's case worth modelling is that the new type was faulty.
;; "While sheet L of _Lear_ was being set, the 's' sort-box was replenished. The
;; new types, however, appear to have been cast from a wrongly-struck matrix,
;; and the 's' is inverted" (i. 500). The effect on the page is arithmetic:
;;
;;   before sheet L    16 inverted in 2,348      0.7%
;;   L1v                6 in 31
;;   L2r                7 in 29
;;   L2v               14 in 32
;;   L3r                3 in 31, all in the first ten lines
;;   L1v-L3r           30 in 83                 36%
;;
;; "a localized increase of over 5,000% can hardly be explained away as
;; accidental" (i. 141). And then the batch is gone and the rate falls back.
;;
;; Two things follow, and the second is the reason this is here at all. The
;; first is a fount state that dates every later book in the shop: an unusual
;; frequency of inverted 's' runs through Okes's output for a year afterwards,
;; and separates what he printed before _Lear_ L from what he printed after.
;; The second is that a batch used up in one continuous run is a tracer through
;; the setting order. Blayney: "The clustering of the aberrant types shows that
;; they had been added to the box as a group just before they began to appear
;; in L1v, and that the new batch was more or less used up by the middle of
;; L3r. L1v-3r must therefore have been set seriatim."
;;
;; That last inference is the whole of Hinman's method in miniature, run on one
;; sort instead of six hundred, and it is a good deal cheaper to check.
(define DEFECTIVE-BATCH 0.15)

;; ---------------------------------------------------------------------------
;; Cannibalization
;; ---------------------------------------------------------------------------
;; A box that has run dry is not the end of the sorts. The rest of them are
;; standing in type a few feet away, in pages already set and not yet printed,
;; and a compositor who needs one takes it out of them.
;;
;; Blayney catches it repeatedly. Six E's were wanted for a page of _Lear_ and
;; "the compositors had found 5 Es and an E from somewhere else. Two of these
;; six types, both set by C, are identifiable as having been taken from H3r,
;; which contained 6 Es ... There is no sign that the page had been
;; distributed, but as the H(o) page containing most of the desired sorts it
;; had certainly been cannibalized" (i. 132). And more generally: "Okes did not
;; own enough type to allow sixteen pages of _Lear_ ... to stand without having
;; their margins cannibalized for capitals" (i. 111).
;;
;; The margins are the point, and they are the constraint. "If types are taken
;; from the middle of an undistributed page there is a risk that several lines
;; will be pied, making the eventual distribution more difficult. The safest
;; place from which to have taken Es, therefore, would have been the marginal
;; speech prefixes" (i. 136). A standing page is a locked block of metal under
;; tension: pull a sort from the middle of a line and the line may spill. So
;; only a small share of what stands is safely reachable, and that share is
;; what limits this.
;;
;; The share is a judgement -- the marginal fraction of a page is not something
;; Blayney counts -- but its existence is not, and neither is the consequence:
;; without it the program borrowed a wrong-fount sort 248 times in one book,
;; where Okes's books show a handful.
(define CANNIBAL-SHARE 0.06)

;; The chance of the fourth expedient rather than the fifth, once robbing has
;; failed. Rare by construction: Blayney demonstrates one instance in a book.
(define BLANK-FOR-PROOF 0.25)

;; How much of this sort is standing in type: everything the fount holds that
;; is not in the box. Cannibalizing gives one of them back, and the page it
;; came from now has a hole in it.
(define (cannibalize! tc ch)
  (define standing (- (hash-ref (tcase-initial tc) ch 0)
                      (max 0 (hash-ref (tcase-boxes tc) ch 0))))
  (define taken (hash-ref (tcase-cannibalized tc) ch 0))
  (cond
    [(< taken (* CANNIBAL-SHARE standing))
     (hash-update! (tcase-cannibalized tc) ch add1 0)
     (hash-update! (tcase-boxes tc) ch add1 0)
     #t]
    [else #f]))
(define REPLENISH-AFTER 40)

(define (replenish! tc ch n)
  (define g (tcase-rng tc))
  (hash-update! (tcase-boxes tc) ch (lambda (k) (+ k n)) 0)
  (bump! (tcase-replenished tc) ch)
  ;; A wrongly-struck matrix is not the usual outcome of an order, but it is
  ;; the outcome that leaves a record.
  (when (and (hash-has-key? INVERSION-RATES ch) (< (rnd g) DEFECTIVE-BATCH))
    (hash-set! (tcase-inverted tc) ch
               (vector n (/ 0.36 (hash-ref INVERSION-RATES ch)))))
  n)

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
         foulness turn-rate rng distinctive (make-hash) counter
         (make-hash) (make-hash) (make-hash) (make-hash)))

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
     ;; A box that empties once is an inconvenience and the compositor shifts.
     ;; A box that keeps emptying is a standing complaint, and at some point
     ;; the master sends to the founder rather than go on setting VV for W.
     ;; The threshold is a guess; that replenishment happened at all is not.
     (when (and (> (hash-ref (tcase-exhausted tc) ch 0) REPLENISH-AFTER)
                (zero? (modulo (hash-ref (tcase-exhausted tc) ch 0)
                               REPLENISH-AFTER)))
       (replenish! tc ch (max 20 (exact-round
                                  (* 0.15 (hash-ref (tcase-initial tc) ch 0))))))
     (define shift
       (for/or ([s (in-list (hash-ref SUBSTITUTIONS ch '()))])
         (and (for/and ([c (in-string s)]) (> (hash-ref boxes c 1) 0)) s)))
     (cond
       [shift
        (for ([c (in-string shift)]) (take! tc c))
        (draw ch shift 'shortage
              (format "~a wanting; ~a set in its room" ch shift) #f)]
       ;; No shift will serve. Before borrowing from another fount, the
       ;; compositor robs the type already standing -- see `cannibalize!'.
       [(cannibalize! tc ch)
        (take! tc ch)
        (draw ch (string ch) 'cannibalized
              (format "~a wanting; taken from the margin of a standing page" ch)
              #f)]
       ;; Nothing safe to rob either. Blayney watches compositor B in exactly
       ;; this corner, wanting a W with no W to be had, and take the fourth
       ;; course: "to set an 'M' or a ligature face down so that the foot
       ;; printed as two black rectangles, and to insert the right type during
       ;; proofing when supplies were again available" (i. 161). He proves it
       ;; happened at I4v36, where the type that eventually filled the space
       ;; cannot have been available until a later sheet had been set.
       ;;
       ;; A deliberate blank, and the only expedient on the ladder that makes
       ;; press-correction *necessary* rather than optional: the forme cannot
       ;; go to press as it stands.
       [(< (rnd g) BLANK-FOR-PROOF)
        (bump! (tcase-blanks tc) ch)
        (draw ch "▮" 'blank-for-proof
              (format "~a wanting; a sort set face down, to be inserted at proof" ch)
              #f)]
       [else
        ;; And last, the sort is borrowed from another fount standing in the
        ;; shop. The reading is right and the letter wrong -- a wrong-fount
        ;; sort, and a gift to the bibliographer, since it dates the page
        ;; against the shop's other work.
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
       ;; The reading is untouched, so `got' is the sort itself and the word
       ;; prints correctly. Only the event records that the type stood upside
       ;; down. It must not reach the corrector: the whole interest of these is
       ;; that they were not caught, sixteen of them surviving 2,332 settings.
       [(< (rnd g) (* (hash-ref INVERSION-RATES ch 0.0)
                      (inversion-boost tc ch)))
        (draw ch (string ch) 'inverted
              (format "~a standing inverted" ch) #f)]
       [else (draw ch (string ch) #f "" #f)])))

;; Return a printed-off forme to the case.
(define (distribute! tc text)
  (define boxes (tcase-boxes tc))
  ;; The robbed pages have gone back into the case, so whatever was taken out
  ;; of their margins is no longer a hole in anything. The budget starts again
  ;; against whatever is standing next.
  (hash-clear! (tcase-cannibalized tc))
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

;; ---------------------------------------------------------------------------
;; What is in the box, and what the compositor therefore spells
;; ---------------------------------------------------------------------------
;; The most useful thing in Blayney, and the one that most embarrasses the rest
;; of compositor-study: a man's spelling is partly a fact about his cases.
;;
;; Compositor B of _Lear_ chose between -ie and -y some 320 times, and his
;; practice looked incoherent -- 73% -ie in sheet D, 38% in sheet K -- until
;; Blayney counted the type. He tabulated the contents of the 'i' and 'y' boxes
;; at the head of every page (i. 174), and the incoherence resolved:
;;
;;   'y' box over 200      B set 49% -y endings
;;   'y' box 100-200                 42%
;;   'y' box under 100               29%
;;
;; against a stock of "at least 500 'y's and 1,046 'i's". The level of the 'i'
;; box "seems to have played virtually no part in the matter", and the asymmetry
;; is arithmetical rather than psychological: "The -ie endings in _Lear_ account
;; for fewer than 4% of the total number of 'i's set - but 60% of the 'y's are
;; terminal." Setting six -ie endings makes no impression on a box of a
;; thousand; setting six -y endings visibly empties one of five hundred. So the
;; sort that the choice can exhaust is the sort that governs the choice, and the
;; relative bias between the two boxes matters much less than the absolute level
;; of the vulnerable one.
;;
;; Blayney's conclusion is the caution: B "was so prone to the influence of
;; several factors, especially that of type-supply, that one could hardly use
;; this group of spellings as a reliable discriminant" (i. 176). A spelling test
;; measures the case as well as the man.
;;
;; The bands below are his three figures as multipliers on habit, with the
;; unstressed band as the baseline: 42/49 and 29/49. They are expressed as
;; fractions of the bill rather than as counts, so that --case-scale does not
;; silently move the thresholds.
(define (box-fraction tc ch)
  (define bill (hash-ref (tcase-initial tc) ch 0))
  (if (<= bill 0)
      1.0
      (max 0.0 (/ (exact->inexact (hash-ref (tcase-boxes tc) ch 0)) bill))))

(define (char-tally s)
  (define h (make-hash))
  (for ([c (in-string s)]) (hash-update! h c add1 0))
  h)

;; How much likelier the compositor is to set `to' in place of `from', given
;; what the two forms cost the case. 1.0 when nothing scarce is at stake, which
;; is the ordinary answer: the effect only bites near the bottom of a box.
;;
;; Both forms must be passed *as they will be set*, after the conventions, or
;; this will compare an s against a long s and see a difference where the case
;; sees none.
(define (supply-factor tc from to)
  (define spent (char-tally from))
  (define extra
    (for/list ([(ch n) (in-hash (char-tally to))]
               #:when (> n (hash-ref spent ch 0))
               #:when (hash-has-key? (tcase-initial tc) ch))
      (box-fraction tc ch)))
  (cond
    [(null? extra) 1.0]
    [else
     (define lowest (apply min extra))
     (cond
       [(>= lowest 0.40) 1.0]
       [(>= lowest 0.20) 0.86]
       [else 0.59])]))

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

  ;; The bill against the two figures Blayney states outright for Okes's
  ;; fount (i. 173): "Okes owned at least 500 'y's and 1,046 'i's". A scaled
  ;; bill that lands within a tenth of both is the check that the proportions
  ;; and the fount size are consistent with each other.
  (check-true (< 420 (hash-ref (tcase-initial tc) #\y) 550))
  (check-true (< 930 (hash-ref (tcase-initial tc) #\i) 1150))

  ;; An average page of _Lear_ "contains 66 'i's and 31 'y's" (i. 173). The
  ;; program's quarto page runs to about 1,400 sorts, so the bill's share for
  ;; 'i' has to put roughly that many on a page or the two calibrations
  ;; contradict each other.
  (define total (for/sum ([(ch n) (in-hash (tcase-initial tc))]) n))
  (check-true (< 55 (* 1400 (/ (hash-ref (tcase-initial tc) #\i) 1.0 total)) 80)
              "about 66 i to a page, as Blayney counted")

  ;; The turn that leaves the reading alone. Short s inverted is still short s.
  (check-equal? (hash-ref INVERSION-RATES #\s) (/ 1.0 150))
  (check-false (hash-ref INVERSION-RATES #\e #f)
               "only s was measured, so only s has a rate")

  ;; A defective batch raises the rate for its sort and for no other, and is
  ;; spent by being set -- which is what makes it date a stretch of setting.
  (let ([tc2 (make-type-case #:rng (make-rng 1608))])
    (check-equal? (inversion-boost tc2 #\s) 1.0 "no batch, no boost")
    (hash-set! (tcase-inverted tc2) #\s (vector 30 50.0))
    (check-equal? (inversion-boost tc2 #\s) 50.0)
    (check-equal? (inversion-boost tc2 #\e) 1.0 "and it is one sort only")
    (for ([i (in-range 30)]) (take! tc2 #\s))
    (check-equal? (inversion-boost tc2 #\s) 1.0 "the batch is used up"))

  ;; Blayney's bands: a form is set less often when it spends a sort the box is
  ;; running out of, and the pressure is one-way. Emptying the y box discourages
  ;; -y without encouraging anything against -ie, because -ie spends an i from a
  ;; box that never feels it.
  (let ([tc3 (make-type-case #:rng (make-rng 1608))])
    (define (set-y! frac)
      (hash-set! (tcase-boxes tc3) #\y
                 (exact-round (* frac (hash-ref (tcase-initial tc3) #\y)))))
    (set-y! 1.0)
    (check-equal? (supply-factor tc3 "honeſtie" "honeſty") 1.0)
    (set-y! 0.30)
    (check-equal? (supply-factor tc3 "honeſtie" "honeſty") 0.86)
    (set-y! 0.05)
    (check-equal? (supply-factor tc3 "honeſtie" "honeſty") 0.59)
    (check-equal? (supply-factor tc3 "honeſty" "honeſtie") 1.0
                  "the i box does not feel a handful of -ie endings"))

  ;; The ladder of expedients when a box is dry. Blayney watches compositor B
  ;; work down it wanting a W; the program must have the rungs in the same
  ;; order, and cannibalization -- robbing type already standing -- is the one
  ;; that was missing and that a shop actually reached for most.
  (let ([tc4 (make-type-case #:rng (make-rng 1608))])
    ;; Nothing standing yet, so nothing to rob.
    (check-false (cannibalize! tc4 #\e) "cannot rob a page that is not set")
    ;; Set most of the e box, and the standing pages become a resource.
    (define bill (hash-ref (tcase-initial tc4) #\e))
    (hash-set! (tcase-boxes tc4) #\e 0)
    (check-true (cannibalize! tc4 #\e) "the margins of a standing page can be robbed")
    ;; But only the margins. Blayney: taking from the middle of an
    ;; undistributed page risks pieing the lines, so most of what stands is
    ;; not safely reachable and the budget runs out well short of it.
    (define got
      (let loop ([n 1])
        (hash-set! (tcase-boxes tc4) #\e 0)
        (if (and (< n bill) (cannibalize! tc4 #\e)) (loop (add1 n)) n)))
    (check-true (< got (* 0.2 bill))
                "only a small share of standing type is safe to take")
    ;; And distribution wipes the slate: the robbed pages are back in the case.
    (distribute! tc4 "")
    (hash-set! (tcase-boxes tc4) #\e 0)
    (check-true (cannibalize! tc4 #\e) "after distribution there is nothing robbed"))

  ;; The long-s ligatures are sorts, drawn from their own boxes, and they print
  ;; as their two letters. The page is the same either way; the box that
  ;; empties is not, which is the whole reason to model them.
  (let ([tc5 (make-type-case #:rng (make-rng 1608))])
    (check-true (> (hash-ref (tcase-initial tc5) #\uFB05) 0) "the fount has st")
    (define before (hash-ref (tcase-boxes tc5) #\uFB05))
    (check-equal? (take-ligature! tc5 #\t) #\uFB05 "st is one sort")
    (check-equal? (hash-ref (tcase-boxes tc5) #\uFB05) (sub1 before)
                  "and taking it empties that box, not the long s box")
    (check-equal? (hash-ref LIGATURE-PRINTS #\uFB05) "ſt"
                  "but it prints as two letters")
    (check-false (take-ligature! tc5 #\z) "there is no sz ligature")
    ;; Empty the box and the compositor sets the letters singly, which is what
    ;; Okes's men did with the ligatures he was short of.
    (hash-set! (tcase-boxes tc5) #\uFB05 0)
    (check-false (take-ligature! tc5 #\t) "an empty ligature box is no ligature"))

  ;; W is the scarce sort, which is why VV appears in early books.
  (check-true (< (hash-ref (tcase-boxes tc) #\W)
                 (hash-ref (tcase-boxes tc) #\e)))
  ;; Emptying the W box forces the shift.
  (hash-set! (tcase-boxes tc) #\W 0)
  (define d (pick! tc #\W))
  (check-equal? (draw-got d) "VV")
  (check-equal? (draw-event d) 'shortage))
