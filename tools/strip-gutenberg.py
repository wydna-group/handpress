"""Strip Project Gutenberg's apparatus, leaving the text as copy.

    python tools/strip-gutenberg.py raw.txt clean.txt

Everything before the START marker and after the END marker is the modern
edition's, not the book's, and would otherwise be cast off and set as though
Milton had written it. The transcriber's notes and the editor's introduction
go the same way.
"""

import re
import sys

src, dst = sys.argv[1], sys.argv[2]
raw = open(src, encoding="utf-8", errors="replace").read()

start = re.search(r"\*\*\*\s*START OF TH[EI][^*]*\*\*\*", raw)
end = re.search(r"\*\*\*\s*END OF TH[EI][^*]*\*\*\*", raw)
body = raw[start.end() if start else 0: end.start() if end else len(raw)]

# The editorial front matter that sits inside the markers on many texts.
body = re.sub(r"^\s*Produced by.*?$", "", body, flags=re.M)
body = re.sub(r"\[Transcriber'?s Note.*?\]", "", body, flags=re.S | re.I)

# Gutenberg wraps prose at about 70 columns. The compositor must do his own
# wrapping, so a paragraph has to arrive as one unit: single newlines inside
# a paragraph are joined, blank lines kept as the breaks they are.
paras = re.split(r"\n\s*\n", body)
out = []
for p in paras:
    p = " ".join(line.strip() for line in p.split("\n")).strip()
    if p:
        out.append(p)

open(dst, "w", encoding="utf-8").write("\n\n".join(out) + "\n")
words = len(re.findall(r"\S+", "\n".join(out)))
print("%d paragraphs, %d words -> %s" % (len(out), words, dst))
