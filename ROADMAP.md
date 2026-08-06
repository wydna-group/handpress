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

**Turner's rule belongs here**, and is the sharpest single experiment available.
The principle is that "in a quarto set by formes, type from the first forme of
each sheet normally reappears in both formes of the succeeding sheet, but type
from the second forme only in the second forme". Blayney takes his *Midsummer
Night's Dream* table and shows that the further claim — that "when type
reappears in this manner, composition cannot have been seriatim" — is
"completely untrue", the same evidence being perfectly consistent with seriatim
setting. This program knows which it did. Generate the recurrence table, run the
rule, count how often it is right.

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

## 4. Concurrent production — the McKenzie mode

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

## 5. Smaller, and well specified

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

---

## 6. Widen the calibration base

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
response is to keep saying so in every report and to build §4, which makes the
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
