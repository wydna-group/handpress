# Findings

The record of what was got wrong and how it was found out, kept because **the
value of this project has been almost entirely in its corrections**. The roadmap
says what is open; this says what was learnt getting there.

It is deliberately not everything. A finding earns a place here only if it would
otherwise be **re-attempted** — a wrong turn someone would take again, a source
that turned out to say something other than its summary, an elimination that
saves a session. Twenty entries were retired when this file was split out of the
roadmap, being intermediate states of finished work.

**The fuller record is the git history.** Commit messages in this project carry
the reasoning at length, so nothing needs preserving here merely for the sake of
preserving it.

Ordered by the roadmap section each belongs to.

---

## §1 — Forme order from type recurrence

### The matrix was measured before the inference was designed, and it is the wrong shape for seriation

Step zero of the inference, and it changed the plan. The obvious way to recover
an order from a table of shared types is seriation — permute until similarity
falls away from the diagonal, which assumes a Robinson matrix. **The recurrence
matrix is not one.** Measured over 8 seeds, quarto, pairs counted only where both
formes hold identifiable type:

| forward offset | 1 | 2 | 3 | 4 | 5 | 6 | 7 |
|---|---|---|---|---|---|---|---|
| **standing 2** — mean shared | 2.21 | **0** | 1.03 | 3.14 | 4.09 | 2.56 | 2.36 |
| pairs sharing nothing | 50/90 | **82/82** | 44/74 | 6/66 | 3/58 | 8/50 | 6/42 |

Similarity does not decrease with distance. It is **zero next door and highest
four or five formes away**, because a forme cannot share a type with one standing
beside it — the metal is locked up in a chase — and its type only reaches the
case when it is distributed, a lag behind.

**The strongest evidence in the matrix is an absence, and it is absolute rather
than statistical.** At two formes standing, every one of 82 pairs at offset 2
shares nothing at all, while pairs four apart share nothing in 6 of 66. A pair of
type-rich formes with no type in common is not weak evidence of anything; it is
proof they stood together.

And the width of that zero band reads off the shop's discipline directly:

| `--formes-standing` | offset 1 | offset 2 | peak at |
|---|---|---|---|
| 1 | 54/91 zero | 4/83 zero | offset 2 |
| 2 | 50/90 zero | **82/82 zero** | offset 5 |
| 3 | **90/90 zero** | **82/82 zero** | offset 4 |

So **`--formes-standing` is recoverable from the evidence**, which is a different
inference from Hinman's and was not on this list. It also puts a number on the
condition Turner's rule depends on and never states: whether the rule can speak
of a book is a fact about that shop's standing-type discipline, and that fact is
itself readable.

**Consequences for the inference, which is still to build:**

- Build it on the zeros, not on a similarity gradient. The problem is closer to
  recovering a band structure than to ordering points on a line.
- Expect the global-flip ambiguity of §2 to reappear: shared type is symmetric
  and says two formes were near, never which came first. The signature sequence
  or Turner's rule would anchor it, and if the flip does recur then "structurally
  certain and globally unanchored" is a property of this evidence generally and
  not of one module.
- **The quarto sample is too short for the folio test.** At folio in sixes the
  same 12,000 words give three formes with *no* identifiable type at all, so
  Hinman's density threshold (§1 above) cannot be tested on it. That needs the
  Folio copy from §10 or a longer text, and finding it out now is cheaper than
  finding it out after the inference is written.

### First attempt at the inference: it produced Blayney's predicted result, and the result was a bug

Worth recording in full, because the near-miss here is the most dangerous kind
this project has met.

The attempt: build the shared-type matrix, weight each pair by a bump that is
negative while two formes stand together and peaks a lag later, search the lag
over 1–4, and hill-climb the permutation with segment reversals and single
moves from six random restarts. Then fix the direction from the trend in
identifiable-piece counts, since the fount batters as the book goes on and later
formes carry more distinctive type — the recurrence matrix being symmetric, it
can give the order only up to reversal, exactly as §2 predicted.

Kendall tau against the truth, quarto, eight seeds: **0.15, and a coin is 0.**

**That is precisely what Blayney says should happen.** A quarto page carries "no
more than 5 or 6 types", which "is not nearly enough to allow the page-order of a
quarto to be determined with any great precision". Our formes hold 15 identifiable
pieces over four pages — his density almost exactly. The temptation to write it
up as his prediction confirmed was considerable, and it would have been wrong.

**The control that caught it.** If the method is sound, the score must rise as
the eye gets finer and the evidence per forme grows. It does not:

| `--discrimination` | identifiable pieces per forme | tau |
|---|---|---|
| 0.26 — the default | 15.1 | 0.15 |
| 0.15 | 20.5 | 0.18 |
| 0.05 | 29.3 | −0.26 |
| 0.0 — a perfect eye | 35.5 | −0.13 |

At 35 pieces a forme the analyst has more than twice Hinman's folio density and
the inference is still at chance. **No quantity of evidence rescues it, so the
fault is in the instrument.** A method that genuinely wanted more evidence would
improve when given it.

The lag search is the visible symptom: it returns 1 on nearly every run, where
the measured profile above puts the peak at offset 5 for two formes standing. The
objective is not finding the structure the matrix demonstrably has, so the fault
is likely there rather than in the hill-climbing — a bump with a hand-chosen
width and a hand-chosen penalty, fitted to nothing.

**The rule for the next attempt: run the density sweep before reporting any
score.** Nothing about the quarto's difficulty can be claimed until the method
has been shown to work somewhere.

### Two more attempts, and the diagnosis above was not deep enough

*The density sweep is necessary and it is not sufficient*, which is a correction
to what this section said first. Raising `--discrimination` adds pieces; it does
not sharpen the offset-profile, because the flatness of that profile comes from
how type circulates and not from how much of it the eye can name. A flat sweep
therefore cannot by itself separate a bad instrument from thin evidence.

**Attempt two: spectral seriation on the Gram matrix.** The raw matrix is a band
at offset 4–5 — anti-Robinson — so seriating it directly asks similarity to fall
with distance when it rises. Its Gram matrix `M·Mᵗ` is an autocorrelation, peaked
at zero and decaying, which is what seriation wants; two formes close in the
order share type with the *same third formes* whether or not they share with each
other. Ordered by the Fiedler vector of that matrix: tau 0.14 at the default
density and −0.01 to 0.08 at every finer one. No better than the bump.

**The diagnostic that should have come first**, and asks about the evidence with
no algorithm in the way. Score an order by the mean-shared-per-offset profile
fitted from the *true* order — the most generous yardstick an analyst could have
— and compare the truth against 2,000 random permutations:

| `--discrimination` | pieces per forme | random orders beating the truth |
|---|---|---|
| 0.26 | 14.5 | **0 of 2,000** |
| 0.10 | 23.1 | **0 of 2,000** |
| 0.0 | 34.2 | **0 of 2,000** |

**The order is in the evidence, decisively, and at every density.** Both searches
were failing to find a maximum that is there. Note the circularity honestly: the
yardstick is fitted to the truth, so this shows the landscape has the truth at
its peak *given the right profile* — not that a profile-free method can reach it.
The margin is exactly the variance of the profile across offsets, which is real
but is carried almost entirely by the hard zero.

**Attempt three: estimate profile and order together.** The obvious escape from
that circularity — fit the profile to the current order, hill-climb the order
under it with full 2-opt, repeat, keep the best-scoring from eight restarts. Mean
|tau| 0.22, 0.22, 0.19 across the three densities, against about 0.3 for a random
order on thirteen formes. It fails, and it fails for a reason worth stating:
**`score(o, profile(o))` is degenerate.** The profile adapts to whatever order it
is given, so the objective rewards any arrangement whose profile happens to be
spiky, and the truth has no special claim on it. Alternating optimisation cannot
identify an order when the yardstick is refitted at every step.

**So the missing ingredient is not a better search.** It is a profile shape
constrained by the mechanism rather than fitted freely: zero while two formes
stand together, rising to a peak a lag later, decaying after — two or three
parameters, not one free value per offset. Attempt one had such a shape and chose
its width and penalty by hand, fitted to nothing; the measured profile in the
section above is what it should have been fitted to. That is where a fourth
attempt starts, and it should carry the permutation test as its own control:
**if the truth is not beaten by a random order, the search is the thing at
fault.**

### Hinman's own method, read at last — and it is not an optimisation at all

Three attempts were made before anyone opened the book by the man who invented
the method and executed it on the largest body of evidence it has ever had.
*Sources beat first principles*, and this is the most expensive demonstration of
it in this file. Hinman i. 76–81, §3 "Order of Formes".

**The criterion is a hard constraint, and it is exactly the hole.**

> "As a general rule, however, the second of two consecutive Folio formes was set
> before the first was distributed, and hence **the two cannot ordinarily have
> types in common**. Throughout most of the book, therefore, **any supposed order
> of formes in which the same types appear in consecutive formes must be
> considered wrong**, the more especially if, given some other order, types do
> not so appear; and **whenever there is only one order in which none of the
> types in the quire appear in consecutive formes, this order may confidently be
> taken as the one actually followed.**" (i. 80)

Not a profile, not a similarity, not a score. A forme pair either shares type or
does not, and sharing **forbids adjacency**. The order is whatever arrangement
satisfies every prohibition — a constraint-satisfaction problem, and the answer
is trustworthy exactly when the solution is unique.

**And the unit is the quire, not the book.** Hinman orders the six formes of one
quire at a time, the quire being given by the signatures. Six formes is 720
arrangements and can be enumerated exhaustively; there is no search problem here
at all. Every attempt above was solving a global thirteen-forme ordering that
Hinman never poses.

**He names the terminal formes by degree.** "Clearly formes 3ᵛ:4 and 1:6ᵛ are the
terminal formes, **since each has types in common with all but one of the other
formes in the quire**" (i. 80). The ends of the chain are the formes prohibited
from fewest positions.

**He states the reversal ambiguity himself**, which independently confirms what
§2 predicted for this evidence before it was tried: "And this could be true of no
other order save one — **the exact reverse of the one shown**."

**And he fixes the direction by chaining across quires** (i. 81): "the last forme
of the preceding quire has types in common with Gg1:6ᵛ but not with Gg3ᵛ:4. So
Gg1:6ᵛ cannot have been the first forme of its quire, though Gg3ᵛ:4 can have."
The same evidence that orders a quire internally also links it to its neighbours,
so one anchor propagates through the book. **The global flip is real, it is
resolved, and it is resolved by the type evidence itself rather than by an
imported assumption** — which is a better answer than §2 could give for the press
variants, where nothing internal breaks the symmetry.

One exception he flags, worth building in rather than discovering: "In the
initial quires of the Folio, and occasionally (but very rarely) elsewhere, the
same types do appear in consecutive formes — but for special reasons which can be
satisfactorily explained."

**What this costs the three attempts.** All of them. The bump, the Gram matrix
and the alternating fit were general-purpose instruments applied to a problem
with an exact domain rule. Worse, the measurement committed in this file two
entries above had already found the rule — "the strongest evidence in the matrix
is an absence, and it is absolute rather than statistical" — and it was then
buried under a weighting function. **The finding was in hand and the wrong tool
was reached for anyway.**

### And built, on his criterion, and it does not miss

`formeorder.rkt`. Per quire, enumerate every order in which no two adjacent
formes share an identifiable type, count them up to reversal, and report the size
of that set rather than a score — Hinman's confidence being conditional on there
being one. A quire of six is 720 arrangements and is enumerated outright.

Folio in sixes, *Areopagitica*, 10 seeds. A quire is tested only if it has four
formes or more, since fewer cannot tell an order from its reverse, and only if
every forme in it carries some identifiable type:

| | quires | determined | of those, right | mean admissible |
|---|---|---|---|---|
| 2 formes standing | 20 | 50% | **10 of 10** | 14.35 |
| 2 standing, a perfect eye | 20 | 50% | **10 of 10** | 9.85 |
| **1 forme standing** | 20 | **80%** | **16 of 16** | 1.65 |
| a copy a third shorter | 10 | 0% | — | 38 |

**Where one order survives it is the true order, 26 times out of 26.** That is
Hinman's claim — "this order may confidently be taken as the one actually
followed" — and it holds exactly as stated. What varies is not his accuracy but
how often he can speak, and that turns on the shop and the copy rather than on
the method: at one forme standing the criterion determines four quires in five,
at two only half, and on a copy a third shorter it determines none at all.

