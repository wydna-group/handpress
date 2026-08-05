"""Which words actually carried the tilde, and how concentrated the habit was."""
import glob, re, sys, io, random, collections, unicodedata
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

files = sorted(glob.glob(r"corpus/texts/*.headed.xml"))
random.seed(1607)
sample = random.sample(files, int(sys.argv[1]) if len(sys.argv) > 1 else 500)

PRE = "ãẽĩõũāēīōū"
COMB = "̃̄"
MARKED = re.compile(r"[A-Za-z̃̄" + PRE + r"]*[" + PRE + COMB + r"][A-Za-z̃̄" + PRE + r"]*")

forms = collections.Counter()
kept = 0
for f in sample:
    raw = open(f, encoding="utf-8", errors="replace").read()
    if "<LANGUAGE>eng</LANGUAGE>" not in raw[:4000]:
        continue
    i = raw.find("<EEBO>")
    body = re.sub(r"<[^>]*>", " ", raw[i:] if i > 0 else raw)
    kept += 1
    for m in MARKED.finditer(body):
        w = unicodedata.normalize("NFC", m.group(0)).strip()
        if len(w) > 1:
            forms[w.lower()] += 1

total = sum(forms.values())
print("%d English documents, %s marked forms, %d distinct\n"
      % (kept, format(total, ","), len(forms)))

run = 0
for n, (w, c) in enumerate(forms.most_common(60), 1):
    run += c
    print("  %-16s %7d  %5.1f%% cumulative" % (w, c, 100.0 * run / total))

for n in (5, 10, 20, 50, 100, 300):
    run = sum(c for _, c in forms.most_common(n))
    print("\ntop %-4d of %d distinct forms cover %.0f%% of all tildes"
          % (n, len(forms), 100.0 * run / total))
