#lang racket/base

;;; The sources this simulation is built from, as citable entries.
;;;
;;; They fall into three kinds, and the distinction matters more than the
;;; alphabetical order suggests:
;;;
;;;   the manuals      Moxon, Smith. Written by printers for printers, and
;;;                    the only sources that describe the work from inside.
;;;
;;;   the archives     McKenzie's Cambridge study, and Simpson's proof-sheets.
;;;                    Records made at the time for other purposes, which is
;;;                    what makes them evidence rather than inference.
;;;
;;;   the analyses     Greg, Hinman, Bowers, Blayney, McKerrow. Reconstructions
;;;                    from the printed books themselves -- the New
;;;                    Bibliography, whose method this program both implements
;;;                    and tests to destruction.

(require scriblib/autobib)

(provide (all-defined-out))

(define-cite ~cite citet generate-bibliography)

;; --- the manuals ---------------------------------------------------------

(define moxon
  (make-bib
   #:title "Mechanick Exercises on the Whole Art of Printing"
   #:author (authors "Joseph Moxon")
   #:date 1683
   #:location (book-location #:publisher "London")
   #:note (string-append
           "Published in parts, 1683-4. The first account of the trade "
           "written from inside it. "
           "The lay of the case, the spaces, the reaching, and the "
           "corrector's reader all come from here.")))

(define smith
  (make-bib
   #:title "The Printer's Grammar"
   #:author (authors "John Smith")
   #:date 1755
   #:location (book-location #:publisher "London")))

;; --- the archives --------------------------------------------------------

(define mckenzie-cambridge
  (make-bib
   #:title "The Cambridge University Press 1696–1712: A Bibliographical Study"
   #:author (authors "D. F. McKenzie")
   #:date 1966
   #:location (book-location #:publisher "Cambridge University Press")
   #:note (string-append
           "Two volumes. The one place where the working of a hand-press "
           "shop can be checked against its surviving output, and the "
           "source of nearly every correction this program has had to make.")))

(define mckenzie-printers
  (make-bib
   #:title "Printers of the Mind: Some Notes on Bibliographical Theories and Printing-House Practices"
   #:author (authors "D. F. McKenzie")
   #:date 1969
   #:location (journal-location "Studies in Bibliography"
                                #:volume "22" #:pages '(1 75))))

(define simpson
  (make-bib
   #:title "Proof-Reading in the Sixteenth, Seventeenth and Eighteenth Centuries"
   #:author (authors "Percy Simpson")
   #:date 1935
   #:location (book-location #:publisher "Oxford University Press")
   #:note (string-append
           "Reprinted 1970 with a foreword by Harry Carter, where most of "
           "the corrections to Simpson actually are.")))

;; --- the analyses --------------------------------------------------------

(define greg
  (make-bib
   #:title "The Shakespeare First Folio: Its Bibliographical and Textual History"
   #:author (authors "W. W. Greg")
   #:date 1955
   #:location (book-location #:publisher "Clarendon Press")))

(define norton
  (make-bib
   #:title "The Norton Facsimile: The First Folio of Shakespeare"
   #:author (authors "Charlton Hinman")
   #:date 1968
   #:location (book-location #:publisher "W. W. Norton")
   #:note (string-append
           "The book itself, in Hinman's through-line numbering, and an "
           "introduction that summarises the press-variant evidence his two "
           "volumes leave scattered: just over 500 variants in about a "
           "hundred variant formes, and about a hundred impressions worked "
           "off before a correction came back. The plates are evidence in "
           "their own right -- word division measured across 790 of them "
           "runs 6.41 per 100 lines in the prose plays against 0.40 in the "
           "verse, which settles a rate that had been calibrated on five "
           "scenes of one comedy.")))

(define hinman
  (make-bib
   #:title "The Printing and Proof-Reading of the First Folio of Shakespeare"
   #:author (authors "Charlton Hinman")
   #:date 1963
   #:location (book-location #:publisher "Clarendon Press")
   #:note (string-append
           "Two volumes. The compositor spellings, the type-recurrence "
           "method, the proof-reading, and the caveat about justification "
           "that the whole method turns on.")))

(define bowers
  (make-bib
   #:title "Principles of Bibliographical Description"
   #:author (authors "Fredson Bowers")
   #:date 1949
   #:location (book-location #:publisher "Princeton University Press")))

(define blayney
  (make-bib
   #:title "The Texts of King Lear and their Origins, I: Nicholas Okes and the First Quarto"
   #:author (authors "Peter W. M. Blayney")
   #:date 1982
   #:location (book-location #:publisher "Cambridge University Press")))

(define mckerrow
  (make-bib
   #:title "An Introduction to Bibliography for Literary Students"
   #:author (authors "R. B. McKerrow")
   #:date 1927
   #:location (book-location #:publisher "Clarendon Press")))

(define gaskell
  (make-bib
   #:title "A New Introduction to Bibliography"
   #:author (authors "Philip Gaskell")
   #:date 1972
   #:location (book-location #:publisher "Oxford University Press")))

(define gaskell-case
  (make-bib
   #:title "The Lay of the Case"
   #:author (authors "Philip Gaskell")
   #:date 1969
   #:location (journal-location "Studies in Bibliography"
                                #:volume "22" #:pages '(125 142))))

(define satchell
  (make-bib
   #:title "Shakespeare's Spelling: A Study of the First Folio Text of Macbeth"
   #:author (authors "Thomas Satchell")
   #:date 1920
   #:location (journal-location "The Times Literary Supplement")
   #:note "The first of the spelling tests, extended by Willoughby and built on by Hinman."))

;; --- the texts -----------------------------------------------------------

(define furness
  (make-bib
   #:title "Much Ado About Nothing"
   #:author (editor (authors "Horace Howard Furness"))
   #:date 1899
   #:location (book-location #:publisher "J. B. Lippincott")))

(define mulcaster
  (make-bib
   #:title "The First Part of the Elementarie which Entreateth Chefelie of the Right Writing of our English Tung"
   #:author (authors "Richard Mulcaster")
   #:date 1582
   #:location (book-location #:publisher "Thomas Vautrollier, London")
   #:note (string-append
           "The General Table gives some eight thousand words in the "
           "spellings he recommends, and the rule that a terminal E "
           "lengthens the vowel before it.")))

(define ise
  (make-bib
   #:title "Internet Shakespeare Editions"
   #:author (authors "Michael Best")
   #:date 1996
   #:url "https://internetshakespeare.uvic.ca/"
   #:note "Begun 1996 and continuing. Source of the old-spelling transcriptions used for calibration."))

(define eebo-tcp
  (make-bib
   #:title "Early English Books Online — Text Creation Partnership, Phase I"
   #:author (authors "Text Creation Partnership")
   #:date 2015
   #:url "https://ora.ox.ac.uk/objects/uuid:ad7da8fc-cd8e-4637-8b7c-99498436dbaa"
   #:note (string-append
           "25,363 texts released to the public domain under the ODC-PDDL. "
           "The 5,287 printed 1580–1640 are the attestation lexicon.")))

(define vard
  (make-bib
   #:title "VARD 2: A Tool for Dealing with Spelling Variation in Historical Corpora"
   #:author (authors "Alistair Baron" "Paul Rayson")
   #:date 2008
   #:location (proceedings-location
               "Postgraduate Conference in Corpus Linguistics, Aston University")
   #:note (string-append
           "Not used directly, but its design settles a problem met here "
           "independently: variant grouping needs a modern wordlist to "
           "anchor it, or `her' becomes a spelling of `here'.")))
