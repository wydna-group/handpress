---
name: handpress
description: Working on the handpress hand-press printing simulator — the discipline the project runs on, what has already been checked against real books, and the traps that have caught us before. Use when changing simulation parameters, adding a device, or interpreting a report.
---

# handpress

A simulation of hand-press composition that then runs the New Bibliography
back over its own output and grades the result. The simulator knows the truth;
a real book never does. That asymmetry is the whole value, and every design
decision should protect it.

Read `README.md` and `ROADMAP.md` first — they are current and detailed. This
file is the working discipline, which they do not carry.

## The one rule

**Every parameter checked against a real book has been wrong, most by an order
of magnitude, and always in the same direction: towards a printing house more
picturesque than the real one.** Assume the next one is too.

| device | in real books | first guess | now |
|---|---|---|---|
| scribal contractions (`ẽ`, `yᵉ`) | 0 in F1 | 83 | 0, behind a flag |
| foul case + turned letters | 0.25 / 1000 words | 11.57 | 1.12 |
| word division | 5.1 / 100 lines | 0.0 | 4.9 |
| medial apostrophes (`rul'd`) | 9.58 / 1000 words | 1.17 | 5.37 |
| ampersand | 14 in five scenes | 35 | 26 (still ~2× over, left wrong) |

The ampersand is deliberately not fitted. Where a figure is off, leave it off
and say so; closing the gap by tuning would make the number worthless.

## Before adding any mechanism

**Decide what will count it in the report.** Four mechanisms have been silently
dead in this codebase, each invisible because nothing exercised it and no
report counted it:

- `catches-misreading` — misreadings carried no page or line, so the press loop
  never saw them
- the catchword bracketing in `description.rkt` — unreachable while catchwords
  were copied from the next page
- the omission branch in `set-page` — unreachable while casting off erred only
  short
- the crowding devices — same cause

A fifth, turn-over, was wrongly added to that list. It fires on verse and reads
zero on prose because only a verse line can be turned over. Which gives the
corollary: **a bare zero cannot distinguish *did not happen* from *could not
happen here*.** Say which.

## Traps that have caught us

- **`check-true` is strict.** `member` and `memv` return sublists, not `#t`.
  Use `check-not-false`. This has cost time four separate times.
- **A comma in Scribble source is `unquote`.** Inside a `tabular` row, wrap it:
  `@elem{@tt{--from}, @tt{--to}}`.
- **Do not assert RNG outcomes in tests.** Assert the property — that a 6 or 9
  was turned, not which one.
- **PowerShell mangles inline Python and here-strings.** Write the script to a
  file, or use `git commit -F`.
- **`raco make` after touching a required module**, or you will test stale
  bytecode and believe it.

## The lexicon

Spelling devices **select, they do not invent**. `lexicon.rkt` says which forms
exist; a rule may only choose among them. Before this, rules produced `theere`
and `manne` freely.

Two tests, and the second is the one that matters:

- `attested?` — does the corpus contain it at all
- `plausible?` — does it hold a real share of its word's occurrences

`theere` occurs 17 times against 145,517 for `here`. Attested, and not a
spelling anybody chose. Gate on `plausible?`.

The variant grouping needs a modern wordlist to anchor it, or `her` becomes a
spelling of `here` — the reduction that correctly joins `heere` to `here` joins
`here` to `her` by identical steps. One known residual error: `runne` is
assigned to `rune` rather than `run`, and no rule about letters can separate
that case from `heere`/`here`. Do not try to fix it by rule; measure the error
rate on a hand-checked sample.

## Checking output

Verify rendered HTML in the headless browser rather than trusting it. Doing so
has found a fabrication bug in the corrector, a word-collision problem I had
overstated more than tenfold, and pages ending two-thirds down — sixteen leaves
of white paper in one book.

Measure, do not eyeball. `0.08%` of word pairs touch; from one screenshot I
called it systematic.

## Sources beat first principles

The corrections have come almost entirely from books, not from thinking harder.
McKenzie's Cambridge Vouchers alone overturned four assumptions: that stints
alternate (they run in long blocks), that setting by formes was normal (it was
not), that type economy was the motive (labour scheduling may have been), and
that the shop worked one book at a time.

When a source is offered, mine it before building.

## What the program must keep saying

McKenzie's objection is correct and inescapable: every percentage the analysis
produces is the analyser inverting the generator, and both were written from
the same account of how a printing house behaved. `MCKENZIE` is appended to
every report. Do not quietly drop it, and do not try to argue with it — build
the concurrency experiment instead, which makes the failure visible.
