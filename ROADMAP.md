# Roadmap

Ordered by evidential value rather than by effort. The question asked of each
item is not "would this be interesting?" but **"would this let the program be
wrong in a way we could detect?"** — which is the only thing it has ever been
good for.

---

## 0. Wanted next

Five things were asked for and all five are built; what is left of this
section is what they turned up on the way, and the two places where the
program still cannot check itself.

- [x] **Preliminary signatures.** `imposition.rkt` now carries a `sig-series`:
      `* ** ***`, `* † ‡ §`, `¶ ¶¶`, lower-case `a b c`, the main alphabet,
      and McKerrow's `π` for leaves that carry nothing. A `page-ref` knows
      which series signs it and where it stands in that series; `π` is a
      citation mark only and never reaches the direction line. The house may
      sign from Jaggard's twenty letters (`--jaggard-alphabet`), which doubles
      three gatherings sooner than everyone else's twenty-three.

      The collation formula takes runs rather than a count, so it prints
      `4°: A² B–L⁴` — Blayney's own formula for the First Quarto of *Lear* —
      and `4°: A⁴ a² B–H⁴` for the English habit.

- [x] **Telling what the preliminary matter *is*.** `prelims.rkt`. A closed
      vocabulary of period headings, matched only before the text begins,
      each kind carrying its own confidence: *the epistle dedicatory* at 0.92,
      *the names of the speakers* at 0.60, *the argument* at 0.50 — because
      McKerrow prints two editions of one masque in which the Names are
      preliminary in the first and the head of the text in the second (p. 182).
      Declared copy is obeyed; guessed copy is reported as a guess, with the
      evidence and East's case beside it. It is off by default; `--guess-prelims` turns it on.

      Two caps, and the second was a bug found by running it: a block that
      grows past 2,600 words with no further heading to close it is given back
      to the text, because plain copy gives no signal where the last block
      ends and a table of contents was swallowing a whole book.

- [x] **The title-page, generated.** `titlepage.rkt`, from Blayney's Appendix
      II — about ninety title-page transcripts from one shop, 1604–9. Counted:
      the printer is named on 58 of 81 and abbreviated to initials on 19 of 50;
      `LONDON,` against `AT LONDON` against `Imprinted at London by` runs
      45 : 9 : 6; a shop is given on 40 of 81, half as *and are to be sold at
      his shop in*, half as *dwelling in*, and 15 of the 40 name a sign; and
      about half the dates are set with the figures spaced apart. The address
      belongs to the bookseller, not the printer, except where there is no
      bookseller.

      It is emitted as **copy**, not as a page, so it goes through the same
      compositor as the text and picks up his spelling and his accidents. It
      is set last and bound first, which is what Blayney's note that the *Lear*
      title-page was "the first part of the book to be set" makes awkward and
      what the type accounting has to survive.

- [x] **Printing the preliminaries last.** `book.rkt` now casts off the text
      first, then the front matter, and works the gatherings in printing order
      while binding them in reading order. Whether the Table goes to the back
      is decided by two questions rather than by a rate: is there room in the
      white leaves the text has already left, and does moving it save leaves at
      the front? Both yes and it moves, which is East; either no and it stays,
      which is Tottel. The report says which, and why, in both cases.

- [x] **Folding and gathering, with the binder's errors.** `binding.rkt`.
      Five kinds of fault, all from the sources; the *rate* is an explicit
      parameter (`--binding-error`) with **no authority claimed for it**, and
      the report prints the disclaimer beside every fault it lists. What is
      not invented is the shape: signatures existed "to get them the right way
      up and in the right order" (Gaskell, p. 79), so an unsigned gathering is
      likelier to go in wrong *and* likelier to survive the warehouse's check,
      because the check is the signatures too.

---

### Reading the copy, instead of guessing at it

- [x] **The heading vocabulary was the wrong instrument, and is now off by
      default.** Demonstrated rather than argued: run against Aylett's *Peace
      with her foure Garders* (1622), a real book with a real dedication and a
      real address to the reader, it found **nothing** — because the book opens
      with fourteen lines of dedicatory verse under no heading at all, so the
      walk stopped before it consulted the vocabulary once. And even where it
      works it is period-bound, so it can do nothing with the modern copy
      anyone is likely to upload. It survives behind `--guess-prelims`, marked
      experimental.

- [x] **`import.rkt`: read what the document says about itself.** Markdown
      with YAML front matter, TEI and EEBO-TCP, LaTeX, Word `.docx`, HTML and
      PDF. Three tiers — *declared* (a TEI `type`, a LaTeX `\frontmatter`, a
      Word paragraph style, a Pandoc div), *constructed* (headings become a
      table of contents, metadata becomes a title-page), and *nothing at all*,
      which is what plain text gets and is the honest answer. A file saved
      under the wrong extension is sniffed.

      The payoff is not tidiness. A table of contents built from a document's
      own headings is genuine preliminary matter, set like the rest of it, and
      it is *the* matter McKerrow watched change sides between editions — so
      it goes straight into the migration decision built for East's case.

