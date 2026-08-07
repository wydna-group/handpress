#!/usr/bin/env python3
"""Assemble the First Folio as copy for the press, in the order of 1623.

    python tools/fetch-folio.py            -> folio/

Nothing here is committed: about 5 MB of text belonging to other people, on
the same footing as corpus/ and the sources/ PDFs. This script rebuilds it.

WHAT IT FETCHES, AND WHY FROM THERE

  The 36 plays, from Project Gutenberg's Complete Works (ebook 100), split
  on its own headings. Modern spelling, one edition throughout, public
  domain. That consistency is the point: the simulator's whole job is to
  turn modern copy into period spelling and then measure how far the print
  has moved from its copy, so the copy has to be modern and it has to be
  uniform.

  The Folger Shakespeare Library's digital texts were the first choice and
  had to be abandoned. Their download endpoint prefix-matches the slug, so
  `henry-v` swallows `henry-vi-part-1`, `henry-vi-part-2`, `henry-vi-part-3`
  and `henry-viii`, and `richard-ii` swallows `richard-iii`: six of the
  thirty-six came back as a duplicate of another play, with HTTP 200 and a
  perfectly well-formed file. Even the TEI zip had `henry-v` as its internal
  filename. Checking that a download succeeds is not checking that it is the
  thing you asked for, which is why `main` below verifies that all 36 texts
  are distinct and that each one's heading is the play it should be.

  The front matter, from the Wikisource transcription of the 1910 facsimile.
  Eight pieces: Jonson's verses facing the portrait, the dedication to the
  Herberts, the address to the great Variety of Readers, the four
  commendatory poems, and the names of the principal actors.

  **The front matter is in ORIGINAL 1623 SPELLING and the plays are not.**
  This is not a choice, it is what exists: no free modern-spelling edition of
  the Folio preliminaries could be found, and the alternative -- modernising
  them here -- would be worse than the inconsistency. It would make this
  script the editor of its own test data, and it would apply exactly the
  orthographic knowledge the simulator encodes, so those sections would
  round-trip perfectly and prove nothing.

  It is 2,122 words against 862,347, or 0.25% of the copy. Read the
  departure statistics for the preliminaries separately from the text, or
  not at all: comparing a set form against copy that is already period
  spelling measures nothing, which is the trap recorded at the foot of
  ROADMAP.md. The rest of the machinery -- printing the preliminaries last,
  signing them apart, the Table, cutting them from the white paper of the
  last sheet -- is exercised properly either way, and that is what the front
  matter is here for.

THE CATALOGUE is not transcribed on Wikisource and is not supplied. The
program builds its own table of contents out of the play headings, which
exercises contents-from-headings and McKerrow's decision about whether the
Table goes in front or at the back -- more of the machinery than a copied
list would have.

WHAT IS DROPPED. Each Folger file opens with an edition credit, a URL and a
build date. That is modern apparatus and no compositor of 1623 could have set
it, so it goes. The "Characters in the Play" lists are kept: the Folio prints
the names of the actors for several plays, so they are period-plausible, and a
list of short lines is useful copy for the measure.

TWO FORMATS, on purpose, because import.rkt reads them differently:

    folio.tei.xml   DECLARED   <div type="dedication"> and the rest, so the
                               preliminaries are obeyed rather than guessed
    folio.md        CONSTRUCTED  YAML gives a title-page, headings give a
                               table of contents, and nothing is declared

Run the simulation on the TEI to exercise the declared path.
"""

import json
import os
import re
import sys
import urllib.parse
import urllib.request
from html import unescape

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "folio")
UA = {"User-Agent": "handpress-corpus/1.0 (bibliographical simulation; research)"}

