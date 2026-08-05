#lang racket/base
;;; The preliminaries: what goes in front, and how a program can tell.
;;;
;;; The preliminaries are the matter printed before the text -- title-page,
;;; dedication, preface, sometimes a table -- and they are printed last. That
;;; is the whole of the reason they have a signature series of their own:
;;;
;;;   "The preliminaries were not included in the main signature series of new
;;;   books because it was usual to print them last; reprints, however,
;;;   sometimes began the main signature series at the beginning of the
;;;   preliminaries." (Gaskell, p. 8)
;;;
;;;   "In composing a new book from MS the normal course was to begin at the
;;;   beginning of the text and proceed straight on to the end, setting up the
;;;   title-page and preliminaries last." (McKerrow, p. 128)
;;;
;;; The hard part is not signing them but knowing which they are, and the two
;;; authorities agree that the question has no answer in the text. **The
;;; boundary is a printer's decision, not a property of the copy.** McKerrow's
;;; case: Tottel put the Table of his 1575 Treatise of Moral Philosophy among
;;; the preliminaries; East reprinted it in 1584, began the text at C1 in
;;; imitation, "then found he had room for the Table in the last gathering of
;;; the book and placed it there, with the result that his preliminaries now
;;; only" half filled a gathering (p. 78). The same matter, in the same words,
;;; is preliminary in one edition and terminal in the next, and the reason is
;;; how much room happened to be left.
;;;
;;; So this module guesses, says that it is guessing, gives its evidence, and
;;; can be overruled. A program that decided the question silently would be
;;; claiming to recover a decision from its outcome.

(require racket/list racket/string racket/match
         "copytext.rkt")

(provide (struct-out prelim-block) (struct-out division)
         divide-copy PRELIM-VOCABULARY MIGRATORY-KINDS
         prelim-kind-label prelim-heading-kind
         division-prelim-units division-summary)

