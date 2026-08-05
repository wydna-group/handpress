# One book, seven ways in

Thomas Floyd, *The Picture of a Perfit Common Wealth* (London, 1600) —
EEBO-TCP `A01013`, chosen because it declares a dedication, an address to the
reader and a table of contents, and then runs on in numbered chapters.

`floyd.*` are the same book converted into each of the formats `import.rkt`
accepts, **carrying the same divisions and the same metadata in every one**, so
that any difference in the books that come out is the format's own doing and
not the conversion's. `floyd.xml` is the TCP original, unaltered.

Open `<format>/floyd.html` for the type-facsimile, built from
`<format>/floyd.tei.xml` and from nothing else. `floyd.report.txt` is the
analysis.

| in | collation | declared | what the format could say |
|---|---|---|---|
| `md` | `4°: *⁴ A–E⁴` | 3 | YAML metadata; Pandoc `::: dedication` |
| `html` | `4°: *⁴ A–E⁴` | 3 | `<meta>`; `<section class="dedication">` |
| `docx` | `4°: *⁴ A–E⁴` | 3 | `docProps/core.xml`; paragraph styles |
| `xml` | `4°: a⁴ A–Q⁴` | 3 | `<div type="dedication">`; `<teiHeader>` |
| `tex` | `4°: a⁴ A–E⁴` | 2 | `\title`/`\author`; `\frontmatter` |
| `pdf` | `4°: *² A–B⁴ C²` | 1 | the Info dictionary and the outline |
| `txt` | `4°: *² A–E⁴` | **0** | nothing |

The last row is the point. Same words, and the plain-text book loses two leaves
of preliminaries — because nothing in a text file can say that a paragraph is a
dedication, so the book honestly has none. Its title-page is generated from the
command line rather than from the document, and names a bookseller the file
never mentioned.

`xml` is longer than the rest only because the derived formats were cut to
fourteen chapters to keep them readable; the TCP original was left whole.

`pdf` is short for a different and more interesting reason: a PDF has thrown
its structure away by construction, so `tools/pdf-to-copy.py` recovers only the
Info dictionary and the outline and rejoins lines into paragraphs by guess. Its
preliminaries were small enough to be printed in the white leaves of the last
sheet and cut out — McKerrow's economy — which is why `C` is bound as a
two-leaf gathering.

The `floyd.*` sources were made with `tools/tcp-to-copy.py` and a conversion
script. To rebuild the seven books from them:

```sh
sh review/regenerate.sh
```

One seed, one shop, one edition size for all seven, so that the only variable
left is the format.
