# Roadmap

Ordered by evidential value rather than by effort. The question asked of each
item is not "would this be interesting?" but **"would this let the program be
wrong in a way we could detect?"** — which is the only thing it has ever been
good for.

Open work comes first, because that is what a roadmap is for. What is built is
summarised at the end with the numbers that came out of it; the detail lives in
the commit messages, the README and the manual.

---

## 1. Forme order from type recurrence

**Hinman's actual method, and the program is uniquely placed to test it.** This
is the one to build above everything else, because it grades itself: the
simulator knows the true order of printing, so it can answer a question no real
book can — how often does type-recurrence evidence give the right answer, and
what does it take to break it?

Blayney sharpens the target and supplies the threshold. Hinman recorded 314
distinctive types in the Folio *Lear* — "a density of approximately 23 per
forme, or 11-12 per page" — and that sufficed to order a folio. A quarto forme
holds four pages, each less than half a folio page, so the same fount condition
yields "no more than 5 or 6 types per page", which "is not nearly enough to
allow the page-order of a quarto to be determined with any great precision".
His criterion is exact: **unless the evidence-density is great enough to reveal
at least two prior distributions in every quarto page, the order in which those
pages were set cannot be proved.** Two, because when a forme is distributed into
depleted cases its types crowd into the next few pages, so knowing which of two
distributions came first is the whole question.

That is a numeric prediction about when the method works, made by its most
careful practitioner, and the simulator can run it at any density and check.
Expect Hinman's folio density to succeed and the quarto density to fail; the
interesting number is where the boundary actually falls.

Everything needed is tracked already. `typecase.rkt` follows individual sorts by
their damage and `note-recurrence!` keeps the places. What is missing is the
inference: given only the recurrences, work out the order the formes went to
press. Expect it to work and then fail interestingly — when two formes were set
close together, when a case was replenished mid-forme, or under concurrent
production, where a sort may recur because it went to another book and came back.

**The analyst's eye is built** — `recurrence.rkt`, and it had to come first,
because until it existed the analysis was handed every distinctive piece in the
fount, perfectly labelled, with every one of its appearances known. That is not
evidence, it is the answer, and grading an inference against the truth means
nothing if the inference starts from the truth.

How far off it was is the measurement worth keeping. At the default fount the
model puts **27.2 distinctive types on a folio page** (± 1.2 over five seeds)
where Hinman's actual harvest from the Folio *Lear* was 11–12. Roughly twice as
much evidence as the man who invented the method ever had — and it is his figure
that every published type-recurrence argument rests on. The gap is *not* a sign
the fount is too battered: `CONDITIONS` says how much metal is damaged and
Hinman's number counts what one man could identify, and closing it by adjusting
the fount would have made the type case wrong to make a report right.

Most of what Hinman says about identifying types (i. 54–6) is a rule, and two
are encoded with no free parameter: **bent or broken ascenders on b, d and h**,
which he says are "practically useless as means of identifying individual
types", and **pieces too alike to separate** — "defective in so nearly the same
way that they cannot always be clearly distinguished from each other". The
second is the interesting one, because it means evidence does not scale with
decay: a fouler fount holds more distinctive pieces *and* more pieces damaged
alike, so past a point further battering buys nothing. That falls out of counting
the model's own pieces, and §1 can test it at any fount condition.

One free parameter, `discrimination`, the finest difference between two injuries
an investigator can reliably see. Anchored on the folio at 0.20, which gives
12.2 ± 0.7 a page against Blayney's 11–12. **The quarto is a check and not a
second anchor, and it passes**: with 0.20 carried over untouched, 5.3 ± 0.5
against the 5–6 Blayney argues for from the type-area. The ratio between the
formats is the model's own.

Anchored on Hinman's Folio, so it is a *ceiling* on what a bibliographer sees
rather than a typical value — the best-equipped study the method has had, with
eighty-odd copies and a collating machine. Blayney says most quarto
investigators "have used rather less evidence per forme than did Hinman", and §4
below records what happened last time a parameter here was anchored on Jaggard
and treated as ordinary. `--discrimination` sets it.

**Two of Hinman's mechanisms are named and not built**, and both belong with the
inference rather than with the eye:

- **The printers culled the worst types.** "any especially striking abnormality
  is, as a rule, soon noticed by the printers themselves, who at once cull the
  peccant type" — so the grossest injuries are *not* the best evidence, because
  they leave the case early. That is a shop behaviour and belongs in
  `typecase.rkt`. Without it, severity is monotone and the model has no reason
  the worst-damaged piece should be rare.
- **A recognisable piece can still be missed on a page.** Defects "especially
  liable to be inked over occasionally — with the result that, in a given page,
  such a type may be unrecognizable in some copies", and an investigator who
  "may simply fail to notice". Recognition here is per piece and held for the
  whole book, so a piece the analyst can use has an unbroken chain — which is
  exactly what makes forme-ordering easy, and therefore exactly what will
  overstate how well the method works. Wants the copies machinery, since
  Hinman's own answer was that "thorough investigation will certainly require
  the use of more than one copy."

**Turner's rule is built and graded**, in `recurrence.rkt` and reported in full.
The principle is that "in a quarto set by formes, type from the first forme of
each sheet normally reappears in both formes of the succeeding sheet, but type
from the second forme only in the second forme". Blayney takes his *Midsummer
Night's Dream* table and shows that the further claim — that "when type
reappears in this manner, composition cannot have been seriatim" — is
"completely untrue".

