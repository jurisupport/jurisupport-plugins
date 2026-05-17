#!/usr/bin/env bash
# Add a book to legal-books DB.
#
# Usage:
#   add_book.sh --pdf /path/to/scan.pdf \
#               --author "곽윤직" --title "민법총칙" \
#               --edition "제9판" --year 2018 --publisher "박영사"

set -euo pipefail

ROOT="$HOME/legal-books"
VENV="$ROOT/.venv/bin/activate"

PDF=""; AUTHOR=""; TITLE=""; EDITION=""; YEAR=""; PUBLISHER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pdf)        PDF="$2"; shift 2 ;;
    --author)     AUTHOR="$2"; shift 2 ;;
    --title)      TITLE="$2"; shift 2 ;;
    --edition)    EDITION="$2"; shift 2 ;;
    --year)       YEAR="$2"; shift 2 ;;
    --publisher)  PUBLISHER="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

for v in PDF AUTHOR TITLE; do
  if [[ -z "${!v}" ]]; then
    echo "Required: --pdf, --author, --title" >&2
    exit 1
  fi
done

if [[ ! -f "$PDF" ]]; then
  echo "PDF not found: $PDF" >&2; exit 1
fi

# Allocate book_id (next available 3-digit)
NEXT_ID=$(ls "$ROOT/books" 2>/dev/null | grep -E '^[0-9]{3}_' | sort -r | head -1 | cut -d_ -f1)
NEXT_ID=$(( 10#${NEXT_ID:-000} + 1 ))
BOOK_ID=$(printf "%03d" "$NEXT_ID")

# Sanitize for folder name
SAFE_TITLE=$(echo "$TITLE" | tr -d '/\\:*?"<>|')
SAFE_AUTHOR=$(echo "$AUTHOR" | tr -d '/\\:*?"<>|')
BOOK_DIR="$ROOT/books/${BOOK_ID}_${SAFE_AUTHOR}_${SAFE_TITLE}_${EDITION}"
mkdir -p "$BOOK_DIR"

echo "[add_book] Book ID: $BOOK_ID"
echo "[add_book] Folder:  $BOOK_DIR"

# Step 1: OCR (if PDF doesn't already have text layer)
OCR_PDF="$BOOK_DIR/${BOOK_ID}.pdf"
echo "[add_book] Step 1/3: OCR (Korean + English, this may take 5–20 min)"
ocrmypdf --skip-text --language kor+eng --output-type pdf "$PDF" "$OCR_PDF" || {
  echo "OCR failed. If the PDF already has text, try --force-ocr flag." >&2
  exit 1
}

# Step 2: Convert to markdown + chunk + embed
# shellcheck disable=SC1090
source "$VENV"
echo "[add_book] Step 2/3: Extracting text and chunking"
python3 "$ROOT/scripts/ingest.py" \
  --book-id "$BOOK_ID" \
  --pdf "$OCR_PDF" \
  --book-dir "$BOOK_DIR" \
  --author "$AUTHOR" \
  --title "$TITLE" \
  --edition "$EDITION" \
  --year "$YEAR" \
  --publisher "$PUBLISHER"

echo "[add_book] Step 3/3: Done. Book $BOOK_ID indexed."
echo ""
echo "Search test:"
echo "  curl -X POST http://localhost:8766/search -H 'Content-Type: application/json' -d '{\"query\":\"$TITLE\",\"top_k\":3}'"
