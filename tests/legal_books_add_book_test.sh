#!/usr/bin/env bash
# Regression tests for legal-books add_book.sh retry safety.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="$ROOT/toolkit/legal-books/scripts/add_book.sh"

failures=0

fail() {
  printf 'not ok - %s\n' "$1" >&2
  failures=$((failures + 1))
}

expect_failed_ingest_cleans_incomplete_folder() {
  local tmpdir bindir output status
  tmpdir="$(mktemp -d)"
  bindir="$tmpdir/bin"
  mkdir -p "$bindir" "$tmpdir/legal-books/.venv/bin" "$tmpdir/legal-books/books" "$tmpdir/legal-books/db" "$tmpdir/legal-books/scripts"
  touch "$tmpdir/legal-books/.venv/bin/activate"
  printf 'scan\n' > "$tmpdir/scan.pdf"

  cat > "$bindir/ocrmypdf" <<'SH'
#!/usr/bin/env bash
args=("$@")
cp "${args[$#-2]}" "${args[$#-1]}"
SH
  chmod +x "$bindir/ocrmypdf"

  cat > "$bindir/tesseract" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == "--list-langs" ]]; then
  printf 'List of available languages in "x" (2):\neng\nkor\n'
  exit 0
fi
exit 0
SH
  chmod +x "$bindir/tesseract"

  cat > "$tmpdir/legal-books/scripts/ingest.py" <<'PY'
#!/usr/bin/env python3
raise SystemExit(9)
PY

  set +e
  output=$(
    HOME="$tmpdir" PATH="$bindir:$PATH" bash "$SCRIPT" \
      --pdf "$tmpdir/scan.pdf" \
      --author "저자" \
      --title "민법총칙" \
      --edition "제1판" \
      --year 2026 \
      --publisher "출판사" 2>&1
  )
  status=$?
  set -e

  if [[ "$status" -eq 0 ]]; then
    fail "add_book fails when ingest fails"
  elif compgen -G "$tmpdir/legal-books/books/001_*" >/dev/null; then
    fail "add_book does not create completed folder on ingest failure"
    printf '%s\n' "$output" >&2
  elif compgen -G "$tmpdir/legal-books/books/.001_*.incomplete" >/dev/null; then
    fail "add_book removes incomplete folder after ingest failure"
    printf '%s\n' "$output" >&2
  else
    printf 'ok - add_book cleans incomplete folder after ingest failure\n'
  fi

  rm -rf "$tmpdir"
}

expect_markdown_source_skips_ocr_tools() {
  local tmpdir bindir output status marker final_dir
  tmpdir="$(mktemp -d)"
  bindir="$tmpdir/bin"
  mkdir -p "$bindir" "$tmpdir/legal-books/.venv/bin" "$tmpdir/legal-books/books" "$tmpdir/legal-books/db" "$tmpdir/legal-books/scripts"
  touch "$tmpdir/legal-books/.venv/bin/activate"
  printf '# 저자 - 민법총칙\n\n## p.1\n\n본문\n' > "$tmpdir/book.md"
  marker="$tmpdir/ingest_args.txt"

  cat > "$bindir/ocrmypdf" <<'SH'
#!/usr/bin/env bash
exit 88
SH
  chmod +x "$bindir/ocrmypdf"

  cat > "$bindir/tesseract" <<'SH'
#!/usr/bin/env bash
exit 88
SH
  chmod +x "$bindir/tesseract"

  cat > "$tmpdir/legal-books/scripts/ingest.py" <<'PY'
#!/usr/bin/env python3
import os
import pathlib
import sys

args = sys.argv[1:]
marker = pathlib.Path(os.environ["MARKER"])
marker.write_text(" ".join(args), encoding="utf-8")
book_dir = pathlib.Path(args[args.index("--book-dir") + 1])
book_id = args[args.index("--book-id") + 1]
(book_dir / f"{book_id}.md").write_text("ok", encoding="utf-8")
(book_dir / f"{book_id}.meta.json").write_text("{}", encoding="utf-8")
PY

  set +e
  output=$(
    HOME="$tmpdir" PATH="$bindir:$PATH" MARKER="$marker" bash "$SCRIPT" \
      --md "$tmpdir/book.md" \
      --author "저자" \
      --title "민법총칙" \
      --edition "제1판" \
      --year 2026 \
      --publisher "출판사" 2>&1
  )
  status=$?
  set -e

  final_dir="$(find "$tmpdir/legal-books/books" -maxdepth 1 -type d -name '001_*' -print -quit)"
  if [[ "$status" -ne 0 ]]; then
    fail "add_book accepts markdown without OCR tools"
    printf '%s\n' "$output" >&2
  elif [[ -z "$final_dir" ]]; then
    fail "add_book creates completed folder for markdown source"
    printf '%s\n' "$output" >&2
  elif ! grep -q -- "--md $tmpdir/book.md" "$marker"; then
    fail "add_book passes markdown source to ingest"
    printf '%s\n' "$output" >&2
  else
    printf 'ok - add_book skips OCR tools for markdown source\n'
  fi

  rm -rf "$tmpdir"
}

expect_failed_ingest_cleans_incomplete_folder
expect_markdown_source_skips_ocr_tools

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
