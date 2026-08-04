# handpress

A simulation of hand-press composition, and of the New Bibliography run back
over the result.

Feed it a copy-text. It casts the copy off into pages, sets it in type as a
named compositor with his own spelling habits, justifies each line by
Moxon's rules, imposes the pages in formes, prints, corrects at press, and
distributes the type back into the case. Then it analyses its own output the
way a bibliographer would — compositor attribution by spelling test, skeleton
formes recovered from damaged running titles, casting-off recovered from
crowded and gaping pages — and tells you how much of what actually happened it
managed to recover.

That last part is the point. The simulator knows the truth, so the analysis can
be graded. It usually does worse than the literature implies.

```sh
racket main.rkt --format folio6 --compositors A,B --html -o out samples/hamlet.txt
```

## Contents

- [What it produces](#what-it-produces)
- [Installing](#installing)
- [Command line](#command-line)
- [What is modelled](#what-is-modelled)
- [Calibration](#calibration)
- [Running it backwards](#running-it-backwards)
- [What it does not do](#what-it-does-not-do)
- [Sources](#sources)

## What it produces

Every run writes into the output directory:

| file | what it is |
|---|---|
| `NAME.facsimile.txt` | the type-facsimile: pages, signatures, catchwords, running titles |
| `NAME.report.txt` | the bibliographical description and the analysis |
| `NAME.html` | an HTML facsimile built directly from the type (`--html`) |
| `NAME.tei.xml` | a TEI P5 encoding of the same setting (`--tei`) |
| `NAME.tei.html` | the TEI transformed to HTML by XSLT (`--xslt`) |

The report opens with a Bowers-style description — collation formula, format,
the press variants sorted by forme and state — and goes on to the analysis:
what the spelling tests say about who set which page, what the running titles
say about the skeletons, where the casting off went wrong, how the case fared.

## Installing

Requires [Racket](https://racket-lang.org/) 8.0 or later. Nothing else.

```sh
git clone https://github.com/USER/handpress.git
cd handpress
raco pkg install --link .
raco test *.rkt
```

`raco pkg install --link` registers the collection so the modules can be
required as `handpress/compositor` and so the Scribble docs build into the
local documentation index. You can skip it and just run `main.rkt` in place.

Build the manual with:

```sh
raco scribble --html --dest doc scribblings/handpress.scrbl
```

The XSLT step (`--xslt`) shells out to a transform driver in `tools/`. On
Windows it uses the .NET `XslCompiledTransform`, which is XSLT 1.0 — the
stylesheet in `xslt/tei-to-html.xsl` is written to that limit and groups by
the sibling axis rather than with `xsl:for-each-group`.

## Command line

Flags come **before** the input file, as Racket's `command-line` requires.

### The book

| flag | effect |
|---|---|
| `-o`, `--out` | directory for the output files |
| `--format` | `folio`, `folio6`, `quarto`, `octavo` |
| `--kind` | `auto`, `verse`, `prose`, `drama` — how the copy is parsed |
| `--title` | running title |
| `--edition` | sheets printed; the Cambridge accounts show 400–820 |
| `--copies` | how many made-up copies to collate for press variants |

### The workmen

| flag | effect |
|---|---|
| `--compositors` | which men are at the frames, e.g. `A,B` or `OkesB,OkesC` |
| `--order` | `formes` or `seriatim` |
| `--cast-off` | accuracy of the casting off, 0–1 |
| `--no-copy-preparation` | the corrector does not mark up the copy first |

### The material

| flag | effect |
|---|---|
| `--case-scale` | size of the fount; below 1.0 the case runs short — try 0.18 |
| `--fount` | condition of the type: `new`, `used`, `worn`, `foul` |
| `--skeletons` | how many skeleton formes are in use |
| `--formes-standing` | formes of type standing before distribution |

### At press

| flag | effect |
|---|---|
| `--first-proof` | chance of a proof pulled *before* the run begins |
| `--seed` | the whole run is deterministic in this |

### Output

| flag | effect |
|---|---|
| `--html` | HTML facsimile built straight from the type |
| `--tei` | TEI P5 encoding |
| `--xslt` | write the TEI and transform it to HTML |
| `--layout` | `opening` (verso \| recto, as bound) or `leaf` |
| `--witness` | which made-up copy the XSLT should show |
| `--numbers` | number every fifth line |
| `--no-long-s` | set short `s` throughout |
| `--modern-uv` | keep modern u/v and i/j |
| `--pages`, `--quiet` | how much to print to the terminal |

## What is modelled

### Casting off

The copy is measured out into pages before setting, so that a compositor can
begin at page 5 without having set pages 1 to 4. When the measurement is wrong
the error has to be absorbed: the page is crowded, or spun out with white, or —
at the limit — a line of copy is dropped. Verse casts off almost exactly and
prose does not (Gaskell, p. 41), so the strain falls where the prose is.

### Imposition

The pages of a forme are not consecutive. A folio in sixes is three sheets
quired one within another, so pages **1 and 12** lie side by side on the outer
forme of the first sheet, 2 and 11 on its inner:

```text
sheet 1   outer (1 12)   inner (2 11)
sheet 2   outer (3 10)   inner (4  9)
sheet 3   outer (5  8)   inner (6  7)
```

Nothing can be printed until both pages of a forme stand in type. This is why
the order of setting matters as much as the order of imposition, and it has a
price in metal that the program now counts. Setting the same play both ways:

| | by formes | seriatim |
|---|---|---|
| most type standing at once | 16,878 sorts | 27,746 sorts |
| pages standing at the peak | 6 | 11 |
| cases at their emptiest | 29% out | 46% out |

A house setting straight through the copy cannot perfect the first sheet until
page 12 is set, so eleven pages stand locked up and the case runs to 46% empty.
Setting by formes from the middle of the gathering outward (5, 8 / 6, 7 /
3, 10 …) lets each sheet go to press and come back to the boxes before the next
is begun.

That is a calculation, not a motive. McKenzie searched the Cambridge Vouchers
for the practice and found setting by formes "was followed occasionally but was
certainly *not* normal" (i. 115); and where work *was* shared, the reason was
likely "not to make more economical use of a limited supply of type but to find
work for a waiting compositor" (i. 116) — labour scheduling, not metal. The
table says what the practice would have saved a house that followed it, not why
any house did. Hinman's evidence that the Folio *was* set by formes rests on
type recurrence and stands separately.

### Justification

Spaces are quantised — em, en, thick, middle, thin, hair — and a line is
justified by choosing among them, not by stretching continuously. When no
combination fits, the compositor reaches for something else: a different
spelling, an abbreviation, a turned-over word, a divided word. The order in
which he reaches is a ranked table of violence to the copy.

This is where habit and necessity become impossible to separate, and it is the
caveat Hinman states about his own method (i. 186–7): a spelling forced by a
tight measure is not evidence of the man who set it.

### Spelling habit

Compositors are profiles with per-word preferences, drawn from published
attribution work. Jaggard's A prefers `doe`, `goe`, `here`; his B prefers `do`,
`go`, `heere` (Hinman i. 182–3). Okes's B sets `-our` where his C sets `-or`,
and C "refused five opportunities to use an apostrophe" his fellow would have
taken (Blayney i. 159–60).

Habit strength is per-word rather than a single scalar, because a single scalar
cannot hold both of Hinman's figures at once: in quire L, A sets `doe`/`goe`
81% of the time but `here` only 50%.

### The lay of the case

The English divided lay, with the upper and lower cases as separate grids so
that no adjacency crosses the division. Reaching distance follows Moxon
(i. 21) — a sort in a far box is likelier to be picked wrong. From this comes
foul case (a letter from an adjoining box), turned letters (`n` for `u`),
wrong-fount sorts, and shortage: when the `w` box is empty, `VV`.

Individual types are tracked as pieces with their own damage, so a battered
sort can recur across formes and date them relative to one another. That is
Hinman's method, and the simulator can be graded on it.

### The corrector, and at press

The copy is marked up for house style before it reaches the compositor —
Blayney's point, and Halliwell-Phillipps's inference about the annotated
quarto that F1 *Much Ado* was set from. At press, proofs are pulled and
corrections made without stopping the run, so sheets of both states go into
the heaps and the made-up copies disagree with one another. Collating several
copies recovers the variants, forme by forme.

## Calibration

Every parameter that has been checked against a real book was wrong when first
guessed, usually by an order of magnitude. The record:

| device | in the real books | first guess | now |
|---|---|---|---|
| scribal contractions (`ẽ`, `yᵉ`) | 0 in F1 | 83 | 0, behind a flag |
| foul case + turned letters | 0.25 / 1000 words | 11.57 | 1.12 |
| word division | 5.1 / 100 lines | 0.0 | 5.3 |
| medial apostrophes (`rul'd`) | 9.58 / 1000 words | 1.17 | 5.37 |
| ampersand | 14 in five scenes | 35 | 26 |

The measurements come from diffing the 1600 quarto of *Much Ado About Nothing*
against the 1623 Folio text set from it — 11,990 words, a real copy-text and a
real setting from it, which is the only kind of evidence that can settle any of
this.

The scribal contractions are the instructive failure. The program used to
produce `implēētatiō` for *implementation*, stacking tilde contractions on one
word, and label the result a space-saving. It was neither: the Folio has none
of them, and some of the substituted forms were *longer* than what they
replaced. The genuine English space-saver was sitting in the same data
unnoticed — the Folio has eight times the quarto's medial apostrophes, turning
some thirty `-ed` endings into `-'d`.

Forward test, Q1600 → F1623, on the spelling that attribution work relies on:

| | actual F1 | simulated |
|---|---|---|
| `here` / `heere` | 52% | 51% |
| `do` / `doe` | 61% | 80% |

The `do`/`doe` overshoot is explained: the real scenes were set by more than
one man, and the simulation ran one man's habit across all of them.

## Running it backwards

`reconstruct.rkt` takes a printed text and tries to recover the copy behind it
— the editor's problem. It reports a word-by-word confusion matrix rather than
a score, because the interesting result is *where* it fails.

The best blanket rule ceilings at 70–76%. There is no per-word evidence to do
better, which is the honest form of Greg's distinction between substantives and
accidentals: he arrived at it by counting, and so does this.

## What it does not do

- **Concurrent production.** McKenzie's central finding is that a shop worked
  on several books at once, and this models one book at a time. The report
  says so, at length, wherever it draws a conclusion that concurrency would
  undermine.
- **Per-compositor cases.** Hinman distinguishes cases x, y and z; here all
  the men draw from one pair.
- **Forme order from type recurrence.** The pieces are tracked and the
  recurrences recorded, but nothing yet reconstructs the order of printing
  from them.

The analysis is circular in the way McKenzie showed all such analysis to be:
it recovers the model's own assumptions. The program says this itself, in the
report, every time.

## Sources

- W. W. Greg, *The Shakespeare First Folio* (1955)
- Charlton Hinman, *The Printing and Proof-Reading of the First Folio of
  Shakespeare*, 2 vols (1963) — the compositor spellings and the justification
  caveat
- Joseph Moxon, *Mechanick Exercises on the Whole Art of Printing* (1683) —
  the lay of the case, the spaces, the reaching
- Philip Gaskell, *A New Introduction to Bibliography* (1972) — the bill of
  letter, casting off, formats
- Fredson Bowers, *Principles of Bibliographical Description* (1949) — the
  form of the description
- Peter W. M. Blayney, *The Texts of King Lear and their Origins* (1982) —
  Okes's compositors, copy preparation
- D. F. McKenzie, "Printers of the Mind" (1969) — the objection
- R. B. McKerrow, *An Introduction to Bibliography for Literary Students*
  (1927) — imposition
- H. H. Furness, ed., *Much Ado About Nothing*, New Variorum (1899) — the
  collation used for calibration

## Licence

MIT.
