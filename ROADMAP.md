# Roadmap

Ordered by evidential value rather than by effort. The question asked of each
item is not "would this be interesting?" but **"would this let the program be
wrong in a way we could detect?"** — which is the only thing it has ever been
good for.

Open work first, because that is what a roadmap is for. Then what is built,
kept short. Then the working rules, which are the most useful part of this file
and the part most expensively learnt.

The README says what the program does and where it currently stands. This file
says what is wrong with it.

**Six items below came out of one afternoon's reading of Moxon and Smith** —
the two printers' manuals the README had listed as sources for a year while
every figure from them arrived second-hand through Gaskell or Blayney. Reading
them directly cost less than any of the work they invalidated. They are marked
**[manuals]**.

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
model put **27.2 distinctive types on a folio page** (± 1.2 over five seeds)
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
the model's own pieces, and this section can test it at any fount condition.

One free parameter, `--discrimination`, the finest difference between two
injuries an investigator can reliably see. Anchored on Hinman's Folio, so it is
a **ceiling** on what a bibliographer sees rather than a typical value — the
best-equipped study the method has had, with eighty-odd copies and a collating
machine. Blayney says most quarto investigators "have used rather less evidence
per forme than did Hinman".

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

### The chaining is built, it never fires, and that is a fault in the shop

`chain-quires`. The last forme of one quire was set immediately before the first
forme of the next, so the prohibition reaches across the boundary: an end that
shares type with the previous quire's last forme cannot be this quire's first
(i. 81). **It says nothing in 24 boundaries of 24**, because *both* ends share.

The cause is not the method. The last forme of one quire shares **six to ten**
identifiable types with the first forme of the next, where Hinman's premise says
they cannot share at all — and the measurement two entries above already showed
it book-wide: consecutive formes here share about 40% of the time (offset 1 is
empty in only 54 of 91 pairs at one forme standing). **This shop does not obey the
premise Hinman's method rests on.**

`book.rkt` distributes on the type ceiling as well as on the count of formes
standing, so a forme can go back to the case early and its type reach the very
next forme. Hinman's shop evidently did not do that.

**Which cuts the opposite way to every correction in this file.** The rule at the
top is that each parameter checked against a book has made the shop poorer or the
evidence thinner. Here the simulation is making a *bibliographer's method* look
worse than it was: the 50–80% strike rate is depressed by the model's own eager
distribution, and a shop honouring the premise would determine more quires than
this one does. The figure to quote is therefore a floor, not an estimate.

**The experiment first proposed here was the wrong one, and Hinman says so
himself two chapters earlier.** It was "raise the fount until consecutive formes
stop sharing", on the strength of §9's note that Moxon's smallest respectable
fount is larger than Blayney's measured one. That is not his account at all
(i. 73–4):

> "Jaggard's supply of type was inadequate for setting the Folio in the customary
> way … Setting by formes, on the other hand, would demand relatively little type.
> **The types used in forme I could be distributed as soon as forme II had been
> set** (provided, of course, that presswork on forme I had been completed
> meanwhile, during the composition of forme II) and at once used again to set
> forme III. Thus **only enough type to set four pages would be absolutely
> required** — although, as before, something above the bare minimum would be
> desirable."

And the stock he later establishes: "the supply was large enough to set about
**eight Folio pages**, and hence that it was **barely adequate, at best, for
setting by successive pages**."

**So the premise has nothing to do with an abundant fount.** The Folio shop was
short of type — that is Hinman's reason for setting by formes in the first place.
The premise holds because of *when* the shop distributed: forme I goes back to
the case **as soon as forme II has been set**, between formes and never during
one. Two consecutive formes cannot share because both are standing while the
second is composed, and that is true at any fount size.

His two numbers make it exact: four pages standing is the absolute minimum for
setting by formes, and the shop held about eight — **twice the minimum**, which
is the margin that keeps a case from running dry in the middle of a forme.

**What is wrong here is therefore the distribution trigger, not the fount.**
`book.rkt` fires distribution mid-forme whenever `standing-sorts` passes
`type-ceiling`, checked after every page. That check is right for *measuring* the
peak — the comment there is correct that the cases run thinnest mid-forme — but
making it also the moment of *action* is what lets a forme reach the case before
its successor is finished, and puts six to ten shared types across a boundary
Hinman says must be empty.

