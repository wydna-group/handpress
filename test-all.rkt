#lang racket/base
;;; Every test in one process.
;;;
;;;     raco test test-all.rkt
;;;
;;; `raco test .' runs each file in a fresh process, and thirteen of the
;;; modules here transitively require `lexicon.rkt', whose 9.8 MB of EEBO
;;; spellings take about 4.2 seconds to read and index. That cost is paid once
;;; per process, so the suite spent most of three minutes reading the same file
;;; over and over and a few seconds running tests. Measured:
;;;
;;;     raco test .            218 s
;;;     raco test -j 8 .       164 s
;;;     raco test test-all.rkt  10 s
;;;
;;; Requiring the test submodules into one module loads the lexicon once.
;;; Nothing about the tests changes -- they are the same submodules, run the
;;; same way, and the count comes out the same.
;;;
;;; The requires live in a `test' submodule rather than at module level so that
;;; `raco test' drives them. Required at module level and run with plain
;;; `racket', a failing check prints its report and the process still exits 0,
;;; which is a suite that cannot fail.
;;;
;;; `raco test .' remains what CI should run. A process per module is the only
;;; thing that catches a module which loads solely because something else
;;; happened to load its dependency first, and it isolates a crash to one file.
;;; This is the one for the edit loop.
;;;
;;; The list is written out rather than globbed on purpose: a module with no
;;; tests is a fact worth having to notice. rng.rkt and info.rkt have none.

(module+ test
  (require (submod "metrics.rkt" test)
           (submod "paper.rkt" test)
           (submod "imposition.rkt" test)
           (submod "pagination.rkt" test)
           (submod "typecase.rkt" test)
           (submod "copytext.rkt" test)
           (submod "import.rkt" test)
           (submod "prelims.rkt" test)
           (submod "titlepage.rkt" test)
           (submod "binding.rkt" test)
           (submod "cancels.rkt" test)
           (submod "corrector.rkt" test)
           (submod "lexicon.rkt" test)
           (submod "orthography.rkt" test)
           (submod "compositor.rkt" test)
           (submod "book.rkt" test)
           (submod "press.rkt" test)
           (submod "analysis.rkt" test)
           (submod "deviation.rkt" test)
           (submod "description.rkt" test)
           (submod "reconstruct.rkt" test)
           (submod "render.rkt" test)
           (submod "tei.rkt" test)
           (submod "validate.rkt" test)
           (submod "main.rkt" test)))
