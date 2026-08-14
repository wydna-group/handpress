# Calibration

Every figure this program is judged by, what it is judged against, and **when it
was last regenerated**. Nothing here is quoted in the README or the ROADMAP
without a pointer back to this file.

This file exists because of a specific failure. Three separate "discrepancies"
between the model and its sources were chased in one session and **all three
dissolved once the spread was measured** — the model side was a single draw, or
the source side was a median, or the source side was three events printed to two
decimals. A point compared against a point manufactures gaps that are not there.

So every row carries, where it can:

- **the spread on the model side** — several seeds, never one run;
- **the spread on the source side** — how many observations are behind the
  figure, and what interval that implies;
- **the stage** each side was measured at. A rate diffed out of a printed book
  counts what *survived* the corrector; the rate a program is set to is what the
  compositor *makes*. These are different quantities and the table used to
  compare them without saying so.

**Regenerate before quoting.** The commands are at the foot of each section.

---

## The First Folio — the standard hard case

*Regenerated 2026-08-14. Four seeds (1623, 11, 22, 44), `--edition 1200`,
`--copies 4`, five compositors, folio in sixes on crown paper.*

> **Do not read a seed's column against the same seed's column in an older
> version of this file.** A seed names a run of the random stream, not a book,
> and any change that alters how many draws are taken before a decision moves
> every decision after it. The casting-off work of `2b0f8f5` repaginated
> Areopagitica from 60 leaves to 64 on one seed; on seed 44 this Folio is now
> 954 pages where it was 948. The per-seed columns are here to show the
> **spread**, and only the spread and the mean may be compared across versions.
> Chasing a per-seed difference cost a session once; see FINDINGS.

```sh
python tools/fetch-folio.py     # not committed; rerun to obtain the copy
racket main.rkt --format folio6 --paper crown --compositors A,B,C,D,E \
  --kind drama --year 1623 --edition 1200 --copies 4 --copy-texts 0 \
  --seed 1623 --quiet -o out-folio folio/folio.tei.xml
```

Copy: about 864,000 words in every run. Pages and formes were once fixed at 948
and 474 whatever the seed; since the casting off acquired two regimes they are
not, and seed 44 gives 954 and 480.

### Against the record

| | 1623 | 11 | 22 | 44 | mean | recorded | source |
|---|---|---|---|---|---|---|---|
| pages | 948 | 948 | 948 | 954 | **950** | 908 | the book |
| press variants | 346 | 531 | 321 | 428 | **407** | "just over 500" | Hinman, Norton, p. xx |
| formes corrected mid-run | 105 | 100 | 111 | 117 | **108** of 474–480 | ~100 of ~450 | ibid. |
| formes proofed | 121 | 110 | 130 | 134 | **124** of 474–480 | — | — |
| word divisions / 100 lines | 1.78 | 1.80 | 1.72 | 1.70 | **1.75** | 2.03 | measured, 790 plates |

**The variant count runs 321 to 531 — a 1.65-fold spread — and its mean now sits
about a fifth below Hinman's figure**, where the previous four seeds gave 368 to
624 and a mean of 484 that straddled it. The two sets of four overlap heavily and
the difference of means is not significant (unpaired *t* ≈ 1.1 on 6 df), but four
seeds cannot detect a shift of that size either, so this is *no evidence of a
change* rather than evidence of none. It was run down commit by commit and no
mechanism was found: `press.rkt` is untouched between the two, misreadings still
survive to print at 100%, and the whole of the movement is re-randomisation and a
changed pagination. Formes corrected, the steadier row and the one `--proof-rate`
is set against, barely moved: 112 to 108.

Every calibration decision recorded in `press.rkt` (proof rate 0.6, then 0.28,
then 0.224) was argued from a *single* full Folio before that spread was known.
Read the row as a range.

Formes corrected is the steadier of the two and is the quantity `--proof-rate` is
set against, which is why it is set against that one.

### What was done to the pages

| per book | 1623 | 11 | 22 | 44 | mean | the bound |
|---|---|---|---|---|---|---|
| crowded | 132 | 151 | 169 | 145 | **149** | — |
| spun out | 168 | 162 | 148 | 156 | **159** | — |
| *either* — miscast | 300 | 313 | 317 | 301 | **308** of 950 (324/1000) | Blayney: "the page-depth is almost entirely consistent" |
| lines of copy dropped | 323 | 276 | 324 | 313 | **309** | McKerrow: "as occasionally happens" |
| catchwords not answering | 99 | 90 | 98 | 97 | **96** | Blayney: "most of the catchwords are right" |

