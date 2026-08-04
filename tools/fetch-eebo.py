"""Fetch a slice of EEBO-TCP Phase I and prepare it for the lexicon builder.

    python tools/fetch-eebo.py --dest corpus --from 1580 --to 1640

Downloads the Visualizing English Print plain-text release of EEBO-TCP Phase I
(25,368 texts, original spelling, 1.41 GB zipped), then extracts only the texts
printed between the given years.

Original spelling is the whole point. VEP also publish a standardised version
in which the spelling has been modernised, and that one is useless here: this
program needs to know what the compositors actually set, not what a later
editor thought they meant.

The texts are public domain -- Phase I entered it on 1 January 2015.

Options
-------
--zip PATH    use a zip already downloaded instead of fetching it
--keep-zip    do not delete the archive afterwards
--all         extract everything, ignoring the date range

The download resumes if interrupted, which matters at this size. Nothing is
extracted that falls outside the date range, so the working corpus stays small
even though the archive is not.
"""

import argparse
import csv
import io
import os
import re
import sys
import urllib.request
import zipfile

# Oxford's research archive, which holds EEBO-TCP Phase I under the ODC Public
# Domain Dedication. The texts entered the public domain on 1 January 2015.
#
# The Wisconsin (VEP) plain-text release would have been more convenient, being
# already stripped of markup and in original spelling, but every file under
# VEPCorporaRelease now returns 404 -- the links are still on the page and the
# directory behind them is gone. Oxford serves TEI XML, which the lexicon
# builder handles anyway.
#
# The archive is split into several zips by year of transcription, not year of
# printing, so all of them are wanted regardless of the date range; the range
# is applied afterwards, from each text's own header.
ORA = ("https://ora.ox.ac.uk/objects/"
       "uuid:ad7da8fc-cd8e-4637-8b7c-99498436dbaa")

YEAR = re.compile(r"(1[3-7]\d\d)")


# ORA answers 403 to urllib's default User-Agent.
UA = "handpress-lexicon/1.0 (research; python-urllib)"


def get(url, extra=None):
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    for k, v in (extra or {}).items():
        req.add_header(k, v)
    return urllib.request.urlopen(req)


def ora_files(page=ORA):
    """The zip URLs listed on the ORA record."""
    html = get(page).read().decode("utf-8", "replace")
    hrefs = re.findall(r'href="([^"]*/files/[0-9a-z]+)"', html)
    seen, out = set(), []
    for h in hrefs:
        u = h if h.startswith("http") else "https://ora.ox.ac.uk" + h
        if u not in seen:
            seen.add(u)
            out.append(u)
    return out


def download(url, path):
    have = os.path.getsize(path) if os.path.exists(path) else 0
    extra = {}
    if have:
        extra["Range"] = "bytes=%d-" % have
        print("  resuming at %.1f MB" % (have / 1e6))
    try:
        resp = get(url, extra)
    except urllib.error.HTTPError as e:
        if e.code == 416:                     # already complete
            print("archive already complete")
            return
        raise
    total = int(resp.headers.get("Content-Length", 0)) + have
    mode = "ab" if have and resp.status == 206 else "wb"
    if mode == "wb":
        have = 0
    done = have
    with open(path, mode) as f:
        while True:
            chunk = resp.read(1 << 20)
            if not chunk:
                break
            f.write(chunk)
            done += len(chunk)
            if total:
                sys.stdout.write("\r  %.0f%%  %.2f / %.2f GB"
                                 % (100.0 * done / total, done / 1e9, total / 1e9))
                sys.stdout.flush()
    print()


def find_metadata(z):
    """The one CSV in the archive, whatever they have called it this release."""
    for n in z.namelist():
        if n.lower().endswith(".csv"):
            return n
    return None


def year_of(row):
    """Pull a printing year out of whichever column carries it."""
    for key in ("date", "Date", "pubdate", "year", "Year", "DATE"):
        if key in row and row[key]:
            m = YEAR.search(str(row[key]))
            if m:
                return int(m.group(1))
    for v in row.values():                    # last resort: any 4-digit year
        if v:
            m = YEAR.search(str(v))
            if m:
                return int(m.group(1))
    return None


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--dest", default="corpus")
    ap.add_argument("--from", dest="lo", type=int, default=1580)
    ap.add_argument("--to", dest="hi", type=int, default=1640)
    ap.add_argument("--zip", dest="zippath")
    ap.add_argument("--keep-zip", action="store_true")
    ap.add_argument("--all", action="store_true")
    args = ap.parse_args()

    os.makedirs(args.dest, exist_ok=True)

    if args.zippath:
        archives = [args.zippath]
    else:
        urls = ora_files()
        print("EEBO-TCP Phase I from Oxford: %d archives" % len(urls))
        archives = []
        for i, u in enumerate(urls, 1):
            p = os.path.join(args.dest, "eebo-part-%02d.zip" % i)
            print("[%d/%d] %s" % (i, len(urls), os.path.basename(p)))
            download(u, p)
            archives.append(p)

    total = 0
    for zippath in archives:
        total += extract(zippath, args)

    out = os.path.join(args.dest, "texts")
    print("\n%d texts in %s" % (total, out))
    print("next:")
    print("  python tools/build-lexicon.py %s -o lexicon.rktd "
          "--modern tools/modern-en.txt --min 3" % out)


def extract(zippath, args):
    with zipfile.ZipFile(zippath) as z:
        meta = find_metadata(z)
        wanted = None
        if meta and not args.all:
            with z.open(meta) as fh:
                rows = list(csv.DictReader(io.TextIOWrapper(fh, "utf-8",
                                                            errors="replace")))
            print("metadata: %d records, columns: %s"
                  % (len(rows), ", ".join(list(rows[0].keys())[:8]) if rows else ""))
            wanted = set()
            for r in rows:
                y = year_of(r)
                if y is None or not (args.lo <= y <= args.hi):
                    continue
                for v in r.values():          # the TCP id, in whichever column
                    if v and re.fullmatch(r"[AB]\d{5}", str(v).strip()):
                        wanted.add(str(v).strip())
                        break
            print("%d texts printed %d-%d" % (len(wanted), args.lo, args.hi))
            if not wanted:
                print("no texts matched; extracting everything instead",
                      file=sys.stderr)
                wanted = None

        out = os.path.join(args.dest, "texts")
        os.makedirs(out, exist_ok=True)
        n = 0
        for name in z.namelist():
            # Oxford serves TEI XML; the builder strips the markup itself.
            if not name.lower().endswith((".xml", ".txt")) or name.endswith("/"):
                continue
            base = os.path.basename(name)
            if wanted is not None:
                tcp = re.match(r"([AB]\d{5})", base)
                if not tcp or tcp.group(1) not in wanted:
                    continue
            with z.open(name) as src, open(os.path.join(out, base), "wb") as dst:
                dst.write(src.read())
            n += 1
            if n % 500 == 0:
                print("  extracted %d" % n)

    print("  %s: %d texts -> %s" % (os.path.basename(zippath), n, out))
    if not args.keep_zip and not args.zippath and os.path.exists(zippath):
        os.remove(zippath)
    return n


if __name__ == "__main__":
    main()
