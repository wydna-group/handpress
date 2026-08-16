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

| parameter | in real books | first guess | now |
|---|---|---|---|
| the fount | 21,953 sorts, ~120 lb (Okes) | 60,000 | 31,200 incl. space |
| tilde abbreviations | 1.01 / 1000 words (1600s) | 83 | 1.66 |
| superscript `yᵗ`, `wᶜʰ` | 5.5 per **million** words | 6,600 | ~0 |
| foul case + turned letters | 0.25 / 1000 words | 11.57 | 0.77 made, 0.59 survives |
| word division | 5.1 / 100 lines | 0.0 | 5.3 |
| medial apostrophes (`rul'd`) | 9.58 / 1000 words | 1.17 | 5.37 |
| ampersand | 3.18 / 1000 (1600s) | 35 | 3.02 |
| class spelling habits (`-ie`) | 57% (Blayney) | 82–91% | 57% |
| wrong-fount sorts | a handful a book | 248 | 14 on the Folio |
| gaps a compositor could set | every one | 14% | 95% |
| the printer named in the imprint | 58 of 81 (Blayney App. II) | — | 72% |
| the imprint date spaced (`1 6 0 8.`) | about half | — | 50% |
| binder's faults per gathering | **no source gives a rate** | — | a knob, 0.01 |
| heap order lost at the drying rack | **no source gives a value** | — | a knob, 0.15 |

Every one of these was wrong in the same direction until it was measured.

**AND WHEN A FIGURE IS ORDERS OUT IT IS ALMOST NEVER THE FIGURE.** Four rows
failed their sources in one week and not one was fixed by changing a rate. Ask
these before touching the number:

| ask | the row that taught it |
|---|---|
| Is the **cause** right? | Wrong fount grew with how hard the fount was worked because it was modelled at an empty box. Hornschuch puts it where italic meets roman. 1,942 → 14. |
| Is it the **quantity** the source means? | `miscast` counts copy measured out wrong; Blayney's "page-depth almost entirely consistent" is about the depth it came out at. |
| Is it a **fault** at all? | The close-set comma is what a case short of space metal does. Bowers: "not considered to be misprints". It has no rate. |
| Has the **instrument** been graded? | Foul case sat above its observation to compensate for a diff assumed to undercount. Graded against a known truth it *over*counts by 69%. |

The last is the one only this program can answer, and the reason it exists: a
generator set above an observation to compensate for an instrument is resting on
a claim about that instrument, and here such claims are measurable. Reproduce the
relationship — a second setting made from a first, diffed as Q against F — and
count what the method recovers against what happened.

Two more shapes of the same mistake, both cheap to check:

- **A mechanism with no report line drifts unseen.** Wrong fount was invisible
  because the only figure printed was the whole `'shift` kind, 98% space-metal.
  Splitting it exposed the row the same afternoon. Add the count *before* the
  mechanism.
- **A rate can be right and its label wrong.** Every apparent fix should be
  checked at the stage the source measured: made, mended at proof, or left
  standing in one copy are three different numbers.

## Where the evidence lives

- `sources/` — the six bibliographies as PDFs, gitignored. **Blayney is the
  richest**: his subject is one quarto reconstructed from its type, so nearly
  everything in him is a number. PDF page = book page + 30.
- `corpus/texts/` — 5,287 EEBO-TCP texts. **Not only a wordlist.** It is text,
  and every tilde, ampersand and brevigraph in it is countable;
  `tools/count-scribal.py` does exactly that. A question about *marks* can be
  answered here even though `lexicon.rkt` only reads *spellings*.
- Tables OCR badly. Pull those pages with `d[i].get_text()` and read them by
  eye rather than trusting a grep.
- **Blayney's Appendix II is a corpus, not an appendix.** Ninety-odd books from
  one shop, each with a title-page transcript, a collation and a list of
  ornaments. Every imprint formula and every preliminary arrangement in
  `titlepage.rkt` and `prelims.rkt` was counted out of it. Starts around PDF
  379. The collations alone answer questions no prose passage does: `A2 B-L4`,
  `A4 *4 (−*2:3) B-X4`, `¶4 π A-B6`, `πA8(−A7,8) A-Bb8 Cc1,2[=πA7,8]`.

## The heaps, and Greg

The one place two authorities lock together, and worth knowing before touching
`press.rkt`. **Gaskell gives the mechanism** (pp. 143-4): heaps gathered from
the top in signature order, in reverse of the printing order for a sheet
perfected inner-forme-first and in printing order for outer-first. **Greg gives
the test**: a made-up copy is conflation by construction, so the groupings
should be random — unless the gathering was systematic, in which case they are
prefixes and suffixes of one order and satisfy his consistency condition
(*Calculus of Variants*, p. 12).

Measured: 60/60 consistent at `--heap-disorder 0`, 16/60 at 1. The second is
what the code did before. `variant-groupings` and `greg-consistent?` in
`press.rkt`.

**Do not "fix" a consistency failure by tuning the disorder down.** The failure
is the detector working.