**Blayney is right, and the number is 57%.** Quarto, eight seeds a side, one
forme standing:

| | sheet-pairs | pattern appears | names the first forme rightly |
|---|---|---|---|
| set by formes | 56 | 54 (96%) | 54 of 54 (100%) |
| set **seriatim** | 56 | 46 (82%) | 46 of 46 (100%) |

As Turner's test for "composition cannot have been seriatim" that is 57%
accuracy against a coin's 50%, and 54% precision when it fires. The pattern
turns up in seriatim setting nearly as often as in setting by formes, which is
exactly Blayney's objection — "it does not describe conditions found only in
sheets set by formes."

**But the rule is not worthless; it is pointed at the wrong question.** Where
the pattern appears it names the forme that was distributed first **100% of the
time, under both methods**. That is what makes it useless as a test of setting
order: it identifies the forme correctly whichever method was used, so the
pattern itself carries no information about the method. A good instrument, a
false claim.

Two things fell out that Turner's statement does not mention.

- **The rule depends on a condition he never states.** It only speaks at *one
  forme standing*. At the default of two the pattern never appears at all in
  112 sheet-pairs: with distribution lagging by a forme, a sheet's type reaches
  only one forme of the next, never both. Whether the rule can be applied to a
  book is a fact about that shop's standing-type discipline.
- **Detection is not what kills it.** Blayney's other worry is that the rule
  reads a negative, so an imperfect eye manufactures the absences it needs. At
  a perfect eye (discrimination 0) the accuracy is 56%, against 57% at Hinman's.
  The rule is structurally uninformative, not evidence-starved — which is a
  sharper criticism than the one about detection, and the opposite of what I
  expected before measuring.

One caveat to carry: at two or more formes standing the model produces a very
clean one-way signal — outer→inner when set by formes, inner→outer when
seriatim — which would discriminate perfectly. That is the model's own
regularity, a fixed standing-type threshold distributing on schedule, and it
should not be believed. Real shops ran several presses and several books; §5 is
where that gets tested.

Related and cheap now that the table exists: the *order* of the sheets it pairs
is the order they were **printed**, not bound, and getting that wrong is silent.
Preliminaries cut from the white paper of the last sheet are bound first, so the
raw page order of a quarto reads H, A, B … G — which produced a confident table
for "H → A", the sheet printed last against the one printed first, and dropped
the real G → H. `turner-table` now orders the sheets itself.

Related and cheap once this exists: **pagination errors as evidence of order.**
`pagination.rkt` already separates errors of omission from commission because
Hinman says only the former are informative. Nothing yet uses them.

---

## 2. Recovering the perfecting order from the groupings

The prize that correlated press-variants opened, and not yet taken. Given a
handful of collated copies, the direction of each grouping — which end of the
gathered order holds the corrected sheets — says which forme of that sheet went
to press first, and the program knows the answer.

The report currently shows the truth *beside* the groupings rather than making
the inference and being scored on it. Turning that round is the analysis half's
next real exam.

**Greg's calculus as an analysis module** is the general form of the same work:
type-1 and type-2 variants, the compounded variational formula, the resolution
of complex variants, the order-of-merit count. Two cautions from him to carry:
the **ambiguity of three texts** (with three witnesses no formal process can
establish relationship), and the **fallacy of constant variation** — that every
transcription introduces about the same number of variants, which is "quite
contrary to experience and leads to erroneous results" (p. 9n, Note C). Also his
warning that the finer the collation, the more non-evidential variants and
chance coincidences it turns up (p. 18).

---

## 3. Watermarks and chain-lines

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

---

## 4. The set widths are invented, and their spread is too narrow

`metrics.rkt` carries a per-sort width table with no source. Its own comment
says so: "an old-face roman, rounded. Exactness is beside the point, proportion
is not." It was built to be plausible. It sits underneath every line the
compositor sets, and it is the one place where "the spacing is the whole point
of the exercise" rests on nothing measured.

**Whether it matters is not known, and the attempt to find out failed.** The
branch `width-experiment` substitutes the only measured alternative anybody has
published — Blokland's appendix a5.5, Garamont / Van den Keere's Moyen Canon
Romain, sixteenth-century foundry type from the Museum Plantin-Moretus, taken
sort by sort with a digital calliper — with the setting density held constant.
Across eight seeds, preliminary scheme pinned so only the seed varies:

| | invented table | measured table | diff / sd |
|---|---|---|---|
| needing an expedient | 70.65 ± 13.86 | 75.29 ± 9.23 | 0.39 |
| a word divided at the end | 84.95 ± 19.13 | 83.50 ± 10.31 | −0.09 |
| quadded out | 169.18 ± 1.60 | 170.25 ± 1.35 | 0.72 |

Nothing there. **The seed dominates everything.** On one width table, changing
only the seed swings word division from 65.34 to 113.41 — a 74% spread, and the
same for expedients. Any difference the widths make is buried under it at this
sample size. Detecting a five-point shift against a standard deviation of
fourteen would need something like sixty runs a side, not eight.

**Two claims made from a single seed and since retracted**, recorded because the
first answer is the one that gets believed:

- *"Division rises 15.4%."* It does on seed 1614. Over eight seeds the
  difference is −1.5, and the sign reverses. Pure noise.
