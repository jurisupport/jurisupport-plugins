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

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TOOLKIT_DIR/../../lib/dry-run.sh" "$@"

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
info_or_plan "플랫폼: $PLATFORM"

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
info_or_plan "디렉토리 구조 생성: $ROOT"
run_or_plan mkdir -p "$ROOT/books" "$ROOT/db" "$ROOT/server" "$ROOT/scripts" "$ROOT/logs"

# ============================================================
# 기존 서버 중지 + 잠긴 venv 정리 (재실행 시 Permission denied 방지)
# ============================================================
if [[ -d "$ROOT/.venv" ]]; then
  info_or_plan "기존 venv 발견 — 서버 중지 후 정리 시도"
  if is_dry_run; then
    info_or_plan "서버 중지 + venv 삭제"
  else
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
fi

# ============================================================
# Python venv + packages
# ============================================================
info_or_plan "Python 가상환경 생성"
if is_dry_run; then
  # Ubuntu/Debian python3-venv 설치
  if [[ "$PLATFORM" == "linux" ]] && ! "$PY" -c "import ensurepip" 2>/dev/null; then
    info_or_plan "python3-venv 자동 설치"
  fi
  info_or_plan "venv 생성: $ROOT/.venv"
  info_or_plan "pip install: fastapi uvicorn pydantic sqlite-utils google-genai pypdf numpy python-dotenv"
  if [[ "$PLATFORM" == "windows" ]]; then
    info_or_plan "pip install: ocrmypdf (Windows)"
  fi
else
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
fi

# ============================================================
# Initialize SQLite DB
# ============================================================
info_or_plan "SQLite DB 초기화"
if is_dry_run; then
  info_or_plan "SQLite DB 생성: $ROOT/db/books_fts.db (books, chunks, chunks_fts 테이블)"
else
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
fi

# ============================================================
# Secrets (Gemini API key)
# ============================================================
SECRETS="$HOME/.jurisupport/secrets.env"
run_or_plan mkdir -p "$(dirname "$SECRETS")"
run_or_plan chmod 700 "$(dirname "$SECRETS")"

if [[ -f "$SECRETS" ]] && grep -q "GEMINI_API_KEY" "$SECRETS"; then
  info_or_plan "Gemini API 키 이미 등록됨: $SECRETS"
else
  if is_dry_run; then
    info_or_plan "Gemini API 키 입력 프롬프트 (interactive read)"
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
fi

# ============================================================
# Copy server and scripts from toolkit
# ============================================================
info_or_plan "서버·스크립트 복사 중"
run_or_plan cp "$TOOLKIT_DIR/server/server.py" "$ROOT/server/server.py"
run_or_plan cp "$TOOLKIT_DIR/scripts/add_book.sh" "$ROOT/scripts/add_book.sh"
run_or_plan cp "$TOOLKIT_DIR/scripts/server.sh" "$ROOT/scripts/server.sh"
run_or_plan cp "$TOOLKIT_DIR/scripts/ingest.py" "$ROOT/scripts/ingest.py"
# Windows: PowerShell 래퍼도 복사
if [[ "$PLATFORM" == "windows" ]] && ls "$TOOLKIT_DIR/scripts/"*.ps1 >/dev/null 2>&1; then
  run_shell_or_plan "cp '$TOOLKIT_DIR/scripts/'*.ps1 '$ROOT/scripts/'"
fi
run_shell_or_plan "chmod +x '$ROOT/scripts/'*.sh 2>/dev/null || true"

# ============================================================
# Install Claude Code skill
# ============================================================
info_or_plan "클로드코드 스킬 설치 중"
SKILL_DST="$HOME/.claude/skills/legal-books"
run_or_plan mkdir -p "$SKILL_DST"
run_or_plan cp "$TOOLKIT_DIR/../../skills/legal-books/SKILL.md" "$SKILL_DST/SKILL.md"

# ============================================================
# Start server (background)
# ============================================================
info_or_plan "검색 서버 시작 (포트 8766)"
if is_dry_run; then
  info_or_plan "서버 시작 + health check: curl http://localhost:8766/health"
else
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
fi

# ============================================================
# Done
# ============================================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}legal-books toolkit 설치 완료 — 검색 서버 가동 중${NC}"
echo -e "${GREEN}========================================${NC}"
cat <<EOF

⚠ 현재 책 DB는 비어 있습니다.
   처음부터 완비된 DB를 받을 수는 없고, 보유 서적을 1권씩 직접 추가해야 합니다.
   책이 늘수록 검색 정확도·인용 출처가 풍부해집니다.

────────────────────────────────────────────────────────────
첫 책 추가 흐름 (한 권 기준 1~2시간 — 대부분 자동)
────────────────────────────────────────────────────────────

  Step 1. 책 스캔 (보유 도서 1권)
    · 사무소·공용 스캐너 또는 ScanSnap 등 사용
    · 권장: 300dpi, 컬러, A4 양면
    · 산출: PDF 1개 파일

  Step 2. 본 스크립트로 추가 (OCR + 청크 + 임베딩 자동)
    ~/legal-books/scripts/add_book.sh \\
      --pdf /경로/scan.pdf \\
      --author "곽윤직" --title "민법총칙" \\
      --edition "제9판" --year 2018 --publisher "박영사"

    소요 시간: 책 두께에 따라 5~30분 (OCR + Gemini 임베딩)
    내부 처리: tesseract OCR(한+영) → 텍스트 추출 → 청크 분할 →
              Gemini 임베딩 → SQLite FTS5 인덱스

  Step 3. 검색 테스트
    curl -X POST http://localhost:8766/search \\
      -H 'Content-Type: application/json' \\
      -d '{"query":"소멸시효","top_k":3}'

  Step 4. 클로드코드에서 자연어 사용
    "민법 시효 쟁점에 대해 교과서 바탕으로 정리해줘"
    → 자동으로 legal-books 검색 → 저자·서명·페이지 인용 포함 답변

────────────────────────────────────────────────────────────
점진적 확장 권장 흐름
────────────────────────────────────────────────────────────
  · 1주차: 가장 자주 보는 책 3권 추가 (예: 민법총칙·민사소송법·전공 분야 1권)
  · 1개월: 보유 책 30%~50%
  · 6개월: 사무소 서가 핵심본 거의 전부

  → 처음부터 완비하려 하지 말고, 사건 작업하면서 필요한 책부터 우선 추가.

자세한 가이드 (스캔 팁·법적 주의·고급 옵션):
   ~/jurisupport-plugins/guides/02_book_scanning.md

⚠ 저작권: 본인 보유본의 사무소 내부 이용만. 외부 공유·재배포 금지.
EOF
