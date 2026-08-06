# One book, three shops

*A Manual of Controversies* (Saint-Omer, 1614) — EEBO-TCP `A18390`, chosen not
because it is representative but because it exercises the things that were
lately wrong: 208 `cap.`, 22 `lib.` and 16 `Cor.` in 23,000 words, all-capital
Latin on nearly every page, seventy-five `ff` words, and three declared
divisions of front matter.

`examples/floyd/` varies the **input format** and holds the shop fixed. This one does
the opposite: same text, same seed, and the shop moved. Open
`<dir>/manual.html`.

| dir | | collation |
|---|---|---|
| `md` | 1614, from markdown + YAML | `4°: ¶⁴ A–E⁴` |
| `xml` | 1614, from the TCP original | `4°: a⁴ A–O⁴` |
| `late` | **1670**, the same copy, after the conventions had gone | `4°: a⁴ A–O⁴` |

## The four views

The page is no longer one scroll. Along the top:

| | |
|---|---|
| **The book** | the leaves, with a map of the whole run above them — one tick per page, darker where the page was harder to fill. Click any tick to go there. |
| **The make-up** | every gathering drawn as its sheet folds, with the conjugate pairs arced together, and the Bowers description under it. Hover a leaf to light its conjugate; a cancelled leaf is dashed and red. |
| **The evidence** | what the run came to — the counts, with the rates as bars so they can be compared at a glance. This was a table at the very bottom of the scroll before, which is to say nobody found it. |
| **The copies** | the eight made-up copies, how each was sewn, and what the binder got wrong. |

Under **The book** the legend is now a filter: click any kind of departure to
hide it. Ten kinds marked at once is an apparatus nobody can read, and it is
the one complaint about a printed apparatus that a screen can actually fix.

## What to look at

**The capitals.** `xml` and `late` are the same text set sixty years apart, and
the difference is the point. In 1614 the fount has no capital U worth the name,
so V does duty for both letters: hover `PROVED` or `SCRIPTVRE` and the note
reads *"the conventions of the case: V for U, the fount having no capital U."*
Eighty-two of them. In `late` there are none — the convention has lapsed, the U
is set as a U, and instead you get twenty-one notes saying *"the U box was
empty, so it was set V"*, because the case still only holds eight of them. Same
letters on the page, entirely different reason, and the tooltip says which.

Measured, not assumed: across 400 corpus books a capital standing inside an
all-capital word is V in 6,028 places against U in 158 — 2.2% in the 1600s,
rising to 22% by the 1640s.

**The abbreviations.** `cap.` and `lib.` are everywhere in this book, and none
of them has grown a terminal `-e`. That rule used to fire on anything ending in
a consonant, making `libe.` out of `lib.`; a word list cannot tell the two apart
because the corpus contains `libe`, but the share of occurrences that are
pointed can — `lib` 93.4%, `cap` 85.2%, against `command` 7.1% and `most` 0.4%.

**The tooltips.** Every marked word carries the account of what happened to it,
and the marks are keyed at the foot of the page. Four categories are new:
a forced **substitution** (an empty box, the same reading), a **sort wanting**
(a type laid face down to hold a place, to be corrected at proof), a
**press variant** with no other cause, and **division**. None of them is called
foul case any more; the twenty-two that still are, are wrong letters.

**The report.** `manual.report.txt`, under WHAT THE COMPOSITOR DID:
*habit given up for the measure* — the habit he had and then set the copy's
spelling instead, because the line wanted the longer form. About a tenth of all
his habits, which is roughly what Blayney's `-ie` counts imply.

## Rebuilding

```sh
sh examples/manual/regenerate.sh
```

`manual.md` and `manual.xml` are the sources; the three directories are output
and are not tracked.
