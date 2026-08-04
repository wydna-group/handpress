#lang racket/base
;;; Checking the simulation against a real book.
;;;
;;; Everything else in this program is internally consistent. This file is the
;;; only place it is asked whether it resembles anything that happened.
;;;
;;; THE TEST CASE. Hinman, i. 195, reports quire L of the Folio Comedies --
;;; six pages set by Compositor C at case x. Those pages contain the end of
;;; _Much Ado About Nothing_, reprinted (Greg says) "without material change"
;;; from the quarto of 1600, and the beginning of _Love's Labour's Lost_ from
;;; Q1598. So the copy survives, the compositor is identified, and Hinman has
;;; counted the result. That is a closed loop of a kind the rest of this
;;; program never gets: known input, known workman, counted output.
;;;
;;; His figures for the do/go and here families:
;;;
;;;   "(a) Five of the six do-go spellings of the Folio text are copy
;;;   spellings. Once there is a change from doe to do -- but this is in a
;;;   prose passage where the Folio's 'short' spelling was evidently required
;;;   to justify a line. On the other hand, twenty-two of the Folio's
;;;   twenty-six doe-goe spellings represent changes in the corresponding
;;;   readings of the copy.
;;;
;;;   (b) Six of the seven here spellings in the Folio are also here spellings
;;;   in the copy. There is one change from heere to here: the copy's 'heere
;;;   is' becomes 'here's' in the Folio -- but manifestly in order to save
;;;   space. On the other hand, six of the Folio's fourteen heere spellings
;;;   are alterations of here spellings in the copy, four of these being in
;;;   short lines where the change was certainly not required for the sake of
;;;   justification."
;;;
;;; Three things follow, and all three are testable here.

(require racket/list racket/string racket/math racket/file racket/format
         "metrics.rkt" "orthography.rkt" "compositor.rkt" "copytext.rkt"
         "imposition.rkt" "book.rkt" "rng.rkt")

(provide hinman-quire-L derive-habit-strength run-validation
         run-real-validation count-families)

;; ---------------------------------------------------------------------------
;; The real test: Q1600 copy in, F1623 to check against
;; ---------------------------------------------------------------------------
;; Much Ado was reprinted in the Folio from the quarto of 1600 "without
;; material change" (Greg, quoted at Hinman i. 195). Both texts survive, so
;; the simulation can be given the actual copy and its output compared with
;; what Jaggard's men actually did with it -- which is the one comparison the
;; rest of this program never gets to make.
;;
;; The counts are aggregate, as Hinman's are. Word-for-word alignment of a
;; reprint is a different and harder problem, and proportions are what the
;; spelling tests actually turn on.

