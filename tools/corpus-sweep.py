"""Every property of the printed page, the model's against the corpus's.

Six properties of a page have been checked against the corpus by hand over the
life of this project, and **every one of them found a defect**: tildes 83 per
1,000 against a true 1.66, the ampersand 35 against 3.02, and in one afternoon
the discovery that the program had no pointing habit and no capitals at all. A
page has dozens of properties. Which ones get checked has been a matter of
somebody happening to wonder.

So this checks them together, and reports the ones that disagree. It is an
instrument for finding where to look, not an answer about any one row.

    python tools/corpus-sweep.py out-a out-b out-c        # one directory a seed
    python tools/corpus-sweep.py --corpus 400 out-*

TWO RULES ARE BUILT IN, BECAUSE BREAKING EITHER MANUFACTURES DISCREPANCIES THAT
ARE NOT THERE -- which this file's own history has done twice within an hour of
being written:

  * **Distributions, never points.** Every corpus figure is a median over
    documents with a quartile range beside it, and every model figure is a
    median over seeds with its range. A pooled rate over a corpus reads 8.46
    ampersands per 1,000 where the per-document median is 3.2, because a few
    long documents drown the rest. Comparing one number against one number is
    how three "discrepancies" were chased in one session and all three
    dissolved.

  * **One extractor a side, both vetted.** The corpus is TCP transcription and
    the model emits a printed page; the same property is not reached the same
    way in both. Every `&' in the corpus is the entity `&amp;'; a tilde is a
    COMBINING mark and not a precomposed letter. A regex that is right for one
    side and wrong for the other reports a defect in the program that is really
    a defect here.

And it says what it CANNOT compare, which is the half of the answer a sweep
usually leaves out.
"""
import glob, re, sys, io, os, random, statistics, collections

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

WORD = re.compile(r"[A-Za-zſ][A-Za-zſ']*")
OPENER = re.compile(r"[.?!]\s*$")
COMBINING = "̃̄"          # tilde and macron, how TCP carries them
PRECOMPOSED = "ãẽĩõũāēīōū"          # how the model writes them

# --- the properties, with an extractor for each side ------------------------
#
# Each returns a count; the caller divides by the word total. Keeping the two
# sides beside each other in one table is the point: it is the only way to see
# that they are asking the same question.

def _stops(ch):
    return (lambda t: t.count(ch)), (lambda t: t.count(ch))

def _corpus_amp(t):
    # Every ampersand arrives as the entity. `&c' is `etc.' and is not the
    # conjunction, which is the distinction tools/count-scribal.py already makes.
    return len(re.findall(r"&amp;", t)) - len(re.findall(r"&amp;\s*c\b", t))

def _model_amp(t):
    return t.count("&") - len(re.findall(r"&\s*c\b", t))

def _corpus_tilde(t):
    return sum(1 for ch in t if ch in COMBINING)

def _model_tilde(t):
    return sum(1 for ch in t if ch in PRECOMPOSED or ch in COMBINING)

def _lexical_hyphen(t):
    """A hyphen joining one word to another, mid-line and single.

    A RAW HYPHEN COUNT IS NOT A COMPARISON, and this file said so in its own
    incomparable list before its first run reported the model 10x high on it.
    Of the model's 443 hyphens, 198 ended a line -- word division, which the
    corpus cannot show because its text is reflowed -- and others were em rules
    written `--'. What is left, and is the same question on both sides, is the
    hyphen inside a compound: `free-born', `life-blood'.
    """
    n = 0
    for line in t.splitlines():
        line = line.rstrip()
        if line.endswith("-"):
            line = line[:-1]                     # the division, not a compound
        n += len(re.findall(r"(?<=[A-Za-zſ])-(?=[A-Za-zſ])", line))
    return n


def _midcaps(t):
    mid = cap = 0
    prev_ends = True
    for tok in t.split():
        w = WORD.search(tok)
        if w:
            if not prev_ends:
                mid += 1
                if w.group(0)[0].isupper():
                    cap += 1
        prev_ends = bool(OPENER.search(tok))
    return cap, mid

