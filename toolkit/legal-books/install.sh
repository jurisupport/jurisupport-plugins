#!/usr/bin/env bash
# legal-books toolkit installer (Mac/Linux)
#
# Sets up:
# - ~/legal-books/ directory structure
# - Python venv with required packages
# - Empty SQLite DB
# - Gemini API key registration
# - Search server start script

set -euo pipefail

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

info()  { echo -e "${GREEN}[info]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*"; }
error() { echo -e "${RED}[error]${NC} $*"; exit 1; }

# ============================================================
# Detect OS
# ============================================================
OS="$(uname -s)"
case "$OS" in
  Darwin*) PLATFORM="mac" ;;
  Linux*)  PLATFORM="linux" ;;
  *) error "Unsupported OS: $OS (Mac/Linux only). Windows users should use WSL2." ;;
esac
info "Detected platform: $PLATFORM"

# ============================================================
# Check prerequisites
# ============================================================
info "Checking prerequisites..."

check_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "$1 is required but not installed. $2"
  fi
}

check_cmd python3 "Install Python 3.10+ first."
check_cmd ocrmypdf "Run: brew install ocrmypdf  (Mac) or apt install ocrmypdf (Linux)"
check_cmd tesseract "Run: brew install tesseract tesseract-lang  (Mac) or apt install tesseract-ocr tesseract-ocr-kor (Linux)"
check_cmd curl "curl is required."

# Check Tesseract Korean
if ! tesseract --list-langs 2>&1 | grep -q "kor"; then
  error "Tesseract Korean language pack not installed. Mac: brew install tesseract-lang. Linux: apt install tesseract-ocr-kor"
fi

# Check Python version >= 3.10
PYV=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYMAJ=$(echo "$PYV" | cut -d. -f1)
PYMIN=$(echo "$PYV" | cut -d. -f2)
if [[ "$PYMAJ" -lt 3 ]] || [[ "$PYMAJ" -eq 3 && "$PYMIN" -lt 10 ]]; then
  error "Python 3.10+ required (found $PYV)"
fi

# ============================================================
# Directory layout
# ============================================================
ROOT="$HOME/legal-books"
info "Creating directory layout at $ROOT"
mkdir -p "$ROOT/books" "$ROOT/db" "$ROOT/server" "$ROOT/scripts" "$ROOT/logs"

# ============================================================
# Python venv + packages
# ============================================================
info "Creating Python venv"
python3 -m venv "$ROOT/.venv"
# shellcheck disable=SC1091
source "$ROOT/.venv/bin/activate"

info "Installing Python packages (this may take a few minutes)"
pip install --quiet --upgrade pip
pip install --quiet \
  fastapi==0.115.0 \
  uvicorn==0.31.0 \
  pydantic==2.9.2 \
  sqlite-utils==3.37 \
  google-genai==0.3.0 \
  pypdf==5.0.1 \
  numpy==1.26.4 \
  python-dotenv==1.0.1

# ============================================================
# Initialize SQLite DB
# ============================================================
info "Initializing SQLite DB"
python3 - <<'PY'
import sqlite3, os, pathlib
ROOT = os.path.expanduser("~/legal-books")
db_path = os.path.join(ROOT, "db", "books_fts.db")
con = sqlite3.connect(db_path)
con.executescript("""
CREATE TABLE IF NOT EXISTS books (
  book_id TEXT PRIMARY KEY,
  author TEXT, title TEXT, edition TEXT, year INTEGER, publisher TEXT,
  added_at TEXT DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS chunks (
  chunk_id TEXT PRIMARY KEY,
  book_id TEXT NOT NULL REFERENCES books(book_id),
  page INTEGER,
  chunk_text TEXT NOT NULL,
  embedding BLOB
);
CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
  chunk_text, chunk_id UNINDEXED, book_id UNINDEXED, page UNINDEXED,
  content='chunks', content_rowid='rowid', tokenize='unicode61'
);
""")
con.commit()
con.close()
print("DB initialized at", db_path)
PY

# ============================================================
# Secrets (Gemini API key)
# ============================================================
SECRETS="$HOME/.jurisupport/secrets.env"
mkdir -p "$(dirname "$SECRETS")"
chmod 700 "$(dirname "$SECRETS")"

if [[ -f "$SECRETS" ]] && grep -q "GEMINI_API_KEY" "$SECRETS"; then
  info "Gemini API key already registered in $SECRETS"
else
  echo ""
  echo "================================================================"
  echo "  Gemini API key registration"
  echo "  Get a free key at: https://aistudio.google.com/apikey"
  echo "================================================================"
  read -r -p "Enter your Gemini API key (or press Enter to skip): " GEMINI_KEY
  if [[ -n "${GEMINI_KEY:-}" ]]; then
    echo "GEMINI_API_KEY=${GEMINI_KEY}" >> "$SECRETS"
    chmod 600 "$SECRETS"
    info "Saved to $SECRETS (chmod 600)"
  else
    warn "Skipped. Set later by adding GEMINI_API_KEY=xxx to $SECRETS"
  fi
fi

# ============================================================
# Copy server and scripts from toolkit
# ============================================================
TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info "Copying server and scripts"
cp "$TOOLKIT_DIR/server/server.py" "$ROOT/server/server.py"
cp "$TOOLKIT_DIR/scripts/add_book.sh" "$ROOT/scripts/add_book.sh"
cp "$TOOLKIT_DIR/scripts/server.sh" "$ROOT/scripts/server.sh"
cp "$TOOLKIT_DIR/scripts/ingest.py" "$ROOT/scripts/ingest.py"
chmod +x "$ROOT/scripts/"*.sh

# ============================================================
# Install Claude Code skill
# ============================================================
info "Installing Claude Code skill"
SKILL_DST="$HOME/.claude/skills/legal-books"
mkdir -p "$SKILL_DST"
cp "$TOOLKIT_DIR/../../skills/legal-books/SKILL.md" "$SKILL_DST/SKILL.md"

# ============================================================
# Start server (background)
# ============================================================
info "Starting search server on port 8766"
"$ROOT/scripts/server.sh" start

sleep 2
if curl -sf http://localhost:8766/health >/dev/null; then
  info "Server is running. Test: curl http://localhost:8766/health"
else
  warn "Server did not respond. Check logs: $ROOT/logs/server.log"
fi

# ============================================================
# Done
# ============================================================
cat <<EOF

${GREEN}========================================
legal-books toolkit installed.
========================================${NC}

Next steps:
  1. Scan your first book (300dpi, color)
  2. Add it:
       ~/legal-books/scripts/add_book.sh \\
         --pdf /path/to/scan.pdf \\
         --author "곽윤직" --title "민법총칙" \\
         --edition "제9판" --year 2018 --publisher "박영사"
  3. Search test:
       curl -X POST http://localhost:8766/search \\
         -H 'Content-Type: application/json' \\
         -d '{"query":"소멸시효","top_k":3}'
  4. In Claude Code:
       "민법 시효 쟁점에 대해 교과서 바탕으로 정리해줘"

Guide: ~/jurisupport-plugins/guides/02_book_scanning.md
EOF
