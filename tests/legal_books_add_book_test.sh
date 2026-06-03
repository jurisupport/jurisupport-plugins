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

expect_failed_ingest_cleans_incomplete_folder

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
