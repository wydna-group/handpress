# Roadmap

Ordered by evidential value rather than by effort. The question asked of each
item is not "would this be interesting?" but **"would this let the program be
wrong in a way we could detect?"** — which is the only thing it has ever been
good for.

---

## 0. Wanted next

Four things asked for, in the order I would build them. The first three are
one piece of work in disguise, which is the interesting part.

- [ ] **Preliminary signatures.** `*`, `¶`, `a`–`z` before `A`, instead of
      continuing the sequence. Not decoration: McKerrow explains *why* they
      exist. A printer who ends a book with spare leaves in the final sheet
      and has preliminary matter to print "will as a matter of course" set the
      preliminaries there — so they are printed **last**, on paper already on
      the press, and must be "considered last and in close conjunction with
      the final sheet of the book, as the printer necessarily considered
      them." A separate signature series is the consequence of that, not a
      convention on its own.

- [ ] **Binding.** Sheets folded, gathered and sewn — and got wrong. Sheets
      bound out of order, inverted, duplicated, omitted. This is the one stage
      where the *book* diverges from the *printing*, and the analysis ought to
      have to cope with it. It is also where the blank leaves go: fill them
      with preliminaries and cancels and most of them stop being blank.

- [ ] **Cancels.** Gaskell has Rousseau's publisher urging him "to use up the
      blank leaves of final sheets for printing cancels" — a corrected leaf
      cut out and its replacement pasted to the stub. Common, visible, and the
      other half of the blank-leaf question.

- [ ] **Collation mode.** Compare two witnesses, or a witness against its
      copy-text, and report the differences as an apparatus. Most of the
      machinery exists — `collate` superimposes two made-up copies, the TEI
      already carries `<app>`/`<rdg wit>`, and the deviation classifier knows
      what kind of change each one is. What is missing is the front end and
      the ability to collate against an arbitrary text rather than another
      copy of the same setting.

- [ ] **More import formats.** PDF and Markdown at least.
      `tools/strip-gutenberg.py` is the pattern: the job is not parsing but
      *preparing copy* — joining wrapped lines so a paragraph reaches the
      compositor whole, and discarding the modern edition's apparatus, which
      would otherwise be cast off and set as though the author had written it.

- [x] **Scribal frequency.** Done, and the target I set here was wrong in both
      directions at once. I proposed one sign per 3,000 words from two data
      points — four tilde vowels in a quarto of 1600, none in F1623. Counting
      them properly in the 5,287 EEBO-TCP books already on disk shows why two
      points could not work: **the practice has a slope.** Tildes per thousand
      words, median English book of the decade, from 32.4M words:

      | | 1580s | 1590s | 1600s | 1610s | 1620s | 1630s |
      |---|---|---|---|---|---|---|
      | tilde | 2.99 | 1.34 | 1.01 | 0.54 | 0.21 | 0.19 |
      | ampersand | 5.45 | 3.11 | 3.18 | 2.36 | 1.92 | 1.47 |

      So my target was three times too low for 1600 and about right for 1635,
      and F1623 having none is unremarkable rather than evidence: the 1620s
      median is 0.21 and an eighth of English books have none at all. The
      conventions now carry a **year**, and `--year` sets it.

      The three things lumped together as "scribal" turned out to have three
      different histories. The **ampersand** crossed over from the hand
      completely and is ordinary printing — left ungated. The **tilde** crossed
      over and stayed productive (4,922 distinct marked forms, from `thē` and
      `frō` down a long tail to `iudgemēt` and `strēgth`) but its frequency
      collapsed; the rule was right and ran ten times too fast. The
      **superscript brevigraphs** did not cross over at all: `yᵗ` occurs 5.5
      times per million words of printed English, `wᵗʰ` 0.2, against the
      program's 6,600. Roughly nine hundred times too many.

      I was also wrong about the lexicon, though not in a way that changes the
      design. A wordlist cannot vouch for `yᵗ` and still cannot — but the
      *corpus behind it* can, because TCP renders the flattened forms as text
      rather than silently expanding them. The corpus could have answered this
      at any point in the last several sessions and I never asked it.

