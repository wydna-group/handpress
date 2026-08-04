"""Build an attestation lexicon from a corpus of early modern printed text.

    python tools/build-lexicon.py CORPUS_DIR [-o lexicon.rktd] [--min 2]

CORPUS_DIR is walked for .xml (EEBO-TCP TEI) and .txt files. The output is a
Racket-readable data file: every spelling that actually occurs, with its count,
grouped into sets of variants of one another.

Why this exists
---------------
The simulation used to change spelling by rule -- strip a terminal e, double a
consonant, add an e to fill out a line -- with nothing checking the result
against a real book. Counted against 24,000 words of Q1600 and F1623, nine of
the "long forms" it could produce (theere, wheere, manne, somme, welle, wille,
himme, themme, whenne) do not occur once. They are not early modern spellings;
they are what a rule produces when nothing validates it.

So the lexicon becomes the authority and the rules only rank candidates that
are already in it. A rule that can only choose among attested forms cannot
invent one.

Grouping
--------
Variants are found without a modern dictionary, by reducing each form to a
skeleton that collapses the alternations the period actually used -- long s,
u/v, i/j, terminal e, doubled letters. Forms sharing a skeleton are variants:

    heere / here          -> her
    doe / do              -> do
    sinne / sin           -> sin

The collapse is deliberately conservative. It does not touch ea/ee, ou/oo or
-ie/-y endings, because those distinguish words that are genuinely different
(here/hear, boot/bout), and a false merge would put a wrong reading into the
compositor's hand -- the exact failure this file exists to prevent.
"""

import argparse
import os
import re
import sys
from collections import Counter, defaultdict

# TEI/EEBO-TCP markup we want gone before tokenising. The TCP files use <g>
# for special characters and carry a lot of apparatus that is not the text.
DROP_ELEMENTS = re.compile(
    r"<(teiHeader|figure|note|speaker|stage|head)\b.*?</\1>", re.S | re.I)
TAGS = re.compile(r"<[^>]+>")
ENTITIES = re.compile(r"&[#\w]+;")

WORD = re.compile(r"[a-zſ']+")


def text_of(path):
    try:
        raw = open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return ""
    if path.lower().endswith((".xml", ".sgm", ".sgml", ".html")):
        raw = DROP_ELEMENTS.sub(" ", raw)
        # a word broken across a line in the original is rejoined
        raw = re.sub(r"<g\s+ref=\"char:EOLhyphen\"\s*/>\s*", "", raw, flags=re.I)
        raw = TAGS.sub(" ", raw)
        raw = ENTITIES.sub(" ", raw)
    return raw


def tokens(raw):
    raw = raw.replace("ſ", "s").replace("’", "'").lower()
    for w in WORD.findall(raw):
        w = w.strip("'")
        if len(w) > 1 or w in ("a", "i", "o"):
            yield w


