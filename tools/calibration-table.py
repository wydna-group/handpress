#!/usr/bin/env python3
"""The calibration figures, across seeds, as a table for CALIBRATION.md.

    python tools/calibration-table.py out-cal-*/folio.tei.report.txt

Every figure in CALIBRATION.md is a range over several runs, never one number,
and this is what produces the range. It exists because of a specific failure:
three separate gaps between the model and its sources were chased in one session
and all three dissolved once the spread was measured. Two of them had a confident
written diagnosis before the arithmetic was done.

The press-variant count is the case that matters. Over four seeds of the same
book and the same code it ran 368 to 624 -- a 1.7-fold spread -- and every
calibration decision recorded in `press.rkt' (proof rate 0.6, then 0.28, then
0.224) was argued from a SINGLE full Folio, before anyone knew that. A rate
quoted from one run of the standard hard case is a draw.

So: run the same book at several seeds, feed the reports here, and paste the
range and the mean. Never the value.

    for s in 1623 11 22 44; do
      racket main.rkt --format folio6 --paper crown --compositors A,B,C,D,E \\
        --kind drama --year 1623 --edition 1200 --copies 4 --copy-texts 0 \\
        --seed $s --quiet -o out-cal$s folio/folio.tei.xml
    done
    python tools/calibration-table.py out-cal*/folio.tei.report.txt

`--copies 4' is deliberate: the press figures come from the press run and not
from the collation, so collating 1,200 copies changes none of them and costs
several minutes a seed. Verified -- 1,200 and 4 give identical counts.
"""

import re
import statistics
import sys

# (label, regex over the report, how to present it). A row whose pattern stops
# matching prints as "?" rather than vanishing: a figure that quietly leaves the
# table is how a mechanism goes dead unnoticed, which is the fault
# tools/audit-mechanisms.py exists to prevent and this one can commit too.
ROWS = [
    ("words",                r"^  ([\d,]+) words, [\d,]+ lines"),
    ("pages",                r"^  [\d,]+ words, [\d,]+ lines, ([\d,]+) pages"),
    ("formes",               r"^    Formes:\s+(\d+)"),
    ("formes proofed",       r"^    Proofed:\s+(\d+) of"),
    ("formes corrected",     r"^    Corrected mid-run:\s+(\d+) of"),
    ("press variants",       r"^    Press variants:\s+(\d+)"),
    ("faults of impression", r"Faults of impression:\s+(\d+)"),
    ("pages crowded",        r"^    crowded\s+(\d+)\s"),
    ("pages spun out",       r"^    spun out\s+(\d+)\s"),
    ("lines dropped",        r"^    lines of copy dropped\s+(\d+)\s"),
    ("lost his place",       r"lost his place\s+(\d+)\s"),
    ("divisions /1000 ln",   r"^    a word divided at the end\s+\d+\s+([\d.]+)"),
    ("accidents made",       r"^    accident of the case\s+(\d+)\s"),
    ("accidents surviving",  r"left standing in one copy\s+(\d+)\s"),
    ("pointed otherwise",    r"^    pointed otherwise than the copy\s+(\d+)\s"),
    ("catchwords not answering", r"Not answering:\s+(\d+) of"),

    # Hornschuch's marks, built 2026-08-14. Each changes a reading and so can
    # reach the variant count, which is the question asked before building any
    # of them.
    ("spaced otherwise",     r"^    spaced otherwise than the copy\s+(\d+)\s"),
    ("a word passed over",   r"^    a word passed over\s+(\d+)\s"),
    ("set a second time",    r"^    set a second time\s+(\d+)\s"),
    ("transposed",           r"^    two words set the wrong way round\s+(\d+)\s"),

    # His judgement rather than his error, built the same day. These are the
    # rows that should move with `--year' and with nothing else.
    ("heavy stop repointed", r"^    the heavy stop set as the period sets it\s+(\d+)\s"),
    ("capitals given",       r"^    given a capital he was not given\s+(\d+)\s"),

    # Wrong fount is the one known fault in the calibration table, and until
    # 2026-08-14 no report line yielded it: the only figure printed was the
    # whole `shift' kind, 98% of it space-metal.
    ("wrong-fount sorts",    r"^      wrong-fount\s+(\d+)"),
    ("cannibalized",         r"^      cannibalized\s+(\d+)"),

    # Lambard's four grades over the same words. They must sum to the marked
    # words and not to more, a word costing the reader by its worst fault.
    ("grade cosmetic",       r"^    blemish only the workmanship\s+(\d+)\s"),
    ("grade orthographic",   r"^    offend against orthographie\s+(\d+)\s"),
    ("grade sense",          r"^    shrewdly peruert the sense\s+(\d+)\s"),
    ("grade meaning",        r"^    vtterly euert his meaning\s+(\d+)\s"),
]

# Figures that are only meaningful per thousand of something else, so that the
# table can carry the quantity a source is actually quoted in.
DERIVED = [
    ("accidents made / 1000 words",      "accidents made", "words", 1000),
    ("accidents surviving / 1000 words", "accidents surviving", "words", 1000),
    ("pointed / 1000 words",             "pointed otherwise", "words", 1000),
    ("miscast / 1000 pages",             None, "pages", 1000),   # crowded + spun
]


def read(path):
    text = open(path, encoding="utf-8", errors="replace").read()
    out = {}
    for label, rx in ROWS:
        m = re.search(rx, text, re.M)
        out[label] = float(m.group(1).replace(",", "")) if m else None
    return out


def fmt(v):
    if v is None:
        return "?"
    return f"{v:.2f}" if v != int(v) else str(int(v))


def main(paths):
    runs = [(p, read(p)) for p in paths]
    if not runs:
        print(__doc__)
        return 1

    print(f"{len(runs)} run(s)\n")
    for p, _ in runs:
        print(f"  {p}")
    print()

    def line(label, values):
        nums = [v for v in values if v is not None]
        cells = "  ".join(f"{fmt(v):>9}" for v in values)
        if not nums:
            print(f"  {label:32s} {cells}")
            return
        rng = f"{fmt(min(nums))} to {fmt(max(nums))}"
        mean = statistics.mean(nums)
        print(f"  {label:32s} {cells}   | {rng:>21}  mean {fmt(round(mean, 2))}")

    for label, _ in ROWS:
        line(label, [d[label] for _, d in runs])

    print()
    for label, num, den, scale in DERIVED:
        vals = []
        for _, d in runs:
            if num is None:                      # the miscast pair
                a, b = d["pages crowded"], d["pages spun out"]
                n = (a + b) if (a is not None and b is not None) else None
            else:
                n = d[num]
            q = d[den]
            vals.append(None if (n is None or not q) else n / q * scale)
        line(label, vals)

    print(
        "\nPaste the RANGE and the MEAN into CALIBRATION.md, never a single value,"
        "\nand put today's date on the section. A figure from one run is a draw."
    )
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