Both bounds are qualitative and neither source gives a rate. **A third of pages
miscast still fails Blayney**, and that is the honest reading — but it was 717
per 1,000 before the casting-off work of 2026-08-12 and is 324 now.

Catchwords not answering rose from a mean of 74 to 96 when the catchword came to
be taken from the copy (`e70d054`) rather than from the next page's first word.
That is the mechanism working: a catchword set from a word the compositor then
lost his place over is *supposed* to fail. At 96 of about 943 set, some 90% still
answer, which is the side of "most" the source asks for. The spread also
tightened, 63–91 to 90–99, which is what a real mechanism replacing a lucky
accident looks like.

### The compositor's faults

| per book | 1623 | 11 | 22 | 44 | mean | note |
|---|---|---|---|---|---|---|
| accident of the case (made) | 822 | 854 | 913 | 880 | **867** | foul case, turned letters, wrong fount |
| — left standing in one copy | 675 | 694 | 726 | 718 | **703** | what a diff against the copy-text would find |
| pointed otherwise than the copy | 226 | 233 | 255 | 250 | **241** | a stop dropped, changed, or intruded |
| he lost his place | 20 | 30 | 19 | 22 | **23** | a word or two dropped or doubled at a page join |
| faults of impression | 506 | 511 | 509 | 456 | **496** | a lead showing, a sort standing proud |

**Faults of impression are not press variants** and must never be added to that
count: mending one alters no reading, so no collation of any number of copies
can find it. They are counted apart for that reason.

---

## Rates against real books

*The stage each side was measured at is given, because for at least one row it
decides whether the two agree.*

| parameter | in the real books | stage | the model | stage | verdict |
|---|---|---|---|---|---|
| foul case + turned letters | **0.25 / 1,000 words** — 3 events in 11,990 (two `Leonato`/`Leonata`, one `tongues`/`tongnes`); exact Poisson 95% CI **0.05–0.73** | survived the corrector | 0.96 made, **0.76 survives** (Folio, 4 seeds) | both printed | **inside the interval at the right stage, outside it at the wrong one** |
| tilde abbreviations | 1580s median **2.99** (p75 5.85, p90 9.65); 1600s **1.11** (p75 2.51); 1620s **0.25** (p75 0.83). 51/78/83 English books ≥2,000 words | printed | 1585 **5.01–7.13**; 1605 **1.71–2.40**; 1625 **0.16–0.87** (4 seeds, *Areopagitica*) | printed | **between median and p75 at every date** — inside the distribution, on the high side of it |
| wrong-fount sorts | "a handful a book" | survived the corrector | **1,947** on the Folio, 2.25 / 1,000 words | 0.5% corrected; the rest print in every copy | ✱ **not comparable** — see below |
| internal space | ~9% (Blayney, ten 20-line samples off *Lear*) | printed | 11.57% (Moxon ladder) | printed | short, and §5's residual |
| word division, prose plays | 6.41 / 100 lines (Norton, 790 plates) | printed | 5.88 | printed | short by the same proportion |
| roman lower-case alphabet | 11 ems (Smith, p. 158) | — | **10.95 ems** | — | 0.5%, and the only row right first time |
| the heavy medial stop | colon is **70%** of colon+semicolon in the 1600s, **35%** by 1640; 300 English books ≥2,000 words, medians by decade | printed | **66.5%** at 1600, **32.7%** at 1640 (*Areopagitica*) | printed | **within 4 points at both ends, and the trend reverses in the right direction** |

✱ **Wrong fount compares across stages and is the one known fault in this
table.** Hornschuch names it as something the corrector cleared; this program
classes it as a *shift* — a shop expedient, like robbing a sort — so the
corrector's own path never offers him one. It belongs with the faults of
impression, being visible on the page and changing no reading. Unfixed.

Two corrections to what this note used to say, both found on 2026-08-14:

*Not quite never.* **Ten of the 1,947 are corrected at press, 0.5%** (and 26
cannibalized borrows with them). They arrive by the other door: the corrector's
copy-comparison scan catches anything whose printed form differs from the copy,
and a borrowed sort that happens to print `V` for `U` differs. `DVKE. ] DUKE.`,
`QVICKLY. ] QUICKLY.` So the reading is "almost never", not "never", and the
mechanism by which the few escape is worth knowing before the row is fixed.

