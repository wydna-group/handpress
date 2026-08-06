#!/bin/sh
# The second review book. Unlike review/, which varies the *input format* and
# holds the shop fixed, this one holds the text fixed and varies the shop --
# because what wants looking at here is the setting, not the readers.
#
#   sh examples/manual/regenerate.sh
set -e
cd "$(dirname "$0")/../.."

run() {                       # run <out> <year> <input>
  racket main.rkt --out "examples/manual/$1" --year "$2" \
    --format quarto --seed 1614 --copies 8 --cancels 1 --html --tei \
    --title "A MANVAL OF CONTROVERSIES" \
    --publisher "Iohn Heigham" --printer "Charles Boscard" \
    "examples/manual/source/$3"
}

echo "=== md: 1614, the shop as the book was really printed ==="
run md 1614 manual.md

echo "=== xml: the TCP original, same shop ==="
run xml 1614 manual.xml

echo "=== late: the same copy set in 1670, when the conventions had gone ==="
run late 1670 manual.xml