;; A run of copy that is preliminary matter, with what it was recognised by.
(struct prelim-block (kind heading units confidence evidence) #:transparent)

;; The copy divided three ways. `terminal' is preliminary in kind but placed
;; after the text, which is East's case; `notes' is what the report must say
;; about how the division was arrived at.
(struct division (prelims body terminal declared? notes) #:transparent)

;; ---------------------------------------------------------------------------
;; The vocabulary
;; ---------------------------------------------------------------------------
;; What counts is a short, closed list, and both authorities give the same one.
;;
;;   "the title, dedication, preface, and, if there is one, list of contents"
;;   (McKerrow, p. 25)
;;
;;   "the title-page (which may be preceded by a half-title), dedication,
;;   preface, table of contents" ... "essentially of the title-page, the
;;   author's or publisher's prefatory matter and, sometimes, a table of
;;   contents" (Gaskell)
;;
;; The headings are the period's own. They are matched against the *heading*
;; only, and only where the heading stands before the text begins, because
;; every one of these phrases can occur inside a text as well.
;;
;; Each carries a confidence, and the differences are not decoration. "The
;; epistle dedicatory" can hardly be anything else. "The argument" heads a
;; preface in one book and every act of a play in another, and "the names of
;; the speakers" is preliminary in one edition of a masque and part of the text
;; in the next -- McKerrow prints both make-ups side by side (p. 182), where
;; the first edition has the Names on B1 with the text following. A flat
;; confidence would hide exactly the cases where the guess is worth doubting.
(define PRELIM-VOCABULARY
  (list
   (list 'title-page 0.95 #px"^(?:the )?title[- ]?page$")
   (list 'half-title 0.95 #px"^half[- ]?title")
   (list 'dedication 0.92
         #px"^(?:the )?(?:epistle )?dedicator(?:ie|y)|^(?:the )?dedication|^to the (?:right |most )?(?:honou?rable|worshipfull?|noble|worthie|worthy|excellent|sacred|reverend|vertuous|virtuous)|^to (?:his|my|the) (?:very |singular |good )*(?:lord|lady|grace|maiestie|majesty|highnesse|highness|patron)|^to the king|^to the queene?")
   (list 'preface 0.9
         #px"^(?:the |a )?(?:epistle|preface|proeme|proem|induction to the reader)|^to the (?:gentle|courteous|curteous|friendly|christian|indifferent|iudicious|judicious|learned|discreet|generall|general)? ?readers?\\b|^to the reader|^(?:the )?(?:author|printer|stationer|publisher|translator|bookseller) to the reader|^the epistle$")
   (list 'contents 0.8
         #px"^(?:the |a )?table\\b|^(?:the )?contents\\b|^(?:the )?index\\b|^a catalogue|^the chapters")
   (list 'errata 0.9
         #px"^(?:the )?errata|^faults escaped|^escapes in the printing|^errors escaped")
   (list 'licence 0.85
         #px"^seene and allowed|^seen and allowed|^imprimatur|^(?:the )?licence")
   (list 'advertisement 0.85
         #px"^(?:an )?aduertisement|^(?:an )?advertisement|^to the buyer|^to the reader concerning")
   (list 'commendatory 0.78
         #px"^to the (?:author|authour|memor(?:ie|y))|^(?:in|vpon|upon) (?:the )?(?:praise|prayse|commendation)|commendator(?:ie|y)|^(?:vpon|upon) the author")
   (list 'persons 0.6
         #px"^(?:the )?(?:names of the )?(?:actors|actours|persons|speakers|personae)|^dramatis person|^the persons of")
   (list 'argument 0.5
         #px"^(?:the )?argument\\b|^the summe of")))

;; Preliminary in kind, but the first thing to be moved when the room is not
;; there. The Table is McKerrow's own example of matter that changed sides
;; between editions; the errata leaf is his other one -- Gabriel Harvey's
;; Gratulationes Valdinenses "runs A-C4, D6, E-L4 + one leaf of errata"
;; (p. 216), where it is printed at the end, while the Masque of the Gentlemen
;; of Gray's Inn carries its errata on a4, among the preliminaries (p. 182).
;; Same kind of matter, both placings attested.
(define MIGRATORY-KINDS '(contents errata))

(define KIND-LABELS
  (hash 'title-page "title-page" 'half-title "half-title"
        'dedication "dedication" 'preface "preface"
        'contents "table of contents" 'errata "errata"
        'licence "licence" 'advertisement "advertisement"
        'commendatory "commendatory verses" 'persons "list of persons"
        'argument "argument"))

(define (prelim-kind-label k) (hash-ref KIND-LABELS k (lambda () (format "~a" k))))

;; Headings are compared stripped of case, of pointing, and of the flourishes
;; a heading picks up in print.
(define (normalise h)
  (string-trim
   (regexp-replace* #px"\\s+"
                    (string-downcase (regexp-replace* #px"[^A-Za-z ]+" h " "))
                    " ")))

;; Which kind of preliminary matter, if any, this heading names, and how far
;; the name is to be trusted. Returns (values kind confidence), or
;; (values #f 0.0) for a heading the vocabulary does not know.
(define (prelim-heading-kind heading)
  (define h (normalise heading))
  (define hit
    (and (not (string=? h ""))
         (for/or ([entry (in-list PRELIM-VOCABULARY)])
           (and (regexp-match? (third entry) h) entry))))
  (if hit (values (first hit) (second hit)) (values #f 0.0)))

(define heading-kind prelim-heading-kind)

;; ---------------------------------------------------------------------------
;; Dividing the copy
;; ---------------------------------------------------------------------------

;; How much of a book its front matter may plausibly be before the guess
;; becomes incredible. Gaskell's preliminaries run to a gathering or two, and
;; Blayney's checklist of ninety-odd books has none longer: A2, A4, *4, ¶8,
;; A4 a2. A fifth of the copy is generous by a wide margin.
;;
;; The cap exists for one case only, and it is not the ordinary one: the walk
;; already stops at the first heading outside the vocabulary, so a normal book
;; never reaches it. What it guards against is a book in which *every* heading
;; matches -- a collection of arguments, a volume of dedicatory epistles --
;; where nothing else would ever say stop.
;;
;; Hence the floor as well as the share. A share alone makes the cap bite
;; hardest on short copy, where it has least business biting: three paragraphs
;; of dedication are a fifth of a pamphlet and a hundredth of a folio, and only
;; one of those is suspicious.
(define PRELIM-SHARE-LIMIT 0.2)
(define PRELIM-UNIT-FLOOR 60)

;; And how long any one piece of front matter may be.
;;
;; This is the cap that matters, and the first version of this module did not
;; have it. A block opens at its heading and runs until the next heading; where
;; the copy that follows carries no headings at all -- which is most plain
;; copy, and all of Areopagitica -- the last block runs to the end of the book.
;; A table of contents of twenty thousand words is not a table of contents,
;; and the front matter came out fifty-two units long against the four that
;; were really there.
;;
;; The cap is in words because that is the unit the sources speak in. Gaskell's
;; preliminaries run to "a gathering or two"; the longest in Blayney's
;; checklist of ninety books is A4 *4, eight leaves. Eight leaves of a pica
;; quarto is sixteen pages of 38 lines at about eight and a half words to the
;; line, so a gathering is around 2,600 words and two are around 5,200. A block
;; over the one, or a whole front matter over the other, is not front matter,
;; and the walk stops there rather than truncating: cutting a block in the
;; middle would put half a table among the preliminaries, which is a worse
;; answer than none.
(define BLOCK-WORD-LIMIT 2600)
(define FRONT-WORD-LIMIT 5200)

;; Divide a parsed copy into preliminaries and text.
;;
;; `declared' is a hash from unit index to kind, for copy that says what it is
;; -- a TEI <div type="dedication">, or an explicit instruction on the command
;; line. Where it is given it is obeyed without argument and without a guess,
;; because it is evidence and the vocabulary is only an inference.
(define (divide-copy units
                     #:declared [declared (hash)]
                     #:guess? [guess? #t]
                     #:limit [limit PRELIM-SHARE-LIMIT])
  (define n (length units))
  (define ceiling (max PRELIM-UNIT-FLOOR (inexact->exact (floor (* limit n)))))

  (cond
    [(not (hash-empty? declared)) (divide-declared units declared)]
    [(or (not guess?) (zero? n))
     (division '() units '() #f
               (list (if guess?
                         "The copy is empty."
                         "No preliminary matter was looked for: the division was not guessed.")))]
    [else (divide-by-heading units ceiling)]))

;; Marked-up copy: believe it.
(define (divide-declared units declared)
  (define-values (pre body)
    (partition (lambda (u) (hash-has-key? declared (copy-unit-index u))) units))
  (define blocks
    (for/list ([grp (in-list (group-runs pre declared))])
      (prelim-block (car grp) (heading-of (cdr grp)) (cdr grp) 1.0
                    "declared in the copy")))
  (division blocks body '() #t
            (list (format "The copy declares its own divisions; ~a ~a taken from the markup, not guessed."
                          (length blocks)
                          (if (= 1 (length blocks)) "was" "were")))))

(define (heading-of us)
  (or (for/or ([u (in-list us)])
        (and (eq? (copy-unit-kind u) 'heading) (copy-unit-text u)))
      ""))

(define (group-runs us declared)
  (let loop ([us us] [cur '()] [kind #f] [out '()])
    (cond
      [(null? us)
       (reverse (if (null? cur) out (cons (cons kind (reverse cur)) out)))]
      [else
       (define k (hash-ref declared (copy-unit-index (car us)) #f))
       (if (eq? k kind)
           (loop (cdr us) (cons (car us) cur) kind out)
           (loop (cdr us) (list (car us)) k
                 (if (null? cur) out (cons (cons kind (reverse cur)) out))))])))

;; Plain copy: guess from the headings, and only from the front.
;;
;; The walk stops at the first thing that is not preliminary, which is the
;; whole discipline of it. A heading outside the vocabulary means the text has
;; begun; so does any body of copy that no preliminary heading introduced; and
;; so does a block that has grown past the extent front matter runs to. The
;; alternative -- scanning the whole book for matching headings -- would find
;; "The argument" at the head of every act and call a play its own front
;; matter.
;;
;; A block that outgrows the limit is abandoned whole rather than cut short.
;; The block boundary is the one thing the copy really does tell us; the extent
;; is a bound taken from what front matter is like elsewhere. Trusting the
;; weaker of the two to cut the stronger would put half a table among the
;; preliminaries and the other half at the head of the text.
(define (divide-by-heading units ceiling)
  (let loop ([us units] [blocks '()] [cur #f] [taken 0] [total 0])
    (define (close)
      (if cur (cons (finish cur) blocks) blocks))
    ;; give the unfinished block back to the text, in its original order
    (define (abandon reason)
      (assemble blocks (append (if cur (reverse (fourth cur)) '()) us)
                taken ceiling reason))
    (cond
      [(null? us) (assemble (close) '() taken ceiling #f)]
      [else
       (define u (car us))
       (define w (if (eq? (copy-unit-kind u) 'blank)
                     0
                     (length (string-split (copy-unit-text u)))))
       (cond
         ;; blank lines belong to whatever they sit in, and lead nowhere
         [(eq? (copy-unit-kind u) 'blank)
          (if cur
              (loop (cdr us) blocks (add-unit cur u 0) (add1 taken) total)
              (loop (cdr us) blocks cur taken total))]

         [(>= taken ceiling)
          (assemble (close) us taken ceiling #f)]

         [(eq? (copy-unit-kind u) 'heading)
          (define-values (kind conf) (heading-kind (copy-unit-text u)))
          (cond
            [(and kind (< (+ total w) FRONT-WORD-LIMIT))
             (loop (cdr us) (close) (open-block kind conf (copy-unit-text u) u)
                   (add1 taken) (+ total w))]
            [kind (abandon 'front-too-long)]
            ;; a heading the vocabulary does not know: the text has begun
            [else (assemble (close) us taken ceiling #f)])]

         [(and cur (>= (+ (fifth cur) w) BLOCK-WORD-LIMIT))
          (abandon 'block-too-long)]

         [(>= (+ total w) FRONT-WORD-LIMIT) (abandon 'front-too-long)]

         [cur (loop (cdr us) blocks (add-unit cur u w) (add1 taken) (+ total w))]

         ;; copy with no preliminary heading over it is text
         [else (assemble (close) us taken ceiling #f)])])))

;; A block under construction: (kind confidence heading reversed-units words)
(define (open-block kind conf heading u) (list kind conf heading (list u) 0))
(define (add-unit b u w)
  (list (first b) (second b) (third b) (cons u (fourth b)) (+ (fifth b) w)))

(define (finish b)
  (define units (reverse (fourth b)))
  (prelim-block (first b) (third b) units (second b)
                (format "the heading ~s is in the vocabulary of preliminary matter"
                        (third b))))

(define (assemble blocks rest taken ceiling [stopped-by #f])
  (define bs (reverse blocks))
  ;; A block of nothing but its own heading was a heading in the text that
  ;; happened to match; it is not front matter and is given back.
  (define (substance b)
    (for/sum ([u (in-list (prelim-block-units b))])
      (if (eq? (copy-unit-kind u) 'blank) 0 1)))
  (define-values (kept given-back) (partition (lambda (b) (> (substance b) 1)) bs))
  (define returned (append* (map prelim-block-units given-back)))
  (division kept (append returned rest) '() #f
            (notes-for kept taken ceiling stopped-by)))

(define (notes-for blocks taken ceiling [stopped-by #f])
  (define base
    (if (null? blocks)
        (list "No preliminary matter was identified. The copy declares none, and no heading before the text is in the vocabulary of preliminary matter.")
        (list
         (format "~a ~a of preliminary matter identified by ~a heading~a: ~a."
                 (length blocks)
                 (if (= 1 (length blocks)) "piece" "pieces")
                 (if (= 1 (length blocks)) "its" "their")
                 (if (= 1 (length blocks)) "" "s")
                 (string-join (for/list ([b (in-list blocks)])
                                (format "~a (~a)"
                                        (prelim-kind-label (prelim-block-kind b))
                                        (real->decimal-string
                                         (prelim-block-confidence b) 2)))
                              "; "))
         "This is a guess. Where the preliminaries end and the text begins was a decision taken in the printing house, not a property of the copy: McKerrow's Treatise of Moral Philosophy is preliminary in Tottel's edition and terminal in East's, in the same words, because East had room for it at the back.")))
  (append
   base
   (if (>= taken ceiling)
       (list (format "The search stopped after ~a units of copy. Every heading up to that point was in the vocabulary, which is likelier to mean a text whose sections are called arguments or epistles than a book with that much front matter." ceiling))
       '())
   (case stopped-by
     [(block-too-long)
      (list (format "One piece ran past ~a words with no further heading to close it, so the text was taken to have begun inside it and the whole piece was given back. Preliminary matter is short: Gaskell's runs to a gathering or two, and the longest in Blayney's checklist of ninety books is eight leaves."
                    BLOCK-WORD-LIMIT))]
     [(front-too-long)
      (list (format "The front matter passed ~a words — two gatherings of a pica quarto — and the search stopped. What follows was taken to be text."
                    FRONT-WORD-LIMIT))]
     [else '()])))

;; ---------------------------------------------------------------------------

(define (division-prelim-units d)
  (append* (map prelim-block-units (division-prelims d))))

(define (division-summary d)
  (string-join
   (append
    (for/list ([b (in-list (division-prelims d))])
      (format "  ~a~a  ~a unit~a — ~a"
              (prelim-kind-label (prelim-block-kind b))
              (if (string=? (prelim-block-heading b) "") ""
                  (format " (~s)" (prelim-block-heading b)))
              (length (prelim-block-units b))
              (if (= 1 (length (prelim-block-units b))) "" "s")
              (prelim-block-evidence b)))
    (division-notes d))
   "\n"))

(module+ test
  (require rackunit)

  ;; The vocabulary, on the period's own headings.
  (define (kind-of h) (let-values ([(k _c) (heading-kind h)]) k))
  (check-equal? (kind-of "THE EPISTLE DEDICATORIE") 'dedication)
  (check-equal? (kind-of "To the Right Honourable the Earle of Southampton")
                'dedication)
  (check-equal? (kind-of "To the Gentle Reader") 'preface)
  (check-equal? (kind-of "The Printer to the Reader") 'preface)
  (check-equal? (kind-of "A Table of the Chapters") 'contents)
  (check-equal? (kind-of "Faults escaped in the printing") 'errata)
  (check-equal? (kind-of "The Names of the Actors") 'persons)
  (check-equal? (kind-of "ACT I. SCENE I.") #f)
  (check-equal? (kind-of "THE TRAGEDY OF HAMLET") #f)
  (check-equal? (kind-of "Chapter the Third") #f)

  ;; Confidence is not flat, and the two shakiest kinds are the ones the
  ;; sources show on both sides of the boundary.
  (define (conf h) (let-values ([(_k c) (heading-kind h)]) c))
  (check-true (> (conf "The Epistle Dedicatorie") (conf "The Names of the Speakers")))
  (check-true (> (conf "To the Reader") (conf "The Argument")))

  ;; A copy with front matter: two blocks, then the text from the first
  ;; heading the vocabulary does not know.
  (define copy
    (string-append
     "# The Epistle Dedicatorie\n\n"
     "To the Right Honourable my very good Lord, the Earle of Pembroke.\n"
     "Your Lordships most humbly at commandement.\n\n"
     "# To the Gentle Reader\n\n"
     "Reader, thou hast here a booke set forth without ambition.\n\n"
     "# THE FIRST BOOKE\n\n"
     "Now began the day to breake, and the shepheards to stirre.\n"))
  (define d (divide-copy (parse-copy copy 'prose)))
  (check-equal? (map prelim-block-kind (division-prelims d)) '(dedication preface))
  (check-false (division-declared? d))
  (check-true (for/or ([u (in-list (division-body d))])
                (string-contains? (copy-unit-text u) "day to breake"))
              "the text is not swallowed by the preliminaries")
  (check-false (for/or ([u (in-list (division-body d))])
                 (string-contains? (copy-unit-text u) "Earle of Pembroke"))
               "the dedication is not left in the text")
  ;; and it says out loud that it is a guess
  (check-true (for/or ([n (in-list (division-notes d))])
                (string-contains? n "guess")))

  ;; A play whose acts are each headed "The Argument" must not be eaten. The
  ;; first heading is outside the vocabulary, so the walk stops at once.
  (define play
    (string-append
     "# THE TRAGEDIE OF GORBODUC\n\n"
     "# The Argument of the first Acte\n\n"
     "Gorboduc king of Britaine divided his realme.\n\n"
     "# The Argument of the second Acte\n\n"
     "Ferrex and Porrex disagreed.\n"))
  (define dp (divide-copy (parse-copy play 'prose)))
  (check-equal? (division-prelims dp) '())
  (check-equal? (length (division-body dp)) (length (parse-copy play 'prose)))

  ;; Copy with no headings at all is all text, and says why it found nothing.
  (define plain (divide-copy (parse-copy "Now the day is over.\n\nAnd night is here.\n" 'prose)))
  (check-equal? (division-prelims plain) '())
  (check-true (for/or ([n (in-list (division-notes plain))])
                (string-contains? n "no heading before the text")))

  ;; A heading in the vocabulary with nothing under it was a heading in the
  ;; text, not a preliminary, and must be handed back rather than kept.
  (define bare (divide-copy (parse-copy "# The Argument\n\n# THE FIRST BOOKE\n\nText.\n" 'prose)))
  (check-equal? (division-prelims bare) '())

  ;; Declared copy is obeyed, not guessed at: a div marked as a dedication is
  ;; a dedication whatever its heading says.
  (define us (parse-copy "# Somewhat Else\n\nA dedication in all but name.\n\n# THE TEXT\n\nBody.\n" 'prose))
  (define decl (hash 0 'dedication 1 'dedication 2 'dedication))
  (define dd (divide-copy us #:declared decl))
  (check-true (division-declared? dd))
  (check-equal? (map prelim-block-kind (division-prelims dd)) '(dedication))
  (check-equal? (prelim-block-confidence (car (division-prelims dd))) 1.0)

  ;; With guessing off, nothing is preliminary and the copy comes back whole.
  (define off (divide-copy (parse-copy copy 'prose) #:guess? #f))
  (check-equal? (division-prelims off) '())
  (check-equal? (length (division-body off)) (length (parse-copy copy 'prose))))