---

## 0a. Out of Blayney, and not yet done

Mining *The Texts of King Lear* fixed six things (see §5 and the commit) and
opened four. These are ordered by how much they would change.

- [ ] **Cannibalization, and the ladder of shifts.** The fount is now Okes's
      size, and that is right; but the *responses* to a shortage are still one
      rung of a five-rung ladder. Blayney watches compositor B want a `W` and
      work down it: set `VV`; take the sort out of a page already standing,
      preferring the margins and speech prefixes because "if types are taken
      from the middle of an undistributed page there is a risk that several
      lines will be pied"; distribute a forme early; **set an `M` or a ligature
      face down so that the foot printed as two black rectangles, and insert
      the right type during proofing**; buy or borrow more. The program has the
      first rung and a crude version of the third. It has no cannibalization at
      all, which is why *Areopagitica* still shows 248 wrong-fount sorts where
      Okes's books show a handful. The face-down placeholder is the prettiest
      of them: a deliberate blank that makes press-correction *necessary*
      rather than optional.

- [ ] **`ſt`, `ſh`, `ſi` as sorts.** `ſt` at 200 is Okes's commonest ligature by
      a wide margin — more than `ﬀ`, `ﬁ` and `ﬂ` together — and the program has
      no such sort, so their work falls back on the plain long s and the box is
      inflated to 745 to cover it. The glyph pipeline already carries long s as
      markup rather than as text, so this may be cheaper than it looks.

- [ ] **Turner's rule, run against the truth.** The best experiment in the
      book, and the program is the only thing that can settle it. Turner's
      principle is that "in a quarto set by formes, type from the first forme of
      each sheet normally reappears in both formes of the succeeding sheet, but
      type from the second forme only in the second forme". Blayney takes his
      *Midsummer Night's Dream* table and shows the claim that "when type
      reappears in this manner, composition cannot have been seriatim" is
      "completely untrue" — the same evidence is perfectly consistent with
      seriatim setting. This program knows which it did. Generate the
      recurrence table, run the rule, count how often it is right. See §2.

- [ ] **Points shared between founts.** Punctuation was "the common property of
      all founts of the same body-size", and Okes was still setting the
      Snowdons' points among his own. So a point is not owned by a fount, and
      the comma box should be shared across every fount in the house. Matters
      as soon as there is more than one fount, i.e. with §3.

## 1. Defects — investigated

Four were listed here. Measuring them found that two were not what they
looked like, which is the usual result and the reason for measuring first.

- [x] **Words collide in the tightest lines.** ~~Systematic.~~ Measured on
      *Areopagitica*: **13 touching pairs in 16,219, or 0.08%**, with the
      median gap at 6.1px against a true thick space of 5.33px. Not a
      modelling error but the residue of substituting a real font for a table
      of widths — a word heavy in long s or capitals renders a shade wider
      than the model allows and borrows the space from its neighbour. Lowering
      `--fit` would clear them and would widen every other gap away from the
      space it is meant to be. Wrong trade. Left as measured, and the CSS
      comment now records the figures. **My visual impression from one
      screenshot overstated this by a wide margin.**

- [x] **Turn-over never fires.** ~~The fifth dead mechanism.~~ It is not dead.
      It fires on verse — once in 267 lines of *Hamlet* — and reads zero on
      prose because **only a verse line can be turned over**; prose that
      overruns is simply wrapped. Every deviation report I had looked at was
      prose. The real defect was in the report, which printed a bare `0.00`
      that could not distinguish *never happened* from *cannot happen here*,
      and so invited exactly that misreading. It now says which, and rates
      turn-over against verse lines rather than all lines.

- [ ] **`runne` modernises to `rune`.** Still open, and now believed
      unfixable by rule. The grouping assigns an old form to its nearest
      current word by edit distance: `rune` is one letter from `runne`, `run`
      is two. Frequency would arbitrate it correctly — `run` is far commoner —
      but the same change breaks `heere`, which is one letter from `here` and
      two from the much commoner `her`. The two cases are orthographically
      identical and lexically opposite. This is precisely why VARD keeps a
      human in the loop, and the honest next step is to **measure the error
      rate on a hand-checked sample** rather than to keep adjusting a rule
      that cannot in principle succeed.