Two cautions from Greg for the analysis work still to come: the **ambiguity of
three texts** (with three witnesses no formal process establishes relationship),
and the **fallacy of constant variation** — that every transcription introduces
about the same number of variants, "quite contrary to experience".

## Reading the copy

`import.rkt` is the door. Markdown+YAML, TEI/TCP, LaTeX, `.docx`, HTML, PDF;
declared divisions reach `prelims.rkt` as `# [dedication] Heading` markers.
**Do not add guessing here.** The heading vocabulary was tried, failed on the
first real book (Aylett 1622 opens with unheaded dedicatory verse), and is now
off by default behind `--guess-prelims`. Where a document declares nothing, the
book gets no preliminary matter — that is the answer, not a gap to fill.

Markup is read with regexes, not a parser, on purpose: TCP is SGML-ish,
exported HTML is whatever the exporter felt like, and a parser that refuses one
upload in twenty is worse than a regex that degrades on all of them.

## The shape of the program

The `.tei.xml` is the record; `tei-html.rkt` builds the facsimile by reading
that file back off disk. There is no second renderer and there must not be.
**Anything absent from the TEI is absent from the page** — that property is
what keeps the encoding honest, and it has already caught four things the file
was quietly missing.

Run the tests with `raco test test-all.rkt` (~10s), not `raco test .` (~3.5
min, because thirteen modules each load the 9.8 MB lexicon in their own
process).

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

### Counting it in the report is necessary and not sufficient

Three mechanisms were added in one session *with* their report rows, and all
three were still wrong on the page — found only because a reader hovered a word
and saw the tooltip call a comma a misreading. There are six places, and a
mechanism is not finished until it is in all of them:

| | what goes wrong without it |
|---|---|
| a row in `deviation-counts`, and the report | the original rule: nothing counts it |
| a pattern in `tools/audit-mechanisms.py` | the one instrument that watches for dead mechanisms cannot see it |
| a branch in `word-deviation` | the tooltip names it as whatever shares its stage |
| a branch in `classify` | it borrows another kind's colour and legend filter |
| an entry in `DEVIATION-KINDS` (`vocabulary.rkt`) | no CSS, no filter rule, no legend text — all three are generated from there |
| a test naming the note it must produce | the table and the tooltip drift apart silently |

**The table and the tooltip must agree about the same word.** `deviation-counts`
told pointing apart from misreading the morning it was built; `word-deviation`
did not, so the report said one thing and the page another. One property, one
decision point — and this module is where that rule is oftenest broken, because
the counting and the naming live thirty lines apart.

And one check no test will make for you. On a rendered page, **count the marked
words whose tooltip opens with a fault other than the one they are coloured by.
It must be nought.** A word carries several notes joined in stage order while the
class is the most significant of them, so a word underlined as want of metal can
open "habit: …" — about forty of two thousand in one book, and exactly what gets
reported as a mislabelled tooltip.

Last: ask whether the new fault **changes a reading**. If it does not, it cannot
be a press variant and must be kept out of that count — mending a risen space or
a wrong-fount sort alters nothing a collation can find, and folding them in
inflates a figure compared against Hinman's, which was got by collating. Two of
the four mechanisms added that session could never have moved the variant count,
by construction, and that was knowable before either was written.

## Traps that have caught us

- **A bug can pass for a finding.** Space-metal was picked and never returned,
  so every line spaced itself with hairs — which looked exactly like a shop
  short of space-metal, a thing that really happened. A *historically
  plausible* symptom is when to check the arithmetic hardest.
- **A comparison must isolate one thing.** Comparing the set form against the
  reading rings every long s and u-for-v as foul case: 3,629 in a book with 16.
  Has happened twice.
- **A test asserting a rare event on one seed is a test of the seed.** Four of
  these have broken this way. Size the sample or assert on the rate.
- **Adding evidence must not subtract evidence.** Giving one compositor his
  measured preference destroyed another's, because the check compared against
  every workman in the table rather than the crew at the frames.
- **A parameter anchored on one example is anchored on that example's end of
  the range.** The fount came from the largest house in London working in
  folio, and made every quarto shop three times too rich.
- **Renames that cross a classification boundary change meaning.** Redefining
  `composed` as the reading made the accident test report 1,048 for 7.
- **A bare zero cannot distinguish *did not happen* from *cannot happen
  here*.** Say which — in the report *and* in the TEI. The binding section
  prints the number of chances and the expectation before the count, for this
  reason.
- **A rule that only fires when something is already there will never fire on
  the first one.** `cast-off` would divide a long paragraph only if the page
  already had something on it, so a two-hundred-line paragraph became one page
  of thirty-eight. It survived for months because real copy has paragraph
  breaks and only a generated dedication is one block.
- **When the sources give an order but no numbers, say so where the numbers
  are.** Gaskell ranks the preliminary signature forms by frequency and gives
  no figures; `PRELIM-SCHEMES` carries weights, and the comment above it says
  the ordering is his and the weights are not.
