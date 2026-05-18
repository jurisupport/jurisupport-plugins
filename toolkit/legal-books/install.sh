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

PLAN_MODE=0
for arg in "$@"; do
  case "$arg" in
    --plan|--dry-run) PLAN_MODE=1 ;;
    *) error "unknown option: $arg (supported: --plan, --dry-run)" ;;
  esac
done

DRY_RUN="${DRY_RUN:-${JURISUPPORT_DRY_RUN:-0}}"
if [[ "$PLAN_MODE" -eq 1 ]]; then
  DRY_RUN=1
fi
is_dry_run() { [[ "${DRY_RUN:-0}" == "1" || "${DRY_RUN:-0}" == "true" || "${DRY_RUN:-0}" == "yes" ]]; }
plan() { echo "PLAN: $*"; }
run_or_plan() {
  if is_dry_run; then
    plan "$*"
  else
    "$@"
  fi
}
run_shell_or_plan() {
  if is_dry_run; then
    plan "$*"
  else
    bash -c "$*"
  fi
}

print_plan() {
  cat <<'EOF'
GREEN: toolkit/legal-books/install.sh --plan / --dry-run (no changes will be made)
- Would check python3, ocrmypdf, tesseract, curl and Korean OCR language pack.
- Would create $HOME/legal-books layout, Python venv, and install FastAPI/uvicorn/Gemini/pdf dependencies.
- Would initialize SQLite FTS DB and optionally write Gemini API key under $HOME/.jurisupport/secrets.env.
- Would copy server/scripts and Claude Code legal-books skill.
- Would start search server on port 8766 and health-check with curl.
- Guard: in --plan/--dry-run mode this script exits before mkdir/venv/pip/python DB/secrets/cp/chmod/server/curl operations.
EOF
}

if is_dry_run; then
  print_plan
fi

# ============================================================
# Detect OS
# ============================================================
OS="$(uname -s)"
case "$OS" in
  Darwin*) PLATFORM="mac" ;;
  Linux*)  PLATFORM="linux" ;;
  *) error "지원하지 않는 OS: $OS (macOS/Linux만 지원). Windows는 WSL2 사용." ;;
esac
info "플랫폼: $PLATFORM"

# ============================================================
# Check prerequisites
# ============================================================
info "필수 도구 확인 중..."

check_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "$1 필요. $2"
  fi
}

if is_dry_run; then plan "command -v python3"; else check_cmd python3 "먼저 Python 3.10+ 설치."; fi
if is_dry_run; then plan "command -v ocrmypdf"; else check_cmd ocrmypdf "설치: brew install ocrmypdf (Mac) 또는 apt install ocrmypdf (Linux)"; fi
if is_dry_run; then plan "command -v tesseract"; else check_cmd tesseract "설치: brew install tesseract tesseract-lang (Mac) 또는 apt install tesseract-ocr tesseract-ocr-kor (Linux)"; fi
if is_dry_run; then plan "command -v curl"; else check_cmd curl "curl 필요."; fi

# Check Tesseract Korean
if is_dry_run; then plan "tesseract --list-langs | grep kor"; elif ! tesseract --list-langs 2>&1 | grep -q "kor"; then
  error "Tesseract 한국어 언어팩 미설치. Mac: brew install tesseract-lang. Linux: apt install tesseract-ocr-kor"
fi

# Check Python version >= 3.10
if is_dry_run; then
  plan "python3 -c <check Python version >= 3.10>"
else
  PYV=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
  PYMAJ=$(echo "$PYV" | cut -d. -f1)
  PYMIN=$(echo "$PYV" | cut -d. -f2)
  if [[ "$PYMAJ" -lt 3 ]] || [[ "$PYMAJ" -eq 3 && "$PYMIN" -lt 10 ]]; then
    error "Python 3.10 이상 필요 (현재 $PYV)"
  fi
fi

# ============================================================
# Directory layout
# ============================================================
ROOT="$HOME/legal-books"
info "디렉토리 구조 생성: $ROOT"
run_or_plan mkdir -p "$ROOT/books" "$ROOT/db" "$ROOT/server" "$ROOT/scripts" "$ROOT/logs"

# ============================================================
# Python venv + packages
# ============================================================
info "Python 가상환경 생성"
# Ubuntu/Debian은 python3-venv 별도 설치 필요
if [[ "$PLATFORM" == "linux" ]] && is_dry_run; then
  plan "python3 -c 'import ensurepip'; install python3-venv with apt-get if missing"
elif [[ "$PLATFORM" == "linux" ]] && ! python3 -c "import ensurepip" 2>/dev/null; then
  info "python3-venv 자동 설치 중..."
  PYV=$(python3 -c 'import sys; print(f"python3.{sys.version_info.minor}-venv")')
  run_shell_or_plan "sudo apt-get install -y '$PYV' python3-venv 2>&1 | tail -3 || sudo apt-get install -y python3-venv 2>&1 | tail -3"
  python3 -c "import ensurepip" 2>/dev/null || error "python3-venv 설치 실패. 수동: sudo apt install python3-venv"