# The order of the 1623 Catalogue: Comedies, then Histories, then Tragedies.
# Troilus and Cressida sits between the Histories and the Tragedies and is
# absent from the Catalogue altogether -- a famous accident of the printing,
# and it is placed here where it actually falls in the book.
PLAYS = [
    ("COMEDIES",  "THE TEMPEST", "The Tempest"),
    (None, "THE TWO GENTLEMEN OF VERONA", "The Two Gentlemen of Verona"),
    (None, "THE MERRY WIVES OF WINDSOR", "The Merry Wives of Windsor"),
    (None, "MEASURE FOR MEASURE", "Measure for Measure"),
    (None, "THE COMEDY OF ERRORS", "The Comedy of Errors"),
    (None, "MUCH ADO ABOUT NOTHING", "Much Ado About Nothing"),
    (None, "LOVE’S LABOUR’S LOST", "Love's Labour's Lost"),
    (None, "A MIDSUMMER NIGHT’S DREAM", "A Midsummer Night's Dream"),
    (None, "THE MERCHANT OF VENICE", "The Merchant of Venice"),
    (None, "AS YOU LIKE IT", "As You Like It"),
    (None, "THE TAMING OF THE SHREW", "The Taming of the Shrew"),
    (None, "ALL’S WELL THAT ENDS WELL", "All's Well That Ends Well"),
    (None, "TWELFTH NIGHT; OR, WHAT YOU WILL", "Twelfth Night, or What You Will"),
    (None, "THE WINTER’S TALE", "The Winter's Tale"),
    ("HISTORIES", "THE LIFE AND DEATH OF KING JOHN", "The Life and Death of King John"),
    (None, "KING RICHARD THE SECOND", "The Tragedy of King Richard the Second"),
    (None, "THE FIRST PART OF KING HENRY THE FOURTH", "The First Part of King Henry the Fourth"),
    (None, "THE SECOND PART OF KING HENRY THE FOURTH", "The Second Part of King Henry the Fourth"),
    (None, "THE LIFE OF KING HENRY THE FIFTH", "The Life of King Henry the Fifth"),
    (None, "THE FIRST PART OF HENRY THE SIXTH", "The First Part of King Henry the Sixth"),
    (None, "THE SECOND PART OF KING HENRY THE SIXTH", "The Second Part of King Henry the Sixth"),
    (None, "THE THIRD PART OF KING HENRY THE SIXTH", "The Third Part of King Henry the Sixth"),
    (None, "KING RICHARD THE THIRD", "The Tragedy of King Richard the Third"),
    (None, "KING HENRY THE EIGHTH", "The Life of King Henry the Eighth"),
    ("TRAGEDIES", "TROILUS AND CRESSIDA", "The Tragedy of Troilus and Cressida"),
    (None, "THE TRAGEDY OF CORIOLANUS", "The Tragedy of Coriolanus"),
    (None, "THE TRAGEDY OF TITUS ANDRONICUS", "The Lamentable Tragedy of Titus Andronicus"),
    (None, "THE TRAGEDY OF ROMEO AND JULIET", "The Tragedy of Romeo and Juliet"),
    (None, "THE LIFE OF TIMON OF ATHENS", "The Life of Timon of Athens"),
    (None, "THE TRAGEDY OF JULIUS CAESAR", "The Tragedy of Julius Caesar"),
    (None, "THE TRAGEDY OF MACBETH", "The Tragedy of Macbeth"),
    (None, "THE TRAGEDY OF HAMLET, PRINCE OF DENMARK", "The Tragedy of Hamlet, Prince of Denmark"),
    (None, "THE TRAGEDY OF KING LEAR", "The Tragedy of King Lear"),
    (None, "THE TRAGEDY OF OTHELLO, THE MOOR OF VENICE", "The Tragedy of Othello, the Moor of Venice"),
    (None, "THE TRAGEDY OF ANTONY AND CLEOPATRA", "The Tragedy of Antony and Cleopatra"),
    (None, "CYMBELINE", "The Tragedy of Cymbeline"),
]

