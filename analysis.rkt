#lang racket/base
;;; The New Bibliography, run on a book whose secrets we happen to know.
;;;
;;; Everything else makes a book. This module forgets how it was made and
;;; tries to find out, using only what is printed on the page -- which is the
;;; bibliographer's actual situation. It then scores itself against the
;;; record, which is the bibliographer's dream.
;;;
;;; Read the last section before believing any of the numbers.

(require racket/list racket/string racket/math racket/set
         "metrics.rkt" "orthography.rkt" "typecase.rkt" "copytext.rkt"
         "corrector.rkt" "compositor.rkt" "imposition.rkt" "book.rkt" "deviation.rkt" "pagination.rkt"
         "prelims.rkt" "titlepage.rkt" "binding.rkt" "cancels.rkt" "import.rkt"
         "press.rkt" "render.rkt" "paper.rkt")

(provide (struct-out page-evidence)
         spelling-evidence attribution-report contamination-report
         skeleton-report castingoff-report case-report press-report
         description full-report MCKENZIE)

(define word-rx #px"[A-Za-zſÀ-ɏﬀﬁﬂﬃﬄ'’]+")

(define (normalise w)
  (string-trim (string-downcase (strip-conventions w)) #px"['’]" #:repeat? #t))

;; ---------------------------------------------------------------------------
;; 1. Compositor attribution from spelling
;; ---------------------------------------------------------------------------

;; `candidates' is the set of workmen the counts cannot separate. Where two
;; men share their preferences -- A and D do, exactly -- the honest verdict is
;; not "no evidence" but "one of these two", and the report should say so
;; rather than quietly scoring it as a failure.
(struct page-evidence (sig counts jcounts tests verdict candidates margin truth
                           crowded?)
  #:transparent)

;; Blayney's practice, and a real advance on counting every occurrence alike:
;; tabulate the justified and the unjustified separately. "The letter 'j'
;; indicates occurrences in justified lines, and an entry such as '2j1' shows
;; two occurrences considered to be unjustified and a third in a justified
;; line" (i. 160). A line is justified if it reaches the right-hand margin;
;; only what stands in a *short* line is evidence of the man rather than of
;; the measure, so the attribution is made on the unjustified counts alone
;; and the justified ones are shown but not weighed.
(define (line-justified? l measure)
  (and (pair? (set-line-words l))
       (not (set-line-quadded? l))
       (>= (line-set-width l) (- measure 2))))

(define (spelling-evidence b [names '("A" "B")])
  (for/list ([p (in-list (book-pages b))])
    (define counts (make-hash))    ; unjustified: the evidence that counts
    (define jcounts (make-hash))   ; justified: shown, but not weighed
    (for ([n (in-list names)]) (hash-set! counts n 0) (hash-set! jcounts n 0))
    (define found '())
    (for* ([l (in-list (page-all-lines p))]
           [w (in-list (set-line-words l))])
      (define tally (if (line-justified? l (set-line-measure l)) jcounts counts))
      (for ([raw (in-list (regexp-match* word-rx (word-printed w)))])
        (define norm (normalise raw))
        (define head (head-form norm))
        (cond
          [head
         ;; A form counts for *every* workman whose habit it answers, not
         ;; merely the first in the list. doe is evidence for A, C and D
         ;; alike; heere is evidence for B and C. Stopping at the first match
         ;; would silently deny the later men any evidence at all, and make a
         ;; four-compositor book look like a two-compositor one.
           (define forms (hash-ref SPELLING-TESTS head))
           (define matched
             (for/list ([n (in-list names)]
                        #:when (and (hash-has-key? forms n)
                                    (string=? (string-downcase (hash-ref forms n)) norm)))
               n))
           (for ([n (in-list matched)]) (hash-update! tally n add1 0))
           (unless (null? matched)
             (set! found (cons (list head norm) found)))]
          [else
           ;; the pattern tests, which is where most of the evidence is
           (define-values (rule who) (pattern-witness norm names))
           (when (and who (hash-has-key? counts who))
             (hash-update! tally who add1 0)
             (set! found (cons (list rule norm) found)))])))

    (define ranked (sort (for/list ([n (in-list names)]) (cons n (hash-ref counts n 0)))
                         > #:key cdr))
    (define top (if (null? ranked) 0 (cdr (car ranked))))
    (define tied (for/list ([r (in-list ranked)] #:when (= (cdr r) top)) (car r)))
    (define next (for/first ([r (in-list ranked)] #:when (< (cdr r) top)) (cdr r)))
    (define-values (verdict candidates margin)
      (if (zero? top)
          (values "?" '() 0)
          (values (string-join tied "/") tied (- top (or next 0)))))
    (page-evidence (page-sig p) counts jcounts (reverse found) verdict candidates
                   margin (page-compositor p) (> (abs (page-pressure p)) 0.35))))

;; Blayney's notation: "2j1" is two occurrences in short lines and one in a
;; justified line. Only the first number is evidence.
(define (blayney-count e n)
  (define u (hash-ref (page-evidence-counts e) n 0))
  (define j (hash-ref (page-evidence-jcounts e) n 0))
  (cond
    [(and (zero? u) (zero? j)) "0"]
    [(zero? j) (number->string u)]
    [else (format "~aj~a" u j)]))

(define (resolved? e)
  (and (= 1 (length (page-evidence-candidates e)))
       (string=? (car (page-evidence-candidates e)) (page-evidence-truth e))))

(define (narrowed? e)
  (and (> (length (page-evidence-candidates e)) 1)
       (member (page-evidence-truth e) (page-evidence-candidates e))
       #t))

(define (attribution-report ev [names '("A" "B")])
  (define w (max 8 (+ 2 (apply max 4 (map string-length names)))))
  (define header
    (format "  ~a ~a ~a ~a ~a"
            (pad "sig." 8)
            (string-join (for/list ([n (in-list names)]) (pad n w)) " ")
            (pad "given" (* 2 w)) (pad "truth" w) (pad "margin" 6)))
  (define rows
    (for/list ([e (in-list ev)])
      (define mark
        (cond
          [(string=? (page-evidence-verdict e) "?") "no evidence"]
          [(resolved? e) ""]
          [(narrowed? e) "narrowed, not resolved"]
          [else (string-append "✗ WRONG"
                               (if (page-evidence-crowded? e) " (crowded page)" ""))]))
      (format "  ~a ~a ~a ~a ~a ~a"
              (pad (page-evidence-sig e) 8)
              (string-join
               (for/list ([n (in-list names)])
                 (pad (blayney-count e n) w)) " ")
              (pad (page-evidence-verdict e) (* 2 w))
              (pad (page-evidence-truth e) w)
              (pad (number->string (page-evidence-margin e)) 6)
              mark)))

  (define judged (filter (lambda (e) (not (string=? (page-evidence-verdict e) "?"))) ev))
  (define right (filter resolved? judged))
  (define narrow (filter narrowed? judged))
  (define crowded (filter page-evidence-crowded? judged))
  (define crowded-right (filter resolved? crowded))
  (define clean (filter (lambda (e) (not (page-evidence-crowded? e))) judged))
  (define clean-right (filter resolved? clean))

  (string-join
   (append
    (list "THE STINTS, RECOVERED FROM SPELLING"
          ""
          "  Test spellings counted on each page, and the page given to the"
          "  workman whose habits it agrees with. 'Truth' is what the record"
          "  of composition says; the bibliographer does not have it."
          ""
          header
          (string-append "  " (make-string (- (string-length header) 2) #\─)))
    rows
    (list ""
          (format "  Attributed: ~a of ~a pages (~a gave no evidence)."
                  (length judged) (length ev) (- (length ev) (length judged))))
    (if (null? judged) '()
        (append
         (list (format "  Resolved to one man and right: ~a (~a%).  Wrong: ~a."
                       (length right) (pct (length right) (length judged))
                       (- (length judged) (length right) (length narrow))))
         (if (null? narrow) '()
             (append
              (list
               (format "  Narrowed but not resolved: ~a — the counts cannot"
                       (length narrow))
               "  separate men who share their preferences on the words that")
              (list (format "  happen to occur: ~a."
                            (string-join
                             (remove-duplicates
                              (for/list ([e (in-list narrow)])
                                (string-join (page-evidence-candidates e) "/")))
                             ", ")))
              (list
               "  Where two men agree throughout — Jaggard's A and D do — no"
               "  spelling test will ever part them. Hinman parted those two"
               "  by the type-case, D being the man who brought case z into"
               "  use in quire K (i. 196).")))))
    (if (null? crowded) '()
        (append
         (list (format "  On crowded or spun-out pages the method is right ~a of ~a (~a%)."
                       (length crowded-right) (length crowded)
                       (pct (length crowded-right) (length crowded))))
         (if (null? clean) '()
             (list (format "  On pages set at ease it is right ~a of ~a (~a%)."
                           (length clean-right) (length clean)
                           (pct (length clean-right) (length clean)))))
         (list ""
               "  A compositor short of room spells to fit the measure, not"
               "  to please himself. Hinman makes the point against his own"
               "  method and gives the instances: A setting 'do' for his"
               "  normal 'doe' in a long prose line, B contracting 'heere'"
               "  to 'here' and expanding 'go' to 'goe' in the same page of"
               "  Troilus. 'Evidence from spelling is far less reliable for"
               "  purposes of compositor identification in prose passages"
               "  and in long lines of verse than elsewhere' (i. 186-7)."))))
   "\n"))

(define (pad s n)
  (if (>= (string-length s) n) s (string-append s (make-string (- n (string-length s)) #\space))))

;; real->decimal-string with 0 places leaves a trailing point ("100."), which
;; looks like a typo in a report meant to be read.
(define (pct a b) (if (zero? b) "0" (number->string (exact-round (* 100.0 (/ a b))))))

;; ---------------------------------------------------------------------------
;; What the bibliographer cannot see
;; ---------------------------------------------------------------------------

(define (contamination-report b)
  (define counts (make-hash))
  (define devices (make-hash))
  (for* ([p (in-list (book-pages b))]
         [l (in-list (page-all-lines p))]
         [w (in-list (set-line-words l))])
    (define just (filter (lambda (c) (string-prefix? c "justification")) (word-causes w)))
    (cond
      [(pair? just)
       (hash-update! counts 'justification add1 0)
       (for ([c (in-list just)])
         (hash-update! devices (string-trim (cadr (string-split c ": "))) add1 0))]
      [(not (string=? (word-habit w) (word-read w))) (hash-update! counts 'habit add1 0)]
      [(not (string=? (word-read w) (word-copy w))) (hash-update! counts 'misread add1 0)]
      [else (hash-update! counts 'copied add1 0)]))
  (define total (for/sum ([(k v) (in-hash counts)]) v))

  (string-join
   (append
    (list "THE SAME EVIDENCE, WITH THE ANSWERS"
          ""
          "  Every word set, classified by why it has the form it has."
          "")
    (if (null? (book-preparation b)) '()
        (let ([kinds (make-hash)])
          (for ([c (in-list (book-preparation b))])
            (hash-update! kinds (change-kind c) add1 0))
          (list
           (format "  Before the compositors: the corrector made ~a alteration(s)"
                   (length (book-preparation b)))
           (format "  to the copy itself (~a)."
                   (string-join (for/list ([(k n) (in-hash kinds)])
                                  (format "~a ~a" n k)) ", "))
           "  These are house habits, not any workman's, so they fall evenly"
           "  across every stint and can never be told from a compositor's"
           "  own practice by counting. They are not in the figures below,"
           "  which begin from the copy as the compositor received it."
           "")))
    (if (zero? total) '()
        (list
         (format "  ~a  followed the copy                        (~a%)"
                 (pad (number->string (hash-ref counts 'copied 0)) 6)
                 (real->decimal-string (* 100.0 (/ (hash-ref counts 'copied 0) total)) 2))
         (format "  ~a  altered by the compositor's habit        (~a%)"
                 (pad (number->string (hash-ref counts 'habit 0)) 6)
                 (real->decimal-string (* 100.0 (/ (hash-ref counts 'habit 0) total)) 2))
         (format "  ~a  altered to make the line justify         (~a%)"
                 (pad (number->string (hash-ref counts 'justification 0)) 6)
                 (real->decimal-string (* 100.0 (/ (hash-ref counts 'justification 0) total)) 2))
         (format "  ~a  misread from the copy                    (~a%)"
                 (pad (number->string (hash-ref counts 'misread 0)) 6)
                 (real->decimal-string (* 100.0 (/ (hash-ref counts 'misread 0) total)) 2))
         ""
         "  Only the first of these leaves the copy-text recoverable. The"
         "  second is the evidence the spelling tests use; the third is the"
         "  noise that spoils it; the fourth is what an editor emends."))
    (if (zero? (hash-count devices)) '()
        (cons "" (cons "  Devices used to make lines justify:"
                       (for/list ([kv (in-list (take (sort (hash->list devices) > #:key cdr)
                                                     (min 14 (hash-count devices))))])
                         (format "    ~a ~a" (pad (car kv) 42) (cdr kv)))))))
   "\n"))

;; ---------------------------------------------------------------------------
;; Skeletons, casting off, the case, the press
;; ---------------------------------------------------------------------------

(define (skeleton-report b)
  (define fmt (book-fmt b))
  (define forme-of (make-hash))
  (for ([g (in-range (book-gatherings b))])
    (for* ([fm (in-list (formes-for-gathering fmt g))]
           [pn (in-list (forme-page-numbers fm))]
           [p (in-list (book-pages b))])
      (when (and (= (page-ref-gathering (page-pref p)) g)
                 (= (page-ref-number (page-pref p)) pn))
        (hash-set! forme-of (page-sig p) (forme-name fm)))))

  (define prints (make-hash))
  (define forme-titles (make-hash))
  (for ([p (in-list (book-pages b))] #:when (page-running-title p))
    (define fp (title-fingerprint (page-running-title p)))
    (hash-update! prints fp (lambda (xs) (append xs (list (page-sig p)))) '())
    (hash-update! forme-titles (hash-ref forme-of (page-sig p) "?")
                  (lambda (xs) (append xs (list fp))) '()))

  ;; formes sharing a damaged title were made ready from the same skeleton
  (define groups '())
  (for ([(fm fps) (in-hash forme-titles)])
    (define hit
      (for/or ([grp (in-list groups)])
        (and (for/or ([f (in-list grp)])
               (not (null? (set-intersect fps (hash-ref forme-titles f '())))))
             grp)))
    (set! groups
          (if hit
              (for/list ([grp (in-list groups)])
                (if (eq? grp hit) (append grp (list fm)) grp))
              (append groups (list (list fm))))))

  (string-join
   (append
    (list "THE SKELETONS, RECOVERED FROM DAMAGED RUNNING TITLES"
          ""
          "  A running title is standing furniture, lifted from one forme to"
          "  the next with its damage on it. Formes that share a damaged"
          "  title were made ready from the same skeleton."
          "")
    (append*
     (for/list ([grp (in-list groups)] [i (in-naturals 1)])
       (append (list (format "  Recovered skeleton ~a — used for ~a forme(s):"
                             (make-string i #\I) (length grp)))
               (for/list ([f (in-list grp)]) (format "      ~a" f))
               (list ""))))
    (list (format "  Distinct damaged titles identified: ~a" (hash-count prints))
          ""
          "  The record says:")
    (for/list ([sk (in-list (book-skeletons b))])
      (format "      ~a ~a forme(s)" (pad (skeleton-name sk) 16)
              (length (skeleton-used-for sk))))
    (list ""
          (format "  Recovered ~a skeleton(s); the house used ~a.~a"
                  (length groups)
                  (length (filter (lambda (s) (pair? (skeleton-used-for s)))
                                  (book-skeletons b)))
                  (if (= (length groups)
                         (length (filter (lambda (s) (pair? (skeleton-used-for s)))
                                         (book-skeletons b))))
                      "  Agreement."
                      "  The recovery is imperfect — as Hinman's first pass was."))))
   "\n"))

;; The scheme of imposition, set out so it can be checked against McKerrow.
;;
;; The pages of a forme are not consecutive. A folio in sixes is three sheets
;; quired one within another, so the outermost sheet carries the outermost
;; pages: 1 and 12 lie side by side on its outer forme, 2 and 11 on its inner.
;; Nothing can be printed until both pages of a forme stand in type, which is
;; why the order of setting matters as much as the order of imposition.
(define (book-by-formes? b) (standing-type-by-formes? (book-standing b)))

(define (imposition-lines b)
  (define fmt (book-fmt b))
  (append
   (list "  The scheme of imposition"
         ""
         (format "    ~a: ~a leaves, ~a page(s), ~a sheet(s) quired"
                 (book-format-name fmt) (book-format-leaves fmt)
                 (book-format-pages fmt) (book-format-sheets fmt))
         "")
   (for/list ([s (in-list (sheet-scheme fmt))] [i (in-naturals 1)])
     (format "    sheet ~a   outer forme ~a   inner forme ~a"
             i
             (pad (format "~a" (sort (car s) <)) 22)
             (format "~a" (sort (cdr s) <))))
   (list ""
         (format "    Set in the order: ~a"
                 (setting-order fmt 0 (book-by-formes? b)))
         (if (book-by-formes? b)
             "    -- by formes, from the middle of the gathering outward, so
       that each sheet can be printed off and distributed before the
       next is begun."
             "    -- straight through the copy, so the first sheet cannot be
       perfected until the last page of the gathering is set.")
         "")))

(define (castingoff-report b)
  (define bad (filter (lambda (p) (> (abs (page-pressure p)) 0.35)) (book-pages b)))
  (string-join
   (append
    (list "THE CASTING OFF, RECOVERED FROM CROWDED AND GAPING PAGES"
          "")
    (imposition-lines b)
    (list ""
          "  Where the copy was measured out wrong the compositor had to"
          "  make it fit. Pages that are visibly crowded or visibly spun out"
          "  mark the joins."
          "")
    (if (null? bad)
        (list "  No page shows serious strain; the casting off was good,"
              "  or the book was set seriatim and the surplus carried on."
              ""
              "  Note that verse casts off almost exactly and prose does not"
              "  (Gaskell, p. 41), so in verse copy the strain is expected to"
              "  be slight and to fall where the prose is.")
        (append
         (append*
          (for/list ([p (in-list bad)])
            (cons (format "  ~a ~a ~a ~a"
                          (pad (page-sig p) 8)
                          (pad (if (> (page-pressure p) 0) "crowded" "spun out") 9)
                          (pad (page-forme-name p) 26)
                          (page-cast-off-note p))
                  (if (null? (page-omitted p)) '()
                      (cons (format "           ~a line(s) of copy dropped altogether:"
                                    (length (page-omitted p)))
                            (for/list ([t (in-list (take (page-omitted p)
                                                         (min 3 (length (page-omitted p)))))])
                              (format "             “~a…”"
                                      (substring t 0 (min 58 (string-length t))))))))))
         (list ""
               "  Strain concentrated within particular formes rather than"
               "  spread evenly through the gathering is the mark of setting"
               "  by formes: the compositor could not carry his surplus"
               "  forward, because the next page of copy belonged to another"
               "  forme."))))
   "\n"))

(define (case-report b)
  (define evs (book-events b))
  (define shifts (filter (lambda (e) (eq? (event-kind e) 'shift)) evs))
  (define accidents (filter (lambda (e) (eq? (event-kind e) 'accident)) evs))
  (define copy-errs (filter (lambda (e) (eq? (event-kind e) 'copy)) evs))
  (define ex (tcase-exhausted (book-case b)))
  (define counts (make-hash))
  (for ([e (in-list accidents)])
    (hash-update! counts (string-trim (car (string-split (event-detail e) "("))) add1 0))
  (string-join
   (append
    (list "THE STATE OF THE CASE" ""
          "  Sorts exhausted while formes stood locked up:")
    (if (zero? (hash-count ex))
        (list "      None; the fount held out.")
        (for/list ([kv (in-list (take (sort (hash->list ex) > #:key cdr)
                                      (min 10 (hash-count ex))))])
          (format "      ~a wanted ~a time(s)" (pad (format "~s" (car kv)) 6) (cdr kv))))
    (list "" (format "  Shifts made for want of a sort: ~a" (length shifts)))
    (for/list ([e (in-list (take shifts (min 8 (length shifts))))])
      (format "      ~a ~a" (pad (event-page e) 10) (event-detail e)))
    (list "" (format "  Accidents of the case: ~a" (length accidents)))
    (for/list ([kv (in-list (take (sort (hash->list counts) > #:key cdr)
                                  (min 10 (hash-count counts))))])
      (format "      ~a ~a" (pad (car kv) 46) (cdr kv)))
    (list "" (format "  Errors made in reading the copy: ~a" (length copy-errs)))
    (standing-lines b)
    (recurrence-lines b))
   "\n"))

;; How much metal the gathering ate.
;;
;; McKerrow's point about imposition has a consequence nobody can set type
;; without meeting: in a folio in sixes the outer forme of the first sheet
;; carries pages 1 and 12, so those two pages must stand together before that
;; sheet can be perfected. A house that sets straight through the copy must
;; therefore hold most of a gathering in standing type before it can print
;; anything; a house that casts off and sets by formes, beginning at the
;; middle of the gathering and working outward, need hold only a sheet.
;; The difference is paid for in type, and this is the bill.
(define (standing-lines b)
  (define st (book-standing b))
  (define dep (sort (case-depletion (book-case b)) > #:key cadddr))
  (define spent (for/sum ([r (in-list dep)]) (- (cadr r) (caddr r))))
  (define bill (for/sum ([r (in-list dep)]) (cadr r)))
  (append
   (list ""
         "  STANDING TYPE AND THE DEPLETION OF THE CASE"
         ""
         (format "    Most type standing at once: ~a sorts, in ~a page(s)"
                 (standing-type-peak-sorts st) (standing-type-peak-pages st))
         (format "    The bill of letter:         ~a sorts" bill)
         (format "    At the worst, the cases were ~a% empty"
                 (exact-round (* 100 (/ spent (max 1 bill)))))
         ""
         "    The sorts that came nearest to running out:")
   (for/list ([r (in-list (take dep (min 8 (length dep))))])
     (format "      ~a bill ~a, fell to ~a  (~a% out)"
             (pad (string (car r)) 5) (pad (number->string (cadr r)) 5)
             (pad (number->string (caddr r)) 5)
             (exact-round (* 100 (cadddr r)))))))

;; ---------------------------------------------------------------------------
;; Recurring types: Hinman's actual method
;; ---------------------------------------------------------------------------
;; A piece of type is set, printed, distributed, and picked again. Where a
;; distinctive piece turns up a second time, the two places must have drawn on
;; the same case -- and the order in which such pieces reappear gives the
;; order in which the formes went to press. Hinman identified some six hundred
;; of these and followed each through the Folio; the two volumes are the
;; result. Everything else in this program models his conclusions. This models
;; the evidence.
(define (recurrence-lines b)
  (define rec (tcase-recurrence (book-case b)))
  (define page-forme
    (for/hash ([p (in-list (book-pages b))]) (values (page-sig p) (page-forme-name p))))
  (define repeats
    (sort (for/list ([(id places) (in-hash rec)] #:when (> (length places) 1))
            (cons id places))
          > #:key (lambda (kv) (length (cdr kv)))))
  (define cross
    (for/list ([r (in-list repeats)]
               #:when (> (length (remove-duplicates
                                  (for/list ([pl (in-list (cdr r))])
                                    (hash-ref page-forme (first pl) "?"))))
                         1))
      r))
  (append
   (list ""
         (format "  Individually identifiable types used: ~a" (hash-count rec))
         (format "  Of those, appearing more than once:   ~a" (length repeats))
         (format "  Appearing in more than one forme:     ~a" (length cross)))
   (if (null? cross)
       (list "      None recurred across formes; nothing here would let a"
             "      bibliographer connect one forme to another.")
       (append
        (list "" "  A few of the recurrences, with the formes they connect:")
        (for/list ([r (in-list (take cross (min 6 (length cross))))])
          (format "      ~a  ~a"
                  (pad (car r) 6)
                  (string-join
                   (for/list ([pl (in-list (cdr r))])
                     (format "~a (~a)" (first pl)
                             (hash-ref page-forme (first pl) "?")))
                   " -> ")))))))

(define (press-report b r)
  (define silent (for/sum ([(k s) (in-hash (press-run-states r))]) (forme-state-silent s)))
  (define proofed (filter forme-state-corrected? (hash-values (press-run-states r))))
  (string-join
   (append
    (list "PRESS VARIANTS" ""
          "  Formes corrected in the middle of the run. Sheets printed"
          "  before the correction were not discarded, so the two states"
          "  are mixed through the edition."
          "")
    (if (zero? silent) '()
        (list (format "  Before any of this: ~a literal(s), in ~a forme(s), were mended"
                      silent
                      (for/sum ([(k s) (in-hash (press-run-states r))]
                                #:when (> (forme-state-silent s) 0)) 1))
              "  on a proof pulled before the pressmen began. Those corrections"
              "  leave no variant behind — every copy shows the mended reading,"
              "  and no amount of collation will ever recover them. What follows"
              "  is a record only of the corrections that were made too late."
              ""))
    (if (null? proofed)
        (list "  No forme was corrected at press.")
        (append*
         (for/list ([s (in-list (sort proofed string<? #:key forme-state-forme))])
           (append
            (list (format "  ~a — corrected after about ~a% of the run:"
                          (forme-state-forme s)
                          (exact-round (* 100 (forme-state-fraction-uncorrected s)))))
            (for/list ([v (in-list (forme-state-variants s))])
              (format "      ~a, l.~a:  ~a ] ~a   (~a)"
                      (pvariant-page v) (pvariant-line v)
                      (pvariant-uncorrected v) (pvariant-corrected v)
                      (pvariant-note v)))
            (list "")))))
    (let ([copies (press-run-copies r)])
      (if (< (length copies) 2) '()
          (let ([diffs (collate r (first copies) (second copies))])
            (append
             (list (format "  Collation of ~a against ~a (~a difference(s)):"
                           (printed-copy-name (first copies))
                           (printed-copy-name (second copies))
                           (length diffs))
                   "")
             (if (null? diffs)
                 (list "      The two copies agree throughout.")
                 (for/list ([d (in-list (take diffs (min 24 (length diffs))))])
                   (format "      ~a ~a ] ~a" (pad (first d) 18) (pad (second d) 24)
                           (third d)))))))))
   "\n"))

(define (description b)
  (define fmt (book-fmt b))
  (string-join
   (append
    (list "BIBLIOGRAPHICAL DESCRIPTION" ""
          (format "  Collation:   ~a" (book-collation b))
          (format "  Format:      ~a (~a), ~a fold(s), ~a leaves to the gathering, ~a sheet(s)"
                  (book-format-name fmt) (book-format-symbol fmt)
                  (book-format-folds fmt)
                  (book-format-leaves fmt) (book-format-sheets fmt))
          ;; Format is the folding; size is the sheet. Neither gives a leaf a
          ;; dimension on its own, so the two are reported together.
          (format "  Paper:       ~a, sheet ~a×~a mm."
                  (paper-name (book-paper b))
                  (paper-long (book-paper b)) (paper-short (book-paper b)))
          (let ([L (book-layout b)])
            (format "  Leaf:        ~a×~a mm. uncut; type page ~a×~a mm.; margins i~a h~a o~a t~a~a"
                    (exact-round (layout-leaf-h L)) (exact-round (layout-leaf-w L))
                    (exact-round (layout-type-h L)) (exact-round (layout-type-w L))
                    (exact-round (layout-inner L)) (exact-round (layout-head L))
                    (exact-round (layout-outer L)) (exact-round (layout-tail L))
                    (if (layout-fits? L) "" "  [WILL NOT FIT THE SHEET]")))
          (format "  Measure:     ~a ems of the body, ~a column(s), ~a lines to the page"
                  (real->decimal-string (book-format-measure-ems fmt) 0)
                  (book-format-columns fmt)
                  (* (book-format-lines fmt) (book-format-columns fmt)))
          (format "  Formes:      ~a" (length (book-formes b)))
          ;; counted from the sheets, not assumed from the format: signing is
          ;; the compositor's own act and the number of leaves he signed was
          ;; his own habit
          (let* ([per (for/list ([gat (in-range (book-gatherings b))])
                        (define ls
                          (for/list ([p (in-list (book-pages b))]
                                     #:when (and (= (page-ref-gathering (page-pref p)) gat)
                                                 (not (string=? (page-signature p) ""))))
                            (page-ref-leaf (page-pref p))))
                        (if (null? ls) 0 (apply max ls)))]
                 [ns (sort (remove-duplicates (filter positive? per)) <)])
            (cond
              [(null? ns) "  Signed:      unsigned throughout"]
              [(= 1 (length ns))
               (format "  Signed:      first ~a leaf/leaves of each gathering, recto"
                       (car ns))]
              [else
               (format (string-append "  Signed:      first ~a to ~a leaves, recto; "
                                      "irregular, the men differing in the habit")
                       (car ns) (apply max ns))]))
          ;; McKerrow: catchwords "ordinarily appear at the foot of every
          ;; page" -- but whether each answers the page it faces has to be
          ;; counted, because the compositor caught the word from his copy
          ;; before the next page was set, and may then have resumed at the
          ;; wrong point. A catchword that does not answer is the trace.
          (let* ([ps (book-pages b)]
                 [bad (for/sum ([p (in-list ps)] [nxt (in-list (cdr ps))])
                        (define f
                          (for/or ([l (in-list (page-all-lines nxt))])
                            (and (pair? (set-line-words l))
                                 (word-printed (car (set-line-words l))))))
                        (if (and f (not (string=? (page-catchword p) ""))
                                 (not (string=? (page-catchword p) f)))
                            1 0))])
            (if (zero? bad)
                "  Catchwords:  on every page, each answering the next"
                (format (string-append "  Catchwords:  on every page; ~a do(es) not "
                                       "answer the page it faces")
                        bad)))
          ""
          "  Stints, in the order the pages were actually set:")
    (for/list ([s (in-list (book-stints b))])
      (format "      Compositor ~a ~a"
              (pad (first s) 3)
              (if (string=? (second s) (third s))
                  (second s)
                  (format "~a–~a" (second s) (third s))))))
   "\n"))

;; ---------------------------------------------------------------------------
;; The objection this whole program cannot answer
;; ---------------------------------------------------------------------------

(define MCKENZIE #<<TEXT
WHAT THE SCORES ABOVE DO NOT SHOW

  Every percentage in this report is the analyser inverting the generator.
  Both were written from the same account of how a printing house behaved --
  one book at a time, steady stints, formes in an orderly rotation, a
  compositor who keeps his habits. So a high score demonstrates that the
  simulation is self-consistent. It demonstrates nothing whatever about
  whether the method works on a real book.

  D. F. McKenzie's warning, from the Cambridge University Press accounts of
  1696-1712 and the Bowyer ledgers of the 1730s -- the only two places where
  the working of a hand-press shop can be checked against its surviving
  output -- is that the patterns are "of such an unpredictable complexity,
  even for such a small printing shop, that no amount of inference from what
  we think of as bibliographical evidence could ever have led to their
  reconstruction" ('Printers of the Mind', SB xxii (1969), 7).

  His distinction is worth keeping exactly: the physical actions of setting,
  imposing, proofing and distributing type do not change from century to
  century, and those are what this program models. What varies, and what it
  assumes away, is "the amount of work done and the relations between those
  performing it ... from day to day". Of normality in that second sense he
  says flatly: "it doesn't exist."

  That is not an impression. Table 9 of the Cambridge study gives production
  times for 36 books of ten sheets or more, and the rates run from 0.16
  sheets a week (Terence 12mo, 16 sheets, 97 weeks) to 4.9 (the Threnodia,
  34 sheets, 7 weeks) -- a spread of thirty to one. Only seven of the 36
  averaged more than two sheets a week.

  The sharpest figures are the reprints, where the book is the same, the
  shop is the same, and only the occasion differs:

      Bennet, Answer to the Dissenters   21 sheets    18 weeks
                        second printing  21 sheets     9 weeks
                         third printing  21 sheets    17 weeks
      Le Clerc, Physica                  22 sheets    23 weeks
                        second printing  22 sheets     8 weeks
      Bennet, Confutation of Popery      24 sheets    30 weeks
                        second printing  24 sheets    15 weeks

  The same book took twice or three times as long depending on nothing the
  book itself records. Any argument that reasons from a book's appearance to
  the manner of its printing has to survive that, and mostly cannot.

  A second finding bears directly on what this program assumes. McKenzie
  went through the Vouchers looking for setting by formes and concluded it
  "was followed occasionally but was certainly not normal" (i. 115); and
  where work was shared between compositors, the likely motive was "not to
  make more economical use of a limited supply of type but to find work for
  a waiting compositor" (i. 116). The standing-type figures above are
  therefore arithmetic about a practice, not evidence of one.

  The honest use of a machine like this is therefore not to confirm the
  method but to break it: to generate books under conditions the analyser
  does not know about -- concurrent production, work interrupted for weeks,
  a stint changing hands in mid-forme, setting shared between two houses --
  and see how confidently it returns a tidy and false answer. Only the
  failures here are evidence. The successes are arithmetic.

  Or, as McKenzie quotes at the head of his paper: "A nice adaptation of
  conditions will make almost any hypothesis agree with the phenomena. This
  will please the imagination, but does not advance our knowledge."
TEXT
  )

;; ---------------------------------------------------------------------------
;; The preliminaries, and the binding
;; ---------------------------------------------------------------------------

(define SCHEME-NOTES
  (hash
   'stars "* ** *** — the commonest form, Gaskell p. 52."
   'symbols "* † ‡ § — symbols \"without logical order\" (Gaskell, p. 52)."
   'lower "text A–, preliminaries a– : \"always quite common\" (Gaskell, p. 52)."
   'english "text from B, preliminaries A — \"a characteristically English habit ... to allow for a sheet of preliminaries signed A\" (Gaskell, p. 52). One sheet is allowed for; anything past it is signed a, b, c."
   'continuous "no separate series at all: the main alphabet begins at the preliminaries. Gaskell (p. 8) finds this in reprints, where the extent of the front matter was already known. Where the front matter fills one gathering it is indistinguishable from the English habit above, and the two part company only if it overflows."
   'unsigned "nothing set in the direction line at all; cited as π after McKerrow (p. 156), \"easily recalled by the p of 'preliminary'\"."
   'none "no preliminary matter, so no second series."))

(define (prelims-report b [r #f] [src #f])
  (define div (book-division b))
  (define plans (book-plans b))
  (define front (filter (lambda (p) (eq? (gathering-plan-role p) 'prelim)) plans))
  (define tp (book-titlepage b))
  (string-append
   "THE PRELIMINARIES\n"
   (make-string 74 #\─) "\n\n"
   "Collation: " (book-collation b) "\n\n"
   (if (null? front)
       "The book has no preliminary gathering: the text begins at A1r.\n"
       (format "~a preliminary gathering~a, signed ~a. ~a\n"
               (length front) (if (= 1 (length front)) "" "s")
               (string-join
                (for/list ([p (in-list front)])
                  (format "~a~a" (series-mark (gathering-plan-series p)
                                              (gathering-plan-index p))
                          (if (< (gathering-plan-leaves p)
                                 (book-format-leaves (book-fmt b)))
                              " (half a sheet, worked and turned)" "")))
                ", ")
               (hash-ref SCHEME-NOTES (book-prelim-scheme b) "")))
   "\n"
   ;; The overflow, which is McKerrow's inference and this program's to check.
   (if (and (> (length front) 1) (eq? (book-prelim-scheme b) 'english))
       (string-append
        "The second preliminary series is not a style. The house allowed one\n"
        "sheet signed A and the front matter would not go in it. McKerrow reads\n"
        "the same signature the same way: of a Masque collating \"?, A4, a4,\n"
        "B–E4, F2\" he says the work \"begins on B1 and this is preceded by A\n"
        "and a, the latter signature strongly suggesting that the preliminary\n"
        "matter was more than the printer had expected and allowed for\"\n"
        "(p. 182). Here that inference is right, and the program knows it is.\n\n")
       "")
   (if tp
       (format "Title-page, set from the shop's own formulae:\n\n    ~a\n\n"
               (string-replace (titlepage-transcript tp) " | " "\n    "))
       "No title-page was generated.\n\n")
   ;; Where a book is called for in code rather than from the command line
   ;; there is no source to describe, and the section is simply absent.
   (if src
       (string-append
        "Where the copy came from:\n\n"
        (wrap (format "Read as ~a. ~a" (source-origin src)
                      (string-join (source-notes src) " "))
              74)
        "\n\n")
       "")
   "How the division was arrived at:\n\n"
   (division-summary div) "\n\n"
   (if (division-declared? div)
       ""
       (string-append
        (wrap (string-append
               "Nothing was declared by the document, so the book has no "
               "preliminary matter beyond its title-page. That is the honest "
               "answer and it is the default. The preliminaries a book has are "
               "the ones its copy can be shown to contain: a division the "
               "source names (a TEI type, a LaTeX \\frontmatter, a Word "
               "paragraph style, a Pandoc div), a table built from its own "
               "headings, or a title-page built from its own metadata. Where a "
               "document says none of that, guessing would be inventing. The "
               "heading vocabulary behind --guess-prelims is experimental and "
               "period-bound: it cannot see front matter that carries no "
               "heading, and it knows nothing of modern copy.")
              74)
        "\n\n"))
   (if (and (book-moved-to-end b) (second (book-moved-to-end b)))
       (format
        (string-append
         "~a was NOT bound in front. It was cast off after the text, found to\n"
         "fit the white leaves left in the last sheet, and printed there —\n"
         "which is East's case exactly. Tottel's 1575 Treatise of Moral\n"
         "Philosophy has its Table among the preliminaries; East reprinting it\n"
         "in 1584 \"found he had room for the Table in the last gathering of the\n"
         "book and placed it there\" (McKerrow, p. 78). The same matter, in the\n"
         "same words, preliminary in one edition and terminal in the next,\n"
         "because of how much room was left.\n\n")
        (string-join (map prelim-kind-label (first (book-moved-to-end b))) " and "))
       ;; Said in full when the matter stayed in front, because "nothing
       ;; moved" and "there was nothing that could move" are different facts
       ;; and only one of them is about this book.
       (if (book-moved-to-end b)
           (format
            (string-append
             "~a could have gone to the back and did not. ~a
"
             "The two questions are McKerrow's, in his order: East \"found he had
"
             "room for the Table in the last gathering of the book and placed it
"
             "there\" (p. 78) — so there must be room in the white leaves the text
"
             "has already left, and moving it must actually save leaves at the
"
             "front. Where it saves nothing the matter stays where it is, which is
"
             "Tottel's edition with the same Table before the text.

")
            (string-join (map prelim-kind-label (first (book-moved-to-end b))) " and ")
            (case (third (book-moved-to-end b))
              [(no-room) "There was not enough white paper left in the last sheet to take it."]
              [else "There was room, but the preliminaries take the same number of leaves either way, so nothing would have been saved."]))
           ""))
   (if r (heaps-section b r) "")
   (if r (cancel-section b r) "")
   (if r (binding-section b r) "")))

(define (heaps-section b r)
  (define groups (variant-groupings r))
  (define consistent? (greg-consistent? groups))
  (define n (length (press-run-copies r)))
  (string-append
   "
THE HEAPS, AND THE COPIES GATHERED FROM THEM
"
   (make-string 74 #\─) "

"
   (wrap (format "~a copies gathered from ~a heap~a, in signature order, from the top of each. A copy is therefore not a random handful of corrected and uncorrected sheets: Gaskell (pp. 143-4) shows that \"the order of printing may have been echoed, either directly or inversely, by the order of gathering\", inversely where the sheet was perfected inner forme first and directly where it was perfected outer forme first. The heaps lose ~a of their order at the drying rack, which is a parameter and not a finding -- Gaskell says only that the order was likely but \"not certain\" to survive."
                 n (hash-count (press-run-states r))
                 (if (= 1 (hash-count (press-run-states r))) "" "s")
                 (real->decimal-string (press-run-heap-disorder r) 2))
         74)
   "

"
   (if (zero? (hash-count groups))
       "No forme was corrected at press, so the copies do not differ and there is nothing to group.
"
       (string-append
        "  forme                        perfected first   corrected in
"
        (apply string-append
               (for/list ([(name copies-with) (in-hash groups)])
                 (format "  ~a ~a ~a
" (pad name 28)
                         (pad (if (hash-ref (press-run-perfecting r) name #t)
                                  "inner" "outer") 17)
                         (if (null? copies-with) "none"
                             (string-join (sort (map (lambda (c)
                                                       (string-replace c "Copy " ""))
                                                     copies-with) string<?) " ")))))
        "
"
        (wrap (format "Greg's condition for consistent grouping -- that \"given any two constant groups, either these or their complements are either mutually exclusive or one wholly includes the other\" (Calculus of Variants, p. 12) -- ~a here. That is the test worth watching. A made-up copy descends from no other copy but is assembled from as many heaps as there are sheets, which is conflation by construction, and Greg warns that where \"the grouping is throughout random ... some sort of conflation has somewhere to be assumed\" (p. 43). Gathered as Gaskell describes, the groupings are constant up to complementation and the condition holds; drawn independently, it fails. So the consistency of these groups measures how far the warehouse preserved the order of printing -- and, sheet by sheet, which forme went to press first."
                      (if consistent? "HOLDS" "FAILS"))
              74)
        "
"))))

(define (cancel-section b r)
  (define cp (press-run-cancels r))
  (define cs (cancel-plan-cancels cp))
  (string-append
   "
CANCELS
"
   (make-string 74 #\─) "

"
   (if (null? cs)
       "No leaf was cancelled.

"
       (string-append
        (format "~a lea~a cut out and replaced.

" (length cs)
                (if (= 1 (length cs)) "f" "ves"))
        (apply string-append
               (for/list ([c (in-list cs)]) (format "  ~a" (cancel-note c))))
        "
"))
   (wrap (string-append
          "The purpose of a cancel is not simulated and is not claimed to be. "
          "McKerrow does not attempt it either: \"into the purpose of these "
          "cancels we need not enter ... the point at present is the aid that "
          "bibliography gives us in detecting them\" (p. 223). What is modelled "
          "is the trace — the leaf cut out, the stub left for the replacement to "
          "be pasted to, the white paper the replacement was printed on, and "
          "the marks by which McKerrow says a cancel may be detected. Five of "
          "his six are here; the sixth is the paper, and this program has none.")
         74)
   "
"
   (apply string-append
          (for/list ([n (in-list (cancel-plan-notes cp))])
            (string-append "
" (wrap n 74) "
")))))

(define (binding-section b r)
  (define copies (press-run-copies r))
  (define rate (press-run-binding-error r))
  (define rolls (* (length copies) (length (book-plans b))))
  (define faults
    (append* (for/list ([pc (in-list copies)])
               (for/list ([f (in-list (bound-copy-faults (printed-copy-binding pc)))])
                 (cons (printed-copy-name pc) f)))))
  (define uncaught (filter (lambda (p) (not (fault-caught? (cdr p)))) faults))
  (string-append
   "\nGATHERING, FOLDING AND SEWING\n"
   (make-string 74 #\─) "\n\n"
   ;; The rolls and the expectation are printed whether or not anything
   ;; happened, because a bare zero cannot tell "did not happen" from "could
   ;; not happen here", and this program has misdiagnosed a live mechanism as
   ;; dead for exactly that reason.
   (format "~a cop~a made up, ~a gathering~a apiece: ~a chances of a fault, of which ~a would be expected at ~a per gathering.\n"
           (length copies) (if (= 1 (length copies)) "y" "ies")
           (length (book-plans b))
           (if (= 1 (length (book-plans b))) "" "s")
           rolls (real->decimal-string (* rolls rate) 1)
           (real->decimal-string rate 3))
   (format "~a fault~a occurred; ~a went out uncorrected.\n\n"
           (length faults) (if (= 1 (length faults)) "" "s")
           (length uncaught))
   (if (null? faults)
       ""
       (string-append
        (string-join
         (for/list ([p (in-list faults)])
           (format "  ~a: ~a~a" (car p) (fault-note (cdr p))
                   (if (fault-caught? (cdr p))
                       " — found when the book was collated, and put right"
                       " — NOT found; the copy went out wrong")))
         "\n")
        "\n\n"))
   (wrap (binding-note rate) 74) "\n"))

;; Break a paragraph to a width, for the notes that have to be said in full.
(define (wrap text width)
  (let loop ([ws (string-split text)] [line '()] [len 0] [out '()])
    (cond
      [(null? ws)
       (string-join (reverse (if (null? line)
                                 out
                                 (cons (string-join (reverse line) " ") out)))
                    "\n")]
      [(and (pair? line) (> (+ len 1 (string-length (car ws))) width))
       (loop ws '() 0 (cons (string-join (reverse line) " ") out))]
      [else (loop (cdr ws) (cons (car ws) line)
                  (+ len 1 (string-length (car ws))) out)])))

(define (full-report b [r #f] [names '("A" "B")] #:source [src #f])
  (define ev (spelling-evidence b names))
  (string-join
   (append (list (description b)
                 (prelims-report b r src)
                 (attribution-report ev names)
                 (contamination-report b)
                 (skeleton-report b)
                 (castingoff-report b)
                 (pagination-report (book-paging b))
                 (case-report b)
                 (deviation-report b r))
           (if r (list (press-report b r)) '())
           (list MCKENZIE))
   (string-append "\n\n" (make-string 74 #\═) "\n\n")))

;; report-html lived here. It formatted the analysis as an HTML fragment for
;; the facsimile page, which meant the figures reached the page by a route that
;; did not pass through the TEI -- so the TEI never had to carry them, and did
;; not. They are now in <hp:statistics> and tei-html.rkt renders them from
;; there, which is both one implementation instead of two and a file that is
;; the whole record rather than most of it.

(module+ test
  (require rackunit)
  (define sample
    (apply string-append
           (for/list ([i (in-range 6)])
             (string-append
              "King. And can you by no drift of conference\n"
              "Get from him why he puts on this confusion,\n"
              "Grating so harshly all his days of quiet\n"
              "With turbulent and dangerous lunacy?\n\n"
              "Queen. Did he receive you well, and was he free\n"
              "In his reply, or niggard of his question?\n\n"))))
  (define b (set-book (make-house #:fmt QUARTO #:seed 1623) sample))
  (define r (run-press b #:copies 4 #:seed 1623))
  (define rep (full-report b r))
  (check-true (regexp-match? #px"BIBLIOGRAPHICAL DESCRIPTION" rep))
  (check-true (regexp-match? #px"THE STINTS, RECOVERED FROM SPELLING" rep))
  (check-true (regexp-match? #px"WHAT THE SCORES ABOVE DO NOT SHOW" rep)
              "the report never omits the objection to itself")
  ;; The attribution must actually attribute something.
  (define ev (spelling-evidence b))
  (check-true (> (length (filter (lambda (e) (not (string=? (page-evidence-verdict e) "?"))) ev))
                 0))
  )
