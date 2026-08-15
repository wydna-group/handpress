#!/usr/bin/env python3
"""Which mechanisms fired, which did not, and which could not.

    python tools/audit-mechanisms.py out-folio/folio.tei.report.txt

A mechanism nothing exercises and no report counts will be dead without
anyone noticing. Four have been, in this program: catches-misreading, the
catchword bracketing, the omission branch, and the crowding devices. Each was
invisible for the same reason -- nothing counted it -- and one live mechanism
was misdiagnosed as dead because a report printed a bare 0.00 beside nothing
that would have said whether it could have been anything else.

So this reads a finished report and sorts every countable mechanism into
three piles, which is one more pile than a list of counts gives you:

    FIRED         it happened, here is how often
    SILENT        it did not happen, but the run gave it the chance
    NOT OFFERED   it could not have happened: the parameter is nought, or
                  the format cannot produce it, or there was nothing of the
                  kind in the copy

Only the middle pile is worth arguing about. A SILENT mechanism on a book of
this size is either very rare or broken, and the report cannot tell you which
-- that is what a test is for.
"""

import re
import sys

# (label, regex over the report, what would have had to be true for it to
#  fire at all). The third element is prose, not a check: it is what to go
#  and look at when something lands in SILENT.
COUNTS = [
    ("copy marked up by the corrector",
     r"copy marked up by the corrector\s+(\d+)", "--no-copy-preparation off"),
    ("misread from the copy",
     r"misread from the copy\s+(\d+)", "any copy at all"),
    ("respelt by habit",
     r"respelt by habit\s+(\d+)", "a compositor with spelling preferences"),
    ("habit given up for the measure",
     r"habit given up for the measure\s+(\d+)", "justification binding somewhere"),
    ("altered to fit the measure",
     r"altered to fit the measure\s+(\d+)", "justification binding somewhere"),
    ("accident of the case",
     r"accident of the case\s+(\d+)", "foulness above 0"),
    # Hornschuch's marks. All four change a reading and so can become press
    # variants, unlike foul case by shape and the faults of impression.
    ("pointed otherwise than the copy",
     r"pointed otherwise than the copy\s+(\d+)", "--mis-point above 0"),
    ("spaced otherwise than the copy",
     r"spaced otherwise than the copy\s+(\d+)", "--mis-space above 0"),
    ("a word passed over",
     r"a word passed over\s+(\d+)", "--mis-drop above 0"),
    ("a word set a second time",
     r"set a second time\s+(\d+)",
     "two like words within four of each other, and the eye going back to the first"),
    ("two words the wrong way round",
     r"two words set the wrong way round\s+(\d+)", "--mis-transpose above 0"),
    # His judgement, not his error. These two answer to --year and to the copy
    # having heavy stops and lower-case nouns to work on at all.
    ("the heavy stop as the period sets it",
     r"the heavy stop set as the period sets it\s+(\d+)",
     "a copy with colons or semicolons in it"),
    ("a capital he was not given",
     r"given a capital he was not given\s+(\d+)",
     "words the period capitalised, standing lower case in the copy"),
    ("corrected at press",
     r"corrected at press\s+(\d+)", "a proof pulled mid-run"),
    ("house conventions (long s, u/v, i/j)",
     r"long s, u for v, i for j\s+(\d+)", "--no-long-s and --modern-uv off"),
    ("needing an expedient",
     r"needing an expedient to come out\s+(\d+)", "lines that will not come out"),
    ("a word divided at the end",
     r"a word divided at the end\s+(\d+)", "a line too long for its measure"),
    ("turned over or under",
     r"turned over or under\s+(\d+)", "VERSE lines; prose cannot be turned over"),
    ("quadded out",
     r"quadded out\s+(\d+)", "short lines: speech ends, paragraph ends"),
    # Anchored to the summary table by its "per 1000 pages" tail, and not to
    # the bare word. `crowded' read 27 where the report said 570, because the
    # pattern was r"crowded\s+(\d+)\s" and took the first match in the file --
    # which, once crowding became common, was a narrative line reading "the
    # page is crowded / 27 line(s) of ...", eleven of them standing ahead of
    # the table. It had been right for as long as crowding was rare enough to
    # produce no such lines.
    #
    # So the pattern was correct only while the thing it counts was
    # uncommon, and it failed silently at the moment there was most to see:
    # a twentyfold undercount, reported as a fall. That is the wrong way round
    # for the one instrument here whose whole purpose is to notice mechanisms
    # nobody is watching, and the other two are anchored the same way even
    # though neither is ambiguous today.
    ("the compositor lost his place",
     r"the compositor lost his place\s+(\d+)\s+[\d.]+\s+per 1000 pages",
     "a page whose copy resumes where the last left off"),
    ("pages crowded",
     r"crowded\s+(\d+)\s+[\d.]+\s+per 1000 pages", "casting off going wrong short"),
    ("pages spun out",
     r"spun out\s+(\d+)\s+[\d.]+\s+per 1000 pages", "casting off going wrong long"),
    ("lines of copy dropped (the omission branch)",
     r"lines of copy dropped\s+(\d+)\s+[\d.]+\s+per 1000 pages",
     "a page that cannot hold its cast-off copy"),
    # A fault of impression is not a press variant and is deliberately counted
    # apart, so it needs its own pattern here or it would be invisible to the
    # one instrument that watches for dead mechanisms.
    ("faults of impression",
     r"Faults of impression:\s+(\d+)", "a space rising or a sort standing proud"),
    ("distinctive types made at press",
     r"Made distinctive at press:\s+(\d+)", "a forme distributed during the run"),
    ("sorts that touched nought",
     r"Sorts that touched nought:\s+(\d+)", "a fount small enough to run dry"),
    ("the comma set close for want of space",
     r"comma-set-close\s+(\d+)",
     "space boxes running low; Blayney's cause for it"),
    ("shifts for want of a sort",
     r"Shifts made for want of a sort:\s+(\d+)", "a box running empty"),
    ("errors reading the copy",
     r"Errors reading the copy:\s+(\d+)", "any copy at all"),
    ("paging errors",
     r"Paging errors:\s+(\d+) of", "--paging-error above 0"),
    ("catchwords not answering",
     r"Not answering:\s+(\d+) of", "casting off going wrong at a page boundary"),
    ("formes proofed",
     r"Proofed:\s+(\d+) of", "--first-proof or the proof rate above 0"),
    ("formes corrected mid-run",
     r"Corrected mid-run:\s+(\d+) of", "an error surviving to the press"),
    ("press variants",
     r"Press variants:\s+(\d+)", "a forme corrected mid-run"),
    ("leaves cancelled",
     r"Leaves cancelled:\s+(\d+) of", "--cancel-rate or --cancels above 0"),
    ("binding faults",
     r"(\d+) faults occurred", "--binding-error above 0"),
    ("identifiable types recurring",
     r"Identifiable types recurring:\s+(\d+)", "distinctive type in the fount"),
    ("recurring across formes",
     r"Recurring across formes:\s+(\d+)", "type distributed and picked again"),
]

