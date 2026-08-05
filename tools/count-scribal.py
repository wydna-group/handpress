"""Scribal marks per 1,000 words, per document, by decade and language."""
import glob, re, sys, io, random, statistics, collections
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8")

files = sorted(glob.glob(r"corpus/texts/*.headed.xml"))
random.seed(1607)
sample = random.sample(files, int(sys.argv[1]) if len(sys.argv) > 1 else 600)

PRE = "ãẽĩõũāēīōū"
COMB = "̃̄"

rows = []
for f in sample:
    raw = open(f, encoding="utf-8", errors="replace").read()
    head = raw[: raw.find("<EEBO>") if "<EEBO>" in raw else 3000]
    m = re.search(r"<DATE>[^<]*?(1[56]\d\d)", head)
    year = int(m.group(1)) if m else None
    lang = "eng" if re.search(r"<LANGUAGE>eng</LANGUAGE>", head) else "other"

    i = raw.find("<EEBO>")
    body = re.sub(r"<[^>]*>", " ", raw[i:] if i > 0 else raw)
    w = len(body.split())
    if w < 2000 or year is None:
        continue
    etc = len(re.findall(r"&\s*c\b", body))
    amp = body.count("&") - etc
    tilde = sum(1 for ch in body if ch in PRE or ch in COMB)
    que = len(re.findall(r"\{que\}", body))
    other_brace = len(re.findall(r"\{(us|per|pro|quod|that|con)\}", body))
    rows.append((year, lang, w, amp, etc, tilde, que + other_brace))

print("%d documents kept\n" % len(rows))


def band(rs, label):
    if not rs:
        return
    w = sum(r[2] for r in rs)

    def per(i):
        return [r[i] / (r[2] / 1000.0) for r in rs]

    def s(i):
        v = sorted(per(i))
        return "%6.2f %6.2f %6.2f" % (
            statistics.median(v), v[int(0.75 * len(v))], v[int(0.95 * len(v))])

    print("%-14s n=%-4d %11s | %s | %s | %s"
          % (label, len(rs), format(w, ","), s(3), s(5), s(6)))


print("%-14s %-6s %11s | %-20s | %-20s | %s"
      % ("", "", "words", "& (med/p75/p95)", "tilde (med/p75/p95)", "brevigraph"))
eng = [r for r in rows if r[1] == "eng"]
band(rows, "all")
band(eng, "english only")
for lo in (1580, 1590, 1600, 1610, 1620, 1630):
    band([r for r in eng if lo <= r[0] < lo + 10], "eng %ds" % lo)

print("\n&c is counted separately: median %.2f per 1,000 words"
      % statistics.median([r[4] / (r[2] / 1000.0) for r in eng]))
zero = sum(1 for r in eng if r[5] == 0)
print("English books with NO tilde at all: %d of %d (%.0f%%)"
      % (zero, len(eng), 100.0 * zero / len(eng)))
heavy = sum(1 for r in eng if r[5] / (r[2] / 1000.0) > 5)
print("English books above 5 per 1,000:    %d of %d (%.0f%%)"
      % (heavy, len(eng), 100.0 * heavy / len(eng)))
