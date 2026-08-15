# Roadmap

**What is wrong with the program and what to do about it.** Ordered by evidential
value rather than by effort: the question asked of each item is not "would this be
interesting?" but **"would this let the program be wrong in a way we could
detect?"** — which is the only thing it has ever been good for.

Each section says where it stands, what is open, and what would settle it. Nothing
here narrates how it got there.

| | |
|---|---|
| **[README.md](README.md)** | what the program does |
| **[CALIBRATION.md](CALIBRATION.md)** | every figure it is judged by, with seeds, spreads and the date each was regenerated — **quote numbers from there, not from here** |
| **[FINDINGS.md](FINDINGS.md)** | what was got wrong and how it was found out; the wrong turns worth not repeating |
| `.claude/skills/handpress/` | the working discipline, and the rules this project runs on |

The rules used to live at the foot of this file. They are in the skill now, where
they are loaded before the work rather than found after it.

**Six items below came out of one afternoon's reading of Moxon and Smith**, the
two printers' manuals this file had listed as sources for a year while every
figure from them arrived second-hand. A seventh came out of Simpson the same way.
They are marked **[manuals]**. Reading them directly cost less than any of the
work they invalidated.

**§12 is nine-tenths built** and what remains in it waits on §11's anchor. **The
live items are §11** — a copy→print pair that can see punctuation and spacing —
**and §8**, the concurrency experiment, which is the only one that asks whether
the apparatus means anything at all.

---

## 1. Forme order from type recurrence

**Built and graded. Hinman's method works exactly as he claims, and what varies
is how often it can speak.**

His criterion is a hard constraint, not a score: "the second of two consecutive
formes was set before the first was distributed, and hence the two cannot
ordinarily have types in common" (i. 80). Sharing a type forbids adjacency, the
order of a quire is whatever arrangement breaks no prohibition, and the reading
is trustworthy exactly when one arrangement survives. `formeorder.rkt` enumerates
the 720 arrangements of a six-forme quire outright; there is no search.

| | |
|---|---|
| where one order survives, it is the true order | **26 of 26** |
| the chaining that fixes direction across a quire boundary | **13 of 13** |
| Turner's rule, as a test of setting method | **57%** against a coin's 50% |
| Turner's rule, naming the forme distributed first | **100%**, quarto and folio alike |
| quires determined at one forme standing / at two | 80% / 50% |

**Quarto is outside the method entirely** — two formes have one order up to
reversal, so the criterion is vacuously satisfied. The report says so rather than
printing a hollow 100%.

**Open.** Two mechanisms Hinman names and this does not model, both of which
would make the method *harder* and therefore more honest:

- **the printers culled the worst types** — "any especially striking abnormality
  is, as a rule, soon noticed by the printers themselves, who at once cull the
  peccant type", so the grossest injuries leave the case early and are not the
  best evidence;
- **a recognisable piece can still be missed on a page** — defects "liable to be
  inked over occasionally", so recognition should be per appearance rather than
  held for the whole book, which is what makes ordering easy here.

And Blayney's density threshold is still untested: he says the order cannot be
proved unless the evidence reveals two prior distributions in every page. The
quarto sample is too short to test it and it wants the Folio copy.

