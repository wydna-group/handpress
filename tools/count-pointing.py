"""Pointing and capitalisation as the printed books actually have them.

The program models a compositor's SPELLING as a habit and his pointing only as
an error, which makes it able to drop or change a stop and unable to point a
book the way a workman pointed one. Nothing here says what he changed -- the
corpus has no copy to compare against -- but it says what the printed page came
out like, which is the thing the model's own output can be held against.

Two quantities, per document, by decade:

  * stops per 1,000 words, by kind
  * of the words standing MID-SENTENCE, how many begin with a capital

The second needs care, because a proper name is capitalised by rule and not by
habit and would swamp the count. So it is given twice: once over every word, and
once with the word-types that are capitalised more than nine times in ten thrown
out, which is what a name looks like. What is left is the variable practice --
`Gentleman', `Ladies', `King' -- which is the thing Blayney names as a
compositor's marker when he says Okes's B capitalised `King'.

    python tools/count-pointing.py [sample size]
"""
import glob, re, sys, io, random, statistics, collections

sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

files = sorted(glob.glob(r"corpus/texts/*.headed.xml"))
random.seed(1607)
sample = random.sample(files, int(sys.argv[1]) if len(sys.argv) > 1 else 400)

STOPS = {",": "comma", ".": "period", ";": "semicolon",
         ":": "colon", "?": "question", "!": "exclam"}
WORD = re.compile(r"[A-Za-zſ][A-Za-zſ']*")
# A sentence opens the text, or follows a full stop, question or exclamation.
OPENER = re.compile(r"[.?!]\s*$")

rows = []
capcount = collections.Counter()   # word type -> capitalised mid-sentence
lowcount = collections.Counter()   # word type -> lower case mid-sentence

for f in sample:
    raw = open(f, encoding="utf-8", errors="replace").read()
    head = raw[: raw.find("<EEBO>") if "<EEBO>" in raw else 3000]
    m = re.search(r"<DATE>[^<]*?(1[56]\d\d)", head)
    year = int(m.group(1)) if m else None
    if not re.search(r"<LANGUAGE>eng</LANGUAGE>", head) or year is None:
        continue

    i = raw.find("<EEBO>")
    body = re.sub(r"<[^>]*>", " ", raw[i:] if i > 0 else raw)
    words = body.split()
    n = len(words)
    if n < 2000:
        continue

    stops = collections.Counter()
    for ch in body:
        if ch in STOPS:
            stops[STOPS[ch]] += 1

    mid = 0
    midcap = 0
    prev_ends_sentence = True
    for tok in words:
        w = WORD.search(tok)
        if w:
            if not prev_ends_sentence:
                mid += 1
                bare = w.group(0)
                if bare[0].isupper():
                    midcap += 1
                    capcount[bare.lower()] += 1
                else:
                    lowcount[bare.lower()] += 1
        prev_ends_sentence = bool(OPENER.search(tok))

    rows.append((year, n, stops, mid, midcap))

def per1000(x, n):
    return 1000.0 * x / n if n else 0.0

def band(y):
    return (y // 10) * 10

print(f"{len(rows)} English documents of 2,000 words or more\n")

print("STOPS PER 1,000 WORDS  (median across documents, p25-p75)")
print(f"  {'decade':8} {'docs':>5} " + " ".join(f"{k:>11}" for k in STOPS.values()))
by = collections.defaultdict(list)
for year, n, stops, mid, midcap in rows:
    by[band(year)].append((n, stops))
for d in sorted(by):
    docs = by[d]
    if len(docs) < 4:
        continue
    cells = []
    for kind in STOPS.values():
        vals = sorted(per1000(s[kind], n) for n, s in docs)
        med = statistics.median(vals)
        cells.append(f"{med:11.1f}")
    print(f"  {d:<8} {len(docs):>5} " + " ".join(cells))

print("\nMID-SENTENCE CAPITALS, per 100 mid-sentence words")
print(f"  {'decade':8} {'docs':>5} {'median':>8} {'p25':>7} {'p75':>7}")
byc = collections.defaultdict(list)
for year, n, stops, mid, midcap in rows:
    if mid:
        byc[band(year)].append(100.0 * midcap / mid)
for d in sorted(byc):
    vals = sorted(byc[d])
    if len(vals) < 4:
        continue
    q = statistics.quantiles(vals, n=4) if len(vals) > 3 else [0, 0, 0]
    print(f"  {d:<8} {len(vals):>5} {statistics.median(vals):8.1f} {q[0]:7.1f} {q[2]:7.1f}")

# Which words carry it, once the names are taken out.
print("\nWORDS CAPITALISED MID-SENTENCE PART OF THE TIME")
print("  (a name is capitalised nearly always; these are the ones that vary)")
varying = []
for w, c in capcount.items():
    total = c + lowcount.get(w, 0)
    if total >= 200:
        share = c / total
        if 0.05 < share < 0.90:
            varying.append((share, total, w))
varying.sort(reverse=True)
print(f"  {len(varying)} word-types vary; the commonest twenty:")
for share, total, w in sorted(varying, key=lambda t: -t[1])[:20]:
    print(f"    {w:<16} {100*share:5.1f}% of {total:>7,} mid-sentence")

allcap = sum(capcount.values())
alllow = sum(lowcount.values())
namey = sum(c for w, c in capcount.items()
            if c / (c + lowcount.get(w, 0)) >= 0.90)
print(f"\n  every mid-sentence word:          {100.0*allcap/(allcap+alllow):5.2f}% capitalised")
print(f"  with the near-always ones removed: "
      f"{100.0*(allcap-namey)/(allcap+alllow-namey):5.2f}%")