# Phrases the report itself uses to say a thing could not have happened. When
# one of these sits beside a zero the mechanism is NOT OFFERED, not SILENT.
IMPOSSIBLE = [
    (r"lines of copy dropped", r"cannot arise here"),
    (r"turned over", r"cannot arise here"),
]

# A silent mechanism is not necessarily a broken one, and the difference is
# worth writing down where it has actually been established by running the
# same code on other copy. Keyed by label.
EXPLAINED = {
    "pages crowded":
        "verse casts off by counting lines; on prose copy this fires at 109/1000",
    "lines of copy dropped (the omission branch)":
        "same cause; on prose copy at cast-off 0.45 it fires at 406/1000",
    "catchwords not answering":
        "same cause; on prose copy at cast-off 0.45, 5 of 57 fail to answer",
}


def main(path):
    text = open(path, encoding="utf-8", errors="replace").read()

    fired, silent, absent, missing = [], [], [], []
    for label, rx, needs in COUNTS:
        m = re.search(rx, text)
        if not m:
            missing.append((label, needs))
            continue
        n = int(m.group(1))
        # the report's own "none was possible" note, on the same line or the next
        line_start = text.rfind("\n", 0, m.start()) + 1
        line_end = text.find("\n", m.end())
        line = text[line_start:line_end if line_end != -1 else len(text)]
        impossible = ("none was possible" in line or "cannot arise" in line
                      or "could not" in line)
        if n > 0:
            fired.append((label, n))
        elif impossible:
            absent.append((label, line.strip()[:70]))
        else:
            silent.append((label, needs))

    w = 46
    print("MECHANISM AUDIT — %s" % path)
    print("=" * 74)
    print("\nFIRED (%d)" % len(fired))
    print("-" * 74)
    for label, n in fired:
        print("    %-*s %12s" % (w, label, "{:,}".format(n)))

    print("\nSILENT — had the chance and did not happen (%d)" % len(silent))
    print("-" * 74)
    if not silent:
        print("    none")
    for label, needs in silent:
        print("    %-*s  needed: %s" % (w, label, needs))
        why = EXPLAINED.get(label)
        if why:
            print("    %-*s    known live: %s" % (w, "", why))

    print("\nNOT OFFERED — could not have happened (%d)" % len(absent))
    print("-" * 74)
    if not absent:
        print("    none")
    for label, why in absent:
        print("    %-*s  %s" % (w, label, why))

    if missing:
        print("\nNOT FOUND IN THE REPORT (%d)" % len(missing))
        print("-" * 74)
        print("    A mechanism the report does not count is the one that goes")
        print("    dead unnoticed. These need a line in the report, not a fix.")
        for label, needs in missing:
            print("    %-*s  %s" % (w, label, needs))

    print("\n" + "=" * 74)
    print("%d fired, %d silent, %d not offered, %d uncounted"
          % (len(fired), len(silent), len(absent), len(missing)))
    unexplained = [l for l, _ in silent if l not in EXPLAINED]
    if unexplained:
        print("\n%d silent mechanism(s) with no established explanation:"
              % len(unexplained))
        for l in unexplained:
            print("    %s" % l)
    return 1 if (unexplained or missing) else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: audit-mechanisms.py <report.txt>")
    sys.exit(main(sys.argv[1]))