**The experiment was run, and the change was reverted.** Moving distribution to
forme completion — the timing half of Hinman's account, without the fount half —
was tried and measured on all three counts at once. Folio in sixes,
*Areopagitica*, 20 seeds for the criterion and 6 for the shortages:

| | consecutive formes sharing | quires determined | shortage events |
|---|---|---|---|
| as it stands, 1 forme standing | — | 80% | 9,749 |
| **at forme completion**, 1 standing | — | 80% | 9,749 |
| as it stands, 2 formes standing | ~40% | 50% | 17,875 |
| **at forme completion**, 2 standing | **9%** | **0%** | **25,313** |

At one forme standing nothing moves at all, to the event: with a single forme
standing, distribution already happens at every forme completion, so the shop was
conformant and the change is a no-op. **That is the check that the two things are
the same thing**, and it passed.

At two formes standing the premise improves exactly as predicted — consecutive
sharing falls from about 40% to 9% — and the model gets worse in both other
respects. Shortages rise **42%**, and the criterion stops determining any quire at
all: fewer pieces circulate, so fewer pairs are prohibited, so more orders survive
and none is unique. Hinman's premise and Hinman's method pull in opposite
directions here, and the reason is the half of his account that was left out.

**The fount margin is not optional, and this fount has not got it.** He specifies
both numbers: four pages standing is the minimum for setting by formes, and the
Folio shop held about eight. Our shop at two formes standing in folio-in-sixes has
four pages standing and a ceiling at two-thirds of the fount — no 2× margin — so
forbidding mid-forme distribution simply runs the cases dry, and the 42% is what
that looks like. Blayney's shortage ladder does not collapse, but it swells past
anything his books show.

**Reverted rather than shipped**, because a change that halves one number to
improve another is the failure this project keeps catching.

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

### What is actually wrong is smaller and more specific

**`--formes-standing` does nothing at folio-in-sixes.** Formes standing 2, 3 and 4
give byte-identical figures for adjacent sharing (12/130), quires determined
(12/23) and the link (0/0); only the shift count moves, by 0.6%. The ceiling
always fires first, because the peak includes the forme *currently being set*: two
complete formes are four pages, the ceiling allows 5.9, so distribution triggers
about two pages into the third forme — mid-forme, every time, whatever the forme
count says. That is precisely the mid-forme distribution Hinman's premise forbids,
and it explains why the parameter cannot fix it.

**And the ceiling fraction is where the two sources part company.** `typecase.rkt`
calls two-thirds "a judgement about how thin a pair of cases may get", claiming no
authority, and it is what makes the quarto agree with Blayney. Hinman's Folio ran
at **six pages of eight — three-quarters**. Raising the ceiling to 3/4 would let
three formes stand at folio and let distribution wait for forme completion, which
is the whole of what the premise needs; it would also give 17.7 quarto pages
standing where Blayney says Okes could not manage sixteen.

**So the ceiling cannot be one constant if both men are right.** It is not a
property of the metal but of a shop's willingness to work thin cases, and the two
best-documented shops of the period differ by a sixth. That is a real finding and
it is left standing rather than split: fitting a single value to the mean of two
shops would satisfy neither and would bury the disagreement, which is the more
interesting fact. The next step is a per-house ceiling, sourced at 2/3 for Okes
and 3/4 for Jaggard, and then the timing change — which at 3/4 should cost far
less than the 42% measured above.

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

Related and cheap once the inference exists: **pagination errors as evidence of
order.** `pagination.rkt` already separates errors of omission from commission
because Hinman says only the former are informative. Nothing yet uses them.

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

## 4. The space bodies are Jacobi's, 1890 **[manuals]**

`metrics.rkt` sets six space bodies — em, en, **thick 1/3, middle 1/4, thin
1/5**, hair 1/8 — and calls them "the spaces and quads, as they lie in the lower
case". Moxon's fount has four, and two of them are not these:

