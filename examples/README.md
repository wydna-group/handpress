# Examples

Everything this program generates for looking at lives here, and nowhere else.

## Where the pages are

Open any of these in a browser:

```
examples/floyd/md/floyd.html          Floyd, from markdown + YAML
examples/floyd/xml/floyd.html         the same book, from the TCP original
examples/floyd/html/floyd.html        …from HTML
examples/floyd/docx/floyd.html        …from a Word document
examples/floyd/tex/floyd.html         …from LaTeX
examples/floyd/pdf/floyd.html         …from a PDF
examples/floyd/txt/floyd.html         …from plain text, which declares nothing

examples/manual/md/manual.html        the Manual, 1614, from markdown
examples/manual/xml/manual.html       the same, from the TCP original
examples/manual/late/manual.html      the same copy set in 1670
```

Beside each `.html` sits the `.tei.xml` it was built from, the
`.report.txt` analysis, the plain-text `.facsimile.txt`, and one
`.copy-*.txt` per made-up copy.

## The two sets, and why there are two

| | holds fixed | varies | the question it answers |
|---|---|---|---|
| **[`floyd/`](floyd/README.md)** | the shop | the **input format** | how much of a book survives being read out of a Word file, a PDF, plain text? |
| **[`manual/`](manual/README.md)** | the text | the **shop** | what does the same copy become when it is set in 1614 and again in 1670? |

Each has its own README saying what to look for.

## Rebuilding

```sh
sh examples/floyd/regenerate.sh
sh examples/manual/regenerate.sh
```

Run from the repository root. Both take a couple of minutes.

## What is and is not committed

The sources (`floyd.*`, `manual.*`) and the output directories are **not** in
git: they are derived from the EEBO-TCP corpus, which is not ours to publish,
and they are regenerable from the scripts above. The READMEs and the scripts
are committed, so a fresh clone knows how to make them.
