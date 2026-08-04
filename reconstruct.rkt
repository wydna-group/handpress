#lang racket/base
;;; Running the press backwards: from the Folio, guess the quarto.
;;;
;;; The forward direction is what a printing house does. This is what an
;;; editor does, and it is the harder half. Everything the compositor did to
;;; his copy either destroyed information or did not; the question is how much
;;; of it can be got back, and the answer is the whole subject.
;;;
;;; The two texts are aligned word for word here rather than compared in the
;;; aggregate. Aligning on the *family* -- treating doe and do as the same
;;; token for the purpose of lining the texts up, then comparing the surface
;;; forms at the positions that match -- gives the actual matrix of what
;;; became what, which is a better measurement than any proportion.

(require racket/list racket/string racket/file racket/format racket/math
         "orthography.rkt")

(provide test-words align confusion reconstruct-report)

;; ---------------------------------------------------------------------------
;; The ordered sequence of test-word occurrences in a text
;; ---------------------------------------------------------------------------

(define (family w)
  (case (string-downcase w)
    [("do" "doe") 'do] [("go" "goe") 'go] [("here" "heere") 'here]
    [else #f]))

(define (long? w) (and (member (string-downcase w) '("doe" "goe" "heere")) #t))

;; (list family surface-form) for every test word, in order
(define (test-words text)
  (for*/list ([w (in-list (regexp-match* #px"[A-Za-z']+" text))]
              [f (in-value (family w))]
              #:when f)
    (list f (string-downcase w))))

;; ---------------------------------------------------------------------------
;; Alignment
;; ---------------------------------------------------------------------------
;; A longest-common-subsequence alignment on the family tags. The two texts
;; are a reprint and its copy, so they agree almost everywhere; the few places
;; they do not are dropped rather than guessed at.

(define (align xs ys)
  (define n (length xs))
  (define m (length ys))
  (define vx (list->vector xs))
  (define vy (list->vector ys))
  (define tbl (make-vector (* (add1 n) (add1 m)) 0))
  (define (idx i j) (+ (* i (add1 m)) j))
  (for* ([i (in-range (sub1 n) -1 -1)] [j (in-range (sub1 m) -1 -1)])
    (vector-set!
     tbl (idx i j)
     (if (eq? (first (vector-ref vx i)) (first (vector-ref vy j)))
         (add1 (vector-ref tbl (idx (add1 i) (add1 j))))
         (max (vector-ref tbl (idx (add1 i) j))
              (vector-ref tbl (idx i (add1 j)))))))
  (let loop ([i 0] [j 0] [acc '()])
    (cond
      [(or (= i n) (= j m)) (reverse acc)]
      [(eq? (first (vector-ref vx i)) (first (vector-ref vy j)))
       (loop (add1 i) (add1 j) (cons (cons (vector-ref vx i) (vector-ref vy j)) acc))]
      [(>= (vector-ref tbl (idx (add1 i) j)) (vector-ref tbl (idx i (add1 j))))
       (loop (add1 i) j acc)]
      [else (loop i (add1 j) acc)])))

;; ---------------------------------------------------------------------------
;; What became what
;; ---------------------------------------------------------------------------

;; family -> hash of (copy-long? . print-long?) -> count
(define (confusion pairs)
  (define h (make-hash))
  (for ([p (in-list pairs)])
    (define f (first (car p)))
    (define c (long? (second (car p))))
    (define pr (long? (second (cdr p))))
    (hash-update! h (list f c pr) add1 0))
  h)

(define (g h f c p) (hash-ref h (list f c p) 0))

;; ---------------------------------------------------------------------------

(define (reconstruct-report dir scenes)
  (define copy-text
    (apply string-append
           (for/list ([s scenes])
             (file->string (build-path dir (format "q1600-~a.txt" s))))))
  (define folio-text
    (apply string-append
           (for/list ([s scenes])
             (file->string (build-path dir (format "f1623-~a.txt" s))))))

  (define pairs (align (test-words copy-text) (test-words folio-text)))
  (define h (confusion pairs))

  (printf "~a\n" (make-string 74 #\=))
  (printf "RUNNING IT BACKWARDS: THE FOLIO AS EVIDENCE FOR THE QUARTO\n")
  (printf "~a\n\n" (make-string 74 #\=))
  (printf "   ~a test-word occurrences aligned between the two texts.\n\n"
          (length pairs))

  (printf "1. WHAT THE COMPOSITORS ACTUALLY DID\n\n")
  (printf "   ~a ~a ~a ~a ~a\n"
          (~a "family" #:width 8) (~a "kept short" #:width 12)
          (~a "short->long" #:width 13) (~a "kept long" #:width 11)
          (~a "long->short" #:width 12))
  (printf "   ~a\n" (make-string 60 #\-))
  (for ([f '(do go here)])
    (printf "   ~a ~a ~a ~a ~a\n"
            (~a f #:width 8)
            (~a (g h f #f #f) #:width 12) (~a (g h f #f #t) #:width 13)
            (~a (g h f #t #t) #:width 11) (~a (g h f #t #f) #:width 12)))
  (newline)

  ;; The measurement that matters: of the chances the compositors had to
  ;; impose the long form, how often did they take it?
  (printf "   Habit strength, measured word by word rather than in the mass:\n")
  (for ([f '(do go here)])
    (define opportunities (+ (g h f #f #f) (g h f #f #t)))
    (define taken (g h f #f #t))
    (printf "     ~a  ~a of ~a opportunities  = ~a%\n"
            (~a f #:width 6) (~a taken #:width 4) (~a opportunities #:width 4)
            (if (zero? opportunities) "--"
                (exact-round (* 100 (/ taken opportunities))))))
  (newline)

  ;; --- 2. The reconstruction ---------------------------------------------
  (printf "2. THE RECONSTRUCTION, AND WHY IT CANNOT DO BETTER\n\n")
  (for ([f '(do go here)])
    (define n (+ (g h f #f #f) (g h f #f #t) (g h f #t #t) (g h f #t #f)))
    (when (> n 0)
      ;; Baseline: assume the copy read what the Folio prints.
      (define baseline (+ (g h f #f #f) (g h f #t #t)))
      ;; Blanket reversion: assume every long form in the Folio was imposed.
      (define revert (+ (g h f #f #f) (g h f #f #t)))
      ;; Blanket lengthening: assume every short form was in the copy long.
      (define lengthen (+ (g h f #t #t) (g h f #t #f)))
      (define best (max baseline revert lengthen))
      (printf "   ~a  (~a occurrences)\n" (~a f #:width 6) n)
      ;; The three rules are exhaustive: follow the page, or guess one form
      ;; everywhere. "Revert the long forms" and "guess short throughout" are
      ;; the same prediction, since a printed short form is already short.
      (printf "     follow the Folio:                ~a correct  (~a%)\n"
              (~a baseline #:width 4) (exact-round (* 100 (/ baseline n))))
      (printf "     guess the short form throughout: ~a correct  (~a%)\n"
              (~a revert #:width 4) (exact-round (* 100 (/ revert n))))
      (printf "     guess the long form throughout:  ~a correct  (~a%)\n"
              (~a lengthen #:width 4) (exact-round (* 100 (/ lengthen n))))
      (printf "     best available rule:             ~a%  (~a points over following the page)\n"
              (exact-round (* 100 (/ best n)))
              (exact-round (* 100 (/ (- best baseline) n))))
      (newline)))

  (printf "   There is no third option. Nothing on the printed page\n")
  (printf "   distinguishes a `doe' the compositor found in his copy from a\n")
  (printf "   `doe' he made, so every reading of a given surface form must be\n")
  (printf "   treated alike, and the best any rule can do is the commoner case.\n")
  (printf "   An editor restoring accidentals is choosing between blanket\n")
  (printf "   rules, not recovering readings. This is Greg's distinction\n")
  (printf "   between substantives and accidentals, arrived at by counting.\n\n")

  ;; --- 3. What is recoverable --------------------------------------------
  (printf "3. WHAT IS RECOVERABLE\n\n")
  (define tot-short-long (for/sum ([f '(do go here)]) (g h f #f #t)))
  (define tot-long-short (for/sum ([f '(do go here)]) (g h f #t #f)))
  (define tot (length pairs))
  (define unchanged (for/sum ([f '(do go here)])
                      (+ (g h f #f #f) (g h f #t #t))))
  (printf "     unchanged from copy:        ~a of ~a  (~a%)\n"
          (~a unchanged #:width 4) tot (exact-round (* 100 (/ unchanged tot))))
  (printf "     lengthened by the workman:  ~a\n" tot-short-long)
  (printf "     shortened by the workman:   ~a\n" tot-long-short)
  (newline)
  (printf "   The distribution of the copy IS recoverable, and well: given the\n")
  (printf "   printed proportion f and the habit strength p, the copy's\n")
  (printf "   proportion is (f - p) / (1 - p). What is not recoverable is which\n")
  (printf "   particular words those were. The aggregate survives the press;\n")
  (printf "   the individual reading does not.\n\n")
  h)

(module+ main
  (require racket/runtime-path)
  (define-runtime-path here ".")
  (void (reconstruct-report (build-path here "samples" "ado")
                            '("2.1" "2.3" "3.1" "4.1" "5.1"))))

(module+ test
  (require rackunit)
  ;; Alignment holds when one stream has an extra occurrence.
  (define a '((do "do") (here "here") (go "goe")))
  (define b '((do "doe") (here "heere") (here "here") (go "go")))
  (define al (align a b))
  (check-equal? (length al) 3)
  (check-equal? (second (car (first al))) "do")
  (check-equal? (second (cdr (first al))) "doe")
  ;; Families never mismatch in an alignment.
  (for ([p (in-list al)])
    (check-equal? (first (car p)) (first (cdr p)))))
