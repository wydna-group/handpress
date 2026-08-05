#!/usr/bin/env python3
"""Pull copy and metadata out of a PDF, for import.rkt.

Writes markdown on stdout: YAML front matter from the Info dictionary, ATX
headings from the outline, paragraphs from the page text. import.rkt then
reads the result through its markdown reader, so this file only has to know
about PDFs and nothing about the press.

A PDF is the weakest source this program accepts, and the reason is worth
stating rather than hiding. It has thrown its structure away by construction:
the file records where marks go on a page, not what the marks mean. Two things
survive -- the Info dictionary, because it is metadata rather than layout, and
the outline, because a table of contents has to be clickable. Everything else
has to be reconstructed, and the reconstruction is guesswork:

  * Lines are rejoined into paragraphs on the evidence of indentation, of a
    line ending short, and of terminal punctuation. A paragraph broken over a
    page is joined across the break.
  * A word divided at a line end is put back together, which loses the fact
    that it was divided -- but that division belonged to the PDF's own
    typesetting, and this program is about to make its own.
  * Running heads and page numbers are dropped where the same short line
    recurs on most pages, which is what a running head is.

None of that is reliable in the way a heading in a Word file is reliable, and
the report says so.
"""

import re
import sys
from collections import Counter


def outline_headings(doc):
    """The outline, flattened to (level, title). Empty if the author made none."""
    try:
        toc = doc.get_toc(simple=True)
    except Exception:
        return []
    return [(lvl, title.strip()) for lvl, title, _page in toc if title.strip()]


def running_heads(pages):
    """Short lines that recur on most pages: running titles and page numbers."""
    first_last = Counter()
    for lines in pages:
        for line in (lines[:1] + lines[-1:]):
            t = re.sub(r"\d+", "#", line.strip())
            if 0 < len(t) < 70:
                first_last[t] += 1
    threshold = max(3, len(pages) // 2)
    return {t for t, n in first_last.items() if n >= threshold}


def join_lines(lines):
    """Rejoin lines into paragraphs.

    A line that ends well short of the block's usual width, or ends in
    terminal punctuation, ends a paragraph; anything else runs on.
    """
    if not lines:
        return []
    widths = sorted(len(l) for l in lines if l.strip())
    if not widths:
        return []
    full = widths[int(len(widths) * 0.9)] if widths else 60

    paras, buf = [], []
    for line in lines:
        t = line.strip()
        if not t:
            if buf:
                paras.append(" ".join(buf))
                buf = []
            continue
        # a word divided at the line end
        if t.endswith("-") and not t.endswith("--"):
            buf.append(t[:-1])
            buf.append("\x00")          # marks a join with no space
            continue
        buf.append(t)
        if len(t) < full * 0.75 or t[-1] in ".!?":
            paras.append(" ".join(buf))
            buf = []
    if buf:
        paras.append(" ".join(buf))
    return [re.sub(r"\s*\x00\s*", "", p).strip() for p in paras if p.strip()]


def main():
    if len(sys.argv) < 2:
        print("usage: pdf-to-copy.py FILE.pdf", file=sys.stderr)
        return 2
    try:
        import fitz
    except ImportError:
        print("PyMuPDF is not installed (pip install pymupdf)", file=sys.stderr)
        return 3

    doc = fitz.open(sys.argv[1])
    info = doc.metadata or {}

    out = []
    meta = {
        "title": (info.get("title") or "").strip(),
        "author": (info.get("author") or "").strip(),
        "publisher": (info.get("producer") or "").strip(),
        "date": (info.get("creationDate") or "").strip(),
    }
    # A PDF's creation date is D:20220314... ; only the year is any use here.
    m = re.search(r"(1[5-9]\d\d|20\d\d)", meta["date"])
    meta["date"] = m.group(1) if m else ""
    # The producer is the software that made the file, not a publisher, unless
    # it happens to look like a name rather than a version string.
    if re.search(r"\d\.\d|Acrobat|Distiller|Ghostscript|LaTeX|Word|Quartz",
                 meta["publisher"], re.I):
        meta["publisher"] = ""

    kept = {k: v for k, v in meta.items() if v}
    if kept:
        out.append("---")
        for k, v in kept.items():
            out.append('%s: "%s"' % (k, v.replace('"', "'")))
        out.append("---")
        out.append("")

    pages = [p.get_text().split("\n") for p in doc]
    heads = running_heads(pages)
    titles = {t.lower(): lvl for lvl, t in outline_headings(doc)}

    for lines in pages:
        body = [l for l in lines
                if re.sub(r"\d+", "#", l.strip()) not in heads
                and not re.fullmatch(r"\s*\d+\s*", l)]
        for para in join_lines(body):
            lvl = titles.get(para.lower())
            if lvl:
                out.append("#" * min(6, lvl) + " " + para)
            else:
                out.append(para)
            out.append("")

    sys.stdout.write("\n".join(out).rstrip() + "\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