(define (count-families text)
  (define t (make-hash))
  (for ([w (in-list (regexp-match* #px"[A-Za-z']+" text))])
    (define low (string-downcase w))
    (case low
      [("doe" "goe") (hash-update! t '(do-go . long) add1 0)]
      [("do" "go")   (hash-update! t '(do-go . short) add1 0)]
      [("heere")     (hash-update! t '(here . long) add1 0)]
      [("here")      (hash-update! t '(here . short) add1 0)]
      [else (void)]))
  t)

(define (share t f)
  (define l (hash-ref t (cons f 'long) 0))
  (define s (hash-ref t (cons f 'short) 0))
  (if (zero? (+ l s)) 0 (/ l (+ l s) 1.0)))

;; ---------------------------------------------------------------------------
;; What Hinman counted
;; ---------------------------------------------------------------------------

;; family -> (list F-long F-short changes-to-long changes-to-short)
;; where "long" is the fuller form (doe/goe, heere) and "short" the other.
(define hinman-quire-L
  (hash
   'do-go  (list 26 6 22 1)     ; 26 doe/goe of which 22 changed; 6 do/go of which 1 changed
   'here   (list 14 7 6 1)))    ; 14 heere of which 6 changed; 7 here of which 1 changed

;; From the counts, the copy's own mix and the strength of the man's habit
;; both fall out by arithmetic.
;;
;;   F-long        = (copy-long kept) + (copy-short changed)
;;   changes-to-long = copy-short * p
;;   F-short       = copy-short * (1 - p)  + (copy-long changed away)
;;
;; so copy-short = changes-to-long + (F-short - changes-to-short), and
;; p = changes-to-long / copy-short.
(define (derive-habit-strength counts)
  (define F-long (first counts))
  (define F-short (second counts))
  (define to-long (third counts))
  (define to-short (fourth counts))
  (define copy-short (+ to-long (- F-short to-short)))
  (define copy-long (+ (- F-long to-long) to-short))
  (values (/ to-long (max 1 copy-short))              ; habit strength
          (/ copy-long (max 1 (+ copy-long copy-short)))))  ; long forms in copy

;; ---------------------------------------------------------------------------
;; Building a copy-text with the quarto's own mix of spellings
;; ---------------------------------------------------------------------------
;; The copy for quire L was a printed quarto, and a quarto has its own
;; inconsistent orthography. Feeding the simulator a modern-spelt text would
;; guarantee that every long form it produced was a "change", which is the
;; question being asked rather than an input to it. So the copy is first spelt
;; to the mix Hinman's own figures imply.

(define (respell text #:do-go q1 #:here q2 #:seed [seed 5])
  (define g (make-rng seed))
  (string-join
   (for/list ([w (in-list (string-split text " "))])
     (define-values (core tail) (split-point w))
     (define low (string-downcase core))
     (define (pick long short q)
       (string-append (match-case core (if (< (rnd g) q) long short)) tail))
     (cond
       [(member low '("do" "doe"))     (pick "doe" "do" q1)]
       [(member low '("go" "goe"))     (pick "goe" "go" q1)]
       [(member low '("here" "heere")) (pick "heere" "here" q2)]
       [else w]))
   " "))

;; ---------------------------------------------------------------------------
;; Measuring the simulated book the way Hinman measured the real one
;; ---------------------------------------------------------------------------

(define (family w)
  (define low (string-downcase (strip-conventions (word-copy w))))
  (define-values (core tail) (split-point low))
  (cond
    [(member core '("do" "doe" "go" "goe")) 'do-go]
    [(member core '("here" "heere")) 'here]
    [else #f]))

(define (long-form? s)
  (define low (string-downcase (strip-conventions s)))
  (define-values (core tail) (split-point low))
  (and (member core '("doe" "goe" "heere")) #t))

;; Hinman's "long lines" are "lines that do use up the whole width of the
;; column" (i. 186) -- width, and nothing else. A verse line squeezed to fit
;; is quadded out and still a long line, so the quadded flag must not enter
;; into it; testing on it was an error that hid the very cases being counted.
(define (justified? l)
  (and (pair? (set-line-words l))
       (>= (line-set-width l) (- (set-line-measure l) EM-QUAD))))

(define (measure-book b)
  (define tally (make-hash))   ; (family . kind) -> count
  (define (bump! k) (hash-update! tally k add1 0))
  (for* ([p (in-list (book-pages b))]
         [l (in-list (page-all-lines p))]
         [w (in-list (set-line-words l))])
    (define f (family w))
    (when f
      (define copy-long (long-form? (word-copy w)))
      (define out-long (long-form? (word-printed w)))
      (define just? (for/or ([c (in-list (word-causes w))])
                      (string-prefix? c "justification")))
      (bump! (list f (if out-long 'F-long 'F-short)))
      (cond
        [(and out-long (not copy-long)) (bump! (list f 'to-long))
                                        (when just? (bump! (list f 'to-long-just)))]
        [(and (not out-long) copy-long) (bump! (list f 'to-short))
                                        (when just? (bump! (list f 'to-short-just)))
                                        (when (justified? l)
                                          (bump! (list f 'to-short-in-long-line)))]
        [else (bump! (list f 'kept))])))
  tally)

(define (get t f k) (hash-ref t (list f k) 0))

;; ---------------------------------------------------------------------------

(define (run-validation sample-path #:seed [seed 1623] #:repeat [repeat 6])
  ;; Hinman's quire L is six dense folio pages carrying 53 occurrences of the
  ;; test words. A single pass of the sample gives a fifth of that, which is
  ;; too few to say anything, so the copy is repeated for statistical power.
  (define raw (apply string-append
                     (for/list ([i (in-range repeat)]) (file->string sample-path))))

  (printf "~a\n" (make-string 74 #\=))
  (printf "CHECKING THE SIMULATION AGAINST HINMAN'S COUNTS FOR QUIRE L\n")
  (printf "~a\n\n" (make-string 74 #\=))

  ;; --- 1. What Hinman's figures imply -------------------------------------
  (printf "1. WHAT HINMAN'S OWN FIGURES IMPLY\n\n")
  (define-values (p1 q1) (derive-habit-strength (hash-ref hinman-quire-L 'do-go)))
  (define-values (p2 q2) (derive-habit-strength (hash-ref hinman-quire-L 'here)))
  (printf "   do/go family:  copy had ~a% long forms; C imposed his habit ~a% of\n"
          (exact-round (* 100 q1)) (exact-round (* 100 p1)))
  (printf "                  the time he had the opportunity.\n")
  (printf "   here family:   copy had ~a% long forms; C imposed his habit ~a% of\n"
          (exact-round (* 100 q2)) (exact-round (* 100 p2)))
  (printf "                  the time.\n\n")
  (printf "   The built-in habit-strength for Compositor A is ~a, for C ~a.\n"
          (profile-habit-strength (hash-ref PROFILES "A"))
          (profile-habit-strength (hash-ref PROFILES "C")))
  (printf "   FINDING: a single scalar cannot hold both. C imposes doe/goe far\n")
  (printf "   more readily than heere. Habit strength is word-specific.\n\n")

  ;; --- 2. Drive the simulator with Hinman's own numbers -------------------
  (printf "2. THE SIMULATION, DRIVEN BY THOSE FIGURES\n\n")
  (define copy (respell raw #:do-go q1 #:here q2))
  ;; Driven with a habit-strength per word-family, as Hinman's counts require.
  (define prof
    (struct-copy profile (hash-ref PROFILES "C")
                 [habit-strength (hash "do" (exact->inexact p1)
                                       "go" (exact->inexact p1)
                                       "here" (exact->inexact p2)
                                       "" (exact->inexact p1))]))
  (define (run fmt)
    (set-book (make-house #:fmt fmt #:compositors '("C") #:seed seed
                          #:prepare-copy? #f #:profiles (hash "C" prof))
              copy))
  ;; Two measures. The quarto is roomy and shows habit almost undisturbed;
  ;; the octavo is tight and is where the measure starts overriding the man.
  (define b (run QUARTO))
  (define b-tight (run OCTAVO))
  (define t (measure-book b))
  (define t-tight (measure-book b-tight))

  (printf "   ~a\n" (~a "" #:width 16))
  (printf "   ~a ~a ~a ~a\n"
          (~a "family" #:width 10) (~a "F-long" #:width 10)
          (~a "F-short" #:width 10) (~a "changed to long" #:width 18))
  (printf "   ~a\n" (make-string 56 #\-))
  (for ([f (in-list '(do-go here))])
    (define hc (hash-ref hinman-quire-L f))
    (printf "   ~a ~a ~a ~a   (simulated)\n"
            (~a f #:width 10)
            (~a (get t f 'F-long) #:width 10)
            (~a (get t f 'F-short) #:width 10)
            (~a (get t f 'to-long) #:width 18))
    (printf "   ~a ~a ~a ~a   (Hinman)\n\n"
            (~a "" #:width 10)
            (~a (first hc) #:width 10)
            (~a (second hc) #:width 10)
            (~a (third hc) #:width 18)))

  ;; The ratio is the thing, since the sample is not Much Ado and the totals
  ;; cannot match. What must match is the proportion changed.
  (printf "   Proportion of the long forms that are changes from copy:\n")
  (for ([f (in-list '(do-go here))])
    (define hc (hash-ref hinman-quire-L f))
    (define sim (let ([n (get t f 'F-long)])
                  (if (zero? n) 0 (/ (get t f 'to-long) n))))
    (define real (/ (third hc) (first hc)))
    (printf "     ~a  simulated ~a%   Hinman ~a%   difference ~a points\n"
            (~a f #:width 8)
            (~a (exact-round (* 100 sim)) #:width 3)
            (~a (exact-round (* 100 real)) #:width 3)
            (exact-round (abs (- (* 100 sim) (* 100 real))))))
  (newline)

  ;; --- 3. The structural prediction ---------------------------------------
  (printf "3. THE PREDICTION THAT DOES NOT DEPEND ON THE COPY\n\n")
  (printf "   Hinman's sharpest observation is not a count but a pattern: the\n")
  (printf "   changes AGAINST the compositor's habit are the ones forced by the\n")
  (printf "   measure. Of his two such changes in quire L, the doe->do was 'in a\n")
  (printf "   prose passage where the short spelling was evidently required to\n")
  (printf "   justify a line', and the heere->here was 'manifestly in order to\n")
  (printf "   save space'. Both. If the simulation is right about the mechanism,\n")
  (printf "   its against-habit changes must be justification-driven too.\n\n")
  (for ([tt (in-list (list t t-tight))]
        [label (in-list '("quarto, 21 ems (roomy)" "octavo, 16 ems (tight)"))])
    (define against (+ (get tt 'do-go 'to-short) (get tt 'here 'to-short)))
    (define against-just (+ (get tt 'do-go 'to-short-just)
                            (get tt 'here 'to-short-just)))
    (define in-long (+ (get tt 'do-go 'to-short-in-long-line)
                       (get tt 'here 'to-short-in-long-line)))
    (printf "   ~a\n" label)
    (printf "     changes against habit:                    ~a\n" against)
    (printf "     of those, driven by justification:        ~a\n" against-just)
    (printf "     of those, in lines reaching the measure:  ~a\n" in-long)
    (cond
      [(zero? against)
       (printf "     NOT TESTED — no against-habit change occurred.\n\n")]
      [(= against against-just)
       (printf "     PASSES — every one was forced by the measure, as in quire L.\n\n")]
      [else
       (printf "     FAILS — ~a were not justification-driven; Hinman found none.\n\n"
               (- against against-just))]))
  b)

;; Given the copy's mix q and the printed mix f, the strength of the habit
;; that carried one into the other: f = q + (1-q)p  =>  p = (f-q)/(1-q).
(define (implied-strength q f)
  (if (>= q 0.999) 0 (max 0 (/ (- f q) (- 1 q)))))

(define (run-real-validation dir scenes #:seed [seed 1623])
  (printf "~a\n" (make-string 74 #\=))
  (printf "MUCH ADO: THE QUARTO OF 1600 AS COPY, THE FOLIO AS THE ANSWER\n")
  (printf "~a\n\n" (make-string 74 #\=))

  (define copy-text
    (apply string-append
           (for/list ([s (in-list scenes)])
             (file->string (build-path dir (format "q1600-~a.txt" s))))))
  (define folio-text
    (apply string-append
           (for/list ([s (in-list scenes)])
             (file->string (build-path dir (format "f1623-~a.txt" s))))))

  (define qc (count-families copy-text))
  (define fc (count-families folio-text))

  ;; Set the same copy with the simulator, using the habit strengths Hinman's
  ;; quire-L counts imply, and count its output the same way.
  (define-values (p1 _q1) (derive-habit-strength (hash-ref hinman-quire-L 'do-go)))
  (define-values (p2 _q2) (derive-habit-strength (hash-ref hinman-quire-L 'here)))
  (define prof
    (struct-copy profile (hash-ref PROFILES "C")
                 [habit-strength (hash "do" (exact->inexact p1)
                                       "go" (exact->inexact p1)
                                       "here" (exact->inexact p2)
                                       "" (exact->inexact p1))]))
  ;; Much Ado is mostly prose, and the transcription gives one line per line
  ;; of the quarto's type. Left to itself the parser reads every short line as
  ;; verse and preserves the quarto's lineation -- but a compositor setting
  ;; prose from a quarto into a narrower folio column reflows it. Telling it
  ;; the copy is prose is not a fudge; it is the fact about this book.
  (define b (set-book (make-house #:fmt FOLIO-IN-SIXES #:compositors '("C")
                                  #:seed seed #:prepare-copy? #f
                                  #:profiles (hash "C" prof))
                      copy-text 'prose))
  (define sc (count-families
              (string-join (for/list ([p (in-list (book-pages b))])
                             (strip-conventions (page-text p))) "\n")))

  (printf "   Scenes: ~a.  Long forms as a share of each family.\n\n"
          (string-join scenes ", "))
  (printf "   ~a ~a ~a ~a\n"
          (~a "family" #:width 9) (~a "Q1600 copy" #:width 12)
          (~a "F1623 actual" #:width 14) (~a "simulated" #:width 11))
  (printf "   ~a\n" (make-string 50 #\-))
  (for ([f (in-list '(do-go here))])
    (printf "   ~a ~a ~a ~a\n"
            (~a f #:width 9)
            (~a (format "~a%" (exact-round (* 100 (share qc f)))) #:width 12)
            (~a (format "~a%" (exact-round (* 100 (share fc f)))) #:width 14)
            (~a (format "~a%" (exact-round (* 100 (share sc f)))) #:width 11)))
  (newline)

  (printf "   Habit strength implied by the shift from copy to print:\n")
  (for ([f (in-list '(do-go here))])
    (define real (implied-strength (share qc f) (share fc f)))
    (define sim (implied-strength (share qc f) (share sc f)))
    (printf "     ~a  Folio ~a   simulated ~a   (Hinman's quire L: ~a)\n"
            (~a f #:width 8)
            (~a (exact-round (* 100 real)) #:width 4)
            (~a (exact-round (* 100 sim)) #:width 4)
            (exact-round (* 100 (if (eq? f 'do-go) p1 p2)))))
  (newline)
  (printf "   Raw counts — Q1600 / F1623 / simulated:\n")
  (for* ([f (in-list '(do-go here))] [k (in-list '(long short))])
    (printf "     ~a ~a  ~a ~a ~a\n" (~a f #:width 7) (~a k #:width 6)
            (~a (hash-ref qc (cons f k) 0) #:width 6)
            (~a (hash-ref fc (cons f k) 0) #:width 6)
            (~a (hash-ref sc (cons f k) 0) #:width 6)))
  (newline))

(module+ main
  (require racket/runtime-path)
  (define-runtime-path here ".")
  (void (run-validation (build-path here "samples" "hamlet.txt")))
  (run-real-validation (build-path here "samples" "ado")
                       '("2.1" "2.3" "3.1" "4.1" "5.1")))

(module+ test
  (require rackunit)
  ;; The arithmetic that recovers habit-strength from Hinman's counts.
  (define-values (p q) (derive-habit-strength (hash-ref hinman-quire-L 'do-go)))
  (check-true (and (> p 0.75) (< p 0.90))
              "C imposed doe/goe on about four opportunities in five")
  (define-values (p2 q2) (derive-habit-strength (hash-ref hinman-quire-L 'here)))
  (check-true (< p2 p) "and heere markedly less readily than doe/goe")
  ;; Respelling gives the copy the mix asked for.
  (define txt (string-join (for/list ([i 400]) "do go here") " "))
  (define out (respell txt #:do-go 0.5 #:here 0.5))
  (define longs (length (regexp-match* #px"\\b(doe|goe|heere)\\b" out)))
  (check-true (and (> longs 400) (< longs 800)) "roughly half are long forms"))
