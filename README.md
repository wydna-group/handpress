# handpress

A simulation of hand-press composition, and of the New Bibliography run back
over the result.

Feed it a copy-text. It casts the copy off into pages, sets it in type as a
named compositor with his own spelling habits, justifies each line by Moxon's
rules, imposes the pages in formes, prints, corrects at press, and distributes
the type back into the case. Then it analyses its own output the way a
bibliographer would — compositor attribution by spelling test, skeleton formes
recovered from damaged running titles, casting-off recovered from crowded and
gaping pages — and tells you how much of what actually happened it recovered.

That last part is the point. The simulator knows the truth, so the analysis can
be graded. It usually does worse than the literature implies.

```sh
racket main.rkt --format folio6 --compositors A,B --html -o out samples/hamlet.txt
```

## Contents

- [What it produces](#what-it-produces) · [Quick start](#quick-start) · [Command line](#command-line)
- [What is modelled](#what-is-modelled) — [the type](#the-type-as-physical-objects), [the paper](#the-paper-format-is-not-size), [casting off](#casting-off), [imposition](#imposition), [justification](#justification), [stints](#stints), [the case](#the-lay-of-the-case)
- [Reading the copy](#reading-the-copy) · [The preliminaries](#the-preliminaries) · [The last sheet](#the-last-sheet) · [Cancels](#cancels)
- [The heaps](#the-heaps-and-the-copies-gathered-from-them) · [Forme order](#the-order-of-formes-from-the-types) · [The perfecting order](#the-perfecting-order-inferred) · [Binding](#gathering-folding-and-binding) · [The lexicon](#the-lexicon)
- [Calibration](#calibration) · [The First Folio](#the-first-folio) · [Running it backwards](#running-it-backwards)
- [What it does not do](#what-it-does-not-do) · [Sources](#sources) · [Roadmap](ROADMAP.md)

**[ROADMAP.md](ROADMAP.md) is the other half of this document.** This file says
what the program does and where it currently stands; the roadmap says what is
wrong with it, what is unbuilt, and what each correction cost to find. Where a
section here ends with a pointer into the roadmap, that is a live uncertainty and
not a footnote.

## What it produces

Every run writes into the output directory:

| file | what it is |
|---|---|
| `NAME.facsimile.txt` | the type-facsimile: pages, signatures, catchwords, running titles |
| `NAME.report.txt` | the bibliographical description and the analysis |
| `NAME.tei.xml` | a TEI P5 encoding of the setting — **the record** (`--tei`) |
| `NAME.html` | the type-facsimile, built by reading that TEI back (`--html`) |
| `NAME.tei.html` | a plain reading text, via XSLT (`--xslt`) |
| `NAME.copy-a.txt` … | one file per made-up copy, for collating |

The report opens with a Bowers-style description — the paper and the leaf it
makes, the collation formula, the type page, the press variants sorted by forme
and state — and goes on to the analysis: what the spelling tests say about who
set which page, what the running titles say about the skeletons, where the
casting off went wrong, how the case fared, and which rules are marked.

**The rules are objects, not lines on a page.** A rule is type-high and prints,
so it wears and can be followed like any other piece. Five box rules frame a
page — one below the head-line as well as one above it, the head-line standing
inside the frame — and ten make a forme; their *arrangement* is re-drawn every
few formes and defines a group of formes printed together. The centre rule
between the columns is not part of that set: it belongs to the type page and
goes to the case with the type beside it, so its recurrence traces the shop's
stock rather than the printing sequence. All of it is Hinman i. 51, 130 and 148.
Each rule is written to the TEI with its id, its length and its damage, and the
facsimile draws the rules the file records.

The HTML facsimile has four views. **The book** is the leaves themselves, with a
map of the whole run above them and a legend below that filters the apparatus by
kind of departure. **The make-up** draws each gathering as its sheet folds, the
conjugate pairs arced together, so a cancel shows you which leaf comes loose when
another is cut out. **The evidence** is the counts. **The copies** is how each
made-up copy was sewn and what the binder got wrong.

## Quick start

### 1. Install Racket

The only thing you need. Download it from
**[racket-lang.org/download](https://racket-lang.org/download/)** and run the
installer — version 8.0 or later, default options. On Windows, let it add Racket
to your PATH when asked. On Debian or Ubuntu, `sudo apt install racket`.

Check it worked by opening a **new** terminal — a new one, so it picks up the
changed PATH — and typing `racket --version`.

<details>
<summary>If that says "command not found"</summary>

Racket is installed but your PATH does not know where it is.

- **Windows** — search the Start menu for "Edit the system environment
  variables" → *Environment Variables* → select **Path** → *Edit* → *New*, and
  add the `bin` folder inside where Racket installed itself, usually
  `C:\Program Files\Racket`. Open a new terminal and try again.
- **macOS** — run this once, changing `v8.12` to the version you installed, then
  open a new Terminal:
  ```sh
  echo 'export PATH="/Applications/Racket v8.12/bin:$PATH"' >> ~/.zshrc
  ```
</details>

### 2. Get handpress

```sh
git clone https://github.com/wydna-group/handpress.git
cd handpress
```

Without git, go to
[github.com/wydna-group/handpress](https://github.com/wydna-group/handpress),
click the green **Code** button, choose **Download ZIP**, and unzip it. Then open
a terminal in that folder. (On Windows: open the folder, click in the address
bar, type `cmd`, press Enter.)

### 3. Run it

```sh
racket main.rkt --html --out out samples/hamlet.txt
```

That sets the sample through a simulated 1600s printing house and writes into a
new `out` folder. **Open `out/hamlet.html` in your browser** — that is the
type-facsimile, with every word where the simulated compositor computed it should
go. `out/hamlet.report.txt` is the analysis, which is the point of the exercise.

Nothing is installed on your system and nothing is written outside the folder you
chose.

### 4. Run it on your own book

handpress reads what your document already says about itself, so give it the
richest format you have — see [Reading the copy](#reading-the-copy).

```sh
racket main.rkt --html --out out --format quarto --year 1610 mybook.docx
```

Plain text works perfectly well; you simply get a book with no preliminary
matter, because a text file cannot say that a paragraph is a dedication. A file
saved under the wrong extension is sniffed, so a TEI document named `.txt` is
still read as TEI.

Worked examples are under **[`examples/`](examples/README.md)**: one 1600 book put
through all seven input formats, so you can see what each buys, and one 1614 book
set twice sixty years apart, so you can see what the shop contributes.

### Optional

```sh
raco pkg install --link .     # require modules as handpress/compositor
raco test test-all.rkt        # 1,192 checks, about fifteen seconds
raco scribble --html --dest doc scribblings/handpress.scrbl
```

`raco test .` runs the same checks in about three and a half minutes, because it
gives each module a fresh process and thirteen of them load the 9.8 MB lexicon on
the way up. Use `test-all.rkt` while working; use `raco test .` in CI, where the
isolation is worth the wait.

### On the TEI

The `.tei.xml` is the record, and everything else is derived from it — including
the facsimile, which is built by reading that file back off disk rather than by
rendering the book a second time. That is deliberate: it is what keeps the
encoding honest, since **anything the TEI does not carry cannot appear on the
page**. It has caught several things the file was quietly missing, most recently
the size of a leaf.

`--xslt` additionally runs `xslt/tei-to-html.xsl` to give a plain reading text for
anyone consuming the file without Racket. It is not a second facsimile and does
not try to be. The step shells out to a transform driver in `tools/`; on Windows
it uses .NET's `XslCompiledTransform`, which is XSLT 1.0, and the stylesheet is
written to that limit.

## Command line

Flags come **before** the input file, as Racket's `command-line` requires.

### The book

| flag | effect |
|---|---|
| `-o`, `--out` | directory for the output files |
| `--format` | `folio`, `folio6`, `quarto`, `octavo` — how often the sheet is folded |
| `--paper` | the sheet itself: `foolscap`, `pot`, `crown`, `demy`, `royal` |
| `--kind` | `auto`, `verse`, `prose`, `drama` — how the copy is parsed |
| `--title` | running title |
| `--book-title` | title as set on the title-page, which is not the running title |
| `--author` | author, as named on the title-page |
| `--printer`, `--publisher` | the names in the imprint |
| `--no-titlepage` | do not generate one |
| `--guess-prelims` | **experimental**: guess preliminary matter from a vocabulary of period headings where the document declares none |
| `--no-contents` | do not build a table of contents from the document's own headings |
| `--jaggard-alphabet` | sign from Jaggard's twenty letters, omitting X, Y and Z |
| `--prelim-signatures` | how the preliminaries are signed — see below |
| `--binding-error` | faults per gathering per copy at the folding — **no source gives a rate** |
| `--cancels` | leaves cancelled for reasons outside the simulation |
| `--cancel-rate` | chance an error surviving the proof is thought worth cutting a leaf out for |
| `--imprint-change` | re-issue with the bookseller's name altered: a cancel title |
| `--heap-disorder` | how often a handful of doublings is laid back out of order at the drying rack, 0–1 — Moxon gives the grain, **no source gives the rate** |
| `--edition` | sheets printed; the Cambridge accounts show 400–820 |
| `--copies` | how many made-up copies to collate for press variants |

### The workmen

| flag | effect |
|---|---|
| `--compositors` | which men are at the frames, e.g. `A,B` or `OkesB,OkesC` |
| `--order` | `formes` or `seriatim` |
| `--cast-off` | accuracy of the casting off, 0–1 — **the manuals describe two regimes, not one dial: [ROADMAP §5](ROADMAP.md)** |
| `--no-copy-preparation` | the corrector does not mark up the copy first |
| `--stint-sheets` | sheets a man sets before the frame changes hands (default: by shop size) |

### The material

| flag | effect |
|---|---|
| `--case-scale` | size of the fount; below 1.0 the case runs short — try 0.18 |
| `--fount` | condition of the type: `new`, `used`, `worn`, `foul` |
| `--skeletons` | how many skeleton formes are in use |
| `--formes-standing` | formes of type standing before distribution |
| `--paging-error` | how freely the paging goes wrong, 0–1 (default 0.04) |

### The analysis

Nothing here changes what was printed. It changes what a bibliographer reading
the result is able to make out, which is a different thing and was not modelled
at all until recently: the analysis used to be handed every distinctive piece in
the fount, perfectly labelled.

| flag | effect |
|---|---|
| `--copy-texts` | how many made-up copies to write out as plain text; 0 for none. **Every copy is collated regardless** — this only limits how many are dumped to disk, and at 1,200 copies of a Folio that is six gigabytes of near-identical text. The apparatus in the TEI holds them all. |
| `--witness` | which made-up copy the facsimile and the XSLT reading text show, e.g. `copya`. It must be *a* copy: the facsimile used to take the first reading of every apparatus, which is the uncorrected state of every forme at once — a book no one owns. Measured on 24 copies with 10 split variants, the closest real copy agreed with that page in 6 of the 10. |
| `--discrimination` | the finest difference between two injuries an investigator can reliably see, 0–1. Anchored on Hinman's Folio and therefore a **ceiling** on what anyone saw, not a typical eye. Raise it for a worse investigator. |

### At press, and output

| flag | effect |
|---|---|
| `--first-proof` | chance of a proof pulled *before* the run begins |
| `--proof-rate` | chance a forme is proofed at all — 0.224, from Hinman's count of corrected formes in the Folio |
| `--seed` | the whole run is deterministic in this |
| `--font` | family the facsimile is drawn in, e.g. `Junicode` |
| `--font-file` | a fount to embed beside the page — `.woff2`, `.ttf`, `.otf` |
| `--fit` | set width of that face against the body; re-derive it when the face changes |
| `--html` | HTML facsimile built from the TEI |
| `--tei` | TEI P5 encoding |
| `--xslt` | write the TEI and transform it to HTML |
| `--layout` | `opening` (verso \| recto, as bound) or `leaf` |
| `--numbers` | number every fifth line |
| `--no-long-s` | set short `s` throughout |
| `--modern-uv` | keep modern u/v and i/j |
| `--modern-spelling` | show the same setting in modern spelling |
| `--year` | the date, which governs the scribal marks — they have a slope |
| `--pages` | draw only the first N pages — terminal render and HTML facsimile alike. The book is still printed and collated whole, and the page says so. |
| `--quiet` | how much to print to the terminal |

## What is modelled

### The type as physical objects

Every sort is a piece of metal drawn from a box that can empty. That includes the
things it is easy to forget are type at all:

- **Space-metal.** A gap is a body a shade lower than the face so that it takes no
  ink. **16% of everything set is white**, and the thick space is about as common
  in a fount as the letter `e` — which Smith's bill confirms outright, 12,000
  thick spaces against 13,000 `e`. Justification is therefore *quantised*: a
  compositor can only set combinations of the bodies he has, so a line fills the
  measure to within less than the finest space rather than exactly.

  **How many bodies he has was an open question, and it is now Moxon's four.**
  The program carried six — em, en, thick 1/3, middle 1/4, thin 1/5, hair 1/8 —
  which Davis & Carter date to Jacobi in 1890, against a period of 1580–1640. It
  now carries Moxon's (1683): "Spaces Thick and Thin, n Quadrats, m Quadrats and
  Quadrats", the thin "the seventh part of the Body" and the thick a quarter.

  Two quantities can be measured against real books, and the change moves both
  toward the measurement — the second of them one it was not chosen on:

  | | Jacobi | Moxon | measured |
  |---|---|---|---|
  | internal space | 13.76% | 11.57% | ~9% (Blayney, off *Lear*) |
  | divisions / 100 lines | 4.94 | 5.88 | 6.41 (Norton, prose plays) |

  The division rate is the independent corroboration: the ladder was picked on
  Blayney's ruler and Moxon's prose, and it then closed 60% of a gap in a
  statistic counted off 790 plates. Both still fall short, in the same direction
  and by about the same amount — which is the residual **[ROADMAP §5](ROADMAP.md)**
  now has a target for: lines ending about 0.6 em short, which is the crowding
  devices' business and not the ladder's. `tools/measure-spacing.rkt` recomputes
  both figures; neither is tuned to.
- **Ligatures**, including `ſt`, `ſh`, `ſi` and `ſſ`, which in an English fount
  outnumbered `ﬀ`, `ﬁ` and `ﬂ` together. They print as their two letters; what
  differs is which box emptied.
- **The ladder of shifts** when a box runs dry, in the order Blayney watched a
  compositor work down it: set `VV` for `W`; rob a sort from the margin of a page
  already standing; distribute a forme early; set a sort **face down** and fill the
  space at proof; send to the founder for more.

### The paper: format is not size

**Format is how often the sheet was folded. Size is how big the sheet was.**
Neither gives a leaf a dimension on its own, and "quarto" says nothing whatever
about how big the book is.

A fold halves whichever dimension is currently longer, and the leaf is the result
stood upright. That one rule is the whole relationship, and it reproduces
Gaskell's Key III (p. 86) exactly. From a foolscap sheet of 420 × 320 mm:

| format | folds | uncut leaf | tall : wide |
|---|---|---|---|
| folio | 1 | 320 × 210 mm | 1.52 |
| quarto | 2 | 210 × 160 mm | 1.31 |
| octavo | 3 | 160 × 105 mm | 1.52 |

The proportion **alternates** rather than settling. A folio and an octavo are
nearly the same shape and nothing like the same size; only the quarto is squat.
Foolscap is the default because Gaskell (p. 68) has the sixteenth century's
ordinary printing paper in that range, growing to demy by the eighteenth.

The type page is placed on the leaf and the margins are what is left, split
inner : head : outer : tail. That proportion (2:3:4:6) is a design convention and
not a measurement — it is the one number here Gaskell does not supply, and it is a
parameter for that reason. The description reports the sheet, the leaf, the type
page and all four margins, and says so outright if the type page will not fit the
paper at all. (It may not fit *well*: [ROADMAP §9](ROADMAP.md).)

The facsimile draws the leaf at that size rather than inventing one: one
millimetre is a fixed number of pixels, and the type, the leaf and the margins all
scale together. A verso's spine is on its right, so the narrow margin changes
sides and the two pages of an opening lean towards each other.

### The fount

The default stack is Times-like, because an old-face roman is narrow and most
modern screen serifs are not. That is an approximation, and the facsimile says so:
the *positions* are the model's and the *glyphs* are the font's, and `--fit` is
the seam between them. Every word sits at an offset the simulation computed, in
`--grid` pixels, while the glyphs are drawn at `--grid × --fit` — deliberately
different units, so a face wider or narrower than the modelled widths can be
reconciled without moving the words.

**The width table has one external check and passes it.** Smith gives the
aggregate: a 24-letter roman lower-case alphabet "takes up eleven m's" (p. 158).
`metrics.rkt`, a–z less j and u, sums to **10.95 em** — 0.5% off. What it still
lacks is an italic table; Moxon and Smith put italic at 0.90 and 0.864 of roman
respectively, and the program sets italic at roman widths.

`--font` names a family, `--font-file` embeds one beside the page so the output
stays self-contained, and `--fit` retunes the seam. **Re-derive `--fit` whenever
the face changes**; leaving it at 1.00 under a wider face is how words come to
collide.

[Junicode](https://junicode.sourceforge.io/) is the fount to use. It is under the
SIL Open Font License, its roman derives from the seventeenth-century Oxford
types, and — checked rather than assumed — it carries every character this program
sets: long s, `ﬀﬁﬂﬃﬄ` and `ſt`, the macron vowels, and the superior letters of
`yᵉ` and `wᶜʰ`. It is not bundled, because a megabyte of fount does not belong in
everyone's install:

```sh
racket main.rkt --html --font Junicode --font-file JunicodeVF-Roman.woff2 book.md
```

Measured on a 24-leaf quarto, Junicode at `--fit 1.00` leaves 4 touching word
pairs in 8,636 — 0.046%, against the 0.08% the stylesheet records for Times. It
needs no retuning.

The same comparison on a two-column folio — *King Lear*, 37 leaves, 27,689 words —
says the same thing more sharply. **Words drawn past the measure: 8 under Junicode
against 49 under Times.** Junicode draws 4.3% narrower than the width table, and
that is left alone rather than tuned out with `--fit`: one em of the face is meant
to be one em of the type body, which it is. It does not accumulate along a line
either, because the word positions are the compositor's and only the glyphs are
the font's — a full line ends 1.85px (0.115 em) short of the measure on average,
over 1,193 of them.

Times is worse for a reason worth stating: every digit in it measures 0.499 em.
Those are the ranging figures of the eighteenth century, and `metrics.rkt` rejects
them on evidence — the ten figures of a sixteenth-century fount run from 0.39 to
0.65. Smith's bill says the same from the other end: he casts them in unequal
*quantities* too, 1,500 ones against 1,000 nines.

What a revival cannot give you is the *measure*. Its fitting is the reviser's, not
the fount's — Marini autospaced IM Fell with his own algorithm, and Blokland notes
that revivals of Renaissance type are fitted optically rather than to any
historical grid. So the font supplies shapes here and nothing else.

Watermarks and chain-lines are **not** modelled, and are the largest single gap —
[ROADMAP §6](ROADMAP.md). Note when picking them up that in this period the mark
does not give the size: Gaskell lists the sixteenth-century foolscap group as
carrying the Strasbourg lily, the pot and the grapes indifferently.

### Casting off

The copy is measured out into pages before setting, so that a compositor can begin
at page 5 without having set pages 1 to 4. When the measurement is wrong the error
has to be absorbed: the page is crowded, or spun out with white, or — at the limit
— a line of copy is dropped. Verse casts off almost exactly and prose does not
(Gaskell, p. 41), so the strain falls where the prose is.

Moxon counts *letters*, not words, and his worked example runs 43 letters × 35
lines of manuscript to a page, 191,135 letters in the copy, ÷ 1,551 to a printed
page = 123 pages = 15 sheets and 3 pages (pp. 241–2). Both manuals also expand the
copy's abbreviations and count them at length, which is why a compositor
introducing tildes is the wrong picture.

**The program uses one accuracy scalar where the manuals describe two regimes**
with different error behaviour, and Smith ties the crowding devices to which
regime was used. [ROADMAP §5](ROADMAP.md).

### Imposition

The pages of a forme are not consecutive. A folio in sixes is three sheets quired
one within another, so pages **1 and 12** lie side by side on the outer forme of
the first sheet, 2 and 11 on its inner:

```text
sheet 1   outer (1 12)   inner (2 11)
sheet 2   outer (3 10)   inner (4  9)
sheet 3   outer (5  8)   inner (6  7)
```

Nothing can be printed until both pages of a forme stand in type. This is why the
order of setting matters as much as the order of imposition, and it has a price in
metal that the program counts. Setting the same play both ways:

| | by formes | seriatim |
|---|---|---|
| most type standing at once | 16,878 sorts | 27,746 sorts |
| pages standing at the peak | 6 | 11 |
| cases at their emptiest | 29% out | 46% out |

A house setting straight through the copy cannot perfect the first sheet until
page 12 is set, so eleven pages stand locked up and the case runs to 46% empty.
Setting by formes from the middle of the gathering outward (5, 8 / 6, 7 / 3, 10 …)
lets each sheet go to press and come back to the boxes before the next is begun.

That is a calculation, and the two authorities disagree about whether it was ever a
motive. Hinman says it was, for the Folio: Jaggard did not own enough type, so
"shortage of type may have rendered it impracticable to set the book in the
conventional way," setting by formes needing "only enough type to set four pages".
McKenzie searched the Cambridge Vouchers and found the practice "was followed
occasionally but was certainly *not* normal" (i. 115); and where work *was* shared,
the reason was likely "not to make more economical use of a limited supply of type
but to find work for a waiting compositor" (i. 116) — labour scheduling, not metal.

They are describing different shops fifty years apart: a London trade house
printing an outsized folio against its stock, and a university press with men to
keep busy. Type economy can be decisive in one and irrelevant in the other. What
the table cannot support is either as a general law of the hand press.

Smith adds a third voice on the same question, from the far side of the change:
early printers "were obliged to have **large Founts of Letter, on account of
printing their Works in Quires of three, four, and even five sheets**; whereas now,
a Fount of half that force will serve … by printing in single sheets" (p. 47). By
his account the constraint was real while books were quired — which is Hinman's
side of it, from a source explaining why it stopped mattering. This program prints
in sixes. See [ROADMAP §9](ROADMAP.md), because it is also the first evidence ever
found here pointing towards a *richer* shop rather than a poorer one.

### Justification

Spaces are quantised — a line is justified by choosing among the bodies in the
case, not by stretching continuously. When no combination fits, the compositor
reaches for something else: a different spelling, an abbreviation, a turned-over
word, a divided word. The order in which he reaches is a ranked table of violence
to the copy.

Moxon states the rule the program follows, and its limit (p. 207): a space after
every word; if the line will not fill, "he puts a Space more between every Word",
then a third, "so that here is now three Spaces, and strictly, good Workmanship
will not allow more, unless the Measure be so short … This often happens in
Marginal Notes". Wider gaps are **pigeon-holes**, "by Compositers (in way of
Scandal) call'd Pidgeon-holes, and are by none accounted good Workmanship", and
the report counts them. He gives the other bound too: a line is too close set when
only a thin space stands between words, "especially if no Capital Letter follows
the Thin-space or Point go before it".

This is where habit and necessity become impossible to separate, and it is the
caveat Hinman states about his own method (i. 186–7): a spelling forced by a tight
measure is not evidence of the man who set it. Moxon supplies the mechanism from
inside the trade — a compositor coming up to a break "either Sets wide to drive a
Word or two more into the Break-line, or else he Sets close to get in that little
Word" (p. 217), which is spacing chosen for the look of the page and nothing else.

### Stints

Compositors do not alternate. A man takes the frame and holds it for several sheets
together, and the next man is whoever is free rather than the next in turn.
McKenzie, from the Cambridge Vouchers: when two or more men worked on a book "they
did not work together setting sheet and sheet about. What usually happened was that
one took over where the other left off and then composed as many sheets as the
master found convenient or as other commitments allowed" (i. 107).

His quarto Virgil: Bertram set A–E, Crownfield F–3G, Michaelis 3H–3Z, Bertram again
to 4F, Délié the single sheet 4G, Crownfield from 4H, Bertram finishing. Long
blocks, one man returning three times, the odd single sheet where somebody was
free. `--stint-sheets` sets the mean block length.

The uncomfortable consequence: those boundaries fall where the shop's *other*
commitments put them, so "the compositorial pattern within any such book will
rarely have any internal significance." It records the house's other work.

### The lay of the case

The English divided lay, with the upper and lower cases as separate grids so that
no adjacency crosses the division. Reaching distance follows Moxon (i. 21) — a sort
in a far box is likelier to be picked wrong. From this comes foul case (a letter
from an adjoining box), turned letters (`n` for `u`), wrong-fount sorts, and
shortage: when the `w` box is empty, `VV`.

The quantities in the boxes come from Blayney's measured Okes fount where he
tabulates a sort and from a tenth of Smith's bill where he does not — Smith's being
the earliest printed bill there is, which Davis & Carter confirm in a note on
Moxon's silence about it. **The space quantities are the one part with no external
anchor and they disagree with Smith in shape**: [ROADMAP §4a](ROADMAP.md).

Individual types are tracked as pieces with their own damage, so a battered sort can
recur across formes and date them relative to one another. That is Hinman's method,
and the simulator can be graded on it.

### Spelling habit

Compositors are profiles with per-word preferences, drawn from published attribution
work. Jaggard's A prefers `doe`, `goe`, `here`; his B prefers `do`, `go`, `heere`
(Hinman i. 182–3). Okes's B sets `-our` where his C sets `-or`, and C "refused five
opportunities to use an apostrophe" his fellow would have taken (Blayney i. 159–60).

Habit strength is per-word rather than a single scalar, because a single scalar
cannot hold both of Hinman's figures at once: in quire L, A sets `doe`/`goe` 81% of
the time but `here` only 50%.

Blayney's sharper finding is built in too: **type-supply governs spelling.** B's
choice between `-ie` and `-y` looked incoherent until the boxes were tabulated page
by page — over 200 `y` available he set 49% `-y`, between 100 and 200 he set 42%,
below 100 he set 29%. A spelling test measures the case as well as the man.

### The compositor's own rules, and the corrector

The copy is marked up for house style before it reaches the compositor — Blayney's
point, and Halliwell-Phillipps's inference about the annotated quarto that F1 *Much
Ado* was set from. At press, proofs are pulled and corrections made without stopping
the run, so sheets of both states go into the heaps and the made-up copies disagree
with one another. Collating several copies recovers the variants, forme by forme.

A handful of Moxon's rules for the compositor are followed directly, and are worth
naming because each is a place the program could have invented something and did
not:

- **The paragraph indent is exactly one em quad** — "an m Quadrat, (more or less is
  not proper)" (p. 217). Verse indents run two to four, "according to the number of
  the Feet of the Verses".
- **The signature alphabet is 23 letters**, J, U and W omitted: "till he come to W,
  which is always skipt, because the Latin Alphabet has not that Letter in it; but
  next V follows X Y Z" (p. 210).
- **The catchword is the first word of the next page**, or two syllables of it, or
  one, "if the Word be very long and the Line very short".
- **Three spaces and no more**, above.

Others he states are not yet kept — the second signature alphabet should be `Aa`
and not `AA`, widows should be avoided, a long break-line at the foot of a page
should carry the catchword at its end rather than costing a line of quads, and
title-page capitals should be letterspaced. [ROADMAP §9](ROADMAP.md).

## Reading the copy

The input is not slurped as text. It is read through `import.rkt`, which takes
whatever the document already says about itself and hands that to the press along
with the words — because a plain-text dump throws away exactly the thing this
program most needs.

| format | what is taken from it |
|---|---|
| **Markdown** | YAML front matter (title, author, publisher, date); ATX headings; Pandoc fenced divs `::: dedication` |
| **TEI** and EEBO-TCP | `<div type="dedication">` and the rest, declared outright; `<teiHeader>` for title, author, publisher, date |
| **LaTeX** | `\frontmatter` … `\mainmatter`, which marks the very division this program is trying to recover; `\title`, `\author`, `\date` |
| **Word** (`.docx`) | paragraph styles — `Title`, `Heading 1`, or a style literally named `Dedication`; `docProps/core.xml` |
| **HTML** | `<meta>` tags, `<h1>`–`<h6>`, and a `class` or `id` naming a division. Also the export target of every one of the above |
| **PDF** | the Info dictionary and the outline, and nothing else — see below |
| plain text | nothing. The book gets no preliminary matter |

Three tiers, in order of what they are worth:

1. **Declared.** The source says what a division is. Obeyed without argument.
2. **Constructed.** The source gives structure and metadata but no divisions, so the
   preliminaries are *built* rather than found: the headings make a table of
   contents, the metadata makes a title-page. Neither is a guess — both are the
   document's own words rearranged into the matter a printing house would have set
   from them.
3. **Nothing.** Plain text with no structure gets no preliminaries.

**PDF is the weakest and says so.** A PDF has thrown its structure away by
construction: it records where marks go on a page, not what the marks mean. Two
things survive — the Info dictionary, because it is metadata rather than layout, and
the outline, because a table of contents has to be clickable. Everything else is
reconstructed by `tools/pdf-to-copy.py`: lines rejoined into paragraphs on the
evidence of indentation and terminal punctuation, divided words put back together,
running heads dropped where the same short line recurs. None of that is reliable in
the way a Word style is reliable, and the report says which it had.

**The heading vocabulary is experimental and off.** The program used to guess the
preliminaries from a closed list of period headings — *to the right honourable*,
*the epistle dedicatorie*. It is still there behind `--guess-prelims`, but it is the
wrong instrument twice over. It cannot see front matter that carries no heading:
Aylett's *Peace with her foure Garders* (1622) opens with fourteen lines of
dedicatory verse under none at all, and the vocabulary is never consulted. And it is
period-bound, so it can do nothing with the modern copy anyone is actually likely to
bring.

## The preliminaries

The front matter — title-page, dedication, preface, sometimes a table — was printed
**last** and bound **first**, and everything else about it follows from that.
Gaskell: "the preliminaries were not included in the main signature series of new
books because it was usual to print them last" (p. 8). McKerrow from the shop floor:
"in composing a new book from MS the normal course was to begin at the beginning of
the text and proceed straight on to the end, setting up the title-page and
preliminaries last" (p. 128). The compositor who has already signed his text A to L
cannot give the front matter letters, so he gives it a series of its own.

The program sets the text first, then the front matter, and works the gatherings in
printing order while binding them in reading order. It signs them in one of
Gaskell's forms (p. 52). Leaves that carry nothing are cited as McKerrow's `π`. A
short preliminary gathering is half a sheet worked and turned — one forme, not two —
which is `A2`, the commonest preliminary arrangement in Blayney's checklist by a wide
margin.

A preliminary gathering is nearly always **shorter than the format's own scheme**,
and that is worth saying because it hid a bad one — see [ROADMAP §10](ROADMAP.md) for
the fault and the test that now guards it.

The signing is a house habit rather than a lottery, so it can be fixed with
`--prelim-signatures`. Gaskell's order of frequency (p. 52) is the order below; the
weights behind `auto` are a guess at a distribution whose *ordering* alone is
attested.

| value | collates |
|---|---|
| `stars` | `*² A–B⁴` — "even commoner" than letters |
| `symbols` | `*² A–B⁴`, then `† ‡ §` "without logical order" |
| `pilcrow` | `¶² A–B⁴` — not in Gaskell's list, but thick on the ground in Blayney's checklist |
| `lower` | `a² A–B⁴` — "always quite common" |
| `english` | `A² B–C⁴` — "a characteristically English habit … to allow for a sheet of preliminaries signed A"; the overflow goes to `a b c` |
| `continuous` | `A² B–C⁴` — no separate series at all; Gaskell finds it in reprints, where the extent was already known |
| `unsigned` | `π² A–B⁴` — nothing in the direction line; McKerrow's citation mark |
| `auto` | drawn from the weights (the default) |

**Which matter is preliminary cannot be got from the text**, and McKerrow has the
case: Tottel's 1575 *Treatise of Moral Philosophy* puts its Table among the
preliminaries; East reprinting it in 1584 "found he had room for the Table in the
last gathering of the book and placed it there" (p. 78). The same matter, in the same
words, preliminary in one edition and terminal in the next, because of how much room
was left.

So the program does not try to get it from the text. It reads what the document says
about itself, and where the document says nothing, **the book has no preliminary
matter** — the default, and the honest answer.

And it reproduces East's decision rather than imitating it. Whether the Table goes to
the back turns on two questions in McKerrow's order: is there room in the white
leaves the text has already left, and does moving it save leaves at the front? Both
yes and it moves; either no and it stays. The report says which, and why, in both
cases — because "nothing moved" and "there was nothing that could move" are different
facts about a book.

The title-page is generated as **copy**, not supplied as a page, so it goes through
the same compositor as the text and picks up his spelling and his accidents. Its
grammar is measured from Blayney's Appendix II — about ninety title-page transcripts
from one shop between 1604 and 1609, down to the observation that about half the
dates are set with the figures spaced apart, `1 6 0 8.`, because the last line of an
imprint is short and the figures were quadded out to fill it. Moxon gives the general
rule of which that is a special case, and it is not yet implemented: capitals on a
title-page are letterspaced, and "if he Sets but one Space between the Letters in a
Word, he Sets three Spaces between Word and Word" (p. 213).

## The last sheet

"As it costs practically as much to print part of a sheet as a complete one, it was
always to the printer's interest to make up a complete sheet whenever he could"
(McKerrow, p. 159). So the end of a book is governed by an economy that decides where
the preliminaries go and what becomes of the white paper.

A text stopping two leaves short of the end of its last sheet, in a house with two
leaves of preliminaries still to print, does not print a separate half-sheet and
leave two leaves white. It imposes the preliminaries "in the middle of his last
sheet, which may therefore run, as actually printed (supposing it to be in fours),
**Z1, [\*], \*2, Z2, the two centre leaves being cut out to be used as
preliminaries**. Such a book will be described as `*², A–Y⁴, Z²`, quite correctly"
(p. 158–9).

The program does this, and the collation comes out short in exactly the leaves that
went. Cut from the centre they come off as a conjugate fold; cut from the tail they
come off disjunct — which is how Bowers *proved* it of Sandys's Ovid, where the
preliminary leaves "are always disjunct and have any watermark on the outer edges of
the two leaves, an impossibility if they had been printed as a fold in the cut-off."
The program records which; the paper that would betray it is
[on the roadmap](ROADMAP.md).

It is a tendency, not a law. McKerrow allows that it "might sometimes have been more
convenient to have the two extra leaves as covers or end-papers", and Bowers warns
from the other side that "it is dangerous, lacking proof, to assume their absence."
So the program does it three times in four and leaves the paper white otherwise.

## Cancels

A leaf cut out and another pasted to the stub. The obvious objection is that cancels
happen for reasons no simulation can produce — the Privy Council took exception to
*Eastward Ho*. McKerrow gets there first and settles it: "**Into the purpose of these
cancels we need not enter** … The point at present is the aid that bibliography gives
us in detecting them" (p. 223).

So the cause is a parameter and the trace is a simulation. Three causes, of which only
the first is modelled in the strong sense:

- **an error the program made itself** and its own corrector missed — the run knows
  what the error was and knows the proof went by without it (`--cancel-rate`)
- **a change of imprint** — the same setting with the bookseller's name altered, which
  is why a cancel title is commoner than any other kind (`--imprint-change`)
- **anything else** — `--cancels N`, a count and not a model, labelled as such in the
  report

The trace is complete: the leaf cut out leaving a stub, the replacement printed in the
white paper at the end of a gathering — Gaskell has Rousseau's publisher "encourag[ing]
the author to use up the blank leaves of final sheets for printing cancels" — or
costing a half-sheet of its own when there is none. Five of McKerrow's six detection
tests (p. 224) are generated as properties of the particular leaf. The sixth is the
paper.

## The heaps, and the copies gathered from them

The stage at which the copies of one impression stop being interchangeable, and the
place where three authorities meet.

**Gaskell supplies the mechanism** (pp. 143–4). The heaps are set out in signature
order and gathered from the top of each. For a sheet perfected inner forme first they
are gathered "in the reverse of the printing order, so that the first book to be
gathered contained the last printed sheets"; for one perfected outer forme first the
heap "had to be turned over… This heap was then gathered in the printing order". So a
made-up copy is **not** a random handful of corrected and uncorrected sheets. The
copies lie in one linear order, each variant divides that order where the corrected
proof came back, and which side is corrected says which forme of that sheet went to
press first.

**Greg supplies the test.** A made-up copy of a printed edition is conflation by
construction — it descends from no other copy but is assembled from as many heaps as
there are sheets, which is the case his calculus warns about (*The Calculus of
Variants*, p. 43). Drawn independently the groupings cross; gathered as Gaskell
describes they are prefixes and suffixes of one order, hence nested or disjoint —
exactly his condition for consistency, that "given any two constant groups, either
these or their complements are either mutually exclusive or one wholly includes the
other" (p. 12).

**Moxon supplies the grain**, and it used to be wrong here. He watched the
warehouse-keeper hang the heap up in doublings of "about a Quire, or half a Quire, or
about seventeen Sheets, more or less" and take it down by sliding "several Doublings
over one another (perhaps three or four)" (pp. 311–12). Two things follow, and neither
is a matter of rate: order is preserved **inside** a doubling, always, and a doubling
can only be laid back out of order among the few handled with it. **A sheet never
travels alone, and it never travels far.**

`--heap-disorder` used to draw independently per copy per sheet — white noise where the
source describes blocks. It now permutes doublings within a handful, and the rate and
the grain come apart cleanly. Over 40 heaps of 750 sheets:

| `--heap-disorder` | sheets that moved | mean travel | furthest |
|---|---|---|---|
| 0.0 — Gaskell's "case of remarkable regularity" | 0% | — | 0 |
| 0.15 — the default | 11.6% | 27 sheets | 65 |
| 0.5 | 37.4% | 26 sheets | 70 |
| 1.0 | 79.9% | 26.2 sheets | 70 |

**The rate says how many sheets move; it says nothing about how far.** That is fixed by
the handful — at most four doublings of at most 25 sheets — and it does not budge across
the whole range of the parameter. The parameter still carries no authority: Gaskell says
only that the order was likely but "not certain" to survive the drying rack.

### What that does to Greg's condition

It inverts the headline. Greg-consistent groupings, 25 runs, edition 750:

| copies collated | 0.0 | 0.15 | 0.5 | 1.0 |
|---|---|---|---|---|
| 4 | 25 / 25 | 25 / 25 | 25 / 25 | 25 / 25 |
| 10 | 25 / 25 | 25 / 25 | 25 / 25 | 25 / 25 |
| 24 | 25 / 25 | 20 / 25 | 14 / 25 | 5 / 25 |
| 60 | 25 / 25 | 16 / 25 | 5 / 25 | **0 / 25** |
| 200 | 25 / 25 | 14 / 25 | 3 / 25 | **0 / 25** |

Under white noise the condition failed a third of the time on ten copies at the default.
Under Moxon's grain it never fails on ten copies **at any disorder at all**, including
total disorder — and fails every time on sixty. The old model said the collation was too
small. It is not too small, it is **too sparse**: ten copies of a 750-sheet impression
stand 75 sheets apart in the heap, and a sheet can be carried at most 75 — three
doublings of at most 25 — with 70 the furthest observed over 40 heaps. The copies sit
just outside the reach of the mechanism, which is why the column is clean rather than
merely high.

So the governing quantity is the spacing between collated copies against how far a sheet
can move — not the number of copies. The same 24 copies, at the same disorder, detect it
or fail to depending on how deep the heap is:

| edition | sheets between collated copies | Greg-consistent |
|---|---|---|
| 150 | 6 | 43% |
| 300 | 12 | 60% |
| 750 | 31 | 78% |
| 1,500 | 62 | 98% |
| 3,000 | 125 | 100% |

**A bibliographer's collation is blind to any disorder finer than its own spacing in the
heap**, and the blindness is total rather than partial. That is measurable here, it falls
out of Moxon's mechanism rather than being fitted, and it is not as far as I know
anywhere in the literature. It also carries a warning for §2: an inference about
perfecting order drawn from four copies is reading a heap it cannot resolve.

## The order of formes, from the types

Hinman's criterion, and his alone: "the second of two consecutive formes was set
before the first was distributed, and hence the two cannot ordinarily have types in
common" (i. 80). **Sharing a type forbids adjacency.** The order of a quire is
whatever arrangement breaks no prohibition, and he takes the reading as proved only
where one arrangement survives — so what the report prints is the size of the
admissible set, not a score. Six formes is 720 arrangements and is enumerated
outright; there is no search.

Folio in sixes, *Areopagitica*, 10 seeds:

| | quires | determined | of those, right | mean admissible |
|---|---|---|---|---|
| 2 formes standing | 20 | 50% | **10 of 10** | 14.35 |
| 2 standing, a perfect eye | 20 | 50% | **10 of 10** | 9.85 |
| 1 forme standing | 20 | **80%** | **16 of 16** | 1.65 |

**Where one order survives it is the true order, 26 times out of 26.** What varies
is not his accuracy but how often he can speak, and that turns on the shop rather
than the method — four quires in five at one forme standing, half at two. A perfect
eye does *not* raise the strike rate; it shrinks the admissible set from 14.35 to
9.85 without turning more quires into singletons.

**The chaining that fixes direction works too**, and finding out why it did not
took three wrong explanations. `forme-order`, the counter that names a forme's
place, runs **backwards within a gathering** — it is assigned from
`formes-for-gathering` while the pages are set from that list reversed. The link
was taking the last forme of a quire and getting the first one set, comparing two
formes five apart instead of none. Corrected, it fixes the direction rightly in
**12 boundaries of 12**. The criterion never caught it because it is scored up to
reversal, and **a test blind to direction is blind to a direction bug**.
[ROADMAP §1](ROADMAP.md). **Quarto is outside the method
entirely** — a quarto gathering is two formes, which have one order up to reversal,
so the criterion is vacuously satisfied and says nothing. The report says that
rather than printing a hollow 100%. [ROADMAP §1](ROADMAP.md).

## The perfecting order, inferred

The exam the heaps opened, and now sat. Gaskell's mechanism run backwards: the corrected
sheets are the ones worked off after the proof came back, so they lie at the end of the
printing order — and a sheet perfected inner forme first is gathered in reverse of that
order, putting its corrected copies **first**. So a grouping that is a *prefix* of the
gathering names the inner forme, a *suffix* names the outer, and the program knows the
answer.

**The analyst is not given the gathering order.** Copies here are named A, B, C… in the
order they were gathered, so sorting them by name would hand over the answer — the fault
`recurrence.rkt` exists to prevent on the type side. Nothing in `perfecting.rkt` reads a
copy's name or its position in a list; the order is reconstructed from how the groupings
nest, which is Greg's condition doing a job rather than being tested. A test feeds the
copies in scrambled eight ways and checks the reading does not move.

**The result is 100%, and it means less than that sounds.** Over 40 runs of 24 copies,
322 of 322 formes are sorted into the right two classes. Three things have to be said
beside it:

- **The chance floor is not a half.** The metric takes the better of two directions, so
  for nothing it scores `E[max(X, n−X)]/n` — 0.75 on two formes, **0.64 on eight**, still
  0.53 on two hundred. Scored against a deliberately shuffled truth the control returns
  66.5%. The report computes the floor per run and prints it beside the score.
- **The direction is not in the evidence.** Calling one class of groupings the prefixes is
  free; taking the other reverses the recovered order and turns every inner into an outer
  at a stroke, and both readings satisfy Greg equally. Over 60 runs the method calls the
  direction rightly 30 times and backwards 30 times — **a coin, as claimed, and measured
  rather than argued**. The ambiguity is exactly 2: the groupings never fell into more
  than one independently-flippable class in any run tested.
- **It is never partly right.** In those 60 runs, **not one** got some formes right and
  others wrong. The method recovers the whole partition or the exact inverse. It has
  precisely one thing it can get wrong, and it gets it wrong half the time.

One fact from outside settles every sheet at once — one sheet whose printing order is
known from the type recurrence ([§1](ROADMAP.md)), or the assumption that the shop
perfected mostly one way. Gaskell's own example supposes inner-first throughout, which
would serve; it is imported rather than read, and is not assumed here.

**And it survives what Greg's own test does not.** At 200 copies and total heap disorder
the consistency condition fails 25 times in 25 — and the perfecting inference is still
100%. Moxon's disorder is local, at most 75 sheets; whether a grouping sits at the head or
the foot of the heap is global. The two are sensitive to different things, which is worth
knowing before treating a failed consistency test as evidence that nothing can be read.

**What a collation can resolve is bounded by its variants, not its copies.** Groupings cut
the gathering in one place each, so *j* variant formes distinguish at most *j*+1 positions
however many copies are on the table. The report brackets copies no variant separates
rather than printing a flat list — 24 copies and one variant fall into two places, and
showing them in a line would dress the arbitrary order of a tie as a finding.

## Gathering, folding and binding

The one stage at which the *book* diverges from the *printing*. Two hands in two
places: the warehouseman gathers in the printing house, walking the line of heaps and
taking one sheet from each (Gaskell, pp. 143–4; Moxon has him begin at the last heap,
p. 315); the binder folds and sews later and elsewhere. Between them they can drop a
sheet, take two, put one in backwards, or sew them out of order — and the whole
apparatus of signatures exists to stop two of those. Signing was "to get them the right
way up and in the right order … in order to help the binder with his folding" (p. 79),
and that sentence is the design.

Moxon gives the check that catches them, in the printing house and before the book goes
out (p. 317): whether every sheet is there, whether two of one sort were gathered, and
whether "the proper Signature of every Sheet lye on its proper corner" — which is the
turned-sheet test. That confirms the shape the program models: **an unsigned gathering
is likelier to go in wrong, and likelier to survive the warehouse's check when it does,
because the check is the signatures too.**

**The rate does not come from anywhere.** Neither Gaskell nor McKerrow nor Moxon gives
one, so `--binding-error` is a parameter with no authority claimed for it, and the
report prints the disclaimer beside every fault it lists. Moxon's *repair* — a book
made perfect from another copy's duplicate sheet — is not modelled and has a
consequence for the heaps: [ROADMAP §9](ROADMAP.md).

## The lexicon

For most of its life this program had no dictionary. Its spelling devices were rules —
strike off a terminal `-e`, double a consonant, add an `-e` to fill a line — and
nothing checked the result. A rule so arranged produces `theere` and `manne` as readily
as `heere` and `doe`, and did.

The remedy is a reversal of authority. **The lexicon says which spellings exist; the
rules only choose among them.** A device that can select but not invent cannot fabricate
a spelling, however tight the line.

`lexicon/eebo-1580-1640.rktd` holds **318,722 spellings attested in 5,287 books printed
1580–1640**, in 45,719 variant groups, with 18,562 mapped to the form still current. It
answers four different questions: `attested?` (is this a real spelling), `plausible?`
(is it one anybody actually used), `variants-of`, and `commonest-form` / `modern-form`.

`plausible?` is the useful one, and a big corpus is what makes the difference matter.
`theere` occurs 17 times against 145,517 for `here` — not a spelling anybody chose, but
the sweepings of a very large floor. Beside it `manne` at 1,147 and `somme` at 467 are
real usage. The threshold is one occurrence in two hundred, stated in the open rather
than buried.

**How the grouping works.** Without a modern wordlist to anchor it, `her` becomes a
spelling of `here` — the reduction that correctly joins `heere` to `here` joins `here`
to `her` by identical steps. What separates them is that `her` is itself a current word,
and a current word is not a misspelling of another. So: reduce each form to a
**skeleton** collapsing the period's alternations (`u`/`v`, `i`/`j`, doubled letters,
terminal `-e`); split each group against a modern wordlist, so every current word keeps
its own variants; then assign each old form to the single **nearest** current word by
edit distance, so `heere` goes to `here` and not also to `her`.

It still errs: `runne` is assigned to `rune` rather than `run`, being nearer. Nothing
about the letters separates that from `heere`/`here`, where distance gives the right
answer — which is why VARD and its relatives keep a human in the loop, and why
`--modern-spelling` is approximate.

**Rebuilding it** — for another period, another kind of book, or a narrower window.
Three commands and about an hour:

```sh
# 1.65 GB of TEI XML from Oxford, filtered by each text's own imprint date
python tools/fetch-eebo.py --dest corpus --from 1580 --to 1640

# a wordlist, from any Hunspell dictionary already on the machine
python tools/make-wordlist.py path/to/en-GB.dic tools/modern-en.txt

# the lexicon itself
python tools/build-lexicon.py corpus/texts \
       -o lexicon/eebo-1580-1640.rktd \
       --modern tools/modern-en.txt --min 5
```

`--min` ignores forms below a count (a hapax in a keyed corpus is as likely a
transcription slip as a spelling); `--modern` supplies the anchor, and the builder warns
if you omit it.

A run picks its lexicon in this order: `$HANDPRESS_LEXICON`, then the shipped one, then
`samples/ado-lexicon.rktd` — 2,370 forms from the two *Much Ado* texts. The last is kept
because it is small enough to read and because the difference is instructive: on the
same copy, words altered to fit the measure rise from 8.70 per thousand to 29.38 once a
real corpus is behind them.

The corpus is not only a wordlist. It is text, and every tilde, ampersand and brevigraph
in it is countable; `tools/count-scribal.py` does exactly that, which is how the scribal
rates were finally settled after several sessions of guessing them from two books.

The modern wordlist is a **build input** and is not redistributed; only its verdict on
public-domain forms is.

## Calibration

Every parameter that has been checked against a real book was wrong when first guessed,
usually by an order of magnitude, and always in the same direction — towards a printing
house more picturesque than the real one. The record:

| parameter | in the real books | first guess | now |
|---|---|---|---|
| the fount | 21,953 sorts (Okes, *Lear* Q1) | 60,000 | 31,200 incl. space |
| tilde abbreviations | 1.01 / 1000 words (English, 1600s) | 83 | 1.66 |
| superscript `yᵗ`, `wᶜʰ` | 5.5 per **million** words | 6,600 | ~0 |
| foul case + turned letters | 0.25 / 1000 words | 11.57 | 0.87 |
| word division | 2.03 / 100 lines (whole Folio) | 0.0 | 1.66 |
| medial apostrophes (`rul'd`) | 9.58 / 1000 words | 1.17 | 5.37 |
| ampersand | 3.18 / 1000 (English, 1600s) | 35 | 3.02 |
| class spelling habits (`-ie`, `-ll`) | 57% (Blayney) | 82–91% | 57% |
| wrong-fount sorts | a handful a book | 248 | 13 |
| gaps a compositor could set | every one | 14% | 95% |
| quarto leaf, tall to wide | 1.31 (Gaskell, Key III) | 1.99 | 1.31 |
| verse share of the Folio | 73% (solved from the plates) | 94% | 73.2% |
| roman lower-case alphabet | 11 ems (Smith, p. 158) | — | **10.95 ems** |

The last row is the only one that was right the first time, and it is the only one that
was checked *after* the fact rather than fitted: the width table was written to be
plausible and turned out to be accurate to 0.5% against a figure nobody had looked up.

Most of the measurements come from diffing the 1600 quarto of *Much Ado About Nothing*
against the 1623 Folio text set from it — 11,990 words, a real copy-text and a real
setting from it. That is a narrow base, and widening it is [ROADMAP §11](ROADMAP.md).

The scribal contractions are the instructive failure. The program used to produce
`implēētatiō` for *implementation*, stacking tilde contractions on one word, and label
the result a space-saving. It was neither: the Folio has none of them, and some of the
substituted forms were *longer* than what they replaced. Both manuals say why the whole
picture was wrong — a compositor casting off *expands* the copy's abbreviations and
counts them at length. The genuine English space-saver was sitting in the same data
unnoticed: the Folio has eight times the quarto's medial apostrophes, turning some thirty
`-ed` endings into `-'d`.

Forward test, Q1600 → F1623, on the spelling that attribution work relies on:

| | actual F1 | simulated |
|---|---|---|
| `here` / `heere` | 52% | 51% |
| `do` / `doe` | 61% | 80% |

The `do`/`doe` overshoot is explained: the real scenes were set by more than one man, and
the simulation ran one man's habit across all of them.

## The First Folio

`tools/fetch-folio.py` assembles the book of 1623 as copy — 868,245 words, all 36 plays
in Catalogue order with the eight preliminary pieces, as both TEI (preliminaries
*declared*) and Markdown (*constructed*). It is not committed; rerun the script. The
plays come from Project Gutenberg in modern spelling; the preliminaries are Wikisource's
transcription and are in **original 1623 spelling**, because no free modern-spelling
edition of them exists — 0.24% of the copy, and the script says so at length.

```
python tools/fetch-folio.py
racket main.rkt --format folio6 --paper crown --compositors A,B,C,D,E \
  --kind drama --year 1623 --edition 1200 --copies 1200 --copy-texts 0 \
  --tei --html -o out-folio folio/folio.tei.xml
python tools/audit-mechanisms.py out-folio/folio.tei.report.txt
```

About seven minutes, and it is the standard hard case — the book that finds defects
nothing smaller does. Where it stands against the record:

| | model | recorded | source |
|---|---|---|---|
| pages | **924** | 908 | the book |
| press variants in the book | **543** | "just over 500" | Hinman, Norton, p. xx |
| formes corrected mid-run | **102 of 462** | ~100 of ~450 | ibid. |
| word divisions per 100 lines | **1.71** | 2.03 | measured, 790 plates |
| type page | 20 ems × 2 × 66 | 20 ems × 2 × 66 | Hinman i. 35 |
| verse share of the text | 73.2% † | 73% | solved from the Norton plates |
| impressions before correction | median 8% † | "about 100" of 1,200 | ibid. |
| identifiable types per page | 12.7 † | 11–12 | Blayney i. 96 on Hinman |
| characters to a line of type | 37.7 mean, 41 median † | 39.6 mean, 42 median | measured, 220 plates / 27,884 lines |

† not recomputed since the space-ladder changed; these four are measured outside
the report and the figures are from the previous run. The last of them is the one
to redo first: narrower spaces put more characters on a line, and the model was
already *under* the plates.

The first four moved a long way, and all four toward the record — 990 pages to
924 against the book's 908, and Hinman's press-variant count reached from twice
his figure. None of it was aimed at: the ladder was chosen on Blayney's ruler and
Moxon's prose, and these are what came out.

**But the same run drops copy, and the cause is worth more than the gains.**

| | Jacobi | Moxon |
|---|---|---|
| pages spun out | 646 | **31** |
| pages crowded | 60 | **570** |
| lines of copy dropped | 142 | **2,569** |
| catchwords not answering | 37 | **476** |

The book was two-thirds spun out, which is a defect this file has carried for
some time. It is now two-thirds crowded, and crowding drops copy — the
catchwords stop answering because the page they anticipate has lost its opening.
The total of mis-cast pages barely moved (706 per 1000 to 601); what changed is
the *direction* of the error.

One cause, and it is not the ladder. `imposition.rkt` casts off by assuming
`NORMAL-SPACE` at every gap, while justification actually averages well above it
— 0.359 em against a nominal 0.333 under Jacobi, but 0.291 against 0.250 under
Moxon. The under-count doubled, from 7.8% to 16.4%, so pages are over-allotted
and the overflow is dropped. The casting-off estimate had been *calibrated to the
old ladder*, which the comment above it says outright, having tuned the verse
test "at a hair".

So this is the coupling **[ROADMAP §5](ROADMAP.md)** now has to break, and it is
the critical path. Nothing here has been tuned to hide it.

**These are the run of commit `45b75fc` and four fixes have landed since.** Every figure
will have moved and none has been re-measured at Folio scale. What is measured, on a
preliminaries-and-Tempest slice: mean page depth 119.2 → 127.5 of 132 lines, full pages
4 of 25 → 21 of 23, and the same copy set in 23 pages where it took 25. **Re-run before
quoting any of it.**

Nothing was tuned to close a gap; where one is open it is open on purpose, and
[ROADMAP §10](ROADMAP.md) says which and why — along with the whole history of what the
Folio caught, which is the most useful record in this repository of how the program has
been wrong.

`tools/audit-mechanisms.py` reads a finished report and sorts every countable mechanism
into *fired*, *silent*, and *not offered* — the third pile being the one a list of counts
cannot give you, because a bare `0` cannot tell a thing that did not happen from one that
could not.

## Running it backwards

`reconstruct.rkt` takes a printed text and tries to recover the copy behind it — the
editor's problem. It reports a word-by-word confusion matrix rather than a score, because
the interesting result is *where* it fails.

The best blanket rule ceilings at 70–76%. There is no per-word evidence to do better,
which is the honest form of Greg's distinction between substantives and accidentals: he
arrived at it by counting, and so does this.

## What it does not do

- **Watermarks and chain-lines.** The paper now has a size but no mould, so the one test
  in McKerrow's cancel checklist the program cannot run is the paper test. This is the
  largest single gap.
- **Concurrent production.** McKenzie's central finding is that a shop worked on several
  books at once, and this models one book at a time. The report says so, at length,
  wherever it draws a conclusion that concurrency would undermine.
- **Per-compositor cases.** Hinman distinguishes cases x, y and z; here all the men draw
  from one pair.
- **Forme order from type recurrence.** The pieces are tracked and the recurrences
  recorded, but nothing yet reconstructs the order of printing from them. This is the
  next thing to build, and the reason is that it grades itself.
- **Italic set widths.** The program has one roman table and sets italic at roman widths,
  which is about 13% too wide.

The analysis is circular in the way McKenzie showed all such analysis to be: it recovers
the model's own assumptions. The program says this itself, in the report, every time.

## Sources

They are not of one kind, and the difference decides how much weight a claim will bear.

**The manuals** — written by printers, for printers, and the only sources that describe
the work from inside. They describe it as it *ought* to be done, which is their strength
and their limit. Both are read directly; for most of this project's life their figures
arrived second-hand through Gaskell and Blayney, and the difference that made is
[ROADMAP §3–5, §7, §9](ROADMAP.md).

- **Joseph Moxon**, *Mechanick Exercises on the Whole Art of Printing* (1683–4), ed.
  Herbert Davis and Harry Carter, 2nd edn (OUP, 1962) — the lay of the case, the
  quantities and thicknesses of the spaces, the reaching, casting off by breaks, the
  compositor's rules for indenting and signing and catchwords, the warehouse-keeper's
  handling of the heaps, and the collation check. **Davis & Carter's notes are half the
  value**: they check Moxon against Plantin's archives, the Oxford accounts, Fertel and
  Fournier, and say where he is wrong or inconclusive.
- **John Smith**, *The Printer's Grammar* (1755) — the earliest printed bill of letter
  there is, which is why `typecase.rkt` rests on it; the relative widths of roman, italic
  and black; the body depths; and two methods of casting off with a judgement between
  them.

**The archives** — records made at the time, for other purposes, which is what makes them
evidence rather than inference. Nearly every correction this program has had to make came
from the first of these.

- **D. F. McKenzie**, *The Cambridge University Press 1696–1712*, 2 vols (1966) —
  production times, compositors' output in ens, the finding that setting by formes was
  *not* normal, and the Vouchers showing men taking over from one another in long blocks
- **Percy Simpson**, *Proof-Reading in the Sixteenth, Seventeenth and Eighteenth
  Centuries* (1935; repr. 1970 with Harry Carter's foreword, where most of the corrections
  to Simpson actually are)

**The analyses** — the New Bibliography. This program stands oddly towards it:
implementing the method in order to test it, and reporting where it fails.

- **Charlton Hinman**, *The Printing and Proof-Reading of the First Folio of Shakespeare*,
  2 vols (1963) — the largest single debt. Compositor spellings, type recurrence,
  proof-reading, the pagination errors, and the caveat about justification the whole
  method turns on
- **Peter W. M. Blayney**, *The Texts of King Lear and their Origins* (1982) — Okes's
  compositors, the measured fount, copy preparation, and the practice of tabulating
  justified and unjustified occurrences apart. **Appendix II is a corpus, not an
  appendix**: ninety-odd books from one shop with title-page transcripts, collations and
  ornaments, out of which every imprint formula in `titlepage.rkt` was counted
- **Philip Gaskell**, *A New Introduction to Bibliography* (1972) — the bill of letter,
  casting off, formats, **paper sizes and the identification of format**, and the shop-size
  rule for dividing copy; and "The lay of the case", *Studies in Bibliography* xxii (1969)
- **R. B. McKerrow**, *An Introduction to Bibliography for Literary Students* (1927) —
  imposition, signing, catchwords, cancels
- **Fredson Bowers**, *Principles of Bibliographical Description* (1949) — the form of the
  description
- **W. W. Greg**, *The Shakespeare First Folio* (1955) and *The Calculus of Variants*
  (1927) — the consistency condition the heaps are tested against
- **Thomas Satchell** (1920), extended by Willoughby — the first of the spelling tests,
  which Hinman built on

**The objection**

- **D. F. McKenzie**, "Printers of the Mind", *Studies in Bibliography* xxii (1969) — the
  paper this program cannot answer and does not try to

**Texts and data**

- **Internet Shakespeare Editions** — old-spelling transcriptions of the *Much Ado* quarto
  and Folio, used for calibration
- **H. H. Furness**, ed., *Much Ado About Nothing*, New Variorum (1899) — the collation
  those measurements are checked against
- **Richard Mulcaster**, *The First Part of the Elementarie* (1582) — the General Table of
  some 8,000 words in the spellings he recommends
- **EEBO-TCP Phase I** — public domain since 2015 under the ODC-PDDL; the 5,287 texts
  printed 1580–1640 are the attestation lexicon
- **Frank E. Blokland**, *On the Origin of Patterning in Movable Latin Type* (2016) — the
  only published per-sort calliper measurements of sixteenth-century foundry type
- **Baron & Rayson**, *VARD 2* (2008) — not used, but it solves the same variant-grouping
  problem, and its design settles a question met here independently

The PDFs live in `sources/`, which is gitignored: they are copyrighted books and the
repository is public.

## What next

See [ROADMAP.md](ROADMAP.md). The two things at the top are both about grading the method
rather than extending the simulation.

**Forme order from type recurrence** is the real prize, because it is Hinman's central
method and this is the only place it can be graded against a known truth. Blayney even
supplies the threshold at which he says it must fail: unless the evidence-density reveals
at least two prior distributions in every quarto page, the order those pages were set in
cannot be proved. The simulator can run it at any density and find where the boundary
actually falls.

**Recovering the perfecting order from the groupings** has been sat: 100% of formes
sorted into the right two classes, and the direction of those classes not recoverable
from press variants at all. What is still open there is the analyst's eye — the
inference is handed a perfect collation, where a real one misses variants — and a book
long enough for the groupings to fall into more than one independently-flippable class,
which has not yet happened in any run tested.

## Licence

MIT.