# (key, wikisource title, TEI div type, heading, the initial the transcription
# dropped because the Folio set it as a decorative capital)
FRONT = [
    ("to-the-reader", "To the Reader",
     "to the reader", "To the Reader", None),
    ("dedication", "To the Most Noble and Incomparable Paire of Brethren",
     "dedication", "To the Most Noble and Incomparable Paire of Brethren", None),
    ("readers", "To the Great Variety of Readers",
     "preface", "To the great Variety of Readers", "F"),
    ("jonson", "To the Memory of My Beloved, the Author Mr. William Shakespeare:"
               " And What He Hath Left Us",
     "commendatory", "To the memory of my beloued, the Author", None),
    ("holland", "Upon the Lines and Life of the Famous Scenicke Poet,"
                " Master William Shakespeare",
     "commendatory", "Vpon the Lines and Life of the Famous Scenicke Poet", "T"),
    ("digges", "To the Memorie of the deceased Authour Maister W. Shakespeare",
     "commendatory", "To the Memorie of the deceased Authour", "S"),
    ("im", "To the memorie of M. W. Shake-speare",
     "commendatory", "To the memorie of M. W. Shake-speare", None),
    ("actors", "The Names of the Principall Actors in all these Playes",
     "dramatis personae", "The Names of the Principall Actors in all these Playes",
     None),
]

WS_BASE = "Shakespeare - First Folio facsimile (1910)/"
GUTENBERG = "https://www.gutenberg.org/cache/epub/100/pg100.txt"


def get(url):
    return urllib.request.urlopen(
        urllib.request.Request(url, headers=UA), timeout=120).read().decode("utf-8")


def wikisource(title):
    """The rendered text of one Wikisource page, stripped to its words.

    Deliberately not the wikitext: these pages are <pages> transclusions of
    the Page: namespace, so action=raw returns a header and nothing else.
    """
    q = urllib.parse.urlencode({"action": "parse", "page": WS_BASE + title,
                                "prop": "text", "format": "json",
                                "formatversion": "2"})
    d = json.loads(get("https://en.wikisource.org/w/api.php?" + q))
    t = d["parse"]["text"]
    for pat in (r"<style.*?</style>", r"<sup.*?</sup>", r"<table.*?</table>"):
        t = re.sub(pat, "", t, flags=re.S)
    t = re.sub(r"<br\s*/?>", "\n", t)
    t = re.sub(r"</p>|</div>|</dd>|</li>|</h\d>", "\n", t)
    t = unescape(re.sub(r"<[^>]+>", "", t))
    # The navigation block -- previous/next links, the site name, the arrows --
    # ends at a zero-width space, and every one of these pages has exactly one.
    # Filtering the nav by pattern instead lets the previous page's title
    # through as if it were the first line of the text.
    i = t.find("​")
    if i != -1:
        t = t[i + 1:]
    return re.sub(r"\n{3,}", "\n\n", t).strip()


def restore_initial(text, letter):
    """Put back the decorative capital the transcription rendered separately.

    The Folio opens these three with a large ornamental initial, which the
    facsimile transcription carries as an image, so the text begins "Rom the
    most able" where the page reads "From the most able". The letter is not a
    guess in any of the three cases; leaving it off would put a word in the
    compositor's copy that no copy ever had.
    """
    if not letter:
        return text
    lines = text.split("\n")
    for i, ln in enumerate(lines):
        if not ln.strip():
            continue
        if i == 0:                      # the heading
            continue
        lines[i] = letter + ln.lstrip()
        break
    return "\n".join(lines)


def strip_markers(text):
    """Take out Gutenberg's italic markers, which are not words.

    Gutenberg marks italic with underscores -- `_Exit Caliban._`, `[_To
    Ferdinand._]` -- and they were going through to the compositor and being
    set as type: 125 of them in The Tempest alone, printing as underscores on
    the page. No compositor ever set one. Comparing our page against the
    Norton plate is what showed it; nothing in the statistics would have,
    because an underscore is just another sort as far as the model is
    concerned.

    The italic itself is a real distinction the Folio observes for stage
    directions, but the program takes that from the copy's structure rather
    than from inline marks, so nothing is lost by removing them.
    """
    text = re.sub(r"_([^_\n]{1,200}?)_", r"\1", text)
    text = text.replace("_", "")
    # `[Exit Caliban.]` is how the program's own reader recognises a stage
    # direction, so the brackets stay; it is the underscores inside them that
    # had to go.
    return text


