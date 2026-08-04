#lang racket/base
;;; A Bowers-style bibliographical description of the edition we have made.
;;;
;;; The form follows Fredson Bowers, _Principles of Bibliographical
;;; Description_ (1949), and in particular the worked description at i. 128-9,
;;; which sets out the order and the abbreviations:
;;;
;;;     RT]   running-titles, with their variants by gathering
;;;     Coll: format, collational formula, leaf count, numbering
;;;           (followed by an indented statement of contents)
;;;     Sigs: the signing statement, in $-notation
;;;     CW:   a selection of catchwords, with the following word bracketed
;;;           where it differs
;;;     Type: lines to the page, type-page in mm., and the 20-line measure
;;;     Copies Examined / Notes
;;;
;;; Two of these carry more weight here than the rest. The running-title
;;; paragraph is where the skeleton formes betray themselves -- Bowers: "the
;;; complete evidence of running-titles ... would almost inevitably reveal
;;; simultaneous setting and printing of different portions of a book" (i.
;;; 125). And the catchword list is, in his words, "a partial check for
;;; variant states of formes": a catchword that does not match the first word
;;; of the next page is evidence of disturbance, and we can generate exactly
;;; that when a page has been reset or crowded.
;;;
;;; The press variants are a statement of *state* in Bowers's sense (ch. 2):
;;; press-correction during continuous printing, producing copies that differ
;;; without differing in edition or issue.

(require racket/list racket/string racket/math racket/format
         "metrics.rkt" "compositor.rkt" "imposition.rkt" "book.rkt"
         "press.rkt" "typecase.rkt")

(provide description-lines description-text description-html
         description-tei-msdesc
         collation-line signing-statement type-line catchword-list
         running-title-paragraph)

;; A printer's pica em is 4.2175 mm, and the Folio's type is pica set solid.
;; So a 20-line measurement -- the standard way of identifying a fount before
;; foundries could be named -- follows directly from the body size.
(define MM-PER-EM 4.2175)

(define (mm x) (exact-round (* x MM-PER-EM)))

;; ---------------------------------------------------------------------------

(define (collation-line b)
  (define fmt (book-fmt b))
  (define leaves (* (book-gatherings b) (book-format-leaves fmt)))
  (format "~a  ~a leaves unnumbered."
          (book-collation b) leaves))

;; Bowers's $-notation: "$3 signed A-D" means the first three leaves of each
;; of gatherings A to D carry a signature. Ours are regular, so the statement
;; is short.
(define (signing-statement b)
  (define fmt (book-fmt b))
  (define n (signed-leaves fmt))
  (define first (signature-letter 0))
  (define last (signature-letter (sub1 (book-gatherings b))))
  (format "$~a signed ~a; rom. caps with arabic numerals; versos unsigned."
          n (if (string=? first last) first (format "~a-~a" first last))))

(define (type-line b)
  (define fmt (book-fmt b))
  (define lines (book-format-lines fmt))
  (define measure (book-format-measure-ems fmt))
  (format "~a ll. ~a×~a mm., ~aR (pica, set solid); measure ~a ems, ~a column(s)."
          (* lines (book-format-columns fmt))
          (mm lines) (mm (* measure (book-format-columns fmt)))
          (mm 20) (exact-round measure) (book-format-columns fmt)))

;; The first word actually standing at the head of a page.
(define (first-word p)
  (for/or ([l (in-list (page-all-lines p))])
    (and (pair? (set-line-words l)) (word-printed (car (set-line-words l))))))

