#lang scribble/manual
@(require (for-label racket/base racket/contract
                     handpress/metrics handpress/typecase handpress/orthography
                     handpress/copytext handpress/corrector handpress/compositor
                     handpress/imposition handpress/book handpress/press
                     handpress/render handpress/analysis))

@title{handpress: a simulation of hand-press composition}

A compositor of the hand-press era, simulated: casting off, spelling habit,
justification, foul case, imposition, skeleton formes, and stop-press
correction. And then the New Bibliography run back over the result, trying to
recover from the printed page what the record says actually happened.

@margin-note{Scribble is itself a typesetting system, which makes documenting
a typesetting simulation in it a small pleasure.}

The modules, in dependency order:
@racketmodname[handpress/metrics],
@racketmodname[handpress/typecase],
@racketmodname[handpress/orthography],
@racketmodname[handpress/copytext],
@racketmodname[handpress/corrector],
@racketmodname[handpress/compositor],
@racketmodname[handpress/imposition],
@racketmodname[handpress/book],
@racketmodname[handpress/press],
@racketmodname[handpress/render],
@racketmodname[handpress/description],
@racketmodname[handpress/tei],
@racketmodname[handpress/analysis],
@racketmodname[handpress/validate],
@racketmodname[handpress/reconstruct].

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
        (list @tt{--format} "folio | folio6 | quarto | octavo")
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
        (list @tt{--modern-uv} "keep modern u/v and i/j")
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

@defproc[(cast-off [units (listof copy-unit?)] [measure exact-integer?]
                   [lines-per-page exact-integer?] [g pseudo-random-generator?]
                   [accuracy real? 0.93])
         (listof cast-off-segment?)]{
Measures the copy out into pages, imperfectly. @racket[accuracy] scales the
difficulty; it does not level it, since the kind of copy matters more than the
skill of the man.}

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

writes @tt{out/hamlet.tei.xml} and then transforms it to
@tt{out/hamlet.tei.html} with @tt{xslt/tei-to-html.xsl}. The result is
compared against the HTML written directly from the standing type, and they
must agree leaf for leaf, line for line, word for word, and position for
position — there is a test to that effect in @tt{main.rkt}. If they ever
diverge, the TEI has lost something.

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

Both HTML renderings carry two CSS custom properties on @tt{.plate}:

@tabular[#:sep @hspace[2]
  (list (list @tt{--grid} "one em of the type body, in pixels")
        (list @tt{--fit}  "the set width of the face against that body"))]

They have to be separate. Every word is positioned at
@tt{calc(var(--grid) * var(--x))}, where @tt{--x} is the offset the simulation
computed. If the position were expressed in @tt{em} instead, it would resolve
against the word's own font-size, so the glyphs and the grid would scale
together and a wide face could never be made to fit — which is exactly the
fault the first version had: 222 pairs of words overlapped, some by six
pixels, and the word-spaces vanished entirely.

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

@section{Calibration}
@declare-exporting[handpress/validate]

Every parameter that has been checked against a real book was wrong when first
guessed, usually by an order of magnitude. The record is worth keeping in
full, because it is the only part of this document that is not inference:

@tabular[#:sep @hspace[3]
  (list (list @bold{device} @bold{in the real books} @bold{first guess} @bold{now})
        (list "scribal contractions" "0 in F1" "83" "0, behind a flag")
        (list "foul case + turned letters" "0.25 / 1000 words" "11.57" "1.12")
        (list "word division" "5.1 / 100 lines" "0.0" "5.3")
        (list "medial apostrophes" "9.58 / 1000 words" "1.17" "5.37")
        (list "ampersand" "14 in five scenes" "35" "26"))]

The measurements come from the 1600 quarto of @emph{Much Ado About Nothing}
and the 1623 Folio text set from it: 11,990 words of real copy-text and a real
setting from it, which is the only kind of evidence that can settle any of
this. Hinman established the descent; Halliwell-Phillipps inferred that the
copy was ``a play-house copy of the edition of 1600, an exemplar of it, with a
few manuscript directions and notes'', which is the corrector's stage exactly.

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

@section{Reading}

@itemlist[
 @item{W. W. Greg, @emph{The Shakespeare First Folio} (1955)}
 @item{Charlton Hinman, @emph{The Printing and Proof-Reading of the First
       Folio of Shakespeare}, 2 vols (1963)}
 @item{Joseph Moxon, @emph{Mechanick Exercises on the Whole Art of Printing}
       (1683–4)}
 @item{Philip Gaskell, @emph{A New Introduction to Bibliography} (1972); and
       ``The lay of the case'', @emph{Studies in Bibliography} xxii (1969)}
 @item{Percy Simpson, @emph{Proof-Reading in the Sixteenth, Seventeenth and
       Eighteenth Centuries} (1935; repr. 1970, with Harry Carter's foreword,
       which is where most of the corrections to Simpson actually are)}
 @item{Fredson Bowers, @emph{Principles of Bibliographical Description}
       (1949) — the form of the description}
 @item{Peter W. M. Blayney, @emph{The Texts of King Lear and their Origins}
       (1982) — Okes's compositors, and copy preparation}
 @item{R. B. McKerrow, @emph{An Introduction to Bibliography for Literary
       Students} (1927) — imposition}
 @item{H. H. Furness, ed., @emph{Much Ado About Nothing}, New Variorum
       (1899) — the collation the calibration is measured against}
 @item{D. F. McKenzie, ``Printers of the Mind'', @emph{Studies in
       Bibliography} xxii (1969) — on the limits of all of this}]

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