- *"The collation changes from `4°: *⁴ A–E⁴` to `4°: A–F⁴`."* It does not. The
  preliminary signature scheme is drawn from weights when left on `auto`, so any
  change upstream shifts the RNG stream and the draw lands elsewhere. Pin the
  scheme with `--prelim-signatures` and both tables give the same collation.
  That was the RNG moving, not the type.

What survives is narrower and still worth having: the table has no source; the
measured fount's spread is wider than ours (m/i 3.86 against 2.79); and `quadded
out` is the one metric with low enough seed variance that a real effect could be
seen there if one exists.

**Why the branch is not merged.** Blokland measured display sizes. Before
Benton's pantograph "every point size was a type on its own and had to be cut
separately", which made adaptations between sizes standard practice, so these
millimetres must not be scaled to a pica. That is exactly the
anchored-on-one-example error recorded at the foot of this file, and it is how
the fount came to be three times too large. What transfers is the structure.

**What transfers, and is worth doing without any new source:** widths came in
shared classes rather than a continuum. Blokland's measured groups, within a
tolerance of 0.2–0.4 mm, are `[a c e]`, `[b d g h n o p q v fi]`, `[i j l]` and
`[r s t]`. Casting with fixed registers is why: matrices of corresponding
letters were justified to one width. Our table gives forty-odd sorts forty-odd
independent decimals.

**What is still wanted: a measured text-size roman.** No book appears to
tabulate one. Vervliet catalogues types for identification — 20-line body,
x-height — not per-sort widths, and Mosley warns in his preface to Carter that
type from identical matrices "may look very different if cast in a mould for a
larger or smaller body", so a set width may not be a property of the matrices
at all. Two routes, neither of them a purchase: measure it off a
high-resolution facsimile of a page in a known fount, solving for widths across
many lines of known content; or write to Blokland, who has the matrices, the
microscope and the method, and measured display sizes only because that is what
his argument needed.

---

## 5. Concurrent production — the McKenzie mode

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
compositors at 5,000–6,000 ens a day against a nominal 12,000, presswork at
about 250 impressions an hour.

Two things wait on this rather than on anything else: **points shared between
founts** (punctuation was "the common property of all founts of the same
body-size", and Okes was still setting the Snowdons' points among his own, so
the comma box belongs to the house), and **space-metal shared the same way**
("pica spaces are pica spaces, irrespective of fount").

---

## 6. Smaller, and well specified

- [ ] **What became of the leaves that stayed white.** Two outlets are modelled
      — preliminaries printed there and cut out, and cancels printed there — and
      where neither applies the program shows a blank leaf and says nothing.
      That is half an answer. McKerrow gives the other half in the same breath:
      "it might sometimes have been more convenient to have the two extra leaves
      as **covers or end-papers**", and elsewhere that spare leaves were used "to
      print matter that was to be bound elsewhere in it, such as titles or
      cancels" (p. 156).

      A white leaf should be *accounted for* rather than displayed: pasted down
      as an endpaper, folded back as a wrapper on a stitched pamphlet (McKerrow,
      p. 123), or genuinely left blank, which really did happen — Bowers is firm
      that "no blank not interrupting continuous text would be torn by the
      printer for excision." Printing unrelated matter on them is the one option
      to leave alone: McKerrow raises it and calls it "merely a suggestion".

- [ ] **The fount has too few figures, and it is Lear's fault.** In Floyd's
      *Common Wealth* the arabic figures run to *zero*: `1` bill 38 → 0, `2`
      33 → 0, `3` 29 → 0, `4` 27 → 0, `&` 38 → 0. That is why 129 face-down
      placeholders appear in a 48-page quarto where Blayney proves one in a whole
      book (i. 161, at I4v36).

      The rate was never the first question. `upper-bill` gives each figure 26–40
      sorts on the rule "the greater of Lear's measured maximum and a tenth of
      Smith's bill". But *Lear* is a play: no numbered chapters, no arabic
      pagination, no marginal citations. Its demand for figures was near zero, so
      its maximum is no evidence about the fount, and Blayney's Smith/10
      yardstick was a statement about **capitals**. A book with a two-hundred-entry
      numbered table of contents cannot be set out of that case.

      Find what a real bill gives for figures — Smith's standard bill in Gaskell
      p. 37, and van den Keere's 1571 registre, which Blayney prints alongside
      the Lear column. Only then is `BLANK-FOR-PROOF` (0.25, a guess) worth
      looking at. The misclassification is already fixed: the placeholder has its
      own category `#sort-wanting` rather than being reported as foul case.

      Their *widths* are fixed, which is a separate thing from their number. The
      table used to give every figure 0.50 em "so that tables would range", which
      was an eighteenth-century convention read back into the sixteenth. Two
      sources say otherwise: Blokland's calliper measurements run 3.37 to 5.53 mm
      across the ten, a spread of 64%, and Marini's IM Fell English — a faithful
      digitisation of the seventeenth-century Oxford types — has old-style
      figures of plainly differing widths. They are now proportioned to his
      measurements with the mean held at the en body, so the density is unchanged
      and only the shape of the distribution has moved. See §4 for why the shape
      transfers from a display size and the values do not.

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
      one letter from `runne`, `run` is two. Frequency would arbitrate correctly
      — `run` is far commoner — but the same change breaks `heere`, one letter
      from `here` and two from the much commoner `her`. The two cases are
      orthographically identical and lexically opposite. This is precisely why
      VARD keeps a human in the loop, and the honest next step is to **measure
      the error rate on a hand-checked sample** rather than keep adjusting a rule
      that cannot in principle succeed.

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
      copy-text, and report the differences as an apparatus. Most of the
      machinery exists — `collate` superimposes two made-up copies, the TEI
      carries `<app>`/`<rdg wit>`, and the deviation classifier knows what kind
      of change each one is. Missing: the front end, and the ability to collate
      against an arbitrary text rather than another copy of the same setting.