def strip_folger_header(text):
    """Drop the modern edition credit; keep everything from the first heading.

    Folger files open with the title, the editors, a URL and a build date,
    then the first setext heading. All of that is apparatus of 2015 and would
    be absurd set in a book of 1623.
    """
    lines = text.split("\n")
    for i in range(1, len(lines)):
        if re.match(r"^=+$", lines[i].strip()) and lines[i - 1].strip():
            return "\n".join(lines[i - 1:]).strip()
    return text.strip()


SPEECH_PREFIX = re.compile(r"^[A-Z][A-Z’'. ]{1,28}\.$")


def is_prose(block):
    """Is this speech prose, or verse?

    It has to be decided here, per speech, and it cannot be left to the
    program's own `looks-like-verse?' -- which asks whether a line is under 78
    characters, a fair rule for copy whose line breaks mean something and a
    useless one for copy wrapped by a machine at 72.

    That is not hypothetical. Emitting every line as <l> made every wrapped
    prose line look like a verse line, and the model then classified **94% of
    the Folio as verse against a true 73%**. The true figure is not a guess:
    the Norton facsimile divides words at 6.41 per 100 lines in the prose
    plays and 0.40 in the verse plays, and the whole book at 2.03, which
    solves for 73% verse -- and that agrees with the usual literary estimate
    of 70-75%. Verse turns over where prose divides, so getting the split
    wrong suppressed word division across the whole book.

    Gutenberg wraps prose hard at about 72 characters and breaks verse at the
    metre, so the signal is the length of a speech's non-final lines: measured
    over Macbeth and the Merry Wives, verse speeches average 41 characters and
    prose speeches 68. Fifty separates them cleanly.

    A one-line speech shorter than the wrap width is genuinely ambiguous --
    nothing in the copy distinguishes a short prose speech from a verse line
    -- and is left as verse, which is the commoner case in a play.
    """
    lines = [l.strip() for l in block.split("\n") if l.strip()]
    lines = [l for l in lines if not SPEECH_PREFIX.match(l)]
    if not lines:
        return False
    if len(lines) == 1:
        return len(lines[0]) >= 62
    body = lines[:-1]                       # the last line is short by nature
    return (sum(len(l) for l in body) / len(body)) >= 50


def esc(s):
    return (s.replace("&", "&amp;").replace("<", "&lt;")
             .replace(">", "&gt;").replace('"', "&quot;"))


def blocks(text):
    """The units a compositor sets: a speech, a stage direction, a paragraph.

    Gutenberg's plays put a blank line between every verse line and TWO blank
    lines between speeches, so splitting on any blank line -- the obvious
    reading -- makes a separate paragraph of every single line of verse.

    That is not a small tidiness point. Done that way the whole Folio came out
    at 862,518 words in 321,154 lines, which is 2.7 words to a line against a
    16-em column that holds about seven; every line was quadded out to the
    measure because every line was the end of a paragraph; 82% of pages had to
    be spun out; and the book ran to 2,437 pages where the real First Folio is
    about 900. The simulator was working correctly on copy that had been
    mangled before it ever saw it.

    So: two or more blank lines end a speech, one blank line is a line break
    inside it.
    """
    out = []
    for b in re.split(r"\n\s*\n\s*\n+", text):
        # single blank lines inside a speech are line breaks, not paragraphs
        b = re.sub(r"\n\s*\n", "\n", b).strip()
        if b:
            out.append(b)
    return out


