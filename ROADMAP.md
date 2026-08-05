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

- [ ] **Scribal frequency.** They are on by default now and fire too often.
      The target is measurable: the 1600 quarto has four tilde vowels in
      12,000 words and F1623 none, while F1 has fourteen ampersands. So about
      one scribal sign per 3,000 words for a printed English book of this
      period, with the ampersand an order of magnitude commoner. Note that the
      lexicon cannot help here and should not: a wordlist cannot vouch for
      `yᵗ`, which is a mark rather than a spelling, so these are exempt from
      the gate by design and their rate is governed only by the compositor's
      `contracts` weight.

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

- [ ] **Blayney properly.** 778 pages, and the only source not worked through.
      Its subject — one quarto's transmission reconstructed in detail — is the
      closest thing in the literature to what this program does end to end.

- [ ] **Manuscript copy.** Every misreading profile here assumes printed copy.
      Setting from a secretary hand is a different problem with a different
      confusion set, and the Duport manuscript and Newton's *Opticks* copy
      survive with the compositors' marks on them.

---

## 5. Modelling gaps, in descending order of consequence

- [ ] **Per-compositor type cases.** Hinman distinguishes cases x, y and z, and
      much of his argument turns on which man used which. Here every workman
      draws from one pair, which makes the type evidence cleaner than it was.
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
- [ ] **One rendering, not two.** `render.rkt` builds HTML from the book and
      the XSLT builds it from the TEI, and the two duplicate each other. Three
      separate drift bugs came out of that in a single session: a stylesheet
      that existed twice and went stale in one copy, a script that existed in
      only one of them so the TEI grew the buttons and none of the behaviour,
      and classes one path uses that the other does not. The TEI carries
      everything of substance, so the direct renderer is redundant and
      `--html` should run the XSLT. Held back only because the Bowers
      description, the statistics and the key have to be ported into XSLT 1.0,
      which has no functions and no grouping.
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
until they matched, and the result would be worthless. Where a figure is off —
the ampersand at roughly twice the observed rate — it is left off, and said to
be off.

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

And: **a parameter no test exercises and no report counts will be dead without
anyone noticing.** Four so far — `catches-misreading`, the catchword
bracketing, the omission branch, and the crowding devices. Turn-over was
wrongly added to that list and taken off again.

To which the turn-over episode adds a corollary, learned by getting it wrong:
**a report that prints a bare zero cannot distinguish a thing that did not
happen from a thing that could not.** Both look like evidence and only one is.
Where a measurement does not apply, say so.
