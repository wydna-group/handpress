#lang racket/base
;;; Reading copy out of the formats people actually have.
;;;
;;; The preliminaries were the last thing this program tried to *guess*, and
;;; the guess was the wrong instrument. A heading vocabulary built from the
;;; period -- "to the right honourable", "the epistle dedicatorie" -- cannot
;;; see front matter that carries no heading, and Aylett's Peace with her Foure
;;; Garders (1622) opens with fourteen lines of dedicatory verse under none at
;;; all. Worse, it cannot help at all with the copy people will actually bring:
;;; a modern manuscript does not address a Lord Keeper.
;;;
;;; So the question is not "which of these headings looks preliminary?" but
;;; "what does this document already say about itself?" -- and the answer is
;;; usually a great deal, because every format worth uploading carries
;;; structure and metadata that a plain-text dump throws away.
;;;
;;;   YAML front matter          title, author, publisher, date
;;;   TEI <div type=...>         the division, declared outright
;;;   TEI <teiHeader>            title, author, publisher, date
;;;   LaTeX \frontmatter         everything to \mainmatter is preliminary
;;;   LaTeX \title \author       the title-page, as the author wrote it
;;;   DOCX paragraph styles      "Title", "Heading 1", "Dedication"
;;;   DOCX docProps/core.xml     dc:title, dc:creator, dc:publisher
;;;   HTML <meta>, <h1>-<h6>     the same, and the export target of all of them
;;;   PDF Info dictionary        title and author; the outline gives the parts
;;;
;;; Three tiers, in order of how much they are worth:
;;;
;;;   DECLARED     the source says what a division is. Obeyed.
;;;   CONSTRUCTED  the source gives structure and metadata but no divisions,
;;;                so the preliminaries are *built* rather than found: the
;;;                headings make a table of contents, the metadata makes a
;;;                title-page. Neither is a guess -- both are the document's
;;;                own words rearranged into the matter a printing house would
;;;                have set from them.
;;;   NOTHING      plain text with no structure gets no preliminaries. That is
;;;                the honest answer, and it is the default.
;;;
;;; The old vocabulary guess survives behind --guess-prelims, marked
;;; experimental, because it is still the only thing that can do anything at
;;; all with a bare transcription -- and because deleting a mechanism is a poor
;;; way to record what was learned from it.

(require racket/list racket/string racket/file racket/path racket/port
         racket/system file/unzip)

(provide (struct-out source) read-source source-kinds
         markdown->source tei->source html->source latex->source
         plain->source docx->source pdf->source
         strip-markup yaml-block contents-from-headings)