> Besides Letters, there is to be Cast for a perfect Fount (properly a Fund)
> **Spaces Thick and Thin, n Quadrats, m Quadrats and Quadrats.** (p. 170)

Davis & Carter, annotating p. 103, are explicit and go further:

> **Moxon knows of only two spaces: the thick and the thin** (p. 170). …
> **The present convention for the thickness of spaces (thick, 3 to the em; mid,
> 4 to the em; thin, 5 to the em) is of uncertain age.** Johnson's *Typographia*
> (1824, p. 101) shows that room was found in the case for the three spaces
> **when the long s went out of use**; Jacobi (*Printing*, 1890, p. 21) gives
> them their present value.

Three problems follow, of which the first is the serious one.

**(a) The values are dated 1890 and used for 1600.** This is the same error
`metrics.rkt` already documents and rejects twenty lines above, for the ranging
figures — "an eighteenth-century convention read back into the sixteenth". The
module caught it once and not twice.

**(b) The program sets long s *and* uses the post-long-s case.** Johnson's
point, as Davis & Carter report it, is that room was found for the three spaces
*because* the long s vacated its boxes. This program sets long s throughout and
provisions ſt, ſh and ſi as sorts in their own right.

**(c) Moxon's own values are neither of the program's.**

| body | Moxon | program |
|---|---|---|
| thin | **1/7 em** — "ought by a strict orderly and methodical measure to be made of the Thickness of the seventh part of the Body; though Founders make them indifferently Thicker or Thinner" (Dictionary, p. 353) | 1/5 em |
| thick | **1/4 em** — "one quarter so thick as the Body is high; though Spaces are seldom Cast so thick" (p. 103) | 1/3 em |

Davis & Carter derive a second reading of the thick space from the casting
instructions: "if a piece of brass a Brevier-thick is enough to make a thick
space of Canon body, **the thick space is one-sixth of the em**" (note to
p. 171). So Moxon supports thick ∈ {1/6, 1/4}, and 1/3 is outside both.

**What it changes.** `NORMAL-SPACE` is `THICK`, so the house's normal word space
is 33% wider than Moxon's. "Three spaces and no more" — which `description.rkt`
already cites and counts against — comes out at 1 em instead of 3/4 em. The
pigeon-hole threshold at `compositor.rkt:564` is `> EM-QUAD`, which is *exactly*
three thick spaces under the program's 1/3 em and therefore internally
consistent; under Moxon's it should be `> 3/4 em`. Every pigeon-hole count in
every report turns on which is right.

**Why this is not a one-line fix.** `UNITS-PER-EM` is 120 so the spaces divide
the em exactly, and the tests assert it. 1/7 of 120 is not an integer. Carrying
1/7, 1/6 and 1/4 exactly needs a unit divisible by 84: **`UNITS-PER-EM 840`**
would do it (em 840, en 420, thick 210 or 140, thin 120). That is a real design
decision with blast radius across every justification the program makes, and it
would invalidate the calibration table, which is why it is here rather than
done.

**The period question underneath it.** Smith (1755) *does* have four spaces —
thick, middle, thin, hair — in his bill, so the six-body ladder is right for the
eighteenth century and doubtful for the seventeenth. The program's period is
1580–1640 and Moxon is the nearest manual to it.

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
bug in the lessons below. Re-derive from Smith/10 and see whether the cascade
survives; if it does, the demand model is wrong somewhere else.

One confirmation while here: "**Letter Founders call 3000 Lower case m's a
Bill**, and proportion all the other Sorts by them; so that a whole Bill of Pica
makes 500 lb" (p. 46 n.) — which is `typecase.rkt`'s "a bill is a fount
proportioned to 3,000 m", now from the source rather than through Blayney.

---

## 5. Casting off is two regimes, not one dial **[manuals]**

`--cast-off` is a single scalar accuracy. Both manuals describe something with
structure, and Smith describes two regimes whose *errors behave differently*.

**Moxon (pp. 239–43)** counts letters, not words — 43 letters × 35 lines = 1,505
a page, × 127 pages = 191,135, ÷ (47 × 33 = 1,551) = 123 pages ÷ 8 = 15 sheets
and 3 pages. Then:

> a strict regard must be had to the **Breaks** … **long Breaks in the Copy are
> generally likely to be Got-in, and consequently a Line is Got-in: But short
> Breaks often Drive-out a Line.** Therefore … he more particularly considers his
> Breaks; and indeed **they serve as so many Regulators to him, to keep him
> within the bounds of his Counted off Copy**: For every Break he examines by the
> number of Lines from the last Break … and accordingly marks it in his Copy.

The error is not global. It is carried break to break and settled at each break,
with the running line-count written in the margin in figures.

**Smith (pp. 155–9)** knows that method and thinks little of it. He prefers
marking off every page — "which tho' it is very tedious, is nevertheless **the
safest way; because if we fall into a mistake in one page, we may recover
ourselves in the next**" — and of the break-to-break method: "they are as often
deceived by it, especially in a long run of close Matter … **Such casting-off
therefore is next to lumping the Copy; and no Compositor is to answer for the
contrary effects thereof.**"

**And the crowding devices are conditional on the regime**, which is the part
that bears hardest here:

> when Copy is cast off close, and the Pages marked off, the Compositor takes
> notice how his Matter runs; and **if he finds that it keeps not even with the
> Copy, he drives either out, or gets in, where he conveniently can** … but
> **this precaution need not be taken where Copy is cast off the other way.**

So: error bounded per page with active correction, or error accumulating across
a chapter with none. Two settings, not one dial — and the second is a licence to
let the mechanisms this program spent months building simply not fire.

Both manuals agree on two smaller points. **Abbreviations in the copy are
expanded** and counted at full length (Moxon p. 243, Smith p. 157) — independent
support for the near-zero measured rate of tildes and superscripts in printed
books, and against the compositor introducing them. And **headings are allotted
an explicit depth in lines**, marked in the margin; Moxon adds that the whites
round a heading must make "a just number of Lines" with the text body, so the
page still justifies in length.

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

## 10. The First Folio as the standard test case

`tools/fetch-folio.py` builds the whole book as copy — 868,245 words, all 36
plays in the order of the 1623 Catalogue with the eight preliminary pieces, as
both declared TEI and constructed Markdown. Nothing is committed; it is other
people's text, on the footing of `corpus/` and `sources/`.

It is the standard case because it is the *hard* one. **The current numbers are
in the README**; what follows is the history, which is where the value is.

### What the scale caught

- **The folio measure was wrong, and by 25%.** `FOLIO` and `FOLIO-IN-SIXES`
  carried an unsourced 16 ems. Hinman measured the book: "twenty lines measure
  about 83 millimetres; and since the horizontal measure of the type-column is
  also about 83 mm., each ordinary Folio line may be said to contain 20 ems"
  (i. 35). At 16 a pentameter does not fit, so **a third of all verse lines were
  being turned over**, each turn-over costing a second line of type. Correcting
  it took turn-overs from 333 to 139 per 1000 verse lines and the book from 1,386
  pages to 1,026.
- **A fuller spelling could overrun the measure and crash the compositor.**
  `justify` re-checks the squeeze every round and gives up at HAIR; the *stretch*
  — fuller spellings to fill a loose line — was never re-checked, so it could
  overshoot. It needs words long enough that one substitution overruns a 16-em
  column, which is why only Hamlet found it: `historical-pastoral` became
  `hiſtorical-paſtoralle` and the line overhung by one hair space. Habit
  proposes, the measure disposes.