- [x] **CRLF.** Worth recording because it is the shape of bug this project
      keeps producing: the LaTeX reader split paragraphs on LF LF, a Windows
      file has CR LF CR LF, so the first real `.tex` file arrived as a single
      paragraph, its `\frontmatter` swallowed the whole book, and the run came
      out empty. Every reader now normalises at the door, and every reader has
      a CRLF test — including the five that never had the bug.

---

### What came out of it

- **A paragraph longer than a page was never divided when it began the page.**
      `cast-off` would only split a unit if something was already standing on
      the page, so a two-hundred-line paragraph was cast off as one page of
      thirty-eight. Every book whose copy has a long unbroken paragraph was
      measured wrong by the difference. Found because a generated dedication is
      one paragraph and would not grow past a single leaf however long it was
      made.

- **Gaskell gives the mechanism by which press-variant states correlate
      between copies, and Greg gives the test for it.** Found here, built in
      the round after. pp. 143–4: the sheets are gathered from the tops of the
      heaps in signature order, so "the order of printing may have been echoed,
      either directly or inversely, by the order of gathering" — inversely
      where the sheet was perfected inner forme first, directly where outer.
      A copy is therefore **not** a random draw of corrected and uncorrected
      states but a systematic one, and Greg's consistency condition detects the
      difference: 60/60 runs consistent when the heaps keep their order, 16/60
      when they do not.

- **Half-sheet imposition is modelled, and only for the case that arises.**
      A two-leaf gathering is one forme worked and turned (Gaskell, p. 83),
      which halves the formes and the paper — and `A2` is the commonest
      preliminary arrangement in Blayney's checklist by a wide margin. Blayney
      has stranger ones got by cutting (`12°: A6 B-N12 P6`) and those are not
      attempted.

- **The title-page is charged to the text case, and should not be.** A real
      title-page drew on titling founts kept apart from the body fount;
      `typecase.rkt` keeps one case. The error is about forty words a book, all
      of them large, and it is stated in the code rather than hidden.

---

### Still wanted

- [ ] **What became of the leaves that stayed white.** The program models two
      outlets for the white paper at the end of a book — preliminaries printed
      there and cut out, and cancels printed there — and where neither applies
      it simply shows a blank leaf and says nothing. That is half an answer.
      McKerrow gives the other half in the same breath as the first: "it might
      sometimes have been more convenient to have the two extra leaves as
      **covers or end-papers**", and elsewhere that spare leaves were used "to
      print matter that was to be bound elsewhere in it, such as titles or
      cancels; or even that did not belong to the book at all" (p. 156).

      So a white leaf should be *accounted for* rather than merely displayed:
      pasted down as an endpaper, folded back as a wrapper on a stitched
      pamphlet (McKerrow, p. 123), or genuinely left blank — which really did
      happen, and Bowers is firm that it did: "no blank not interrupting
      continuous text would be torn by the printer for excision." The
      facsimile should say which, the way it now says which leaves were cut
      out. Printing unrelated matter on them is the one option to leave alone:
      McKerrow raises it and calls it "merely a suggestion".

- [ ] **The fount has too few figures, and it is Lear's fault.** The exhaustion
      has now been measured, which was the prerequisite for touching
      `BLANK-FOR-PROOF` at all. In Floyd's *Common Wealth* the arabic figures
      run to *zero*: `1` bill 38 → 0, `2` 33 → 0, `3` 29 → 0, `4` 27 → 0, and
      `&` 38 → 0. That is why 129 face-down placeholders appear in a 48-page
      quarto where Blayney proves one in a whole book (i. 161, at I4v36).

      So the rate was never the first question. `upper-bill` gives each figure
      26–40 sorts, on the rule "the greater of Lear's measured maximum and a
      tenth of Smith's bill". But *Lear* is a play: no numbered chapters, no
      arabic pagination, no marginal citations. Its demand for figures was
      near zero, so its maximum is no evidence about the fount, and Blayney's
      Smith/10 yardstick was a statement about **capitals**, not about figures.
      A book with a two-hundred-entry numbered table of contents cannot be set
      out of that case.

      What to do: find what a real bill gives for figures — Smith's standard
      bill in Gaskell p. 37, and van den Keere's 1571 registre, which Blayney
      prints alongside the Lear column — and set them from that rather than
      from a play. Only then is `BLANK-FOR-PROOF` (0.25, a guess) worth
      looking at.

      The misclassification is fixed: the placeholder now has its own category
      `#sort-wanting` rather than being reported as foul case.

