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
- [Quick start](#quick-start)
- [Command line](#command-line)
- [What is modelled](#what-is-modelled)
- [Reading the copy](#reading-the-copy)
- [The preliminaries](#the-preliminaries)
- [The last sheet](#the-last-sheet)
- [Cancels](#cancels)
- [The heaps](#the-heaps-and-the-copies-gathered-from-them)
- [Gathering, folding and binding](#gathering-folding-and-binding)
- [The lexicon](#the-lexicon)
- [Calibration](#calibration)
- [Running it backwards](#running-it-backwards)
- [What it does not do](#what-it-does-not-do)
- [Sources](#sources)
- [Roadmap](ROADMAP.md)

## What it produces

Every run writes into the output directory:

| file | what it is |
|---|---|
| `NAME.facsimile.txt` | the type-facsimile: pages, signatures, catchwords, running titles |
| `NAME.report.txt` | the bibliographical description and the analysis |
| `NAME.tei.xml` | a TEI P5 encoding of the setting — **the record** (`--tei`) |
| `NAME.html` | the type-facsimile, built by reading that TEI back (`--html`) |
| `NAME.tei.html` | a plain reading text, via XSLT (`--xslt`) |

The report opens with a Bowers-style description — collation formula, format,
the press variants sorted by forme and state — and goes on to the analysis:
what the spelling tests say about who set which page, what the running titles
say about the skeletons, where the casting off went wrong, how the case fared.

## Quick start

### 1. Install Racket

The only thing you need. Racket is a programming language; handpress is written
in it, and nothing else has to be installed.

Download it from **[racket-lang.org/download](https://racket-lang.org/download/)**
and run the installer. Version 8.0 or later. The default options are right.

- **Windows** — run the `.exe`. When asked, let it add Racket to your PATH.
- **macOS** — open the `.dmg` and drag Racket to Applications. Then add it to
  your PATH by running this once in Terminal:
  ```sh
  echo 'export PATH="/Applications/Racket v8.12/bin:$PATH"' >> ~/.zshrc
  ```
  changing `v8.12` to whatever version you installed, then open a new Terminal.
- **Linux** — `sudo apt install racket` on Debian or Ubuntu, or use the
  installer from the site, which is usually newer.

**Check it worked.** Open a new terminal — a new one, so it picks up the
changed PATH — and type:

```sh
racket --version
```

You should see something like `Welcome to Racket v8.12`. If instead you get
"command not found" or "not recognized as an internal or external command",
Racket is installed but your PATH does not know where it is. On Windows, search
the Start menu for "Edit the system environment variables" → *Environment
Variables* → select **Path** → *Edit* → *New*, and add the `bin` folder inside
where Racket installed itself, usually `C:\Program Files\Racket`. Then open a
new terminal and try again.

### 2. Get handpress

**With git**, if you have it:

```sh
git clone https://github.com/wydna-group/handpress.git
cd handpress
```

**Without git**, which is fine — you do not need it to run this. Go to
[github.com/wydna-group/handpress](https://github.com/wydna-group/handpress),
click the green **Code** button, choose **Download ZIP**, and unzip it
wherever you like. Then open a terminal in that folder. (On Windows: open the
unzipped folder, click in the address bar, type `cmd`, and press Enter.)

### 3. Run it

```sh
racket main.rkt --html --out out samples/hamlet.txt
```

That sets the sample through a simulated 1600s printing house and writes into a
new `out` folder. Then **open `out/hamlet.html` in your browser** — double-click
it, or drag it onto a browser window. That is the type-facsimile: every word
sits where the simulated compositor computed it should.

Alongside it you will find:

| file | what it is |
|---|---|
| `hamlet.html` | the facsimile — start here |
| `hamlet.report.txt` | the analysis, which is the point of the exercise |
| `hamlet.tei.xml` | the TEI record everything else is built from |
| `hamlet.copy-a.txt` … | one file per made-up copy, for collating |

Nothing is installed on your system and nothing is written outside the folder
you chose.

### 4. Run it on your own book

handpress reads what your document already says about itself, so give it the
richest format you have:

| you have | extension | what handpress takes from it |
|---|---|---|
| a Markdown file | `.md` | YAML title/author/publisher/date; headings; `::: dedication` |
| a Word document | `.docx` | document properties; paragraph styles including `Title` and `Heading 1` |
| a web page or export | `.html` | `<meta>` tags, `<h1>`–`<h6>`, `class="dedication"` |
| a TEI or EEBO-TCP file | `.xml` | `<div type="dedication">` and the `<teiHeader>` |
| a LaTeX source | `.tex` | `\title`, `\author`, and `\frontmatter` |
| a PDF | `.pdf` | the title and author it was saved with, and its outline |
| a plain text file | `.txt` | the words, and nothing else |

```sh
racket main.rkt --html --out out --format quarto --year 1610 mybook.docx
```

A file saved under the wrong extension is sniffed, so a TEI document named
`.txt` is still read as TEI. Plain text works perfectly well — you simply get a
book with no preliminary matter, because a text file cannot say that a
paragraph is a dedication. See [Reading the copy](#reading-the-copy).

There is a worked example in **[`review/`](review/README.md)**: one 1600 book
put through all seven formats, so you can see what each one buys.

### Optional

Register the collection, so the modules can be required as
`handpress/compositor` and the manual builds into your local Racket docs:

```sh
raco pkg install --link .
```

You can skip this and run `main.rkt` in place, as above.

Run the tests:

```sh
raco test test-all.rkt
```

About fifteen seconds for all 991 checks. `raco test .` runs the same checks in
about three and a half minutes, because it gives each module a fresh process
and thirteen of them load the 9.8 MB lexicon on the way up. Use `test-all.rkt`
while working; use `raco test .` in CI, where the isolation is worth the wait.

Build the manual:

```sh
raco scribble --html --dest doc scribblings/handpress.scrbl
```

### On the TEI

The `.tei.xml` is the record, and everything else is derived from it —
including the facsimile, which is built by reading that file back off disk
rather than by rendering the book a second time. That is deliberate: it is what
keeps the encoding honest, since **anything the TEI does not carry cannot
appear on the page**. It has already caught six things the file was quietly
missing.

`--xslt` additionally runs `xslt/tei-to-html.xsl` to give a plain reading text
for anyone consuming the file without Racket. It is not a second facsimile and
does not try to be. The step shells out to a transform driver in `tools/`; on
Windows it uses .NET's `XslCompiledTransform`, which is XSLT 1.0, and the
stylesheet is written to that limit.

## Command line

Flags come **before** the input file, as Racket's `command-line` requires.

### The book

| flag | effect |
|---|---|
| `-o`, `--out` | directory for the output files |
| `--format` | `folio`, `folio6`, `quarto`, `octavo` |
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
| `--heap-disorder` | how much of the heaps' order the drying destroys, 0–1 — **no source gives a value** |
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
| `--stint-sheets` | sheets a man sets before the frame changes hands (default: by shop size) |
| `--paging-error` | how freely the paging goes wrong, 0–1 (default 0.04) |

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
| `--modern-spelling` | show the same setting in modern spelling |
| `--pages`, `--quiet` | how much to print to the terminal |

## What is modelled

### The type as physical objects

Every sort is a piece of metal drawn from a box that can empty. That includes
the things it is easy to forget are type at all:

- **Space-metal.** A gap is a body a shade lower than the face so that it takes
  no ink — em quad, en, thick, middle, thin, hair. **16% of everything set is
  white**, and the thick space is as common in a fount as the letter `e`.
  Justification is therefore *quantised*: a compositor can only set
  combinations of the bodies he has, so a line fills the measure to within less
  than a hair rather than exactly.
- **Ligatures**, including `ſt`, `ſh`, `ſi` and `ſſ`, which in an English fount
  outnumbered `ﬀ`, `ﬁ` and `ﬂ` together. They print as their two letters; what
  differs is which box emptied.
- **The ladder of shifts** when a box runs dry, in the order Blayney watched a
  compositor work down it: set `VV` for `W`; rob a sort from the margin of a
  page already standing; distribute a forme early; set a sort **face down** and
  fill the space at proof; send to the founder for more.

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

That is a calculation, and the two authorities disagree about whether it was
ever a motive.

Hinman says it was, for the Folio: Jaggard did not own enough type, so
"shortage of type may have rendered it impracticable to set the book in the
conventional way," setting by formes needing "only enough type to set four
pages". McKenzie searched the Cambridge Vouchers and found the practice "was
followed occasionally but was certainly *not* normal" (i. 115); and where work
*was* shared, the reason was likely "not to make more economical use of a
limited supply of type but to find work for a waiting compositor" (i. 116) —
labour scheduling, not metal.

They are describing different shops fifty years apart — a London trade house
printing an outsized folio against its stock, and a university press with men
to keep busy. Type economy can be decisive in one and irrelevant in the other.
What the table cannot support is either as a general law of the hand press.

### Reading the copy

The input is not slurped as text. It is read through `import.rkt`, which takes
whatever the document already says about itself and hands that to the press
along with the words — because a plain-text dump throws away exactly the thing
this program most needs.

| format | what is taken from it |
|---|---|
| **Markdown** | YAML front matter (title, author, publisher, date); ATX headings; Pandoc fenced divs `::: dedication` |
| **TEI** and EEBO-TCP | `<div type="dedication">` and the rest, declared outright; `<teiHeader>` for title, author, publisher, date |
| **LaTeX** | `\frontmatter` … `\mainmatter`, which marks the very division this program is trying to recover; `\title`, `\author`, `\date` |
| **Word** (`.docx`) | paragraph styles — `Title`, `Heading 1`, or a style literally named `Dedication`; `docProps/core.xml` for the document properties |
| **HTML** | `<meta>` tags, `<h1>`–`<h6>`, and a `class` or `id` naming a division. Also the export target of every one of the above |
| **PDF** | the Info dictionary and the outline, and nothing else — see below |
| plain text | nothing. The book gets no preliminary matter |

A file saved under the wrong extension is sniffed, so a TEI document called
`.txt` is still read as TEI.

Three tiers, in order of what they are worth:

1. **Declared.** The source says what a division is. Obeyed without argument.
2. **Constructed.** The source gives structure and metadata but no divisions,
   so the preliminaries are *built* rather than found: the headings make a
   table of contents, the metadata makes a title-page. Neither is a guess —
   both are the document's own words rearranged into the matter a printing
   house would have set from them.
3. **Nothing.** Plain text with no structure gets no preliminaries.

**PDF is the weakest and says so.** A PDF has thrown its structure away by
construction: it records where marks go on a page, not what the marks mean.
Two things survive — the Info dictionary, because it is metadata rather than
layout, and the outline, because a table of contents has to be clickable.
Everything else is reconstructed by `tools/pdf-to-copy.py`: lines rejoined into
paragraphs on the evidence of indentation and terminal punctuation, divided
words put back together, running heads dropped where the same short line
recurs on most pages. None of that is reliable in the way a Word style is
reliable, and the report says which it had.

**The heading vocabulary is experimental and off.** The program used to guess
the preliminaries from a closed list of period headings — *to the right
honourable*, *the epistle dedicatorie*. It is still there behind
`--guess-prelims`, but it is the wrong instrument twice over. It cannot see
front matter that carries no heading: Aylett's *Peace with her foure Garders*
(1622) opens with fourteen lines of dedicatory verse under none at all, and the
vocabulary never gets consulted. And it is period-bound, so it can do nothing
whatever with the modern copy anyone is actually likely to bring.

### The preliminaries

The front matter — title-page, dedication, preface, sometimes a table — was
printed **last** and bound **first**, and everything else about it follows from
that. Gaskell: "the preliminaries were not included in the main signature
series of new books because it was usual to print them last" (p. 8). McKerrow
from the shop floor: "in composing a new book from MS the normal course was to
begin at the beginning of the text and proceed straight on to the end, setting
up the title-page and preliminaries last" (p. 128). The compositor who has
already signed his text A to L cannot give the front matter letters, so he
gives it a series of its own.

The program sets the text first, then the front matter, and works the
gatherings in printing order while binding them in reading order. It signs
them in one of Gaskell's forms (p. 52): `* ** ***`, `* † ‡ §`, lower-case
`a b c` with the text from A, or the "characteristically English habit" of the
text from B with the preliminaries signed A. Leaves that carry nothing are
cited as McKerrow's `π`. A short preliminary gathering is half a sheet worked
and turned — one forme, not two — which is `A2`, the commonest preliminary
arrangement in Blayney's checklist by a wide margin.

The signing is a house habit rather than a lottery, so it can be fixed with
`--prelim-signatures`. Gaskell's order of frequency (p. 52) is the order below;
the weights behind `auto` are a guess at a distribution whose *ordering* alone
is attested.

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

**Which matter is preliminary cannot be got from the text**, and both
authorities say so. McKerrow has the case: Tottel's 1575 *Treatise of Moral
Philosophy* puts its Table among the preliminaries; East reprinting it in 1584
"found he had room for the Table in the last gathering of the book and placed
it there" (p. 78). The same matter, in the same words, preliminary in one
edition and terminal in the next, because of how much room was left.

So the program does not try to get it from the text. It reads what the
document says about itself — see [Reading the copy](#reading-the-copy) — and
where the document says nothing, **the book has no preliminary matter**. That
is the default and it is the honest answer.

And it reproduces East's decision rather than imitating it. Whether the Table
goes to the back turns on two questions in McKerrow's order: is there room in
the white leaves the text has already left, and does moving it save leaves at
the front? Both yes and it moves; either no and it stays. The report says
which, and why, in both cases — because "nothing moved" and "there was nothing
that could move" are different facts about a book.

The title-page is generated as **copy**, not supplied as a page, so it goes
through the same compositor as the text. Its grammar is measured from Blayney's
Appendix II, about ninety title-page transcripts from one shop between 1604 and
1609: the printer is named on 58 of 81 and abbreviated to initials on 19 of 50;
a shop is given on 40 of 81, half as *and are to be sold at his shop in* and
half as *dwelling in*; and about half the dates are set with the figures spaced
apart — `1 6 0 8.` — because the last line of an imprint is short and the
figures were quadded out to fill it.

### The last sheet

It costs as much to print part of a sheet as a whole one, so the end of a book
is governed by an economy that decides where the preliminaries go and what
becomes of the white paper. McKerrow, p. 159:

> as it costs practically as much to print part of a sheet as a complete one,
> it was always to the printer's interest to make up a complete sheet whenever
> he could

A text that stops two leaves short of the end of its last sheet, in a house
with two leaves of preliminaries still to print, does not print a separate
half-sheet and leave two leaves white. It prints the preliminaries **in** the
white leaves and cuts them out:

> he will as a matter of course impose these preliminaries in the middle of his
> last sheet, which may therefore run, as actually printed (supposing it to be
> in fours), **Z1, [\*], \*2, Z2, the two centre leaves being cut out to be used
> as preliminaries**. Such a book will be described as `*², A–Y⁴, Z²`, quite
> correctly. (p. 158–9)

The program does this, and the collation comes out short in exactly the leaves
that went. Cut from the centre they come off as a conjugate fold; cut from the
tail they come off disjunct — which is how Bowers *proved* it of Sandys's Ovid,
where the preliminary leaves "are always disjunct and have any watermark on the
outer edges of the two leaves, an impossibility if they had been printed as a
fold in the cut-off." The program records which; the paper that would betray it
is [on the roadmap](ROADMAP.md).

It is a tendency, not a law, and both authorities say so. McKerrow: "we must
not assume that a printer would in every case economize his labour and paper in
this fashion: it might sometimes have been more convenient to have the two
extra leaves as covers or end-papers." Bowers, from the other side: "Even when
normal printing practice might lead one to expect economical machining without
blanks, it is dangerous, lacking proof, to assume their absence." So the
program does it three times in four and leaves the paper white otherwise.

### Cancels

A leaf cut out and another pasted to the stub. The obvious objection is that
cancels happen for reasons no simulation can produce — the Privy Council took
exception to *Eastward Ho*. McKerrow gets there first and settles it:

> **Into the purpose of these cancels we need not enter.** There may have been
> in the original print something so grossly incorrect that it was too much for
> even the easy-going printer of the day — or for the author; or, as often in
> early times, there may have been something that the authorities found
> objectionable. **The point at present is the aid that bibliography gives us
> in detecting them.** (p. 223)

So the cause is a parameter and the trace is a simulation. Three causes, of
which only the first is modelled in the strong sense:

- **an error the program made itself** and its own corrector missed — the run
  knows what the error was and knows the proof went by without it (`--cancel-rate`)
- **a change of imprint** — the same setting with the bookseller's name
  altered, which is why a cancel title is commoner than any other kind
  (`--imprint-change`)
- **anything else** — `--cancels N`, a count and not a model, labelled as such
  in the report

The trace is complete: the leaf cut out leaving a stub, the replacement printed
in the white paper at the end of a gathering — Gaskell has Rousseau's publisher
"encourag[ing] the author to use up the blank leaves of final sheets for
printing cancels" — or costing a half-sheet of its own when there is none. And
five of McKerrow's six detection tests (p. 224) are generated as properties of
the particular leaf. The sixth is the paper.

### The heaps, and the copies gathered from them

The stage at which the copies of one impression stop being interchangeable, and
the place where two authorities meet.

**Gaskell supplies the mechanism** (pp. 143–4). The heaps are set out in
signature order and gathered from the top of each. For a sheet perfected inner
forme first they are gathered "in the reverse of the printing order, so that
the first book to be gathered contained the last printed sheets"; for one
perfected outer forme first the heap "had to be turned over… This heap was then
gathered in the printing order". So a made-up copy is **not** a random handful
of corrected and uncorrected sheets. The copies lie in one linear order, each
variant divides that order where the corrected proof came back, and which side
is corrected says which forme of that sheet went to press first.

**Greg supplies the test.** His calculus assumes simple transcription, and warns
that where "the grouping is throughout random or if inconsistent forms are of
frequent occurrence… some sort of conflation has somewhere to be assumed"
(*The Calculus of Variants*, p. 43). A made-up copy of a printed edition is
conflation by construction — it descends from no other copy but is assembled
from as many heaps as there are sheets. Drawn independently the groupings
cross; gathered as Gaskell describes they are prefixes and suffixes of one
order, hence nested or disjoint, which is exactly Greg's condition for
consistency: "given any two constant groups, either these or their complements
are either mutually exclusive or one wholly includes the other" (p. 12).

Measured over 25 runs of ten copies:

| `--heap-disorder` | Greg-consistent |
|---|---|
| 0.0 — Gaskell's "case of remarkable regularity" | 60 / 60 |
| 0.15 — the default | 37 / 60 |
| 0.5 | 29 / 60 |
| 1.0 — an independent draw per forme | 16 / 60 |

The last row is what this program did until the heaps were modelled. The
parameter between them carries no authority: Gaskell says only that the order
was likely but "not certain" to survive the drying rack.

### Gathering, folding and binding

The one stage at which the *book* diverges from the *printing*. Two hands in
two places: the warehouseman gathers in the printing house, walking the line of
heaps and taking one sheet from each (Gaskell, pp. 143–4); the binder folds and
sews later and elsewhere. Between them they can drop a sheet, take two, put one
in backwards, or sew them out of order — and the whole apparatus of signatures
exists to stop two of those:

> It was necessary, when assembling the sheets of a book, to get them the right
> way up and in the right order; and to this end each sheet was signed on the
> first page with a letter of the alphabet … in order to help the binder with
> his folding. (Gaskell, p. 79)

That sentence is the design. The *kinds* of fault come from the sources, as
does the fact that made-up books were collated before they went out. **The rate
does not.** Neither Gaskell nor McKerrow gives one, so `--binding-error` is a
parameter with no authority claimed for it, and the report prints the
disclaimer beside every fault it lists. What is not invented is the shape: an
unsigned gathering is likelier to go in wrong, and likelier to survive the
warehouse's check when it does, because the check is the signatures too.

### Justification

Spaces are quantised — em, en, thick, middle, thin, hair — and a line is
justified by choosing among them, not by stretching continuously. When no
combination fits, the compositor reaches for something else: a different
spelling, an abbreviation, a turned-over word, a divided word. The order in
which he reaches is a ranked table of violence to the copy.

This is where habit and necessity become impossible to separate, and it is the
caveat Hinman states about his own method (i. 186–7): a spelling forced by a
tight measure is not evidence of the man who set it.

### Stints

Compositors do not alternate. A man takes the frame and holds it for several
sheets together, and the next man is whoever is free rather than the next in
turn. McKenzie, from the Cambridge Vouchers: when two or more men worked on a
book "they did not work together setting sheet and sheet about. What usually
happened was that one took over where the other left off and then composed as
many sheets as the master found convenient or as other commitments allowed"
(i. 107).

His quarto Virgil: Bertram set A–E, Crownfield F–3G, Michaelis 3H–3Z, Bertram
again to 4F, Délié the single sheet 4G, Crownfield from 4H, Bertram finishing.
Long blocks, one man returning three times, the odd single sheet where somebody
was free. `--stint-sheets` sets the mean block length.

The uncomfortable consequence: those boundaries fall where the shop's *other*
commitments put them, so "the compositorial pattern within any such book will
rarely have any internal significance." It records the house's other work.

### The lexicon

For most of its life this program had no dictionary. Its spelling devices were
rules — strike off a terminal `-e`, double a consonant, add an `-e` to fill a
line — and nothing checked the result. A rule so arranged produces `theere` and
`manne` as readily as `heere` and `doe`, and did.

The remedy is a reversal of authority. **The lexicon says which spellings
exist; the rules only choose among them.** A device that can select but not
invent cannot fabricate a spelling, however tight the line.

`lexicon/eebo-1580-1640.rktd` holds **318,722 spellings attested in 5,287 books
printed 1580–1640**, in 45,719 variant groups, with 18,562 mapped to the form
still current. It answers three different questions:

| question | procedure |
|---|---|
| is this a real spelling? | `attested?` |
| is it one anybody actually used? | `plausible?` |
| how else was this word spelt? | `variants-of` |
| which spelling is standard? | `commonest-form` |
| which is still current? | `modern-form` |

`plausible?` is the useful one, and a big corpus is what makes the difference
matter. `theere` occurs 17 times against 145,517 for `here` — not a spelling
anybody chose, but the sweepings of a very large floor. Beside it `manne` at
1,147 and `somme` at 467 are real usage. The threshold is one occurrence in two
hundred, stated in the open rather than buried.

**How the grouping works.** Without a modern wordlist to anchor it, `her`
becomes a spelling of `here` — the reduction that correctly joins `heere` to
`here` joins `here` to `her` by identical steps. What separates them is that
`her` is itself a current word, and a current word is not a misspelling of
another. So:

1. reduce each form to a **skeleton** collapsing the period's alternations —
   `u`/`v`, `i`/`j`, doubled letters, terminal `-e`
2. split each group against a modern wordlist, so every current word keeps its
   own variants and takes none of its neighbour's
3. assign each old form to the single **nearest** current word by edit distance,
   so `heere` goes to `here` (one letter) and not also to `her` (two)

It still errs: `runne` is assigned to `rune` rather than `run`, being nearer.
Nothing about the letters separates that from `heere`/`here`, where distance
gives the right answer — which is why VARD and its relatives keep a human in
the loop, and why `--modern-spelling` is approximate.

**Rebuilding it** — for another period, another kind of book, or a narrower
window. Two commands and about an hour:

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
transcription slip as a spelling); `--modern` supplies the anchor, and the
builder warns if you omit it.

A run picks its lexicon in this order: `$HANDPRESS_LEXICON`, then the shipped
one, then `samples/ado-lexicon.rktd` — 2,370 forms from the two *Much Ado*
texts. The last is kept because it is small enough to read and because the
difference is instructive: on the same copy, words altered to fit the measure
rise from 8.70 per thousand to 29.38 once a real corpus is behind them.

The modern wordlist is a **build input** and is not redistributed; only its
verdict on public-domain forms is.

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

| parameter | in the real books | first guess | now |
|---|---|---|---|
| the fount | 21,953 sorts, ~120 lb (Okes, *Lear* Q1) | 60,000 | 31,200 incl. space |
| tilde abbreviations | 1.01 / 1000 words (English, 1600s) | 83 | 1.66 |
| superscript `yᵗ`, `wᶜʰ` | 5.5 per **million** words | 6,600 | ~0 |
| foul case + turned letters | 0.25 / 1000 words | 11.57 | 0.87 |
| word division | 5.1 / 100 lines | 0.0 | 5.3 |
| medial apostrophes (`rul'd`) | 9.58 / 1000 words | 1.17 | 5.37 |
| ampersand | 3.18 / 1000 (English, 1600s) | 35 | 3.02 |
| class spelling habits (`-ie`, `-ll`) | 57% (Blayney) | 82–91% | 57% |
| wrong-fount sorts | a handful a book | 248 | 13 |
| gaps a compositor could set | every one | 14% | 95% |

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

They are not of one kind, and the difference decides how much weight a claim
will bear.

### The manuals — written by printers, for printers

The only sources that describe the work from inside. They describe it as it
*ought* to be done, which is their strength and their limit.

- **Joseph Moxon**, *Mechanick Exercises on the Whole Art of Printing*
  (1683–4) — the lay of the case, the quantities of the spaces, the reaching,
  and the reader who speaks the copy aloud to the corrector
- **John Smith**, *The Printer's Grammar* (1755) — later, and useful mainly
  where it confirms Moxon

### The archives — records made at the time, for other purposes

Which is what makes them evidence rather than inference. Nearly every
correction this program has had to make came from the first of these.

- **D. F. McKenzie**, *The Cambridge University Press 1696–1712: A
  Bibliographical Study*, 2 vols (1966) — production times, compositors'
  output in ens, the finding that setting by formes was *not* normal, and the
  Vouchers showing men taking over from one another in long blocks
- **Percy Simpson**, *Proof-Reading in the Sixteenth, Seventeenth and
  Eighteenth Centuries* (1935; repr. 1970 with Harry Carter's foreword, where
  most of the corrections to Simpson actually are)

### The analyses — reconstructions from the printed books

The New Bibliography. This program stands oddly towards it: implementing the
method in order to test it, and reporting where it fails.

- **Charlton Hinman**, *The Printing and Proof-Reading of the First Folio of
  Shakespeare*, 2 vols (1963) — the largest single debt. Compositor spellings,
  type recurrence, proof-reading, the pagination errors, and the caveat about
  justification the whole method turns on
- **W. W. Greg**, *The Shakespeare First Folio* (1955)
- **Fredson Bowers**, *Principles of Bibliographical Description* (1949) — the
  form of the description
- **Peter W. M. Blayney**, *The Texts of King Lear and their Origins* (1982) —
  Okes's compositors, copy preparation, and the practice of tabulating
  justified and unjustified occurrences apart
- **R. B. McKerrow**, *An Introduction to Bibliography for Literary Students*
  (1927) — imposition, signing, catchwords
- **Philip Gaskell**, *A New Introduction to Bibliography* (1972) — the bill
  of letter, casting off, formats, and the shop-size rule for dividing copy;
  and "The lay of the case", *Studies in Bibliography* xxii (1969)
- **Thomas Satchell** (1920), extended by Willoughby — the first of the
  spelling tests, which Hinman built on

### The objection

- **D. F. McKenzie**, "Printers of the Mind", *Studies in Bibliography* xxii
  (1969) — the paper this program cannot answer and does not try to

### Texts and data

- **Internet Shakespeare Editions** — old-spelling transcriptions of the
  *Much Ado* quarto and Folio, used for calibration
- **H. H. Furness**, ed., *Much Ado About Nothing*, New Variorum (1899) — the
  collation those measurements are checked against
- **Richard Mulcaster**, *The First Part of the Elementarie* (1582) — the
  General Table of some 8,000 words in the spellings he recommends, and the
  rule that a terminal E lengthens the vowel before it
- **EEBO-TCP Phase I** — public domain since 2015 under the ODC-PDDL; the
  5,287 texts printed 1580–1640 are the attestation lexicon
- **Baron & Rayson**, *VARD 2* (2008) — not used, but it solves the same
  variant-grouping problem, and its design settles a question met here
  independently

## What next

See [ROADMAP.md](ROADMAP.md). The preliminaries, the signature series, the
generated title-page and the binder's errors are built. Two things are next,
and both are about grading the method rather than extending the simulation.

**Correlated press-variant states.** Gaskell describes the mechanism and this
program does not have it: the sheets are gathered from the tops of the heaps in
signature order, so "the order of printing may have been echoed, either
directly or inversely, by the order of gathering" (pp. 143–4), and which way
round depends on whether the sheet was perfected inner-forme-first. A copy is
therefore not a random draw of corrected and uncorrected states but a
systematic one. `press.rkt` still rolls every forme independently. Build it and
the analysis can be asked a question with a right answer: from a handful of
collated copies, recover the order of printing.

**Recovering forme order from type recurrence** is the real prize, because it
is Hinman's central method and this is the only place it can be graded against
a known truth — Blayney even supplies the threshold at which he says it must
fail.

## Licence

MIT.
