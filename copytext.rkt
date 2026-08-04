#lang racket/base
;;; The copy: what lies on the compositor's visorium, and how he misreads it.
;;;
;;; The copy-text is the thing the New Bibliography exists to reconstruct and
;;; can never see. Here we have the luxury of possessing it, which is the
;;; whole point of the exercise: everything the press does to it is recorded,
;;; so that the reconstruction can afterwards be scored against the truth.
;;;
;;; The misreadings modelled here are those the New Bibliographers assembled
;;; into a standing repertory of scribal and compositorial error: the minim
;;; confusions of the secretary hand, in which m, n, u, i and w are all built
;;; from the same downstrokes; the confusion of e with o and c with t;
;;; eyeskip over a repeated word; the substitution of a commoner phrase for a
;;; rarer one under the pressure of memory; and simple transposition.

(require racket/string racket/list racket/match racket/set "rng.rkt")

(provide (struct-out copy-unit) (struct-out misreading)
         parse-copy misread
         MINIM-CONFUSIONS HAND-CONFUSIONS MEMORIAL)

;; kind is one of 'verse 'prose 'prefix 'stage 'heading 'blank
(struct copy-unit (kind text index speaker) #:transparent)

(struct misreading (original reading kind note) #:transparent)

(define stage-rx
  #px"^(?:\\[|(?i:enter|exit|exeunt|manet|alarum|flourish|sennet|dies|aside|within)\\b)")

(define prefix-rx
  #px"^([A-Z][A-Za-z'’]{1,14}(?:\\s+[A-Z][a-z]{1,12})?)\\.\\s+(.*)$")

(define prefix-only-rx #px"^([A-Z][A-Z '’]{1,20})[.:]?\\s*$")

(define (stage-direction? line) (regexp-match? stage-rx line))

(define (looks-like-verse? line) (< (string-length line) 78))

;; Who actually speaks in this copy.
;;
;; A verse line may perfectly well read "Affront Ophelia. Her father and
;; myself," and look exactly like a speech prefix. What distinguishes a real
;; speaker is that he comes back: prefixes recur, and they recur in the stage
;; directions that bring the speaker on. One pass over the copy to collect
;; them, and the ambiguity disappears.
(define (find-speakers lines)
  (define counts (make-hash))
  (define named (make-hash))
  (for ([raw (in-list lines)])
    (define line (string-trim raw))
    (cond
      [(string=? line "") (void)]
      [(stage-direction? line)
       (for ([w (in-list (regexp-match* #px"[A-Z][a-z]{2,}" line))])
         (hash-set! named w #t))]
      [else
       (define m (regexp-match prefix-rx line))
       (when m (hash-update! counts (cadr m) add1 0))]))
  (for/set ([(name n) (in-hash counts)]
            #:when (or (>= n 2)
                       (hash-ref named (car (string-split name)) #f)))
    name))

(define (split-speech-prefix line [speakers #f])
  (define m1 (regexp-match prefix-only-rx line))
  (cond
    [(and m1 (string=? line (string-upcase line)))
     (values (string-titlecase (string-trim (cadr m1))) "")]
    [else
     (define m (regexp-match prefix-rx line))
     (cond
       [(not m) (values #f line)]
       [else
        (define name (cadr m))
        (define rest (caddr m))
        (cond
          [(and speakers (not (set-member? speakers name))) (values #f line)]
          [(and (<= (length (string-split name)) 2)
                (> (string-length rest) 0)
                (char-upper-case? (string-ref rest 0)))
           (values name rest)]
          [else (values #f line)])])]))

(define (sniff lines)
  (define body
    (filter (lambda (l) (and (not (string=? l ""))
                             (not (string-prefix? l "#"))))
            (map string-trim lines)))
  (cond
    [(null? body) 'prose]
    [else
     (define n (length body))
     (define prefixed
       (for/sum ([l (in-list body)])
         (define-values (p _r) (split-speech-prefix l))
         (if p 1 0)))
     (define shortish (for/sum ([l (in-list body)])
                        (if (< (string-length l) 62) 1 0)))
     (define capitalled (for/sum ([l (in-list body)])
                          (if (char-upper-case? (string-ref l 0)) 1 0)))
     (cond
       [(> prefixed (* n 0.12)) 'drama]
       [(and (> shortish (* n 0.8)) (> capitalled (* n 0.6))) 'verse]
       [else 'prose])]))

;; Break a plain text into the units a compositor would recognise.
(define (parse-copy text [kind 'auto])
  (define lines
    (string-split (string-replace (string-replace text "\r\n" "\n") "\r" "\n")
                  "\n" #:trim? #f))
  (define k (if (eq? kind 'auto) (sniff lines) kind))
  (define speakers (find-speakers lines))

  (define units '())       ; reversed
  (define para '())        ; reversed

  (define (emit! kind text [speaker #f])
    (set! units (cons (copy-unit kind text (length units) speaker) units)))

  (define (flush!)
    (unless (null? para)
      (emit! 'prose (string-trim (string-join (reverse para) " ")))
      (set! para '())))

  (for ([raw (in-list lines)])
    (define line (string-trim raw #:left? #f))
    (define stripped (string-trim line))
    (cond
      [(string=? stripped "")
       (flush!)
       (when (and (pair? units) (not (eq? (copy-unit-kind (car units)) 'blank)))
         (emit! 'blank ""))]

      [(string-prefix? stripped "#")
       (flush!)
       (emit! 'heading (string-trim (string-trim stripped "#" #:right? #f)))]

      [(stage-direction? stripped)
       (flush!)
       (emit! 'stage (string-trim (string-trim stripped "[") "]"))]

      [else
       (define-values (prefix rest) (split-speech-prefix stripped speakers))
       (cond
         [prefix
          (flush!)
          (emit! 'prefix prefix #f)
          (unless (string=? rest "")
            ;; A speech is not verse merely because it is a speech. Hamlet
            ;; abuses Ophelia in prose, and the compositor can see that as
            ;; well as we can: the line runs past where a verse line stops.
            (define verse? (and (memq k '(verse drama)) (looks-like-verse? rest)))
            (emit! (if verse? 'verse 'prose) rest prefix))]
         [(and (memq k '(verse drama)) (looks-like-verse? stripped))
          (flush!)
          (emit! 'verse stripped)]
         [else (set! para (cons stripped para))])]))

  (flush!)
  (reverse units))

;; ---------------------------------------------------------------------------
;; Misreading the copy
;; ---------------------------------------------------------------------------
;; In the secretary hand the minims -- the plain downstrokes that make up m,
;; n, u, i, v and w -- are undifferentiated, so that a word may be counted
;; wrong without being read wrong at all. This is the single most productive
;; source of error in the transmission of English printed drama, and the
;; standing justification for a great deal of emendation.

(define MINIM-CONFUSIONS
  '(("m" "in") ("in" "m") ("m" "ni") ("nn" "un") ("un" "nn")
    ("u" "n") ("n" "u") ("ui" "in") ("im" "un") ("w" "vv")
    ("m" "nn") ("nu" "un")))

;; Letters the secretary hand does not keep decently apart.
(define HAND-CONFUSIONS
  '(("e" "o") ("o" "e") ("c" "t") ("t" "c") ("c" "e") ("e" "c")
    ("f" "ſ") ("l" "b") ("h" "b") ("a" "o") ("y" "g") ("r" "s")))

;; Commonplaces that swim up under the pressure of memory and displace the
;; rarer reading actually in the copy.
(define MEMORIAL
  (hash "sad" "poor" "poor" "sad" "great" "good" "good" "great"
        "thy" "the" "the" "thy" "a" "the" "this" "the" "these" "those"
        "shall" "will" "will" "shall" "doth" "does" "hath" "has"
        "mine" "my" "my" "mine" "and" "but" "but" "and"
        "life" "love" "love" "life" "heart" "head" "sword" "word"))

(define (apply-pair word pairs g)
  (define low (string-downcase word))
  (define candidates (filter (lambda (p) (string-contains? low (car p))) pairs))
  (cond
    [(null? candidates) #f]
    [else
     (define p (rnd-choice g candidates))
     (define idx (let loop ([i 0])
                   (cond [(> (+ i (string-length (car p))) (string-length low)) #f]
                         [(string=? (substring low i (+ i (string-length (car p))))
                                    (car p)) i]
                         [else (loop (add1 i))])))
     (and idx
          (string-append (substring word 0 idx)
                         (cadr p)
                         (substring word (+ idx (string-length (car p))))))]))

(define (transpose word g)
  (define n (string-length word))
  (and (>= n 4)
       (let ([i (+ 1 (rnd-int g (- n 3)))])
         (string-append (substring word 0 i)
                        (string (string-ref word (add1 i))
                                (string-ref word i))
                        (substring word (+ i 2))))))

;; Pass a line of copy through a fallible eye and a fallible memory.
;;
;; Returns (values pairs errors) where each pair is (cons copy-form read-form).
;; Keeping both is the whole point: the copy reading is what an editor is
;; trying to recover, and it is the one thing the printed page does not
;; contain.
(define (misread words g rate memorial-rate)
  (define errors '())
  (define (note! e) (set! errors (cons e errors)))

  (define pairs
    (for/list ([wd (in-list words)])
      (define cur wd)
      (cond
        [(< (string-length cur) 3) (cons wd cur)]
        [else
         (define slip
           (and (< (rnd g) rate)
                (let ([roll (rnd g)])
                  (cond
                    [(< roll 0.45)
                     (let ([n (apply-pair cur MINIM-CONFUSIONS g)])
                       (and n (list n 'minim "minims miscounted in the copy")))]
                    [(< roll 0.85)
                     (let ([n (apply-pair cur HAND-CONFUSIONS g)])
                       (and n (list n 'misreading
                                    "letters confused in the secretary hand")))]
                    [else
                     (let ([n (transpose cur g)])
                       (and n (list n 'transposition
                                    "letters transposed in the stick")))]))))
         (cond
           [(and slip (not (string=? (car slip) cur)))
            (note! (misreading wd (car slip) (cadr slip) (caddr slip)))
            (cons wd (car slip))]
           [else
            (define low (string-trim cur ".,;:!?" #:repeat? #t))
            (define lowd (string-downcase low))
            (cond
              [(and (hash-has-key? MEMORIAL lowd) (< (rnd g) memorial-rate))
               (define sub (hash-ref MEMORIAL lowd))
               (define new (if (string-contains? cur lowd)
                               (string-replace cur lowd sub)
                               sub))
               (note! (misreading wd new 'memorial
                                  "commoner word substituted from memory"))
               (cons wd new)]
              [else (cons wd cur)])])])))

  ;; eyeskip: the eye returns to the second of two like words near by, and
  ;; everything between them is lost without trace
  (define final
    (cond
      [(and (> (length pairs) 6) (< (rnd g) (* rate 0.6)))
       (define v (list->vector pairs))
       (define seen (make-hash))
       (let loop ([i 0])
         (cond
           [(>= i (vector-length v)) pairs]
           [else
            (define cur (string-downcase (cdr (vector-ref v i))))
            (define j (hash-ref seen cur #f))
            (cond
              [(and j (> (- i j) 1) (<= (- i j) 4) (> (string-length cur) 2))
               (define dropped
                 (string-join (for/list ([k (in-range (add1 j) (add1 i))])
                                (car (vector-ref v k))) " "))
               (note! (misreading dropped "" 'eyeskip
                                  (format "eye returned to the second ~s"
                                          (cdr (vector-ref v i)))))
               (append (for/list ([k (in-range 0 (add1 j))]) (vector-ref v k))
                       (for/list ([k (in-range (add1 i) (vector-length v))])
                         (vector-ref v k)))]
              [else (hash-set! seen cur i) (loop (add1 i))])]))]
      [else pairs]))

  (values final (reverse errors)))

(module+ test
  (require rackunit)

  (define drama "Enter King and Queen.\n\nKing. And can you by no drift\nGet from him why he puts on this confusion?\n\nQueen. Did he receive you well?\n\nKing. Affront Ophelia. Her father and myself,\nLawful espials, will bestow ourselves\n")
  (define us (parse-copy drama))
  (define kinds (map copy-unit-kind us))
  (check-not-false (memq 'stage kinds))
  (check-not-false (memq 'prefix kinds))
  (check-not-false (memq 'verse kinds))

  ;; "Affront Ophelia." looks exactly like a speech prefix but occurs once,
  ;; so it must not be taken for one.
  (check-false
   (for/or ([u (in-list us)])
     (and (eq? (copy-unit-kind u) 'prefix)
          (string-prefix? (copy-unit-text u) "Affront"))))
  ;; King and Queen recur or are named in the direction, so they are speakers.
  (define prefixes
    (for/list ([u (in-list us)] #:when (eq? (copy-unit-kind u) 'prefix))
      (copy-unit-text u)))
  (check-not-false (member "King" prefixes))
  (check-not-false (member "Queen" prefixes))

  ;; Misreading preserves the copy reading alongside what he took it for,
  ;; and never invents or loses a word except by recorded eyeskip.
  (define g (make-rng 7))
  (define words (string-split "the quick brown foxes leap over lazy hounds today"))
  (define-values (pairs errs) (misread words g 0.9 0.2))
  (define skipped
    (for/sum ([e (in-list errs)] #:when (eq? (misreading-kind e) 'eyeskip))
      (length (string-split (misreading-original e)))))
  (check-equal? (+ (length pairs) skipped) (length words))
  (check-equal? (map car pairs)
                (for/list ([wd (in-list words)]
                           #:when (member wd (map car pairs)))
                  wd)))