Note which way the perfect eye cuts. It does **not** raise the strike rate; it
shrinks the admissible set from 14.35 to 9.85 without turning more quires into
singletons. More evidence prohibits more arrangements, and the last few
prohibitions are the expensive ones.

### The chaining fires, and is right 12 times in 12 — the bug was in the truth

`chain-quires` was silent in 24 boundaries of 24, and three explanations were
offered and recorded before the real one: that the shop distributed too eagerly,
that the fount was too small, that consecutive formes shared 40% of the time. All
three were wrong, and the last two were withdrawn. **`forme-order` is not the
order the formes were set in.**

The counter is assigned by walking `formes-for-gathering` forwards, while the
pages are set from `setting-order`, which is built from that same list
**reversed** (`imposition.rkt`). For a folio in sixes, `forme-order` 0 is the
inner forme of the inner sheet holding pages 2 and 11 — and the pages actually
set first are 5 and 8, which belong to `forme-order` 5. **The setting order within
a gathering is the exact reverse of the counter that names it.**

Two things follow, and the second is why it survived so long.

- **The link was being handed the wrong pair.** It took the last forme of a quire
  by `forme-order`, which is the *first* forme set, and compared it against the
  next quire across a gap of five formes instead of none. Six to ten shared types
  is exactly what the measured profile predicts at that distance. The link was
  never failing; it was being asked a question about two formes that were not
  adjacent.
- **The criterion could not detect it, by construction.** Hinman's reading is
  scored up to reversal, and a reversed truth is as right as an unreversed one, so
  the 26-of-26 was untouched. **A test that is deliberately blind to direction is
  blind to a direction bug**, and every within-quire figure this file has printed
  was correct while the order underneath was inside out.

Corrected in `quire-formes`, which now reverses within each gathering. Folio in
sixes, *Areopagitica*, 20 seeds:

| | quires | determined | right | boundaries | spoke | right |
|---|---|---|---|---|---|---|
| 1 forme standing | 40 | 32 | **32** | 12 | **12** | **12** |
| 2 formes standing | 39 | 20 | **20** | 0 | — | — |

**Hinman's method is now built entire and works entire**: the criterion names the
order of a quire and is right whenever it speaks, and the link across the boundary
fixes the direction and is right whenever it speaks. At two formes standing no
boundary is testable, because determined quires rarely fall next to each other.

**And `forme-order` is now numbered in the order the formes are set.**
`book.rkt` walks `(reverse formes)`, since `setting-order` hands out the pages of
the last forme in that list first. The three readers were checked one by one
before the change and measured on both sides of it:

- **The preliminaries assertion** (`book.rkt:1523–1537`) was never affected. It
  asks `min(front) > max(rest)` across **gatherings**, and the preliminaries are a
  gathering of their own set last, so they hold the highest counter values
  whatever the direction inside each one.
- **The compositor's turn** was reversed within a gathering. `man-for-forme` reads
  the counter while the pages arrive in setting order, so the stint plan was
  consumed backwards — stints stayed whole and contiguous, but which man took a
  gathering first was inverted, and with it which man met the thin case, which is
  what governs the `-ie`/`-y` choice Blayney measured.
- **Skeleton wear** accumulated in counter order, so running-title damage
  progressed backwards inside a gathering.

**Both headline outputs are unmoved by the correction**, which is the result that
made it safe to keep. Folio in sixes, 6 seeds:

| | before | after |
|---|---|---|
| attribution, right of attributed | 101 / 114 | **101 / 114** |
| skeletons recovered over the truth | +18 | **+18** |

Unchanged, not unexamined — the plan's random draws do differ, and the point of
measuring was that they might not have cancelled. Compositors are symmetric in
aggregate and the skeleton over-count is coarse enough not to feel a reordering of
which forme took which. **A correction that is right in principle and neutral in
effect is worth making and worth saying is neutral**, so that nobody later reads
the commit as having bought an improvement.

And the link improves slightly with the truth straightened: 13 boundaries of 13
right at one forme standing, against 12 of 12 before.

### And the fount was not the problem — it is right, from two sources at once

The next move looked obvious: raise the fount. It was wrong, and measuring before
changing anything is what caught it. Hinman gives all three figures for the Folio
(i. 50): four pages standing is the absolute minimum for setting by formes, "**six
Folio pages, three full formes, were often 'standing' at the same time**", and the
stock was "large enough to set about **eight pages**".

Measured against this program's own fount, at 30,901 sorts:

| | this fount | the shop the source measured |
|---|---|---|
| folio pages in the whole fount | **8.85** | Jaggard, "about eight pages" |
| folio pages standing under the ceiling | **5.9** | Jaggard, six pages / three formes |
| quarto pages standing under the ceiling | **15.7** | Okes, not enough for "sixteen pages of *Lear*" |

**Both formats land on their source, and the sources are different men in
different shops working different formats.** The fount was derived from Blayney's
Okes quarto and had never been checked against a folio house; it agrees with
Hinman to within 10% on a measure — pages of double-column folio — that nothing in
its derivation knew about. That is the first independent confirmation the fount
has had, and it arrived from the format it was *not* fitted to.

### Except that the model cannot tell the difference, and a per-house ceiling was nearly built for nothing

The obvious next move was a ceiling per house, 2/3 for Okes and 3/4 for Jaggard.
Measured before building, and **the whole range the two men disagree about is one
program**. Areopagitica, 5 seeds, counting the rungs of Blayney's ladder:

| ceiling | folio6 shifts | robbed | face down | quarto shifts |
|---|---|---|---|---|
| **2/3 — Blayney's** | 14,853 | 4,892 | 1,228 | 6,242 |
| **3/4 — Hinman's** | **14,853** | **4,892** | **1,228** | **6,242** |
| 0.90 | 21,060 | 5,332 | 2,408 | 6,242 |
| 0.999 | 21,060 | 5,332 | 2,408 | 6,242 |

Byte-identical at the two sourced values. The ceiling only begins to bite above
about 0.9, because distribution is granular — a whole forme goes back at once, so
a ceiling a few hundred sorts higher selects the *same* forme a page later and the
case arrives in the same state. **And at quarto the ceiling never fires at all**,
at any value from 2/3 to 0.999: `--formes-standing` governs the format entirely.

**Two parameters, each inert where the other binds.** At folio the forme count
does nothing (measured earlier: standing 2, 3 and 4 give identical figures); at
quarto the ceiling does nothing. Neither is dead — each governs one format — but
each looks alive in the format where it is not, which is worse than a dead
parameter and is not a case the lessons had covered.

**What this settles about the disagreement**: it is real in the sources and
currently below the model's resolution. Recording it as a finding to be encoded
was premature — encoding it would have produced two named shops that behave
identically, and a reader would reasonably infer the distinction mattered. The
honest statement is that Blayney and Hinman differ, and that nothing this program
now computes can distinguish them.

**And it settles the profiles question.** Selectable shop profiles motivated by
this difference would be ceremony. What a profile could honestly carry is the
values that *do* change behaviour — the fount, the format and measure, the proof
rate, the signature alphabet, the setting method — and the argument for it is not
the ceiling but the fact that a run today already mixes Okes's fount with
Jaggard's proof rate, Jaggard's measure and Okes's ceiling, and says so nowhere.

**The exception is his and is kept**: where a shop distributed sooner than the
criterion assumes, no order is admissible at all; the report counts those quires
separately and quotes him on the initial quires of the Folio, rather than
reporting them as failures to determine.

**Quarto is not merely hard for this method, it is outside it.** A quarto
gathering is one sheet and two formes, and two formes have exactly one order up
to reversal, so the criterion is vacuously satisfied and says nothing. That is a
sharper statement than Blayney's — his "not nearly enough to allow the page-order
of a quarto to be determined with any great precision" is about evidence density,
where this is about there being no question of the right shape to ask. The
report says so instead of printing a hollow 100%.

### Turner's rule is built and graded

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
should not be believed. Real shops ran several presses and several books; §8 is
where that gets tested.

Related and cheap now that the table exists: the *order* of the sheets it pairs
is the order they were **printed**, not bound, and getting that wrong is silent.
Preliminaries cut from the white paper of the last sheet are bound first, so the
raw page order of a quarto reads H, A, B … G — which produced a confident table
for "H → A", the sheet printed last against the one printed first, and dropped
the real G → H. `turner-table` now orders the sheets itself.

### The same fault again at folio, and it read as the rule being always wrong

Every Folio report on disk said this, and had for as long as the format has been
run:

> Where it appears it names the first-set forme rightly **0** of 37 times. The
> truth for this book is the **#f** forme.

Two compounding bugs, neither of which any test touched.

- **The answer key had no answer.** `true-first-forme` ended
  `(and (= 2 (length done)) …)` — it asks a *gathering* for its two formes, and
  only a format whose gathering is one sheet has two. A folio in sixes has six,
  so it returned `#f` at that format entirely, every comparison against it
  failed, and the false itself was formatted into the report. The question is
  about a **sheet**; it is now asked per sheet and answered where the sheets of a
  gathering agree.
- **The sheets were paired in bound order.** The remedy quoted just above orders
  sheets by first appearance in `book-pages`, and **quiring is exactly what
  defeats that remedy**: a folio in sixes is three sheets quired one within
  another, printed 3, 2, 1 and bound 1, 2, 3. So the table read `A1 → A2` where
  the succession is `A3 → A2`, and asked the rule about every pair backwards.
  `page-views` now orders by `forme-order`, which is numbered in setting order
  and answers the preliminaries case and the quiring case together.

Corrected, at folio in sixes over six seeds: **12 sheet-pairs fire and the rule
names the forme distributed first rightly 12 of 12** — the same 100% the quarto
measurement gives, which is what a rule that "identifies the forme distributed
first, whichever method was used" should do at any format.

**Nothing about the published figures moves**, because every Turner number in
this file was measured at quarto, where a gathering *is* one sheet and both bugs
are invisible. What moves is the Folio report, which was printing a hard zero for
a rule it had never once asked correctly.

Three lessons, and the first is not yet in the list below. **A guard written for
the shape of one format is a claim about every format**, and `(= 2 (length done))`
was such a claim, made silently, by a piece of arithmetic that looks like a
sanity check. The second is the file's own: a bare zero cannot tell *did not
happen* from *could not be asked here*, and the report now says which. The third
is that this is the second time the printed-versus-bound order has been got wrong
in the same function — **a fix aimed at one cause of a class does not cover the
class**, and the quiring case was sitting in the same module all along.

Related and cheap once the inference exists: **pagination errors as evidence of
order.** `pagination.rkt` already separates errors of omission from commission
because Hinman says only the former are informative. Nothing yet uses them.

---


---

## §4 — The space bodies are Jacobi's, 1890

### Blokland mined for the shape, and the shape is wrong in a way that points the other way

No new book was needed: `blokland1.pdf` is on disk at 458 pages, and appendix a5.5,
"Measurement results", gives seventeen lower-case widths of Garamont / Van den
Keere's Moyen Canon Romain in millimetres, taken with a digital calliper at the
Museum Plantin-Moretus. His thesis is the shape claim itself — "one set letter per
group of letters with the same width" — and he cast type from the original matrices
"with a limited number of register settings adjusting to groups of matrices",
naming one group outright: *g, n, o, q* with *d*.

**The absolute widths are still unusable** for the reason §7 gives and the
`width-experiment` branch demonstrated — he measured a display size, and before
Benton's pantograph every size was cut separately. **The proportions are not**, and
proportions are what the open question is about. Both tables normalised to their
own mean over the sixteen letters they share:

| | Blokland | this table | |
|---|---|---|---|
| `f` | 0.47 | **0.73** | ours far too wide |
| `i` | 0.48 | **0.62** | ours too wide |
| `v` | 1.11 | **1.00** | ours too narrow |
| `y` | 1.11 | **1.00** | ours too narrow |
| `z` | 1.04 | **0.89** | ours too narrow |
| `a c e h n p r t u` | | | agree within 0.05 |

**So the table is wrong in shape, as suspected — and it is not obvious that this
is the 4.8%.** The two sorts most out are `f` and `i`, both far too *wide* here,
and `i` is among the commonest letters in English. A table whose common narrow
sorts are too wide sets *wider* words, which need *less* white, not more. The
error is real and may push the opposite way to the one wanted.