def skeleton(w):
    """Reduce a form to what it shares with its variants.

    Only the alternations that are purely orthographic in this period are
    collapsed. Anything that could distinguish two different words is left
    alone.

    The length guard is not a detail. Without it the collapse merges `as` with
    `asse` and `at` with `ate` -- different words, run together because they
    happen to differ by a doubled letter and a terminal e. A false merge is
    worse than a missed one: it puts a wrong reading into the compositor's
    hand, which is the failure this file exists to prevent. So a reduction is
    only made when it leaves a stem of at least three letters.

    That guard also declines to merge `do` with `doe`, which is correct
    behaviour and not a shortcoming: no rule about letters can tell that pair
    from `at`/`ate`, because orthographically they are the same case. Short
    function words are handled by the curated table in orthography.rkt, every
    entry of which has been checked against the corpus.
    """
    s = w.replace("v", "u").replace("j", "i")   # one letter, two shapes
    collapsed = re.sub(r"([a-z])\1", r"\1", s)
    if len(collapsed) >= 3:
        s = collapsed
    if s.endswith("e") and len(s) - 1 >= 3:
        s = s[:-1]
    return s or w


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("corpus")
    ap.add_argument("-o", "--out", default="lexicon.rktd")
    ap.add_argument("--min", type=int, default=2,
                    help="ignore forms occurring fewer than this many times; "
                         "a hapax in a keyed corpus is as likely to be a "
                         "transcription slip as a spelling")
    ap.add_argument("--modern", metavar="WORDLIST",
                    help="a list of modern English words, one per line. "
                         "Without it the grouping merges her with here and "
                         "wonne with wone, because no rule about letters can "
                         "tell a variant spelling from a different word. Two "
                         "forms that are both modern words are never treated "
                         "as spellings of one another.")
    args = ap.parse_args()

    modern = set()
    if args.modern:
        with open(args.modern, encoding="utf-8", errors="replace") as f:
            modern = {w.strip().lower() for w in f if w.strip()}
        print("modern wordlist: %d words" % len(modern), file=sys.stderr)

    counts = Counter()
    files = 0
    for root, _, names in os.walk(args.corpus):
        for n in names:
            if not n.lower().endswith((".xml", ".sgm", ".sgml", ".txt", ".html")):
                continue
            counts.update(tokens(text_of(os.path.join(root, n))))
            files += 1
            if files % 200 == 0:
                print("  %d files, %d distinct forms" % (files, len(counts)),
                      file=sys.stderr)

    counts = Counter({w: c for w, c in counts.items() if c >= args.min})

    groups = defaultdict(list)
    for w, c in counts.items():
        groups[skeleton(w)].append((w, c))

    # A group may hold two different words that merely look alike after the
    # reduction -- her and here, wonne and wone. No rule about letters can
    # separate those, because orthographically they are the same case as
    # breake and break. A modern wordlist can: a form that is itself a
    # standard word is not a variant spelling of another standard word.
    #
    # Given one, each group is split so that every modern word keeps its own
    # variants and takes none of its neighbour's. Without one the groups are
    # left whole and the caller is warned.
    def distance(a, b):
        prev = list(range(len(b) + 1))
        for i, ca in enumerate(a, 1):
            cur = [i]
            for j, cb in enumerate(b, 1):
                cur.append(min(prev[j] + 1, cur[j - 1] + 1,
                               prev[j - 1] + (ca != cb)))
            prev = cur
        return prev[-1]

    def split(forms):
        mods = [w for w, _ in forms if w in modern]
        if len(mods) < 2:
            return [forms]
        # Each variant belongs to the one modern word it is nearest to, not to
        # every one it happens to resemble. `heere' is one letter from `here'
        # and two from `her', so it goes to `here' alone.
        freq = dict(forms)
        buckets = {m: [(m, freq[m])] for m in mods}
        for w, c in forms:
            if w in modern:
                continue
            best = min(mods, key=lambda m: (distance(w, m), -freq[m]))
            buckets[best].append((w, c))
        # No fallback to the unsplit group. If every modern word in the group
        # turns out to have no variants of its own, the right answer is that
        # there are no variants here at all -- not that the whole group is one
        # word after all. Returning [forms] put `not' and `note' back together
        # (436 and 12 occurrences, both ordinary English words), and a device
        # then set `note' for `not' on the authority of the lexicon itself.
        return [v for v in buckets.values() if len(v) > 1]

    varied = {}
    for k, v in groups.items():
        if len(v) < 2:
            continue
        parts = split(v) if modern else [v]
        for i, part in enumerate(parts):
            if len(part) > 1:
                key = k if i == 0 else "%s~%d" % (k, i)
                varied[key] = sorted(part, key=lambda p: -p[1])

    if not modern:
        print("warning: no --modern wordlist given, so groups may merge "
              "different words (her/here). Pass one for a clean lexicon.",
              file=sys.stderr)

    with open(args.out, "w", encoding="utf-8") as f:
        f.write(";; Generated by tools/build-lexicon.py -- do not edit.\n")
        f.write(";; %d files, %d attested forms, %d variant groups.\n" %
                (files, len(counts), len(varied)))
        f.write("((attested\n")
        for w, c in sorted(counts.items()):
            f.write('  ("%s" . %d)\n' % (w, c))
        f.write(" )\n (variants\n")
        for k in sorted(varied):
            forms = " ".join('("%s" . %d)' % (w, c) for w, c in varied[k])
            f.write('  ("%s" %s)\n' % (k, forms))
        f.write(" ))\n")

    print("%d files, %d attested forms, %d variant groups -> %s"
          % (files, len(counts), len(varied), args.out))


if __name__ == "__main__":
    main()
