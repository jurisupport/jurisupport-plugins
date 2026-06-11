#!/usr/bin/env bash
# Add a book to legal-books DB.
#
# Usage:
#   add_book.sh --pdf /path/to/scan.pdf \
#               --author "곽윤직" --title "민법총칙" \
#               --edition "제9판" --year 2018 --publisher "박영사"
#
#   add_book.sh --md /path/to/book.md \
#               --author "곽윤직" --title "민법총칙" \
#               --edition "제9판" --year 2018 --publisher "박영사"

set -euo pipefail

ROOT="$HOME/legal-books"
# OS 감지 → venv activate 경로 (Windows venv는 Scripts/, 그 외는 bin/)
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) VENV="$ROOT/.venv/Scripts/activate"; PY=python; PLATFORM=windows ;;
  Darwin*)              VENV="$ROOT/.venv/bin/activate";     PY=python3; PLATFORM=mac ;;
  *)                    VENV="$ROOT/.venv/bin/activate";     PY=python3; PLATFORM=linux ;;
esac

expand_user_path() {
  case "$1" in
    "~") printf '%s\n' "$HOME" ;;
    "~/"*) printf '%s\n' "$HOME/${1#~/}" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

sanitize_path_segment() {
  printf '%s' "$1" | tr -d '/\\:*?"<>|'
}

check_ocr_dependencies() {
  local missing=""
  command -v ocrmypdf  >/dev/null 2>&1 || missing+="ocrmypdf "
  command -v tesseract >/dev/null 2>&1 || missing+="tesseract "
  if [[ -n "$missing" ]]; then
    echo "[add_book] 다음 도구가 필요합니다: $missing" >&2
    echo "" >&2
    case "$PLATFORM" in
      mac)
        echo "  설치: brew install ocrmypdf tesseract tesseract-lang" >&2 ;;
      linux)
        echo "  설치: sudo apt install ocrmypdf tesseract-ocr tesseract-ocr-kor" >&2 ;;
      windows)
        echo "  설치 (PowerShell):" >&2
        echo "    winget install UB-Mannheim.TesseractOCR" >&2
        echo "    winget install ArtifexSoftware.GhostScript.AGPL" >&2
        echo "    winget install qpdf.qpdf       # 없으면 https://github.com/qpdf/qpdf/releases" >&2
        echo "    그리고 venv 안에서:" >&2
        echo "      source ~/legal-books/.venv/Scripts/activate" >&2
        echo "      pip install ocrmypdf" >&2
        echo "  설치 후 새 Git Bash 창에서 본 스크립트 재실행" >&2
        ;;
    esac
    exit 1
  fi

  if ! tesseract --list-langs 2>&1 | grep -q "kor"; then
    echo "[add_book] Tesseract 한국어 언어팩(kor) 없음." >&2
    echo "  Mac:    brew install tesseract-lang" >&2
    echo "  Linux:  sudo apt install tesseract-ocr-kor" >&2
    echo "  Windows: UB-Mannheim 빌드 재설치(설치 마법사에서 'Korean' 체크)" >&2
    exit 1
  fi
}

PDF=""; MD=""; AUTHOR=""; TITLE=""; EDITION=""; YEAR="0"; PUBLISHER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --pdf)        PDF="$2"; shift 2 ;;
    --md)         MD="$2"; shift 2 ;;
    --author)     AUTHOR="$2"; shift 2 ;;
    --title)      TITLE="$2"; shift 2 ;;
    --edition)    EDITION="$2"; shift 2 ;;
    --year)       YEAR="$2"; shift 2 ;;
    --publisher)  PUBLISHER="$2"; shift 2 ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

if [[ -n "$PDF" && -n "$MD" ]]; then
  echo "Use exactly one source: --pdf or --md" >&2
  exit 1
fi
if [[ -z "$PDF" && -z "$MD" ]]; then
  echo "Required: one of --pdf or --md" >&2
  exit 1
fi

for v in AUTHOR TITLE; do
  if [[ -z "${!v}" ]]; then
    echo "Required: --author, --title" >&2
    exit 1
  fi
done

INGEST_SOURCE_ARGS=()
SOURCE_KIND=""
if [[ -n "$PDF" ]]; then
  PDF="$(expand_user_path "$PDF")"
  if [[ ! -f "$PDF" ]]; then
    echo "PDF not found: $PDF" >&2; exit 1
  fi
  check_ocr_dependencies
  SOURCE_KIND="pdf"
