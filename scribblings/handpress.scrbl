#lang scribble/manual
@(require scribble/core scriblib/footnote "bib.rkt"
          ;; `placeholder?' is ours and racket/base's both. Excluding it there
          ;; rather than here because the one this manual documents is the piece
          ;; of type set face down to hold a space, not the graph-building
          ;; placeholder — and without the exclusion the document does not build
          ;; at all, which is how it went a while without being built.
          (for-label (except-in racket/base placeholder?) racket/contract
                     handpress/metrics handpress/typecase handpress/orthography
                     handpress/copytext handpress/corrector handpress/compositor
                     handpress/imposition handpress/paper handpress/book
                     handpress/press handpress/render handpress/analysis
                     handpress/lexicon handpress/pagination handpress/deviation))

@title{handpress: a simulation of hand-press composition}

A compositor of the hand-press era, simulated: casting off, spelling habit,
justification, foul case, imposition, skeleton formes, and stop-press
correction. And then the New Bibliography run back over the result, trying to
recover from the printed page what the record says actually happened.

@margin-note{Scribble is itself a typesetting system, which makes documenting
a typesetting simulation in it a small pleasure.}

The modules, in dependency order. They are declared here rather than merely
named, because @racket[declare-exporting] attaches bindings to a module without
defining the module itself — so every module link in this manual dangled, and
@tt{raco setup} had been saying so.

@defmodule*/no-declare[(handpress/metrics
                        handpress/paper
                        handpress/typecase
                        handpress/orthography
                        handpress/copytext
                        handpress/corrector
                        handpress/compositor
                        handpress/imposition
                        handpress/prelims
                        handpress/titlepage
                        handpress/book
                        handpress/press
                        handpress/cancels
                        handpress/binding
                        handpress/render
                        handpress/description
                        handpress/tei
                        handpress/analysis
                        handpress/validate
                        handpress/lexicon
                        handpress/reconstruct)]

@table-of-contents[]

@section{Using it}

@verbatim|{
racket main.rkt --format quarto --compositors A,B --html -o out samples/hamlet.txt
}|

Flags come @emph{before} the input file, as Racket's
@racket[command-line] requires.

@tabular[#:sep @hspace[2]
  (list (list @bold{flag} @bold{effect})
        (list @bold{The book} "")
        (list @elem{@tt{-o}, @tt{--out}} "directory for the output files")
        (list @tt{--format} "folio | folio6 | quarto | octavo — how often the sheet is folded")
        (list @tt{--paper} "the sheet itself: foolscap | pot | crown | demy | royal")
        (list @tt{--kind} "auto | verse | prose | drama — how the copy is parsed")
        (list @tt{--title} "running title")
        (list @tt{--edition} "sheets printed; the Cambridge accounts show 400–820")
        (list @tt{--copies} "made-up copies to collate for press variants")
        (list @bold{The workmen} "")
        (list @tt{--compositors} "which men are at the frames, e.g. A,B or OkesB,OkesC")
        (list @tt{--order} "formes | seriatim")
        (list @tt{--cast-off} "accuracy of the casting off, 0–1")
        (list @tt{--no-copy-preparation} "the corrector does not mark up the copy")
        (list @bold{The material} "")
        (list @tt{--case-scale} "below 1.0 the case runs short; try 0.18")
        (list @tt{--fount} "condition of the type: new | used | worn | foul")
        (list @tt{--skeletons} "skeleton formes in use")
        (list @tt{--formes-standing} "formes of type standing before distribution")
        (list @bold{At press} "")
        (list @tt{--first-proof} "chance of a proof pulled before the run begins")
        (list @tt{--seed} "the whole run is deterministic in this")
        (list @bold{Output} "")
        (list @tt{--html} "an HTML facsimile built straight from the type")
        (list @tt{--tei} "a TEI P5 encoding")
        (list @tt{--xslt} "write the TEI and transform it to HTML")
        (list @tt{--layout} "opening (verso | recto, as bound) or leaf")
        (list @tt{--witness} "which made-up copy the XSLT should show")
        (list @tt{--numbers} "number every fifth line of type")
        (list @tt{--no-long-s} "set short s throughout")
        (list @tt{--font} "family the facsimile is drawn in, e.g. Junicode")
        (list @tt{--font-file} "a fount to embed beside the page (.woff2/.ttf/.otf)")
        (list @tt{--fit} "set width of that face against the body; re-derive it when the face changes")
        (list @tt{--modern-uv} "keep modern u/v and i/j")
        (list @tt{--year} "the date, which governs the scribal marks — they have a slope")
        (list @elem{@tt{--pages}, @tt{--quiet}} "how much to print to the terminal"))]

Every run writes @tt{NAME.facsimile.txt} (the type-facsimile) and
@tt{NAME.report.txt} (the description and the analysis); the output flags add
@tt{NAME.html}, @tt{NAME.tei.xml} and @tt{NAME.tei.html}.

Run the tests with @tt{raco test *.rkt}. Build this document with
@tt{raco scribble --html --dest doc scribblings/handpress.scrbl}.

@section{What is modelled}

@subsection{Casting off}
@declare-exporting[handpress/imposition]

A house setting by formes must know in advance where the copy for each page
begins, so the copy is measured out beforehand — by counting words and
computing, not by eye. Verse casts off almost exactly; prose is much harder,
so the strain falls where the prose is. What makes the practice workable at
all is that early spelling is @emph{elastic}: ``In the days when abbreviations
were to some extent optional copy was to some extent elastic'' (Harry Carter).

@bold{The error has to run both ways.} This closed a segment whenever the next
unit would carry the estimate past the page, so a page was never allotted more
copy than it held and every error ran short. Measured across the samples, every
page came out spun out or exact and none was crowded.

That is not a small inaccuracy. It silently disabled three separate mechanisms
downstream: the branch that drops copy for want of room, the report's count of
dropped lines, and the catchword mismatch — each of which then looked like
working code that simply never fired.

The man marking up the copy judges by eye how much manuscript makes a page,
and when the surplus looks small he commits it and is sometimes wrong. So a
unit that overruns may still be taken in, with a probability that falls away as
the surplus grows: a line over is easily missed, and the rare four- or
five-line misjudgement is what actually costs text, because there is not that
much white on the page to take out. He is wrong oftener with prose than with
verse, which is Gaskell's point and the reason @tt{slip} exists.

@defproc[(cast-off [units (listof copy-unit?)] [measure exact-integer?]
                   [lines-per-page exact-integer?] [g pseudo-random-generator?]
                   [accuracy real? 0.93])
         (listof cast-off-segment?)]{
Measures the copy out into pages, imperfectly, and in both directions.
@racket[accuracy] scales the difficulty; it does not level it, since the kind
of copy matters more than the skill of the man.

On the @emph{Much Ado} prose at the default accuracy this now gives twelve
crowded pages against twelve spun out. Dropped copy stays rare — the crowding
devices absorb most of the strain, which is what they are for — but it happens,
and when it does the catchword left facing the gap no longer answers.}

@subsection{Justification}
@declare-exporting[handpress/compositor]

Nothing in a line of type is elastic. The line must fill the measure exactly,
so a compositor short of room strikes off a terminal @tt{-e}, sets @tt{&} for
@emph{and}, @tt{yᵉ} for @emph{the}, puts a stroke over a vowel to stand for a
following nasal (@tt{thē}), reduces a doubled consonant, abbreviates the
speech prefix, and — if he is that sort of man — runs verse together as prose.
A compositor with room to spare does the reverse.

The asymmetry is historical: the period's default was the fuller spelling, so
there was always more room to expand than to contract. This is why crowded
pages abbreviate visibly while gaping pages merely look generous.

@defproc[(set-prose [c comp?] [text string?] [spec page-spec?] [pressure real?]
                    [#:first-indent? first-indent? boolean? #t]
                    [#:lead lead (listof word?) '()])
         (listof set-line?)]{
Fills the stick line by line. The compositor fills greedily and then asks
whether one more word might be pinched in; he finds out by trying it, and if
the trial will not lift he keeps the other line.}

@defproc[(make-line [ws (listof word?)] [spaces (listof exact-integer?)]
                    [indent exact-nonnegative-integer?]
                    [measure exact-positive-integer?] [kind symbol?]
                    [#:justification justification string? ""]
                    [#:turned-over? turned-over? boolean? #f]
                    [#:quadded? quadded? boolean? #f]
                    [#:italic? italic? boolean? #f])
         set-line?]{
Builds a line of type, and refuses to build one wider than the measure. This
is the one physical law in the program: a line that overhangs cannot be locked
up in a chase, so it must not be constructible. In the Python original the
same property was a test run afterwards; here it is checked at every
construction.}

@subsection{Spelling habit}
@declare-exporting[handpress/orthography]

@tabular[#:sep @hspace[3]
  (list (list @bold{} @bold{Compositor A} @bold{Compositor B})
        (list "" @tt{doe, goe, here} @tt{do, go, heere})
        (list "" @tt{griefe, grieue} @tt{greefe, greeue})
        (list "" @tt{Traytor, young} @tt{Traitor, yong}))]

These are the discriminants Thomas Satchell isolated in @emph{Macbeth} in 1920,
which Willoughby extended and Hinman built the Folio's stints upon. The split
is @emph{crossed}, not full forms against short ones: A is the @tt{doe}/@tt{goe}
man but the @tt{here} man. A workman who merely spelt fully would be
undetectable, because justification alone would produce that.

Okes's men, from Blayney's @emph{Texts of King Lear}, are in the same table:
B sets @tt{-our} where C sets @tt{-or} (``the spellings `conquerour' and
`labour' … strongly support … compositor B'', i. 159), and C ``refused five
opportunities to use an apostrophe'' that B would have taken.

@defthing[SPELLING-TESTS hash?]{
Maps a head-word to a hash of compositor name → preferred form. Plain data,
meant to be edited.}

Habit strength is a per-word table rather than a single number, because one
number cannot hold Hinman's own figures: in quire L, A sets @tt{doe}/@tt{goe}
81 per cent of the time but @tt{here} only 50 per cent. A scalar strong enough
for the first is far too strong for the second.

@subsection{The elided ending}
@declare-exporting[handpress/orthography]

@tt{rul'd} for @emph{ruled} — the contraction the English trade actually used,
and the one this program was longest without. Across five scenes of
@emph{Much Ado} the Folio has 114 medial apostrophes against the quarto's 14,
turning some thirty @tt{-ed} endings into @tt{-'d}. R. G. White noticed the
practice without counting it: the Folio is ``carefully printed for the day,
even as to punctuation, contracted syllables, and capital letters'' (Furness,
@emph{Variorum}, p. 293).

It does not elide after @tt{t} or @tt{d}, where the ending is a syllable that
must be sounded: @emph{wanted} and @emph{ended} keep their @tt{-ed}.

The instructive part is where it belongs. Put among the justification devices,
it fired only when a line needed squeezing, and produced 15 apostrophes where
the Folio has 114. It is a @emph{habit} before it is ever a convenience, so it
sits with spelling preference, and Okes's C is the one workman who declines
it. Because A, B and Okes's B all elide, the form is no evidence of which of
them set a page, and @racket[pattern-witness] excludes it from attribution: a
form several workmen would all have set testifies to none of them.

@defproc[(pattern-witness [word string?]) (values (or/c string? #f) (or/c string? #f))]{
Returns the rule and the compositor whose habit a form testifies to, for the
pattern tests (@tt{-ie}/@tt{-y}, @tt{-ll}/@tt{-l}). These are an extrapolation
from Satchell's list rather than something Hinman demonstrates; treat them as
a device for making the simulation legible at short lengths.}

@subsection{Stints, and how the frame changes hands}
@declare-exporting[handpress/book]

This program used to change compositors every forme — a tidy alternation, and
the one shop whose records survive contradicts it flatly. McKenzie, from the
Cambridge Vouchers: when two or more men worked on a book ``they did not work
together setting sheet and sheet about. What usually happened was that one took
over where the other left off and then composed as many sheets as the master
found convenient or as other commitments allowed'' (i. 107).

His quarto Virgil shows the shape. Bertram set A–E; Crownfield F–3G; Michaelis
3H–3Z; Bertram resumed to 4F; Délié set the single sheet 4G; Crownfield took
over at 4H; and Bertram finished the book after Crownfield retired at 4O. Four
men, long blocks, one man returning three times, and the odd single sheet
dropped in where somebody was briefly free.

@racket[make-house] therefore takes @racket[#:stint-sheets], the mean length of
a stint in sheets, and builds a plan of contiguous blocks with a single sheet
about one time in six. The next man is whoever is free rather than the next in
rotation.

Left unset it follows the size of the shop, which is Gaskell's rule (p. 41) and
the thing that reconciles the authorities. Where there were ``no more than two
or three'' compositors the tendency was for a man to concentrate on particular
books ``and to set at least whole sheets or whole formes'' — McKenzie's
Cambridge, and long stints. Where there were more, copy went out in small
``takings'' or ``takes'' ``to whoever was ready for them'', so that ``the
setting of sheets, formes, and even individual pages were on occasion shared''.
A large house genuinely does approach the rapid alternation this program used
to do unconditionally; the mistake was doing it for every house.

@margin-note{Honesty about the demonstration: the rule is implemented and the
block structure does change shape with the shop — a two-man house opens with a
twelve-page block where a five-man house sets even blocks of four. But on the
24 pages of the @emph{Much Ado} sample the number of changes of hand comes out
much the same either way, so this is an evidenced parameter rather than a
measured effect.}

The consequence for attribution is the uncomfortable part. Those boundaries
fall where the shop's @emph{other} commitments put them, so — as McKenzie
says — ``the compositorial pattern within any such book will rarely have any
internal significance''. It records the house's other work, not anything about
the book being analysed.

@margin-note{The nuance that partly rescues the method: the shop is chaotic,
but a single book's composition is usually ``a simple matter of progression
from sheet to sheet by consecutive compositors''. Stints are blocks, and blocks
are findable.}

@subsection{The compositor's freedom with his copy}
@declare-exporting[handpress/orthography]

The expansion and contraction devices are not an inference. The manuscript copy
for two Cambridge books survives beside the printed sheets, and Knell can be
watched expanding @tt{q} to @tt{que}, @tt{fut:} to @tt{futuro}, @tt{salib:} to
@tt{salibus}, @tt{p} to @tt{per}, @tt{Gram:} to @tt{Grammat:} — and contracting
@tt{et} to @tt{&} (i. 118). McKenzie's conclusion is that ``a compositor was
evidently not only free to expand or contract forms in his copy but that
authors probably relied upon him to do so.''

That is direct archival warrant for the ampersand device and for the whole
expand/contract ladder, from a shop that kept its records.

@subsection{Space-metal, and why justification is quantised}

A gap between two words is a piece of type: a body cast a shade lower than the
face so that it takes no ink. Em quad, en quad, thick, middle, thin, hair.
They are picked from boxes, they run out, and they are distributed with
everything else.

Two figures make the case for taking them seriously. A quarto page here holds
1,311 letters and 253 word-gaps, so @bold{16% of everything set is white}; and
the thick space, the normal word space of the house, is as common in a fount as
the letter @tt{e} and needs a box about as deep.

The consequence is that justification is @emph{quantised}. A compositor cannot
make a gap of any width he likes; he can only set combinations of the bodies he
has. This program spent a long time dividing the white by handing out single
units of 1/120 em until the arithmetic came out — a body no founder ever cast —
with the result that 86% of its gaps were widths no combination of real spaces
could make. What a compositor does is @citet[moxon]'s account, and it is
stepped: he sets with one space between words, and if the line will not fill he
``puts a Space more between every Word'', and if still not, another. So a line
fills the measure to within less than a hair rather than exactly, and that
residue is real — it was taken up by the pressure of the lock-up.

@citet[blayney] makes space-metal the hinge of his whole reconstruction. Okes
had never printed a play before @emph{Lear}, and ``what @emph{Lear} used in the
quantities most unprecedented in the pica books of 1605-7 was space-metal''. A
play is short lines, quadded-out ends and marginal prefixes: it eats quads
where prose eats letters. The program reproduces the asymmetry without being
told to — provisioned from prose demand, @emph{Areopagitica} never empties the
em-quad box and @emph{Much Ado} empties it outright.

@subsection{The lay of the case}
@declare-exporting[handpress/typecase]

The English divided lay, after Gaskell's fig. 23 (reproducing Smith's
@emph{Printer's Grammar}, 1755). The essential thing is that the lower case is
@emph{divided}: two blocks with a gap between them, and no hand strays across
the division. So @tt{n} adjoins @tt{h} and @tt{m}, @tt{i} adjoins the long
@tt{ſ}, @tt{p} adjoins @tt{q} — but @tt{e} and @tt{i} are not neighbours,
though a single undivided grid would make them so.

@defthing[ADJACENT hash?]{Sort → the sorts in the boxes touching it.}

@defproc[(pick! [tc tcase?] [ch char?] [#:careless careless real? 1.0]) draw?]{
Takes one sort from the case, with all that may go wrong: foul case, a turned
letter, a shift for a wanting sort (@tt{VV} for @tt{W}), or a wrong-fount sort
borrowed from another case.}

@subsection{Damaged and worn type}
@declare-exporting[handpress/typecase]

Type wears. A fount bought new is clean; one that has printed twenty books has
sorts with broken serifs, battered shoulders, split hairlines, and these
injuries are peculiar to the individual piece of metal. That is what makes
Hinman's method possible: a particular damaged @tt{e} recurring in two formes
proves they were set from the same case within one distribution cycle.

So the pieces are tracked individually. @racket[sort-piece] carries an
identifier and its own damage, drawn from a vocabulary keyed to letter
anatomy — a serif can break on a letter that has serifs, a bowl can fill on a
letter that has a bowl.

@defthing[CONDITIONS hash?]{
The proportion of the fount that is distinctive: @racket['new] .002,
@racket['used] .010, @racket['worn] .030, @racket['foul] .070. Selected with
@tt{--fount}. A shop's founts differed, and a country house working a fount
sold on from London is a different thing from Jaggard buying new.}

@defproc[(batter! [tc tcase?] [n exact-integer?]) void?]{
Damages @racket[n] sound sorts. Called each time a forme is printed off,
because type is injured at press as well as in the case — which is why Hinman
could date some formes by the @emph{first} appearance of a particular injury.}

@subsection{Imposition and the skeleton forme}
@declare-exporting[handpress/imposition]

Pages are printed several to a sheet, in formes. The running titles and
furniture are not reset for each forme; the assembled skeleton is lifted from
a printed-off forme and re-used, each running title carrying its own
accumulating damage. A broken letter recurring at intervals therefore tells
you which skeleton was used when — Hinman's method.

The pages of a forme are not consecutive, and this is the fact from which most
of the rest follows. A folio in sixes is three sheets quired one within
another, so the outermost sheet carries the outermost pages (McKerrow,
@emph{Introduction}, ch. ii):

@verbatim|{
sheet 1   outer forme (1 12)   inner forme (2 11)
sheet 2   outer forme (3 10)   inner forme (4  9)
sheet 3   outer forme (5  8)   inner forme (6  7)
}|

The general rule, which the tests assert for every format rather than for
these cases only: on any sheet of a quired gathering a page's fellow in the
forme is @math{(pages + 1) - p}. For a folio in sixes that is 13 − 1 = 12.

@defproc[(sheet-scheme [f book-format?]) (listof (cons/c (listof exact-integer?)
                                                          (listof exact-integer?)))]{
Page numbers on the outer and inner forme of each sheet.}

@defproc[(setting-order [f book-format?] [gathering exact-integer?]
                        [by-formes? boolean?])
         (listof exact-integer?)]{
The order in which the pages of a gathering are actually composed. Set
seriatim they go 1, 2, 3…; set by formes the house begins at the middle of the
gathering and works outward: 5, 8, 6, 7, 3, 10, 4, 9, 1, 12, 2, 11.}

@subsection{The sheet, and the size it makes}
@declare-exporting[handpress/paper]

@bold{Format is how often the sheet was folded. Size is how big the sheet was.}
Neither gives a leaf a dimension on its own, and ``quarto'' says nothing whatever
about how big the book is. For most of this program's life only the first was
modelled, so a leaf had no dimensions at all and the stylesheet was left to
invent them — it drew a quarto at 1.99 tall to wide where Gaskell's own figures
give 1.31.

A fold halves whichever dimension is currently the longer, and the leaf is the
result stood upright. That one rule is the whole relationship between format and
size, and it reproduces Gaskell's Key III (p. 86) exactly for pot, demy and
royal in every format, which is what the test submodule asserts. From a foolscap
sheet of 420 × 320 mm:

@tabular[#:sep @hspace[2]
  (list (list @bold{format} @bold{folds} @bold{uncut leaf} @bold{tall : wide})
        (list "folio"  "1" "320 × 210 mm" "1.52")
        (list "quarto" "2" "210 × 160 mm" "1.31")
        (list "octavo" "3" "160 × 105 mm" "1.52"))]

The proportion @emph{alternates} rather than settling. A folio and an octavo are
nearly the same shape and nothing like the same size; only the quarto is squat.

Foolscap is the default because Gaskell (p. 68) has the sixteenth century's
ordinary printing paper in that range, growing to demy by the eighteenth.
@tt{--paper} selects among foolscap, pot, crown, demy and royal; each carries a
note recording where its figure comes from, because a sheet size is a citation
and not a constant — the same name meant different paper in different countries
and centuries, which is the whole difficulty of Gaskell's Table 3.

@defproc[(paper-leaf [p paper?] [folds exact-nonnegative-integer?])
         (values real? real?)]{
The uncut leaf in millimetres, height first, after @racket[folds] folds. Kept in
exact rationals so that three folds of an odd sheet do not accumulate the error
that halving to 0.5 mm at each step would.}

@defproc[(leaf-layout [leaf-h real?] [leaf-w real?] [type-h real?] [type-w real?]
                      [canon (listof real?) MARGIN-CANON])
         layout?]{
Places the type page on the leaf. The margins are what is left over, split
inner : head : outer : tail. @racket[layout-fits?] is @racket[#f] when the type
page is simply larger than the paper — a measure or a line count no sheet of
that size could carry — which is reported rather than clamped away.}

@racket[MARGIN-CANON] is @racket['(2 3 4 6)]. The type page does not sit in the
middle of the leaf: it sits toward the inner and upper corner, so that the two
type pages of an opening read as one block and the tail carries the weight. This
is the one number in the module Gaskell does not supply — a convention and not a
measurement, and a parameter for that reason.

It is also where a finding sits that has @emph{not} been tuned away. The canon
only yields those proportions when the type page shares the leaf's shape, and
ours does not: on foolscap the quarto's type page is 160 × 89 mm, a ratio of
1.80, on a leaf of 1.31. So the outer margins come out wider than the head and
tail, which is the wrong way round for a hand-press book. Either the measure is
too narrow for the paper or the stock is wrong for these books, and Blayney's
Okes quartos are where to settle it.

Watermarks, countermarks and chain-lines are @bold{not} modelled. Note before
adding them that in this period the mark will not give the size: Gaskell lists
the sixteenth-century foolscap group as carrying the Strasbourg lily, the pot and
the grapes indifferently, and warns (p. 68) that the marks ``were not used
exclusively for particular sizes, especially during the sixteenth century''.

@subsection{Standing type, and what a gathering costs in metal}
@declare-exporting[handpress/book]

Nothing can be printed until both pages of a forme stand in type, and type
that stands cannot be distributed back into the case. So the order of setting
has a price, and the program counts it. Setting the same play both ways:

@tabular[#:sep @hspace[3]
  (list (list @bold{} @bold{by formes} @bold{seriatim})
        (list "most type standing at once" "16,878 sorts" "27,746 sorts")
        (list "pages standing at the peak" "6" "11")
        (list "cases at their emptiest" "29% out" "46% out")
        (list @tt{e} "fell to 2,888 of 5,362" "fell to 1,452")
        (list @tt{B} "fell to 111 of 224" "fell to 35"))]

A house setting straight through the copy cannot perfect the first sheet until
page 12 is set, so eleven pages stand locked up and the case runs to 46 per
cent empty. A house that casts off and sets by formes can print each sheet and
return it to the boxes before beginning the next.

@bold{But that is a calculation, not a motive, and the archives do not support
turning it into one.} McKenzie went through the Cambridge Vouchers looking for
exactly this practice and concluded that setting by formes ``was followed
occasionally but was certainly @emph{not} normal'' (@emph{Cambridge University
Press}, i. 115). Worse for the economic story, where work @emph{was} shared he
found the likely reason was the opposite of the one modelled here: ``the
principal reason for the shared setting was not to make more economical use of
a limited supply of type but to find work for a waiting compositor'' (i. 116).
Labour scheduling, not metal.

@bold{But Hinman argues the opposite, for the Folio, and he is not guessing
either.} His case is that Jaggard simply did not own enough type: ``shortage
of type may have rendered it impracticable to set the book in the conventional
way. If so, the size of the supply was one of the factors which made the
alternative method desirable'' — setting by formes needing ``only enough type
to set four pages''.

So the two authorities disagree, and the disagreement is not a muddle. They
are describing different shops fifty years apart: a London trade house
printing an unusually large folio against its type stock, and a university
press with time on its hands and men to keep busy. Economy of type can be
decisive in one and irrelevant in the other. What cannot be done is to take
either as a general law of the hand press, which is what this program's
documentation was doing.

So the table above says what setting by formes would have saved a house that
did it. Whether any given house did it for that reason is a question about
that house. Hinman's evidence
that the Folio @emph{was} set by formes is separate and stands on its own
footing — it rests on type recurrence, not on economy — and McKenzie names
that same test as the one that would have settled his own question: ``One
distinctive sort appearing in both formes of a sheet would of course outweigh
all the ambiguous testimony of the Vouchers, for it would prove conclusively
that one forme could not have been set until type from the other had been
distributed.'' At Cambridge the evidence was lacking. In the Folio it was not.

This program tracks the distinctive sorts that would constitute that evidence
but does not yet reconstruct forme order from them. Until it does, the
standing-type figures are arithmetic about a practice, not proof of one.

Capital @tt{B} is the sort under most strain in @emph{Much Ado} either way —
Beatrice, Benedicke, Balthasar, Borachio against a bill of 224. That is the
kind of pressure that produces a substitution.

@margin-note{The sorts figure counts every piece in a standing page, spaces
and quads included, so it is a type-body count rather than a letter count:
comparable between runs, but not directly against a founder's bill in pounds
weight.}

@defstruct*[standing-type ([peak-sorts exact-integer?]
                           [peak-pages exact-integer?]
                           [ledger list?]
                           [by-formes? boolean?])]{
The high-water mark of standing type and the page-by-page ledger behind it,
carried on the @racket[book].}

@defproc[(case-depletion [tc tcase?])
         (listof (list/c char? exact-integer? exact-integer? real?))]{
Per sort: the bill it started with, the fewest ever left in the box, and the
proportion out at the worst moment.}

@subsection{Catchwords, and why they can disagree}
@declare-exporting[handpress/book]

The catchword is taken from the @emph{copy}, not from the next page. The
compositor finished a page, looked at his manuscript for the word that came
next, and set it in the direction line — before the next page existed.

McKerrow's proof is the mismatches: we find ``a correct catchword in cases
where the opening words of the next page are wrong, owing to the compositor
having mistaken the point at which he left off and consequently omitted or
repeated a word or two. The catchword must therefore have been taken from the
MS.'' Hence his editorial rule — where a catchword disagrees with the page it
faces, ``the reading of the former may well be given the preference, for it was
the earlier set up''. The catchword can be the better witness to the copy than
the text it points at.

This program took the catchword from the next page's first printed word, which
guarantees the two always agree. @racket[add-catchwords] now prefers the copy
reading where the following page dropped any.

This was inert until the casting off was made to err in both directions (see
@secref["Casting_off"]). With that repaired the diagnostic appears where it
should — at @tt{--cast-off 0.6} on the @emph{Much Ado} prose, @tt{E4r} catches
@tt{but} from the copy while @tt{E4v} opens @tt{Change}, because five lines
went missing between them.

@subsection{Signatures, and who puts them there}
@declare-exporting[handpress/book]

Signing is the compositor's act, not the imposer's. McKerrow finds the
Elizabethan men ``normally finished a page of work at a time, adding catchword
and signature (if necessary) before proceeding to the next one'', rather than
setting long columns and dividing them into pages afterwards. So the signature
in the direction line is put there by whoever set the page.

And the number of leaves signed was that man's own habit. McKerrow: ``there
cannot be said to have been in early times any definite practice ... we may
have anything from the first two to every leaf.'' Hinman saw the same at
Jaggard's, where in a quarto one man might sign the first two leaves and
another the first three.

This program used to sign half the leaves of every gathering, uniformly,
because the format said so. Now each workman has his own count. Set one man to
work and the book is regular; set five and it is not:

@verbatim|{
  [A]          Signed: first 3 leaf/leaves of each gathering, recto
  [A,B,C,D,E]  Signed: first 2 to 3 leaves, recto; irregular, the men
                       differing in the habit
}|

@margin-note{Which man signed how many, neither source says. Assigning
particular counts to Hinman's A and B would manufacture exactly the kind of
evidence this program exists to test, so the count is drawn per workman from
the run's seed. The phenomenon is attested; the attribution is not.}

Both the Bowers signing statement and the summary in the report now count what
the sheets actually show rather than asserting the format's rule, which is what
a descriptive bibliographer does and what this program was not doing.

@subsection{The preliminaries, and why they have a series of their own}
@declare-exporting[handpress/prelims]

The front matter was printed @emph{last} and bound @emph{first}, and everything
else about it follows. Gaskell: ``the preliminaries were not included in the
main signature series of new books because it was usual to print them last;
reprints, however, sometimes began the main signature series at the beginning
of the preliminaries'' (p. 8). McKerrow from the shop floor: ``in composing a
new book from MS the normal course was to begin at the beginning of the text
and proceed straight on to the end, setting up the title-page and preliminaries
last'' (p. 128). A compositor who has already signed his text A to L cannot
give the front matter letters without collision, so he gives it a series of its
own — and Gaskell's exception proves it, because in a reprint the extent is
known in advance and the separate series is not needed.

The forms, in Gaskell's order of frequency (p. 52), are all in
@racket[imposition]: @tt{*  **  ***}; the symbols @tt{*  †  ‡  §} ``without
logical order''; the main series from A with the preliminaries @tt{a b c},
``always quite common''; and the main series from @bold{B} with the
preliminaries signed A, ``a characteristically English habit … to allow for a
sheet of preliminaries signed A''. Leaves that carry nothing at all are cited
as McKerrow's @tt{π} (p. 156), ``easily recalled by the p of `preliminary''',
which is a citation mark only and never reaches the direction line.

@margin-note{Gaskell gives the order and no numbers, and neither does McKerrow.
@racket[PRELIM-SCHEMES] weights them, and the weights are a guess at a
distribution whose ordering alone is attested. Nothing in this program should
be read as evidence for them.}

A short preliminary gathering is half a sheet, worked and turned: ``all the
pages for a half sheet were imposed in one forme; this forme was first printed
on one side of the whole sheet, then the heap of paper was turned … and printed
from the same forme on the other side'' (Gaskell, p. 83). One forme, not two,
and one pull per two copies — which is why @tt{A2} is the commonest preliminary
arrangement in Blayney's checklist by a wide margin.

The overflow is the interesting case, and McKerrow reads it the way this
program generates it. Of two editions of the Masque of the Gentlemen of Gray's
Inn, the first collating @tt{?, A4, a4, B–E4, F2}, he says that ``even from the
make-up alone we might guess that Ed. 1 is the earlier, for the work itself
begins on B1 and this is preceded by A and a, @bold{the latter signature
strongly suggesting that the preliminary matter was more than the printer had
expected and allowed for}'' (p. 182). The second series is not a style. It is a
misjudgement made visible — the house allowed one sheet signed A and the front
matter would not go in it — and because the program knows whether the overflow
happened, the inference can be scored.

@subsection{Telling what the preliminary matter is}
@declare-exporting[handpress/prelims]

The hard part is not the signing. Both authorities agree the question has no
answer in the text: @bold{the boundary is a printer's decision, not a property
of the copy}. McKerrow has the case. Tottel's 1575 @italic{Treatise of Moral
Philosophy} puts its Table among the preliminaries; East reprinting it in 1584
began the text at C1 in imitation, ``then found he had room for the Table in
the last gathering of the book and placed it there, with the result that his
preliminaries now only'' half filled a gathering (p. 78). The same matter, in
the same words, is preliminary in one edition and terminal in the next, and the
reason is how much room happened to be left.

So @racket[divide-copy] guesses, says that it is guessing, gives its evidence,
and can be overruled. Marked-up copy is believed. Plain copy is matched against
a closed vocabulary of period headings — the list is McKerrow's ``the title,
dedication, preface, and, if there is one, list of contents'' (p. 25) — and
only where the heading stands before the text begins, because every one of
those phrases occurs inside texts as well.

The confidences are not flat, and the differences are the point. @italic{The
epistle dedicatory} can hardly be anything else and scores 0.92. @italic{The
names of the speakers} scores 0.60, because McKerrow prints two editions of one
masque in which it is preliminary in the first and the head of the text in the
second. @italic{The argument} scores 0.50, because it heads a preface in one
book and every act of a play in another. A flat confidence would hide exactly
the cases worth doubting.

Two caps, and the second was found by running it rather than by thinking:

@itemlist[
@item{A walk that meets a heading outside the vocabulary stops there, which is
      what keeps a play whose acts are each called ``The Argument'' from being
      read as its own front matter.}
@item{A block that grows past 2,600 words with no further heading to close it
      is @emph{abandoned whole} and given back to the text. Plain copy gives no
      signal where the last block ends, so before this a table of contents ran
      on to the end of the book. Cutting it short instead would have put half a
      table among the preliminaries and half at the head of the text; the block
      boundary is the one thing the copy really tells us, and the extent is only
      a bound taken from what front matter is like elsewhere.}]

Whether the Table then goes to the back is decided by arithmetic on two
make-ups rather than by a rate: is there room in the white leaves the text has
already left, and does moving it save leaves at the front? Both yes and it
moves, which is East; either no and it stays, which is Tottel. The report says
which, and why, in both cases — because ``nothing moved'' and ``there was
nothing that could move'' are different facts about a book.

@subsection{The title-page}
@declare-exporting[handpress/titlepage]

Supplied by hand, a title-page would be a cheat at the most formulaic thing a
hand-press book contains, and formulae can be measured. Blayney's Appendix II
is a checklist of about ninety books from one London shop between 1604 and
1609, each with a substantive transcript. Counted over those transcripts:

@tabular[#:sep @hspace[2]
  (list (list @bold{element} @bold{observed})
        (list "the printer is named" "58 of 81")
        (list "… abbreviated to initials" "19 of 50")
        (list @tt{LONDON,} "45 of 60")
        (list @tt{AT LONDON} "9 of 60")
        (list @tt{Imprinted at London by} "6 of 60")
        (list "a shop is given" "40 of 81")
        (list "… as “and are to be sold at his shop in”" "20 of 40")
        (list "… as “dwelling in”" "20 of 40")
        (list "… naming a sign" "15 of 40")
        (list "the date set with figures spaced apart" "about half"))]

Two things the transcripts settle that guesswork gets wrong. The address is the
@emph{bookseller's}, not the printer's — ``Printed by N. O. for Roger Iackson,
dwelling in Fleetstreet neere to the Conduit'' is Jackson's shop — and it
belongs to the printer only where there is no bookseller to own it. And
``dwelling in'' and ``and are to be sold at his shop in'' are two ways of
saying the same thing, which is why they come out twenty and twenty.

The date is quadded: the last line of an imprint is short and the figures were
spread to fill it, which is why about half of them read @tt{1 6 0 8.} rather
than @tt{1608.} The spaces are metal, and this program charges for them.

The page is handed back as @bold{copy}, not as a page, for two reasons. It must
go through the same compositor as everything else, so that its spelling, its
long s and its accidents are his rather than the program's; and it must be
settable at a moment of the run's choosing, because Blayney found the
@italic{Lear} title-page was ``the first part of the book to be set'' and then
distributed. Set first, printed last: the awkward case for the type accounting.

@margin-note{The type is charged to the text case, which is wrong and is
reported as wrong. A real title-page drew on titling founts kept apart from the
body fount — Blayney records which line came from which — and
@racket[typecase] keeps one case. The error is about forty words a book, all of
them large.}

@subsection{The last sheet, and what becomes of the white paper}
@declare-exporting[handpress/book]

One sentence governs the end of every book:

@nested[#:style 'inset]{``as it costs practically as much to print part of a
sheet as a complete one, it was always to the printer's interest to make up a
complete sheet whenever he could.'' (McKerrow, p. 159)}

So a text that stops two leaves short of the end of its last sheet, in a house
with two leaves of preliminaries still to print, does not print a separate
half-sheet and leave two leaves white. It prints the preliminaries @emph{in}
the white leaves and cuts them out:

@nested[#:style 'inset]{``he will as a matter of course impose these
preliminaries in the middle of his last sheet, which may therefore run, as
actually printed (supposing it to be in fours), @bold{Z1, [*], *2, Z2, the two
centre leaves being cut out to be used as preliminaries}. Such a book will be
described as @tt{*², A–Y⁴, Z²}, quite correctly.'' (p. 158–9)}

And where the front matter is a single title-leaf: ``the printer would be quite
likely to print it Z1, Z2, Z3, [—], cutting off his last leaf to form the
title.''

A gathering is therefore @emph{printed} whole and @emph{bound} short.
@racket[page-refs] takes per-leaf signature overrides so that one sheet can
carry two series at once, and @racket[plan-bound-leaves] is what the collation
formula counts. McKerrow's reason for pressing the point is that the
alternative makes editors record leaves that never existed — ``@tt{*1 and Z4
wanting, probably blanks}, thus inventing two blank leaves which in fact never
existed'' — which is exactly what this program used to produce.

Cut from the centre the preliminaries come off as a conjugate fold; cut from
the tail they come off disjunct. Which of the two is recorded, because it is
the fact Bowers used to prove the case: of Sandys's Ovid he observes that the
printed preliminary leaves ``are always disjunct and have any watermark on the
outer edges of the two leaves, @bold{an impossibility if they had been printed
as a fold} in the cut-off.'' The paper that would betray it is not modelled;
see the roadmap.

@margin-note{It is a tendency, not a law, and the authorities guard it from
both sides. McKerrow: ``we must not assume that a printer would in every case
economize his labour and paper in this fashion: it might sometimes have been
more convenient to have the two extra leaves as covers or end-papers.'' Bowers:
``Even when normal printing practice might lead one to expect economical
machining without blanks, it is dangerous, lacking proof, to assume their
absence.'' Hence @racket[CUT-OUT-SHARE], and white paper otherwise.}

@subsection{Cancels, and why the cause is not simulated}
@declare-exporting[handpress/cancels]

A cancel is a leaf cut out and another pasted to the stub. The obvious
objection to simulating one is that they happen for reasons no printing house
can generate — the Privy Council took exception to @italic{Eastward Ho}.
McKerrow gets there first and makes the decision:

@nested[#:style 'inset]{``@bold{Into the purpose of these cancels we need not
enter.} There may have been in the original print something so grossly
incorrect that it was too much for even the easy-going printer of the day — or
for the author; or, as often in early times, there may have been something that
the authorities found objectionable. @bold{The point at present is the aid that
bibliography gives us in detecting them.}'' (p. 223)}

So the cause is a parameter and the trace is a simulation. Three causes, of
which only the first is modelled in the strong sense:

@itemlist[
@item{@bold{An error the program made itself} and its own corrector missed. The
      run knows what the error was, which page it is on, and that the proof went
      by without it, so nothing is supplied from outside. @tt{--cancel-rate}.}
@item{@bold{A change of imprint} — the same setting with the bookseller's name
      altered, which is why a cancel title is commoner than any other kind.
      @tt{--imprint-change}.}
@item{@bold{Anything else} — @tt{--cancels N}, a count and not a model. The
      report says so in those words.}]

The trace is complete, because that is the part that can be got wrong. The leaf
is cut out ``leaving a stub of paper to which the new leaf could be pasted''
(p. 223). The replacement is printed in the white paper at the end of a
gathering — Gaskell has Rousseau's publisher writing ``to encourage the author
to use up the blank leaves of final sheets for printing cancels'', and McKerrow
that ``spare leaves at the end of a book were used to print matter that was to
be bound elsewhere in it, @bold{such as titles or cancels}'' (p. 156) — or it
costs a half-sheet of its own, which the report distinguishes because it is the
expensive case. A cancellans is a leaf, so the paper it can use must be blank
on both sides.

And @racket[mckerrow-signs] generates five of McKerrow's six detection tests
(p. 224) as properties of the particular leaf, so that the analysis half can
one day be scored on finding them: the setting of headline, signature or text
differing; a different number of lines to the page; a signature where its
fellows carry none; a part-signature away from the first leaf of its gathering;
two press figures in what should be one forme. The sixth is the paper, and is
not claimed.

@margin-note{Bowers's caution holds throughout: ``It may be taken as an axiom
that no blank not interrupting continuous text would be torn by the printer for
excision.'' A cancel is a deliberate act on a printed leaf. Blanks stay.}

@subsection{The heaps, and why a copy is not a random draw}
@declare-exporting[handpress/press]

Two authorities meet here, and between them they turn the making-up of copies
from a shuffle into an inference.

Gaskell gives the mechanism (pp. 143–4). The heaps stand in signature order and
are gathered from the top of each. For a sheet perfected inner forme first they
come off ``in the reverse of the printing order, so that the first book to be
gathered contained the last printed sheets''; for one perfected outer forme
first the heap ``had to be turned over to show the first page of the signature,
which brought the first-printed sheet to the top. This heap was then gathered
in the printing order''. So the copies lie in one linear order, each variant
divides that order at the point the corrected proof came back, and which side
of the division is corrected says which forme of that sheet went to press
first.

Greg gives the test. His calculus assumes simple transcription, and warns that
where ``the grouping is throughout random or if inconsistent forms are of
frequent occurrence, the relationship of the manuscripts cannot be accounted
for on the hypothesis of simple transcription; some sort of conflation has
somewhere to be assumed'' (@italic{The Calculus of Variants}, p. 43).

@bold{A made-up copy of a printed edition is conflation by construction.} It
descends from no other copy; it is assembled from as many heaps as there are
sheets, which is Greg's many-one relation exactly. Drawn independently the
groupings cross. Gathered as Gaskell describes they are prefixes and suffixes
of one order, hence nested or disjoint — which is precisely Greg's condition
for consistency: ``given any two constant groups, either these or their
complements are either mutually exclusive or one wholly includes the other''
(p. 12).

@racket[variant-groupings] returns the grouping each press variant makes, and
@racket[greg-consistent?] applies the condition. Over 25 runs of ten copies:

@tabular[#:sep @hspace[3]
  (list (list @bold{@tt{--heap-disorder}} @bold{consistent})
        (list "0.0  (Gaskell's \"case of remarkable regularity\")" "60 of 60")
        (list "0.15 (the default)" "37 of 60")
        (list "0.5" "29 of 60")
        (list "1.0  (an independent draw per forme)" "16 of 60"))]

The last row is what this program did until the heaps were modelled — and the
fact that it fails Greg's test is the point, not an embarrassment: the test is
a detector for the very thing the code was getting wrong.

@margin-note{The parameter itself carries no authority. Gaskell hypothesises
``a case of remarkable regularity'' and hedges it in the same breath: after
drying, ``the chances were that … the sheets would be in the same order as
before, although this was not certain to happen.'' How much order the rack
destroys is a knob, and the report says so.}

What is not built, and is the next real exam for the analysis half: making the
inference rather than showing the answer. The direction of each grouping says
which forme of its sheet went to press first, and this program knows the truth.

@subsection{Gathering, folding and the binder's errors}
@declare-exporting[handpress/binding]

The one stage at which the @emph{book} diverges from the @emph{printing}.
Everything before it is the same for every copy of an impression; from here on
the copies are individuals, and a bibliographer describing one has to tell the
faults of the copy from the faults of the edition.

Two hands in two places. The warehouseman gathers, in the printing house: the
heaps ``were set out in signature order on a long table, with the first recto
pages upwards and to the near side'', and the gatherer ``took off the top copy
of the last sheet of the book and then walked along the line of sheets, taking
off one copy of each in turn'' (Gaskell, pp. 143–4). The books ``were then
collated to ensure that each was made up correctly'', and only then folded,
pressed and baled. The binder folds and sews later and elsewhere.

Between them they can drop a sheet, take two, put one in backwards, or sew them
out of order — and the whole apparatus of signatures exists to stop two of
those:

@nested[#:style 'inset]{``It was necessary, when assembling the sheets of a
book, to get them the right way up and in the right order; and to this end each
sheet was signed on the first page with a letter of the alphabet so that they
could readily be arranged in alphabetical order; similar signatures were also
placed on the rectos of a few leaves after the first of each sheet in order to
help the binder with his folding.'' (Gaskell, p. 79)}

That sentence is the design of @racket[binding]. The @emph{kinds} of fault come
from the sources, as does the fact that made-up books were collated before they
went out. @bold{The rate does not.} Neither Gaskell nor McKerrow gives one, so
@racket[BINDING-ERROR-RATE] is an explicit parameter carrying no authority
whatever, and the report prints the disclaimer beside every fault it lists. It
is a knob, not a finding.

What is not invented is the shape. An unsigned gathering offers the binder no
help with either the order or the way up, so it goes in wrong oftener — and
survives the warehouse's own check oftener, because the check is the signatures
too. A preliminary series signed @tt{π} is therefore the most misbindable thing
in a book, which is a consequence of Gaskell's sentence rather than an
invention on top of it.

@subsection{The corrector}
@declare-exporting[handpress/corrector]

Before copy reaches the frames it is read through and marked up — capitals
altered, house spellings imposed, page endings crossed. So the compositor does
not set from what the author wrote, and a spelling that differs from the
manuscript may be the house's rather than any workman's. Because house habits
fall evenly across every stint, no amount of counting can separate them from a
compositor's own practice.

@defproc[(prepare-copy [cr corrector?] [units (listof copy-unit?)])
         (values (listof copy-unit?) (listof change?))]{
Prepares copy to house style, returning the prepared units and a record of
every alteration.}

@subsection{At press}
@declare-exporting[handpress/press]

The press does not stop for a proof. At three or four impressions a minute and
fifteen to thirty minutes for the reader, some 60 to 120 sheets of an edition
of about 1,200 were printed before the marked proof came back — so the
uncorrected state is typically 5 to 10 per cent of the copies. The corrector
generally worked without the copy, so he catches foul case readily and
misreadings hardly at all, and sometimes he made it worse.

Whether the corrector had the copy in front of him is a question with two
answers, and this module used to give only one. Moxon describes the proper
method: the master-printer appoints someone ``well skill'd in true and quick
Reading, to Read the Copy'' aloud while the corrector follows the proof. On
that method a misreading is as catchable as a turned letter.

Hinman found the Folio was not corrected that way — ``the copy was in all
probability seldom if ever used to correct perfectly obvious mistakes'' that
the context would yield sense for. But seldom is not never, and he can point
to the corrections that prove the copy was sometimes at the reader's elbow: a
two-line speech that ``cannot have been restored save by reference to the
copy'', and a line bearing no resemblance to the one it replaced.

So @racket[consults-copy] governs how often the copy is called for, and the
two methods fail differently. Sense catches foul case and leaves a plausible
misreading standing; the copy catches the omission that sense cannot see.
Hinman also noticed the consequence of a scare — having found a considerable
omission, the reader grew ``somewhat more careful ... at least for a time'' —
so a serious catch raises vigilance for the next forme.

@margin-note{Building this turned up a bug of some standing. Misreadings are
recorded when the compositor reads his copy, before the word is placed, so
they carry no page or line and the press loop never saw them: no misreading
was correctable by any method, and @racket[catches-misreading] did nothing at
all. They are now found on the page, where the copy reading and the read
reading disagree.}

@defproc[(run-press [b book?]
                    [#:copies copies exact-integer? 4]
                    [#:seed seed exact-integer? 1623]
                    [#:proof-rate proof-rate real? 0.6]
                    [#:consults-copy consults-copy real? 0.12]
                    [#:first-proof first-proof real? 0.0])
         press-run?]{
Prints the book, correcting some formes in mid-run, and makes up copies at
random from the heaps.

@racket[first-proof] is the chance a forme was proofed and mended
@emph{before} the pressmen began. Such corrections leave no variant: every
copy shows the mended reading. So the catalogue of press variants, however
many copies are collated, records only the corrections made too late.}

@defproc[(collate [r press-run?] [a printed-copy?] [b printed-copy?])
         (listof (list/c string? string? string?))]{
Superimposes two copies and reports where the page moves, as the Hinman
collator does mechanically.}

@section{The bibliographical description}
@declare-exporting[handpress/description]

Every rendering opens with a description of the edition in the form Fredson
Bowers sets out in @emph{Principles of Bibliographical Description} (1949),
following the worked example at i. 128–9:

@tabular[#:sep @hspace[2]
  (list (list @tt{RT]}   "running-titles, with their variants grouped by the damage that identifies a skeleton")
        (list @tt{Coll:} "format, collational formula, leaf count, numbering — followed by the contents")
        (list @tt{Sigs:} "the signing statement in Bowers's $-notation: $2 signed A means the first two leaves of gathering A")
        (list @tt{CW:}   "catchwords, with the following word bracketed where it does not answer")
        (list @tt{Type:} "lines to the page, type-page in mm., and the 20-line measurement")
        (list @tt{States:} "press variants by forme, with the point in the run at which each was corrected")
        (list @tt{Copies:} "how many were collated")
        (list @tt{Notes:} "compositor stints, and the pages showing strain from the casting off"))]

Two of these carry more weight here than the rest. The running-title
paragraph is where the skeleton formes betray themselves — Bowers: the
complete evidence of running-titles ``would almost inevitably reveal
simultaneous setting and printing of different portions of a book'' (i. 125).
And the catchword list is his ``partial check for variant states of formes'':
a catchword that does not answer the first word of the next page is evidence
that something was reset or crowded after it was set, and the simulation
produces exactly that.

The type-line is computed rather than invented. A pica em is 4.2175 mm and the
type is set solid, so the 20-line measurement follows from the body — 84 mm
for pica, written @tt{84R} in the trade's shorthand.

@defproc[(description-text [b book?] [run (or/c press-run? #f) #f]) string?]{
The description as Bowers would set it out.}

@defproc[(description-tei-msdesc [b book?] [run (or/c press-run? #f) #f]) string?]{
The same, as a TEI @tt{<msDesc>} for the header. Bowers's sections map onto
TEI's physical description almost one for one: @tt{<collation>},
@tt{<foliation>}, @tt{<layout>} and @tt{<typeNote>} take the formula, the
numbering, the make-up and the type. The signing statement, catchwords and
running-titles go in @tt{<additions>} as labelled paragraphs — a content
model that is certainly valid, rather than one guessed at.}

@section{TEI, and the facsimile rebuilt from it}
@declare-exporting[handpress/tei]

@verbatim|{
racket main.rkt --xslt -o out samples/hamlet.txt
}|

writes @tt{out/hamlet.tei.xml} and a plain reading text beside it.

The important arrangement is the other way round. @tt{--html} does not render
the book a second time: it reads the @tt{.tei.xml} back off disk and builds the
type-facsimile from that and nothing else. So the TEI is the record and
everything else is derived from it, and @bold{anything the TEI does not carry
cannot appear on the page}.

That is a property rather than a discipline, and it earns its keep. There were
once two renderers — one from the book in memory, one from the TEI — and they
drifted, because each knew things the other did not; a parity test between them
caught none of it. Reading from the file instead has already exposed four
things the encoding was quietly missing: the identity of the damaged sorts, the
statistics, the stage-by-stage account of what happened to each word, and the
space-metal. Each had reached the page by some route that did not pass through
the file, so the file never had to carry it.

The XSLT survives as a deliberately smaller thing: a reading text, giving the
words and the page breaks and the @emph{reading} rather than the glyph —
@tt{<reg>} not @tt{<orig>} — which is the half of every @tt{<choice>} the
facsimile does not show. It makes no claim to match the facsimile, and there is
a test that it does not try.

@defproc[(book->tei [b book?] [run (or/c press-run? #f) #f]
                    [names (listof string?) '("A" "B")])
         string?]{
Encodes the book as TEI P5.}

TEI already has the vocabulary and most projects never use it:
@tt{<fw>} is forme work — running titles, signatures, catchwords;
@tt{<pb/>}, @tt{<cb/>}, @tt{<lb/>} are page, column and type line;
@tt{<lb break="no"/>} is a word divided across a line;
@tt{<choice>} with @tt{<abbr>}/@tt{<expan>} is a compositor's contraction and
with @tt{<sic>}/@tt{<corr>} a literal; and @tt{<app>} with
@tt{<rdg wit="…">} is a critical apparatus, which is exactly what a list of
press variants across copies of one edition is. Compositors are
@tt{<respStmt>}s and every page carries @tt{@"@"resp}; the causes of variation
are a @tt{<taxonomy>} in the header that every word points into with
@tt{@"@"ana}.

@bold{Two decisions worth arguing with.}

@italic{Milestones, not containers.} Verse lines, speeches and typographic
lines overlap constantly here: a turned-over verse line is one verse line
across two type lines, and a prose paragraph runs over a page break. XML
cannot nest overlapping hierarchies, and TEI's own answer is the milestone.
So @tt{<lb/>} is empty and the words are its siblings. The cost is that
@tt{<l>} does not appear; the benefit is that nothing is misrepresented, and
the XSLT can group words by sibling axis — which XSLT 1.0 can actually do.

@italic{Geometry in a foreign namespace.} The point of the program is that the
justification is the compositor's and not the browser's, so the computed
position of every word must survive into the output. But an em offset is
process data, not text, and has no business wearing TEI semantics. It goes in
the @tt{hp:} namespace, the standard escape hatch; strip that one namespace
and you lose nothing textual.

@subsection{Leaves, openings, and which side you are looking at}

The XSLT rendering lays the book out in @deftech{openings}: the verso of one
leaf on the left and the recto of the next on the right, as the book is held.
The first recto therefore stands alone on the right of the first opening, with
a dashed placeholder where the outside of the book would be, and a final verso
stands alone on the left. Every leaf is given the full depth of a page,
because a leaf is a fixed piece of paper however little type stands on it.

Under each page is its signature, the leaf it belongs to, and whether it is
the recto or the verso.

@tt{--layout leaf} pairs the two sides of one leaf instead, recto then verso.
That is not a view anyone ever has of a bound book — the two sides of a leaf
cannot be seen at once — but it is the view the compositor and the pressman
had, and it puts the two formes of a leaf where they can be compared. Both are
offered because ``show the leaves with the pages side by side'' can reasonably
mean either.

@subsection{Fitting the face to the body}

The rendering is scaled by one number. A pica em is 4.2175 mm and is drawn
@tt{--grid} pixels wide, so @tt{--mm} — one millimetre in pixels — follows from
it, and the type, the leaf and the margins are all measured in the same
millimetres and move together.

@tabular[#:sep @hspace[2]
  (list (list @tt{--grid} "one em of the type body, in pixels")
        (list @tt{--mm}   "one millimetre, derived: --grid ÷ 4.2175")
        (list @tt{--fit}  "the set width of the face against that body")
        (list @tt{--lead} "line pitch as a multiple of the body")
        (list @elem{@tt{--leaf-h}, @tt{--leaf-w}} "the uncut leaf in mm, from the file")
        (list @elem{@tt{--mi}, @tt{--mh}, @tt{--mo}, @tt{--mt}} "inner, head, outer and tail margins in mm"))]

The leaf dimensions and the margins are @emph{read out of the TEI}, not computed
here. The stylesheet used to build a leaf from the type page plus eleven ems of
margin it had chosen itself, which is a second place deciding a thing the model
should own — and it drew a quarto half again too tall. Now the sheet decides the
size, the file carries it, and the stylesheet only scales it.

@tt{--lead} is 1.00 because the description says the type is set solid, and set
solid means the line pitch @emph{is} the body. It was 1.44, a screen line-height
with nothing behind it, which inflated the type page by 44%.

Two bugs surfaced the moment the paper became authoritative, both of which the
old arrangement had concealed by feeding the leaf and its contents the same wrong
number. @tt{--lines} is the lines on the @emph{page}, which is what a
bibliographer counts — a two-column folio of 66-line columns has 132 — so the
depth of a column is @tt{--lines} divided among the columns and not @tt{--lines}
itself. And the gutter between columns had to go into the modelled type page,
because without it the flex box squeezed the columns to fit, and a column that is
squeezed does not reflow: every word in it sits at an absolute offset the
compositor computed, so it clips.

@tt{--grid} and @tt{--fit} have to be separate. Every word is positioned at
@tt{calc(var(--grid) * var(--x))}, where @tt{--x} is the offset the simulation
computed. If the position were expressed in @tt{em} instead, it would resolve
against the word's own font-size, so the glyphs and the grid would scale
together and a wide face could never be made to fit — which is exactly the
fault the first version had: 222 pairs of words overlapped, some by six
pixels, and the word-spaces vanished entirely.

@tt{--font} names the family, @tt{--font-file} embeds a fount beside the page so
the output stays self-contained, and @tt{--fit} retunes the seam. The fount is a
rendering choice and not a fact about the book, so it is a parameter of the
renderer and stays out of the TEI: the file records what was set, not what a
browser was asked to draw it with.

@hyperlink["https://junicode.sourceforge.io/"]{Junicode} is the fount to use.
Its roman derives from the seventeenth-century Oxford types, it is under the SIL
Open Font License, and — checked rather than assumed — it carries every
character this program sets: long s, the f-ligatures and @tt{ſt}, the macron
vowels, and the superior letters of @tt{yᵉ} and @tt{wᶜʰ}. Measured on a 24-leaf
quarto it leaves 4 touching word pairs in 8,636 at @tt{--fit 1.00}, against the
0.08% recorded below for Times, so it needs no retuning. It is not bundled.

A revival gives shapes and not the measure. Its fitting is the reviser's rather
than the fount's — Marini autospaced IM Fell with his own algorithm, and
Blokland observes that revivals of Renaissance type are fitted optically rather
than to any historical grid.

The default stack is Times-like, because an old-face roman is narrow and
Georgia and Palatino are not. Calibrated by measuring every word in the
rendered page, @tt{--fit: 1.00} puts the median word within 1% of its modelled
width and brings the median gap between words to 5.4px against a true thick
space of 5.33px. So the white you see between two words is the space the
compositor put there. If you substitute a wider face, lower @tt{--fit} until
no words touch.

@subsection{Running the transform}

The stylesheet is XSLT 1.0, because the processor most likely to be present
without an install is .NET's @tt{XslCompiledTransform}. @racket[apply-xslt]
prefers @tt{xsltproc} if it is on the @tt{PATH} and otherwise calls
@tt{tools/xslt.ps1}.

@defproc[(apply-xslt [xml path?] [xsl path?] [out path?]
                     [#:witness witness string? "copya"]) boolean?]{
Applies a stylesheet, returning @racket[#f] if no processor could be found.}

The @tt{witness} parameter chooses which made-up copy of the edition the
facsimile shows. Since the copies were gathered at random from the heaps they
disagree, so @tt{--witness copya} and @tt{--witness copyb} produce genuinely
different pages from the same TEI — which is the point of an apparatus.

@section{The lexicon}
@declare-exporting[handpress/lexicon]

For most of its life this program had no dictionary. Its spelling devices were
rules — strike off a terminal @tt{-e}, double a consonant, add an @tt{-e} to
fill out a line — and nothing checked what came out. A rule so arranged will
produce @tt{theere} and @tt{manne} as readily as @tt{heere} and @tt{doe}, and
did.

The remedy is not more rules but a reversal of authority. The lexicon says
which spellings exist; the rules only choose among them. A device that can
select but not invent cannot fabricate a spelling, however tight the line.

@subsection{What is in it}

@racketmodname[handpress/lexicon] ships with 318,722 spellings attested in
5,287 books printed between 1580 and 1640, drawn from EEBO-TCP@~cite[eebo-tcp]. They are
grouped into 45,719 sets of variants of one another, and 18,562 are mapped to
the form still current.

It answers three questions, and they are genuinely different:

@tabular[#:sep @hspace[2]
  (list (list @bold{question} @bold{procedure})
        (list "is this a real spelling?" @racket[attested?])
        (list "is it one anybody used?" @racket[plausible?])
        (list "how else was this word spelt?" @racket[variants-of])
        (list "which spelling is standard?" @racket[commonest-form])
        (list "which is still current?" @racket[modern-form]))]

@defproc[(attested? [w string?] [lx lexicon? (current-lexicon)]) boolean?]{
Whether the corpus contains this form at all.}

@defproc[(plausible? [w string?] [lx lexicon? (current-lexicon)]) boolean?]{
Whether it holds a real share of its own word's occurrences.

This is the more useful test, and a large corpus is what makes the difference
matter. @tt{theere} occurs seventeen times in 5,287 books against 145,517 for
@tt{here}, and @tt{wheere} six. Those are not spellings anybody chose; they are
the sweepings of a very large floor — foreign words, slips, mis-keyings. Set
beside them @tt{manne} at 1,147 occurrences and @tt{somme} at 467 are real
usage. The threshold is @racket[plausible-share], one in two hundred, and it is
a judgement stated in the open rather than buried.@note{This distinction cost
the author some embarrassment. Working from the 24,000 words of the two
@emph{Much Ado} texts, I asserted in code, comments and three commit messages
that nine forms the old rules could produce were ``not early modern spellings
at all''. Against 5,287 books, six of the nine occur. The claim was true of my
sample and false of the language, which is the characteristic failure of a
corpus too small for the question asked of it.}}

@defproc[(variants-of [w string?] [lx lexicon? (current-lexicon)])
         (listof (cons/c string? exact-integer?))]{
Every attested spelling of the same word, commonest first. This is what a
compositor short of room chooses from.}

@defproc[(modern-form [w string?] [lx lexicon? (current-lexicon)])
         (or/c string? #f)]{
The spelling still in use, where the corpus records one; @racket[#f] otherwise.
Drives @tt{--modern-spelling}.}

@subsection{How the variants are grouped}

Without a modern wordlist to anchor it, @tt{her} becomes a spelling of
@tt{here}. The reduction that correctly joins @tt{heere} to @tt{here} joins
@tt{here} to @tt{her} by exactly the same steps, and no rule about letters
distinguishes the two cases. What does distinguish them is that @tt{her} is
itself a current word, and a current word is not a misspelling of another
current word.@note{This is the design of @citet[vard], arrived at here
independently and after making the error it exists to prevent — which is at
least a good way to understand why a tool is built as it is.}

So the grouping runs in three steps:

@itemlist[#:style 'ordered
 @item{Reduce each form to a @deftech{skeleton} that collapses the period's
       orthographic alternations — the shared letters @tt{u}/@tt{v} and
       @tt{i}/@tt{j}, doubled letters, a terminal @tt{-e}. Forms sharing a
       skeleton are candidates for one another.}
 @item{Split each group against a modern wordlist, so that every current word
       keeps its own variants and takes none of its neighbour's.}
 @item{Assign each old form to the single nearest current word by edit
       distance, so @tt{heere} goes to @tt{here} — one letter away — and not
       also to @tt{her}, which is two.}]

The reduction is deliberately conservative and guarded by length. Without the
guard it merges @tt{as} with @tt{asse} and @tt{at} with @tt{ate}: different
words, run together because they happen to differ by a doubled letter and a
terminal @tt{e}. A false merge is worse than a missed one, because it puts a
wrong @emph{reading} into the compositor's hand rather than merely a wrong
spelling.

@margin-note{It still errs. @tt{runne} is assigned to @tt{rune} rather than
@tt{run}, the first being nearer by edit distance. Nothing about the letters
separates that case from @tt{heere}/@tt{here}, where distance gives the right
answer. This is why VARD and its relatives keep a human in the loop, and why
@tt{--modern-spelling} should be read as approximate.}

@subsection{Rebuilding it}

The shipped lexicon covers 1580–1640. For another period, another language of
book, or a narrower window, rebuild it. Two commands, and an hour:

@verbatim|{
# 1.65 GB of TEI XML from Oxford, filtered to a date range by each
# text's own imprint
python tools/fetch-eebo.py --dest corpus --from 1580 --to 1640

# a wordlist, from any Hunspell dictionary already on the machine
python tools/make-wordlist.py path/to/en-GB.dic tools/modern-en.txt

# the lexicon itself
python tools/build-lexicon.py corpus/texts \
       -o lexicon/eebo-1580-1640.rktd \
       --modern tools/modern-en.txt --min 5
}|

@tabular[#:sep @hspace[2]
  (list (list @bold{option} @bold{effect})
        (list @tt{--min} "ignore forms occurring fewer than this many times; a hapax in a keyed corpus is as likely to be a transcription slip as a spelling")
        (list @tt{--modern} "the wordlist that anchors the grouping. Without it the groups merge different words, and the builder says so")
        (list @elem{@tt{--from}, @tt{--to}} "printing years, taken from each text's own header rather than a catalogue"))]

A run picks its lexicon in this order: the file named by the
@envvar{HANDPRESS_LEXICON} environment variable, then the shipped
@filepath{lexicon/eebo-1580-1640.rktd}, then the small
@filepath{samples/ado-lexicon.rktd} built from the two @emph{Much Ado} texts.
The last is kept because it is small enough to read, and because the difference
between it and the real one is instructive: on the same copy the proportion of
words altered to fit the measure rises from 8.70 per thousand to 29.38 when a
corpus is behind it. The compositor then has genuine variants to choose among
instead of the handful a rule could invent.

@margin-note{The modern wordlist is a build input and is not redistributed.
Only its verdict on public-domain forms is, which is a judgement about the
corpus rather than a copy of the dictionary.}

@section{Calibration}
@declare-exporting[handpress/validate]

Every parameter that has been checked against a real book was wrong when first
guessed, usually by an order of magnitude. The record is worth keeping in
full, because it is the only part of this document that is not inference:

@tabular[#:sep @hspace[3]
  (list (list @bold{parameter} @bold{in the real books} @bold{first guess} @bold{now})
        (list "the fount" "21,953 sorts (Okes)" "60,000" "31,200 incl. space")
        (list "tilde abbreviations" "1.01 / 1000 words" "83" "1.66")
        (list "superscript y-t, w-ch" "5.5 per million words" "6,600" "~0")
        (list "foul case + turned letters" "0.25 / 1000 words" "11.57" "0.87")
        (list "word division" "5.1 / 100 lines" "0.0" "5.3")
        (list "medial apostrophes" "9.58 / 1000 words" "1.17" "5.37")
        (list "ampersand" "3.18 / 1000 words" "35" "3.02")
        (list "class spelling habits" "57% (Blayney)" "82-91%" "57%")
        (list "wrong-fount sorts" "a handful a book" "248" "13")
        (list "gaps a compositor could set" "every one" "14%" "95%"))]

The measurements come from the 1600 quarto of @emph{Much Ado About Nothing}
and the 1623 Folio text set from it: 11,990 words of real copy-text and a real
setting from it, which is the only kind of evidence that can settle any of
this.@note{Transcriptions from @citet[ise]. @citet[hinman] establishes the
descent; Halliwell-Phillipps, quoted in @citet[furness], inferred that the copy
was ``a play-house copy of the edition of 1600, an exemplar of it, with a few
manuscript directions and notes'' — which is the corrector's stage exactly. In
the same appendix P. A. Daniel judges that most of the variation is the
printer's rather than the annotator's, which is the assumption this program had
been making without warrant.}

@bold{A caution about the size of this evidence.} Eleven thousand words is
enough to catch an error of an order of magnitude and not enough to settle a
question of usage. Several confident claims made from it — see the footnote to
@racket[plausible?] — turned out to be true of the sample and false of the
language. Where a figure below rests on the two @emph{Much Ado} texts alone, it
should be read as a bound rather than a measurement.

@bold{The instructive failure.} The program used to produce @tt{implēētatiō}
for @emph{implementation}, stacking tilde contractions on a single word, and
label it a space-saving. It was neither. The Folio has @emph{no} scribal
contractions in these scenes, and some substituted forms were @emph{longer}
than what they replaced — an expansion mislabelled as a contraction, because
the TEI marked both with @tt{<abbr>}. Expansions are now @tt{<orig>}/@tt{<reg>},
only one alteration may be applied to a word, and the scribal signs are off by
default. The genuine English space-saver was in the same data unnoticed: see
@secref["The_elided_ending"].

Forward test, Q1600 → F1623, on the spelling that attribution work depends on:

@tabular[#:sep @hspace[3]
  (list (list @bold{} @bold{actual F1} @bold{simulated})
        (list @elem{@tt{here} / @tt{heere}} "52%" "51%")
        (list @elem{@tt{do} / @tt{doe}} "61%" "80%"))]

The @tt{do}/@tt{doe} overshoot has a known cause rather than an excuse: the
real scenes were set by more than one man, and the simulation ran a single
man's habit across all of them.

@section{What is reconstructed}
@declare-exporting[handpress/analysis]

The analysis works only from what is printed, and scores itself against the
record afterwards.

@defproc[(spelling-evidence [b book?] [names (listof string?) '("A" "B")])
         (listof page-evidence?)]{
Counts the test forms page by page and assigns each page to the workman it
agrees with.}

@defproc[(full-report [b book?] [r (or/c press-run? #f) #f]
                      [names (listof string?) '("A" "B")])
         string?]{
The whole report: bibliographical description, the scheme of imposition, the
stints recovered from spelling, the same evidence with the answers, the
skeletons recovered from damaged running titles, the casting off recovered
from crowded pages, the state of the case with its standing-type ledger, the
press variants — and @racket[MCKENZIE].}

@subsection{Backwards: the editor's problem}
@declare-exporting[handpress/reconstruct]

Given a printed text, recover the copy behind it. This is what an editor does,
and the module reports a word-by-word confusion matrix rather than a score,
because the interesting result is @emph{where} it fails.

Run from the Folio text of @emph{Much Ado} against the quarto it was set from,
the best blanket rule ceilings at 70–76 per cent. No per-word rule does
better, because no per-word evidence exists. That is the honest form of Greg's
distinction between substantives and accidentals: he arrived at it by
counting, and so does this.

@section{The objection}
@declare-exporting[handpress/analysis]

@defthing[MCKENZIE string?]{
Appended to every report, because the tables above it read as proof and are
not.

Every percentage the analysis produces is the analyser inverting the
generator. Both were written from the same account of how a printing house
behaved, so a high score demonstrates that the simulation is self-consistent
and nothing else. McKenzie's finding from the Cambridge and Bowyer records —
the only places the working of a hand-press shop can be checked against its
output — is that the patterns are ``of such an unpredictable complexity, even
for such a small printing shop, that no amount of inference from what we think
of as bibliographical evidence could ever have led to their reconstruction.''

His distinction is the useful part: the physical actions of setting, imposing,
proofing and distributing type do not change from century to century, and
those are what this program models. What varies, and what it assumes away, is
``the amount of work done and the relations between those performing it …
from day to day''. Of normality in that sense he says flatly: ``it doesn't
exist.''

So the honest use of this machine is not to confirm the method but to break
it. Only the failures are evidence; the successes are arithmetic.}

@section{The sources}

Everything this program does is drawn from somewhere, and the sources are not
of one kind. The distinction matters more than an alphabetical list suggests,
because it decides how much weight a claim will bear.

@bold{The manuals} — @citet[moxon], @citet[smith] — were written by printers
for printers. They are the only sources that describe the work from inside, and
they describe it as it @emph{ought} to be done. The lay of the case, the
quantities of the spaces, the reaching, the reader who speaks the copy aloud:
all of that is Moxon's, and where this program models a procedure rather than
an outcome it is usually following him.

@bold{The archives} — @citet[mckenzie-cambridge], and the proof-sheets behind
@citet[simpson] — are records made at the time for other purposes, which is
what makes them evidence rather than inference. Nearly every correction this
program has had to make came from the first of them. Its production times, its
compositors' output in ens, its finding that setting by formes ``was followed
occasionally but was certainly not normal'', and its Vouchers showing that men
took over from one another in long blocks rather than alternating, between them
overturned four separate assumptions in the code.

@bold{The analyses} — @citet[greg], @citet[hinman], @citet[bowers],
@citet[blayney], @citet[mckerrow], and behind them @citet[satchell] — are
reconstructions from the printed books themselves. This is the New
Bibliography, and this program stands in an odd relation to it: it implements
the method in order to test it, and reports where it fails. @citet[hinman] is
the largest single debt — the compositor spellings, the type-recurrence
method, the proof-reading, the pagination errors, and the caveat about
justification that the whole method turns on.

@bold{The objection} — @citet[mckenzie-printers] — is the paper this program
cannot answer and does not try to. See @secref["The_objection"].

@bold{The texts and data} are @citet[ise] for the old-spelling transcriptions
used in calibration, @citet[furness] for the collation they are measured
against, @citet[mulcaster] for what the period held correct spelling to be, and
@citet[eebo-tcp] for what was actually printed. @citet[vard] is not used but
solves the same variant-grouping problem, and its design settles a question met
here independently.

@(generate-bibliography #:sec-title "Bibliography")

@section{What the archives say about rates}

The program models no clock at all: a page is set, and no time passes. These
are the figures it would need if it did, and they are worth recording because
they are measured rather than assumed.

@bold{Composition.} The obvious norm would be 1,000 ens an hour over a
twelve-hour day and a six-day week — call it 12,000 ens a day. Actual daily
averages at Cambridge run at about half that: Bertram 5,700, Knell 5,603.
Pokins is the exception at some 10,600 ens a day over five weeks in 1702, and
he stands out sharply from everyone else. McKenzie's reading is that ``each
compositor's output was conditioned more by what he was content to earn than
by any sanctions that Crownfield might have imposed'' (i. 119).

@bold{Presswork.} A token is 250 sheets and was reckoned an hour's work, which
agrees with Moxon's ``if two men Work at the Press ten Quires is an Hour''
(240 sheets). So roughly 250 impressions an hour at a press worked by two men
— which is where @racket[run-press]'s three or four impressions a minute comes
from, and the one rate in this program that was right before it was checked.

@bold{Concurrency.} A compositor did not work through a book to the exclusion
of others: ``normally he would be setting type for two or three
concurrently''. Books were correspondingly slow — Bentley's Horace was over
eight years in the Press, Wasse's Sallust exactly five.

@section{What is not modelled}

@itemlist[
 @item{@bold{Concurrent production.} McKenzie's central finding is that a shop
       worked on several books at once; this models one book at a time. The
       report says so wherever it draws a conclusion that concurrency would
       undermine.}
 @item{@bold{Per-compositor cases.} Hinman distinguishes cases x, y and z;
       here all the men draw from one pair.}
 @item{@bold{Forme order from type recurrence.} The pieces are tracked and the
       recurrences recorded, but nothing yet reconstructs the order of
       printing from them.}]
