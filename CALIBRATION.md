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

*Regenerated 2026-08-13. Four seeds (1623, 11, 22, 44), `--edition 1200`,
`--copies 4`, five compositors, folio in sixes on crown paper.*

```sh
python tools/fetch-folio.py     # not committed; rerun to obtain the copy
racket main.rkt --format folio6 --paper crown --compositors A,B,C,D,E \
  --kind drama --year 1623 --edition 1200 --copies 4 --copy-texts 0 \
  --seed 1623 --quiet -o out-folio folio/folio.tei.xml
```

Copy: 864,000 words in every run; 948 pages; 474 formes. Those three do not move
with the seed and are the same book each time.

### Against the record

| | 1623 | 11 | 22 | 44 | mean | recorded | source |
|---|---|---|---|---|---|---|---|
| pages | 948 | 948 | 948 | 948 | **948** | 908 | the book |
| press variants | 478 | 624 | 465 | 368 | **484** | "just over 500" | Hinman, Norton, p. xx |
| formes corrected mid-run | 107 | 119 | 118 | 106 | **112** of 474 | ~100 of ~450 | ibid. |
| formes proofed | 118 | 134 | 129 | 118 | **125** of 474 | — | — |
| word divisions / 100 lines | 1.79 | 1.72 | 1.72 | 1.72 | **1.74** | 2.03 | measured, 790 plates |

**The variant count runs 368 to 624 — a 1.7-fold spread — and its mean straddles
Hinman's figure.** Every calibration decision recorded in `press.rkt` (proof rate
0.6, then 0.28, then 0.224) was argued from a *single* full Folio before that
spread was known. Read the row as a range.

Formes corrected is the steadier of the two and is the quantity `--proof-rate` is
set against, which is why it is set against that one.

### What was done to the pages

| per book | 1623 | 11 | 22 | 44 | mean | the bound |
|---|---|---|---|---|---|---|
| crowded | 123 | 137 | 129 | 131 | **130** | — |
| spun out | 177 | 187 | 155 | 193 | **178** | — |
| *either* — miscast | 300 | 324 | 284 | 324 | **308** of 948 (325/1000) | Blayney: "the page-depth is almost entirely consistent" |
| lines of copy dropped | 232 | 318 | 214 | 275 | **260** | McKerrow: "as occasionally happens" |
| catchwords not answering | 66 | 91 | 63 | 76 | **74** | Blayney: "most of the catchwords are right" |

Both bounds are qualitative and neither source gives a rate. **A third of pages
miscast still fails Blayney**, and that is the honest reading — but it was 717
per 1,000 before the casting-off work of 2026-08-12 and is 325 now.

### The compositor's faults

| per book | 1623 | 11 | 22 | 44 | mean | note |
|---|---|---|---|---|---|---|
| accident of the case (made) | 835 | 812 | 818 | 864 | **832** | foul case, turned letters, wrong fount |
| — left standing in one copy | 653 | 629 | 636 | 714 | **658** | what a diff against the copy-text would find |
| pointed otherwise than the copy | 244 | 244 | 236 | 267 | **248** | a stop dropped, changed, or intruded |
| he lost his place | 18 | 23 | 17 | 23 | **20** | a word or two dropped or doubled at a page join |
| faults of impression | 509 | 512 | 513 | 456 | **498** | a lead showing, a sort standing proud |

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
| wrong-fount sorts | "a handful a book" | survived the corrector | **1,996** on the Folio, 2.31 / 1,000 words | **never corrected here** | ✱ **not comparable** — see below |
| internal space | ~9% (Blayney, ten 20-line samples off *Lear*) | printed | 11.57% (Moxon ladder) | printed | short, and §5's residual |
| word division, prose plays | 6.41 / 100 lines (Norton, 790 plates) | printed | 5.88 | printed | short by the same proportion |
| roman lower-case alphabet | 11 ems (Smith, p. 158) | — | **10.95 ems** | — | 0.5%, and the only row right first time |

✱ **Wrong fount compares across stages and is the one known fault in this
table.** Hornschuch names it as something the corrector cleared; this program
classes it as a *shift* — a shop expedient, like robbing a sort — so no corrector
is ever offered it and every one prints in every copy. It belongs with the faults
of impression, being visible on the page and changing no reading. Unfixed.

```sh
racket tools/measure-spacing.rkt samples/areopagitica.txt   # space and division
racket tools/measure-castoff.rkt --kind drama folio/folio.tei.xml
```

---

## The analysis, graded against the truth it knows

*Regenerated 2026-08-13 except where noted.*

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

*Regenerated 2026-08-13, `samples/areopagitica.txt` at folio in sixes.*

Every mechanism must name itself in the tooltip and carry its own colour, or the
table and the page will disagree about the same word.

| | |
|---|---|
| marked words on the page | 2,056 |
| **without a tooltip** | **0** |
| **whose tooltip opens with a fault other than the one they are coloured by** | **0** (was ~40) |

```sh
racket main.rkt --format folio6 --kind prose --seed 5 --html -o out samples/areopagitica.txt
```

---

## What is not measured here

- **Watermarks and chain-lines** — not modelled at all; the largest single gap.
- **Concurrent production** — McKenzie's central finding, and this models one
  book at a time.
- Four knobs with **no source behind them at all**: `--binding-error`,
  `--heap-disorder`, `--impression-faults`, `--mis-resume`, `--mis-point`. Each
  prints its disclaimer beside its count. They are parameters, not findings.
- The Folio's four *derived* rows — verse share, impressions before correction,
  identifiable types per page, characters to a line — are measured outside the
  report and have **not** been regenerated since the space ladder changed on
  2026-08-12. Do not quote them.