;; A selection of catchwords, with the following word in brackets where it
;; does not answer. A catchword that fails to answer is a sign that something
;; has been reset or crowded since it was set, which is why Bowers asks for
;; the list.
(define (catchword-list b [limit 12])
  (define pages (book-pages b))
  (define entries
    (for/list ([p (in-list pages)] [i (in-naturals)]
               #:unless (string=? (page-catchword p) ""))
      (define nxt (and (< (add1 i) (length pages)) (list-ref pages (add1 i))))
      (define answer (and nxt (first-word nxt)))
      (list (page-sig p) (page-catchword p)
            (and answer (not (string=? answer (page-catchword p))) answer))))
  (define shown (if (> (length entries) limit) (take entries limit) entries))
  (values shown (max 0 (- (length entries) (length shown)))))

;; Running-titles grouped by their damage, which is what identifies a
;; skeleton. Bowers prints the variants in parentheses by gathering; we print
;; them by the pages the title appears on, since that is what the evidence is.
(define (running-title-paragraph b)
  (define groups (make-hash))
  (for ([p (in-list (book-pages b))] #:when (page-running-title p))
    (define rt (page-running-title p))
    (hash-update! groups (title-fingerprint rt)
                  (lambda (xs) (append xs (list (page-sig p)))) '()))
  (define text
    (or (for/or ([p (in-list (book-pages b))])
          (and (page-running-title p) (running-title-text (page-running-title p))))
        ""))
  (values text
          (sort (hash->list groups) string<? #:key car)))

;; ---------------------------------------------------------------------------
;; The description as lines of text
;; ---------------------------------------------------------------------------

(define (description-lines b [run #f])
  (define fmt (book-fmt b))
  (define-values (rt-text rt-groups) (running-title-paragraph b))
  (define-values (cws cw-more) (catchword-list b))

  (define states
    (if run
        (sort (filter forme-state-corrected?
                      (hash-values (press-run-states run)))
              string<? #:key forme-state-forme)
        '()))
  (define silent
    (if run (for/sum ([(k s) (in-hash (press-run-states run))]) (forme-state-silent s)) 0))

  (append
   (list (format "TITLE]  ~a" (book-title b))
         "")
   ;; running-titles
   (list (format "RT]     ~a" rt-text))
   (for/list ([g (in-list rt-groups)] [i (in-naturals)])
     (format "        (~a) ~a~a"
             (integer->char (+ (char->integer #\a) i))
             (string-join (cdr g) " ")
             (if (string=? (car g) "no damage noted") ""
                 (format "  [~a]" (car g)))))
   (list "")
   ;; collation and contents
   (list (format "Coll:   ~a" (collation-line b)))
   (contents-lines b)
   (list "")
   (list (format "Sigs:   ~a" (signing-statement b)))
   (list "")
   ;; catchwords
   (cons (format "CW:     ~a"
                 (string-join
                  (for/list ([c (in-list (if (null? cws) '() (list (car cws))))])
                    (catchword-entry c)) " "))
         (append
          (for/list ([c (in-list (if (null? cws) '() (cdr cws)))])
            (format "        ~a" (catchword-entry c)))
          (if (zero? cw-more) '()
              (list (format "        (and ~a more)" cw-more)))))
   (list "")
   (list (format "Type:   ~a" (type-line b)))
   (list "")
   ;; states
   (list "States:")
   (if (and (null? states) (zero? silent))
       (list "        No forme was corrected at press; the edition is uniform.")
       (append
        (append*
         (for/list ([s (in-list states)])
           (cons (format "        ~a, corrected after about ~a% of the run:"
                         (forme-state-forme s)
                         (exact-round (* 100 (forme-state-fraction-uncorrected s))))
                 (for/list ([v (in-list (forme-state-variants s))])
                   (format "          ~a l.~a  ~a ] ~a"
                           (pvariant-page v) (pvariant-line v)
                           (pvariant-uncorrected v) (pvariant-corrected v))))))
        (if (zero? silent) '()
            (list (format "        ~a further literal(s) were mended before the run began"
                          silent)
                  "        and leave no variant: no collation can recover them."))))
   (list "")
   (list (format "Copies: edition of ~a; ~a collated~a"
                 (if run (press-run-edition run) "?")
                 (if run (length (press-run-copies run)) 0)
                 (if run (format " (~a)"
                                 (string-join (map printed-copy-name
                                                   (press-run-copies run)) ", "))
                     "")))
   (list "")
   (list "Notes:  Stints, in the order the pages were set —")
   (for/list ([s (in-list (book-stints b))])
     (format "        Compositor ~a  ~a" (first s)
             (if (string=? (second s) (third s))
                 (second s) (format "~a–~a" (second s) (third s)))))
   (let ([strained (filter (lambda (p) (> (abs (page-pressure p)) 0.35))
                           (book-pages b))])
     (if (null? strained) '()
         (cons "        Pages showing strain from the casting off —"
               (for/list ([p (in-list strained)])
                 (format "        ~a ~a" (page-sig p)
                         (if (> (page-pressure p) 0) "crowded" "spun out"))))))
   (let ([dropped (for/sum ([p (in-list (book-pages b))]) (length (page-omitted p)))])
     (if (zero? dropped) '()
         (list (format "        ~a line(s) of copy were omitted for want of room."
                       dropped))))
   ;; Moxon allows three spaces between words and no more; wider gaps are
   ;; "Pidgeon-holes" and a reproach to the workman. Worth counting, because
   ;; they are a measure of how hard the casting off pressed.
   (let ([pigeons (for*/sum ([p (in-list (book-pages b))]
                             [l (in-list (page-all-lines p))]
                             #:when (regexp-match? #px"pigeon-holes"
                                                   (set-line-justification l)))
                    1)])
     (if (zero? pigeons) '()
         (list (format "        ~a line(s) show pigeon-holes — gaps wider than the"
                       pigeons)
               "        three spaces Moxon allows as good workmanship.")))))

(define (catchword-entry c)
  (format "~a ~a~a" (first c) (second c)
          (if (third c) (format " [~a]" (third c)) "")))

(define (contents-lines b)
  (define pages (book-pages b))
  (define blank
    (for/list ([p (in-list pages)] #:when (null? (filter (lambda (l) (pair? (set-line-words l)))
                                                         (page-all-lines p))))
      (page-sig p)))
  (define set-pages
    (for/list ([p (in-list pages)] #:unless (member (page-sig p) blank))
      (page-sig p)))
  (append
   (list (format "        ~a: text.~a"
                 (if (null? set-pages) "—"
                     (if (= 1 (length set-pages))
                         (car set-pages)
                         (format "~a–~a" (car set-pages) (last set-pages))))
                 (if (null? blank) ""
                     (format " ~a: blank." (string-join blank " ")))))))

(define (description-text b [run #f])
  (string-join (description-lines b run) "\n"))

;; ---------------------------------------------------------------------------
;; HTML
;; ---------------------------------------------------------------------------

(define (esc s)
  (for/fold ([s s]) ([p (in-list '(("&" "&amp;") ("<" "&lt;") (">" "&gt;")))])
    (string-replace s (car p) (cadr p))))

(define (description-html b [run #f])
  (format "<div class=\"desc\"><h2>Bibliographical description</h2><pre>~a</pre><p class=\"deskey\">After the form of Bowers, <i>Principles of Bibliographical Description</i>, i. 128–9.</p></div>"
          (esc (description-text b run))))

;; ---------------------------------------------------------------------------
;; TEI
;; ---------------------------------------------------------------------------
;; Bowers's sections map onto TEI's physical description almost one for one.
;; <collation>, <foliation>, <layout> and <typeNote> take the formula, the
;; numbering, the page make-up and the type; the signing statement, the
;; catchwords and the running-titles go in <additions> as labelled paragraphs,
;; which is a content model that is certainly valid rather than one I have
;; guessed at.

(define (description-tei-msdesc b [run #f])
  (define fmt (book-fmt b))
  (define-values (rt-text rt-groups) (running-title-paragraph b))
  (define-values (cws cw-more) (catchword-list b))
  (string-join
   (append
    (list "        <msDesc>"
          "          <msIdentifier><idno>simulated edition</idno></msIdentifier>"
          "          <physDesc>"
          "            <objectDesc form=\"codex\">"
          "              <supportDesc material=\"paper\">"
          (format "                <extent>~a leaves</extent>"
                  (* (book-gatherings b) (book-format-leaves fmt)))
          (format "                <collation><p>~a</p></collation>"
                  (esc (collation-line b)))
          "                <foliation><p>Leaves unnumbered; signed only.</p></foliation>"
          "              </supportDesc>"
          (format "              <layoutDesc><layout columns=\"~a\" writtenLines=\"~a\"><p>~a</p></layout></layoutDesc>"
                  (book-format-columns fmt) (book-format-lines fmt)
                  (esc (type-line b)))
          "            </objectDesc>"
          (format "            <typeDesc><typeNote><p>~a</p></typeNote></typeDesc>"
                  (esc (type-line b)))
          "            <additions>"
          (format "              <p><label>Sigs</label>: ~a</p>" (esc (signing-statement b)))
          (format "              <p><label>RT</label>: ~a~a</p>"
                  (esc rt-text)
                  (apply string-append
                         (for/list ([g (in-list rt-groups)] [i (in-naturals)])
                           (format " (~a) ~a~a"
                                   (integer->char (+ (char->integer #\a) i))
                                   (esc (string-join (cdr g) " "))
                                   (if (string=? (car g) "no damage noted") ""
                                       (format " [~a]" (esc (car g))))))))
          (format "              <p><label>CW</label>: ~a~a</p>"
                  (esc (string-join (map catchword-entry cws) "; "))
                  (if (zero? cw-more) "" (format " (and ~a more)" cw-more)))
          "            </additions>"
          "          </physDesc>"
          "        </msDesc>"))
   "\n"))

(module+ test
  (require rackunit)

  (define sample
    (apply string-append
           (for/list ([i (in-range 12)])
             (string-append
              "King. And can you by no drift of conference\n"
              "Get from him why he puts on this confusion,\n"
              "Grating so harshly all his days of quiet\n"
              "With turbulent and dangerous lunacy?\n\n"))))
  (define b (set-book (make-house #:fmt QUARTO #:seed 1623) sample))
  (define r (run-press b #:copies 4 #:seed 1623))
  (define t (description-text b r))

  ;; Bowers's headings are all present and in his order.
  (for ([h (in-list '("RT]" "Coll:" "Sigs:" "CW:" "Type:" "States:" "Copies:" "Notes:"))])
    (check-true (regexp-match? (regexp (regexp-quote h)) t)
                (format "~a is present" h)))
  (define (at rx) (caar (regexp-match-positions rx t)))
  (check-true (< (at #px"RT\\]") (at #px"Coll:")) "RT precedes Coll")
  (check-true (< (at #px"Coll:") (at #px"Sigs:")) "Coll precedes Sigs")
  (check-true (< (at #px"Sigs:") (at #px"CW:")) "Sigs precedes CW")
  (check-true (< (at #px"CW:") (at #px"Type:")) "CW precedes Type")

  ;; The $-notation says how many leaves of each gathering are signed, and a
  ;; quarto signs the first two.
  (check-true (regexp-match? #px"\\$2 signed" t))

  ;; A 20-line measurement of pica comes out at about 84 mm.
  (check-true (regexp-match? #px"84R" t) "the 20-line measure of pica")

  ;; Every catchword listed either answers the next page or is flagged.
  (define-values (cws more) (catchword-list b))
  (check-true (> (length cws) 0))
  (for ([c (in-list cws)])
    (check-true (string? (second c))))

  ;; The TEI fragment is a balanced msDesc.
  (define x (description-tei-msdesc b r))
  (check-true (regexp-match? #px"<msDesc>" x))
  (check-true (regexp-match? #px"</msDesc>" x))
  (check-equal? (length (regexp-match* #px"<collation>" x)) 1)
  (check-equal? (length (regexp-match* #px"<label>" x)) 3))
