# -*- coding: utf-8 -*-
"""The worst cluster, not the average.

Blayney's maxima are "the number of types of each sort that were in type just
before each distribution" -- the peak, not the mean. A book's figures are not
spread evenly: they gather in a table of contents, a set of marginal
citations, a chronology. So the bill has to survive the worst window of copy
that can stand locked up at once, and the mean says nothing about it.
"""
import io, re, sys, collections
sys.stdout.reconfigure(encoding="utf-8")

FILES = [
    ("Floyd, Common Wealth",
     r"C:\Users\kantb\OneDrive\Documents\book\handpress-rkt\examples\floyd\source\floyd.md"),
    ("The First Folio",
     r"C:\Users\kantb\OneDrive\Documents\book\handpress-rkt\folio\folio.md"),
    ("Areopagitica",
     r"C:\Users\kantb\OneDrive\Documents\book\handpress-rkt\samples\areopagitica.txt"),
]

PAGE_CHARS = 1311
STANDING = 12
WINDOW = PAGE_CHARS * STANDING

SORTS = "0123456789&"
print("Worst %d characters of copy (%d pages standing):\n" % (WINDOW, STANDING))
print("  %-24s %s" % ("book", "  ".join("%4s" % c for c in SORTS)))
peaks = collections.defaultdict(int)
for name, path in FILES:
    try:
        t = io.open(path, encoding="utf-8", errors="replace").read()
    except FileNotFoundError:
        continue
    body = re.sub(r"\s+", " ", t)
    row = []
    for c in SORTS:
        # positions of this sort, then the densest window
        pos = [i for i, ch in enumerate(body) if ch == c]
        best = 0
        j = 0
        for i in range(len(pos)):
            while pos[i] - pos[j] >= WINDOW:
                j += 1
            best = max(best, i - j + 1)
        row.append(best)
        peaks[c] = max(peaks[c], best)
    print("  %-24s %s" % (name, "  ".join("%4d" % v for v in row)))

print("\n  %-24s %s" % ("PEAK OF ANY", "  ".join("%4d" % peaks[c] for c in SORTS)))
print("\n  %-24s %s" % ("bill now",
      "  ".join("%4d" % v for v in [30, 40, 34, 30, 28, 28, 26, 26, 26, 26, 40])))