*Four failed inference attempts, the anti-Robinson matrix measurement that should
have stopped them, and the direction bug a reversal-blind test could not see:
[FINDINGS](FINDINGS.md#1-forme-order-from-type-recurrence).*

---

## 2. Recovering the perfecting order — *built and graded; the direction is not there*

The prize that correlated press-variants opened. `perfecting.rkt`, reported in
full. Given the groupings and nothing else, it recovers the gathering order from
the way they nest, reads each grouping as a prefix or a suffix of it, and calls
the forme perfected first. **100% — 322 of 322 formes over 40 runs of 24
copies.** Three things have to be said beside that number, and the third was not
expected.

**The chance floor is not a half.** The metric takes the better of two
directions, so for nothing it scores `E[max(X, n−X)]/n`: 0.75 on two formes,
0.64 on eight, still 0.53 on two hundred. Against a deliberately shuffled truth
the control returns 66.5%. `chance-floor` computes it per run and the report
prints it beside the score, because a rate without the thing it should be
compared to is this project's oldest failure.

**The direction is not recoverable from press variants at all.** Calling one
class of groupings the prefixes is free; taking the other reverses the recovered
order and turns every inner into an outer at a stroke, and both readings satisfy
Greg equally. Over 60 runs the method calls it rightly 30 times and backwards 30
— a coin, measured rather than argued, and there is a test that fails if the code
ever leans either way. One external fact settles every sheet together: one sheet
ordered by type recurrence (§1), or the assumption that the shop perfected mostly
one way. Gaskell's example supposes inner-first throughout and would serve; that
is imported, not read, and is not assumed here.

**It is never partly right.** In those 60 runs not one got some formes right and
others wrong — the whole partition or the exact inverse. The method has precisely
one thing it can get wrong and gets it wrong half the time. That is a very
different failure profile from the graceful degradation §1's type-recurrence work
expects, and it is worth carrying into that work: **an inference can be
structurally certain and globally unanchored**, which no accuracy figure on its
own will show.

**And it survives what Greg's own test does not.** At 200 copies and total heap
disorder the consistency condition fails 25 times in 25 (§3) while this reads
100%. Moxon's disorder is local, at most 75 sheets; whether a grouping sits at
the head or the foot of the heap is global. A failed consistency test is not
evidence that nothing can be read off the groupings.

One limit the report now states rather than papering over: groupings cut the
gathering in one place each, so *j* variant formes distinguish at most *j*+1
positions among the copies however many are collated. Copies no variant separates
are bracketed together instead of being listed in the arbitrary order of a tie.

**Still open here**, and the reason this section is not simply deleted:

- **The analyst is handed `variant-groupings` directly**, which is a perfect
  collation. A real one misses variants and invents none; the effect of an
  imperfect eye on this inference is unmeasured, and §1's `--discrimination`
  is the model for how to do it.
- **The 100% is on one book at one format.** Nothing here has been run at folio,
  on a book long enough for the groupings to fall into more than one
  independently-flippable class — the component count was 1 in every run tested,
  and the report is written to handle 2^n but has never seen n > 1.

**Greg's calculus as an analysis module** is the general form of the same work:
type-1 and type-2 variants, the compounded variational formula, the resolution
of complex variants, the order-of-merit count. Two cautions from him to carry:
the **ambiguity of three texts** (with three witnesses no formal process can
establish relationship), and the **fallacy of constant variation** — that every
transcription introduces about the same number of variants, which is "quite
contrary to experience and leads to erroneous results" (p. 9n, Note C). Also his
warning that the finer the collation, the more non-evidential variants and
chance coincidences it turns up (p. 18).

**§3 is done and it changes what this exam means.** The groupings now carry
Moxon's grain, and the first consequence is known before the inference is
built: on a sparse collation the disorder is invisible, so the inference will
score better than it deserves to and the score must be read against the
spacing of the copies. Grade it at several collation sizes or it will flatter
itself.

---

---

## 3. The heaps had the wrong grain — *done, and it inverted the result* **[manuals]**

**A published number in the README was produced by a mechanism Moxon rules out.**
It was the cheapest item on the list and it changed more than expected.

`--heap-disorder` has always carried the disclaimer that no source gives its
value, and that is still true of the *rate*. But Moxon gives the **mechanism**,
and the code's was not it. `press.rkt` drew independently **per copy per sheet**:

```racket
(define ordered? (> (rnd g) heap-disorder))
```

Every sheet decided on its own whether it kept its place — white noise. Moxon,
on hanging the heap up to dry and taking it down again (pp. 311–12):

> he doubles over so much of the Heap as he thinks good, **perhaps about a
> Quire, or half a Quire, or about seventeen Sheets, more or less** … [and
> taking down] the Warehouse-keeper clapping the flat side of his Peel against
> the Right Hand edge of the Paper, **slides several Doublings over one another
> (perhaps three or four)**: And putting the Peel under them, takes them off the
> Racks, and lays them on the Heap again

The heap is taken apart and put back in **blocks of about seventeen sheets**,
moved three or four blocks at a time. Order is preserved *within* a doubling,
always. **A sheet never travels alone** — which is precisely what the per-sheet
draw made it do.

**The prediction was that block-structured disorder at the same nominal rate
would score far higher on `greg-consistent?` than the then-current 37/60 at
0.15. It does: 25/25.** And the reason turned out to be more interesting than
the number, because it is not about the rate at all.

Separating the two, over 40 heaps of 750 sheets:

| `--heap-disorder` | sheets that moved | mean travel | furthest |
|---|---|---|---|
| 0.15 — the default | 11.6% | 27 sheets | 65 |
| 0.5 | 37.4% | 26 sheets | 70 |
| 1.0 | 79.9% | 26.2 sheets | 70 |

**The rate governs how many sheets move and has no effect whatever on how far.**
That is fixed by the handful — four doublings of at most 25 sheets — and it is a
consequence of the mechanism rather than of any parameter. The old model had no
such bound: a sheet could go anywhere in the heap.

So the condition became blind, and blind in a specific way. Ten copies of a
750-sheet impression stand 75 sheets apart in the heap and no sheet travels more
than 70, so **at ten copies the condition now holds at every disorder including
1.0**, where the noise model failed a third of the time at 0.15. At sixty copies
— 12 sheets apart — it fails 25 times in 25. The README carries both tables.

**The old reading of the sample-size effect was wrong.** It was recorded as a
small-sample artefact: collate more copies, get more chances to see the lost
order. It is not about the number of copies, it is about their *spacing in the
heap* against how far a sheet can move. The same 24 copies detect the disorder
on a 150-sheet impression (43% consistent) and cannot on a 3,000-sheet one
(100%). A collation is blind to any disorder finer than its own spacing, and
the blindness is total rather than partial.

That was not tuning the disorder down until the failure went away — the rate is
untouched at 0.15 and the failure is larger than ever at a dense collation. The
noise had the wrong shape, and correcting the shape moved the answer in a
direction nobody had predicted, including this file.

**What still has no source is the rate**, exactly as before. Moxon gives the
doubling, the handful and the care taken; he does not say how often the care
failed.

Moxon supplies two further constraints while he is about it. The heaps are laid
out in signature order and gathered "**beginning at the last Heap first**"
(p. 315) — Davis & Carter flag that he contradicts himself about which end is
the left hand, and gloss the intent: the end sheet is gathered first. And the
warehouse-keeper is careful to lay every sheet so its signature falls over the
signature of the first, "**lest when the Books come to be Gathered, some Sheets
may be Turned**", which names the fault the care is against.

---

---

## 4. The space bodies — *done*

`metrics.rkt` set six space bodies dated to Jacobi 1890 in a fount of 1600. It
now sets Moxon's four — em, en, thick 1/4, thin 1/7, no middle and no hair — with
`UNITS-PER-EM` at 840 so that sevenths and sixths of the em are whole numbers.

What settled it was not the documentary case, which had been sound and unacted-on
for two sessions. It was that a *second* quantity moved the right way, one nobody
had consulted when choosing the ladder: word divisions per 100 lines, counted off
790 plates of the Norton Facsimile, closed 60% of its gap.

**Nothing further is owed here.** The residual — lines ending about 0.6 em short —
was handed to §5 and is now largely explained by the casting off, not the ladder.

*The three eliminated candidates, Smith's bill against the demand table, Blokland's
measured proportions, and the case/compositor unit disagreement the move exposed:
[FINDINGS](FINDINGS.md#4-the-space-bodies-are-jacobis-1890).*

---

## 5. Casting off — *the largest error is found and fixed; the two regimes are still unbuilt* **[manuals]**

`--cast-off` is a single accuracy scalar. **Both manuals describe something with
structure, and Smith describes two regimes whose errors behave differently.**

Moxon (pp. 239–43) counts *letters*, not words, and carries the error break to
break, settling it at each: "long Breaks in the Copy are generally likely to be
Got-in … But short Breaks often Drive-out a Line … they serve as so many
Regulators to him". Smith (pp. 155–9) knows that method and prefers marking off
every page — "the safest way; because if we fall into a mistake in one page, we
may recover ourselves in the next" — and calls the other "next to lumping the
Copy". **And the crowding devices are conditional on which was used**: a
compositor drives out or gets in "where he conveniently can … but this precaution
need not be taken where Copy is cast off the other way."

So: error bounded per page with active correction, or error accumulating with
none. **Both are now built** — `--cast-off-method pages|breaks` — with the three
differences the sources give:

| | `pages` (Smith) | `breaks` (Moxon) |
|---|---|---|
| where the error is settled | at every page, "we may recover ourselves in the next" | only at a break, his "Regulators" |
| the error carried forward | none | the drift since the last break |
| the crowding devices | used | **not used** — "this precaution need not be taken" |

**Both differences measure, and the second only where Smith says it should.**

Smith's condition shows plainly on any copy: under `breaks` the compositor
reaches for an expedient 267 times against 311, and alters 310 words to fit the
measure against 382, while quadding out is unchanged — quadding is not a crowding
device.

The drift shows nothing on ordinary copy and a great deal on close matter, which
is the whole of Smith's complaint. Isolated at the cast-off, mean distance of a
page's allotment from a full page:

| | close matter, no breaks | a break each paragraph |
|---|---|---|
| `pages` | 0.78 | 0.07 |
| `breaks` | **1.38** | 0.07 |

**The two regimes coincide exactly when breaks are frequent and part when they
are not** — Moxon's "Regulators" doing their work, and Smith's "as often deceived
by it, **especially in a long run of close Matter**". On a real book the
paragraphs fall about once a page, so the methods agree; the model reproduces the
scope of the objection rather than differing everywhere.

*This entry first recorded the drift as unmeasurable and blamed the slip
granularity. That was a probe fault: the close-matter test joined paragraphs and
so cut the prose units from 105 to 9, removing the slip draws it meant to
concentrate. **The third probe in one session to measure the wrong thing.***

**What was wrong, and is now fixed.** The dial was never the cause. At
`--cast-off 1.0`, with the deliberate error off entirely, the Folio came out
*more* miscast than at the default — the estimator carried a bias of about four
per cent that the dial was partly cancelling. Most of it was one omission: the
casting off scored a **speech prefix at nought** while `compose` sets it at the
head of the following line, where it can turn that line over. Worth 5,425 lines
on the Folio, about 5.7 a page, against a measured mean overflow of 6.19.

| per 1,000 pages | before the ladder | after it | now |
|---|---|---|---|
| miscast either way | 717 | 650 | **325** |
| lines of copy dropped | 144 | 2,780 | **274** |
| catchwords not answering | 37 | 515 | **78** |

**Still open.**

- **Nothing, on the regimes.** Both are built and both differences measure.
- **The last of the prose residual, and it is small.** The estimator divided
  total width by the measure, which assumes perfect packing and no waste at any
  line end. It now fills a stick the way a compositor does — word by word, judged
  at the finest space, since `justify` squeezes before it gives up. Measured per
  100 prose lines set: **−2.11 by division, +3.23 packed at the normal space,
  −1.12 packed at the finest**. Halved, not closed; what is left is the
  justification regime rather than the packing.
- **A third of pages miscast still fails Blayney's bound**, "the page-depth is
  almost entirely consistent", said of a book he is at pains to call badly
  printed. Neither he nor McKerrow gives a rate; both give a bound, and the
  program fails them.

*The withdrawn `NORMAL-SPACE` diagnosis, the reconciliation that found the report
had been right, the vigilance runaway, and the predicted casualty that arrived on
schedule: [FINDINGS](FINDINGS.md#5-casting-off-is-two-regimes-not-one-dial).*

---

## 6. Watermarks and chain-lines

The evidence half the rest of this depends on. The paper stock now exists to
hang them on — sheet sizes, the fold, and the leaf it makes — but a mould, its
twin, and a mark falling in the half-sheet the mould put it in are all still
wanting.

Every test in McKerrow's cancel checklist that this program cannot yet run is a
paper test: "if the paper appears to be different" (p. 224), and the chain-line
comparison of a leaf against its conjugate — "if the gatherings are of four
leaves, compare the first with the fourth, the second with the third … Are the
chain-lines the same distance apart? If not, one of the two leaves must be a
cancel."

It is also how Bowers *proved* the cut-out preliminaries of Sandys's Ovid: the
two printed leaves "are always disjunct and have any watermark on the outer
edges of the two leaves, **an impossibility if they had been printed as a fold**
in the cut-off." The program already records whether a cut-out pair was
conjugate or disjunct, so the fact the watermark would betray is in the file;
what is missing is the paper that would betray it.

**Wanted:** a stock with a mould and a twin, watermarks in the half-sheet the
mould put them in, chain-lines at a spacing per mould, and Blayney's table of
watermarks by sheet and copy (Appendix II, no. 56) as the thing to reproduce.
Position follows format and is already determined — Gaskell's Key I (p. 85):
folio, chain-lines vertical and the mark in the middle of the leaf; quarto,
horizontal and the mark in the spine fold; octavo, vertical and the mark at the
head of the spine fold.

**Note before starting that the mark will not give the size in this period.**
Gaskell lists the sixteenth-century foolscap group as carrying the Strasbourg
lily, the pot and the grapes indifferently, and warns (p. 68) that the marks
"were not used exclusively for particular sizes, especially during the sixteenth
century". A watermark is evidence about a mould, not a ruler.

**Moxon adds one thing a paper model should know** (pp. 320–3): the two outside
quires of every ream are **cording quires**, made up by the paper-maker of
"torn, wrinckled, stained, and otherwise naughty Sheets" and culled sheet by
sheet against the light. The good paper recovered from them is used deliberately
**in the middle of the book**, never at the beginning or end, "for though we
call'd it good Paper, yet it very rarely happens to be so beautiful as the
Inside Quires". The worst paper in a copy is not randomly placed.

---

---

## 7. The set widths: better anchored than this file used to claim **[manuals]**

This section used to open "the set widths are invented". That is now half wrong
and the correction is worth having.

**Smith gives an aggregate, and the table meets it.** Setting the procedure as
well as the result — put an alphabet of roman lower case in a stick and an
alphabet of italic on top of it (p. 158):

> whereas an alphabet [of 24 letters] of the **Italic** in this work occupies the
> width of **nine m's and an n**, **Roman** takes up **eleven m's**, and **Black,
> fifteen**.

`metrics.rkt`'s roman lower case, a–z less j and u, sums to **10.95 em** against
Smith's 11 — **0.5% off**, an independent period check on a table nobody had
checked. It should stop being called invented.

**What is still missing is the italic**, and the program has none:

| | Moxon (p. 243) | Smith (p. 158) |
|---|---|---|
| italic : roman | 45 : 50 → **0.90** | 9.5 : 11 → **0.864** |
| black : roman | 43 : 40 → **1.075** | 15 : 11 → **1.364** |

They are close on italic (mean ≈ 0.88) and far apart on black letter. `em-widths`
is one roman table, and Moxon sets proper names, words of emphasis and whole
title-page lines in italic (p. 216); italic set at roman widths is ~13% too wide.
Both manuals caveat their own figures the same way — Moxon: "nor all Romans of
the same Body to be of an equal Thickness, because some are Cut Thicker or
Thinner on the Face"; Smith: "it may be, that what Italic gets in upon the
Roman, is so trifling, as not to deserve regarding". So take 0.88 with the
caveat attached, not as a constant.

**Whether the per-sort widths matter is still unknown, and the attempt to find
out failed.** The branch `width-experiment` substitutes the only measured
alternative anybody has published — Blokland's appendix a5.5, Garamont / Van den
Keere's Moyen Canon Romain, sixteenth-century foundry type from the Museum
Plantin-Moretus, taken sort by sort with a digital calliper — with setting
density held constant. Across eight seeds, preliminary scheme pinned so only the
seed varies:

| | invented table | measured table | diff / sd |
|---|---|---|---|
| needing an expedient | 70.65 ± 13.86 | 75.29 ± 9.23 | 0.39 |
| a word divided at the end | 84.95 ± 19.13 | 83.50 ± 10.31 | −0.09 |
| quadded out | 169.18 ± 1.60 | 170.25 ± 1.35 | 0.72 |

Nothing there. **The seed dominates everything.** On one width table, changing
only the seed swings word division from 65.34 to 113.41 — a 74% spread.
Detecting a five-point shift against a standard deviation of fourteen would need
something like sixty runs a side, not eight.

**Two claims made from a single seed and since retracted**, recorded because the
first answer is the one that gets believed:

- *"Division rises 15.4%."* It does on seed 1614. Over eight seeds the difference
  is −1.5, and the sign reverses. Pure noise.
- *"The collation changes from `4°: *⁴ A–E⁴` to `4°: A–F⁴`."* It does not. The
  preliminary signature scheme is drawn from weights on `auto`, so any change
  upstream shifts the RNG stream and the draw lands elsewhere. Pin the scheme and
  both tables give the same collation. That was the RNG moving, not the type.

**Why the branch is not merged.** Blokland measured display sizes. Before
Benton's pantograph "every point size was a type on its own and had to be cut
separately", so these millimetres must not be scaled to a pica. That is exactly
the anchored-on-one-example error in the lessons below, and it is how the fount
came to be three times too large. What transfers is the structure.

**What transfers, and needs no new source:** widths came in shared classes
rather than a continuum. Blokland's measured groups, within 0.2–0.4 mm, are
`[a c e]`, `[b d g h n o p q v fi]`, `[i j l]` and `[r s t]`. Casting with fixed
registers is why — matrices of corresponding letters were justified to one width.
Our table gives forty-odd sorts forty-odd independent decimals.

**Still wanted: a measured text-size roman.** No book appears to tabulate one.
Vervliet catalogues types for identification — 20-line body, x-height — not
per-sort widths, and Mosley warns that type from identical matrices "may look
very different if cast in a mould for a larger or smaller body", so a set width
may not be a property of the matrices at all. Two routes: solve for widths off a
high-resolution facsimile across many lines of known content, or write to
Blokland, who has the matrices, the microscope and the method.

Smith also gives **body depths** (pp. 148–52), if bodies are ever modelled:
Great Primer : English 4:5 · English : Pica 9:10 · Pica : Small Pica 7:8 ·
Small Pica : Long Primer 14:15 · Long Primer : Burgeois 7:8 · Long Primer :
Brevier 4:5 · Burgeois : Brevier 9:8.

---

---

## 8. Concurrent production — the McKenzie mode

The program models one book at a time. McKenzie's central finding is that a shop
worked on several at once, and that the patterns this produces are "of such an
unpredictable complexity … that no amount of inference from what we think of as
bibliographical evidence could ever have led to their reconstruction."

Every report says so and then carries on assuming otherwise. Building it means
several books in the house at once sharing men, presses and type; a stint
interrupted for weeks and resumed; a case replenished from another book's
distributed forme; and type recurring across books rather than only within one.

The point is not realism for its own sake. It is that **the analysis should then
fail**, and the interesting measurement is how fast and in which direction. This
is the honest reply to the objection: not an argument, an experiment.

Needs a clock, which the program does not have. McKenzie supplies the rates —
compositors at 5,000–6,000 ens a day against a nominal 12,000, presswork at about
250 impressions an hour. Moxon supplies the unit the shop actually counted in: a
**token** is 10 quires for a whole press, 5 for a single press-man (p. 321).

Two things wait on this rather than on anything else: **points shared between
founts** (punctuation was "the common property of all founts of the same
body-size", and Okes was still setting the Snowdons' points among his own, so the
comma box belongs to the house), and **space-metal shared the same way** ("pica
spaces are pica spaces, irrespective of fount").

---

---

## 9. Smaller, and well specified

- [ ] **Collation repairs are not modelled, and they conflate copies.** **[manuals]**
      `binding.rkt` claims no authority for its fault rate, correctly — Moxon
      gives none. He gives the **check**, exactly (p. 317): "First, To examine
      whether the whole number of Sheets that belong to a Book are Gathered in
      the Book. Secondly, To examine that **two Sheets of one sort are not
      Gathered**. Thirdly, To examine whether the **proper Signature of every
      Sheet lye on its proper corner**."

      The third is the turned-sheet test, and it confirms the reasoning already
      in the README that an unsigned gathering is likelier to go in wrong *and*
      likelier to survive the check — the check *is* the signature and its
      corner. Moxon even has the compositor set the signature nearer the end of
      the line than the middle so the collationer need not "prick up with his
      Bodkin the corners of the Sheet so high to see the Signature: which in a
      long train of work saves time" (p. 210).

      **The repair is the part with a consequence.** A book short a sheet, where
      the heap is exhausted, "is laid by as **Unperfect** till he have Colationed
      the whole Impression of Books, to see if he can make it Perfect **with some
      other Book, that may have two of the same Sheets Gathered in it**." So a
      copy can receive a sheet from *another copy's* position in the heap order —
      a documented, targeted source of exactly the conflation Greg's calculus
      warns about, and unlike `--heap-disorder` it has a cause, a trace, and a
      frequency bounded by how often a duplicate was gathered. Belongs with §3.

- [ ] **No paper overplus.** **[manuals]** Moxon's warehouse-keeper adds an
      eleventh quire to every fourth, fifth or sixth token (or every second, if
      the quires run 24 rather than 25). Davis & Carter do the arithmetic in the
      margin: "His allowance for spoiled sheets is at the most **24 in 480, plus
      24 for the book: a little more than 5 per cent**. It is a small allowance to
      include proofing." It covers "Proves, Revises, Register-Sheets,
      Tympan-Sheets, and … other accidents … either by naughty Sheets, or Faults
      committed in Beating, Pulling, Bad Register". `--edition` is sheets printed
      and `--first-proof` is a probability; there is no waste allowance, and 5% is
      the number if one is wanted.

- [ ] **The second signature alphabet is `AA` and should be `Aa`.** **[manuals]**
      `letters-mark` (`imposition.rkt:101`) repeats the capital. Moxon, p. 210:
      "if the Book contain above three and twenty Sheets, the Signature of the
      four and twentieth Sheet must be **A a**, if five and twenty **B b** … still
      as he begins a new Alphabet **adding an a**." Blayney's Appendix II
      collations — already mined for this project — agree: `πA8(−A7,8) A-Bb8
      Cc1,2` has **`Bb`** and **`Cc`**. Two sources against the code. A contained
      fix in one function, but it changes every collation formula past 23
      gatherings, so it wants a deliberate pass over the tests.

- [ ] **Rules Moxon states that the program may not keep.** **[manuals]** Each is
      cheap to check and none has been:
      - The catchword is the first word of the next page, "**or if the Word be
        very long and the Line very short, two Syllables, or sometimes but one**"
        (p. 210).
      - **Widows are avoided**: "Nor do good Compositers account it good
        Workmanship to begin a Page with a Break-line" — and a long break at the
        foot of a page **becomes the direction line**, with the catchword set at
        the end of it (p. 217). That is a line of page depth the program may be
        spending.
      - Quartos are signed worse than the rule: Moxon states it (all odd pages on
        the outside of the sheet are signed) and then says "**in Quarto's they not
        only leave the Signature 4 out, but rarely put in Signature 3**" (p. 211).
        A documented gap between rule and practice, which is the kind of thing
        this program is for.
      - **Title-pages letterspace their capitals**, quantitatively: "if he Sets
        but one Space between the Letters in a Word, he Sets **three Spaces
        between Word and Word**: And if he Set two Spaces between Letter and
        Letter, he Sets **four Spaces between Word and Word**" (p. 213). Blayney's
        spaced imprint date `1 6 0 8.`, which `titlepage.rkt` already reproduces
        at 50%, is a special case of this general rule and is currently the only
        part of it modelled.

- [ ] **Moxon's fount weights point the other way from every previous
      correction.** **[manuals]** p. 25: long primer **500 lb** in a *small*
      printing-house (150 of it italic); pica and english **800–1,000 lb**; other
      bodies **300–400 lb** "accounted a good Fount". The program models ~31,200
      sorts on Blayney's measured Okes fount (21,953 sorts). Smith's whole bill of
      pica is 500 lb ≈ 172,000 sorts, so Okes sits near **Smith/10**, which is the
      yardstick `typecase.rkt` already adopts — internally consistent. But
      Moxon's *smallest* respectable fount is two to three times Blayney's
      measured one.

      Smith supplies a reconciliation: "the Professors of the Art were obliged to
      have **large Founts of Letter, on account of printing their Works in Quires
      of three, four, and even five sheets**; whereas now, a Fount of **half that
      force** will serve … **by printing in single sheets**" (p. 47). Moxon says
      the same from the other side — "he cannot Impose till he has Set to the last
      Page of that Quire" (p. 211). By Smith's account this program's period needed
      twice the fount of 1755 work for the same output, and the program prints in
      sixes.

      That bears on the Hinman/McKenzie disagreement without settling it: it is an
      argument that type supply was a real constraint in quired work, which is
      Hinman's side, from a source explaining why it stopped being one. **Every
      previous correction has made the shop poorer; this is the first evidence
      pointing the other way, which is reason to check it hard rather than act on
      it.** Smith also gives fount size in units this program computes directly —
      a fount of english "sat up about twelve sheets in 4to", one large fount
      "above thirty sheets in Folio, of 77 lines long, and 45 m's wide" (p. 48) —
      which is comparable to "pages standing at the peak" and a better yardstick
      than pounds.

- [ ] **What became of the leaves that stayed white.** Two outlets are modelled —
      preliminaries printed there and cut out, and cancels printed there — and
      where neither applies the program shows a blank leaf and says nothing. That
      is half an answer. McKerrow gives the other half in the same breath: "it
      might sometimes have been more convenient to have the two extra leaves as
      **covers or end-papers**", and elsewhere that spare leaves were used "to
      print matter that was to be bound elsewhere in it, such as titles or
      cancels" (p. 156).

      A white leaf should be *accounted for* rather than displayed: pasted down as
      an endpaper, folded back as a wrapper on a stitched pamphlet (p. 123), or
      genuinely left blank, which really did happen — Bowers is firm that "no
      blank not interrupting continuous text would be torn by the printer for
      excision." Printing unrelated matter on them is the one option to leave
      alone: McKerrow raises it and calls it "merely a suggestion".

- [ ] **A forced substitution is free in the model and was not in the shop.**
      `pick-line!` owns `printed` and writes it; `width` was derived from
      `composed` by the stage before and is not rewritten. But the substituted
      sorts are not the same width as what they replace:

      | composed | set instead | difference |
      |---|---|---|
      | `ﬃ` 0.85 | `f`+`ﬁ` 0.88 | +0.03 em |
      | `ﬀ` 0.60 | `f`+`f` 0.66 | +0.06 em |
      | `ſ` 0.30 | `s` 0.39 | +0.09 em |

      So a line that took a substitution is physically wider than the measure it
      was justified to, and `make-line`'s post-condition — a line wider than the
      measure cannot be locked up in a chase — is bypassed, because `pick-line!`
      reaches the line by `struct-copy` rather than through the constructor.

      The magnitude is small: fifteen substitutions in 1,526 lines, at most
      0.09 em on a 21-em measure, less than the hair the line would be re-spaced
      with. The present behaviour is closer to the truth than recording the wider
      width would be. But it is silent, and what happened is not: the compositor
      who finds his ffi box empty and sets f + fi has made the line too long and
      must take a thin out somewhere. The fix is to re-space after picking — a
      real pass, belonging with any other work on justification. Recorded rather
      than patched, because a patch that updated `width` alone would make the
      facsimile worse while looking like a fix.

- [ ] **Word division breaks inside consonant clusters.** 23% of the divided
      words in Floyd break where no compositor would break them — `Exc-epte`,
      `conſtr-`, `praecl-`, `ſhipp-`, `omn-`, `Ariſt-`. Moxon and McKerrow both
      have division by syllable; the rule here divides by width alone. 42% break
      after a single consonant and 35% after a vowel, which are the ordinary
      cases; it is the remaining quarter that wants a syllable rule.

- [ ] **`runne` modernises to `rune`.** Believed unfixable by rule. The grouping
      assigns an old form to its nearest current word by edit distance: `rune` is
      one letter from `runne`, `run` is two. Frequency would arbitrate correctly —
      `run` is far commoner — but the same change breaks `heere`, one letter from
      `here` and two from the much commoner `her`. The two cases are
      orthographically identical and lexically opposite. This is precisely why
      VARD keeps a human in the loop, and the honest next step is to **measure the
      error rate on a hand-checked sample** rather than keep adjusting a rule that
      cannot in principle succeed.

- [ ] **The type page may be wrong for the paper.** Fell out of building the
      sheet, and nothing has been retuned to hide it. The margin canon 2:3:4:6
      only yields those proportions when the type page shares the leaf's shape,
      and ours does not: on foolscap the quarto's type page is 160×89 mm, a ratio
      of 1.80, on a leaf of 1.31. So the outer margins come out wider than head
      and tail, which is the wrong way round for a hand-press book. Either the
      21-em measure is too narrow for foolscap or the stock is wrong for these
      books. Blayney's Okes quartos are where to settle it, by measuring type
      pages against leaves rather than by adjusting until it looks right.

- [ ] **Collation mode.** Compare two witnesses, or a witness against its
      copy-text, and report the differences as an apparatus. Most of the machinery
      exists — `collate` superimposes two made-up copies, the TEI carries
      `<app>`/`<rdg wit>`, and the deviation classifier knows what kind of change
      each one is. Missing: the front end, and the ability to collate against an
      arbitrary text rather than another copy of the same setting.

- [ ] **Per-compositor type cases.** Hinman distinguishes cases x, y and z, and
      much of his argument turns on which man used which; here every workman draws
      from one pair, which makes the type evidence cleaner than it was. Blayney
      adds the sharper version: Okes's men *divided* one fount into two cases
      part-way through the book, and after that "it is impossible to be sure how
      much type was in either case at any one point" — the division itself
      destroys the evidence.

- [ ] **Standing type between editions.** A second edition set from the first with
      some formes never distributed. (Half-sheet imposition, which used to be
      filed with this, is built.)

- [ ] **Two-pull press.** A folio forme needed two pulls; the timing model will
      need it when there is a clock.

- [ ] **Thirty-two bindings the manual mentions but does not document.**
      `raco setup --check-pkg-deps` names them: `make-house`, `book?`,
      `PRELIM-SCHEMES`, `page-spec?`, `page-evidence?` and the rest. Each renders
      as plain code instead of a link, because there is no `defproc` or `defstruct`
      to link to. Not a blocker — the package builds clean — but it is the
      difference between a manual and a reference, and the list is already written
      for us.

- [x] **The fount has too few figures, and it is Lear's fault.** *Done.* In
      Floyd's *Common Wealth* the arabic figures ran to *zero* — and the run
      confirmed it sort for sort: `2` wanted 25 times, `&` 16, `1` 15, `3` 11,
      `4` 10, and nothing else in the bill emptied.

      `upper-bill` gave each figure 26–40 sorts on the rule "the greater of Lear's
      measured maximum and a tenth of Smith's bill". But *Lear* is a play: no
      numbered chapters, no arabic pagination, no marginal citations. Blayney says
      as much himself — three of the numerals in his list are there only because
      they appear on the titlepage, "despite the fact that they were not used in
      the text itself".

      **The instruction to find a real bill could not be carried out, and that was
      the finding** — at the time. Blayney's table (i. 146) has no numerals row;
      Gaskell (p. 37) gives the full bill only as ratios and refers the rest to
      Smith pp. 38–48; van den Keere's 1571 registre gives no figures. *This has
      since been superseded: Smith's own bill, read directly, gives the figures
      unequal — 1,500 / 1,300 / 1,300 / 1,100 / 1,100 / 1,200 / 1,100 / 1,000 /
      1,000 / 1,600 for 1–9 and 0 — which is itself evidence about relative demand
      and has not yet been compared against what is here.*

      So they were measured from the demand, and by Blayney's own criterion — his
      maxima are "the number of types of each sort that were in type just before
      each distribution", which is the **peak, not the mean**. Averaged, Floyd
      wants sixteen `2`s standing against a bill of 34 and the case looks ample.
      It is not: figures gather in a contents table, a set of citations, a
      chronology. The densest twelve pages that can stand locked up together want

      | | 0 | 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | & |
      |---|---|---|---|---|---|---|---|---|---|---|---|
      | peak | 19 | 56 | 60 | 45 | 37 | 23 | 21 | 18 | 17 | 12 | 53 |
      | was | 30 | 40 | 34 | 30 | 28 | 28 | 26 | 26 | 26 | 26 | 40 |
      | now | 30 | 80 | 80 | 60 | 50 | 32 | 30 | 26 | 24 | 20 | 72 |

      and the five short of their peak are exactly the five the run reported
      exhausted, in the same order. The whole increase is 170 sorts on a net total
      near 22,000 — under one per cent by count, less by weight. It is not a bigger
      fount, it is a fount whose upper case is no longer laid out as though every
      book were a play. Two sanity checks: the figures now sit in the same band as
      the capitals beside them (16–80 against Smith/10's 20–80); and for the one
      sort a real 1571 fount does record, van den Keere gives **160** ampersands
      where this gives 72.

      **`BLANK-FOR-PROOF` is left at 0.25**, and the reason is worth stating
      because the obvious move is wrong. Tuning it until the model produces
      Blayney's one instance would fit a number that is not a census: a placeholder
      filled at proof leaves nothing behind, and his proof at I4v36 works only
      because the type that filled it "cannot have been available until a later
      sheet had been set". The count is bounded below by one and above by nothing.
      His prose points the other way in any case — *Lear* "bristles with
      deliberately-turned types and other improvised substitutions", and what he
      finds notable is "the relative infrequency of accidental foul-case errors,
      **wrong-fount types**, and turned letters" (i. 179), which is the very branch
      this parameter chooses against.

      Measured consequence: **129 face-down sorts in a 48-page prose quarto before;
      none at all across five seeds after; seven in a play set as a quarto**, which
      is Okes's own case. Above the one he can prove, well inside "bristles", and
      nought where the strain is not there.

---

---

## 10. The First Folio as the standard test case

`tools/fetch-folio.py` builds the whole book as copy — 868,245 words, all 36
plays in the order of the 1623 Catalogue with the eight preliminary pieces, as
both declared TEI and constructed Markdown. Nothing is committed; it is other
people's text, on the footing of `corpus/` and `sources/`.

It is the standard case because it is the *hard* one. **The current numbers are
in the README**; what follows is the history, which is where the value is.

---

## 11. Widen the calibration base

**The corpus sweep is built** — `tools/corpus-sweep.py`. Eleven properties of the
printed page, the model's distribution against the corpus's, the copy-text in a
third column. Six properties had been checked by hand over this project's life and
**every one found a defect**; this checks them together so that which get looked
at stops being a matter of who wondered.

Its first run produced **two flags and both were the instrument's fault** — a
hyphen count that was 45% line-end division, and a full stop the copy was already
short on. Hence the two rules in its docstring: **distributions and never points**
(a pooled corpus rate reads 8.46 ampersands per 1,000 where the per-document
median is 2.19) and **one vetted extractor a side** (every `&` in the corpus is
`&amp;`; a tilde is a combining mark). It prints what it *cannot* compare, which
is the half a sweep usually omits.

Open in it: **a genre filter.** All three flags on the Folio — periods, questions,
mid-sentence capitals — came of comparing drama against a mostly-prose corpus. 80
English drama texts of 1580–1640 carry usable `<TERM>` headings, thin for
quartiles but enough for a median. It would also settle the **capitals overshoot**
(20.7% mid-sentence against a corpus 10.3%, on a copy already at 14.2%), which is
the likeliest real defect in the habit work: the rule *adds* the period's share
rather than *targeting* it.

And one row it raises without settling: **the apostrophe**, 8.84 per 1,000 against
a corpus median of 0.17 but a pooled 10.22 — a distribution so skewed that
CALIBRATION's 9.58 and the corpus median are both true of different populations.


- [ ] **F2, F3, F4.** Furness's Variorum collates three further reprint
      generations, each set from its predecessor, with variants recorded line by
      line. Three more copy→print transmissions with known copy, which would
      roughly quadruple the evidence. Extracting them means reading the apparatus
      rather than diffing, since the interesting cases are errors *shared* between
      texts, which a mechanical diff cannot see.

- [ ] **Manuscript copy.** Every misreading profile assumes printed copy. Setting
      from a secretary hand is a different problem with a different confusion set,
      and the Duport manuscript and Newton's *Opticks* copy survive with the
      compositors' marks on them.

---

---

## 12. What a corrector could correct **[manuals]**

**Nine of Hornschuch's marks and two of the compositor's habits are built.** See
*Built* below for what each cost and CALIBRATION.md for what each reads. The
governing finding, which every one of them turned on:

**Every error rate in the calibration table was diffed out of a *printed book*,
so it counts what got past the corrector; the rate the program is set to is what
the compositor *makes*.** One number was doing both jobs. The report now prints
made, mended at proof, and left standing in one copy — and the same confusion has
since been found in four more rows.

And the test to put to any new kind, before writing it: **only a fault that
changes a reading can become a press variant.** Foul case by shape and the faults
of impression could never have closed the variant gap, and both were built first.

### Open

- **The redundant *letter*** — the other half of Hornschuch's second mark. A
  letter set twice inside a word sits very close to the literals foul case
  already makes, and the first question is whether it is distinguishable from
  them on the page at all. **If it is not, it should not be built.**

- **The signing statement's exceptions.** Bowers puts the breaches in the bracket
  the formula now fills — `[$2(−K2) signed; A2 in ital., misprinting E2 as C2]`
  — and the program states the pattern and none of them. Moxon quantifies the
  commonest: "in Quarto's they not only leave the Signature 4 out, but **rarely
  put in Signature 3**". A documented gap between rule and practice, and checkable
  against the F2 facsimile by eye, signatures being large and in the direction
  line.

- **An anchor that can see the new kinds.** The *Much Ado* diff is
  word-against-word and cannot register punctuation, spacing or lineation, which
  is why nothing here has ever counted them. §11 is a dependency, not a parallel
  item. Note what F2 can and cannot do for it: it is a page-image scan with no
  text layer, so it answers spacing and signatures by eye and nothing by diff —
  **OCR would manufacture exactly the ſ/f and n/u confusions being measured.**

- **Whether he pointed MORE than his copy**, and not merely otherwise. What is
  matched is the *share* of heavy stops, not the density: the model chooses among
  the stops the copy has and adds none. Needs a copy→print pair, so §11 again.

- **Lambard's edition size** — **six hundred copies, and twenty years to sell
  them.** `--edition` defaults to 750 and the Folio runs at 1,200; nothing in the
  calibration file rests on a real edition size yet.

**Do not fit any of it to the twenty corrections on that page.** It carries eight
times the book's average and says the density is short without saying what it is.

*Hornschuch's marks in full, the two itemised proof censuses, the errata evidence,
the stage audit, and the rate derived wrongly from a density before rightly from a
share: [FINDINGS](FINDINGS.md).*

---

## Built

Kept short on purpose. Each was argued out at length when it was done; what is
worth carrying forward is the number it produced. The README describes what these
*do*; this is what they *cost to get right*.

**What a corrector could correct**, all of 2026-08-14/15, and the point of the
list is that **no two rates came from the same kind of evidence**:

- **spacing left out** — a *share*, 3 of the proof page's 20 corrections.
- **a word passed over** — a *ceiling*, half of Gascoigne's errata discounted for
  severity, because errata are selected for it.
- **transposition of words** — an *ordering*, 0 in ~32 itemised corrections, so
  set under pointing and the check is the order of the counts.
- **the redundant word** — a *mirror*: dittography is eyeskip run backwards and
  takes that mechanism's rate. **The only kind with no knob.**
- **pointing and capitals as habits** — the *corpus*, 300 and 491 books. The
  colon is the heavy stop 70% of the time in the 1600s and 35% by 1640, and **a
  modernised copy has it the wrong way round**. 3,761 word-types carry capitals.
- **the close-set comma** — an *outcome*, not a rate at all. Blayney's patches of
  close spacing are space-shortage; the program had the shortage and not the
  response. 30% of commas, and patchy the way he describes.
- **Lambard's grades** — and they are **not the corrector's order**. He grades by
  danger, a reader without copy catches by detectability, and they part at both
  ends, which is why the dangerous errors are the ones that survive.
- **wrong fount** — 1,942 to **14**, by giving it Hornschuch's cause (italic
  meeting roman) instead of a smaller rate. A rate two orders out is usually not
  a rate.
- **the spinning-out device** — could only double a white line that already
  stood, and the median spun-out page had none. The book went from 82.0% to
  **99.9%** within two lines of its measure.
- **foul case** — held above its observation to compensate for an instrument that
  was never graded. Graded, it *over*counts by 69%. Rates down a quarter and
  inside the interval at last.

**The material.**

- **Space-metal is type** — the biggest thing the model was missing. A gap is a
  cast body picked by hand from a box that can empty. **16% of everything set is
  white.** The fount rose from 21,953 to 31,200 because Blayney's table counts
  letters, capitals, points and ligatures and no quads at all. Provisioned from
  *prose* demand, the play strain falls out by itself: a play empties the em-quad
  box (100% out against 8% for prose) because every short speech line is quadded
  to the measure — Blayney's asymmetry, reproduced rather than fitted.
  Justification is quantised as a consequence: 86% of the old gaps were widths no
  founder ever cast, and a line now fills to within less than a hair (median 4/120
  em) rather than exactly. *The bodies themselves are now in doubt — see §4.*
- **The bill of type and the size of the fount** — wrong by nearly a factor of
  three. 60,000 sorts was derived from Jaggard's Folio pica, the largest house in
  London working in folio; the default is now Okes's measured 21,953. Two
  independent checks came out right: 465 `y` and 974 `i` against Blayney's "at
  least 500 'y's and 1,046 'i's", and 67 `i` a page against his measured 66.
- **The ladder of shifts** when a box runs dry, in Blayney's order: set `VV`; rob a
  standing page at the margins; distribute a forme early; set a sort face down and
  fill at proof; send to the founder. On *Areopagitica* the ladder reads 226
  robbed, 13 wrong-fount, 4 face down, against 248 wrong-fount before.
- **`ſt`, `ſh`, `ſi` as sorts.** `ſt` at 200 is Okes's commonest ligature, more
  than `ﬀ`, `ﬁ` and `ﬂ` together. A ligature prints as its two letters; what
  differs is which box emptied.
- **Type-supply governs spelling** — the best thing in Blayney. B's choice between
  `-ie` and `-y` looked incoherent until the boxes were tabulated: over 200 `y`
  available he set 49% `-y`, between 100 and 200 he set 42%, below 100 he set 29%.
  A spelling test measures the case as well as the man.
- **Inverted sorts as evidence.** Short `s` upside down at 1 in 150, invisible to
  the corrector and legible three centuries later.
- **The sheet, and the size it makes.** Format is a folding and not a size; the two
  together give a leaf. One rule — a fold halves whichever dimension is longer —
  reproduces Gaskell's Key III exactly for pot, demy and royal in all three
  formats.

**The book.**

- **Preliminary signatures** — `sig-series` for `* ** ***`, `* † ‡ §`, `¶ ¶¶`,
  lower-case, the main alphabet, and McKerrow's `π` for leaves carrying nothing.
  The collation formula takes runs, so it prints `4°: A² B–L⁴`, Blayney's own
  formula for *Lear* Q1.
- **Printing the preliminaries last**, and East's decision about the Table
  reproduced rather than imitated: is there room in the white leaves already left,
  and does moving it save leaves at the front?
- **The title-page, generated as copy** so it goes through the same compositor —
  from Blayney's Appendix II, about ninety transcripts from one shop 1604–9.
- **The last sheet**, with preliminaries printed in the white leaves and cut out,
  conjugate from the centre and disjunct from the tail.
- **Cancels** — the trace simulated and the cause parameterised, which is
  McKerrow's own division ("into the purpose of these cancels we need not enter").
  Five of his six detection tests are generated; the sixth is the paper, and is §6.
- **Folding, gathering and the binder's errors** — five kinds of fault, all from
  the sources; the *rate* is a parameter with no authority claimed for it.
- **Half-sheet imposition**: a two-leaf gathering is one forme worked and turned
  (Gaskell, p. 83), and `A2` is the commonest preliminary arrangement in Blayney's
  checklist by a wide margin.
- **Correlated press-variant states**, the meeting point of Gaskell and Greg, at
  Moxon's grain: the heap goes up to dry in doublings and comes down three or
  four at a time, so a sheet moves only among its neighbours — 26 sheets on
  average, never past 70. Consistency then turns on how far apart the collated
  copies stand in the heap rather than on how many there are. *§3.*

**Reading the copy.**

- **`import.rkt`** — Markdown with YAML, TEI and EEBO-TCP, LaTeX, Word, HTML and
  PDF, in three tiers: *declared*, *constructed*, and *nothing at all*, which is
  what plain text gets and is the honest answer.
- **The heading vocabulary was the wrong instrument** and is off by default.
  Demonstrated rather than argued: against Aylett's *Peace with her foure Garders*
  (1622) it found nothing, because the book opens with fourteen lines of dedicatory
  verse under no heading, so the walk stopped before the vocabulary was consulted
  once.
- **Scribal frequency has a slope**, which two data points could not show. Tildes
  per thousand words fall 2.99 → 0.19 across the 1580s to the 1630s; the superscript
  brevigraphs never crossed over from the hand at all (`yᵗ` at 5.5 per *million*
  words against the program's 6,600).

**Output.**

- **One rendering, not two.** The facsimile is built by `tei-html.rkt` out of the
  `.tei.xml` and nothing else, so anything absent from the TEI is absent from the
  page — a property rather than a discipline that has to be remembered. It found
  two things immediately: the TEI carried no record of which damaged sorts set a
  word, and no statistics.
- **Four views and a filter.** The book, the make-up, the evidence, the copies; a
  map of the whole run, collation diagrams that show which leaf comes loose when
  another is cut out, and a legend that filters the apparatus by kind of departure.
- **The leaf at its true size**, drawn from the sheet in the file rather than
  invented by the stylesheet.

**Defects found by measuring rather than by looking.**

- **Words collide in the tightest lines** — *not* systematic. 13 touching pairs in
  16,219, or 0.08%. My visual impression from one screenshot overstated it by a
  wide margin.
- **Turn-over never fires** — *not* dead. It fires on verse, once in 267 lines of
  *Hamlet*, and reads zero on prose because only a verse line can be turned over.
  The real defect was a report that printed a bare `0.00`.
- **Foul case fired on every u-for-v** — 1,048 words classified as accidents
  against a measured rate of about five for that book. Self-inflicted by a rename.
  **1,048 → 7.**
- **A paragraph longer than a page was never divided when it began the page**, so a
  two-hundred-line paragraph was cast off as one page of thirty-eight.

---

## Not doing, and why

**Answering McKenzie.** The objection is correct and the program cannot escape it.
Every percentage the analysis produces is the analyser inverting the generator;
both were written from the same account of how a printing house behaved, so
agreement demonstrates self-consistency and nothing else. The right response is to
keep saying so in every report and to build §8, which makes the failure visible
rather than arguing about it.

**Fitting the parameters to the sample.** Several rates sit close to their measured
targets. It would be easy to close the remaining gaps by adjusting until they
matched, and the result would be worthless. Where a figure is off it is left off,
and said to be off: the tilde runs about 1.5× the median for 1605 (inside the
interquartile range, so unremarkable), and the ampersand at twice the 1630s median,
between that median and its 75th percentile.

The note that used to stand here — "the ampersand at roughly twice the observed
rate" — was measured against the Folio's fourteen in twelve thousand words, and the
corpus says the Folio is unusually sparing. Against the median book of its decade
the ampersand was about right all along. **A figure said to be off can be as wrong
as one said to be right.**

