# The attestation lexicon

`eebo-1580-1640.rktd` — 318,722 spellings attested in **5,287 books printed
between 1580 and 1640**, grouped into 45,719 sets of variants of one another,
with 18,562 mapped to the form still current.

## Why it is here rather than built on demand

Because it costs an hour and 1.65 GB to make, and because without it the
program falls back to a lexicon of 2,370 forms drawn from two texts, which is
enough to demonstrate the mechanism and not enough to be trusted. The
difference between the two is not academic: measured on the same copy, the
proportion of words altered to fit the measure rises from 8.70 per thousand to
29.38 when a real corpus is behind it, because the compositor then has genuine
variants to choose among instead of the handful a rule could invent.

## What it is for

Three questions, and they are different ones:

| question | answer |
|---|---|
| is this a real spelling? | `attested?`, `plausible?` |
| what else could this word be spelt? | `variants-of` |
| what is this word's current spelling? | `modern-form` |

The first gates the compositor's spelling devices so that they select rather
than invent. The second gives him something to select from. The third drives
`--modern-spelling`.

## Provenance

Derived from **EEBO-TCP Phase I**, released into the public domain on 1 January
2015 under the Open Data Commons Public Domain Dedication and Licence, and
fetched from the University of Oxford's research archive. Rebuild with:

```sh
python tools/fetch-eebo.py --dest corpus --from 1580 --to 1640
python tools/build-lexicon.py corpus/texts -o lexicon/eebo-1580-1640.rktd \
       --modern tools/modern-en.txt --min 5
```

The `modern` and `current` sections were computed with a modern English
wordlist as a build input, used only to decide which of two attested spellings
is the one still in use — a judgement about public-domain forms. The wordlist
itself is not redistributed here; `tools/make-wordlist.py` extracts one from
any Hunspell dictionary.

## Its limits

**It is a corpus, not a dictionary.** It records what was printed, including
mistakes. `theere` occurs seventeen times against 145,517 for `here`; that is
not a spelling anyone chose but the sweepings of a very large floor. Hence
`plausible?`, which asks whether a form holds a real share of its word's
occurrences rather than merely appearing.

**The variant groups are approximate.** Forms are grouped by a skeleton that
collapses the period's orthographic alternations, then split against the modern
wordlist so that `her` is not treated as a spelling of `here`. Where two modern
words remain close, the grouping can still err: `runne` is assigned to `rune`
rather than `run`, because the first is nearer by edit distance. No rule about
letters separates that case from `heere`/`here`, which is why VARD and its
relatives keep a human in the loop.

**Sixty years is a long time.** A form current in 1580 may be archaic by 1640,
and the counts here flatten that. For work on a narrower period, rebuild with
tighter dates.