def main():
    os.makedirs(OUT, exist_ok=True)
    raw = os.path.join(OUT, "raw")
    os.makedirs(raw, exist_ok=True)

    print("front matter, from Wikisource (original 1623 spelling):")
    front = []
    for key, title, kind, head, initial in FRONT:
        path = os.path.join(raw, "front-%s.txt" % key)
        if os.path.exists(path):
            body = open(path, encoding="utf-8").read()
        else:
            body = restore_initial(wikisource(title), initial)
            open(path, "w", encoding="utf-8").write(body)
        front.append((kind, head, body))
        print("    %-14s %5d words%s" % (key, len(body.split()),
                                         "  (initial %s restored)" % initial
                                         if initial else ""))

    print("plays, from Project Gutenberg ebook 100 (modern spelling):")
    whole = os.path.join(raw, "pg100.txt")
    if not os.path.exists(whole):
        open(whole, "w", encoding="utf-8").write(get(GUTENBERG))
    t = open(whole, encoding="utf-8").read()
    t = t[t.index("*** START OF THE PROJECT GUTENBERG"):
          t.index("*** END OF THE PROJECT GUTENBERG")]

    # The book's own contents list, which is the only reliable way to know
    # which of its many all-capital lines are work titles. Matching any
    # capitalised line instead picks up ACT I, SCENE II and every shouting
    # speech prefix, and the first slice came out one word long.
    head_block = t[:t.index("\nTHE SONNETS\n")]
    titles = [m.group(1).strip() for m in
              re.finditer(r"^ {4}([A-Z][A-Z0-9’',;.\- ]{3,})$", head_block, re.M)]
    if len(titles) < 40:
        raise SystemExit("found only %d titles in the contents" % len(titles))

    # Where each of those titles stands as a heading in the body, flush left.
    #
    # The first occurrence, not the only one: "KING HENRY THE EIGHTH" is both a
    # play and a person, so it appears again a few lines later in that play's
    # Dramatis Personae. Taking the first is safe here and is *checked* rather
    # than assumed -- the body runs in the same order as the contents, so the
    # marks must come out strictly increasing. If they ever do not, a title has
    # matched something that is not its heading and the assertion says so.
    marks = []
    for ti in titles:
        m = re.search(r"^" + re.escape(ti) + r"\s*$", t, re.M)
        if not m:
            raise SystemExit("title %r never appears as a heading" % ti)
        marks.append((m.start(), m.end(), ti))
    for (a, _b, h1), (c, _d, h2) in zip(marks, marks[1:]):
        if a >= c:
            raise SystemExit("%r and %r are out of order; a title has matched "
                             "something that is not its heading" % (h1, h2))

    def slice_for(heading):
        i = [k for k, (a, b, h) in enumerate(marks) if h == heading]
        if len(i) != 1:
            raise SystemExit("heading %r not found once" % heading)
        k = i[0]
        end = marks[k + 1][0] if k + 1 < len(marks) else len(t)
        return t[marks[k][1]:end].strip()

    plays, seen = [], {}
    for i, (section, heading, title) in enumerate(PLAYS, 1):
        body = strip_markers(slice_for(heading))
        # Not a download check but a content check. The Folger endpoint served
        # six wrong plays with HTTP 200 apiece; only comparing the texts caught
        # it. An identical body means the split went wrong.
        h = hash(body)
        if h in seen:
            raise SystemExit("%s is identical to %s" % (title, seen[h]))
        seen[h] = title
        if len(body.split()) < 9000:
            raise SystemExit("%s is only %d words; the split is wrong"
                             % (title, len(body.split())))
        open(os.path.join(raw, "%02d.txt" % i), "w", encoding="utf-8").write(body)
        plays.append((section, title, body))
        print("    %2d %-44s %7d words" % (i, title, len(body.split())))
    print("    all %d distinct, none suspiciously short" % len(plays))

    fw = sum(len(b.split()) for _, _, b in front)
    pw = sum(len(b.split()) for _, _, b in plays)

    # ---- TEI: the declared path -------------------------------------------
    t = ['<?xml version="1.0" encoding="UTF-8"?>',
         '<TEI xmlns="http://www.tei-c.org/ns/1.0">',
         '  <teiHeader><fileDesc><titleStmt>',
         '    <title>Mr. William Shakespeares Comedies, Histories, &amp; Tragedies</title>',
         '    <author>William Shakespeare</author>',
         '  </titleStmt><publicationStmt>',
         '    <publisher>Isaac Iaggard and Ed. Blount</publisher>',
         '    <date>1623</date>',
         '  </publicationStmt><sourceDesc><p>Plays: Folger Shakespeare Library,'
         ' modern spelling. Preliminaries: Wikisource transcription of the 1910'
         ' facsimile, original spelling.</p></sourceDesc>',
         '  </fileDesc></teiHeader>',
         '  <text><body>']
    for kind, head, body in front:
        t.append('    <div type="%s">' % esc(kind))
        t.append('      <head>%s</head>' % esc(head))
        for b in blocks(body)[1:]:          # [0] is the heading, already used
            t.append('      <p>%s</p>' % esc(b))
        t.append('    </div>')
    # <l> per line of the play, not <p> per speech.
    #
    # import.rkt ends a <p> with a blank line and an <l> with a single
    # newline, and copytext.rkt turns every blank line of copy into a white
    # line of TYPE. A play has a paragraph per speech, so <p> put a white line
    # between every two speeches: 37,395 of 178,728 column slots stood empty,
    # 21% of the type page, and the book ran to 1,357 pages against the real
    # Folio's ~900.
    #
    # No compositor did that. Speeches run straight on in the Folio and the
    # speech prefix is what marks the new one -- a blank line between speeches
    # is a modern typographic convention that arrived with the copy, not with
    # the printing house. `parse-copy' flushes on a speech prefix anyway, so
    # the speeches stay separate units without needing to be spaced apart.
    for section, title, body in plays:
        t.append('    <div type="part">')
        t.append('      <head>%s</head>' % esc(title))
        for b in blocks(body):
            if is_prose(b):
                # One paragraph. The line breaks are Gutenberg's wrap and mean
                # nothing; keeping them would present a prose speech to the
                # compositor as a column of short lines.
                t.append('      <p>%s</p>' % esc(" ".join(
                    l.strip() for l in b.split("\n") if l.strip())))
            else:
                for line in b.split("\n"):
                    if line.strip():
                        t.append('      <l>%s</l>' % esc(line.strip()))
        t.append('    </div>')
    t.append('  </body></text>')
    t.append('</TEI>')
    tei_path = os.path.join(OUT, "folio.tei.xml")
    open(tei_path, "w", encoding="utf-8").write("\n".join(t) + "\n")

    # ---- Markdown + YAML: the constructed path -----------------------------
    m = ["---",
         "title: Mr. William Shakespeares Comedies, Histories, & Tragedies",
         "author: William Shakespeare",
         "printer: Isaac Iaggard",
         "publisher: Ed. Blount",
         "year: 1623",
         "---",
         ""]
    for kind, head, body in front:
        m.append("# " + head)
        m.append("")
        m.append("\n\n".join(blocks(body)[1:]))
        m.append("")
    for section, title, body in plays:
        m.append("# " + title)
        m.append("")
        m.append(body)
        m.append("")
    md_path = os.path.join(OUT, "folio.md")
    open(md_path, "w", encoding="utf-8").write("\n".join(m) + "\n")

    print("\n  %-22s %8.1f MB" % ("folio.tei.xml",
                                  os.path.getsize(tei_path) / 1e6))
    print("  %-22s %8.1f MB" % ("folio.md", os.path.getsize(md_path) / 1e6))
    print("  %d words of text, %d of preliminaries (%.2f%%)"
          % (pw, fw, 100.0 * fw / (pw + fw)))


if __name__ == "__main__":
    sys.exit(main())