fi
run_or_plan python3 -m venv "$ROOT/.venv"
# shellcheck disable=SC1091
if is_dry_run; then plan "source $ROOT/.venv/bin/activate"; else source "$ROOT/.venv/bin/activate"; fi

info "Python 패키지 설치 중 (수 분 소요)"
run_or_plan pip install --quiet --upgrade pip
run_or_plan pip install --quiet \
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
info "SQLite DB 초기화"
if is_dry_run; then
  plan "python3 initialize SQLite FTS DB"
else
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
print("DB 초기화 완료:", db_path)
PY
fi

# ============================================================
# Secrets (Gemini API key)
# ============================================================
SECRETS="$HOME/.jurisupport/secrets.env"
run_or_plan mkdir -p "$(dirname "$SECRETS")"
run_or_plan chmod 700 "$(dirname "$SECRETS")"

if [[ -f "$SECRETS" ]] && grep -q "GEMINI_API_KEY" "$SECRETS"; then
  if is_dry_run; then info "Gemini API 키 등록 상태 확인 예정: $SECRETS (dry-run: 실제 변경 없음)"; else info "Gemini API 키 이미 등록됨: $SECRETS"; fi
else
  echo ""
  echo "================================================================"
  echo "  Gemini API 키 등록"
  echo "  무료 키 발급: https://aistudio.google.com/apikey"
  echo "================================================================"
  if is_dry_run; then plan "read Gemini API key prompt; default skip"; GEMINI_KEY=""; else read -r -p "Gemini API 키 입력 (건너뛰려면 Enter): " GEMINI_KEY; fi
  if [[ -n "${GEMINI_KEY:-}" ]]; then
    if is_dry_run; then plan "append GEMINI_API_KEY to $SECRETS"; else echo "GEMINI_API_KEY=${GEMINI_KEY}" >> "$SECRETS"; fi
    run_or_plan chmod 600 "$SECRETS"
    if is_dry_run; then info "저장 예정: $SECRETS chmod 600 (dry-run: 실제 변경 없음)"; else info "저장 완료: $SECRETS (chmod 600)"; fi
  else
    warn "건너뛰기. 나중에 $SECRETS 에 GEMINI_API_KEY=xxx 추가."
  fi
fi

# ============================================================
# Copy server and scripts from toolkit
# ============================================================
TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info "서버·스크립트 복사 중"
run_or_plan cp "$TOOLKIT_DIR/server/server.py" "$ROOT/server/server.py"
run_or_plan cp "$TOOLKIT_DIR/scripts/add_book.sh" "$ROOT/scripts/add_book.sh"
run_or_plan cp "$TOOLKIT_DIR/scripts/server.sh" "$ROOT/scripts/server.sh"
run_or_plan cp "$TOOLKIT_DIR/scripts/ingest.py" "$ROOT/scripts/ingest.py"
run_or_plan chmod +x "$ROOT/scripts/"*.sh

# ============================================================
# Install Claude Code skill
# ============================================================
info "클로드코드 스킬 설치 중"
SKILL_DST="$HOME/.claude/skills/legal-books"
run_or_plan mkdir -p "$SKILL_DST"
run_or_plan cp "$TOOLKIT_DIR/../../skills/legal-books/SKILL.md" "$SKILL_DST/SKILL.md"

# ============================================================
# Start server (background)
# ============================================================
info "검색 서버 시작 (포트 8766)"
run_or_plan "$ROOT/scripts/server.sh" start

if is_dry_run; then plan "sleep 2"; else sleep 2; fi
if is_dry_run; then
  plan "curl -sf http://localhost:8766/health"
elif curl -sf http://localhost:8766/health >/dev/null; then
  if is_dry_run; then info "서버 실행 확인 예정: curl http://localhost:8766/health (dry-run: 실제 변경 없음)"; else info "서버 실행 중. 확인: curl http://localhost:8766/health"; fi
else
  warn "서버 응답 없음. 로그 확인: $ROOT/logs/server.log"
fi

# ============================================================
# Done
# ============================================================
echo ""
echo -e "${GREEN}========================================${NC}"
if is_dry_run; then echo -e "${GREEN}legal-books toolkit PLAN 완료 (dry-run: 실제 변경 없음)${NC}"; else echo -e "${GREEN}legal-books toolkit 설치 완료${NC}"; fi
echo -e "${GREEN}========================================${NC}"
cat <<EOF

다음 단계:
  1. 첫 책 스캔 (300dpi, 컬러)
  2. 추가:
       ~/legal-books/scripts/add_book.sh \\
         --pdf /경로/scan.pdf \\
         --author "곽윤직" --title "민법총칙" \\
         --edition "제9판" --year 2018 --publisher "박영사"
  3. 검색 테스트:
       curl -X POST http://localhost:8766/search \\
         -H 'Content-Type: application/json' \\
         -d '{"query":"소멸시효","top_k":3}'
  4. 클로드코드에서:
       "민법 시효 쟁점에 대해 교과서 바탕으로 정리해줘"

가이드: ~/jurisupport-plugins/guides/02_book_scanning.md
EOF
