#lang racket/base
;;; The printing house with more than one book in it.
;;;
;;; Roadmap §8, and the reply this program has owed McKenzie since the first
;;; report was printed with his objection appended to it. The objection is that
;;; every percentage the analysis produces is the analyser inverting the
;;; generator, and both were written from the same account of how a shop
;;; behaved. The reply is not an argument. It is to build the shop he documents,
;;; run the same analysis over it, and measure what happens to the answers.
;;;
;;; HIS THESIS IS ABOUT VARIANCE, NOT ABOUT A NUMBER OF BOOKS. "productive
;;; conditions were constantly changing, not just from century to century in
;;; different houses, but from day to day in the same house, simply because
;;; concurrent printing has been the universal practice for the last 400 years"
;;; (Printers of the Mind, SB 22 (1969), p. 49). In `sources/mckenzie.pdf' the
;;; PDF page is the journal page, with no offset -- unlike Blayney.
;;;
;;; WHAT REACHES THE BOOK UNDER TEST. Another job in the house touches it by
;;; exactly two channels, and everything here exists to model those two:
;;;
;;;   It takes metal out of the shared case and holds it. A piece Hinman would
;;;   trace through consecutive formes instead goes into another book's forme
;;;   and comes back later. His criterion is a PROHIBITION -- sharing a type
;;;   forbids adjacency -- so this does not add noise, it can make the true
;;;   order inadmissible or dissolve the uniqueness his confidence depends on.
;;;
;;;   It takes a man from the frame, so the stint boundaries in this book record
;;;   the house's other work. Which is McKenzie's own conclusion: the
;;;   compositorial pattern within a book "will rarely have any internal
;;;   significance" (i. 107).
;;;
;;; NEITHER CHANNEL NEEDS THE OTHER WORK TO BE A BOOK, and that is why `ballast'
;;; below is not one. It has a length, a character stream and a place in the
;;; queue; it has no pages, no proofs, no collation and no description. This is
;;; not a shortcut. Alongside volume I of Suidas -- which McKenzie offers as a
;;; Folio-equivalent, 954 pages, 22 months, edition 1500 -- the same one and a
;;; half presses printed volume II ("yet another Shakespeare Folio as it were"),
;;; **20 other books whole or in part, and at least 23 smaller jobs** (p. 33).
;;; Appendix II(d) shows what that work is: catalogues, Votes, hymns, proposals,
;;; "a Greek quarto page", "an English folio page", "imposing 3 half sheets".
;;; Mostly jobbing. Forty-odd items is not a load you model by printing forty
;;; books, and modelling it as nothing misrepresents the shop far worse than
;;; modelling it as sheets does.
;;;
;;; THE CLOCK IS A SPREAD AND NOT A RATE, which is the correction that cost two
;;; drafts of the plan. It is tempting to read McKenzie as giving 12,000 ens a
;;; day. He gives that as the HYPOTHETICAL maximum -- 1,000 ens an hour times
;;; twelve (p. 8) -- and the whole of his part II exists to show nobody did it:
;;;
;;;   composition   hypothetical 12,000 ens a day, 72,000 a week
;;;                 recorded: Pokins 6,307 a day through 1702, Bertram 5,700,
;;;                 Knell 5,603, and "often the daily totals were well below
;;;                 these figures" (p. 9)
;;;
;;;   presswork     hypothetical 3,000 impressions a day, 18,000 a week
;;;                 recorded: Ponder and Quinny by the week -- 15,200; 13,800;
;;;                 9,700; 12,700; 10,700; 17,000. Green single-handed 8,250 one
;;;                 week and 4,750 the next (p. 10)
;;;
;;; Those named men are the shop's BEST sustained performances, not its average.
;;; A constant-rate scheduler would reproduce McKerrow's equation -- the thing
;;; this experiment exists to falsify -- and would look rigorous doing it.
;;;
;;; AND IT MUST NOT OPTIMISE. Mcllwraith, whom McKenzie quotes approvingly
;;; (p. 25 n. 41): printers "were sometimes willing to interrupt their work for
;;; quite a slight cause. This in turn suggests that time was not at a premium,
;;; and casts some doubt on any argument which rests on the assumption that
;;; speed was economically important." So the scheduler is a queue, not a
;;; solver. Nothing here tries to balance composition against presswork, because
;;; the belief that a shop did so is one of the things under test.
;;;
;;; DETERMINISM. Nothing here uses threads or real time. The shop advances
;;; whichever job's clock reads earliest, ties broken by the order the jobs were
;;; declared, so a seed names a run exactly as it did before. That matters more
;;; than it sounds: the interleaving changes the order in which the shared case
;;; is drawn from, so a per-seed diff between "alone" and "concurrent" is
;;; dominated by re-randomisation rather than by concurrency. Score over seeds,
;;; never within one.

