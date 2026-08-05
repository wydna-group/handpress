#!/usr/bin/env python3
"""Turn an EEBO-TCP transcription into copy for the press.

The job is not parsing but *preparing copy*, in the sense tools/strip-gutenberg.py
means it: what comes out has to be what a compositor was handed, not what a
modern edition looks like. So the page-breaks, the gaps, the editorial notes and
the TCP word-division marks all go, wrapped lines are joined so that a paragraph
reaches the frame whole, and verse stays broken where the poet broke it.

Two modes, and the difference is the point of the exercise:

    --plain     headings as headings.  The program must GUESS which of them
                are preliminary, from its vocabulary and their position.

    --declare   headings marked with the TCP editors' own div type, as
                "# [dedication] The Epistle Dedicatorie".  The program OBEYS.

Run it both ways on the same book and the guess can be scored against the
markup, which is the only way to find out whether the vocabulary is any good.

    python tools/tcp-to-copy.py corpus/texts/A00024.headed.xml -o out.txt
    python tools/tcp-to-copy.py corpus/texts/A00024.headed.xml -o out.txt --declare
"""

import argparse
import html
import re
import sys

# TCP div types -> the kinds prelims.rkt knows. Anything not here is text, and
# is deliberately not declared: the point of declaring is to say what the
# markup actually asserts, not to improve on it.
KINDS = {
    "title page": "title-page",
    "half title": "half-title",
    "dedication": "dedication",
    "epistle dedicatory": "dedication",
    "to the reader": "preface",
    "preface": "preface",
    "epistle": "preface",
    "proem": "preface",
    "table of contents": "contents",
    "contents": "contents",
    "index": "contents",
    "errata": "errata",
    "argument": "argument",
    "to the author": "commendatory",
    "commendatory verses": "commendatory",
    "dramatis personae": "persons",
    "license": "licence",
    "licence": "licence",
    "imprimatur": "licence",
    "advertisement": "advertisement",
}

# What to call a division that carries no heading of its own. A title page or a
# dedication often has none -- the words on the page are the heading -- and
# without something the walk has nothing to open a block on.
SUPPLIED = {
    "dedication": "The Epistle Dedicatorie",
    "title page": "Title-page",
    "to the reader": "To the Reader",
    "preface": "The Preface",
    "table of contents": "The Table",
    "argument": "The Argument",
    "to the author": "To the Author",
    "errata": "Errata",
}

DROP = re.compile(
    r"<(PB|GAP|FIGURE|NOTE|MILESTONE|CB)\b[^>]*/?>|</(NOTE|FIGURE)>", re.I)
TAG = re.compile(r"<[^>]+>")


def clean(text):
    text = DROP.sub(" ", text)
    text = TAG.sub(" ", text)
    text = html.unescape(text)
    # TCP marks a word divided at a line-end with U+2223; the division is an
    # accident of the original setting and must not survive into the copy,
    # which is what the compositor is going to divide for himself.
    text = text.replace("∣", "")
    text = text.replace("‧", "")
    return re.sub(r"\s+", " ", text).strip()


def convert(path, declare=False, limit=None, keep_title=False):
    src = open(path, encoding="utf-8", errors="replace").read()
    body = src[src.find("<TEXT"):] if "<TEXT" in src else src
    out = []

    # One pass over the divisions and their contents, in order.
    tokens = re.finditer(
        r"<DIV[0-9][^>]*TYPE=\"([^\"]+)\"[^>]*>|<HEAD>(.*?)</HEAD>"
        r"|<L\b[^>]*>(.*?)</L>|<P\b[^>]*>(.*?)</P>",
        body, re.S | re.I)

    pending = None          # a div whose heading we have not seen yet
    skipping = False
    for m in tokens:
        div, head, line, para = m.group(1), m.group(2), m.group(3), m.group(4)
        if div is not None:
            pending = div.lower()
            # The printed title-page of the original is not copy for a new
            # setting. A compositor working from manuscript was given the
            # title and the imprint separately, and handpress generates one;
            # keeping this would put two title-pages in the book. Reprint copy
            # really did include it, hence the flag.
            skipping = (pending == "title page" and not keep_title)
            continue

        if skipping and div is None:
            continue

        if head is not None:
            text = clean(head)
            if not text:
                continue
            kind = KINDS.get(pending or "")
            if declare and kind:
                out.append("# [%s] %s" % (kind, text))
            else:
                out.append("# " + text)
            out.append("")
            pending = None
            continue

        # A division with no heading of its own still has to be announced, or
        # its opening paragraph is indistinguishable from the end of whatever
        # came before it.
        if pending is not None:
            supplied = SUPPLIED.get(pending)
            if supplied:
                kind = KINDS.get(pending)
                if declare and kind:
                    out.append("# [%s] %s" % (kind, supplied))
                else:
                    out.append("# " + supplied)
                out.append("")
            pending = None

        if line is not None:
            text = clean(line)
            if text:
                out.append(text)
            continue

        if para is not None:
            text = clean(para)
            if text:
                out.append(text)
                out.append("")

    text = "\n".join(out)
    text = re.sub(r"\n{3,}", "\n\n", text)
    if limit:
        text = text[:limit]
    return text.strip() + "\n"


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("input")
    ap.add_argument("-o", "--out")
    ap.add_argument("--declare", action="store_true",
                    help="mark each heading with the TCP editors' div type")
    ap.add_argument("--limit", type=int, help="stop after N characters")
    ap.add_argument("--keep-title-page", action="store_true",
                    help="keep the original's printed title-page as copy "
                         "(a reprint had one; a first edition did not)")
    a = ap.parse_args()

    text = convert(a.input, declare=a.declare, limit=a.limit,
                   keep_title=a.keep_title_page)
    if a.out:
        open(a.out, "w", encoding="utf-8").write(text)
        heads = len(re.findall(r"^# ", text, re.M))
        print("%s: %d characters, %d headings%s"
              % (a.out, len(text), heads, ", declared" if a.declare else ""),
              file=sys.stderr)
    else:
        sys.stdout.write(text)


if __name__ == "__main__":
    main()