- **Prefer a rule to a rate.** Whether the Table migrates to the back is
  decided by arithmetic on two make-ups — is there room, and does it save
  leaves — not by a probability. A rate there would have been invented; the
  rule is McKerrow's own account of what East did.

## How the numbers go wrong

The traps above are about mechanisms. These are about the figures, and they have
cost more time than the mechanisms have.

- **Two errors cancelling is this project's characteristic failure.** A
  calibration that agrees with a source can be two mistakes meeting in the
  middle: press variants matched Hinman while the copy-restoration that supplied
  them was the mechanism he says was "seldom if ever used". **Check a
  mechanism's *share* against what the source says its share should be, not only
  its total** — and when fixing a real bug makes a calibration row worse, that
  row was not measuring what its label said.
- **A figure from one run of the standard hard case is a draw.** Press variants
  run 368 to 624 over four seeds of the same book and code; three successive
  proof-rate calibrations were each argued from a single Folio before anyone
  measured that. Every figure belongs in `CALIBRATION.md` with its seeds, its
  spread and the date it was regenerated.
- **Measure the spread on *both* sides before believing a gap.** Three
  discrepancies chased in one session all dissolved: one was a single draw, one
  was a median compared against a single book, one was three events printed to
  two decimals. **Three events is not a rate** — put an interval on any anchor
  counted in single figures.
- **Ask of every measured rate: measured at which stage?** A rate diffed out of
  a printed book counts what *survived* the corrector; the rate a program is set
  to is what the compositor *makes*. Comparing them is comparing two quantities.
- **A single unrepresentative page gives a proportion, never a density.** The one
  proof-corrected Folio leaf carries eight times the book's average corrections;
  a rate taken off its density overshot eightfold, where its *share* by category
  held.
- **A number that shares its name with another number is not a number.** "Crowded"
  meant 570 in one table and 11 in another, in the same report, with neither
  stating its threshold.
- **A convention with no date on it is dated by whoever wrote it down last.** The
  space bodies were Jacobi 1890 in a 1600 fount. When a value arrives as "the
  standard widths", ask *standard when*.
- **One property, one decision point.** Two stages settling the same thing will
  contradict each other and hide it. Five instances so far, most recently the
  counting and the naming of the same fault thirty lines apart in one module.

## How the work goes wrong

- **Read the source before building on a summary of it.** Moxon and Smith sat
  cited-but-unread for a year and one afternoon with them produced six roadmap
  items. Simpson went the same way and held the only proof-corrected page of the
  First Folio. **A source you have cited is not a source you have read** — check
  what has actually been quoted from it before treating it as read.
- **Having the finding is not the same as using it.** The measurement that
  solved forme-order had been committed to the roadmap two entries above the
  three attempts that ignored it. Knowing a rule plainly does not prevent
  breaking it: most of these have been broken by someone who had just written
  them down.
- **A stale compile manufactures failures that read like findings.** A changed
  signature leaves dependents compiled against the old one and their tests are
  *silently skipped* — 164 of them once, with the suite reporting a clean pass.
  Watch the absolute count. Rebuild clean before judging any failure.
- **A test deliberately blind to one thing is blind to a bug in that thing.**
  Hinman's criterion is scored up to reversal, so it could not see that the
  forme order underneath it was inside out.
- **A guard written for the shape of one format is a claim about every format.**
  `(= 2 (length done))` is true of a quarto gathering and of nothing else; it
  looked like a sanity check and silently returned a false at folio.
- **Measure a disagreement's consequence before encoding it.** Blayney and
  Hinman differ on how thin a pair of cases may be worked, and the whole range
  they disagree about produces byte-identical output. Encoding it would have
  made two named shops that behave alike.

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
alternate (they run in long blocks), that setting by formes was normal — "it was
followed occasionally but was certainly not normal" — that type economy was the
motive **for two men sharing a book** (labour scheduling was; he calls shortage
of type a "subsidiary" reason there, *Cambridge University Press* i. 144), and
that the shop worked one book at a time.

**Say which question a motive answers.** That third item stood for a year without
its qualifier and read as though McKenzie thought type shortage unimportant, which
is close to the reverse of his position. On *setting by formes* he is emphatic the
other way: Hinman displaced type shortage in favour of an economic timing ratio
and thereby "starts a bibliographical hare", because "**the constant factor
throughout the Folio is shortage of type because of the method of quiring**"
(*Printers of the Mind*, p. 37). Shared work and setting by formes are two
questions, and he gives them opposite answers.

Which the program has since measured, and he is right: type shortage is the whole
mechanism by which concurrent production destroys Hinman's forme-order criterion.
See §8 in FINDINGS.

When a source is offered, mine it before building.

## What the program must keep saying

McKenzie's objection is correct and inescapable: every percentage the analysis
produces is the analyser inverting the generator, and both were written from
the same account of how a printing house behaved. `MCKENZIE` is appended to
every report. Do not quietly drop it, and do not try to argue with it — build
the concurrency experiment instead, which makes the failure visible.