- [ ] **Per-compositor type cases.** Hinman distinguishes cases x, y and z, and
      much of his argument turns on which man used which; here every workman
      draws from one pair, which makes the type evidence cleaner than it was.
      Blayney adds the sharper version: Okes's men *divided* one fount into two
      cases part-way through the book, and after that "it is impossible to be
      sure how much type was in either case at any one point" — the division
      itself destroys the evidence.

- [ ] **Standing type between editions.** A second edition set from the first
      with some formes never distributed. (Half-sheet imposition, which used to
      be filed with this, is built.)

- [ ] **Two-pull press.** A folio forme needed two pulls; the timing model will
      need it when there is a clock.

- [ ] **Thirty-two bindings the manual mentions but does not document.**
      `raco setup --check-pkg-deps` names them: `make-house`, `book?`,
      `PRELIM-SCHEMES`, `page-spec?`, `page-evidence?` and the rest. Each renders
      as plain code instead of a link, because there is no `defproc` or
      `defstruct` to link to. Not a blocker — the package builds clean — but it
      is the difference between a manual and a reference, and the list is
      already written for us.

---

## 6a. The First Folio as the standard test case

`tools/fetch-folio.py` builds the whole book as copy — 868,245 words, all 36
plays in the order of the 1623 Catalogue with the eight preliminary pieces,
as both declared TEI and constructed Markdown. Nothing is committed; it is
other people's text, on the footing of `corpus/` and `sources/`.

It is the standard case because it is the *hard* one. Everything the program
had been exercised on was a quarto of prose or a single play; setting the
whole Folio at 1,200 copies found four defects that nothing smaller did.

**What it caught.**

- **The folio measure was wrong, and by 25%.** `FOLIO` and `FOLIO-IN-SIXES`
  carried an unsourced 16 ems. Hinman measured the book: "twenty lines measure
  about 83 millimetres; and since the horizontal measure of the type-column is
  also about 83 mm., each ordinary Folio line may be said to contain 20 ems"
  (i. 35). At 16 a pentameter does not fit, so **a third of all verse lines
  were being turned over**, each turn-over costing a second line of type.
  Correcting it took turn-overs from 333 to 139 per 1000 verse lines and the
  book from 1,386 pages to 1,026, against the real Folio's 908.
- **A fuller spelling could overrun the measure and crash the compositor.**
  `justify` re-checks the squeeze every round and gives up at HAIR; the
  *stretch* — fuller spellings to fill a loose line — was never re-checked, so
  it could overshoot. It needs words long enough that one substitution
  overruns a 16-em column, which is why only Hamlet found it:
  `historical-pastoral` became `hiſtorical-paſtoralle` and the line overhung by
  one hair space. Habit proposes, the measure disposes.