- [x] **Foul case fired on every u-for-v.** 1,048 words classified as
      accidents of the case against 12 misreadings, where the measured rate is
      a quarter per thousand words — about five for that book. Self-inflicted:
      redefining `composed` as the *reading*, so the TEI would carry
      searchable English, silently changed what the accident test compared. It
      began asking whether the set form differed from the reading, which is
      true of every convention applied. Now compares what printed against what
      was composed, both as set. **1,048 → 7.** The lesson is the familiar
      one: a rename that crosses a classification boundary is a change of
      meaning, not of names.

- [x] **A produced form ignored the case of its source.** The devices that
      append letters built them from the word's core and added the letter in
      lower case regardless, so `HONOUR` came back `HONOURe`. Fixed at the
      chokepoint both `contractions` and `expansions` share, so every device
      inherits it.

- [x] **Blank leaves looked like a failure.** They are correct — a gathering
      is a whole sheet and must be completed — and are now labelled. But see
      §0: a printer would have filled them.

- [x] **Milton's division rate is unvalidated.** Nothing to retract: the
      figure appears in no published document, only in a commit message that
      already flags it. The caution stands — 148 per thousand lines against 51
      measured from F1, on a text whose vocabulary is far more Latinate, with
      no evidence either way — and it should not be quoted until there is a
      division rate for 1640s prose to check it against.

---

## 2. The one that matters most: forme order from type recurrence

**This is Hinman's actual method, and the program is uniquely placed to test
it.**

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
Expect Hinman's folio density to succeed and the quarto density to fail, and
the interesting number is where the boundary actually falls.

Everything needed is already tracked. `typecase.rkt` follows individual sorts
by their damage, records where each one printed, and `note-recurrence!` keeps
the places. What is missing is the inference: given only the recurrences, work
out the order in which the formes went to press.

The reason to build it above everything else is that **it grades itself**. The
simulator knows the true order. So it can answer a question no real book can:
how often does type-recurrence evidence give the right answer, and what does it
take to break it? Hinman's whole reconstruction of the Folio rests on this, and
nobody has ever been able to check it against a known truth.

Expect it to work well and then to fail interestingly — most likely when two
formes were set close together, when a case was replenished mid-forme, or under
concurrent production, where a sort may recur because it went to another book
and came back.

Related and cheap once that exists: **pagination errors as evidence of order.**
`pagination.rkt` already distinguishes errors of omission from commission
because Hinman says only the former are informative. Nothing yet uses them.

---

## 3. Concurrent production — the McKenzie mode

The program models one book at a time. McKenzie's central finding is that a
shop worked on several at once, and that the patterns this produces are "of
such an unpredictable complexity … that no amount of inference from what we
think of as bibliographical evidence could ever have led to their
reconstruction."

Every report says so and then carries on assuming otherwise. Building it would
mean:

- several books in the house at once, sharing men, presses and type
- a compositor's stint interrupted for weeks and resumed
- a case replenished from another book's distributed forme
- type recurring across books, not only within one

The point is not realism for its own sake. It is that **the analysis should
then fail**, and the interesting measurement is how fast and in which
direction. This is the honest reply to the objection: not an argument, an
experiment.

Needs a clock, which the program does not have. McKenzie supplies the rates —
compositors at 5,000–6,000 ens a day against a nominal 12,000, presswork at
about 250 impressions an hour.

---

## 4. Widen the calibration base

Nearly every rate in this program rests on **one pairing**: about 12,000 words
of the *Much Ado* quarto against the Folio set from it. That is a narrow base
for the confident tables the reports now print.

- [ ] **F2, F3, F4.** Furness's Variorum collates three further reprint
      generations, each set from its predecessor, with variants recorded line
      by line. Three more copy→print transmissions with known copy, which would
      roughly quadruple the evidence. Extracting them means reading the
      apparatus rather than diffing, since the interesting cases are errors
      *shared* between texts, which a mechanical diff cannot see.

