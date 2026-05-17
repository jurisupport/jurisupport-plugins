#!/usr/bin/env bash
# case-records toolkit installer (Mac/Linux)
#
# Same structure as legal-books but for case files. Port 8767.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[info]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*"; }
error() { echo -e "${RED}[error]${NC} $*"; exit 1; }

OS="$(uname -s)"
case "$OS" in
  Darwin*) PLATFORM="mac" ;;
  Linux*)  PLATFORM="linux" ;;
  *) error "Unsupported OS: $OS (Mac/Linux only)" ;;
esac
info "Platform: $PLATFORM"

# Prerequisites
command -v python3 >/dev/null || error "Python 3.10+ required"
command -v curl >/dev/null || error "curl required"

ROOT="$HOME/case-records"
info "Creating $ROOT"
mkdir -p "$ROOT/cases" "$ROOT/db" "$ROOT/server" "$ROOT/scripts" "$ROOT/logs"

info "Creating Python venv"
python3 -m venv "$ROOT/.venv"
# shellcheck disable=SC1091
source "$ROOT/.venv/bin/activate"
pip install --quiet --upgrade pip
pip install --quiet \
  fastapi==0.115.0 uvicorn==0.31.0 pydantic==2.9.2 \
  sqlite-utils==3.37 google-genai==0.3.0 pypdf==5.0.1 \
  numpy==1.26.4 python-dotenv==1.0.1 python-docx==1.1.2

info "Initializing SQLite DB"
python3 - <<'PY'
import sqlite3, os
ROOT = os.path.expanduser("~/case-records")
db_path = os.path.join(ROOT, "db", "cases_fts.db")
con = sqlite3.connect(db_path)
con.executescript("""
CREATE TABLE IF NOT EXISTS cases (
  case_id TEXT PRIMARY KEY,
  case_name TEXT,
  status TEXT,            -- 종결/진행중/중지
  result TEXT,            -- 전부승소/일부승소/패소/조정/취하 등
  court TEXT,
  added_at TEXT DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS documents (
  doc_id TEXT PRIMARY KEY,
  case_id TEXT NOT NULL REFERENCES cases(case_id),
  doc_type TEXT,          -- 소장/답변서/준비서면/판결문 등
  doc_date TEXT,
  author_role TEXT,       -- 우리측/상대측/법원/원고/피고
  source_file TEXT
);
CREATE TABLE IF NOT EXISTS chunks (
  chunk_id TEXT PRIMARY KEY,
  doc_id TEXT NOT NULL REFERENCES documents(doc_id),
  case_id TEXT NOT NULL REFERENCES cases(case_id),
  chunk_text TEXT NOT NULL,
  embedding BLOB
);
CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
  chunk_text, chunk_id UNINDEXED, case_id UNINDEXED, doc_id UNINDEXED,
  content='chunks', content_rowid='rowid', tokenize='unicode61'
);
""")
con.commit()
con.close()
print("DB initialized")
PY

# Reuse Gemini key from legal-books if exists
SECRETS="$HOME/.jurisupport/secrets.env"
if [[ ! -f "$SECRETS" ]] || ! grep -q "GEMINI_API_KEY" "$SECRETS"; then
  mkdir -p "$(dirname "$SECRETS")"; chmod 700 "$(dirname "$SECRETS")"
  echo ""
  echo "Gemini API key not yet registered (used for embeddings)."
  echo "Get a free key at: https://aistudio.google.com/apikey"
  read -r -p "Enter Gemini API key (or press Enter to skip): " GEMINI_KEY
  if [[ -n "${GEMINI_KEY:-}" ]]; then
    echo "GEMINI_API_KEY=${GEMINI_KEY}" >> "$SECRETS"
    chmod 600 "$SECRETS"
  fi
else
  info "Reusing existing Gemini API key from $SECRETS"
fi

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$TOOLKIT_DIR/server/server.py" "$ROOT/server/server.py"
cp "$TOOLKIT_DIR/scripts/"*.{sh,py} "$ROOT/scripts/"
chmod +x "$ROOT/scripts/"*.sh

# Install skill
SKILL_DST="$HOME/.claude/skills/case-records"
mkdir -p "$SKILL_DST"
cp "$TOOLKIT_DIR/../../skills/case-records/SKILL.md" "$SKILL_DST/SKILL.md"

# Start server
"$ROOT/scripts/server.sh" start
sleep 2
if curl -sf http://localhost:8767/health >/dev/null; then
  info "Server running on port 8767"
else
  warn "Server start failed. Check $ROOT/logs/server.log"
fi

cat <<EOF

${GREEN}========================================
case-records toolkit installed.
========================================${NC}

Next steps:
  1. Index your first case:
       ~/case-records/scripts/ingest_case.sh \\
         --case-dir ~/사건/2018가단11111_홍○○_대여금 \\
         --case-id 2018가단11111 \\
         --case-name "홍○○ 대여금" \\
         --status 종결 --result 전부승소

  2. Or batch-index all cases under ~/사건/:
       ~/case-records/scripts/ingest_all.sh --root ~/사건

  3. Search test:
       curl -X POST http://localhost:8767/search \\
         -H 'Content-Type: application/json' \\
         -d '{"query":"보증금","top_k":3}'

Guide: ~/jurisupport-plugins/guides/03_case_records.md
EOF