;; `text' is copy, in the form the compositor gets it, with declared divisions
;; marked on their headings as "# [dedication] The Epistle Dedicatorie".
;; `metadata' carries what the file says about itself; `notes' is what the
;; report must say about where any of it came from.
(struct source (text metadata origin notes) #:transparent)

;; The division kinds prelims.rkt knows, and what the various formats call
;; them. Anything not here is text: the point of reading a declaration is to
;; carry what the document asserts, not to improve on it.
(define DIVISION-KINDS
  (hash "title page" 'title-page "titlepage" 'title-page "title_page" 'title-page
        "half title" 'half-title "halftitle" 'half-title
        "dedication" 'dedication "epistle dedicatory" 'dedication
        "epistle-dedicatory" 'dedication
        "to the reader" 'preface "preface" 'preface "epistle" 'preface
        "proem" 'preface "foreword" 'preface "introduction" 'preface
        "table of contents" 'contents "contents" 'contents "toc" 'contents
        "index" 'contents
        "errata" 'errata "corrigenda" 'errata
        "argument" 'argument
        "to the author" 'commendatory "commendatory" 'commendatory
        "commendatory verses" 'commendatory
        "dramatis personae" 'persons "cast" 'persons
        "license" 'licence "licence" 'licence "imprimatur" 'licence
        "advertisement" 'advertisement "colophon" 'colophon))

(define (source-kinds) DIVISION-KINDS)

(define (kind-of name)
  (and name
       (hash-ref DIVISION-KINDS
                 (string-downcase (string-trim (regexp-replace* #px"[_-]+" name " ")))
                 #f)))

;; ---------------------------------------------------------------------------
;; Common
;; ---------------------------------------------------------------------------

;; Markup is stripped with regexes rather than parsed, deliberately.
;;
;; The files this has to read are not clean. EEBO-TCP transcriptions are
;; SGML-ish and predate XML; exported HTML is whatever the exporter felt like;
;; a Word document round-tripped through three programs is worse. A parser that
;; refuses one upload in twenty is a worse tool than a regex that degrades
;; gracefully on all of them, because the failure is total and the user cannot
;; do anything about it.
;; Every reader begins here.
;;
;; A file written on Windows has CRLF line endings, so a paragraph break is
;; CR LF CR LF rather than LF LF. The LaTeX reader split on the latter, so a
;; whole document arrived as a single paragraph, the first \frontmatter in
;; it swallowed the lot, and the book came out empty -- on the very first real
;; .tex file, because this program is developed on Windows. Normalising once at
;; the door is cheaper than remembering it in six readers.
(define (normalise-newlines s)
  (regexp-replace* #px"\r\n?" s "\n"))

;; U+2223 is how EEBO-TCP marks a word divided at a line-end in the book it
;; transcribes, and U+2027 a syllable break. Both are facts about the original
;; setting, not about the words, and they must not survive into the copy --
;; this program is about to divide the words for itself. Left in, they reached
;; the compositor: "HONORA∣tiss." was set as one word with a bar in the middle
;; of it, and every such word was one sort wider than it should have been.
(define (strip-markup s)
  (define t (regexp-replace* #px"<[^>]*>" s " "))
  (define u (string-replace (string-replace (unescape t) "∣" "") "‧" ""))
  (string-trim (regexp-replace* #px"\\s+" u " ")))

(define ENTITIES
  (hash "amp" "&" "lt" "<" "gt" ">" "quot" "\"" "apos" "'" "nbsp" " "
        "mdash" "—" "ndash" "–" "hellip" "…" "rsquo" "’" "lsquo" "‘"
        "ldquo" "“" "rdquo" "”"))

(define (unescape s)
  (regexp-replace*
   #px"&(#x?[0-9A-Fa-f]+|[A-Za-z]+);" s
   (lambda (all body)
     (cond
       [(string-prefix? body "#x")
        (string (integer->char (string->number (substring body 2) 16)))]
       [(string-prefix? body "#")
        (string (integer->char (string->number (substring body 1))))]
       [else (hash-ref ENTITIES body (lambda () all))]))))

;; A heading, with its declaration if it has one.
(define (heading-line kind text)
  (cond
    [(string=? (string-trim text) "") ""]
    [kind (format "# [~a] ~a\n\n" kind (string-trim text))]
    [else (format "# ~a\n\n" (string-trim text))]))

(define (para-line text)
  (if (string=? (string-trim text) "") "" (format "~a\n\n" (string-trim text))))

;; ---------------------------------------------------------------------------
;; A table of contents, constructed
;; ---------------------------------------------------------------------------
;; This is the part that makes structured copy worth having. A table of
;; contents is preliminary matter, it was set like the rest of it, and where a
;; document has real headings it can be built from them exactly -- no guessing,
;; no vocabulary, nothing invented but the arrangement.
;;
;; And it behaves like the real thing once it is there: it is the matter
;; McKerrow watched change sides between editions, so it is subject to the same
;; decision about whether it goes in front or at the back.
(define (contents-from-headings headings)
  (cond
    [(< (length headings) 3) #f]
    [else
     (string-append
      (heading-line 'contents "The Contents")
      (apply string-append
             (for/list ([h (in-list headings)])
               (para-line h))))]))

;; ---------------------------------------------------------------------------
;; Plain text
;; ---------------------------------------------------------------------------

(define (plain->source text0)
  (define text (normalise-newlines text0))
  (source text (hash) "plain text"
          (list "Plain text carries no structure and no metadata, so nothing is declared and nothing is constructed. The book has no preliminary matter beyond a title-page. See --guess-prelims for the experimental heading vocabulary.")))

;; ---------------------------------------------------------------------------
;; YAML front matter
;; ---------------------------------------------------------------------------
;; Not a YAML parser and does not pretend to be: a leading `---' fence, one
;; `key: value' to a line, quotes stripped. That is what a document's front
;; matter actually contains, and a real YAML library would buy nothing but a
;; dependency.

(define META-KEYS
  (hash "title" 'title "author" 'author "creator" 'author
        "publisher" 'publisher "printer" 'printer
        "date" 'date "year" 'year "subtitle" 'subtitle
        "motto" 'motto "epigraph" 'motto))

(define (yaml-block text)
  (define m (regexp-match #px"^---\\s*\r?\n(.*?)\r?\n---\\s*\r?\n(.*)$" text))
  (cond
    [(not m) (values (hash) text)]
    [else
     (define meta
       (for/fold ([h (hash)]) ([line (in-list (string-split (cadr m) "\n"))])
         (define kv (regexp-match #px"^([A-Za-z_-]+)\\s*:\\s*(.*)$" (string-trim line)))
         (cond
           [(not kv) h]
           [else
            (define key (hash-ref META-KEYS (string-downcase (cadr kv)) #f))
            (define val (string-trim (caddr kv) #px"[\"']" #:repeat? #t))
            (if (and key (not (string=? val ""))) (hash-set h key val) h)])))
     (values meta (caddr m))]))

;; ---------------------------------------------------------------------------
;; Markdown
;; ---------------------------------------------------------------------------
;; Headings are the structure; YAML is the metadata; Pandoc's fenced divs are
;; the declaration, because they are the only way markdown has of saying what a
;; section *is* rather than what it looks like.
;;
;;     ::: dedication
;;     To the Right Honourable ...
;;     :::
;;
;; A heading whose text names a division is taken as declaring it, which is not
;; the period vocabulary in disguise: "Contents", "Preface", "Dedication" are
;; the words a modern author writes, and matching them is reading the document,
;; not guessing at it.

(define (markdown->source text0)
  (define text (normalise-newlines text0))
  (define-values (meta body) (yaml-block text))
  (define lines (string-split (string-replace body "\r\n" "\n") "\n" #:trim? #f))
  (define out (open-output-string))
  (define headings '())
  (define declared 0)
  (define fenced #f)          ; the kind of the div we are inside, if any
  (define in-code? #f)

  (for ([raw (in-list lines)])
    (define line (string-trim raw #:left? #f))
    (define t (string-trim line))
    (cond
      [(regexp-match? #px"^```" t) (set! in-code? (not in-code?))
                                   (write-string "\n" out)]
      [in-code? (write-string (string-append line "\n") out)]

      ;; ::: dedication   /   ::: {.dedication}
      [(regexp-match #px"^:::+\\s*\\{?\\.?([A-Za-z_-]+)?\\}?\\s*$" t)
       => (lambda (m)
            (define name (cadr m))
            (define k (and name (kind-of name)))
            (cond
              [k (set! fenced k)
                 (set! declared (add1 declared))
                 (write-string (heading-line k (string-titlecase
                                                (regexp-replace* #px"[_-]+" name " ")))
                               out)]
              [else (set! fenced #f) (write-string "\n" out)]))]

      [(regexp-match #px"^(#{1,6})\\s+(.*?)\\s*#*$" t)
       => (lambda (m)
            (define depth (string-length (cadr m)))
            (define txt (caddr m))
            (define k (or fenced (kind-of txt)))
            (when k (set! declared (add1 declared)))
            ;; Only the top two levels go in the table; a contents listing
            ;; every sub-heading of a long book is an index, not a table.
            (when (and (<= depth 2) (not k)) (set! headings (cons txt headings)))
            (write-string (heading-line k txt) out))]

      [else (write-string (string-append line "\n") out)]))

  (define headings* (reverse headings))
  (source (get-output-string out) meta "Markdown"
          (markdown-notes meta declared headings*)))

(define (markdown-notes meta declared headings)
  (append
   (if (hash-empty? meta)
       (list "No YAML front matter, so the title-page is generated from the command line rather than from the document.")
       (list (format "YAML front matter gives ~a."
                     (string-join (for/list ([(k v) (in-hash meta)])
                                    (format "~a ~s" k v)) ", "))))
   (if (zero? declared)
       '()
       (list (format "~a division~a declared by the document itself." declared
                     (if (= 1 declared) "" "s"))))
   (if (>= (length headings) 3)
       (list (format "~a headings, from which a table of contents can be constructed."
                     (length headings)))
       '())))

;; ---------------------------------------------------------------------------
;; TEI, and EEBO-TCP
;; ---------------------------------------------------------------------------
;; The richest of the formats, because it says outright what every division is.
;; Both the P5 form (<div type="dedication">) and the older TCP form
;; (<DIV1 TYPE="dedication">) are read, since the corpus this project measures
;; itself against is the latter.

(define (tei->source text0)
  (define text (normalise-newlines text0))
  (define meta (tei-metadata text))
  (define body
    (let ([i (or (find-tag text #px"<(?i:text)\\b")
                 (find-tag text #px"<(?i:body)\\b"))])
      (if i (substring text i) text)))
  (define out (open-output-string))
  (define declared 0)
  (define pending (box #f))
  (define skipped (box #f))

  ;; A division with no heading of its own -- a title-page or a dedication
  ;; often has none, the words on the page being the heading -- still has to be
  ;; announced, or its first paragraph runs on from whatever came before.
  (define SUPPLIED
    (hash 'dedication "The Epistle Dedicatorie" 'preface "The Preface"
          'contents "The Contents" 'argument "The Argument"
          'commendatory "To the Author" 'errata "Errata"
          'licence "The Licence" 'persons "The Persons"))

  (for ([m (in-list (regexp-match-positions*
                     ;; <item> matters as much as <p>. A TEI or TCP table of
                     ;; contents is a <list> of <item>s, so a reader that
                     ;; matches only paragraphs finds the division, declares it
                     ;; preliminary, and then hands back nothing at all -- which
                     ;; is how a book whose copy declared a table of contents
                     ;; came out with no table in it.
                     ;; `(?s:)' throughout, because a `.' in a Racket regexp
                     ;; does not match a newline and every one of these elements
                     ;; routinely spans lines in a real file. Without it the
                     ;; reader silently dropped any paragraph long enough to be
                     ;; wrapped -- which is most of them in a transcription
                     ;; that keeps the original's line breaks.
                     #px"(?s:<(?i:div[0-9]?)\\b[^>]*>|<(?i:head)\\b[^>]*>.*?</(?i:head)>|<(?i:l|item)\\b[^>]*>.*?</(?i:l|item)>|<(?i:p)\\b[^>]*>.*?</(?i:p)>)"
                     body))])
    (define frag (substring body (car m) (cdr m)))
    (cond
      [(regexp-match? #px"^<(?i:div)" frag)
       (define ty (regexp-match #px"(?i:type)\\s*=\\s*[\"']([^\"']+)[\"']" frag))
       (define k (and ty (kind-of (cadr ty))))
       ;; The printed title-page of the original is not copy for a new setting:
       ;; the program sets its own, and keeping this one gives the book two.
       (set-box! skipped (eq? k 'title-page))
       (set-box! pending (and (not (eq? k 'title-page)) k))
       (when (and k (not (eq? k 'title-page))) (set! declared (add1 declared)))]

      [(unbox skipped) (void)]

      [(regexp-match? #px"^<(?i:head)" frag)
       (write-string (heading-line (unbox pending) (strip-markup frag)) out)
       (set-box! pending #f)]

      [else
       (when (unbox pending)
         (write-string (heading-line (unbox pending)
                                     (hash-ref SUPPLIED (unbox pending) "Preliminary"))
                       out)
         (set-box! pending #f))
       (define txt (strip-markup frag))
       (unless (string=? txt "")
         ;; A verse line runs on to the next; a list item does not. Given a
         ;; single newline, consecutive items are joined into one paragraph by
         ;; `parse-copy', and a forty-entry table of contents arrives as one
         ;; block of prose.
         (write-string (if (regexp-match? #px"^<(?i:l)\\b" frag)
                           (string-append txt "\n")
                           (para-line txt))
                       out))]))

  (source (clean-blanks (get-output-string out)) meta "TEI"
          (list (if (zero? declared)
                    "The TEI declares no preliminary divisions, so the book has none beyond its title-page."
                    (format "~a preliminary division~a declared by the TEI markup and taken from it, not guessed."
                            declared (if (= 1 declared) "" "s"))))))

(define (find-tag s rx)
  (define m (regexp-match-positions rx s))
  (and m (caar m)))

;; The date of the *book*, not of the file about the book.
;;
;; Taking the first <date> in a TEI document is wrong in exactly the case that
;; matters most here. A TEI header describes two things: the electronic text
;; and the source it was made from. Its <fileDesc><publicationStmt><date> is
;; when the transcription was published, and in every EEBO-TCP file that is the
;; first date in the document -- "2007-01 (EEBO-TCP Phase 1)". The book's own
;; date is in <sourceDesc>, further down: "M. D. C. XIV [1614]".
;;
;; So every book set from a TCP file was being printed in 2007. The damage was
;; silent and total: the conventions are dated, so with year 2007 the capital U
;; was kept where a fount of 1614 had none, the tilde fell to the floor rate of
;; the 1630s, and `--year' appeared to do nothing at all because the document
;; always overruled it. It also explains a discrepancy noted three sessions ago
;; and wrongly put down to clustering -- 0.22 scribal marks per thousand words
;; in the TEI book against 1.80 in the same text read from markdown.
;;
;; <sourceDesc> is searched first, and the file's own publication date is used
;; only if the source description has no date of its own.
(define SOURCE-DESC-RX
  #px"(?i:<sourceDesc\\b)(?:.*?)(?i:<date[^>]*>)(.*?)</(?i:date)>")

(define (tei-metadata text)
  (define (grab rx key h)
    (define m (regexp-match rx text))
    (if (and m (not (string=? (strip-markup (cadr m)) "")))
        (hash-set h key (strip-markup (cadr m)))
        h))
  (let* ([h (hash)]
         [h (grab #px"(?i:<title[^>]*>)(.*?)</(?i:title)>" 'title h)]
         [h (grab #px"(?i:<author[^>]*>)(.*?)</(?i:author)>" 'author h)]
         [h (grab #px"(?i:<publisher[^>]*>)(.*?)</(?i:publisher)>" 'publisher h)]
         [h (grab SOURCE-DESC-RX 'date h)]
         [h (if (hash-has-key? h 'date) h
                (grab #px"(?i:<date[^>]*>)(.*?)</(?i:date)>" 'date h))])
    h))

(define (clean-blanks s)
  (string-trim (regexp-replace* #px"\n{3,}" s "\n\n")))

;; ---------------------------------------------------------------------------
;; HTML
;; ---------------------------------------------------------------------------
;; Worth having for its own sake and worth twice that as the export format of
;; everything else: Word, Google Docs, Pages and every markdown tool will all
;; produce it, and a class or an id is as good a declaration as a TEI type.

(define (html->source text0)
  (define text (normalise-newlines text0))
  (define meta (html-metadata text))
  (define body
    (let ([i (find-tag text #px"<(?i:body)\\b")]) (if i (substring text i) text)))
  (define out (open-output-string))
  (define headings '())
  (define declared 0)
  (define fenced (box #f))

  (for ([m (in-list (regexp-match-positions*
                     ;; `(?s:)' for the same reason as in the TEI reader: a `.'
                     ;; does not match a newline, and a paragraph in real HTML
                     ;; is wrapped as often as not. Without it every <p> long
                     ;; enough to break a line was silently dropped.
                     #px"(?s:<(?i:section|div|article)\\b[^>]*>|<(?i:h[1-6])\\b[^>]*>.*?</(?i:h[1-6])>|<(?i:p|li|blockquote)\\b[^>]*>.*?</(?i:p|li|blockquote)>)"
                     body))])
    (define frag (substring body (car m) (cdr m)))
    (cond
      [(regexp-match? #px"^<(?i:section|div|article)" frag)
       (define cls (regexp-match #px"(?i:class|id)\\s*=\\s*[\"']([^\"']+)[\"']" frag))
       (set-box! fenced
                 (and cls (for/or ([w (in-list (string-split (cadr cls)))]) (kind-of w))))]

      [(regexp-match? #px"^<(?i:h[1-6])" frag)
       (define depth (string->number (substring (car (regexp-match #px"(?i:h[1-6])" frag)) 1)))
       (define txt (strip-markup frag))
       (define k (or (unbox fenced) (kind-of txt)))
       (when k (set! declared (add1 declared)))
       (when (and (<= depth 2) (not k)) (set! headings (cons txt headings)))
       (write-string (heading-line k txt) out)
       (set-box! fenced #f)]

      [else (write-string (para-line (strip-markup frag)) out)]))

  (source (clean-blanks (get-output-string out)) meta "HTML"
          (list (format "~a division~a declared by class or id; ~a heading~a for a table of contents."
                        declared (if (= 1 declared) "" "s")
                        (length headings) (if (= 1 (length headings)) "" "s")))))

(define (html-metadata text)
  (define (meta-tag name)
    (define m (regexp-match
               (pregexp (format "(?i:<meta[^>]*name\\s*=\\s*[\"']~a[\"'][^>]*content\\s*=\\s*[\"']([^\"']*)[\"'])" name))
               text))
    (and m (cadr m)))
  (define t (regexp-match #px"(?i:<title[^>]*>)(.*?)</(?i:title)>" text))
  (for/fold ([h (hash)])
            ([pair (in-list (list (cons 'title (and t (strip-markup (cadr t))))
                                  (cons 'author (meta-tag "author"))
                                  (cons 'publisher (meta-tag "publisher"))
                                  (cons 'date (meta-tag "date"))))])
    (if (and (cdr pair) (not (string=? (cdr pair) "")))
        (hash-set h (car pair) (cdr pair))
        h)))

;; ---------------------------------------------------------------------------
;; LaTeX
;; ---------------------------------------------------------------------------
;; The one format that has the printing house's own vocabulary built into it,
;; because it was written by a typesetter: \frontmatter and \mainmatter mark
;; exactly the division this program is trying to recover, and mark it because
;; the front matter is numbered differently -- which is the same fact about
;; printing order that gave the preliminaries a signature series of their own.

(define (latex->source text0)
  (define text (normalise-newlines text0))
  (define (brace-arg cmd)
    (define m (regexp-match (pregexp (format "\\\\~a\\s*\\{([^}]*)\\}" cmd)) text))
    (and m (string-trim (strip-tex (cadr m)))))
  (define meta
    (for/fold ([h (hash)])
              ([pair (in-list (list (cons 'title (brace-arg "title"))
                                    (cons 'author (brace-arg "author"))
                                    (cons 'date (brace-arg "date"))
                                    (cons 'publisher (brace-arg "publisher"))))])
      (if (and (cdr pair) (not (string=? (cdr pair) "")))
          (hash-set h (car pair) (cdr pair))
          h)))

  (define body
    (let ([m (regexp-match #px"(?s:\\\\begin\\{document\\}(.*)\\\\end\\{document\\})" text)])
      (if m (cadr m) text)))

  (define out (open-output-string))
  (define headings '())
  (define declared 0)
  (define front? (box #f))

  (for ([para (in-list (regexp-split #px"\n[ \t]*\n" body))])
    (define t (string-trim para))
    (cond
      [(string=? t "") (void)]
      [(regexp-match? #px"\\\\frontmatter" t) (set-box! front? #t)]
      [(regexp-match? #px"\\\\(mainmatter|backmatter)" t) (set-box! front? #f)]
      [(regexp-match #px"\\\\(chapter|section|subsection|part)\\*?\\s*\\{([^}]*)\\}" t)
       => (lambda (m)
            (define txt (strip-tex (caddr m)))
            ;; Inside \frontmatter everything is preliminary by declaration --
            ;; that is what the command means -- and the heading names which
            ;; kind it is where it can.
            (define k (or (kind-of txt) (and (unbox front?) 'preface)))
            (when k (set! declared (add1 declared)))
            (when (and (not k) (member (cadr m) '("chapter" "part" "section")))
              (set! headings (cons txt headings)))
            (write-string (heading-line k txt) out)
            (define rest (strip-tex (substring t (cdr (car (regexp-match-positions
                                                            #px"\\\\(chapter|section|subsection|part)\\*?\\s*\\{[^}]*\\}" t))))))
            (write-string (para-line rest) out))]
      [(regexp-match #px"\\\\begin\\{([A-Za-z]+)\\}" t)
       => (lambda (m)
            (define k (kind-of (cadr m)))
            (when k (set! declared (add1 declared))
                  (write-string (heading-line k (string-titlecase (cadr m))) out))
            (write-string (para-line (strip-tex t)) out))]
      [else (write-string (para-line (strip-tex t)) out)]))

  (source (clean-blanks (get-output-string out)) meta "LaTeX"
          (list (format "~a division~a declared by the source; \\frontmatter ~a."
                        declared (if (= 1 declared) "" "s")
                        (if (regexp-match? #px"\\\\frontmatter" text)
                            "marks the preliminaries outright"
                            "is not used")))))

(define (strip-tex s)
  (let* ([s (regexp-replace* #px"(?m:%.*$)" s "")]
         [s (regexp-replace* #px"\\\\(begin|end)\\{[A-Za-z*]+\\}" s " ")]
         [s (regexp-replace* #px"\\\\(emph|textit|textbf|textsc|text)\\s*\\{([^}]*)\\}" s "\\2")]
         [s (regexp-replace* #px"\\\\[A-Za-z]+\\*?(\\[[^]]*\\])?" s " ")]
         [s (regexp-replace* #px"[{}]" s "")]
         [s (regexp-replace* #px"~" s " ")])
    (string-trim (regexp-replace* #px"\\s+" s " "))))

;; ---------------------------------------------------------------------------
;; Word
;; ---------------------------------------------------------------------------
;; A .docx is a zip of XML, so no library is needed beyond the one in the
;; standard distribution. What matters is not the text -- that is easy -- but
;; the *styles*: a paragraph styled "Title" is the title, one styled
;; "Heading 1" is a heading, and one styled "Dedication" says so outright.
;; docProps/core.xml carries the author and the title as the file's own
;; properties, which is where Word puts what the user typed into File > Info.

(define (docx->source path)
  (define entries (make-hash))
  (call-with-input-file path
    (lambda (in)
      (unzip in (lambda (name dir? content)
                  (unless dir?
                    (hash-set! entries (bytes->string/utf-8 name #\?)
                               (port->string content)))))))
  (define doc (normalise-newlines (hash-ref entries "word/document.xml" "")))
  (define core (hash-ref entries "docProps/core.xml" ""))

  (define (core-field tag key h)
    (define m (regexp-match (pregexp (format "<~a[^>]*>(.*?)</~a>" tag tag)) core))
    (if (and m (not (string=? (strip-markup (cadr m)) "")))
        (hash-set h key (strip-markup (cadr m)))
        h))
  (define meta
    (let* ([h (hash)]
           [h (core-field "dc:title" 'title h)]
           [h (core-field "dc:creator" 'author h)]
           [h (core-field "dc:publisher" 'publisher h)]
           [h (core-field "dcterms:created" 'date h)])
      h))

  (define out (open-output-string))
  (define headings '())
  (define declared 0)

  (for ([m (in-list (regexp-match* #px"<w:p\\b.*?</w:p>|<w:p\\b[^>]*/>" doc))])
    (define style
      (let ([s (regexp-match #px"<w:pStyle[^>]*w:val=\"([^\"]+)\"" m)]) (and s (cadr s))))
    ;; The runs of a paragraph are its text; Word splits a sentence across them
    ;; wherever the formatting changes, so they have to be joined before
    ;; anything is done with the result.
    (define txt
      (string-trim
       (unescape
        (apply string-append
               (for/list ([r (in-list (regexp-match* #px"<w:t[^>]*>(.*?)</w:t>" m))])
                 (regexp-replace #px"(?s:^<w:t[^>]*>(.*)</w:t>$)" r "\\1"))))))
    (define heading-depth
      (let ([h (and style (regexp-match #px"^(?i:Heading)\\s*([1-6])$" style))])
        (and h (string->number (cadr h)))))
    (define k (or (and style (kind-of style)) (kind-of txt)))
    (cond
      [(string=? txt "") (void)]
      [(and style (string-ci=? style "Title"))
       (void)]   ; the title belongs on the title-page, not in the text
      [(or heading-depth k)
       (when k (set! declared (add1 declared)))
       (when (and heading-depth (<= heading-depth 2) (not k))
         (set! headings (cons txt headings)))
       (write-string (heading-line k txt) out)]
      [else (write-string (para-line txt) out)]))

  ;; A Word file whose title was styled rather than set in the properties.
  (define styled-title
    (for/or ([m (in-list (regexp-match* #px"<w:p\\b.*?</w:p>" doc))])
      (and (regexp-match? #px"<w:pStyle[^>]*w:val=\"(?i:Title)\"" m)
           (let ([t (string-trim (apply string-append
                                        (for/list ([r (in-list (regexp-match* #px"<w:t[^>]*>(.*?)</w:t>" m))])
                                          (regexp-replace #px"(?s:^<w:t[^>]*>(.*)</w:t>$)" r "\\1"))))])
             (and (not (string=? t "")) (unescape t))))))

  (source (clean-blanks (get-output-string out))
          (if (and styled-title (not (hash-has-key? meta 'title)))
              (hash-set meta 'title styled-title)
              meta)
          "Word (.docx)"
          (list (format "~a division~a declared by paragraph style; ~a heading~a for a table of contents.~a"
                        declared (if (= 1 declared) "" "s")
                        (length headings) (if (= 1 (length headings)) "" "s")
                        (if (hash-empty? meta)
                            " The document properties are empty, so the title-page comes from the command line."
                            "")))))

;; ---------------------------------------------------------------------------
;; PDF
;; ---------------------------------------------------------------------------
;; The weakest of them, and said to be. A PDF has thrown its structure away by
;; construction: what survives is the Info dictionary and, if the author made
;; one, the outline. The text comes back as lines on a page rather than as
;; paragraphs, so it has to be rejoined -- which is guesswork of a different
;; kind, and is why this is last in the list rather than first.
;;
;; Shelled out to Python, because PyMuPDF exists and no Racket equivalent does.

(define (pdf->source path helper)
  (define out (open-output-string))
  (define err (open-output-string))
  (define ok
    (parameterize ([current-output-port out] [current-error-port err])
      (define py (or (find-executable-path "python")
                     (find-executable-path "python3")))
      (and py (system* py helper path))))
  (cond
    [(not ok)
     (source "" (hash) "PDF"
             (list (format "The PDF could not be read: ~a" (string-trim (get-output-string err)))))]
    [else
     (define text (get-output-string out))
     ;; The helper emits the metadata as YAML front matter and the outline as
     ;; headings, so the rest of the pipeline is the markdown one.
     (define s (markdown->source text))
     (struct-copy source s
                  [origin "PDF"]
                  [notes (append
                          (list "A PDF has no divisions to declare. What can be had is the Info dictionary and the outline, and the text has been rejoined from lines into paragraphs by guess.")
                          (source-notes s))])]))

;; ---------------------------------------------------------------------------
;; Dispatch
;; ---------------------------------------------------------------------------

(define (read-source path #:pdf-helper [helper #f])
  (define ext (string-downcase (or (and (filename-extension path)
                                        (bytes->string/utf-8 (filename-extension path)))
                                   "")))
  (case ext
    [("md" "markdown" "mdown") (markdown->source (file->string path))]
    [("html" "htm" "xhtml")    (html->source (file->string path))]
    [("tex" "latex" "ltx")     (latex->source (file->string path))]
    [("docx")                  (docx->source path)]
    [("pdf")                   (pdf->source path helper)]
    [("xml" "tei")             (sniff-xml (file->string path))]
    [else
     ;; A .txt file may still be TEI or HTML saved under the wrong name, and a
     ;; file with no extension gives nothing away at all, so look inside.
     (sniff (file->string path))]))

(define (sniff-xml text)
  (if (regexp-match? #px"(?i:<(TEI|teiHeader|DIV[0-9]?\\b|ETS|EEBO))" text)
      (tei->source text)
      (html->source text)))

(define (sniff text)
  (cond
    [(regexp-match? #px"(?i:<(TEI|teiHeader|DIV[0-9] |ETS))" text) (tei->source text)]
    [(regexp-match? #px"(?i:<html|<!DOCTYPE html)" text) (html->source text)]
    [(regexp-match? #px"\\\\documentclass|\\\\begin\\{document\\}" text)
     (latex->source text)]
    [(or (regexp-match? #px"^---\\s*\r?\n" text)
         (regexp-match? #px"(?m:^#{1,6} \\S)" text))
     (markdown->source text)]
    [else (plain->source text)]))

(module+ test
  (require rackunit)

  ;; YAML front matter, and the body left alone.
  (let-values ([(meta body) (yaml-block "---\ntitle: Peace\nauthor: Robert Aylett\npublisher: \"Nathaniel Butter\"\n---\nNow began the day.\n")])
    (check-equal? (hash-ref meta 'title) "Peace")
    (check-equal? (hash-ref meta 'author) "Robert Aylett")
    (check-equal? (hash-ref meta 'publisher) "Nathaniel Butter")
    (check-equal? (string-trim body) "Now began the day."))

  ;; A document with no front matter is not mangled by looking for it.
  (let-values ([(meta body) (yaml-block "Just text.\n")])
    (check-true (hash-empty? meta))
    (check-equal? body "Just text.\n"))

  ;; Markdown: metadata, a Pandoc div, and a heading that names its own kind.
  (define md
    (markdown->source
     (string-append
      "---\ntitle: A Booke\nauthor: Someone\ndate: 1622\n---\n\n"
      "::: dedication\nTo my very good Lord.\n:::\n\n"
      "## Preface\n\nReader, thou hast here a booke.\n\n"
      "# The First Booke\n\nNow began the day.\n\n"
      "# The Second Booke\n\nAnd so it ended.\n")))
  (check-equal? (hash-ref (source-metadata md) 'title) "A Booke")
  (check-equal? (hash-ref (source-metadata md) 'date) "1622")

  ;; The date of the book, not the date of the transcription. Every EEBO-TCP
  ;; file puts its own publication date first, and taking that one printed
  ;; every book from the corpus with the conventions of 2007.
  (let ()
    (define tcp
      (string-append
       "<TEI><teiHeader><fileDesc><titleStmt><title>A Manual</title></titleStmt>"
       "<publicationStmt><date>2007-01 (EEBO-TCP Phase 1).</date></publicationStmt>"
       "<sourceDesc><biblFull><publicationStmt>"
       "<date>M. D. C. XIV [1614]</date>"
       "</publicationStmt></biblFull></sourceDesc>"
       "</fileDesc></teiHeader><text><body><p>Some copy to set.</p></body></text></TEI>"))
    (define s (tei->source tcp))
    (check-equal? (hash-ref (source-metadata s) 'date) "M. D. C. XIV [1614]"
                  "the source's date, not the file's"))
  ;; and a file with only its own date still yields it
  (let ()
    (define plain
      (string-append
       "<TEI><teiHeader><fileDesc><titleStmt><title>X</title></titleStmt>"
       "<publicationStmt><date>1650</date></publicationStmt></fileDesc></teiHeader>"
       "<text><body><p>Copy.</p></body></text></TEI>"))
    (check-equal? (hash-ref (source-metadata (tei->source plain)) 'date) "1650"))
  (check-true (regexp-match? #px"# \\[dedication\\]" (source-text md)))
  (check-true (regexp-match? #px"# \\[preface\\] Preface" (source-text md)))
  ;; and an ordinary heading is left undeclared
  (check-true (regexp-match? #px"# The First Booke" (source-text md)))
  (check-false (regexp-match? #px"\\[[a-z-]+\\] The First Booke" (source-text md)))

  ;; Nothing in the document, nothing invented.
  (define plain (plain->source "Now began the day to breake.\n"))
  (check-true (hash-empty? (source-metadata plain)))
  (check-true (for/or ([n (in-list (source-notes plain))])
                (string-contains? n "no structure")))

  ;; TEI: the division types are the declaration.
  (define tei
    (tei->source
     (string-append
      "<TEI><teiHeader><title>Peace with her foure Garders</title>"
      "<author>Robert Aylett</author><publisher>Nathaniel Butter</publisher>"
      "</teiHeader><text><body>"
      "<div type=\"dedication\"><p>To the Right Reverend Father in God.</p></div>"
      "<div type=\"preface\"><head>To the curious Reader</head><p>Reader.</p></div>"
      "<div type=\"part\"><head>Meditation I</head><l>Some loathing Peace, wish Warre,</l></div>"
      "</body></text></TEI>")))
  (check-equal? (hash-ref (source-metadata tei) 'author) "Robert Aylett")
  (check-equal? (hash-ref (source-metadata tei) 'publisher) "Nathaniel Butter")
  (check-true (regexp-match? #px"# \\[dedication\\]" (source-text tei)))
  (check-true (regexp-match? #px"# \\[preface\\] To the curious Reader" (source-text tei)))
  (check-true (regexp-match? #px"# Meditation I" (source-text tei)))
  ;; a dedication with no heading of its own still gets announced
  (check-true (string-contains? (source-text tei) "To the Right Reverend Father"))

  ;; The original's own title-page is not copy for a new setting.
  (define tei-tp
    (tei->source "<text><body><div type=\"title page\"><p>PEACE WITH HER FOURE GARDERS. London, 1622.</p></div><div type=\"part\"><head>Meditation I</head><p>Now.</p></div></body></text>"))
  (check-false (string-contains? (source-text tei-tp) "FOURE GARDERS"))
  (check-true (string-contains? (source-text tei-tp) "Meditation I"))

  ;; HTML: a class is as good a declaration as a TEI type.
  (define h
    (html->source
     (string-append
      "<html><head><title>A Booke</title>"
      "<meta name=\"author\" content=\"Someone\"></head><body>"
      "<section class=\"dedication\"><h2>To my Lord</h2><p>Yours humbly.</p></section>"
      "<h1>The First Booke</h1><p>Now began the day.</p></body></html>")))
  (check-equal? (hash-ref (source-metadata h) 'title) "A Booke")
  (check-equal? (hash-ref (source-metadata h) 'author) "Someone")
  (check-true (regexp-match? #px"# \\[dedication\\] To my Lord" (source-text h)))
  (check-true (regexp-match? #px"# The First Booke" (source-text h)))

  ;; LaTeX: \frontmatter is the declaration, and it is a real one.
  (define tex
    (latex->source
     (string-append
      "\\documentclass{book}\n\\title{A Booke}\n\\author{Someone}\n"
      "\\begin{document}\n\\frontmatter\n\n"
      "\\chapter{Preface}\n\nReader, thou hast here a booke.\n\n"
      "\\mainmatter\n\n\\chapter{The First Booke}\n\nNow began the day.\n"
      "\\end{document}\n")))
  (check-equal? (hash-ref (source-metadata tex) 'title) "A Booke")
  (check-equal? (hash-ref (source-metadata tex) 'author) "Someone")
  (check-true (regexp-match? #px"# \\[preface\\] Preface" (source-text tex)))
  (check-true (regexp-match? #px"# The First Booke" (source-text tex)))
  (check-false (regexp-match? #px"\\\\chapter" (source-text tex))
               "the TeX commands do not reach the compositor")

  ;; Sniffing, for a file saved under the wrong name.
  (check-equal? (source-origin (sniff "<html><body><p>Hi</p></body></html>")) "HTML")
  (check-equal? (source-origin (sniff "---\ntitle: X\n---\n\nHi\n")) "Markdown")
  (check-equal? (source-origin (sniff "# A Heading\n\nHi\n")) "Markdown")
  (check-equal? (source-origin (sniff "Just some prose.\n")) "plain text")
  (check-equal? (source-origin (sniff "\\documentclass{book}\n\\begin{document}\nHi\n\\end{document}"))
                "LaTeX")

  ;; A table of contents is built from the headings, or not built at all.
  (check-false (contents-from-headings '("One" "Two")))
  (define toc (contents-from-headings '("The First Booke" "The Second Booke" "The Third")))
  (check-true (regexp-match? #px"# \\[contents\\]" toc))
  (check-true (string-contains? toc "The Second Booke"))

  ;; Entities are decoded, because a compositor setting "&amp;" would be
  ;; setting four sorts where the author wrote one.
  (check-equal? (strip-markup "<p>Peace &amp; Warre</p>") "Peace & Warre")
  (check-equal? (strip-markup "<p>caf&#233;</p>") "café")

  ;; CRLF. A file written on Windows -- which is most of them -- must read the
  ;; same as one written on anything else. This is not hypothetical: the LaTeX
  ;; reader split paragraphs on "\n\n", so the first real .tex file arrived as
  ;; one paragraph, its \frontmatter swallowed the book, and the run came out
  ;; empty. Every reader is checked, because the bug was in the one reader that
  ;; had not been.
  (define crlf-tex
    (latex->source
     (string-append
      "\\documentclass{book}\r\n\\title{A Booke}\r\n\\begin{document}\r\n"
      "\\frontmatter\r\n\r\n\\chapter{Preface}\r\n\r\nReader.\r\n\r\n"
      "\\mainmatter\r\n\r\n\\chapter{The First Booke}\r\n\r\nNow began the day.\r\n"
      "\\end{document}\r\n")))
  (check-true (regexp-match? #px"# \\[preface\\] Preface" (source-text crlf-tex))
              "CRLF LaTeX still declares its front matter")
  (check-true (string-contains? (source-text crlf-tex) "Now began the day.")
              "CRLF LaTeX still yields a text")

  (define crlf-md
    (markdown->source "---\r\ntitle: A Booke\r\n---\r\n\r\n## Preface\r\n\r\nReader.\r\n"))
  (check-equal? (hash-ref (source-metadata crlf-md) 'title) "A Booke")
  (check-true (regexp-match? #px"# \\[preface\\] Preface" (source-text crlf-md)))

  (define crlf-tei
    (tei->source "<text><body>\r\n<div type=\"dedication\">\r\n<p>To my Lord.</p>\r\n</div>\r\n</body></text>"))
  (check-true (regexp-match? #px"# \\[dedication\\]" (source-text crlf-tei))))