- [x] **Blayney properly.** Done, and it supplied more usable numbers than the
      other five sources together — because his subject is one quarto
      reconstructed in detail, which is what this program does end to end.
      What came out of it is in §0 and §5; the short version is that the fount
      was nearly three times too large, the bill was interpolated from an
      eighteenth-century table when a measured English one exists, and a
      compositor's spelling turns out to be partly a fact about his boxes.

- [ ] **Manuscript copy.** Every misreading profile here assumes printed copy.
      Setting from a secretary hand is a different problem with a different
      confusion set, and the Duport manuscript and Newton's *Opticks* copy
      survive with the compositors' marks on them.

---

## 5. Modelling gaps, in descending order of consequence

- [x] **The bill of type, and the size of the fount.** Both were wrong, and the
      fount by nearly a factor of three. It stood at 60,000 sorts on one anchor
      at the top of the trade — Jaggard's Folio pica, calculated by Gaskell from
      Hinman — and the bill was interpolated from an eighteenth-century table.
      Blayney counted the other end: Okes set the whole of *Lear* Q1 from
      21,953 types weighing "unlikely to have been much more than 120 lb", and
      tabulated every sort of it against a quarter of Smith's 1755 bill and van
      den Keere's 1571 registre. So the default is now the small quarto house
      rather than the great folio house, on figures measured from an English
      book of the right decade. Two independent checks came out right: the
      scaled bill gives 465 `y` and 974 `i` against Blayney's "at least 500
      'y's and 1,046 'i's", and puts 67 `i` on a page against his measured
      average of 66.
- [x] **Type-supply governs spelling.** The best thing in the book. Compositor
      B's choice between `-ie` and `-y` looked incoherent — 73% in one sheet,
      38% in another — until Blayney tabulated the boxes page by page: over 200
      `y` available he set 49% `-y`, between 100 and 200 he set 42%, below 100
      he set 29%. The asymmetry is arithmetic, not psychology: `-ie` endings are
      under 4% of all the `i` set, but 60% of the `y` are terminal, so the
      choice can empty the one box and not the other. Hence his caution, which
      the program now embodies: a spelling test measures the case as well as the
      man.
- [x] **Inverted sorts as evidence.** Short `s` set upside down at 1 in 150 —
      invisible to reader and corrector, and legible three centuries later.
      With it, replenishment: Okes's `s` box was refilled mid-sheet from a
      wrongly-struck matrix, the rate went to 30 in 83 for three pages, and the
      cluster proves those pages were set seriatim.
- [ ] **Per-compositor type cases.** Hinman distinguishes cases x, y and z, and
      much of his argument turns on which man used which. Here every workman
      draws from one pair, which makes the type evidence cleaner than it was.
      Blayney adds the sharper version: Okes's men *divided* one fount into two
      cases part-way through the book, and after that "it is impossible to be
      sure how much type was in either case at any one point" — the division
      itself destroys the evidence.
- [ ] **Standing type between editions**, and the half-sheet imposition that
      goes with short books.
- [ ] **Cancels.** A leaf cut out and a cancellans pasted in is common, visible,
      and entirely unmodelled.
- [ ] **Two-pull press.** A folio forme needed two pulls; the timing model will
      need it when there is a clock.

---

## 6. Output and interface

- [x] Openings in the direct HTML — done, and in the TEI rendering too, with
      the leaf, sheet and forme a page belongs to lit on hover and pinned on
      click.
