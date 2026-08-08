#lang racket/base
;;; Command line: put a text through the press.
;;;
;;;   racket main.rkt samples/hamlet.txt --format quarto --compositors A,B
;;;   racket main.rkt samples/hamlet.txt --format folio6 --html -o out

(require racket/cmdline racket/file racket/string racket/port racket/list
         racket/system racket/runtime-path racket/math
         "book.rkt" "press.rkt" "render.rkt" "tei-html.rkt" "analysis.rkt" "imposition.rkt"
         "orthography.rkt" "compositor.rkt" "tei.rkt" "binding.rkt" "import.rkt"
         "paper.rkt" "recurrence.rkt")

(provide run-handpress apply-xslt)

(define-runtime-path xslt-dir "xslt")

;; The stylesheet that travels with a linked rendering is not the file on disk:
;; the departure marks are generated from the vocabulary and appended to it, so
;; copying xslt/facsimile.css would put out a page on which nothing the
;; simulation found is marked at all. Both assets come from tei-html.rkt, which
;; is where the composing is done for the inlined rendering too.
(define (write-assets! out-dir)
  (call-with-output-file (build-path out-dir "facsimile.css") #:exists 'truncate
    (lambda (o) (display (facsimile-stylesheet) o)))
  (call-with-output-file (build-path out-dir "facsimile.js") #:exists 'truncate
    (lambda (o) (display (facsimile-script) o))))
(define-runtime-path tools-dir "tools")
(define-runtime-path pdf-helper "tools/pdf-to-copy.py")