- **Copy names broke past 26 copies.** `(integer->char (+ 65 i))` gave copy 27
  the name `Copy [`, copy 28 `Copy \` — not a legal Windows filename — and copy
  33 `Copy a`, which after `string-downcase` overwrote copy A. Now A…Z, AA, AB…
- **The heap table printed every copy name per forme.** Fine for four copies,
  useless for 1,200: one forme ran to six hundred names and buried the finding
  underneath. Counts now, with the first ten names.

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

### Two further defects the scale exposed

- **`--cancel-rate` was drawn per surviving error, not per leaf**, so its meaning
  changed with the length of the book: 0.15 meant one leaf in eight on a pamphlet
  and 349 of 511 leaves on the Folio, against the real book's one famous cancel.
  A parameter whose meaning depends on the size of its input is not a parameter.
  Now at most one cancel per leaf.
- **The discrimination anchor had rotted.** It was fitted at 0.20 when the folio
  measure was an unsourced 16 ems; correcting the measure to Hinman's 20 put a
  quarter more type on the page and the same eye found a quarter more evidence on
  it. Re-anchored to 0.26 (11.5 types a page against his 11–12). **The quarto
  check no longer passes at the same value** — about 4.3 against Blayney's 5–6 —
  and that is left standing, because his reasoning assumes a quarto page holds
  half a folio page's type-area where ours holds 30%. Tuning until both fit would
  bury the discrepancy that says one of the two measures is still wrong.

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

## 11. Widen the calibration base

Nearly every rate rests on **one pairing**: about 12,000 words of the *Much Ado*
quarto against the Folio set from it. That is a narrow base for the confident
tables the reports print.

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

## Built

Kept short on purpose. Each was argued out at length when it was done; what is
worth carrying forward is the number it produced. The README describes what these
*do*; this is what they *cost to get right*.

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

---

## The rules this project actually runs on

**Every parameter checked against a real book has been wrong**, most by an order of
magnitude, and always in the direction of making the simulation more picturesque
than the truth. Assume the next one is too. *One exception has now appeared —
Moxon's fount weights, §9 — and being the first it deserves more scepticism than
the rule, not less.*

**Read the source before building on a summary of it.** Moxon and Smith sat in
`sources/` and in the README's bibliography while every figure from them arrived
through Gaskell or Blayney. One afternoon with the actual books produced six
roadmap items, one confirmation that a table called invented is accurate to 0.5%,
and one live anachronism in the most foundational module in the program. **A source
you have cited is not a source you have read.**

**A convention with no date on it is dated by whoever wrote it down last.** The
ranging figures were caught because someone asked when tabular figures began. The
space bodies twenty lines below them were not, and they are Jacobi 1890. When a
value arrives as "the standard widths", ask *standard when*.

**A parameter anchored on one example is anchored on that example's end of the
range.** 60,000 sorts was not a guess; it was carefully derived from the
best-documented fount of the period — and from the largest house in London working
in folio, which made every other shop three times richer than it was and suppressed
the shortages that are half the evidence. One good anchor at the wrong end of a
range is more misleading than no anchor, because it looks like diligence.

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
model. The casting off allowed a line for a blank the compositor no longer set.
Three times, one shape.

**A parameter no test exercises and no report counts will be dead without anyone
noticing.** Four so far — `catches-misreading`, the catchword bracketing, the
omission branch, and the crowding devices. Turn-over was wrongly added to that list
and taken off again. To which that episode adds a corollary: **a report that prints
a bare zero cannot distinguish a thing that did not happen from a thing that could
not.** Both look like evidence and only one is.

**A general-purpose instrument reached for where the domain has an exact rule is
the most expensive mistake in this file.** Three forme-order inferences were
built — a weighted bump, spectral seriation, an alternating fit — before anyone
read the man who invented the method. Hinman does not score orders at all: two
formes sharing a type **cannot be adjacent**, and the order is whatever
satisfies every such prohibition, per quire, in 720 enumerable arrangements.
Worse, the measurement recorded here two entries earlier had already found that
rule — "the strongest evidence in the matrix is an absence, and it is absolute
rather than statistical" — and it was buried under a weighting function anyway.
**Having the finding is not the same as using it.** When the literature contains
practitioners, read how they actually proceeded before designing a method for
them.

**Test whether the answer is in the evidence before blaming either the evidence
or the instrument.** Three searches for the forme order all returned chance, and
two rounds of reasoning about *why* were spent before the cheap decisive
experiment was run: score the true order against 2,000 random ones. It was beaten
by none of them at any density, so the signal was there the whole time and every
argument about thin evidence had been about nothing. A permutation test costs
twenty lines and settles what a week of algorithm-tuning cannot.

**An objective that refits its own yardstick cannot identify anything.**
Estimating the offset-profile from the current order and then optimising the
order under that profile rewards any arrangement whose profile is spiky, and the
truth has no special claim on it. The fix is a shape constrained by the mechanism
with two or three parameters, not one free value per offset. Degeneracy of this
kind looks like a search failure and is not one.

**When a result matches the literature's prediction, that is the moment to build
the control.** The first forme-order inference scored a flat 0.15 on quarto,
which is exactly what Blayney says must happen at that evidence density — and it
was the algorithm, proved by giving the analyst twice Hinman's folio density and
watching the score stay at chance. The lessons below already say a historically
plausible symptom is when to check the arithmetic hardest; this is the same rule
for a historically plausible *result*, which is more seductive because it arrives
looking like a finding rather than like a bug. **A method must be shown to work
somewhere before its failure anywhere means anything.**

**An inference can be structurally certain and globally unanchored, and an
accuracy figure will not show it.** The perfecting inference sorts every forme in
the book into the right two classes, every time, and cannot say which class is
which — 30 runs right and 30 backwards, never a mixture. Quoted as "100%" it
sounds like a solved problem; quoted as "one binary fact short of a solved
problem, and that fact is a coin" it is the truth. Ask of any score not only how
often it is right but **what shape its error has**, because a method that fails
wholesale and a method that fails gracefully can print the same percentage.

**A metric that takes the best of several readings has a chance level above a
coin, and it is usually higher than it looks.** Scoring the better of two
directions on eight formes gives 64% for nothing, and on two hundred still 53%.
The floor is computed and printed beside every score rather than assumed.

**Two errors cancelling is this project's characteristic failure.** `proof-rate`
was wrong and variants-per-forme were wrong in the opposite direction, and the
product landed near Hinman's figure by accident for months. Report a rate beside
its components, never alone.

**One seed is not a measurement, and this applies to rates and not only to rare
events.** Word division on one width table ranges from 65 to 113 per thousand lines
across eight seeds — a 74% spread — so a single-seed comparison can produce any
answer you like, in either direction, and it will look like a finding. Two claims
were made that way in one session and both were noise. Before comparing two
versions of anything, run enough seeds to see the variance, and pin whatever is
drawn at random.

**A normalisation that looks neutral can smuggle in the effect you are testing
for.** Substituting a measured width table, I held the unweighted mean over a–z,
which seemed the obvious control. `i` and `s` are 13.5% of the text between them
and both shrank hard, so the frequency-weighted mean fell 2.56% and the text simply
set narrower — I had changed the density while believing I had changed only the
proportions. Ask what a control actually holds constant, and weight it by how often
each thing occurs in the copy rather than by how many kinds there are.

**A mechanism can be right in its rate and wrong in its grain, and the grain is
where the result lives.** `--heap-disorder` always carried an honest disclaimer
about its *value* and was quietly wrong about its *shape* — white noise where
Moxon describes blocks of seventeen sheets. The disclaimer on the number made
the structure look considered. Correcting the shape while leaving the rate alone
did not adjust the heap figures, it **reversed** what they meant: the parameter
governs how many sheets move and has no bearing at all on how far, so a
collation spaced wider than a sheet can travel is blind to the whole range of
it. A number that was read as a small-sample effect for months was a
sampling-interval effect. **Ask what a parameter does not control.**

**The corpus can answer questions about marks, not only about words.** The scribal
rates were guessed from two books for several sessions while 5,287 sat on disk,
because `lexicon.rkt` reads that corpus as a list of *spellings* and a spelling test
cannot vouch for `yᵗ`. True of the lexicon, irrelevant to the corpus, which is text,
and in which every tilde is countable. The tool was built for one question and I
stopped asking it others.

**Verify in both colour schemes.** A page can be correct in every measurement I take
and unusable on the machine it is opened on. The facsimile shipped with a dark-mode
override on `body` and `.leaf` and on nothing else, so on a dark display the
masthead kept its parchment ground while its text turned light — title, lede and
all four tabs at 1.03:1, which is invisible — and the collation diagrams were dark
line-work on a dark ground. Headless renders default to light, so none of it
appeared in any screenshot taken here.