- [x] **One rendering, not two.** Done. `render.rkt` built HTML from the book
      in memory and the XSLT built it from the TEI, and three drift bugs came
      out of that in a single session. The facsimile is now built by
      `tei-html.rkt` out of the `.tei.xml` file and nothing else, so anything
      absent from the TEI is absent from the page — which is the property that
      keeps the TEI honest rather than a discipline that has to be remembered.

      It found two things immediately. The TEI carried no record of which
      damaged sorts set a word, and no statistics; both had gone unnoticed
      only because the renderer that needed them held its own copy of the
      book. Following a piece of type from one forme to another is the whole
      method this program exists to test, so a file that could not express it
      was not the record it claimed to be.

      **No Saxon.** The blocker was said to be XSLT 1.0's want of functions
      and grouping, but what could not be ported was never transformation:
      the statistics and the key are computations over counts and a join
      against a declared taxonomy. In XSLT 3.0 they would still be a rewrite
      of Racket that already exists, and the processor would be a JRE this
      project otherwise does not need. The constraint that matters — the TEI
      is the single source of truth — is about which way the data flows, not
      about which language does the walking.

      The stylesheet is kept, scoped to a plain reading text: the words, the
      page breaks, and the *reading* rather than the glyph, which is the half
      of every `<choice>` the facsimile does not show. It no longer attempts
      the analytical furniture, and the test asserts that it does not — if
      `dev-`, `--x:` or the statistics reappear in it, the decision has been
      quietly reversed. Its reason to exist is that the TEI can be consumed by
      standard tools; that reason survives without a parity claim it could
      never keep.

- [ ] Filter the type-facsimile by deviation class, so a reader can see all the
      foul case at once, or all the fitting alterations.

---

## Not doing, and why

**Answering McKenzie.** The objection is correct and the program cannot escape
it. Every percentage the analysis produces is the analyser inverting the
generator; both were written from the same account of how a printing house
behaved, so agreement demonstrates self-consistency and nothing else. The right
response is to keep saying so in every report and to build §3, which makes the
failure visible rather than arguing about it.

**Fitting the parameters to the sample.** Several rates now sit close to their
measured targets. It would be easy to close the remaining gaps by adjusting
until they matched, and the result would be worthless. Where a figure is off it
is left off, and said to be off: the tilde runs about 1.5× the median for 1605
(inside the interquartile range, so unremarkable), and the ampersand runs at
twice the 1630s median, between that median and its 75th percentile.

The note that used to stand here — "the ampersand at roughly twice the observed
rate" — was measured against the Folio's fourteen in twelve thousand words, and
the corpus says the Folio is unusually sparing. Against the median book of its
decade the program's ampersand was about right all along. A figure said to be
off can be as wrong as one said to be right.

---

## The rule this project actually runs on

Every parameter checked against a real book has been wrong, most by an order of
magnitude, and always in the direction of making the simulation more
picturesque than the truth. Assume the next one is too.

A third, learned by breaking the foul-case classification while renaming
variables around it: **a rename that crosses a classification boundary is a
change of meaning, not of names.** Redefining `composed` to mean the reading
rather than the set form left the accident test comparing two things that
differ by convention, and it began reporting 1,048 accidents where there were
7. Nothing failed; the number was simply wrong, and only a reader who knew the
expected rate would have caught it. Which is the argument for keeping the
measured rates written down beside the code.

And the one that should have been obvious: **the corpus can answer questions
about marks, not only about words.** The scribal rates were guessed from two
books for several sessions while 5,287 sat on disk, because `lexicon.rkt` reads
that corpus as a list of *spellings* and a spelling test cannot vouch for `yᵗ`.
That is true of the lexicon and irrelevant to the corpus, which is text, and in
which every tilde and brevigraph is countable. The tool was built for one
question and I stopped asking it others.

And a fourth, from the fount size: **a parameter anchored on one example is
anchored on that example's end of the range.** 60,000 sorts was not a guess; it
was carefully derived from the best-documented fount in the period. It was also
the largest printing house in London working in folio, and using it as the
default made every other shop three times richer than it was — which suppressed
the shortages that are half the evidence. One good anchor at the wrong end of a
range is more misleading than no anchor, because it looks like diligence.

And: **a parameter no test exercises and no report counts will be dead without
anyone noticing.** Four so far — `catches-misreading`, the catchword
bracketing, the omission branch, and the crowding devices. Turn-over was
wrongly added to that list and taken off again.

To which the turn-over episode adds a corollary, learned by getting it wrong:
**a report that prints a bare zero cannot distinguish a thing that did not
happen from a thing that could not.** Both look like evidence and only one is.
Where a measurement does not apply, say so.
