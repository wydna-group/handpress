# Roadmap

Ordered by evidential value rather than by effort. The question asked of each
item is not "would this be interesting?" but **"would this let the program be
wrong in a way we could detect?"** — which is the only thing it has ever been
good for.

---

## 1. Defects, before features

Small, known, and each one an instance of something that has bitten before.

- [ ] **Words collide in the tightest lines.** `progenythey`,
      `vigorouslyproductiue`, `knowthey`. Either the `--fit` calibration
      between glyph width and modelled type width has drifted, or the
      compositor is genuinely setting zero-width spaces where he squeezes
      hardest. Measure it in the browser against the modelled space widths —
      the CSS comment records how that was done the first time — rather than
      adjusting `--fit` until it looks right.

- [ ] **Turn-over never fires.** `turned over or under` reads 0.00 in every
      report. That is the fifth dead mechanism this project has found, and it
      matters more now: since division began refusing bad breaks, turning a
      word over is exactly what should happen in their place. Suspect the
      condition is unreachable, as the omission branch was.

- [ ] **`runne` modernises to `rune`.** The variant grouping assigns an old
      form to its nearest modern word by edit distance, and `rune` is nearer
      than `run`. Nothing about the letters separates that from `heere`/`here`,
      where distance gives the right answer. Probably needs frequency to
      arbitrate, and needs its error rate measured rather than assumed.

- [ ] **Milton's division rate is unvalidated.** 148 per thousand lines against
      51 measured from F1. His prose is far more Latinate and some of that is
      real, but there is no evidence either way. Either find a division rate
      for a 1640s prose tract or stop quoting the figure.

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

- [ ] Openings in the direct HTML — verso and recto side by side as bound. The
      XSLT path does this; the direct one does not.
- [ ] A collation view: two made-up copies superimposed, as the Hinman collator
      shows them.
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

And: **a parameter no test exercises and no report counts will be dead without
anyone noticing.** Five so far — `catches-misreading`, the catchword
bracketing, the omission branch, the crowding devices, and turn-over. Before
adding a mechanism, decide what will count it.
