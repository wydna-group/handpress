#!/bin/sh
# One book, seven ways in. Same seed, same shop, same edition size, so that any
# difference between the seven is the input format's own doing.
#
#   sh examples/floyd/regenerate.sh
#
# The floyd.* sources are made by the conversion script in the scratchpad from
# corpus/texts/A01013.headed.xml; only the outputs are rebuilt here.
set -e
cd "$(dirname "$0")/../.."

for f in md html docx xml tex pdf txt; do
  echo "=== $f ==="
  racket main.rkt --out "examples/floyd/$f" \
    --format quarto --seed 1600 --year 1600 --copies 8 \
    --title "A PERFIT COMMON WEALTH" \
    --publisher "Nathaniel Butter" --printer "Nicholas Okes" \
    --cancels 1 --html --tei "examples/floyd/source/floyd.$f"
done