*And it was not measurable.* The only figure the report gave was **375,852
shifts**, which is the whole `'shift` kind and is 98% space-metal — 367,822
whites made up of smaller pieces. Nothing printed distinguished the five causes,
so this row's number could not be got from the report at all. It now can:

```
Shifts made for want of a sort: 375852
  wrong-fount      1947
  cannibalized     4524
  face-down         603
  another-sort      956
  space-metal    367822
```

**Pointing was a habit and the program had it only as an error.** Measured on
its own output before this was built, the model's pointing was its copy's
pointing to within the error rate — comma 85.3 per 1,000 in the copy against
78.7 on the page, semicolon 11.1 against 10.0. It was making no choices at all,
while Blayney identifies a workman by his pointing and his capitals as readily
as by his spelling.

The corpus settles the one choice that leaves an unambiguous trace, per 1,000
words, medians over 300 books:

| decade | 1580 | 1590 | 1600 | 1610 | 1620 | 1630 | 1640 |
|---|---|---|---|---|---|---|---|
| colon | 9.8 | 10.7 | 11.1 | 12.5 | 7.9 | 7.3 | 6.8 |
| semicolon | 6.6 | 6.2 | 4.7 | 9.3 | 10.4 | 9.5 | 12.5 |

**A modernised copy-text has this the wrong way round**, an editor putting
semicolons where the printer set colons: *Areopagitica* as this program receives
it reads semicolon 11.1 against colon 3.2, which is the 1640s ratio inverted.
The compositor now sets the heavy stop his period set, selecting between two
marks his copy already uses and inventing neither.

What is matched is the **share**, not the density. The model reads colon 8.6 per
1,000 against the corpus's 11.1, because it chooses among the heavy stops the
copy has and does not add any. Whether a compositor also pointed *more* than his
copy is a separate question and is not modelled.

**Capitalisation, the same evidence and the same shape.** The measurement gives
**10.5% of mid-sentence words capitalised, 5.7% once the word-types capitalised
nine times in ten are dropped as proper names** — and the words that vary are
exactly Blayney's kind of marker: `king` 78.7%, `church` 87.1%, `faith` 20.6%,
`loue` 10.1%. `tools/build-capitals.py` writes the 3,761 of them to
`lexicon/capitals-1580-1640.rktd` with each one's share, and the rule selects
from that table, so it cannot invent a capital any more than a spelling device
can invent a spelling. The model reads **9.2%** against the copy's 4.2%.

Two difficulties dissolved rather than being solved, and both are worth knowing.
A capital falls on a noun and there is no part of speech here — but the corpus
names the words, so none is needed. And the count is of MID-SENTENCE words —
but the rule only ever adds a capital to a word the copy left in lower case, and
a word opening a sentence arrives with one already, so the restriction enforces
itself and no sentence tracking is needed either.

**The workmen do not differ, and that is deliberate.** Blayney's point is that
they do, and the corpus shows books running 6% to 17%. But no source gives a
per-compositor figure, and inventing an assignment would put a difference into
the attribution evidence that nothing measured — the fault this file exists to
prevent. Every compositor here capitalises alike.

```sh
python tools/count-pointing.py 300                          # pointing and capitals
python tools/build-capitals.py 600 > lexicon/capitals-1580-1640.rktd
racket tools/measure-spacing.rkt samples/areopagitica.txt   # space and division
racket tools/measure-castoff.rkt --kind drama folio/folio.tei.xml
```

---

## The analysis, graded against the truth it knows

*Measured 2026-08-13 and **not re-measured since**, unlike every other table in
this file. Read these as the most recent figures, not as current ones.*

Three mechanism commits have landed since, and two rows are known to sit on
quantities that moved. **Perfecting order** is read off press variants, and those
fell from a mean of 484 to 407. **Compositor attribution** is read off spelling,
and the lexicon now gates every device that produces it. The rest rest on type
recurrence and are less exposed, but all of them were taken before the random
stream shifted, and none has been re-run. Re-running them is the next thing this
file needs.

