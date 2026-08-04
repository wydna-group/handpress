"""Extract a plain modern wordlist from a Hunspell .dic file.

    python tools/make-wordlist.py path/to/en-GB.dic tools/modern-en.txt

The lexicon builder needs a modern wordlist to anchor its variant grouping.
Without one it merges `her` with `here`, because no rule about letters can
distinguish a variant spelling from a different word: `here`/`heere` and
`her`/`here` are the same case orthographically. A form that is itself a
standard modern word is not a variant spelling of another standard word, and
that is the only thing that separates them.

Hunspell lines are `word/FLAGS`; the flags are morphology we do not want.
"""

import re
import sys

src, dst = sys.argv[1], sys.argv[2]
words = set()
for i, line in enumerate(open(src, encoding="utf-8", errors="replace")):
    if i == 0 and line.strip().isdigit():
        continue                      # Hunspell puts a count on line 1
    w = line.split("/")[0].strip().lower()
    if w and re.fullmatch(r"[a-z']+", w):
        words.add(w)

with open(dst, "w", encoding="utf-8") as f:
    f.write("\n".join(sorted(words)))
print("%d modern words -> %s" % (len(words), dst))