else
  MD="$(expand_user_path "$MD")"
  if [[ ! -f "$MD" ]]; then
    echo "Markdown not found: $MD" >&2; exit 1
  fi
  INGEST_SOURCE_ARGS=(--md "$MD")
  SOURCE_KIND="md"
fi

# shellcheck disable=SC1090
source "$VENV"

# Allocate book_id from both completed folders and DB rows.
BOOK_ID=$(ROOT="$ROOT" "$PY" <<'PY'
import os
import re
import sqlite3
from pathlib import Path

root = Path(os.environ["ROOT"])
ids = set()
books_dir = root / "books"
if books_dir.exists():
    for child in books_dir.iterdir():
        if child.is_dir():
            match = re.match(r"^(\d{3})_", child.name)
            if match:
                ids.add(int(match.group(1)))

db_path = root / "db" / "books_fts.db"
if db_path.exists():
    try:
        con = sqlite3.connect(db_path)
        try:
            for (book_id,) in con.execute("SELECT book_id FROM books"):
                if re.fullmatch(r"\d+", str(book_id)):
                    ids.add(int(book_id))
        finally:
            con.close()
    except sqlite3.Error:
        pass

print(f"{max(ids, default=0) + 1:03d}")
PY
)

# Sanitize for folder name
SAFE_TITLE=$(sanitize_path_segment "$TITLE")
SAFE_AUTHOR=$(sanitize_path_segment "$AUTHOR")
SAFE_EDITION=$(sanitize_path_segment "$EDITION")
FINAL_BOOK_DIR="$ROOT/books/${BOOK_ID}_${SAFE_AUTHOR}_${SAFE_TITLE}_${SAFE_EDITION}"
BOOK_DIR="$ROOT/books/.${BOOK_ID}_${SAFE_AUTHOR}_${SAFE_TITLE}_${SAFE_EDITION}.incomplete"

if [[ -e "$FINAL_BOOK_DIR" ]]; then
  echo "[add_book] target folder already exists: $FINAL_BOOK_DIR" >&2
  exit 1
fi
if [[ -e "$BOOK_DIR" ]]; then
  echo "[add_book] removing stale incomplete folder: $BOOK_DIR" >&2
  rm -rf "$BOOK_DIR"
fi
mkdir -p "$BOOK_DIR"

echo "[add_book] Book ID: $BOOK_ID"
echo "[add_book] Folder:  $FINAL_BOOK_DIR"

cleanup_failed_book_dir() {
  local status=$?
  if [[ "$status" -ne 0 && -n "${BOOK_DIR:-}" && -d "$BOOK_DIR" ]]; then
    if [[ "${LEGAL_BOOKS_KEEP_FAILED:-0}" == "1" ]]; then
      echo "[add_book] failed; keeping incomplete folder for debugging: $BOOK_DIR" >&2
    else
      echo "[add_book] failed; removing incomplete folder: $BOOK_DIR" >&2
      rm -rf "$BOOK_DIR"
    fi
  fi
}
trap cleanup_failed_book_dir EXIT

# Step 1: OCR (if PDF doesn't already have text layer)
if [[ "$SOURCE_KIND" == "pdf" ]]; then
  OCR_PDF="$BOOK_DIR/${BOOK_ID}.pdf"
  echo "[add_book] Step 1/3: OCR (Korean + English, this may take 5–20 min)"
  ocrmypdf --skip-text --language kor+eng --output-type pdf "$PDF" "$OCR_PDF" || {
    echo "OCR failed. If the PDF already has text, try --force-ocr flag." >&2
    exit 1
  }
  INGEST_SOURCE_ARGS=(--pdf "$OCR_PDF")
else
  echo "[add_book] Step 1/3: Reading markdown source"
fi

# Step 2: Convert to markdown + chunk + embed
echo "[add_book] Step 2/3: Extracting text and chunking"
"$PY" "$ROOT/scripts/ingest.py" \
  --book-id "$BOOK_ID" \
  "${INGEST_SOURCE_ARGS[@]}" \
  --book-dir "$BOOK_DIR" \
  --author "$AUTHOR" \
  --title "$TITLE" \
  --edition "$EDITION" \
  --year "$YEAR" \
  --publisher "$PUBLISHER"

mv "$BOOK_DIR" "$FINAL_BOOK_DIR"
trap - EXIT

echo "[add_book] Step 3/3: Done. Book $BOOK_ID indexed."
echo "[add_book] Folder:  $FINAL_BOOK_DIR"
echo ""
echo "Search test:"
echo "  curl -X POST http://localhost:8766/search -H 'Content-Type: application/json' -d '{\"query\":\"$TITLE\",\"top_k\":3}'"
