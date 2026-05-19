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
# Windows: py launcher가 가리키는 python.exe 절대경로를 추출
# (PY="py -3.12"처럼 공백 들어가면 "$PY" 인용 시 깨지므로)
# Windows 경로(C:\...)를 Git Bash에서 쓸 수 있는 POSIX(/c/...)로 변환
to_posix() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$1" 2>/dev/null || echo "$1"
  else
    echo "$1"
  fi
}

if [[ "$PLATFORM" == "windows" ]]; then
  if command -v py >/dev/null 2>&1 && py -3.12 --version >/dev/null 2>&1; then
    PY="$(to_posix "$(py -3.12 -c 'import sys; print(sys.executable)' 2>/dev/null)")"
    info "Python 3.12: $PY"
  elif command -v py >/dev/null 2>&1 && py -3.11 --version >/dev/null 2>&1; then
    PY="$(to_posix "$(py -3.11 -c 'import sys; print(sys.executable)' 2>/dev/null)")"
    info "Python 3.11: $PY (3.12 권장)"
  else
    PY="$(command -v python3 2>/dev/null || command -v python 2>/dev/null)"
    [[ -z "$PY" ]] && error "Python 미설치. PowerShell: winget install Python.Python.3.12"
    info "Python 경로: $PY ($("$PY" --version 2>&1))"
  fi
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
check_cmd curl "curl 필요."

# OCRmyPDF · Tesseract는 책 스캔(add_book.sh)할 때만 필요.
# 검색 서버는 OCR 없이도 가동 가능하므로 여기선 warn으로 강등.
OCR_READY=true
if ! command -v ocrmypdf >/dev/null 2>&1; then
  warn "ocrmypdf 미설치 — 책 스캔할 때만 필요. 검색 서버는 OCR 없이도 가동됩니다."
  case "$PLATFORM" in
    mac)     warn "  설치: brew install ocrmypdf" ;;
    linux)   warn "  설치: sudo apt install ocrmypdf" ;;
    windows) warn "  설치: 본 스크립트가 venv 안에 pip install ocrmypdf 시도 (ghostscript·qpdf 필요)" ;;
  esac
  OCR_READY=false
fi

if ! command -v tesseract >/dev/null 2>&1; then
  warn "tesseract 미설치 — 책 OCR에만 필요. (이미 OCR된 PDF 입력 시 불요)"
  case "$PLATFORM" in
    mac)     warn "  설치: brew install tesseract tesseract-lang" ;;
    linux)   warn "  설치: sudo apt install tesseract-ocr tesseract-ocr-kor" ;;
    windows) warn "  설치: PowerShell에서 'winget install UB-Mannheim.TesseractOCR' 후 새 Git Bash 창" ;;
  esac
  OCR_READY=false
elif ! tesseract --list-langs 2>&1 | grep -q "kor"; then
  warn "Tesseract 설치됨, 한국어 언어팩 없음 — 한글 책 OCR에 필요."
  case "$PLATFORM" in
    mac)     warn "  설치: brew install tesseract-lang" ;;
    linux)   warn "  설치: sudo apt install tesseract-ocr-kor" ;;
    windows) warn "  설치: UB-Mannheim 빌드 재설치(설치 마법사에서 'Korean' 체크)" ;;
  esac
  OCR_READY=false
fi

if $OCR_READY; then
  info "✓ OCR 도구 모두 준비됨 (ocrmypdf + tesseract + 한국어)"
else
  warn "→ 검색 서버는 가동 가능. 책 스캔하려면 위 안내 따라 보완 후 add_book.sh 실행."
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
# 기존 서버 중지 + 잠긴 venv 정리 (재실행 시 Permission denied 방지)
# ============================================================
if [[ -d "$ROOT/.venv" ]]; then
  info "기존 venv 발견 — 서버 중지 후 정리 시도"
  # 1) 서버 중지 (있다면)
  if [[ "$PLATFORM" == "windows" ]] && [[ -f "$ROOT/scripts/server.ps1" ]]; then
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$ROOT/scripts/server.ps1")" stop 2>/dev/null || true
  elif [[ -f "$ROOT/scripts/server.sh" ]]; then
    bash "$ROOT/scripts/server.sh" stop 2>/dev/null || true
  fi
  sleep 1
  # 2) venv 삭제
  if ! rm -rf "$ROOT/.venv" 2>/dev/null; then
    warn "기존 venv 삭제 실패. Python 프로세스가 잡고 있을 수 있음."
    if [[ "$PLATFORM" == "windows" ]]; then
      warn "PowerShell에서 다음 실행 후 재시도:"
      warn "  Get-Process python,pythonw -ErrorAction SilentlyContinue | Stop-Process -Force"
      warn "  Remove-Item -Recurse -Force '$ROOT/.venv'"
    else
      warn "수동 실행: pkill -f 'legal-books/.venv'; rm -rf '$ROOT/.venv'"
    fi
    error "venv 정리 필요."
  fi
  info "✓ 기존 venv 정리 완료"
fi

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
info "venv Python 버전: $(python --version 2>&1)"

info "Python 패키지 설치 중 (수 분 소요)"
python -m pip install --progress-bar on --upgrade pip
# Windows에선 ocrmypdf도 pip로 설치 (ghostscript·qpdf·tesseract는 winget으로 시스템 설치됨)
if [[ "$PLATFORM" == "windows" ]]; then
  pip install --progress-bar on --only-binary :all: ocrmypdf
fi
# --only-binary :all: → wheel만 사용 (Windows에 C 컴파일러 없어도 안전)
# numpy 버전 pin 풀기: Python 3.13+에서도 wheel 있는 최신 사용
# pydantic은 ocrmypdf 17.4.2+ 와 호환되는 2.12.5+ 범위 사용
# (이전엔 ==2.9.2로 못박아두어 ocrmypdf와 충돌)
pip install --progress-bar on --only-binary :all: \
  "fastapi>=0.115,<1" \
  "uvicorn>=0.31,<1" \
  "pydantic>=2.12.5,<3" \
  "sqlite-utils>=3.37" \
  "google-genai>=0.3" \
  "pypdf>=5,<6" \
  "numpy>=1.26,<3" \
  "python-dotenv>=1"

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