- **Copy names broke past 26 copies.** `(integer->char (+ 65 i))` gave copy 27
  the name `Copy [`, copy 28 `Copy \` — not a legal Windows filename — and copy
  33 `Copy a`, which after `string-downcase` overwrote copy A. Now A…Z, AA, AB…
- **The heap table printed every copy name per forme.** Fine for four copies,
  useless for 1,200: one forme ran to six hundred names and buried the finding
  underneath. Counts now, with the first ten names.

**Then the Norton Facsimile arrived**, and it did what every source the user
has supplied has done. Two kinds of evidence came out of it, and both
overturned something.

*Measured off the plates.* The facsimile's OCR is good enough to count on, and
Hinman's through-line numbers identify a genuine leaf, so the whole book can be
measured rather than sampled — 790 pages, 101,006 lines of type:

| | word divisions per 100 lines |
|---|---|
| whole Folio | **2.03** |
| prose plays (Merry Wives, Much Ado, As You Like It) | 6.41 |
| verse plays (Macbeth, Caesar, Richard II, King John) | 0.40 |

The 16× gap confirms the model's rule — verse turns over where prose divides —
and the three rates together *solve* for the book's composition: 73% verse,
which agrees with the usual literary estimate of 70–75%.

**We were producing 94%**, and the cause was the `<l>`-per-line fix above.
`looks-like-verse?` asks whether a line is under 78 characters, which is fair
for copy whose breaks mean something and useless for copy a machine wrapped at
72: every wrapped prose line read as verse, and since verse does not divide,
word division collapsed to 0.15 per 100 lines. Classifying per *speech* on the
length of its non-final lines — verse averages 41 characters, prose 68 — gives
**73.2% verse and 1.77 divisions per 100 lines** against the measured 2.03.

This also retires a figure that had been quoted here for months. The word
division rate was calibrated on "5.1 per 100 lines across five scenes of *Much
Ado*"; the whole book gives 2.03. **The single sample was 2.5× the book**,
because those scenes are prose and most of the Folio is not.

*Read out of Hinman's introduction* (pp. xix–xxi), which gives the press-variant
figures his two volumes do not summarise: "just over 500" press variants in the
whole book, about seventy in the Comedies (in 29 of more than 300 pages),
seventy in the Histories (in 31 of 262), and some 370 in the Tragedies — half
of those in the seventy-odd pages set by Compositor E, whose work was reviewed
because he was "evidently expected to make many errors". That is roughly a
hundred variant formes in about 450.

| | model, before | Hinman |
|---|---|---|
| formes corrected mid-run | 258 of 511 (50%) | ~100 of ~450 (22%) |
| press variants | 1,035 | "just over 500" |
| impressions before correction | median 8% | "about 100" of 1,200 = 8.3% |

The last of those was already right and is the one nothing was fitted to. The
first two were wrong because `proof-rate` was an unsourced 0.6; it is now 0.28,
derived from his count. The *unevenness* was already modelled — E's formes are
proofed 1.9× as often — and only the base rate under it was wrong.

**Two further defects the scale exposed.**

- **`--cancel-rate` was drawn per surviving error, not per leaf**, so its
  meaning changed with the length of the book: 0.15 meant one leaf in eight on a
  pamphlet and 349 of 511 leaves on the Folio, against the real book's one
  famous cancel. A parameter whose meaning depends on the size of its input is
  not a parameter. Now at most one cancel per leaf.
- **The discrimination anchor had rotted.** It was fitted at 0.20 when the folio
  measure was an unsourced 16 ems; correcting the measure to Hinman's 20 put a
  quarter more type on the page and the same eye found a quarter more evidence
  on it. Re-anchored to 0.26 (11.5 types a page against his 11–12). **The quarto
  check no longer passes at the same value** — about 4.3 against Blayney's 5–6 —
  and that is left standing, because his reasoning assumes a quarto page holds
  half a folio page's type-area where ours holds 30%. Tuning until both fit
  would bury the discrepancy that says one of the two measures is still wrong.

### Results against the record

Everything below is the whole Folio at a full edition of 1,200 copies. The
right-hand column is what the literature says; the middle is where the program
now lands. Nothing was tuned to close a gap — where one is left, it is left.

| | before | after | recorded | source |
|---|---|---|---|---|
| verse share of the text | 94% | **73.2%** | 73% | solved from the Norton plates |
| word divisions per 100 lines | 0.15 | **1.77** | 2.03 | measured, 790 plates |
| press variants in the book | 1,035 | **561** | "just over 500" | Hinman, Norton, p. xx |
| formes corrected mid-run | 258 of 511 | **144 of 510** | ~100 of ~450 | ibid. |
| impressions before correction | median 8% | median 8% | "about 100" of 1,200 | ibid. |
| identifiable types per page | 18.9 | **12.7** | 11–12 | Blayney i. 96 on Hinman |
| type page | — | 20 ems × 2 × 66 | 20 ems × 2 × 66 | Hinman i. 35 |
| leaves cancelled | 349 of 511 | **69 of 510** | one famous cancel | McKerrow, Hinman |
| pages | 1,386 | **1,020** | 908 | the book |

The uncorrected-impressions figure is the one nothing was fitted to: it falls
out of the edition size and Hinman's own four pulls a minute, and it was right
before anyone looked.

Two gaps are deliberately open. The **quarto type-density check no longer
passes** at the folio's re-anchored discrimination — about 4.3 against
Blayney's 5–6 — because his reasoning assumes a quarto page holds half a folio
page's type-area where ours holds 30%; tuning until both fit would bury the
discrepancy that says one of the two measures is still wrong. And **pages run
12% over**, which is accounted for: Gutenberg prints a scene list and Dramatis
Personæ at the head of every play that the Folio does not.

### What a plate showed that no statistic did

Setting a page beside the Norton facsimile of the same play found four things
the numbers could not, because none of them changes a rate:

- the running title read `THE HISTORY` — the book's global default — on all
  1,020 pages, where the Folio names the play;
- Gutenberg's italic markers were being set as type, 4,510 underscores;
- the Folio's **box frame and centre rule** were not drawn at all, though
  Hinman treats them as skeleton furniture and a bruised rule is evidence in
  the same way a damaged running title is;
- the first line of a speech is indented in the Folio and flush in ours.

All four are now fixed, and the last two turned out to be larger than they
looked.

**The speech indent** was applied to the prose path first and did nothing,
because three-quarters of the Folio goes through `set-verse`, which had no
first-line indent at all. It is `set-verse #:first-indent?` now, taken only by
the line that carries the prefix — which is what Lear 295 shows: `Lear.
Returne to her? and fifty men dismiss'd?` stands in from the margin and the
five lines under it do not. The indented line is genuinely narrower and so
turns over sooner, which is why the Folio turns over on prefix lines more than
on any other.

**The brackets** wanted more than a regex, as expected, and the visible stray
`]` was the small half of it. `[Aside.] I must obey ...` matched the direction
test on its first character, so the *entire verse line* was set as a
direction — italic, ranged right — with the bracket surviving the trim. 611
lines of the Folio went that way, 350 more broken mid-line, 45 at the end, and
5 wrapped across two lines with the `[` on one and the `]` on the other. The
brackets are now lifted in `copytext.rkt` before anything else reads the line:
a modern edition's square brackets are apparatus, exactly like Gutenberg's
underscores, and there is not one on any page of the Folio. Each bracketed
span becomes a direction in its own right — above the line if it stood before
any speech, below if it interrupted or followed it — and the verse line it was
sitting in survives whole, which splitting it would not.

### Rules, borders and ornaments are objects

Prompted by the question *what do the sources say about frames and ornaments —
those are objects too*. They are, and the sources are unanimous and precise:

