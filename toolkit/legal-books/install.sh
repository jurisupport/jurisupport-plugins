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
  Darwin*)              PLATFORM="mac" ;;
  Linux*)               PLATFORM="linux" ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
  *) error "지원하지 않는 OS: $OS (macOS/Linux/Windows Git Bash만 지원)" ;;
esac
info "플랫폼: $PLATFORM"

# Python 명령 + venv activate 경로
if [[ "$PLATFORM" == "windows" ]]; then
  PY="$(command -v python3 2>/dev/null || command -v python 2>/dev/null)"
  [[ -z "$PY" ]] && error "Python 미설치. PowerShell: winget install Python.Python.3.12"
  VENV_ACTIVATE="Scripts/activate"
else
  PY="python3"
  VENV_ACTIVATE="bin/activate"
fi

# ============================================================
# Check prerequisites
# ============================================================
info "필수 도구 확인 중..."

check_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    error "$1 필요. $2"
  fi
}

"$PY" --version >/dev/null 2>&1 || error "Python 3.10+ 필요."
check_cmd ocrmypdf "Mac: brew install ocrmypdf | Linux: apt install ocrmypdf | Windows: pip install ocrmypdf (windows-bootstrap.ps1이 의존성 자동 설치)"
check_cmd tesseract "Mac: brew install tesseract tesseract-lang | Linux: apt install tesseract-ocr tesseract-ocr-kor | Windows: winget install UB-Mannheim.TesseractOCR"
check_cmd curl "curl 필요."

# Check Tesseract Korean
if ! tesseract --list-langs 2>&1 | grep -q "kor"; then
  error "Tesseract 한국어 언어팩 미설치. Mac: brew install tesseract-lang. Linux: apt install tesseract-ocr-kor. Windows: UB-Mannheim 빌드 재설치(언어팩 포함)."
fi

# Check Python version >= 3.10
PYV=$("$PY" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYMAJ=$(echo "$PYV" | cut -d. -f1)
PYMIN=$(echo "$PYV" | cut -d. -f2)
if [[ "$PYMAJ" -lt 3 ]] || [[ "$PYMAJ" -eq 3 && "$PYMIN" -lt 10 ]]; then
  error "Python 3.10 이상 필요 (현재 $PYV)"
fi

# ============================================================
# Directory layout
# ============================================================
ROOT="$HOME/legal-books"
info "디렉토리 구조 생성: $ROOT"
mkdir -p "$ROOT/books" "$ROOT/db" "$ROOT/server" "$ROOT/scripts" "$ROOT/logs"

# ============================================================
# Python venv + packages
# ============================================================
info "Python 가상환경 생성"
# Ubuntu/Debian은 python3-venv 별도 설치 필요
if [[ "$PLATFORM" == "linux" ]] && ! "$PY" -c "import ensurepip" 2>/dev/null; then
  info "python3-venv 자동 설치 중..."
  PYV=$("$PY" -c 'import sys; print(f"python3.{sys.version_info.minor}-venv")')
  sudo apt-get install -y "$PYV" python3-venv 2>&1 | tail -3 || \
    sudo apt-get install -y python3-venv 2>&1 | tail -3
  "$PY" -c "import ensurepip" 2>/dev/null || error "python3-venv 설치 실패. 수동: sudo apt install python3-venv"
fi
"$PY" -m venv "$ROOT/.venv"
# shellcheck disable=SC1091
source "$ROOT/.venv/$VENV_ACTIVATE"

info "Python 패키지 설치 중 (수 분 소요)"
pip install --quiet --upgrade pip
# Windows에선 ocrmypdf도 pip로 설치 (ghostscript·qpdf·tesseract는 winget으로 시스템 설치됨)
if [[ "$PLATFORM" == "windows" ]]; then
  pip install --quiet ocrmypdf
fi
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
info "SQLite DB 초기화"
"$PY" - <<'PY'
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

# ============================================================
# Secrets (Gemini API key)
# ============================================================
SECRETS="$HOME/.jurisupport/secrets.env"
mkdir -p "$(dirname "$SECRETS")"
chmod 700 "$(dirname "$SECRETS")"

if [[ -f "$SECRETS" ]] && grep -q "GEMINI_API_KEY" "$SECRETS"; then
  info "Gemini API 키 이미 등록됨: $SECRETS"
else
  echo ""
  echo "================================================================"
  echo "  Gemini API 키 등록"
  echo "  무료 키 발급: https://aistudio.google.com/apikey"
  echo "================================================================"
  read -r -p "Gemini API 키 입력 (건너뛰려면 Enter): " GEMINI_KEY
  if [[ -n "${GEMINI_KEY:-}" ]]; then
    echo "GEMINI_API_KEY=${GEMINI_KEY}" >> "$SECRETS"
    chmod 600 "$SECRETS"
    info "저장 완료: $SECRETS (chmod 600)"
  else
    warn "건너뛰기. 나중에 $SECRETS 에 GEMINI_API_KEY=xxx 추가."
  fi
fi

# ============================================================
# Copy server and scripts from toolkit
# ============================================================
TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info "서버·스크립트 복사 중"
cp "$TOOLKIT_DIR/server/server.py" "$ROOT/server/server.py"
cp "$TOOLKIT_DIR/scripts/add_book.sh" "$ROOT/scripts/add_book.sh"
cp "$TOOLKIT_DIR/scripts/server.sh" "$ROOT/scripts/server.sh"
cp "$TOOLKIT_DIR/scripts/ingest.py" "$ROOT/scripts/ingest.py"
# Windows: PowerShell 래퍼도 복사
if [[ "$PLATFORM" == "windows" ]] && ls "$TOOLKIT_DIR/scripts/"*.ps1 >/dev/null 2>&1; then
  cp "$TOOLKIT_DIR/scripts/"*.ps1 "$ROOT/scripts/"
fi
chmod +x "$ROOT/scripts/"*.sh 2>/dev/null || true

# ============================================================
# Install Claude Code skill
# ============================================================
info "클로드코드 스킬 설치 중"
SKILL_DST="$HOME/.claude/skills/legal-books"
mkdir -p "$SKILL_DST"
cp "$TOOLKIT_DIR/../../skills/legal-books/SKILL.md" "$SKILL_DST/SKILL.md"

# ============================================================
# Start server (background)
# ============================================================
info "검색 서버 시작 (포트 8766)"
if [[ "$PLATFORM" == "windows" ]]; then
  powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$ROOT/scripts/server.ps1")" start
else
  "$ROOT/scripts/server.sh" start
fi

sleep 2
if curl -sf http://localhost:8766/health >/dev/null; then
  info "서버 실행 중. 확인: curl http://localhost:8766/health"
else
  warn "서버 응답 없음. 로그 확인: $ROOT/logs/server.log"
fi

# ============================================================
# Done
# ============================================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}legal-books toolkit 설치 완료${NC}"
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