- [ ] **Word division breaks inside consonant clusters.** 23% of the divided
      words in Floyd break somewhere no compositor would break them —
      `Exc-epte`, `conſtr-`, `praecl-`, `ſhipp-`, `omn-`, `Ariſt-`. Moxon and
      McKerrow both have division by syllable, and the rule here appears to
      divide by width alone. 42% break after a single consonant and 35% after
      a vowel, which are the ordinary cases; it is the remaining quarter that
      wants a syllable rule rather than a measurement.

- [ ] **Watermarks and chain-lines.** A can of worms of its own, and the
      evidence that half the rest of this depends on. Every test in McKerrow's
      cancel checklist that this program cannot yet run is a paper test:
      "if the paper appears to be different" (p. 224), and the chain-line
      comparison of a leaf against its conjugate — "if the gatherings are of
      four leaves, compare the first with the fourth, the second with the
      third … Are the chain-lines the same distance apart? If not, one of the
      two leaves must be a cancel."

      It is also how Bowers *proved* the cut-out preliminaries of Sandys's
      Ovid: the two printed leaves "are always disjunct and have any watermark
      on the outer edges of the two leaves, **an impossibility if they had been
      printed as a fold** in the cut-off." The program now records whether a
      cut-out pair was conjugate or disjunct, so the fact the watermark would
      betray is already in the file; what is missing is the paper that would
      betray it.

      Wanted: a paper stock with a mould and a twin, watermarks falling in the
      half-sheet the mould put them in, chain-lines at a spacing per mould, and
      Blayney's own table of watermarks by sheet and copy (Appendix II, no. 56)
      as the thing to reproduce.

- [x] **Correlated press-variant states between copies.** Built, and it turned
      out to be the meeting point of Gaskell and Greg.

      Gaskell (pp. 143-4): the heaps are gathered in signature order from the
      tops of the piles, "in the reverse of the printing order" for a sheet
      perfected inner forme first and "in the printing order" for one perfected
      outer forme first. So the copies lie in one linear order and each
      variant divides that order at the point the corrected proof came back.

      Greg supplies the test. His calculus assumes simple transcription, and
      warns that where "the grouping is throughout random or if inconsistent
      forms are of frequent occurrence ... some sort of conflation has
      somewhere to be assumed" (p. 43). **A made-up copy is conflation by
      construction** — it descends from no other copy but is assembled from as
      many heaps as there are sheets. Drawn independently the groupings cross;
      gathered as Gaskell describes they are prefixes and suffixes of one
      order, hence nested or disjoint, which is exactly Greg's consistency
      condition (p. 12): "either these or their complements are either mutually
      exclusive or one wholly includes the other."

      Measured over 25 runs of ten copies: **60/60 consistent at disorder 0,
      16/60 at disorder 1** — the second being what this program used to do.
      `--heap-disorder` is the knob, and Gaskell gives no value for it; he says
      only that the order was likely but "not certain" to survive the drying.

- [ ] **Recovering the perfecting order from the groupings.** The prize this
      opens. Given a handful of collated copies, the direction of each
      grouping — which end of the gathered order holds the corrected sheets —
      says which forme of that sheet went to press first, and the program knows
      the answer. This is the analysis half's next real exam, and it is not
      built: the report shows the truth beside the groupings rather than
      making the inference and being scored on it.

- [ ] **Greg's calculus as an analysis module.** Type-1 and type-2 variants,
      the compounded variational formula, the resolution of complex variants,
      and the order-of-merit count. Two cautions from him to carry: the
      **ambiguity of three texts** (with three witnesses no formal process can
      establish relationship), and the **fallacy of constant variation** — that
      every transcription introduces about the same number of variants, which
      is "quite contrary to experience and leads to erroneous results" (p. 9n,
      Note C). Also his warning that the finer the collation the more
      non-evidential variants and chance coincidences it turns up (p. 18).

- [ ] **Turner's rule tested against known truth.** Named here so it does not
      get lost again: the program knows which forme was printed first and can
      score any rule that claims to recover it.

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

- [x] **Cannibalization, and the ladder of shifts.** Done. Blayney watches
      compositor B want a `W` with none to be had and work down five rungs:
      set `VV`; rob a page already standing, preferring the margins and speech
      prefixes because "if types are taken from the middle of an undistributed
      page there is a risk that several lines will be pied"; distribute a forme
      early; set an `M` or a ligature **face down** so the foot printed as two
      black rectangles, and insert the right type at proof; buy or borrow more.
      The program had rungs one, three and five.

      Cannibalization is capped at the marginal share of what stands, which is
      the constraint Blayney gives — a standing page is a locked block of metal
      under tension, and only its edges are safe to pull from. The share is a
      judgement; the cap is not, and neither is what happens without it. On
      *Areopagitica* the ladder now reads

      | rung | events |
      |---|---|
      | robbed from a standing page | 226 |
      | wrong-fount sort borrowed | 13 |
      | face down, to be filled at proof | 4 |

      against 248 wrong-fount sorts before, in a book where Okes's own show a
      handful. The face-down placeholder is the one expedient on the ladder
      that makes press-correction *necessary* rather than optional: the forme
      cannot go to press as it stands. Nothing yet acts on that, and it is the
      obvious next thing — see §2.