- **They print.** A rule is type-high, which is exactly what distinguishes it
  from the furniture (Blayney i. 124 n. 2), and is cast on a body of so many
  ems — McKerrow infers the existence of wide spaces from the fact that
  "ornaments and rules of several ems in length were quite common" (p. 108).
  The Cambridge press bought brass rules from a London joiner at about
  sixpence each (McKenzie i. 42).
- **Five to a page, ten to a forme.** "Each page is surmounted by a headline
  and enclosed in a frame of 'box' rules. Five box rules appear, since one is
  used below as well as one above the headline. Although it is within the four
  rules that frame the page as a whole, therefore, the headline is
  nevertheless separated from the text proper by a rule" (Hinman i. 51).
- **The two kinds go different ways.** Box rules are the skeleton's, stripped
  and lifted with the running titles (Gaskell p. 109 counts them among the
  skeleton's "regularly repeated rules or ornaments"). The centre rule
  "belongs to the type-page proper rather than to its skeleton, and it was not
  removed from the type-page during stripping operations" (Hinman i. 130) — it
  goes to the case with the type beside it.
- **The arrangement is the fingerprint.** "Almost never, when rules took up
  new positions in a given forme, did they resume exactly their former
  positions in some later forme. Hence a given arrangement of rules serves to
  define a group of formes belonging to the same printing sequence" (i. 148).
  A whole new set of box rules *is* a new skeleton (i. 44).
- **They wear, and the wear is datable.** Hinman follows individual centre
  rules by their degeneration and names three of the worst in the last quire
  of the Tragedies (i. 148). The satyr tailpiece was damaged during the
  printing of Z6 and is found in two states in the Folio (i. 20).

So `imposition.rkt` has a `type-rule` struct: an id, a kind, a length in ems or
lines, accumulated damage, and impressions worked. The skeleton owns ten of
them and a mutable arrangement re-drawn every few formes; the page owns a
centre rule drawn from a shop stock sized to the standing formes. They wear at
one imperfection per 25,000 impressions, which is read off what Hinman treats
as *remarkable* — extreme degeneration worth a footnote at the end of a book
of some 500 formes. They are written to the TEI as `<milestone unit="rule">`
with `@hp:role` saying which stock they belong to, and the facsimile draws the
rules the file says are there, with damage and a hover naming the piece.

The stylesheet's `border: 1px solid` box is gone with them: four sides of one
CSS border cannot be four objects, and Hinman's whole argument is that they
are.

**Still only rules.** Ornaments, factotums, head- and tail-pieces are not
modelled. The satyr is the obvious next one and is fully specified in the
sources — a rectangle of about 70 × 120 mm, used as a tailpiece for 24 of the
36 plays whenever the last lines take up less than about two-thirds of the
final page, in two states either side of Z6.

**What it showed that is not a defect.** Three mechanisms report nought on the
Folio — pages crowded, lines of copy dropped, catchwords not answering — and
all three are alive. They are consequences of the casting off, and casting off
is some sixteen times tighter on verse than on prose, because the man counts
verse lines and estimates prose: `slip` in `imposition.rkt`, 0.06 against 1.0,
which is Gaskell's point. The same code on prose copy at the same accuracy
crowds 109 pages per thousand and drops 406 lines per thousand. **The report
now says so beside the noughts**, because a bare `0.00` is exactly the reading
that once had a live mechanism written off as dead here.

`tools/audit-mechanisms.py` sorts every countable mechanism into *fired*,
*silent*, and *not offered*, and now distinguishes a silence with an
established explanation from one without. It exits non-zero only for the
latter, so it is usable as a check.

**Greg's consistency condition depends on how many copies you collate**, which
was not expected and is worth chasing:

| heap-disorder | 24 copies | 200 copies |
|---|---|---|
| 0 — Gaskell's ideal | HOLDS | HOLDS |
| 0.15 — the default | HOLDS | **FAILS** |
| 0.5 | FAILS | FAILS |

At the default disorder the condition holds on a small collation and fails on a
large one. That is the detector working — more copies mean more chances for the
warehouse's lost order to show — but it means **a bibliographer collating four
copies would conclude the heaps kept their order when they did not**. The
sensitivity of Greg's test to sample size is measurable here and is not, as far
as I know, anywhere in the literature.

---

## 7. Widen the calibration base

Nearly every rate rests on **one pairing**: about 12,000 words of the *Much Ado*
quarto against the Folio set from it. That is a narrow base for the confident
tables the reports print.

- [ ] **F2, F3, F4.** Furness's Variorum collates three further reprint
      generations, each set from its predecessor, with variants recorded line by
      line. Three more copy→print transmissions with known copy, which would
      roughly quadruple the evidence. Extracting them means reading the apparatus
      rather than diffing, since the interesting cases are errors *shared*
      between texts, which a mechanical diff cannot see.

- [ ] **Manuscript copy.** Every misreading profile assumes printed copy. Setting
      from a secretary hand is a different problem with a different confusion
      set, and the Duport manuscript and Newton's *Opticks* copy survive with the
      compositors' marks on them.

---

## Built

Kept short on purpose. Each of these was argued out at length when it was done;
what is worth carrying forward is the number it produced.

**The material.**

- **Space-metal is type** — the biggest thing the model was missing. A gap is a
  cast body picked by hand from a box that can empty. **16% of everything set is
  white**, and the thick space is as common in a fount as the letter `e`. The
  fount rose from 21,953 to 31,200 because Blayney's table counts letters,
  capitals, points and ligatures and no quads at all. Provisioned from *prose*
  demand, the play strain falls out by itself: a play empties the em-quad box
  (100% out against 8% for prose) because every short speech line is quadded to
  the measure — Blayney's asymmetry, reproduced rather than fitted. Justification
  is quantised as a consequence: 86% of the old gaps were widths no founder ever
  cast, and a line now fills to within less than a hair (median 4/120 em) rather
  than exactly. The white is in the TEI, body by body on each `<lb/>`.
- **The bill of type and the size of the fount** — wrong by nearly a factor of
  three. 60,000 sorts was derived from Jaggard's Folio pica, the largest house in
  London working in folio; the default is now Okes's measured 21,953. Two
  independent checks came out right: 465 `y` and 974 `i` against Blayney's "at
  least 500 'y's and 1,046 'i's", and 67 `i` a page against his measured 66.
- **The ladder of shifts** when a box runs dry, in Blayney's order: set `VV`; rob
  a standing page at the margins; distribute a forme early; set a sort face down
  and fill at proof; send to the founder. On *Areopagitica* the ladder reads 226
  robbed, 13 wrong-fount, 4 face down, against 248 wrong-fount before.
- **`ſt`, `ſh`, `ſi` as sorts.** `ſt` at 200 is Okes's commonest ligature, more
  than `ﬀ`, `ﬁ` and `ﬂ` together. A ligature prints as its two letters; what
  differs is which box emptied.
- **Type-supply governs spelling** — the best thing in Blayney. B's choice
  between `-ie` and `-y` looked incoherent until the boxes were tabulated: over
  200 `y` available he set 49% `-y`, between 100 and 200 he set 42%, below 100 he
  set 29%. A spelling test measures the case as well as the man.
- **Inverted sorts as evidence.** Short `s` upside down at 1 in 150, invisible to
  the corrector and legible three centuries later.
- **The sheet, and the size it makes.** `paper.rkt`. Format is a folding and not
  a size; the two together give a leaf. Named stocks with foolscap 420×320 mm the
  default (Gaskell p. 68: the sixteenth century's ordinary printing paper), and
  one rule — a fold halves whichever dimension is longer — which reproduces his
  Key III exactly for pot, demy and royal in all three formats. The proportion
  alternates: from one sheet the folio is 1.52 tall to wide, the quarto 1.31, the
  octavo 1.52 again.

**The book.**

- **Preliminary signatures** — `sig-series` for `* ** ***`, `* † ‡ §`, `¶ ¶¶`,
  lower-case, the main alphabet, and McKerrow's `π` for leaves carrying nothing.
  The collation formula takes runs, so it prints `4°: A² B–L⁴`, Blayney's own
  formula for *Lear* Q1.
- **Printing the preliminaries last**, and East's decision about the Table
  reproduced rather than imitated: is there room in the white leaves already
  left, and does moving it save leaves at the front?
- **The title-page, generated as copy** so it goes through the same compositor —
  from Blayney's Appendix II, about ninety transcripts from one shop 1604–9.
- **The last sheet**, with preliminaries printed in the white leaves and cut out,
  conjugate from the centre and disjunct from the tail.
- **Cancels** — the trace simulated and the cause parameterised, which is
  McKerrow's own division ("into the purpose of these cancels we need not
  enter"). Five of his six detection tests are generated; the sixth is the paper,
  and is §3.
- **Folding, gathering and the binder's errors** — five kinds of fault, all from
  the sources; the *rate* is a parameter with no authority claimed for it.
- **Half-sheet imposition**, for the case that arises: a two-leaf gathering is one
  forme worked and turned (Gaskell, p. 83), and `A2` is the commonest preliminary
  arrangement in Blayney's checklist by a wide margin.
- **Correlated press-variant states**, the meeting point of Gaskell and Greg. A
  made-up copy is conflation by construction, so Greg's consistency condition
  detects whether the heaps kept their order: **60/60 consistent at disorder 0,
  16/60 at disorder 1** — the second being what this program used to do.

**Reading the copy.**

- **`import.rkt`** — Markdown with YAML, TEI and EEBO-TCP, LaTeX, Word, HTML and
  PDF, in three tiers: *declared*, *constructed*, and *nothing at all*, which is
  what plain text gets and is the honest answer.
- **The heading vocabulary was the wrong instrument** and is off by default.
  Demonstrated rather than argued: against Aylett's *Peace with her foure
  Garders* (1622) it found nothing, because the book opens with fourteen lines of
  dedicatory verse under no heading, so the walk stopped before the vocabulary
  was consulted once.
- **Scribal frequency has a slope**, which two data points could not show.
  Tildes per thousand words fall 2.99 → 0.19 across the 1580s to the 1630s; the
  superscript brevigraphs never crossed over from the hand at all (`yᵗ` at 5.5
  per *million* words against the program's 6,600). `--year` sets the date.

**Output.**

- **One rendering, not two.** The facsimile is built by `tei-html.rkt` out of the
  `.tei.xml` and nothing else, so anything absent from the TEI is absent from the
  page — a property rather than a discipline that has to be remembered. It found
  two things immediately: the TEI carried no record of which damaged sorts set a
  word, and no statistics.
- **Four views and a filter.** The book, the make-up, the evidence, the copies;
  a map of the whole run, collation diagrams that show which leaf comes loose
  when another is cut out, and a legend that filters the apparatus by kind of
  departure — the one thing a screen can fix that a printed apparatus cannot.
- **The leaf at its true size**, drawn from the sheet in the file rather than
  invented by the stylesheet.

**Defects found by measuring rather than by looking.**

- **Words collide in the tightest lines** — *not* systematic. 13 touching pairs
  in 16,219, or 0.08%, the residue of substituting a real font for a table of
  widths. My visual impression from one screenshot overstated it by a wide
  margin.
- **Turn-over never fires** — *not* dead. It fires on verse, once in 267 lines of
  *Hamlet*, and reads zero on prose because only a verse line can be turned over.
  The real defect was a report that printed a bare `0.00`.
- **Foul case fired on every u-for-v** — 1,048 words classified as accidents
  against a measured rate of about five for that book. Self-inflicted by a
  rename. **1,048 → 7.**
- **A paragraph longer than a page was never divided when it began the page**, so
  a two-hundred-line paragraph was cast off as one page of thirty-eight.

---

## Not doing, and why

**Answering McKenzie.** The objection is correct and the program cannot escape
it. Every percentage the analysis produces is the analyser inverting the
generator; both were written from the same account of how a printing house
behaved, so agreement demonstrates self-consistency and nothing else. The right
response is to keep saying so in every report and to build §5, which makes the
failure visible rather than arguing about it.

**Fitting the parameters to the sample.** Several rates sit close to their
measured targets. It would be easy to close the remaining gaps by adjusting until
they matched, and the result would be worthless. Where a figure is off it is left
off, and said to be off: the tilde runs about 1.5× the median for 1605 (inside
the interquartile range, so unremarkable), and the ampersand at twice the 1630s
median, between that median and its 75th percentile.

The note that used to stand here — "the ampersand at roughly twice the observed
rate" — was measured against the Folio's fourteen in twelve thousand words, and
the corpus says the Folio is unusually sparing. Against the median book of its
decade the ampersand was about right all along. **A figure said to be off can be
as wrong as one said to be right.**

---

## The rule this project actually runs on

**Every parameter checked against a real book has been wrong**, most by an order
of magnitude, and always in the direction of making the simulation more
picturesque than the truth. Assume the next one is too.

**A parameter anchored on one example is anchored on that example's end of the
range.** 60,000 sorts was not a guess; it was carefully derived from the
best-documented fount of the period — and from the largest house in London
working in folio, which made every other shop three times richer than it was and
suppressed the shortages that are half the evidence. One good anchor at the wrong
end of a range is more misleading than no anchor, because it looks like
diligence.

**A rename that crosses a classification boundary is a change of meaning, not of
names.** Redefining `composed` to mean the reading rather than the set form left
the accident test comparing two things that differ by convention, and it reported
1,048 accidents where there were 7. Nothing failed; the number was simply wrong,
and only a reader who knew the expected rate would have caught it — which is the
argument for keeping the measured rates written down beside the code.

**One property, one decision point.** Two stages settling the same thing will
contradict each other, and the contradiction hides until something forces them
apart. The deviation vocabulary lived in five places and had already drifted. The
leaf's size was decided by the stylesheet while the format was decided by the
model, and when the paper was finally given a size, two bugs fell straight out
that the old arrangement had concealed by feeding both sides the same wrong
number.

**A parameter no test exercises and no report counts will be dead without anyone
noticing.** Four so far — `catches-misreading`, the catchword bracketing, the
omission branch, and the crowding devices. Turn-over was wrongly added to that
list and taken off again. To which that episode adds a corollary: **a report that
prints a bare zero cannot distinguish a thing that did not happen from a thing
that could not.** Both look like evidence and only one is.

**One seed is not a measurement, and this applies to rates and not only to rare
events.** It was already written down here that a test asserting a rare event
happened at least once, on one seed, is a test of the seed. The same is true of
every rate the report prints. Word division on one width table ranges from 65 to
113 per thousand lines across eight seeds — a 74% spread — so a single-seed
comparison can produce any answer you like, in either direction, and it will
look like a finding. Two claims were made that way in one session and both were
noise. Before comparing two versions of anything, run enough seeds to see the
variance, and pin whatever is drawn at random: the preliminary signature scheme
is on `auto` by default, so it re-draws whenever the RNG stream shifts and turns
an unrelated change into an apparent change of collation.

**A normalisation that looks neutral can smuggle in the effect you are testing
for.** Substituting a measured width table, I held the unweighted mean over
a–z, which seemed the obvious control. `i` and `s` are 13.5% of the text between
them and both shrank hard, so the frequency-weighted mean fell 2.56% and the
text simply set narrower — I had changed the density while believing I had
changed only the proportions. Ask what a control actually holds constant, and
weight it by how often each thing occurs in the copy rather than by how many
kinds there are.

**The corpus can answer questions about marks, not only about words.** The
scribal rates were guessed from two books for several sessions while 5,287 sat on
disk, because `lexicon.rkt` reads that corpus as a list of *spellings* and a
spelling test cannot vouch for `yᵗ`. True of the lexicon, irrelevant to the
corpus, which is text, and in which every tilde is countable. The tool was built
for one question and I stopped asking it others.

**Verify in both colour schemes.** A page can be correct in every measurement I
take and unusable on the machine it is opened on. The facsimile shipped with a
dark-mode override on `body` and `.leaf` and on nothing else, so on a dark
display the masthead kept its parchment ground while its text turned light —
title, lede and all four tabs at 1.03:1, which is invisible — and the collation
diagrams were dark line-work on a dark ground. Headless renders default to light,
so none of it appeared in any screenshot taken here.
