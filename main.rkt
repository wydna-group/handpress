#lang racket/base
;;; Command line: put a text through the press.
;;;
;;;   racket main.rkt samples/hamlet.txt --format quarto --compositors A,B
;;;   racket main.rkt samples/hamlet.txt --format folio6 --html -o out

(require racket/cmdline racket/file racket/string racket/port racket/list
         racket/system racket/runtime-path
         "book.rkt" "press.rkt" "render.rkt" "analysis.rkt" "imposition.rkt"
         "orthography.rkt" "compositor.rkt" "tei.rkt")

(provide run-handpress apply-xslt)

(define-runtime-path xslt-dir "xslt")
(define-runtime-path tools-dir "tools")

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
                       #:compositors [comps "A,B"]
                       #:order [order "formes"]
                       #:kind [kind 'auto]
                       #:seed [seed 1623]
                       #:copies [copies 4]
                       #:case-scale [case-scale 1.0]
                       #:cast-off [cast-off 0.93]
                       #:skeletons [skeletons 2]
                       #:formes-standing [standing 2]
                       #:prepare-copy? [prepare? #t]
                       #:first-proof [first-proof 0.0]
                       #:edition [edition 750]
                       #:condition [condition 'used]
                       #:title [title "THE HISTORY"]
                       #:pages [pages 0]
                       #:numbers? [numbers? #f]
                       #:long-s? [long-s? #t]
                       #:modern-uv? [modern-uv? #f]
                       #:html? [html? #f]
                       #:tei? [tei? #f]
                       #:xslt? [xslt? #f]
                       #:witness [witness "copya"]
                       #:layout [layout "opening"]
                       #:quiet? [quiet? #f])
  (define copy (file->string input))
  (define names (map string-trim (string-split comps ",")))
  (define cv (conventions long-s? (not modern-uv?) (not modern-uv?) #t))
  (define h (make-house #:fmt (hash-ref FORMATS fmt-name)
                        #:compositors names
                        #:seed seed
                        #:by-formes? (string=? order "formes")
                        #:conventions cv
                        #:case-scale case-scale
                        #:cast-off-accuracy cast-off
                        #:skeletons skeletons
                        #:formes-standing standing
                        #:prepare-copy? prepare?
                        #:condition condition
                        #:title title))
  (define b (set-book h copy kind))
  (define r (run-press b #:copies copies #:seed seed #:first-proof first-proof
                       #:edition edition))
  (define facsimile (render-book-text b #:numbers? numbers?))
  (define report (full-report b r names))

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
    ;; one file per made-up copy of the edition, so they can be collated
    (for ([pc (in-list (press-run-copies r))])
      (write! (format ".~a.txt" (string-downcase
                                 (string-replace (printed-copy-name pc) " " "-")))
              (render-book-text b (copy-reading-map pc r))))
    (when (or tei? xslt?)
      (write! ".tei.xml" (book->tei b r names)))
    (when xslt?
      (define xml (build-path out-dir (string-append stem ".tei.xml")))
      (define xsl (build-path xslt-dir "tei-to-html.xsl"))
      (define out (build-path out-dir (string-append stem ".tei.html")))
      (unless (apply-xslt xml xsl out #:witness witness #:layout layout)
        (eprintf "could not run an XSLT processor; ~a not written\n"
                 (path->string out))))
    (when html?
      (write! ".html"
              (render-book-html
               b #:title (string-append (string-titlecase title) " — a type-facsimile")
               #:lede (format "~a · set by ~a · ~a · ~a formes. Every word is placed at the position the simulated compositor computed for it."
                              (book-collation b) (string-join names ", ")
                              (if (string=? order "formes") "set by formes" "set seriatim")
                              (length (book-formes b)))
               #:run r
               #:extra (report-html b r names))))
    (printf "\nWritten to ~a\n" (path->string (path->complete-path out-dir))))
  b)

(module+ main
  (define out-dir #f)
  (define fmt-name "quarto")
  (define comps "A,B")
  (define order "formes")
  (define kind 'auto)
  (define seed 1623)
  (define copies 4)
  (define case-scale 1.0)
  (define cast-off 0.93)
  (define skeletons 2)
  (define standing 2)
  (define prepare? #t)
  (define first-proof 0.0)
  (define edition 750)
  (define condition 'used)
  (define title "THE HISTORY")
  (define pages 0)
  (define numbers? #f)
  (define long-s? #t)
  (define modern-uv? #f)
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
     [("--formes-standing") n "formes of type standing before distribution"
                            (set! standing (string->number n))]
     [("--first-proof") f "chance of a proof pulled BEFORE the run"
                        (set! first-proof (string->number f))]
     [("--edition") n "sheets printed; the Cambridge accounts show 400-820"
                    (set! edition (string->number n))]
     [("--fount") c "condition of the type: new | used | worn | foul"
                  (set! condition (string->symbol c))]
     [("--title") t "running title" (set! title t)]
     [("--pages") n "show only the first N pages on screen"
                  (set! pages (string->number n))]
     [("--no-copy-preparation") "the corrector does not mark up the copy"
                                (set! prepare? #f)]
     [("--numbers") "number every fifth line of type" (set! numbers? #t)]
     [("--no-long-s") "set short s throughout" (set! long-s? #f)]
     [("--modern-uv") "keep modern u/v and i/j" (set! modern-uv? #t)]
     [("--html") "also write an HTML facsimile, direct from the type" (set! html? #t)]
     [("--tei") "also write a TEI P5 encoding" (set! tei? #t)]
     [("--xslt") "write the TEI and transform it to HTML with XSLT" (set! xslt? #t)]
     [("--witness") w "which made-up copy the XSLT should show (copya, copyb...)"
                    (set! witness w)]
     [("--layout") l "opening (verso|recto, as bound) or leaf (recto|verso)"
                   (set! layout l)]
     [("--quiet") "write files but print only a summary" (set! quiet? #t)]
     #:args (input) input))

  (void (run-handpress input
                       #:out out-dir #:fmt-name fmt-name #:compositors comps
                       #:order order #:kind kind #:seed seed #:copies copies
                       #:case-scale case-scale #:cast-off cast-off
                       #:skeletons skeletons #:formes-standing standing
                       #:prepare-copy? prepare? #:first-proof first-proof
                       #:edition edition #:condition condition
                       #:title title #:pages pages #:numbers? numbers?
                       #:long-s? long-s? #:modern-uv? modern-uv?
                       #:html? html? #:tei? tei? #:xslt? xslt?
                       #:witness witness #:layout layout #:quiet? quiet?)))

(module+ test
  (require rackunit racket/file racket/port)

  ;; The whole point of putting the geometry into the TEI is that the
  ;; facsimile can be rebuilt from it. So the HTML made by XSLT out of the TEI
  ;; must agree with the HTML made directly from the standing type: same
  ;; leaves, same type lines, same words, same positions. If it does not, the
  ;; TEI has lost something.
  (define dir (make-temporary-file "handpress~a" 'directory))
  (define sample (build-path dir "s.txt"))
  (display-to-file
   (apply string-append
          (for/list ([i (in-range 10)])
            (string-append
             "King. And can you by no drift of conference\n"
             "Get from him why he puts on this confusion,\n"
             "Grating so harshly all his days of quiet\n"
             "With turbulent and dangerous lunacy?\n\n")))
   sample)

  (run-handpress (path->string sample) #:out (path->string dir)
                 #:html? #t #:xslt? #t #:quiet? #t)

  (define direct (build-path dir "s.html"))
  (define via-tei (build-path dir "s.tei.html"))

  (check-true (file-exists? (build-path dir "s.tei.xml")) "TEI was written")

  (cond
    [(file-exists? via-tei)
     (define (counts f)
       (define h (file->string f))
       ;; "leaf plate" only: the XSLT also emits "leaf absent" placeholders
       ;; for the blank left of the first opening and right of the last.
       (list (length (regexp-match* #px"class=\"leaf plate\"" h))
             (length (regexp-match* #px"class=\"tline\"" h))
             (length (regexp-match* #px"class=\"w[ \"]" h))
             (regexp-match* #px"--x:([0-9.]+)" h)))
     (define a (counts direct))
     (define b (counts via-tei))
     (check-equal? (first b) (first a) "same number of leaves")
     (check-equal? (second b) (second a) "same number of type lines")
     (check-equal? (third b) (third a) "same number of words")
     (check-equal? (fourth b) (fourth a)
                   "every word at the same computed position")]
    [else
     (printf "  (no XSLT processor available; round-trip check skipped)\n")])

  (delete-directory/files dir))