PROPERTIES = [
    ("comma",        lambda t: t.count(","),  lambda t: t.count(","),  1000),
    ("period",       lambda t: t.count("."),  lambda t: t.count("."),  1000),
    ("semicolon",    lambda t: t.count(";"),  lambda t: t.count(";"),  1000),
    ("colon",        lambda t: t.count(":"),  lambda t: t.count(":"),  1000),
    ("question",     lambda t: t.count("?"),  lambda t: t.count("?"),  1000),
    ("apostrophe",   lambda t: t.count("'"),  lambda t: t.count("'"),  1000),
    ("hyphen in a word", _lexical_hyphen,     _lexical_hyphen,         1000),
    ("ampersand",    _corpus_amp,             _model_amp,              1000),
    ("scribal mark", _corpus_tilde,           _model_tilde,            1000),
    ("digits",       lambda t: len(re.findall(r"[0-9]", t)),
                     lambda t: len(re.findall(r"[0-9]", t)),           1000),
]

# Asked of both sides but on its own denominator: mid-sentence words.
CAPS = ("mid-sentence capitals", 100)

# What the two sides cannot be asked, and why. Printing this is not padding:
# a sweep that silently omits them invites somebody to add them later without
# knowing they are incomparable.
INCOMPARABLE = [
    ("long s", "TCP normalises ſ to s; the corpus reads 0 in half a million words"),
    ("ligatures ﬁ ﬂ ﬀ", "normalised in transcription the same way"),
    ("italic and black letter", "markup in the source, absent once tags are stripped"),
    ("word division at a line end", "the model breaks lines and the corpus text is reflowed"),
    ("u/v and i/j", "both sides have them, but the corpus is the model's own source for the rule"),
]


def corpus_rows(n_sample):
    files = sorted(glob.glob(r"corpus/texts/*.headed.xml"))
    random.seed(1607)
    rows = []
    for f in random.sample(files, min(n_sample, len(files))):
        raw = open(f, encoding="utf-8", errors="replace").read()
        head = raw[: raw.find("<EEBO>") if "<EEBO>" in raw else 3000]
        if not re.search(r"<LANGUAGE>eng</LANGUAGE>", head):
            continue
        m = re.search(r"<DATE>[^<]*?(1[56]\d\d)", head)
        if not m or not (1580 <= int(m.group(1)) <= 1640):
            continue
        i = raw.find("<EEBO>")
        body = re.sub(r"<[^>]*>", " ", raw[i:] if i > 0 else raw)
        n = len(body.split())
        if n < 2000:
            continue
        vals = {name: per * f_corp(body) / n for name, f_corp, _, per in PROPERTIES}
        cap, mid = _midcaps(body)
        if mid:
            vals[CAPS[0]] = 100.0 * cap / mid
        rows.append(vals)
    return rows


def copy_row(path):
    """The copy-text measured the same way.

    THE PROGRAM REPRODUCES ITS COPY unless it has a habit, so a property the
    copy is unlike a period book in shows up here as the model's fault when it
    is nothing of the kind. The first run of this sweep flagged the full stop at
    half the corpus rate; the copy was at 19.6 and the model at 19.3, so the
    answer was Milton's sentences and not the program. Without this column that
    takes an afternoon to find out; with it, it is a glance.
    """
    body = open(path, encoding="utf-8-sig", errors="replace").read()
    n = len(body.split())
    vals = {name: per * f_mod(body) / n for name, _, f_mod, per in PROPERTIES}
    cap, mid = _midcaps(body)
    if mid:
        vals[CAPS[0]] = 100.0 * cap / mid
    return vals