| method | result | note |
|---|---|---|
| Hinman's forme order, folio in sixes | **11 of 76 quires determined; 11 of 11 right** | right whenever it speaks; it speaks rarely at this fount |
| the chaining that fixes direction | **12 of 12** (20 seeds, one forme standing) | ROADMAP §1 |
| Turner's rule, quarto | pattern in 96% by formes / 82% seriatim; **57% as a test of method**; names the first-distributed forme **54 of 54** | Blayney's objection, measured |
| Turner's rule, folio in sixes | **12 of 12** over six seeds | was reading 0 of 37 until 2026-08-12; two compounding bugs |
| perfecting order from press variants | **322 of 322 formes**, direction a coin (30/30 over 60 runs) | chance floor 0.64, printed beside it |
| Greg's consistency, 10 copies | holds at every disorder | blind: the copies stand further apart than a sheet can travel |
| Greg's consistency, 60 copies | fails 25 of 25 at total disorder | the detector working |
| compositor attribution, Folio, 5 men | **33–34% of attributed pages right** | A and D share every preference; no spelling test parts them |
| compositor attribution, *Areopagitica*, 2 men | 101 of 114 | the figure the README quotes; different population |

---

## The apparatus

*Regenerated 2026-08-14, `samples/areopagitica.txt` at folio in sixes.*

Every mechanism must name itself in the tooltip and carry its own colour, or the
table and the page will disagree about the same word.

| | |
|---|---|
| marked words on the page | 1,611 |
| **without a tooltip** | **0** |
| **whose tooltip opens with a fault other than the one they are coloured by** | **0** (was ~40) |

The count fell from 2,056 when the lexicon came to gate every device
(`ad99ada`): the marks that went were spellings no one ever wrote, and a device
that can select but not invent cannot make them. Do not read the fall as lost
coverage.

A tooltip names its mechanism, but not always by the taxonomy's word for it —
about a sixth open in the compositor's terms instead, `the ſ box was empty, so
it was set s` for a substitution, `no sort to set "and" with` for a wanting
sort. That is the house style and not a defect; a checker that matches the kind
name literally will report them and be wrong.

```sh
racket main.rkt --format folio6 --kind prose --seed 5 --html -o out samples/areopagitica.txt
```

---

## What is not measured here

- **Watermarks and chain-lines** — not modelled at all; the largest single gap.
- **Concurrent production** — McKenzie's central finding, and this models one
  book at a time.
- Eight knobs with **no source behind them at all**: `--binding-error`,
  `--heap-disorder`, `--impression-faults`, `--mis-resume`, `--mis-point`,
  `--mis-space`, `--mis-transpose`, `--mis-drop`. Each prints its disclaimer
  beside its count. They are parameters, not findings.

  Two of them are at least *proportioned* to something. `--mis-point` (0.0003)
  and `--mis-space` (0.00045) are set from the shares of the one proof-corrected
  Folio page — punctuation two of its twenty corrections, spacing three — and
  never from its density, which is eight times the book's average and worthless.
  A share survives a bad page; a density does not. Neither is set to bring the
  variant total to Hinman's figure, and the total is left where it falls.
  Anything drawn from the **ratio within** spacing, two words run together
  against one opened, is resting on three instances and should say so.

  `--mis-drop` (0.0004) is bounded from the other side, and by evidence that
  contradicts itself usefully. **Neither proof census shows a dropped word**;
  **half of Gascoigne's fifty-one errata are dropped words**. Both hold, because
  a corrector can see a sense break but cannot supply the missing word without
  the copy — so the fault is rare among proof corrections and common among what
  reached the reader. Errata are besides selected for severity (Lambard prints
  only the "most daungerous"), which inflates a sense-perverting fault further.
  Half is therefore a **ceiling**, and the rate is set well under it: 6 against
  36 misreadings on one book. Quote the inequality, not the six.

  **Dittography has no knob and is the model for the rest.** It is the eyeskip
  slip run backwards, so it takes the eyeskip rate rather than one of its own —
  the claim being only that an eye returning to the wrong one of two like words
  does not favour the earlier over the later. A mechanism that borrows the rate
  of the one it mirrors adds no parameter to this list, and that is worth more
  than a well-argued number.

  `--mis-transpose` (0.0001) has not even a share behind it, and is the one
  place in this file where a number stands for an **inequality**. A word
  transposition appears in neither itemised census — none of the Folio page's
  twenty corrections, none of the dozen from the Grete Herball — while pointing
  appears in both. Zero in about thirty-two gives a bound and not a rate, so it
  is set below the pointing rate and **what may be quoted from it is the
  ordering**: transposed under pointed under spaced, which one book gives as 2,
  5 and 6. The third-of-pointing is arbitrary; the inequality is not.
- The Folio's four *derived* rows — verse share, impressions before correction,
  identifiable types per page, characters to a line — are measured outside the
  report and have **not** been regenerated since the space ladder changed on
  2026-08-12. Do not quote them.