(require racket/list racket/generator racket/math
         "book.rkt" "typecase.rkt" "rng.rkt" "metrics.rkt" "imposition.rkt")

(provide (struct-out shop) (struct-out job) (struct-out shop-result)
         make-shop run-shop
         ENS-PER-DAY-RECORDED HOURS-PER-DAY compose-hours page-ens-full
         shop-book shop-elsewhere shop-shared-sorts shop-book-sorts)

;; ---------------------------------------------------------------------------
;; The clock
;; ---------------------------------------------------------------------------

;; A twelve-hour day, which is the multiplier McKenzie uses to turn an hourly
;; rate into a daily one (p. 8).
(define HOURS-PER-DAY 12)

;; The three sustained daily averages he names, in ens (p. 9). They are the top
;; of the shop's range, not its middle, and the spread is drawn to say so: a
;; man's day is anywhere from a third of the best figure to the best figure, and
;; the low end is the commoner. Hence the beta, which is not a fitted curve --
;; no source gives a distribution -- but a statement that "often the daily
;; totals were well below these figures" and never above them.
(define ENS-PER-DAY-RECORDED '(6307 5700 5603))
(define ENS-PER-DAY-BEST (apply max ENS-PER-DAY-RECORDED))
(define ENS-PER-DAY-FLOOR (exact-round (/ ENS-PER-DAY-BEST 3)))

;; What one page costs the man who set it, in hours. Drawn fresh each page,
;; because the variance IS the finding -- a man who set at one rate all week is
;; the hypothetical shop, not the recorded one.
(define (compose-hours ens g)
  (define per-day
    (+ ENS-PER-DAY-FLOOR
       (* (- ENS-PER-DAY-BEST ENS-PER-DAY-FLOOR) (rnd-beta g 2.0 3.0))))
  (* HOURS-PER-DAY (/ ens (max 1.0 per-day))))

;; ---------------------------------------------------------------------------
;; The jobs
;; ---------------------------------------------------------------------------

;; `kind'     -- 'book (a real one, reported on) or 'ballast (the house's other work)
;; `step'     -- advance it once; #f when it has finished
;; `clock'    -- hours of shop time this job has consumed
;; `standing' -- sorts it is holding in standing formes just now
;; `result'   -- the book, once there is one
(struct job (name kind [step #:mutable] [clock #:mutable]
                  [standing #:mutable] [result #:mutable]
                  [ens #:mutable] [pages #:mutable])
  #:transparent)

(struct shop (case jobs rng) #:transparent)

;; `book' is the job that was asked for; `others' are the ballast loads; `hours'
;; is how long the house took over the lot.
(struct shop-result (book jobs hours) #:transparent)

(define (shop-book r)
  (for/or ([j (in-list (shop-result-jobs r))])
    (and (eq? (job-kind j) 'book) (job-result j))))

;; How many sorts the house's other work is holding, from one job's point of
;; view. This is what makes the type ceiling a fact about the house.
(define (shop-elsewhere s me)
  (for/sum ([j (in-list (shop-jobs s))] #:unless (eq? j me)) (job-standing j)))

;; ---------------------------------------------------------------------------
;; Ballast
;; ---------------------------------------------------------------------------
;; The house's other work, modelled as what it actually does to this book: it
;; empties boxes and it holds metal.
;;
;; Its characters come from the copy already in hand, cycled. Not the corpus --
;; `corpus/' is gitignored, so anything depending on it works here and nowhere
;; else -- and nothing generated, which would be invention. The claim this rests
;; on is that what a case feels is a letter-frequency load, and two English
;; books of the period do not differ enough in letter frequency to change which
;; boxes run thin. That is measurable rather than assumed; `tools/ballast-check.py'
;; measures it.
;;
;; A ballast forme is built a page at a time so that it holds metal for a while
;; and then gives it back, which is the only behaviour of it that this book can
;; feel.
;; A page of jobbing work, in ens: the format's measure times its lines, two ens
;; to the em. FULL, where a page of a book comes out about four fifths full once
;; the white lines and the broken paragraphs are taken off -- a catalogue or a
;; sheet of Votes is set solid, and those are what the ledger actually lists.
;;
;; The two readings bracket McKenzie's own figure rather than being fitted to
;; it: a quarto sheet is 12,768 ens set solid and 10,320 as this program's books
;; come out, against his "some 10,000 to 12,000 ens" for a quarto sheet (p. 8).
(define (page-ens-full fmt)
  (exact-round (* 2 (book-format-columns fmt)
                  (book-format-measure-ems fmt)
                  (book-format-lines fmt))))

(define (make-ballast-step s j sheets fmt text)
  (define tc (shop-case s))
  (define per-page (page-ens-full fmt))
  (define pages-per (book-format-pages fmt))
  ;; two formes to a sheet, however many sheets make up a gathering
  (define pages-per-forme
    (max 1 (quotient pages-per (* 2 (book-format-sheets fmt)))))
  (define total-pages (* sheets pages-per))
  (define cursor (box 0))
  (define page-no (box 0))
  ;; formes standing: a list of (pieces . chars), given back in order
  (define standing (box '()))

  (define (take-chars n)
    (define len (string-length text))
    (define out (make-string n))
    (for ([i (in-range n)])
      (string-set! out i (string-ref text (modulo (+ (unbox cursor) i) len))))
    (set-box! cursor (modulo (+ (unbox cursor) n) len))
    out)

  (define (set-one-page!)
    (define chars (take-chars per-page))
    (define pieces
      (for/fold ([acc '()]) ([ch (in-string chars)])
        (define d (pick! tc ch))
        (if (draw-piece d) (cons (draw-piece d) acc) acc)))
    (for ([p (in-list pieces)])
      (note-recurrence! tc p (list (unbox page-no) 0 0 0)))
    (set-box! standing (append (unbox standing) (list (cons pieces chars))))
    (set-box! page-no (add1 (unbox page-no)))
    (set-job-standing! j (+ (job-standing j)
                            (for/sum ([c (in-string chars)])
                              (if (char-whitespace? c) 0 1))))
    (string-length chars))

  ;; ONE FORME, AND NOT ONE GATHERING, which is the difference between jobbing
  ;; work and a book. It is also the difference between a model and an
  ;; impossibility: a folio-in-sixes gathering set solid is 63,360 ens, and the
  ;; house fount is 31,200 sorts, so a ballast job holding a gathering would be
  ;; holding twice the metal in the building. Held that way it blew the shop
  ;; ceiling permanently and drove every book to distribute after every page --
  ;; which destroyed Hinman's criterion completely, and looked exactly like the
  ;; finding this module was built to look for.
  ;;
  ;; A half-sheet is what the ledger actually records anyway: "imposing 3 half
  ;; sheets", "a Greek quarto page", "an English folio page" (appendix II(d)).
  (define (give-back!)
    (let loop ()
      (when (> (length (unbox standing)) pages-per-forme)
        (define oldest (car (unbox standing)))
        (set-box! standing (cdr (unbox standing)))
        (distribute! tc (cdr oldest))
        (distribute-pieces! tc (car oldest))
        (set-job-standing! j (max 0 (- (job-standing j)
                                       (for/sum ([c (in-string (cdr oldest))])
                                         (if (char-whitespace? c) 0 1)))))
        (loop))))

  (lambda ()
    (cond
      [(>= (unbox page-no) total-pages)
       ;; finished: everything still standing goes back to the case
       (for ([held (in-list (unbox standing))])
         (distribute! tc (cdr held))
         (distribute-pieces! tc (car held)))
       (set-box! standing '())
       (set-job-standing! j 0)
       #f]
      [else
       (define n (set-one-page!))
       (give-back!)
       ;; a ballast page is charged at the same ens as it set characters, which
       ;; is McKenzie's own equivalence -- "1000 ens or letters an hour" (p. 8)
       n])))

;; ---------------------------------------------------------------------------
;; Building and running the house
;; ---------------------------------------------------------------------------

;; `h'        -- the house, as `book.rkt' means it
;; `copy'     -- the copy for the book under test
;; `ballast'  -- a list of sheet-counts, one per other job in the house
;; `shared-ceiling?' exists to take the two channels apart, and they are
;; different claims about the same shop. With it on, the house's metal is one
;; pool and this book distributes sooner because the other work is holding type
;; -- a shortage argument. With it off, the case is still shared, so type still
;; travels out to another job and back, but this book's decision to distribute
;; is its own -- a circulation argument. Running both says which one does the
;; damage, and neither can be read off the other.
(define (make-shop h copy [copy-kind 'auto]
                   #:ballast [ballast '()]
                   #:shared-ceiling? [shared-ceiling? #t]
                   #:seed [seed (house-seed h)])
  (define tc (make-type-case #:scale (house-case-scale h)
                             #:condition (house-condition h)
                             #:rng (make-rng (+ seed 1))))
  (define book-job (job 'book 'book #f 0.0 0 #f 0 0))
  (define ballast-jobs
    (for/list ([sheets (in-list ballast)] [i (in-naturals)])
      (job (string->symbol (format "ballast~a" (add1 i))) 'ballast #f 0.0 0 #f 0 0)))
  (define s* (shop tc (cons book-job ballast-jobs) (make-rng (+ seed 9001))))

  ;; The book under test. It is handed the shared case and a way of asking how
  ;; much metal the rest of the house is holding.
  (define g (set-book/steps h copy copy-kind
                            #:job 'book
                            #:case tc
                            #:standing-elsewhere
                            (lambda ()
                              (if shared-ceiling? (shop-elsewhere s* book-job) 0))))
  (set-job-step! book-job
                 (lambda ()
                   (cond
                     [(eq? (generator-state g) 'done) #f]
                     [else
                      (set-case-job! tc 'book)
                      (define v (g))
                      (cond
                        [(tick? v)
                         (set-job-standing! book-job (tick-standing v))
                         (set-job-pages! book-job (add1 (job-pages book-job)))
                         (tick-ens v)]
                        [else
                         (set-job-result! book-job v)
                         (set-job-standing! book-job 0)
                         #f])])))

  (for ([bj (in-list ballast-jobs)] [sheets (in-list ballast)])
    (define step (make-ballast-step s* bj sheets (house-fmt h) copy))
    (set-job-step! bj (lambda ()
                        (set-case-job! tc (job-name bj))
                        (define n (step))
                        (when n (set-job-pages! bj (add1 (job-pages bj))))
                        n)))
  s*)

;; How much of this book's type stood in another job's forme at some point --
;; the one number the THE HOUSE section exists to print, and the whole of what
;; concurrency does to the recurrence evidence.
;;
;; A piece counts when the case's record has it printing both in the book and in
;; something else. From the bibliographer's side those other appearances are not
;; evidence he is missing; they are an interval in which the piece was simply
;; absent, and its return looks like a fresh distribution.
(define (shop-shared-sorts s)
  (define rec (tcase-recurrence (shop-case s)))
  (for/sum ([(id places) (in-hash rec)])
    (define jobs (for/list ([p (in-list places)]) (car p)))
    (if (and (memq 'book jobs) (ormap (lambda (j) (not (eq? j 'book))) jobs)) 1 0)))

;; And how many of this book's pieces there were to begin with, so the share can
;; be stated rather than the count alone.
(define (shop-book-sorts s)
  (define rec (tcase-recurrence (shop-case s)))
  (for/sum ([(id places) (in-hash rec)])
    (if (memq 'book (for/list ([p (in-list places)]) (car p))) 1 0)))

;; The loop. Advance whichever job's clock reads earliest; ties by declaration
;; order, so the run is reproducible. A job that returns #f has finished.
(define (run-shop s)
  (define g (shop-rng s))
  (let loop ()
    (define live (filter (lambda (j) (job-step j)) (shop-jobs s)))
    (unless (null? live)
      (define next
        (for/fold ([best (car live)]) ([j (in-list (cdr live))])
          (if (< (job-clock j) (job-clock best)) j best)))
      (define ens ((job-step next)))
      (cond
        [ens
         (set-job-ens! next (+ (job-ens next) ens))
         (set-job-clock! next (+ (job-clock next) (compose-hours ens g)))]
        [else (set-job-step! next #f)])
      (loop)))
  (shop-result (for/or ([j (in-list (shop-jobs s))])
                 (and (eq? (job-kind j) 'book) (job-result j)))
               (shop-jobs s)
               (apply max 0.0 (map job-clock (shop-jobs s)))))

(module+ test
  (require rackunit racket/file racket/runtime-path)
  (define-runtime-path areo-sample "samples/areopagitica.txt")

  ;; THE CONTROL ARM. A shop with one job and no ballast must give back the book
  ;; the old straight-through loop gave, or the experiment compares concurrency
  ;; against a moved baseline and every conclusion from it is worthless.
  (let ()
    (define txt (file->string areo-sample))
    (define (house) (make-house #:seed 5 #:compositors '("A" "B")))
    (define alone (set-book (house) txt 'prose))
    (define r (run-shop (make-shop (house) txt 'prose)))
    (define shopped (shop-result-book r))
    (check-equal? (length (book-pages shopped)) (length (book-pages alone))
                  "the shop with one job sets the same number of pages")
    (check-equal? (for/list ([p (in-list (book-pages shopped))]) (page-text p))
                  (for/list ([p (in-list (book-pages alone))]) (page-text p))
                  "and sets exactly the same type on every one of them")
    (check-true (> (shop-result-hours r) 0) "and the clock ran"))

  ;; The clock is a spread, not a rate. Two pages of identical size must not
  ;; cost identical time, or this has rebuilt the hypothetical shop.
  (let ()
    (define g (make-rng 7))
    (define costs (for/list ([i 40]) (compose-hours 1000 g)))
    (check-true (> (length (remove-duplicates costs)) 30)
                "a man's day is drawn, not assumed")
    ;; and never faster than the best sustained rate any of his three men managed
    (check-true (for/and ([c (in-list costs)])
                  (>= c (* HOURS-PER-DAY (/ 1000 ENS-PER-DAY-BEST))))
                "and never better than Pokins at his best")))