- [x] **`ſt`, `ſh`, `ſi` as sorts.** Done, and cheaper than it looked. `ſt` at
      200 is Okes's commonest ligature by a wide margin, more than `ﬀ`, `ﬁ` and
      `ﬂ` together; `ſh` is 83 and `ſi` 48. The long-s box could come back from
      the inflated 745 to the 343 Blayney measured.

      The Unicode problem turned out not to be one. Only `ſt` has a character
      (U+FB05); the others get private-use codepoints that never leave the type
      case, because a ligature **prints as its two letters**. The page is
      identical either way. What differs is which box emptied — and a shortage
      of `ſt` is a fact about the fount that shows in the recurrence evidence,
      which is the entire reason to model them.

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

- [x] **Space-metal is type.** Added, and it turns out to be the biggest thing
      the model was missing. A gap in a line is a piece of metal a shade lower
      than the face so that it takes no ink: it is cast, it sits in a box, it
      is picked by hand, it runs out, and it is distributed. The program had
      been treating the spacing as arithmetic, which is the one thing it is
      not — space-metal was the only part of a forme that could never be short.

      Blayney makes it the hinge of the whole *Lear* reconstruction. Okes "had
      not printed a play before … This fact put an unprecedented strain on the
      supplies of numerous sorts", and "what *Lear* used in the quantities most
      unprecedented in the pica books of 1605-7 was **space-metal**."

      No bill of the period tabulates quads, so the quantities come from
      measured demand: a quarto page here runs to 1,311 letters and 253
      word-gaps, so **16% of everything set is white**, and a dozen pages
      standing lock up some three thousand word-spaces. Which gives the figure
      worth stating plainly — **the thick space is as common in a fount as the
      letter e**, and its box has to be about as deep. The fount total rises
      from 21,953 to 31,200 because Blayney's table counts letters, capitals,
      points and ligatures and no quads at all.

      Provisioned from *prose* demand, the play strain then falls out by itself,
      which is the check that matters:

      | | em quad | thick | hair |
      |---|---|---|---|
      | prose (*Areopagitica*) | 8% out | 52% | 80% |
      | drama (*Much Ado*) | **100% out** | 56% | 25% |

      A play empties the em-quad box and prose never touches it, because every
      short speech line is quadded out to the measure. That is Blayney's
      asymmetry, reproduced rather than fitted.

      **The spacing was not quantised, and could not have been set.**
      `apportion` handed out single units of 1/120 em until the arithmetic came
      out — a body no founder ever cast. Measured, **86% of the gaps were
      widths no combination of em, en, thick, middle, thin and hair could
      make**: 43/120 of an em, 41, 47. The lines filled the measure exactly and
      were unsettable. Now every gap is whole pieces, which is Moxon's account
      and is quantised — he sets one space between words, and if the line will
      not fill he "puts a Space more between every Word", and if still not,
      another. The commonest widths are now the ladder itself: thick 7,239,
      hair 2,546, middle 1,869, thin 1,226, en 1,105. A line fills to within
      less than a hair — median 4/120 em — rather than exactly, and that
      residue is real: it was taken up by the pressure of the lock-up.

      The white is in the TEI, named body by body on each `<lb/>`
      (`hp:white="thick-space thick-space hair-space"`), because the file had
      recorded where every word stood and nothing about what held them apart —
      four pieces of type in every five words. One limitation stated rather
      than hidden: those are the bodies the ladder gives for the width, and
      where a box was empty the compositor made the same white out of smaller
      pieces. That substitution is recorded as an event but not yet there.

      On screen the *positions* are exact and the visible gaps are not quite,
      because a real font's glyphs are not the modelled widths — the `--fit`
      problem the stylesheet already documents. The model and the file are
      right; the rendering absorbs the font error into the white.

      Still to do, and both from the same page of Blayney: space-metal was
      shared between founts of the same body ("pica spaces are pica spaces,
      irrespective of fount"), like the points — so it belongs to the house and
      not to the fount, which matters at §3. And the white had to be
      distributed *first*, which "would have left the pages in a condition in
      which they could not have been tied" — the material property of the
      quads decided whether a book's type could be kept standing at all.

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