**Frequency-weighted, and it goes the wrong way.** Both normalised tables against
the letter frequencies of the copy itself, 58,989 letters:

| | weighted mean, normalised |
|---|---|
| Blokland's proportions | **0.9301** |
| this table | 0.9507 |

**His shape sets text 2.17% *narrower* than ours**, where 4.8% *wider* is what
reaching Blayney's 9% requires. `i` at 9.8% of all letters (his 0.48 against our
0.62) and `f` at 3.2% (0.47 against 0.73) dominate the rarer `v`, `y` and `z`
going the other way. **Adopting his proportions would widen the gap, not close
it.**

### All three candidates are now eliminated, which points back at the anchor

- **`justify`'s stretch** — out. The median gap is the body itself and the mean is
  3% above it.
- **The measure** — out. *Lear*'s is 22.76 ems against this program's 21: wider,
  and carrying less white.
- **The shape of the set widths** — out. The only measured Renaissance roman there
  is sets text narrower still.

Nothing mechanical is left, and three independent investigations came back empty
against the same number. **The remaining possibility is that the 9% is not
comparable to what is being computed here**, and that was flagged as an assumption
when the anchor was first run: Blayney's phrase is "the average amount of internal
space in a given area of visible type", read here as space over space-plus-type.
The alternative reading, space over type alone, gives 15.2% and is further away —
but a third is available and untested, that his "area of visible type" is the
measure times the depth, counting the leading between lines, which no reading here
has attempted.

**The reading holds up.** His method, in the same note: marginal space measured
directly in millimetres, non-marginal computed as 9% of "a given area of visible
type" over ten 20-line samples. A 20-line sample within the measure *is* the type
rectangle, and within the measure a justified line is letters plus spaces and
nothing else — so his 9% is space over space-plus-letters, which is what has been
computed here all along. The third reading is closed and the comparison is
like-for-like.

**So invert it and ask what gap would produce it.** From this program's own
figures — mean gap 0.343 em, share 13.2%:

| | |
|---|---|
| white : type now | 0.1521 |
| white : type at 9% | 0.0989 |
| gaps must shrink by | **×0.650** |
| **mean gap needed** | **0.223 em** |

And where 0.223 falls is the whole answer:

| | |
|---|---|
| Jacobi's thick, in use on `main` | 0.333 em |
| **Moxon's thick** | **0.250 em** |
| **the target** | **0.223 em** |
| Davis & Carter's thick | 0.167 em |
| Moxon's thin | 0.143 em |

**Blayney's shop was spacing between Moxon's thick and his thin, and much nearer
the thick.** A house setting mostly thicks with thins mixed in averages almost
exactly 0.223 — which is Moxon's fount doing what Moxon says it does, and it is
not reachable with a ladder whose narrowest ordinary space is a third of an em.

That reconciles everything: the branch reached 11.9% rather than 10.2% because
`justify` had to stretch to fill the measure. **Measured on the branch, it does
reach for the thin — and the mean is dragged by something else.**

| gaps on `moxon-ladder`, 48,067 of them | |
|---|---|
| mean gap | **0.302 em** (target 0.223) |
| exactly at the thick, 0.25 | **57%** |
| at or below the thin, 0.143 | **22.9%** |
| the remaining fifth | averages **0.63 em** — wider than an en quad |

So four gaps in five are set at the thick or finer, exactly as a Moxon house would
set them, and **a fifth are padded past an en quad**. That tail alone carries the
mean from about 0.22 to 0.30 — which is to say, **remove it and the branch lands
on Blayney's figure.**

**The residual is in how the leftover is distributed, not in the ladder.** A line
short of its measure has the remainder spread over its gaps, and `space-bodies`
builds each gap greedily from the largest body that fits — so a line wanting much
white gets a few very wide gaps rather than many slightly wide ones. A compositor
short of measure has other recourse: divide a word, respell, or reach for the next
line. This one only pads.

**But the padding is not a tail, and the diagnosis needed checking before anyone
acted on it.** Grouping the same lines by how many gaps they have:

| gaps per line | lines | mean gap |
|---|---|---|
| 4–6 | 595 | **0.395 em** |
| 7–9 | **4,208** | 0.312 em |
| 10–12 | 1,007 | **0.248 em** |
| 13+ | 7 | 0.172 em |

The wide gaps do concentrate where there are fewest of them to share the
remainder, which is arithmetic and not a defect. But **the bulk of the book — 4,208
lines of 5,951 — sits at 0.312 with seven to nine gaps**, so this is not a tail of
outliers dragging an otherwise sound mean. Only the lines carrying ten gaps or more
reach Moxon's thick.

**Which says the lines are ending short of what they could hold.** At eight gaps of
0.312 a 21-em line spends 2.50 em on white and 18.5 on type; Blayney's ratio wants
1.89 on white and 19.1 on type. **The difference is about 0.6 em a line — roughly a
quarter of a word.** Our compositor stops a syllable early and spreads the
remainder, where a real one would divide the word, respell it, or crowd the line.

**So the last piece is not `space-bodies` at all, it is what happens when a line
will not quite go**, and that is §5's subject: Moxon's and Smith's crowding
devices, and Smith's warning that they are conditional on the casting-off regime.
§4 and §5 have converged the way §4 and §7 did, and this time on a mechanism the
program already has and may simply not be reaching for often enough. The check
already exists — `description.rkt` counts gaps against Moxon's "three spaces and no
more", 3/4 em at his thick — and at 0.312 the ordinary line is nowhere near it,
which is why the fault has never shown there.

**What is settled** is that the question no longer wants a source. The data are on
disk, they are measured rather than invented, and the objection that blocked them
applies to their scale and not to their shape.

**Where `--fit` comes in**, and why it is not a free knob: it scales the widths
against the body, so it moves content and measure together and cannot on its own
change the ratio the white depends on. Whatever explains the 4.8% has to be a
change in one and not the other.

**And sizing it turned up a fourth, which the unit move had already broken.**
`typecase.rkt` held its own copy of the six body widths as literals in 1/120 em —
`(cons 40 # )` for the thick and so on — and did not require `metrics.rkt`
at all. When the unit moved to 1/840 that table went on naming a thick space of
40 units, **thinner than a hair at the new unit**, so the case and the compositor
disagreed about what a body was.

**Every test passed.** Nothing checked that the case's idea of a body agreed with
the compositor's, and the space-metal tests were themselves written in the same
stale literals — `take-space! tc6 55` and "a thick and a hair make 55/120" — so
they were self-consistently wrong and went on passing against the broken table.
The tests were part of the fault rather than a check on it.

Now sourced from `metrics.rkt`, with the fixtures written in terms of the
constants. Measured after the repair: internal space **13.2%**, unchanged, and the
play's shortage figures intact. So the damage was latent rather than expressed —
the greedy decomposition still terminated, it was simply choosing bodies against a
ladder that no longer existed.

**The lesson is the one this file already names and did not apply widely enough.**
One property, one decision point — and the property here was not a rate or a rule
but a *unit*. When the denominator of a shared quantity changes, every literal
expressed in it is wrong at once, and literals hide in test fixtures as readily as
in code. *The unit move was reported as costing two trivial fixups; it cost three,
and the third was invisible until the ladder was sized.*

### 4a. And the quantities disagree with the only bill there is

`typecase.rkt` says of the space-metal:

> The quantities are measured from the demand rather than found in a bill,
> **because no bill of this period tabulates them.**

Davis & Carter confirm the premise about Moxon — "Moxon does not discuss the
composition of a fount … **The earliest printed schemes are apparently those in
Smith's *Printer's Grammar* of 1755**" (note to p. 19). But Smith's bill *does*
tabulate the spaces, and `typecase.rkt` already uses that same bill for the
letters at Smith/4 and Smith/10. Smith is being treated as good enough for `e`
and not for the thick space.

Smith, pp. 42–45, in two columns: the founder's standard bill, and Smith's own
revision for English matter. He states on p. 46 that both total **133,110**, and
they do, exactly — which is how the OCR of this table is known to be sound.

| | to be cast | in all |
|---|---|---|
| lower case | 90,200 | 89,500 |
| capitals | 14,350 | 14,950 |
| double letters | 5,300 | 4,350 |
| figures | 10,800 | 12,200 |
| points | 12,460 | 12,110 |
| **total** | **133,110** | **133,110** |