def model_rows(dirs):
    rows = []
    for d in dirs:
        hits = glob.glob(os.path.join(d, "*.facsimile.txt"))
        if not hits:
            print(f"  (no *.facsimile.txt in {d}; skipped)", file=sys.stderr)
            continue
        body = open(hits[0], encoding="utf-8", errors="replace").read()
        n = len(body.split())
        vals = {name: per * f_mod(body) / n for name, _, f_mod, per in PROPERTIES}
        cap, mid = _midcaps(body)
        if mid:
            vals[CAPS[0]] = 100.0 * cap / mid
        rows.append(vals)
    return rows


def spread(vals):
    vals = sorted(vals)
    if len(vals) < 4:
        return statistics.median(vals), min(vals), max(vals)
    q = statistics.quantiles(vals, n=4)
    return statistics.median(vals), q[0], q[2]


def decile(vals, lo=0.10, hi=0.90):
    vals = sorted(vals)
    if len(vals) < 10:
        return min(vals), max(vals)
    return (vals[int(lo * len(vals))], vals[int(hi * len(vals)) - 1])


def main():
    args = sys.argv[1:]
    n_sample = 400
    copy_path = None
    while args and args[0].startswith("--"):
        if args[0] == "--corpus":
            n_sample = int(args[1]); args = args[2:]
        elif args[0] == "--copy":
            copy_path = args[1]; args = args[2:]
        else:
            break
    if not args:
        print(__doc__)
        return 1

    copy = copy_row(copy_path) if copy_path else None
    corpus = corpus_rows(n_sample)
    model = model_rows(args)
    if not corpus or not model:
        print("nothing to compare", file=sys.stderr)
        return 1

    print(f"{len(corpus)} English books 1580-1640 of 2,000 words or more, "
          f"against {len(model)} run(s) of the model\n")
    head = f"  {'property':20} {'corpus':>9} {'p25-p75':>15}"
    if copy:
        head += f" {'the copy':>9}"
    head += f" {'model':>9} {'range':>15}   verdict"
    print(head)
    print("  " + "-" * (len(head) + 4))

    names = [p[0] for p in PROPERTIES] + [CAPS[0]]
    flagged = []
    for name in names:
        cv = [r[name] for r in corpus if name in r]
        mv = [r[name] for r in model if name in r]
        if not cv or not mv:
            continue
        cmed, c25, c75 = spread(cv)
        mmed, mlo, mhi = spread(mv)
        d10, d90 = decile(cv)
        if c25 <= mmed <= c75:
            verdict = "inside the quartiles"
        elif d10 <= mmed <= d90:
            verdict = "outside p25-p75, inside p10-p90"
        else:
            verdict = "OUTSIDE p10-p90" + (" — high" if mmed > d90 else " — low")
            flagged.append((name, cmed, mmed))
        line = f"  {name:20} {cmed:9.2f} {c25:7.2f}-{c75:<7.2f}"
        if copy:
            line += f" {copy.get(name, float('nan')):9.2f}"
        line += f" {mmed:9.2f} {mlo:7.2f}-{mhi:<7.2f}  {verdict}"
        print(line)

    print()
    if flagged:
        print("  WORTH LOOKING AT — the model's median is outside the corpus's")
        print("  tenth-to-ninetieth percentile on these:")
        for name, c, m in flagged:
            note = ""
            if copy and name in copy and c:
                cp = copy[name]
                # The program reproduces the copy unless it has a habit for
                # this. If the copy is off the same way, the copy is the answer.
                if abs(cp - m) < 0.25 * max(abs(m), 1e-9):
                    note = f"   <- THE COPY IS ALREADY {cp:.2f}; not the program"
            print(f"    {name:20} corpus {c:8.2f}   model {m:8.2f}   "
                  f"({m/c if c else float('inf'):.1f}x){note}")
        print()
        print("  A flag is a place to look and not a defect. Check the extractor")
        print("  on both sides before believing it, and check that the copy-text")
        print("  is not the cause: the model reproduces its copy's pointing, so a")
        print("  modernised copy shows here as the program's fault when it is not.")
    else:
        print("  Nothing outside p10-p90.")

    print("\n  NOT COMPARABLE, and why:")
    for name, why in INCOMPARABLE:
        print(f"    {name:26} {why}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
