#!/usr/bin/env bash
# Rebuild legal-books DB rows from completed book folders.
#
# Usage:
#   reindex.sh              # reindex every book folder
#   reindex.sh --book-id 001

set -euo pipefail

ROOT="$HOME/legal-books"
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) VENV="$ROOT/.venv/Scripts/activate"; PY=python ;;
  Darwin*)              VENV="$ROOT/.venv/bin/activate";     PY=python3 ;;
  *)                    VENV="$ROOT/.venv/bin/activate";     PY=python3 ;;
esac

usage() {
  cat <<'EOF'
Usage:
  reindex.sh
  reindex.sh --book-id 001

Rebuilds DB chunks and FTS rows from each book folder's <book_id>.pdf or <book_id>.md.
EOF
}

BOOK_ID=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --book-id) BOOK_ID="$2"; shift 2 ;;
    --all) shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown arg: $1" >&2; usage >&2; exit 1 ;;
  esac
done

if [[ ! -f "$VENV" ]]; then
  echo "[reindex] venv not found: $VENV" >&2
  echo "[reindex] Run toolkit/legal-books/install.sh first." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$VENV"

ROOT="$ROOT" BOOK_ID="$BOOK_ID" "$PY" <<'PY'
import json
import os
import re
import subprocess
import sys
from pathlib import Path

root = Path(os.environ["ROOT"])
only_book_id = os.environ.get("BOOK_ID", "")
books_dir = root / "books"
ingest = root / "scripts" / "ingest.py"

if not books_dir.exists():
    print(f"[reindex] books directory not found: {books_dir}", file=sys.stderr)
    sys.exit(1)
if not ingest.exists():
    print(f"[reindex] ingest script not found: {ingest}", file=sys.stderr)
    sys.exit(1)

book_dirs = []
for child in sorted(books_dir.iterdir()):
    if not child.is_dir():
        continue
    match = re.match(r"^(\d{3})_", child.name)
    if not match:
        continue
    book_id = match.group(1)
    if only_book_id and book_id != only_book_id:
        continue
    book_dirs.append((book_id, child))

if not book_dirs:
    target = f"book {only_book_id}" if only_book_id else "completed book folders"
    print(f"[reindex] no {target} found", file=sys.stderr)
    sys.exit(1)

failures = 0
for book_id, book_dir in book_dirs:
    pdf = book_dir / f"{book_id}.pdf"
    md = book_dir / f"{book_id}.md"
    meta_path = book_dir / f"{book_id}.meta.json"
    if not meta_path.exists() or (not pdf.exists() and not md.exists()):
        print(
            f"[reindex] skip {book_id}: missing source PDF/MD or {meta_path.name}",
            file=sys.stderr,
        )
        failures += 1
        continue

    with meta_path.open("r", encoding="utf-8") as f:
        meta = json.load(f)

    cmd = [
        sys.executable,
        str(ingest),
        "--book-id",
        book_id,
        "--pdf" if pdf.exists() else "--md",
        str(pdf if pdf.exists() else md),
        "--book-dir",
        str(book_dir),
        "--author",
        str(meta.get("author") or ""),
        "--title",
        str(meta.get("title") or ""),
        "--edition",
        str(meta.get("edition") or ""),
        "--year",
        str(meta.get("year") or 0),
        "--publisher",
        str(meta.get("publisher") or ""),
    ]
    print(f"[reindex] {book_id}: {meta.get('author', '')} {meta.get('title', '')}")
    result = subprocess.run(cmd, check=False)
    if result.returncode != 0:
        failures += 1

if failures:
    print(f"[reindex] completed with {failures} failure(s)", file=sys.stderr)
    sys.exit(1)

print(f"[reindex] done: {len(book_dirs)} book(s)")
PY