Spaces are given separately and total 32,000 each way — thick 15,000 → **12,000**,
middle 10,000 → **10,000**, thin 5,000 → **8,000**, hair 2,000 → **2,000**; with
quadrats m 2,000, n 5,000, and the large quadrats by weight (4 m's 40 lb, 3 m's
30 lb, 2 m's 10 lb). Row labels and figures are reconstructed from the table;
both column totals check exactly.

**Smith independently confirms the claim the code makes in prose.**
`typecase.rkt` states "the thick space is as common in a fount as the letter e".
Smith: thick 12,000, `e` 13,000. That is the proposition, from a printer, at
0.92. **The code's own table does not obey it**, and the disagreement has a
shape. Normalising each body to the `e` box:

| body | program | ÷ e | Smith | ÷ e | program ÷ Smith |
|---|---|---|---|---|---|
| em quad | 900 | 0.31 | 2,000 | 0.15 | **2.0× rich** |
| en quad | 1,200 | 0.41 | 5,000 | 0.38 | 1.1× |
| thick | 4,000 | **1.38** | 12,000 | **0.92** | **1.5× rich** |
| middle | 800 | 0.28 | 10,000 | 0.77 | **0.36× — 2.8× poor** |
| thin | 900 | 0.31 | 8,000 | 0.62 | **0.50× — 2× poor** |
| hair | 1,400 | 0.48 | 2,000 | 0.15 | **3.1× rich** |

(program `e` = 2,907; Smith `e` = 13,000)

The program holds too many of the *extreme* bodies and too few of the
*intermediate* ones. Smith's fount justifies by mixing middle and thin, which
are nearly as numerous as the thick; the program's justifies with thick and then
cascades to hair — and `typecase.rkt` says so outright, "every line that could
not find a thick space made the white out of middles, then thins, then hairs,
and drained the whole ladder", which is why the thick box was raised to 4,000
and the hair box to 1,400.

**That cascade is what a 2.8× hole in the middle of the ladder would produce.**
The hair box at 3.1× Smith's proportion looks like the residue of the space-metal
bug in the lessons below.

**Re-derived from Smith, and the cascade survives — so the demand model is wrong
somewhere else, exactly as this line predicted.** The quantities are now his
ratios against his 13,000 `e`, applied to this fount's own: em 450, en 1,120,
thick 2,680, middle 2,240, thin 1,790, hair 450. The total space-metal is very
nearly unchanged, so it is a redistribution and not a richer shop.

Measured on a play — where Blayney says the strain falls — over four seeds:

| | space-metal shifts | the sort that empties |
|---|---|---|
| the demand table | 32 | en quad, 100% gone |
| **Smith's proportions** | **32** | **en quad, 100% gone** |

**The strain is on the en quad, which neither table addresses**: the demand model
puts it at 0.41 of `e` and Smith at 0.385, so filling the hole in the middle of
the ladder leaves the binding constraint exactly where it was. The thick-to-hair
cascade the code describes is not what a play does to this case.

**Kept anyway, and for provenance rather than effect.** An invented table has been
replaced by the only bill anyone has; the module's own claim that "no bill of this
period tabulates them" is retired as false; and Smith confirms in his own numbers
the proposition the code asserted from arithmetic — thick 12,000 against `e`
13,000, a ratio of 0.92 where the demand model had 1.38. **A change that improves
where a number comes from and moves no measurement is worth making and worth
labelling as such**, so nobody reads it as having bought an improvement.

### Blayney cannot settle the en quad, and gives a different check instead

Sent to *Lear* to answer why a play empties the en quad. **He has no per-body
figure at all.** Appendix IV's note on how the space-metal was measured:

> "**Figures are given in ems**, and the total excludes the titlepage. Marginal
> space has been measured in millimetres within what appears to be the 'standard'
> prose measure (for *Lear*) of 22.76 ems … **Ten random 20-line samples yielded a
> figure of approximately 9% as the average amount of internal space in a given
> area of visible type**, and that figure has been used for all calculations of
> non-marginal space."

He measured space-metal as **ems of total space**, marginal and internal counted
apart, and never as thick-against-en-against-hair. So the question this file
raised cannot be answered from the richest source there is, and no amount of
further reading in him will help. **Recorded so that nobody spends another session
looking.**

Two things do come back from the trip.

**The en quad emptying on a play is probably right, not a defect.** It is what his
own account predicts — a play is short lines, quadded-out ends and marginal
prefixes, and he notes marginal stage directions of just over 4 ems on C2ᵛ and
D3ᵛ and 3 ems on F3ʳ. Quadding out and margins are en and em work. The model
reproducing that strain is the asymmetry being modelled, and the open question is
only whether the box is the right depth — which is precisely what he gives no
number for.

### Merged — and a second measurement, which the ladder was not chosen on, agreed

The ladder is now Moxon's four: em, en, **thick 1/4, thin 1/7**, and no middle or
hair at all. What settled it was not the documentary case above, which had been
sound and unacted-on for two sessions. It was that a *second* quantity moved the
right way — one nobody had consulted when choosing the ladder.

| | Jacobi | Moxon | measured |
|---|---|---|---|
| internal space, share of type area | 13.76% | 11.57% | ~9% (Blayney, off *Lear*) |
| word divisions per 100 lines | 4.94 | 5.88 | 6.41 (Norton, prose plays) |
| mean gap | 0.359 em | 0.291 em | 0.223 em (inverted from Blayney) |

Internal space is the quantity §4a chose the ladder on, so its improvement is not
evidence — it is the thing that was fitted. **The division rate is evidence.** It
comes from a different source (the Norton Facsimile, 790 plates), a different
method (counting hyphens at line-ends), and a different mechanism (the floor for
squeezing rising from 1/8 to 1/7, so the compositor reaches for a division
sooner). Nothing about the choice of 1/4 and 1/7 was tuned to it, and it closed
60% of its gap.

Both still fall short, in the same direction and by about the same proportion.
That is the residual §4 had already localised and handed to §5: lines ending
about 0.6 em short. The ladder was never going to close it, and it did not.

**Read the row that matches the sample.** The prose plays divide at 6.41 per 100
lines and the verse ones at 0.40, because verse turns over where prose divides.
The sample used here is prose, so 6.41 is its row; judged against the whole
book's 2.03 the same run would look three times too loose. This is the third time
a figure in this file has been quoted against the wrong population — after the
quarto-for-folio forme overlap and the five-scenes-for-whole-book division rate —
and the lesson is the same one, unlearned twice: **put the population in the
number.**

`tools/measure-spacing.rkt` computes both quantities. It exists because they
decided the ladder, neither appears in the report, and the 13.2% that stood in
this file for two sessions had to be recomputed by hand every time it was
questioned — which is how it came to be quoted against a sample nobody could
reproduce. (It is 13.76% over the four seeds and two formats the tool uses; the
old figure was one run.)

And the first version of the table above got this wrong in the way the paragraph
below it warns against. Jacobi's 13.49% was quarto only; Moxon's 11.57% was
quarto and octavo together. Both columns now cover the same eight runs, and the
corrected figure is 13.76% -- which makes the change slightly larger, not
smaller, so nothing rests on it. **The population error was committed inside the
same table as the lesson about population errors**, which is worth recording
precisely because knowing the rule plainly does not prevent it. Only running both
sides through one instrument does, and that is the better argument for
`tools/measure-spacing.rkt` than convenience ever was.

### What the change broke, and what that was worth

Three fixtures. None was patched to agree, and two turned out to be about
something other than the ladder.

**A count that was measuring the ladder and calling it the copy.**
`compositor.rkt` asserted that 24 words stand in type for 24 words of copy. A
divided word is two pieces sharing one `word-copy` — "ſho-" and "vld" are both
*should* — so the count reads 25 the moment the compositor divides anything, and
reads it as a *loss* when it is the opposite. It held while the normal space was
1/3 em and broke on 1/4, which divides oftener. It now rejoins the pieces and
asserts the copy string itself: unmovable by any ladder, and strictly stronger,
since 24 would also have survived two words swapping places.

**A fixture whose premise had quietly stopped holding.** `imposition.rkt` needs a
verse line the two casting-off tests *disagree* about — one that overflows at the
normal space and goes at the finest. That band is a property of the ladder, not
of the line. *Lear*'s "No, rather I abiure all roofes" sat in it at 1/3 em and
simply fits at 1/4 (16,306 against a 16,800 measure). The premise is asserted
rather than assumed, so it failed loudly instead of leaving the real check
testing nothing — which is the only reason this was a two-minute problem. The
replacement is from `samples/hamlet.txt`, so the figures can be checked, and is
the furthest from either edge of the band of the seven candidates in that sample.

**And one that was not about the ladder at all.** The heap test's sparse rate
read exactly 1.0, and 0.96 under the new ladder. It also reads 1.0 when moved to
the top of its block and 0.96 when left where it was — same model, same book,
same twenty-five seeds. `run-press` **wears the type it prints from**: serialise
the book before and after and it grows, the rules picking up "printing heavy at
one end" and "a break a third of the way down". So twenty-five runs over one book
are not twenty-five draws from one distribution; they are one press working the
same forme twenty-five times, and the later runs have more to see than the first.

That is worse here than it would be anywhere else, because accumulated damage is
exactly what `variant-groupings` keys on. **The measurement loop was feeding the
detector evidence it had itself manufactured.** Each call now sets the book
again, at 1.3 seconds on the suite.

The comment eleven lines below the broken assertion already stated the rule it
broke — "assert the ordering of the rates rather than their values … pinning the
numbers would make this a test of the seed sequence". The dense assertions
followed it; the sparse one did not; the sparse one broke. **A rule written down
next to the code that violates it is not a rule, it is a note.**

The general form, which is new to this file: **a measurement loop that reuses a
mutable object is measuring an accumulating process, whatever it says it is
measuring.** Anywhere a book is built once and pressed many times, the runs are
not exchangeable and their order is part of the result.

---


---

## §5 — Casting off is two regimes, not one dial

### Reconciled, off the record rather than by re-running — and the report was right

The reconciliation asked for above did not need a run at all. **The TEI carries
`hp:pressure` on every page**, which is the quantity `deviation.rkt` thresholds,
so the report can be checked against the record it was written from:

| | crowded | spun out | the report |
|---|---|---|---|
| Jacobi, `out-folio` | 60 | 646 | 60 / 646 |
| Moxon, `out-folio-moxon` | 570 | 31 | 570 / 31 |

**Exact, in both columns, on both runs.** The report and the record agree and the
probe was wrong. Its code is not recoverable — it was never committed — which is
the argument for `tools/measure-castoff.rkt` existing instead of another
afternoon's script.

**And a session was lost to the report naming two populations with one word.**
`deviation.rkt` counts a page crowded at `pressure > 0`, which is an overflow of
more than two lines; `analysis.rkt` lists pages at `|pressure| > 0.35`, a third of
a page or worse. On the Folio those are **570 and 11**. Both were called
"crowded", in the same report, with neither stating its threshold — so "the
crowded figure" named two numbers fifty times apart and the disagreement could
not be localised. The casting-off section now prints both counts and the test
between them. **A number that shares its name with another number is not a
number**, and this file has no lesson covering it.

### The dial is not the cause: at perfect casting off the book is worse

`--cast-off 1.0` kills both the slip draw and the misjudge branch, so whatever
miscasting survives is the estimator's own. Measured on the real Folio copy at
its own format, four seeds:

| `--cast-off` | pages | crowded | spun out | mean overflow | lines dropped |
|---|---|---|---|---|---|
| **1.00 — no deliberate error at all** | 3,660 | **2,627 (71.8%)** | 51 (1.4%) | **+6.19** | **12,895** |
| 0.93 — the default | 3,702 | 2,109 (57.0%) | 161 (4.3%) | +5.25 | 9,291 |

**Perfect casting off is worse than imperfect casting off.** That kills the whole
family of explanations resting on `--cast-off`, including the accuracy scalar
this section was opened to replace: the dial is not merely the wrong shape, it is
not where the error is. The deliberate error at 0.93 is partly *cancelling* a
larger bias, which is the most misleading arrangement a parameter can be in — it
made the defect look like the dial's business for as long as anyone only moved
the dial.

The bias is a shift of the whole distribution rather than a tail. Recovering
overflow from the recorded pressures:

| | mean overflow | median | miscast 2–20 lines | beyond 20 |
|---|---|---|---|---|
| Jacobi | −6.62 | −7.04 | 703 | 3 |
| Moxon | +5.58 | +4.84 | 597 | 4 |

**About twelve lines a page separate the two ladders, and nearly every page moves
with them.** No page-boundary accident produces that; an estimator does.

### And the estimator was not measuring the speech prefix at all

`tools/measure-castoff.rkt` puts the estimator's prediction for one copy unit
beside the lines the compositor actually sets from it, with no page boundary in
the way. The prediction is got by calling the real `cast-off` on a single unit
with a page too deep to close a segment early, so nothing is reimplemented and
the instrument cannot drift from the code it measures.

**And it produced two false findings before it produced a true one**, both the
same mistake: it compared the estimate against the *setting routine* instead of
against `compose`, which is what decides what a unit costs a page. It reported
headings 100% over — `compose` puts a white line above and below one and the
estimator's `(+ n 2)` was right all along — and then verse **+1.24%**, the wrong
sign, because it dropped the speech prefix that `compose` hands on. Both are
written into the tool beside the code that gets them right, because the second
survived a full run of the instrument and went into a table before it was caught.
**A probe that models one stage of a pipeline is a claim about the whole
pipeline**, and this one had to be corrected twice before its answer held.

Whole Folio, at its own format, **before** any change:

| kind | units | est lines | set lines | bias / 100 lines |
|---|---|---|---|---|
| verse | 89,168 | 93,432 | 97,135 | **−3.81** |
| prose | 3,975 | 18,755 | 19,708 | **−4.84** |
| stage | 6,195 | 6,938 | 6,912 | +0.38 |
| heading | 44 | 138 | 154 | −10.39 |

**Both branches under-predict by about four per cent**, which on a 132-line page
is five lines — against a measured mean overflow of 6.19. The arithmetic closes.

And the largest single cause is one line of code. `compose` holds a `prefix` unit
and hands it to the next verse or prose unit as `lead`, where it is set at the
head of that unit's first line — so "Ham." is what pushes a line past the measure
and turns it over. `estimate` scored a prefix at **nought** and measured the
verse line's own text, so **every line the prefix turned over was invisible to
the casting off**. Counted directly, the same copy set with the prefix and
without: **1,110 speeches on a slice of the Folio, 156 lines, about five to a
page.**

Corrected — `cast-off` now carries the pending prefix exactly as `compose` does,
and allows its width at the unpressed cut of four characters, a man casting off
beforehand not being able to know the compositor will squeeze this one to two.
The cut itself moved to `abbreviate-prefix` in `copytext.rkt`, because two stages
needing the same answer must not each keep their own.

Measured again on the whole Folio afterwards:

| bias / 100 lines set | before | after |
|---|---|---|
| verse | −3.81 | **−0.56** |
| prose | −4.84 | **−2.47** |
| stage | +0.38 | +0.07 |

**The prefix is worth 5,425 lines across 29,889 speeches** — 5.7 to a page against
a measured mean overflow of 6.19. It was the whole of the verse error and about
half the prose error, prose in a play carrying prefixes too.

**This is not the `NORMAL-SPACE` fudge §5 forbids.** The estimator was omitting a
thing that is set on the page; Moxon's own method counts every letter that will
stand there, prefixes included. Nothing was fitted to a target, and prose is
still −4.84 — the remaining error, and a different mechanism (`split-unit`
measures a broken paragraph at `NORMAL-SPACE`, which is where the original
hypothesis belongs and where it may yet be right).

### The predicted casualty arrived on schedule

Two checks in `book.rkt` broke the moment the change landed: *copy is dropped
where the page will not hold it*, and *a catchword does not answer the page it
faces*. **§5 said in writing that they would**, before any of this was built:

> a mechanism that can only fire as a side-effect of a bug will read as healthy
> while the bug lasts and vanish when it is fixed. Fix §5's casting off and this
> count goes to nought — which will look like an improvement and will actually be
> the loss of the one piece of evidence McKerrow says the phenomenon exists to
> give.

So the omission branch had been firing off a systematic four-per-cent
over-allotment, not off the deliberate casting-off error the checks name. They
were passing for the wrong reason and had been since they were written.

**Not patched to agree.** Measured over 24 seeds after the change, seeds dropping
copy: 3 at accuracy 0.45, 4 at 0.30, 3 at 0.20, 7 at 0.10, 5 at 0.00 — and the
count of seeds with a failed catchword is *identical* at every one, which is the
same single fact seen twice that this section already records. The checks now run
at accuracy 0.0, the worst casting off there is, where seeds 0, 5 and 8 all fire:
three independent hits in nine, a test of the program rather than of a seed. The
mechanism is still reachable and is now as rare as McKerrow says it is.

**What has not changed is that this program still cannot produce McKerrow's
actual mechanism** — the compositor mis-resuming and losing a word or two. Its
only route to a disagreeing catchword remains a page overflowing, so the count is
still a symptom of a different defect, and the entry below stands.

### The press-variant count was a draw, and a runaway was dealing the cards

The obvious reading of 543 → 366 was that crowding manufactures press variants, so
the earlier agreement with Hinman was resting on the casting-off defect. That
reading is *partly* right and it is not what the numbers say. **Both figures are
single runs, and nobody had ever measured the spread.**

Three seeds of the same book and the same code:

| seed | corrected formes | press variants | literals | restored from copy |
|---|---|---|---|---|
| 1623 | 87 | **366** | 155 | 204 |
| 11 | 100 | **851** | 178 | 663 |
| 22 | 108 | **563** | 168 | 395 |

**A 2.3-fold spread — larger than any difference this file has ever attributed to
a change in the model.** Every calibration decision recorded in `press.rkt` —
proof rate 0.6, then 0.28, then 0.224, each argued from a full Folio — compared
single draws of this. And corrected formes average 98 against Hinman's hundred, so
**that** constant was well set and the run reading 87 was a low draw, not the
regression it was written up as two entries above.

**The spread is all in one route.** Literals are steady at 155–178, because every
proofed forme catches those. Readings restored from the copy run 204, 663, 395.

And that route was running away. The module header states the source exactly —
Hinman's reader, having found "a considerable omission", grew "somewhat more
careful … at least for a time", so **a serious catch raises vigilance and the
vigilance decays**. The code did neither: it re-armed on *any* misreading, once per
caught word, at even odds. Six or so chances on a forme puts the continuation
probability near 0.98, so the mean run was tens of formes and one consultation
swallowed most of the book.

It also stood the book against its own source. Hinman's variants are "mostly
obvious blunders" and the copy "seldom if ever used"; **copy restoration was the
majority of ours at 57%, and 79% on seed 11.**

Raised once per forme now, and only where consulting the copy turned something up
— a geometric decay with a mean of two formes, which is "for a time":

| seeds 1623 / 11 / 22, measured both ways | pre | post |
|---|---|---|
| press variants | 366 / 851 / 563 | **280 / 291 / 330** |
| spread, widest over narrowest | **2.32×** | **1.18×** |
| corrected formes | 87 / 100 / 108 | **96 / 98 / 100** |
| literals | 155 / 178 / 168 | **187 / 187 / 192** |
| restored from copy | 204 / 663 / 395 | **86 / 99 / 129** |

**And a fourth seed was then run, and it is the honest qualification to all of the
above.** Seed 44 gives 432 variants, 121 corrected formes, 219 literals and 204
from the copy. Over the four post-fix seeds the variants are **280, 291, 330,
432** — a spread of **1.54×**, not the 1.18× the first three showed, and the
literal share falls from 67% to 51% across them.

So the fair statement is the paired one: on the three seeds measured both ways the
spread falls from 2.32× to 1.18×. **Four seeds is still four seeds**, and this
section's own lesson applies to this section — a spread quoted from three draws is
the same error as a rate quoted from one, committed while writing up the error.
The improvement is real and the variance is reduced, not abolished; a good part of
what is left tracks the proofed count, which runs 119 to 135 across the four.

Corrected formes over the four are 96, 98, 100, 121 — mean 104 against Hinman's
hundred, still the best-behaved of these quantities. The severity he names is
*not* modelled and
the comment says so: every misreading here is a single word, so there is no
considerable omission to distinguish, and "serious" is approximated by "found
anything at all".

### And the remaining shortfall is structural, not a constant to turn

280 against "just over 500" is now the honest figure, and it cannot be closed by
tuning, because the arithmetic forbids it. The whole book holds **813 accident
events and 1,538 misreadings**. Only about a fifth of formes are ever proofed and
corrected, so a corrector sees some 172 accidents and catches three-quarters of
them — about 130 literals, which is what comes out. To reach 500 variants
*mostly* from literals, as Hinman describes them, the book would need roughly
**2,500 accidents: three times the measured foul-case rate** of 0.87 per 1,000
words, which is one of the best-anchored numbers in the program.

**So two anchored facts are in tension and the model cannot hold both**: the
measured rate of foul case and turned letters, and Hinman's count of press
variants arising mostly from obvious blunders. The resolution is not a constant.
It is that **this program's vocabulary of correctable error is narrower than the
real one** — a compositor's page offers a corrector wrong founts, spacing,
punctuation, dropped and doubled letters, transposed words and failures of sense,
where the model offers foul case, turned letters, wrong fount and misreadings.

Until it is done, 280 is the right number to print and the gap is the finding.
**What must not happen is the gap being closed by raising `consults-copy`**, which
would restore the old total by the exact mechanism Hinman denies.

**And the source settles it, more sharply than the arithmetic did — [§12](#12-what-a-corrector-could-correct--simpson-read-at-last-and-the-error-rate-is-calibrated-on-the-wrong-population).**
Simpson gives twenty corrections on one surviving proof page of the Folio against
this program's 2.5 to a page, and the reason is not a rate set too low: the error
rates here are measured on *printed books*, which are post-correction, and the
corrector's input is the pre-correction population. One number is doing two jobs.

### The sources were mined for a yardstick, and they moved the diagnosis

Neither of the two quantities called regressions above had a measured rate
anywhere in this project, which meant they were being called wrong on judgement.
Two sources give bounds rather than rates, and the bounds are enough.

**Blayney, p. 30**, describing *Lear* — in the paragraph whose whole purpose is
to say how badly it was printed, and this is the concession before the
criticism: "Register was satisfactorily made, **the page-depth is almost entirely
consistent, and most of the catchwords are right**."

**McKerrow, p. 66**: "when, **as occasionally happens**, we find a page too long
or too short, we need not suspect an author's correction at the last moment … it
may merely be that lines were omitted or repeated by the compositor in the
original setting-up, for even if this were discovered immediately on proofing, it
would not have been thought worth while to overrun later pages."

Both are bounds, and the program fails them in **both** columns:

| per 1000 pages | Jacobi | Moxon | the bound |
|---|---|---|---|
| miscast either way | **717** | **650** | "almost entirely consistent" |
| catchwords not answering | 37 | **515** | "most … are right" |

**Which changes the diagnosis.** The entry above blames the ladder for exposing a
coupling. That is true and too kind: at 717 per 1000 the casting off was already
failing Blayney's bound by a wide margin *before* the ladder, and had been for as
long as the figure has been printed. The ladder did not break casting off. It
moved the failure from spun-out pages to crowded ones, and **white paper is
quieter than lost text** — which is the only reason the old number looked
tolerable. §10 recorded "two thirds of the book came out spun out" as a defect
and it was the same defect.

**And two of the four regressions are one.** `add-catchwords` already follows
McKerrow: the catchword is set from the copy, not from the next page, which is
right and was fixed for good reasons. It reads the first word of whatever the
next page *dropped*, and falls back to that page's own opening word when nothing
was dropped — so where nothing is dropped the two agree by construction. **A
catchword can only fail to answer where the next page dropped copy.** 515 and
2,780 are one number seen twice, and reporting them as two independent
confirmations was double-counting.

### A mechanism the sources describe and this program cannot produce

McKerrow's catchword evidence is not the overflow case at all. His is the
compositor losing his place:

> The comparative frequency with which we find a correct catchword in cases where
> the opening words of the next page are wrong, owing to **the compositor having
> mistaken the point at which he left off and consequently omitted or repeated a
> word or two**.

A word or two, from mis-resuming — and it is *why* he can prove the catchword was
set from the manuscript. This program has no such mechanism. Its only route to a
disagreeing catchword is a page overflowing its cast-off allocation, so:

- in a correctly cast book it would produce **zero** catchword failures, where
  McKerrow reports "comparative frequency"; and
- every catchword failure it does produce is a symptom of a different defect.

That is worse than a dead mechanism, and the lessons do not yet have the shape:
**a mechanism that can only fire as a side-effect of a bug will read as healthy
while the bug lasts and vanish when it is fixed.** Fix §5's casting off and this
count goes to nought — which will look like an improvement and will actually be
the loss of the one piece of evidence McKerrow says the phenomenon exists to
give.

It is not built here, because no source gives a rate: "comparative frequency" is
not a number. It belongs with binder's faults and heap disorder as **a knob with
no source**, and it should be added with the *repetition* case at the same time —
McKerrow's proof (1) is the same slip in the other direction, "the last line or
the last few words of one page being repeated at the beginning of the next", and
he lists five books where it happens.

---


---

## §10 — The First Folio as the standard test case

### Then the Norton Facsimile arrived

And it did what every source the user has supplied has done.

*Measured off the plates.* The facsimile's OCR is good enough to count on, and
Hinman's through-line numbers identify a genuine leaf, so the whole book can be
measured rather than sampled — 790 pages, 101,006 lines of type:

| | word divisions per 100 lines |
|---|---|
| whole Folio | **2.03** |
| prose plays (Merry Wives, Much Ado, As You Like It) | 6.41 |
| verse plays (Macbeth, Caesar, Richard II, King John) | 0.40 |

The 16× gap confirms the model's rule — verse turns over where prose divides —
and the three rates together *solve* for the book's composition: 73% verse, which
agrees with the usual literary estimate of 70–75%.

**We were producing 94%**, and the cause was the `<l>`-per-line fix.
`looks-like-verse?` asks whether a line is under 78 characters, which is fair for
copy whose breaks mean something and useless for copy a machine wrapped at 72:
every wrapped prose line read as verse, and since verse does not divide, word
division collapsed to 0.15 per 100 lines. Classifying per *speech* on the length
of its non-final lines — verse averages 41 characters, prose 68 — gives 73.2%
verse.

This also retired a figure quoted here for months. Word division was calibrated
on "5.1 per 100 lines across five scenes of *Much Ado*"; the whole book gives
2.03. **The single sample was 2.5× the book**, because those scenes are prose and
most of the Folio is not.

*Read out of Hinman's introduction* (pp. xix–xxi), which gives the press-variant
figures his two volumes do not summarise: "just over 500" press variants in the
whole book, about seventy in the Comedies (in 29 of more than 300 pages), seventy
in the Histories (in 31 of 262), and some 370 in the Tragedies — half of those in
the seventy-odd pages set by Compositor E, whose work was reviewed because he was
"evidently expected to make many errors". That is roughly a hundred variant formes
in about 450. `proof-rate` was an unsourced 0.6; his count put it at 0.28, and
then at 0.224 (below).

### The preliminaries were never printed

Found by opening the front end and scrolling, not by reading code — which is the
point of building the front end. Four faults, every one silent: the report went
on stating the right thing about a book that did not have it.

**The front matter was thrown away by the fetch script.** It wrote
`blocks(body)[1:]`, reasoning that block [0] was the heading. Block [0] *is* the
heading, but it is not separated from what follows by a blank line, so `blocks`
returned the title and the whole piece as one block and the slice discarded it.

| | words | kept |
|---|---|---|
| Jonson's poem | 668 | **0** |
| To the great Variety of Readers | 477 | **0** |
| the Catalogue and the Actors | 30 | **0** |
| the dedication | 487 | 8 |

The whole preliminaries of the First Folio came to **98 words of headings**, and
the report said "8 preliminary divisions declared by the TEI markup and taken
from it, not guessed" throughout — true of the divisions, and of not one word
inside them. Now 2,188 words.

**And then the page loop dropped them anyway.** `formes-for-gathering` hands back
the whole twelve-page folio scheme whatever `#:leaves` it is given, so a
three-leaf preliminary gathering is set in the order 5 8 6 7 3 10 4 9 1 12 2 11 —
and the second entry, page 8, has no segment. The loop answered `(void)` and
**stopped** instead of skipping, so page 5 was composed and the other five were
not. The preliminaries were one leaf, and blank. It could only bite on a gathering
shorter than the format's scheme, which in practice means every preliminary
gathering.

**Two thirds of the pages were spun out** — 646 of 990, with white at the foot of
the second column. The casting off judged whether a verse line turns over at the
*ordinary* space, where the compositor's own test is content plus a hair to each
gap: `set-verse` works down the ladder and squeezes the words themselves before
it gives up. On the same copy the caster-off predicted **363** turn-overs in 2,188
verse lines where the compositor set **166** — 197 lines of copy held back over 25
pages, 7.9 a page, against a 12.8-line average shortfall. At a hair it predicts
130, erring the other way by 1.4 a page, which leaves the crowded pages and the
omission branch something to fire on. Mean depth 119.2 → **127.5** of 132; full
pages 4 of 25 → **21 of 23**.

**`proof-rate` 0.28 → 0.224.** It is the rate formes are *proofed* and was
calibrated against Hinman's count of formes *corrected*, which is not the same
number: 86% of proofed formes have something worth altering, and E's are proofed
1.9 times as often, lifting the effective rate to 32.3%. That gave 137 corrected
of 493 — 27.8% against Hinman's 22.2% — and 773 variants against his "just over
500". It was wrong when it was set and went unnoticed because variants per
corrected forme were 3.90 against his 5.00, so the product landed near 500 by
accident. Setting a white line between speeches was what held that figure down;
with the page solid it is 5.64 and the compensation is gone. **Two errors
cancelling is the failure mode this project keeps finding, and it is the argument
for reporting a rate beside its components rather than alone.**

**`--pages` truncated the terminal render and nothing else**, so there was no way
to ask for a facsimile of part of a book. The Folio's is 79 MB and three and a
half minutes of layout, and nothing else touched it: 1,200 copies gives 79.5 MB
and one copy 78.6, because the book is the size and not the edition. `--pages 40`
now gives 3.1 MB, and the page says on its face that it shows 40 leaves of 985 so
the counts above it are not misread.

### What a plate showed that no statistic did

Setting a page beside the Norton facsimile of the same play found four things the
numbers could not, because none of them changes a rate: the running title read
`THE HISTORY` on all 1,020 pages where the Folio names the play; Gutenberg's
italic markers were being set as type, 4,510 underscores; the Folio's **box frame
and centre rule** were not drawn at all; and the first line of a speech is
indented in the Folio and flush in ours.

**The speech indent** was applied to the prose path first and did nothing, because
three-quarters of the Folio goes through `set-verse`, which had no first-line
indent at all. It is `set-verse #:first-indent?` now, taken only by the line that
carries the prefix. The indented line is genuinely narrower and so turns over
sooner, which is why the Folio turns over on prefix lines more than on any other.

**The brackets** wanted more than a regex, and the visible stray `]` was the small
half of it. `[Aside.] I must obey ...` matched the direction test on its first
character, so the *entire verse line* was set as a direction — italic, ranged
right. 611 lines went that way, 350 more broken mid-line, 45 at the end, and 5
wrapped across two lines. Brackets are now lifted in `copytext.rkt` before
anything else reads the line: a modern edition's square brackets are apparatus,
exactly like Gutenberg's underscores, and there is not one on any page of the
Folio.

### The white line between speeches was the editor's

The Folio sets a play **solid**. On Lear 295 the two columns run sixty-six lines
each without a white line anywhere in them — the white and the rules come at
`Actus Tertius. Scena Prima.` and nowhere else.

A modern edition puts a blank line between speeches because a modern reader
expects one, and the reader here was setting every one of them as a white line of
quads. On *King Lear* that was **229 lines of type in 4,400 — a line of the page
for every speech.**

The blank unit is still emitted, because it is in the copy and the reader's job is
to report what the copy contains. It is *marked*, and `compose` declines to set
white for it — only in dramatic copy, and only where no heading is beside it.

**And the casting off had to be told.** `cast-off` went on allowing a line for a
blank that `compose` no longer set, so every page in a play came up a line short
for every speech on it and the compositor spun out what he had to fill the depth.
A real mechanism, fired by two stages disagreeing about arithmetic rather than by
anything in the copy. **This is the third time that fault has appeared here and it
is always the same shape: one property settled in two places.**

### Rules, borders and ornaments are objects

Prompted by the question *what do the sources say about frames and ornaments —
those are objects too*. They are, and the sources are unanimous:

- **They print.** A rule is type-high, which is exactly what distinguishes it from
  the furniture (Blayney i. 124 n. 2), and is cast on a body of so many ems.
  McKerrow infers wide spaces from the fact that "ornaments and rules of several
  ems in length were quite common" (p. 108). Cambridge bought brass rules from a
  London joiner at about sixpence each (McKenzie i. 42).
- **Five to a page, ten to a forme.** "Each page is surmounted by a headline and
  enclosed in a frame of 'box' rules. Five box rules appear, since one is used
  below as well as one above the headline" (Hinman i. 51).
- **The two kinds go different ways.** Box rules are the skeleton's, stripped and
  lifted with the running titles. The centre rule "belongs to the type-page proper
  rather than to its skeleton, and it was not removed from the type-page during
  stripping operations" (i. 130) — it goes to the case with the type beside it.
- **The arrangement is the fingerprint.** "Almost never, when rules took up new
  positions in a given forme, did they resume exactly their former positions in
  some later forme. Hence a given arrangement of rules serves to define a group of
  formes belonging to the same printing sequence" (i. 148).
- **They wear, and the wear is datable.** Hinman follows individual centre rules by
  their degeneration and names three of the worst in the last quire of the
  Tragedies (i. 148).

So `imposition.rkt` has a `type-rule` struct: id, kind, length in ems or lines,
accumulated damage, impressions worked. They wear at one imperfection per 25,000
impressions, read off what Hinman treats as *remarkable*. The stylesheet's
`border: 1px solid` box is gone with them: four sides of one CSS border cannot be
four objects, and Hinman's whole argument is that they are.

**Still only rules.** Ornaments, factotums, head- and tail-pieces are not
modelled. The satyr tailpiece is the obvious next one and is fully specified in
the sources — about 70 × 120 mm, used for 24 of the 36 plays whenever the last
lines take up less than about two-thirds of the final page, in two states either
side of Z6.

### What it showed that is not a defect

Three mechanisms report nought on the Folio — pages crowded, lines of copy
dropped, catchwords not answering — and all three are alive. They are consequences
of the casting off, and casting off is some sixteen times tighter on verse than on
prose, because the man counts verse lines and estimates prose: `slip` in
`imposition.rkt`, 0.06 against 1.0, which is Gaskell's point. The same code on
prose copy at the same accuracy crowds 109 pages per thousand and drops 406 lines
per thousand. **The report now says so beside the noughts**, because a bare `0.00`
is exactly the reading that once had a live mechanism written off as dead here.

`tools/audit-mechanisms.py` sorts every countable mechanism into *fired*,
*silent*, and *not offered*, and distinguishes a silence with an established
explanation from one without. It exits non-zero only for the latter.

**Greg's consistency condition depends on how many copies you collate**, which was
not expected — and the explanation first given for it was wrong. It was recorded
as a small-sample effect: more copies, more chances for the warehouse's lost
order to show. §3 replaced the noise model with Moxon's doublings and the real
variable turned out to be the **spacing of the collated copies in the heap**
against how far a sheet can travel, which the mechanism bounds at 70. Ten copies
of a 750-sheet impression are 75 sheets apart and cannot see the disorder at any
rate at all; sixty copies are 12 apart and see it every time. The sample was not
too small, it was too sparse. Numbers in the README.

---


---

## §12 — What a corrector could correct

### The number: twenty corrections on one page of the First Folio

> "A solitary page, proof-corrected, of the First Folio of Shakespeare survives.
> It is page 352, containing a portion of the text of *Antony and Cleopatra* from
> scene i, line 27, to scene iii, line 23, of the third act. … **There are twenty
> corrections, mostly of pure compositor's blunders**" (Simpson, p. 82)

The Folger leaf, found by Halliwell-Phillipps in a parcel of Folio fragments.
Against it, this program's whole Folio holds **813 accident events and 1,538
misreadings over 948 pages — 2.5 correctable errors to a page.** Simpson's one
page carries twenty.

**An eightfold shortfall, and it is not a rate that was set too low. It is the
wrong population.** The foul-case rate here is 0.87 per 1,000 words, measured by
diffing the *Much Ado* quarto against the Folio set from it — that is, measured on
**errors that survived into print**. The corrector's input is errors *before* he
corrected them, and the difference between the two is exactly what he caught. The
program generates errors at the surviving rate and then corrects a share of them,
so it necessarily ends with fewer survivors than were measured *and* far fewer
corrections than Hinman and Simpson observed. One number is being asked to do two
jobs.

That is the finding, and it is worth more than the press-variant total it was
chased for. **Every error rate in the calibration table taken from a printed book
is a post-correction rate**, and any mechanism whose consumer is the corrector
needs the pre-correction one.

Caveats, kept because one page is one page: this leaf was proofed, and proofing
was not spread evenly — Hinman found it "in considerable measure confined to some
six or eight plays", so a proofed page may be a selected-bad page. Twenty is one
observation with no variance behind it, which is the error this file has just
finished committing twice. It bounds the direction, not the value.

### The vocabulary: Hornschuch's marks, 1608

Simpson reports Hieronymus Hornschuch's *Orthotypographia* (1608) at length
(pp. 130–2) — a proof-corrector's manual from inside the modelled period, with
the full list of correction marks. It is a taxonomy of correctable error, and
most of it is missing here:

| Hornschuch's mark | in the program |
|---|---|
| a letter, a word, or a stop **left out** | no — the next one to build |
| anything **redundant**, struck through | no |
| a **turned** letter or stop | yes |
| words **run together**, the spacing left out | no |
| a **lead showing** between words (his same mark) | **built** — see below |
| a **gap closed up** in a word split in two | no |
| type **awry, aslant, or standing above the line** so the nearest letters print fainter | **built** — see below |
| **transposition** of words | no |
| spacing to be **marked off** | no |
| the **full stop** | **built** — see below |

And his account of the corrector's watch-list gives two rules rather than rates,
which is what this project prefers:

- **Foul case has two causes, and the program models one.** Letters "slip over
  from adjoining boxes" — which is `ADJACENT`, built from the case lay — *and*
  "letters similar in form elude the printer", for which he names **r/t, n/u, e/c,
  a/v, e/o, c/t** and the ſt/fi/fl ligatures. A shape-confusion set is a different
  mechanism from box adjacency and needs no rate of its own.
- **Wrong fount is not uniform.** It is "mostly caused by having to vary the type,
  for example by inserting italics and capitals in a body of lower case". So it
  concentrates where italic and roman meet, which the program can place by rule.

He also names turned **s** and **o** and the numeral **0**, where `TURNED-PAIRS`
has n/u, b/q, d/p and 6/9 — and the program already knows the harder half of that
point, that a turned `o` is invisible to a reader.

### The distribution: what the Folio's corrector actually did

Simpson itemises the Folger page (p. 83), which gives a shape to aim at rather
than a rate to fit:

- **misspellings** — `hould`/`Should`, `their`/`there`, `plaes'd`/`pleas'd`,
  `voic'c`/`voic'd`
- **punctuation** — a comma deleted, a comma inserted
- **a turned letter**, marked
- **omitted spacing** — `onboth parts`, `farethee well`
- **a space wrongly inside a word** — `tro bled`, closed up
- **a crowded line mended at proof**: finding the line too full after altering
  `rume` to `rheume`, the corrector deleted the final `e` of `yeare`. That is a
  crowding device applied by the *corrector*, which §5 does not have and which
  belongs with its work
- **a miscorrection** — the final `d` struck out of `builded` in error. The
  program has this as `sophisticates`, and here is a real instance

And what he missed, which is as useful:

- a **speech prefix wrong** — `Ant.` for `Agri.`, "the compositor's eye running on
  to the mention of his name in the line". The program has no such mechanism, and
  it sits exactly beside the speech-prefix work §5 has just done
- a plural not corrected; a **turned `n`** in `tougue`; and the faulty verse-lining
  throughout

### A second itemised census, and it is the richest there is

Simpson describes Treveris's corrected proof of `The Grete Herball` (1526),
recovered from a binding at Queen's College, in enough detail to count
(pp. 63–4). It is worth more than the Folio leaf because he lists the
corrections rather than totalling them, and the kinds are the point:

- **literals** — `watrr`/`water`, `greueth`/`groweth`, and the two the corrector
  MISSED, `monnteth` and `gote` for `hote`
- **letters alike on the page** — `femeth`/`semeth`, `anayled`/`auayled`,
  `laudaue`/`laudane`, and `monnteth` again. Three n/u and one long-s/f, from
  six identifiable literals
- **a sort standing too high** — "the adjustment of the letter `n` of `soden`,
  printed too high"
- **a lead showing between words**, marked with a cross, twice — a space risen
  far enough to take ink. The program has this only as skeleton damage, never as
  a fault on the page
- **a broken letter**, marked
- **a word substituted** — `the` corrected to `of`
- **a miscorrection by the corrector himself** — he wrote `et` in the margin for
  `pacyon` where he should have written `nt`

And one that bears on a calibration already settled: **the compositor's
contractions were corrected out**. The proof reads `nothyn / ge` and `y` with a
superior letter, got by contracting to make the line justify; the published text
expands them. That is the mechanism behind the near-zero rate of tildes and
superior letters in printed books which §10's calibration table records as
measured — the marks were set and then removed, so counting printed books
measures the corrector as much as the compositor. **The same stage error as the
foul-case row, in a row nobody had suspected.**

Simpson's marking convention is worth having too: an irregularity of *printing*
rather than of letter — a sort above the line, a broken face — is marked with "a
curled stroke like an elongated six", distinct from the marks for a wrong letter.
The corrector's own vocabulary separates the two, and so should any model of him.

### The errata lists, and why they are a floor and not a census

Errata are the other surviving record of what a corrector missed, and Simpson
gives many. Two are enumerated:

- **Gascoigne, *The Droome of Doomes day* (1576)** — "Fifty-one corrections
  follow. **They fall into two sets: they are either dropped words or
  misprints**." A dropped word is Hornschuch's first mark and the program has no
  such mechanism at all.
- **Nine errata** in another, and **six misprints** in Drayton's *Muses Elizium*,
  where the printer blames "partly the raggednesse of the written Copy, and
  partly our ouersight" — copy quality and compositor named as the two causes,
  which is the split `--no-copy-preparation` models.

**But an errata list is selected for severity and cannot be read as a rate.** Two
printers say so outright. Lambard's *Perambulation of Kent* (1576) grades the
faults — some "blemish only the beautie of our owne workmanship", others "offend
against the lawes of Orthographie", others "shrewdly peruert the sense", others
"vtterly euert his meaning" — and then prints only "**Suche therefore as be most
daungerous**". Bartholomew Young's *Diana* (1598) is blunter: "the greatest faults
are at the ende of the Booke set downe, **the lesse being of no moment purposely
omitted**".

So the printed errata give a **lower bound on surviving errors and a taxonomy of
severity**, and they are evidence against any attempt to read a rate off them.
The taxonomy is usable as it stands: a model that graded its own errors the way
Lambard grades his — cosmetic, orthographic, sense-perverting, meaning-destroying
— could say which of them a corrector working by sense would catch, which is
exactly the distinction `catches-accident` and `catches-misreading` are groping
at with two numbers and no principle.

Lambard also gives an edition size in passing: **six hundred copies**, and twenty
years to sell them.

### The stage audit, run over every error row — and only one was what it looked like

§12 found the foul-case row comparing a rate the program *makes* against a
measurement of what *survived*. The obvious next move was to check the other
rows, since only the **error** rows can be affected: a word division or an
ampersand is a deliberate act and no corrector removes it, but an error passes
through him and the printed book records only what he missed.

Three rows were at risk. The audit found one real fault, one clean row, and one
lesson that applies to the whole table.

**Wrong-fount sorts — a real stage error, and unfixed.** Hornschuch names it
outright as something the corrector cleared: "Wrong fount (*literæ heterogeneæ*)
is another source of trouble", caused "mostly by having to vary the type, for
example by inserting italics and capitals in a body of lower case". In this
program it is classified as a **`'shift`** — a shop expedient alongside robbing a
sort and setting one face down — so `press.rkt` never offers it to the corrector
and every one of them prints in every copy. The table then compares that
uncorrected count against "a handful a book", which is what survived a corrector
who was clearing them.

And the count is not small: **1,996 wrong-fount sorts in the Folio, 2.31 per
1,000 words.** The classification is defensible on its own terms — the draw
returns the right character, so "the reading is right and the letter wrong" — but
that is exactly the class the faults of impression above occupy: visible on the
page, no reading changed, and therefore mendable at proof but invisible to any
collation. **It belongs with them and is not yet moved there.**

**Tilde and superscript rows — no stage error, and a presentation fault that runs
through the whole table.** These are calibrated the other way round: `SCRIBAL-RATES`
holds rates measured off printed EEBO-TCP books and `tilde-chance` is fitted
backwards so the program's *printed* output matches them. Both sides are printed
rates, so the comparison is sound.

What is not sound is that both sides are printed as points. The corpus figure is a
**median across documents**; the program's is **one run of one text**. Recounted
from the 5,287 texts on disk, English, 2,000 words or more:

| | books | with none | median | p75 | p90 | p95 | model, 4 seeds |
|---|---|---|---|---|---|---|---|
| 1580s | 51 | 0% | 2.99 | 5.85 | 9.65 | 11.19 | **5.01–7.13** |
| 1600s | 78 | 6% | 1.11 | 2.51 | 5.04 | 10.19 | **1.71–2.40** |
| 1620s | 83 | 14% | 0.25 | 0.83 | 2.25 | 4.78 | **0.16–0.87** |

**The program sits between the median and the third quartile at every date** — a
book that uses the device rather more than the typical book, and nowhere near
outside the range. Whether it ought to sit on the median is a judgement nobody has
made; what the table shows instead is "1.01" against "1.66", two points, with the
spread and the skew invisible. A sixth of books in the 1620s have no tilde at all.

### The rate, got wrong from a page this file had already warned about

Set first from the leaf's **density**: two corrections in some 900 words, caught at
the rate a literal is caught by, giving about three per thousand made. On the
Folio that produced **412 pointing variants in a total of 934** — against Hinman's
"just over 500" for the whole book, every kind included. Nearly double, from one
category.

The fault is the page, not the arithmetic. **That leaf carries twenty corrections
where Hinman's figure implies two and a half to a page**, so it runs eight times
the book's average — and §12 says exactly that, four paragraphs above where the
density was taken off it. *Recorded because knowing the caveat and writing it down
did not stop it being ignored by the person who wrote it, two hours later.*

What survives one bad page is the **share**, not the density: punctuation is two of
its twenty corrections, about a tenth of what the corrector caught. A proportion
does not care that the page was a bad one. Re-derived on that basis the rate is
**0.0003**, and pointing comes out at 45 of 478 variants — 9.4%, which is the share
it was set from and therefore no evidence of anything. The *total* is what gets
read afterwards.


---

## The facsimile at folio scale

Not a roadmap section. The rendering was never measured until it was called
slow, and the three costs turned out to be separate, differently caused, and
badly misjudged on first inspection.

### The 33 MB of inline styles cannot be moved to a stylesheet, and moving them makes the file bigger

The obvious optimisation, and the one anybody will reach for. A folio's facsimile
is 75 MB, and **867,976 `style="--x:…;--w:…"` attributes are 33.4 MB of it — 44%**.
Inline style is the textbook thing to hoist into a class.

Counted before it was attempted: **680,545 of those values are distinct, 78.4%
unique**. Every word sits at its own measured position, so there is almost
nothing to share. Hoisting them costs a 28.8 MB stylesheet plus 13.1 MB of class
references — **42.0 MB against the 33.4 MB it replaces**, and the file grows by a
quarter. The three values that do repeat are `--m:20.000` and its kin, 1,970 of
them, which is per-column and not per-word.

The related question, whether to serve the stylesheet as a separate file, is
answered the same way from the other end: the stylesheet is **~30 KB of 75 MB**,
so unlinking it saves 0.04% and costs the self-contained property. Neither is
where the bytes are. **The bytes are irreducibly per-word data**, and only
chunking or fewer words will move them.

### `content-visibility` was expected to fix interaction only, and fixed the load as well

Measured on the folio before anything was changed: **81 s to `domContentLoaded`,
1,074,060 DOM nodes, and 25 to 32 SECONDS for a single reflow** — paid again on
every zoom, resize and legend toggle. The reasoning was that the 81 s is the HTML
parser building a million nodes, which `content-visibility` cannot help, so it
would fix the reflow and leave the load alone.

Wrong, and by a lot. With `content-visibility: auto` on `.opening`, reflow fell
to **100 ms** — but `domContentLoaded` fell to **14.6 s** as well. The parser is
not the whole of that 81 s: the browser lays out incrementally *as the document
streams in*, and skipping the layout skips it during parsing too. **A cost
attributed to parsing was mostly layout wearing parsing's clothes.**

The trap in applying it is margin collapse. `content-visibility` brings paint
containment, which clips `.tag` — 46px above its opening, being its `top:
-2.9rem` and therefore the same on every book — so the containment box needs
padding. Taking that padding out of the margin *arithmetically*, 3.4rem of margin
becoming 0.4rem margin and 3rem padding, is wrong: **adjacent margins collapse
and padding does not**, so every gap grew by 48px and the book by 23,625px. The
correct compensation leaves 0.1rem of margin on each side and puts the rest in
padding.

### Streaming the TEI, and what it does and does not save

`read-xml` on the 85 MB folio TEI: **54 s and 2,561 MB retained**. The same file
walked a page at a time with `read-xml/element`: **28 s and 13 MB** — the stdlib
does this, no `sxml` or SSAX needed. Rendering was refactored to work from a
header and a stream of pages, and the output is **byte-identical**.

What it does not save is the memory of a *full* render, which is dominated by the
75 MB of HTML being accumulated and comes out around 400 MB either way. What it
does save is `--pages`, which used to read all 985 pages and throw 965 away: a
20-page preview went from the whole 54 s parse to **11 s, of which only 2 s is
XML** — 123 ms for the header, 414 ms for the twenty pages, and 1.5 s counting
the rest of the book, which is needed only to say "showing the first 20 of 985".
The remaining 9 s is module loading, and was always there.

One thing the header cannot answer: its `<extent>` says "990 pages" where the
body holds **985 `<div type="page">`**. The bibliographical count and the encoded
count are different numbers, and the one the facsimile reports has to be counted.

---

## Comparing runs

### A seed names a run of the random stream, not a book, and the per-seed columns invited a false alarm

The Folio was regenerated and press variants read **346** where CALIBRATION.md
recorded **478 for the same seed** — a 28% fall against a calibration target the
old figure straddled. It looked like a regression, and it was chased as one.

The chase was sound and worth keeping. A worktree at the commit that wrote the
table reproduced its figures **exactly** — 478 variants, 66 catchwords failing,
118 proofed, 107 corrected — so the table was not stale-in-the-sense-of-wrong,
and the movement was genuinely caused by the commits after it. Bisecting four
commits at one seed put the whole of it in `ad99ada`, which touches
**`orthography.rkt` and nothing else**, and the whole of *that* in one class:
"reading restored from the copy", 309 to 134, which is 83% of the loss.

That looked damning, because the obvious mechanism would be the lexicon gate
quietly repairing misreadings — a device forced to produce an attested form,
handed `thier`, returning `their`. A compositor sets what he read, and a spelling
device that undoes his eye-slip is a spell-checker in a printing house.

**Measured, and it does not happen: 636 misreadings made, 636 surviving to print,
0 repaired — and 0 at every one of the three commits.** `press.rkt` is byte for
byte the same across the change. There is no mechanism.

What actually moved is the stream. On one seed, Areopagitica sets in **60 leaves
at the older commit and 64 at both later ones** — the casting off acquired two
regimes — and on seed 44 the Folio is now 954 pages and 480 formes where the
table says 948 and 474. Word count moves 0.09% while misreadings move 4%, which
nothing but a shifted sequence of draws explains. **The same seed after a change
of this kind is a different book**, so the per-seed columns are not paired
observations and the differences between them are not differences.

Read across versions, only the spread and the mean mean anything: 368–624 against
321–531, overlapping, *t* ≈ 1.1. And with four seeds that test could not detect a
real shift of a fifth either, so the honest verdict is **no evidence of a
regression**, not proof there was none.

The header of that table now says so, because the shape of the table is what
caused the error: four labelled columns beside four older labelled columns are
an invitation to subtract them.

### Wrong fount was right all along, and unmeasurable from the report

Chasing what looked like a stale calibration row produced two false trails worth
marking, because both are easy to walk again.

**`wrong-fount` in the TEI is not a wrong-fount sort.** Grepping the Folio's TEI
for the string gives 79, against a recorded 1,996, which looks like a mechanism
that has collapsed. They are running-title damage names — `[a wrong-fount i]`
from `imposition.rkt` — identifying a skeleton forme, and have nothing to do with
the event. A wrong-fount *borrow* leaves no such string.

**The category is not mislabelled either.** The next guess was that the row
reported the whole `'shift` kind under the name of one of its five causes. It
does not: counted apart, wrong fount on the Folio is **1,947** against the
recorded 1,996 — the row was accurate, and the difference is stream drift.

What was actually wrong is that **no number in the report could have produced
it**. The only figure printed was `Shifts made for want of a sort: 375852`, which
is the whole kind and **98% space-metal** — 367,822 whites made up of smaller
pieces, beside 4,524 cannibalized, 1,947 wrong fount, 956 another sort and 603
face-down. A row graded against Blayney's "a handful a book" was being kept by
hand from a quantity the program never printed. `analysis.rkt` now prints the
five apart. **A figure in CALIBRATION.md that no report line yields is a figure
nobody can check, and it will drift silently.**

The one substantive correction: the note said no corrector is ever offered a
wrong-fount sort. **Ten of the 1,947 are corrected**, by the other door — the
copy-comparison scan catches anything whose printed form differs from the copy,
and a borrowed sort that prints `V` for `U` differs. `DVKE. ] DUKE.`

### Lambard's grades are not the order a corrector catches in

The obvious use for the four grades — "blemish only the beautie of our owne
workmanship", "offend against the lawes of Orthographie", "shrewdly peruert the
sense", "vtterly euert his meaning" — is as a ladder of catch rates: the worse
the fault, the likelier it is mended. **That is backwards, and putting the two
orders side by side is what shows it.**

Lambard grades by DANGER. A corrector reading without the copy catches by
DETECTABILITY — by what disturbs the surface, not what costs the reader. The two
run in different orders and part at both ends:

| | Lambard's rank | how catchable |
|---|---|---|
| cosmetic — a wrong fount, a shift | least dangerous | **not at all by sense**; the reading is untouched |
| orthographic — `hanourable` | second least | **easiest**; not a word, the eye stops |
| sense-perverting — `their` for `there` | second worst | **among the hardest**; it reads |
| meaning-destroying — a word dropped | worst | visible as a break, but not repairable without copy |

So **the dangerous errors are exactly the ones that survive**. That is why an
errata list is full of what a proof census does not show, and it is the same
two-stage disagreement the dropped word turns on: Gascoigne's fifty-one errata
are half dropped words, and neither surviving proof census shows one at all.
Lambard is evidence about *what got out*, not about what a corrector found —
and he says so himself by printing only "Suche therefore as be most daungerous".

The program's two catch rates turned out to be two of the four grades already:
`catches-accident` 0.75 is the orthographic one, `catches-misreading` 0.10 the
sense one. Naming them so is byte-identical on a full run. What it buys is that
the other two grades have somewhere to sit, and that **a new fault is now graded
rather than given a rate of its own** — which is the fifth different way this
project has found of not inventing a number.

### Wrong fount was two orders out because the mechanism had the wrong cause

The row read **1,947** on the Folio against "a handful a book", and it had stood
in CALIBRATION.md marked as the one known fault for long enough to be quoted as
a caveat rather than treated as a defect. Two attempts at it failed before the
right shape, and both failures are worth keeping.

**It was invisible, and that is why it drifted.** The only figure the report gave
was `Shifts made for want of a sort: 375852`, the whole kind and 98%
space-metal. Splitting that in the report exposed the row the same afternoon.
A figure no report line yields is one nobody can check.

**The constant contradicted its own comment.** The last resort for an empty box
chose between setting a sort face down and borrowing from another fount, and the
note above it reasons correctly from Blayney — *Lear* "bristles with … improvised
substitutions" while he remarks "the relative infrequency of … wrong-fount
types" — and concludes the parameter "should not be pushed toward the borrow".
It was set to push 0.75 toward the borrow.

**First fix, and it was wrong.** Give the corner to the face-down, on the
argument that the sources bound the two differently: Blayney proves the
face-down once and the note calls its observable count "bounded below by 1 and
above by nothing", where the borrow is bounded above at a handful. The reasoning
about the sources was right and the consequence was not — the face-down went to
3,695, and because it is the one expedient that makes press-correction
*necessary*, **the variant count went to 1,152 against Hinman's five hundred**.
Neither expedient can carry four thousand.

**The corner was the error.** The model emptied a box and then asked what
desperate thing to do about it, four thousand times. A working shop distributes
continuously, so the commonest answer to an empty box is that it was not empty by
the time he reached it, and the page keeps no record. The expedients are for the
times the supply really failed: face-down held at 629–678 and press variants at
472–627, both where they were.

**And the borrow got the cause the source gives it.** Hornschuch: wrong fount is
"mostly caused by having to vary the type, for example by inserting italics and
capitals in a body of lower case". That sentence had been in this file since
Simpson was read and nothing was built on it. Placed where italic meets roman it
reads **11–16**, at the same stage as the source — which is also why a
wrong-fount sort dates a page against the shop's other work.

**A rate that is two orders out is not usually a rate.** It was the cause.

### Spinning out could only double white that was already there

A sixth of the Folio showed white at the foot, and the row that should have
caught it was pointed at the wrong quantity. `miscast 324 per 1,000` counts pages
whose copy was MEASURED OUT wrong; Blayney's "the page-depth is almost entirely
consistent" is about the depth the page came out at, and the crowding devices
exist to turn the one into the other. The report had said as much for months —
it prints the miscast count and, separately, the two pages "under serious
strain", with the note that "the two counts are not interchangeable" — and the
calibration table quoted the first against a claim about the second.

Measured directly, the defect was one-sided and complete:

| | pages | filled the measure |
|---|---|---|
| crowded | 132 | 86.4% |
| **spun out** | **168** | **4.2%** |

Crowding worked and spinning out essentially never did, and the cause was a
single condition:

    ;; an extra white line wherever there is already one
    (if (and (eq? (set-line-kind l) 'blank) (< added need)) ...)

**It could only double a blank that already stood.** The median spun-out page had
none at all, and 95% of them wanted more white than the page had blanks to
double. The device was not weak; it had nothing to work with — which is a
different failure from a badly-set rate and wants a different fix.

A page has more joints than it has blank lines: a paragraph beginning, which its
indent marks; a speech or stage direction, whose first word is italic; a heading.
Opening those as well takes spun-out pages from 4.2% to **90.4%** filling and the
book from 82.0% to **99.9%** within two lines of its measure, with press
variants, formes corrected, the crowded/spun split and the surviving-accident
rate all where they were.

**A row that fails a source may be pointed at the wrong quantity, and the way to
find out is to measure the quantity the source is actually talking about.**

### The close-set comma is neither a convention nor a fault: it is what a short case does

Nine pages of the Second Folio were read by eye to settle whether `--mis-space`
was too low. Two things are visible on those pages and they are not the same
thing:

- **words genuinely run together**, `Whichſpeed`, `Towhom`, `Vntothe`, `Wifeand`
  — mean about 3 a page;
- **no space after a comma**, ranging from 7 a page on one to about 50 on
  another.

Bowers separates them in as many words: a word run together with the next is
"**a misprint** … which must be reproduced", while two words "separated by a
comma but set close up without a space following the comma … **are not
considered to be misprints**".

The first reading of the second kind was that it must be a house convention, and
Smith supports that much — the comma "clinge[s] to the Matter so close as it
always does, **in England**", where "all other Printing Nations make it a law to
put at least a thin Space before it". Moxon gives the mechanics: an em is seven
thin spaces and the comma is cast one and a half of them, so the sort reads as
its own gap.

**But the variance was too wide for a convention, and Blayney had already found
why.** Counting Okes's men he reports that "C set approximately 20% of his
unjustified commas without a space", that B's average was higher and erratic,
and that "several patches of exceptionally frequent close spacing can probably be
explained as **the result of space-shortage**" — K3v spaced 16 : unspaced 3
against K4r spaced 4 : unspaced 22. Sixteen per cent on one forme and
eighty-five on the next.

**So the program had the cause and not the effect.** Space-metal shortage was
already the hinge of the whole type-case model — 370,728 shifts for want of it on
a Folio — and its only response was to make a white "up of smaller pieces". It
could not do the thing Blayney watched a compositor do. The white is not lost
when the comma is set close, it is **moved**: he is short of metal, not of
measure, so the space goes into the other gaps of the same line and the line
still fills. That is why no corrector marks it.

Added, it gives **29.9% of commas** on the Folio — between Blayney's C at 20% and
his B at "considerably higher" — with **nothing tuned to make it so**, and the
right kind of patchiness: 4 on the quietest page against 59 on the busiest, a
15-fold spread where Blayney's two formes differ 7-fold.

**And a caution about the instrument.** Blayney, with the sheets under a glass,
declined to tabulate this: "it is often extremely difficult to decide whether or
not a space is likely to be present". A thin space is a seventh of an em. My
counts came off a 105-dpi rendering, where it is invisible. **The eye-counts
above are good for an ordering and worthless as rates**, and the number in
CALIBRATION.md is Blayney's, not mine.

### The Q/F diff overcounts foul case, and the rate was set on the belief that it undercounts

`typecase.rkt` held the foul-case rate above the one measured figure — 0.25 per
1,000 words, three accidents in 11,990 of *Much Ado* — on an argument written
into the code: the comparison "can only see errors that changed a word into a
different string, that escaped the corrector, and that stand in the one copy
transcribed. It cannot see an error shared by both books." All true, and all
pointing one way: the diff must undercount, so the generator should sit above it.

**Nobody measured it, and it is wrong-signed.**

This is the one experiment a library cannot run and this program can. The
historical relationship was reproduced exactly: a first setting stands for the
quarto, its printed text becomes the copy for a second, and the two printed texts
are diffed word for word — so an error already in the quarto IS reproduced by the
second compositor and IS hidden from the diff, which is the very difficulty the
old reasoning rested on. Then the bibliographer's rule was applied: ring a
one-letter swap between adjoining boxes that leaves a form nobody ever wrote.

    148,828 words     126 accidents made     213 attributed     169%

**It overcounts by seventy per cent.** Foul case has no signature of its own. The
mark it leaves — one letter wrong, the wrong letter next door in the case, the
result not a word — is exactly the mark of a misreading, and exactly the mark of
a sort taken because the right box was empty. The bibliographer ringing it cannot
tell the three apart, and the hidden shared errors do not make up the difference.

Two false starts are worth keeping, because both are ways of getting this wrong:

- **Diffing the copy-text against the print** attributed 5,080 accidents where 74
  happened. Modern-spelling copy against period-spelling print makes every
  convention look like an error.
- **Adding the non-word filter but keeping that comparison** still gave 1,107 for
  74. The comparison has to be print against print, in one orthography, or it
  measures the modernisation and not the case.

The rates came down a quarter, which puts the SURVIVING figure at 0.55–0.63
against the interval's 0.05–0.73 — inside it, at the same stage, for the first
time. Not down to the 0.25 point estimate: three hand-classified events is a thin
anchor, the interval is wide because of it, and a rate carrying this much doubt
belongs at the top rather than the middle.

**A generator set above an observation to compensate for an instrument is resting
on a claim about the instrument. That claim is measurable here, and was not
measured for a year.**