;; Apply an XSLT 1.0 stylesheet. Prefers xsltproc or Saxon if either is on the
;; PATH; otherwise falls back to .NET's XslCompiledTransform through
;; PowerShell, which needs no install on Windows. Returns #t on success.
(define (apply-xslt xml xsl out #:witness [witness "copya"]
                    #:layout [layout "opening"])
  (define (try-exe name args)
    (define exe (find-executable-path name))
    (and exe
         (parameterize ([current-output-port (open-output-nowhere)])
           (apply system* exe args))))
  (or
   (let ([exe (find-executable-path "xsltproc")])
     (and exe
          (let ([o (open-output-file out #:exists 'replace)])
            (begin0 (parameterize ([current-output-port o])
                      (system* exe "--stringparam" "witness" witness
                               "--stringparam" "layout" layout
                               (path->string xsl) (path->string xml)))
                    (close-output-port o)))))
   (let ([ps (or (find-executable-path "pwsh") (find-executable-path "powershell"))])
     (and ps
          (system* ps "-NoProfile" "-ExecutionPolicy" "Bypass" "-File"
                   (path->string (build-path tools-dir "xslt.ps1"))
                   "-Xml" (path->string xml)
                   "-Xsl" (path->string xsl)
                   "-Out" (path->string out)
                   "-Witness" witness
                   "-Layout" layout)))
   #f))

(define (run-handpress input
                       #:out [out-dir #f]
                       #:fmt-name [fmt-name "quarto"]
                       ;; The fount the facsimile is drawn in. A family name
                       ;; needs the reader to have it installed; a file is
                       ;; copied beside the page and embedded, which keeps the
                       ;; output self-contained the way the CSS and script are.
                       #:face [face #f]
                       #:font-file [font-file #f]
                       #:fit [fit #f]
                       ;; Bound as `sheet-name', not `paper-name': the latter
                       ;; is paper.rkt's own accessor, and shadowing it here
                       ;; turned (paper-name (book-paper b)) into an attempt to
                       ;; apply the string "foolscap" to an argument. Same trap
                       ;; imposition.rkt notes about `format'.
                       #:paper-name [sheet-name "foolscap"]
                       #:compositors [comps "A,B"]
                       #:order [order "formes"]
                       #:kind [kind 'auto]
                       #:seed [seed 1623]
                       #:copies [copies 4]
                       #:case-scale [case-scale 1.0]
                       #:cast-off [cast-off 0.93]
                       #:skeletons [skeletons 2]
                       #:formes-standing [standing 2]
                       #:stint-sheets [stint #f]
                       #:paging-error [paging-error 0.04]
                       #:prepare-copy? [prepare? #t]
                       #:first-proof [first-proof 0.0]
                       #:edition [edition 750]
                       #:condition [condition 'used]
                       #:title [title "THE HISTORY"]
                       #:book-title [book-title #f]
                       #:author [author #f]
                       #:printer [printer #f]
                       #:publisher [publisher #f]
                       #:titlepage? [titlepage? #t]
                       #:find-prelims? [find-prelims? #f]
                       #:contents? [contents? #t]
                       #:binding-error [binding-error #f]
                       #:cancel-rate [cancel-rate 0.0]
                       #:cancels [cancels 0]
                       #:imprint-change? [imprint-change? #f]
                       #:heap-disorder [heap-disorder 0.15]
                       ;; How many made-up copies get written out as text.
                       #:copy-texts [copy-texts 12]
                       ;; How fine an eye the analysis reads the book with.
                       ;; Nothing in the printing house sees this: it changes
                       ;; what the report can identify, never what was set.
                       #:discrimination [discrimination DEFAULT-DISCRIMINATION]
                       #:jaggard? [jaggard? #f]
                       #:prelim-style [prelim-style #f]
                       #:pages [pages 0]
                       #:numbers? [numbers? #f]
                       #:long-s? [long-s? #t]
                       #:modern-uv? [modern-uv? #f]
                       #:modern-spelling? [modern-spelling? #f]
                       ;; The scribal signs -- the stroke for a nasal, y-e for
                       ;; the, w-ch for which -- inherited from the manuscript
                       ;; hand. On by default because they are the most
                       ;; visibly period thing a page can do; see --no-scribal
                       ;; and the note in the report for what the evidence says.
                       #:scribal? [scribal? #t]
                       ;; The year of the impression. Not decoration: the
                       ;; scribal signs fall away by a factor of fifteen across
                       ;; the period this program covers, so a rate that is
                       ;; right for 1585 is fifteen times wrong for 1635.
                       ;; #f, not 1600: the default has to be distinguishable
                       ;; from a year the operator actually chose, or the
                       ;; document's date cannot know whether to defer to it.
                       #:year [year #f]
                       #:html? [html? #f]
                       #:tei? [tei? #f]
                       #:xslt? [xslt? #f]
                       #:witness [witness "copya"]
                       #:layout [layout "opening"]
                       #:quiet? [quiet? #f])
  ;; The document is read through import.rkt rather than slurped as text, so
  ;; that whatever it says about itself -- its divisions, its title, its author
  ;; -- reaches the press instead of being thrown away at the door.
  (define src (read-source input #:pdf-helper (path->string pdf-helper)))
  (define meta (source-metadata src))
  (define copy
    (let* ([body (source-text src)]
           [toc (and contents?
                     (not (regexp-match? #px"# \\[contents\\]" body))
                     (contents-from-headings
                      (for/list ([m (in-list (regexp-match*
                                              #px"(?m:^# (?!\\[)(.*)$)" body))])
                        (substring m 2))))])
      ;; A table of contents built from the document's own headings is
      ;; preliminary matter and is set like the rest of it. It goes in front of
      ;; the copy so that the divider finds it where a table belongs; whether
      ;; it stays there is settled later, by how much room the last sheet has.
      (if toc (string-append toc body) body)))
  (define (from-meta key given)
    (or given (let ([v (hash-ref meta key #f)])
                (and v (not (string=? (string-trim v) "")) (string-trim v)))))
  ;; What the operator said beats what the document says, and the document
  ;; beats the default. It was the other way round -- the document first, the
  ;; flag last -- so `--year' silently did nothing for any input that carried a
  ;; date, which is every TEI file, every .docx and every PDF. A flag that is
  ;; ignored whenever the interesting case arises is worse than no flag.
  ;;
  ;; The years are also sanity-checked. A date after the hand press is a date
  ;; read out of the wrong element, and printing a 1614 book with the
  ;; conventions of 2007 is not a thing to do quietly.
  (define (plausible-year n)
    (and n (<= 1450 n 1830) n))
  (define doc-year
    (or (plausible-year (let ([d (from-meta 'year #f)]) (and d (string->number d))))
        (plausible-year
         (let ([d (from-meta 'date #f)])
           (and d (let ([m (regexp-match #px"1[45678][0-9][0-9]" d)])
                    (and m (string->number (car m)))))))))
  (define year* (or year doc-year 1600))
  (define names (map string-trim (string-split comps ",")))
  (define cv (conventions long-s? (not modern-uv?) (not modern-uv?) #t scribal? year*))
  (define h (make-house #:fmt (hash-ref FORMATS fmt-name)
                        #:paper (or (paper-named sheet-name)
                                    (error 'handpress
                                           "unknown paper ~s; have ~a"
                                           sheet-name
                                           (string-join (paper-names) ", ")))
                        #:compositors names
                        #:seed seed
                        #:by-formes? (string=? order "formes")
                        #:conventions cv
                        #:case-scale case-scale
                        #:cast-off-accuracy cast-off
                        #:skeletons skeletons
                        #:formes-standing standing
                        #:stint-sheets stint
                        #:paging-error paging-error
                        #:prepare-copy? prepare?
                        #:condition condition
                        #:title title
                        #:book-title (from-meta 'title book-title)
                        #:author (from-meta 'author author)
                        #:printer printer
                        #:publisher (from-meta 'publisher publisher)
                        #:titlepage? titlepage?
                        #:find-prelims? find-prelims?
                        #:sig-alphabet (if jaggard? JAGGARD-LETTERS SIG-LETTERS)
                        #:prelim-style prelim-style))
  (define b (set-book h copy kind))
  (define r (run-press b #:copies copies #:seed seed #:first-proof first-proof
                       #:edition edition
                       #:binding-error (or binding-error BINDING-ERROR-RATE)
                       #:cancel-rate cancel-rate
                       #:cancels cancels
                       #:imprint-change? imprint-change?
                       #:heap-disorder heap-disorder))
  ;; The setting is finished before this point and is not affected by it. The
  ;; parameter governs only how the page is shown -- the same forme read in
  ;; the reader's spelling instead of the compositor's.
  (show-modernised? modern-spelling?)
  (define facsimile (render-book-text b #:numbers? numbers?))
  ;; Set after the book is made and before it is read, which is the order the
  ;; thing describes: the injuries are in the metal either way, and this says
  ;; only how much of them an investigator can make out.
  (current-discrimination discrimination)
  (define report (full-report b r names #:source src))

  (unless quiet?
    (for ([p (in-list (if (positive? pages)
                          (take (book-pages b) (min pages (length (book-pages b))))
                          (book-pages b)))])
      (printf "╭─ sig. ~a  ~a, set by Compositor ~a\n\n"
              (page-sig p) (page-forme-name p) (page-compositor p))
      (displayln (render-page-text p (book-format-columns (book-fmt b))
                                   #:numbers? numbers?
                                   #:measure-ems (book-format-measure-ems (book-fmt b))))
      (newline) (newline))
    (displayln report))

  (when out-dir
    (make-directory* out-dir)
    (define stem
      (let-values ([(base name dir?) (split-path (string->path input))])
        (path->string (path-replace-extension name #""))))
    (define (write! suffix text)
      (call-with-output-file (build-path out-dir (string-append stem suffix))
        #:exists 'replace
        (lambda (o) (write-string text o))))
    (write! ".facsimile.txt" facsimile)
    (write! ".report.txt" report)
    ;; One file per made-up copy, so they can be collated by eye. Capped,
    ;; because an edition is 1,200 copies and each one of a Folio renders to
    ;; some megabytes: writing them all is six gigabytes of near-identical
    ;; text nobody asked for. The *collation* still covers every copy -- that
    ;; happens in the press run and is reported in full; this only limits how
    ;; many are written out to read.
    (for ([pc (in-list (if (and (positive? copy-texts)
                                (> (length (press-run-copies r)) copy-texts))
                           (take (press-run-copies r) copy-texts)
                           (if (zero? copy-texts) '() (press-run-copies r))))])
      (write! (format ".~a.txt" (string-downcase
                                 (string-replace (printed-copy-name pc) " " "-")))
              (render-book-text b (copy-reading-map pc r))))
    (when (or tei? xslt?)
      (write! ".tei.xml" (book->tei b r names)))
    (when xslt?
      (define xml (build-path out-dir (string-append stem ".tei.xml")))
      (define xsl (build-path xslt-dir "tei-to-html.xsl"))
      ;; The stylesheet is shared with the direct rendering and linked rather
      ;; than inlined, so it has to travel with the output.
      (write-assets! out-dir)
      (define out (build-path out-dir (string-append stem ".tei.html")))
      ;; No processor is a documented outcome, not a fault: `apply-xslt' returns
      ;; #f when it can find neither xsltproc nor PowerShell, and the reading
      ;; text is the one output that is optional. So it is reported and not
      ;; raised -- and not on stderr under --quiet, because a machine reading
      ;; stderr for failures will otherwise count a missing optional tool as
      ;; one. The package build service does exactly that.
      (unless (apply-xslt xml xsl out #:witness witness #:layout layout)
        (unless quiet?
          (eprintf "could not run an XSLT processor; ~a not written\n"
                   (path->string out)))))
    ;; The facsimile is built from the TEI file, not from the book in memory.
    ;; That is the whole of the change: there is one rendering, its source is
    ;; the file on disk, and anything the TEI does not carry cannot appear.
    (when html?
      ;; Always written, never reused. Skipping the write when the file
      ;; happened to exist meant a stale TEI from an earlier run silently
      ;; became the source of the new HTML, and the facsimile then showed a
      ;; book that had not been printed.
      (define xml (build-path out-dir (string-append stem ".tei.xml")))
      (write! ".tei.xml" (book->tei b r names))
      (write-assets! out-dir)
      ;; An embedded fount travels with the page, like the stylesheet and the
      ;; script. Copied rather than linked to where it happens to sit, so the
      ;; output directory can be moved without the type going with it.
      (when font-file
        (unless (file-exists? font-file)
          (error 'handpress "no such font file: ~a" font-file))
        (define-values (_d fname _m) (split-path (string->path font-file)))
        (copy-file font-file (build-path out-dir fname) #t))
      (write! ".html"
              (tei-file->html
               xml
               ;; The same witness the XSLT reading text uses. The facsimile
               ;; must be *a* copy, not the earliest state of every forme at
               ;; once, which is a book no one owns.
               #:witness witness
               #:face face #:font-file font-file
               #:fit (and fit (string->number fit))
               ;; `--pages' truncated the terminal render and nothing else, so
               ;; there was no way at all to ask for a facsimile of part of a
               ;; book -- and on the Folio the facsimile is 79 MB and three and
               ;; a half minutes of layout. It now means what it says on both.
               #:pages pages
               ;; The collation gives the format, which is a folding and not a
               ;; size, so the sheet and the leaf it makes are named beside it.
               ;; A reader who is told "4°" and nothing else has been told how
               ;; the paper was folded and not how big the book is.
               #:lede (let ([L (book-layout b)])
                        (format "~a · ~a sheet ~a×~a mm, folded ~a · uncut leaf ~a×~a mm · set by ~a · ~a · ~a formes. Every word is placed at the position the simulated compositor computed for it."
                                (book-collation b)
                                (paper-name (book-paper b))
                                (paper-long (book-paper b)) (paper-short (book-paper b))
                                (case (book-format-folds (book-fmt b))
                                  [(1) "once"] [(2) "twice"] [(3) "three times"]
                                  [else (format "~a times" (book-format-folds (book-fmt b)))])
                                (exact-round (layout-leaf-h L))
                                (exact-round (layout-leaf-w L))
                                (string-join names ", ")
                                (if (string=? order "formes") "set by formes" "set seriatim")
                                (length (book-formes b)))))))
    (printf "\nWritten to ~a\n" (path->string (path->complete-path out-dir))))
  b)

(module+ main
  (define out-dir #f)
  (define fmt-name "quarto")
  (define sheet-name "foolscap")
  (define face #f)
  (define font-file #f)
  (define fit #f)
  (define comps "A,B")
  (define order "formes")
  (define kind 'auto)
  (define seed 1623)
  (define copies 4)
  (define case-scale 1.0)
  (define cast-off 0.93)
  (define skeletons 2)
  (define standing 2)
  (define stint #f)
  (define paging-error 0.04)
  (define prepare? #t)
  (define first-proof 0.0)
  (define edition 750)
  (define condition 'used)
  (define title "THE HISTORY")
  (define book-title #f)
  (define author #f)
  (define printer #f)
  (define publisher #f)
  (define titlepage? #t)
  (define find-prelims? #f)
  (define contents? #t)
  (define binding-error #f)
  (define cancel-rate 0.0)
  (define cancels 0)
  (define imprint-change? #f)
  (define heap-disorder 0.15)
  (define discrimination DEFAULT-DISCRIMINATION)
  (define copy-texts 12)
  (define jaggard? #f)
  (define prelim-style #f)
  (define pages 0)
  (define numbers? #f)
  (define long-s? #t)
  (define modern-uv? #f)
  (define modern-spelling? #f)
  (define scribal? #t)
  (define year #f)          ; #f until --year says otherwise; see year* above
  (define html? #f)
  (define tei? #f)
  (define xslt? #f)
  (define witness "copya")
  (define layout "opening")
  (define quiet? #f)

  (define input
    (command-line
     #:program "handpress"
     #:once-each
     [("-o" "--out") dir "directory for the output files" (set! out-dir dir)]
     [("--format") f "folio | folio6 | quarto | octavo" (set! fmt-name f)]
     [("--paper") p "sheet the shop buys: foolscap | pot | crown | demy | royal"
                    (set! sheet-name p)]
     [("--font") f "family the facsimile is drawn in, e.g. Junicode" (set! face f)]
     [("--font-file") f "a fount to embed beside the page, .woff2/.ttf/.otf"
                        (set! font-file f)]
     [("--fit") n "set width of that face against the body; re-derive it when the face changes"
                  (set! fit n)]
     [("--compositors") c "which workmen are at the frames" (set! comps c)]
     [("--order") o "formes | seriatim" (set! order o)]
     [("--kind") k "auto | verse | prose | drama" (set! kind (string->symbol k))]
     [("--seed") s "seed for the run" (set! seed (string->number s))]
     [("--copies") n "copies made up from the heaps" (set! copies (string->number n))]
     [("--case-scale") s "size of the fount; below 1.0 the case runs short"
                       (set! case-scale (string->number s))]
     [("--cast-off") a "accuracy of the casting off, 0-1"
                     (set! cast-off (string->number a))]
     [("--skeletons") n "skeleton formes in use" (set! skeletons (string->number n))]
     [("--paging-error") x "how freely the paging goes wrong, 0-1 (default 0.04)"
      (set! paging-error (string->number x))]
     [("--stint-sheets") n "sheets a man sets before the frame changes hands (default: by shop size)"
      (set! stint (string->number n))]
     [("--formes-standing") n "formes of type standing before distribution"
                            (set! standing (string->number n))]
     [("--first-proof") f "chance of a proof pulled BEFORE the run"
                        (set! first-proof (string->number f))]
     [("--edition") n "sheets printed; the Cambridge accounts show 400-820"
                    (set! edition (string->number n))]
     [("--fount") c "condition of the type: new | used | worn | foul"
                  (set! condition (string->symbol c))]
     [("--title") t "running title" (set! title t)]
     [("--book-title") t "title as set on the title-page" (set! book-title t)]
     [("--author") a "author, as named on the title-page" (set! author a)]
     [("--printer") p "printer named in the imprint" (set! printer p)]
     [("--publisher") p "bookseller named in the imprint" (set! publisher p)]
     [("--no-titlepage") "do not generate a title-page" (set! titlepage? #f)]
     [("--guess-prelims") "EXPERIMENTAL: where the document declares nothing, guess preliminary matter from a vocabulary of period headings. Off by default, and unreliable on anything but early copy that happens to head its front matter."
      (set! find-prelims? #t)]
     [("--no-contents") "do not build a table of contents from the document's headings"
      (set! contents? #f)]
     [("--binding-error") x "faults per gathering per copy at the folding (no source gives a rate)"
      (set! binding-error (string->number x))]
     [("--cancels") n "leaves cancelled for reasons outside the simulation"
      (set! cancels (string->number n))]
     [("--cancel-rate") x "chance that an error surviving the proof is thought worth cutting a leaf out for"
      (set! cancel-rate (string->number x))]
     [("--imprint-change") "re-issue with the bookseller's name altered: a cancel title"
      (set! imprint-change? #t)]
     [("--copy-texts") n
      "how many made-up copies to write out as text; 0 for none. Every copy is still collated."
      (set! copy-texts (string->number n))]
     [("--discrimination") x
      "how finely the ANALYSIS can tell one damaged type from another, 0-1; the default is anchored on Hinman's Folio and is a ceiling, not a typical eye"
      (set! discrimination (string->number x))]
     [("--heap-disorder") x
      "how much of the heaps' order the drying and piling destroy, 0-1. At 0 the copies are gathered exactly as Gaskell describes and the press variants group consistently; at 1 every forme is an independent draw. No source gives a value (default 0.15)"
      (set! heap-disorder (string->number x))]
     [("--jaggard-alphabet") "sign from Jaggard's 20 letters, omitting X, Y and Z"
      (set! jaggard? #t)]
     [("--prelim-signatures") st
      "how the preliminaries are signed: stars (* ** ***) | symbols (* † ‡ §) | pilcrow (¶ ¶¶) | lower (a b c) | english (text from B, prelims A then a) | continuous (no separate series) | unsigned (McKerrow's π) | auto"
      (set! prelim-style (and (not (string=? st "auto")) (string->symbol st)))]
     [("--pages") n "draw only the first N pages: the terminal render and the HTML facsimile. The book is still printed and collated whole."
                  (set! pages (string->number n))]
     [("--no-copy-preparation") "the corrector does not mark up the copy"
                                (set! prepare? #f)]
     [("--numbers") "number every fifth line of type" (set! numbers? #t)]
     [("--no-long-s") "set short s throughout" (set! long-s? #f)]
     [("--modern-uv") "keep modern u/v and i/j" (set! modern-uv? #t)]
     [("--no-scribal") "set no scribal abbreviations at all" (set! scribal? #f)]
     [("--year") y "year of the impression; scribal signs are dated (default 1600)"
                 (set! year (string->number y))]
     [("--modern-spelling") "show the same setting in modern spelling"
      (set! modern-spelling? #t)]
     [("--html") "also write an HTML facsimile, rendered from the TEI" (set! html? #t)]
     [("--tei") "also write a TEI P5 encoding" (set! tei? #t)]
     [("--xslt") "also write a plain reading text via the XSLT" (set! xslt? #t)]
     [("--witness") w "which made-up copy the XSLT should show (copya, copyb...)"
                    (set! witness w)]
     [("--layout") l "opening (verso|recto, as bound) or leaf (recto|verso)"
                   (set! layout l)]
     [("--quiet") "write files but print only a summary" (set! quiet? #t)]
     #:args (input) input))

  (void (run-handpress input
                       #:out out-dir #:fmt-name fmt-name #:paper-name sheet-name
                       #:face face #:font-file font-file #:fit fit
                       #:compositors comps
                       #:order order #:kind kind #:seed seed #:copies copies
                       #:case-scale case-scale #:cast-off cast-off
                       #:skeletons skeletons #:formes-standing standing
                       #:stint-sheets stint #:paging-error paging-error
                       #:prepare-copy? prepare? #:first-proof first-proof
                       #:edition edition #:condition condition
                       #:title title #:book-title book-title #:author author
                       #:printer printer #:publisher publisher
                       #:titlepage? titlepage? #:find-prelims? find-prelims?
                       #:contents? contents?
                       #:binding-error binding-error #:jaggard? jaggard?
                       #:prelim-style prelim-style
                       #:cancel-rate cancel-rate #:cancels cancels
                       #:imprint-change? imprint-change? #:heap-disorder heap-disorder
                       #:discrimination discrimination #:copy-texts copy-texts
                       #:pages pages #:numbers? numbers?
                       #:long-s? long-s? #:modern-uv? modern-uv?
                       #:modern-spelling? modern-spelling? #:scribal? scribal? #:year year
                       #:html? html? #:tei? tei? #:xslt? xslt?
                       #:witness witness #:layout layout #:quiet? quiet?)))

(module+ test
  (require rackunit racket/file racket/port)

  ;; There is one facsimile now, built by tei-html.rkt out of the .tei.xml and
  ;; nothing else, so there is no longer a parity to check: the two renderings
  ;; that used to be compared were the problem, not the thing being tested.
  ;;
  ;; What the stylesheet is for now is different in kind. It renders the TEI as
  ;; a plain reading text, for anyone who wants to see the file without Racket,
  ;; and it deliberately does not attempt the analytical furniture -- no
  ;; statistics, no key, no deviation colouring, no leaf and sheet grouping,
  ;; no damaged type. Holding it to the Racket renderer's output was what made
  ;; it drift; holding it to the *text* is a claim it can keep.
  ;;
  ;; So: the same words, in the same order. Nothing about the markup.
  (define dir (make-temporary-file "handpress~a" 'directory))
  (define sample (build-path dir "s.txt"))
  (display-to-file
   (apply string-append
          (for/list ([i (in-range 10)])
            (string-append
             "King. And can you by no drift of conference
"
             "Get from him why he puts on this confusion,
"
             "Grating so harshly all his days of quiet
"
             "With turbulent and dangerous lunacy?

")))
   sample)

  (run-handpress (path->string sample) #:out (path->string dir)
                 #:html? #t #:xslt? #t #:quiet? #t)

  (check-true (file-exists? (build-path dir "s.tei.xml")) "TEI was written")
  (check-true (file-exists? (build-path dir "s.html")) "the facsimile was built")

  (define via-tei (build-path dir "s.tei.html"))
  (cond
    [(file-exists? via-tei)
     (define h (file->string via-tei))
     ;; It renders every page the TEI declares ...
     (check-equal? (length (regexp-match* #px"class=\"pb\"" h))
                   (length (regexp-match* #px"<div type=\"page\""
                                          (file->string (build-path dir "s.tei.xml"))))
                   "the reading text covers every page of the TEI")
     ;; ... and the words of the book are in it.
     (check-true (regexp-match? #px"drift of conference" h)
                 "the reading text is the text")
     ;; ... and it is scoped down. These are the facsimile's business, and the
     ;; stylesheet claiming them is what made the two drift. If any of them
     ;; comes back, the decision has been quietly reversed.
     (for ([furniture (in-list '(#px"dev-" #px"--x:" #px"data-leaf"
                                 #px"What the run came to" #px"class=\"dmg"))])
       (check-false (regexp-match? furniture h)
                    (format "the reading text does not attempt ~a" furniture)))]
    [else
     (printf "  (no XSLT processor available; reading-text check skipped)
")])

  (delete-directory/files dir))
