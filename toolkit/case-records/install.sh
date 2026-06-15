#!/usr/bin/env bash
# case-records toolkit installer (Mac/Linux)
#
# Same structure as legal-books but for case files. Port 8767.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TOOLKIT_DIR/../../lib/dry-run.sh" "$@"

info()  { echo -e "${GREEN}[info]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*"; }
error() { echo -e "${RED}[error]${NC} $*"; exit 1; }

OS="$(uname -s)"
case "$OS" in
  Darwin*)              PLATFORM="mac" ;;
  Linux*)               PLATFORM="linux" ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
  *) error "지원하지 않는 OS: $OS (macOS/Linux/Windows Git Bash만 지원)" ;;
esac
info_or_plan "플랫폼: $PLATFORM"

source "$TOOLKIT_DIR/../../lib/python-detect.sh"
select_python 3.10 || error "Python 3.10 이상 필요. PowerShell: winget install Python.Python.3.12"
info "Python $PY_VERSION: $PY_DISPLAY"
if [[ "$PLATFORM" == "windows" && "$PY_VERSION" == 3.11.* ]]; then
  warn "Python 3.12 권장"
fi
if [[ "$PLATFORM" == "windows" ]]; then
  VENV_ACTIVATE="Scripts/activate"
else
  VENV_ACTIVATE="bin/activate"
fi

# Prerequisites
run_python --version >/dev/null 2>&1 || error "Python 3.10 이상 필요"
command -v curl >/dev/null || error "curl 필요"

ROOT="$HOME/case-records"
info_or_plan "디렉토리 생성: $ROOT"
run_or_plan mkdir -p "$ROOT/cases" "$ROOT/db" "$ROOT/server" "$ROOT/scripts" "$ROOT/logs"

# 기존 서버 중지 + 잠긴 venv 정리 (재실행 시 Permission denied 방지)
if [[ -d "$ROOT/.venv" ]]; then
  info_or_plan "기존 venv 발견 — 서버 중지 후 정리 시도"
  if is_dry_run; then
    info_or_plan "서버 중지 + venv 삭제"
  else
    if [[ "$PLATFORM" == "windows" ]] && [[ -f "$ROOT/scripts/server.ps1" ]]; then
      powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$ROOT/scripts/server.ps1")" stop 2>/dev/null || true
    elif [[ -f "$ROOT/scripts/server.sh" ]]; then
      bash "$ROOT/scripts/server.sh" stop 2>/dev/null || true
    fi
    sleep 1
    if ! rm -rf "$ROOT/.venv" 2>/dev/null; then
      warn "기존 venv 삭제 실패. Python 프로세스가 잡고 있을 수 있음."
      if [[ "$PLATFORM" == "windows" ]]; then
        warn "PowerShell에서 다음 실행 후 재시도:"
        warn "  Get-Process python,pythonw -ErrorAction SilentlyContinue | Stop-Process -Force"
        warn "  Remove-Item -Recurse -Force '$ROOT/.venv'"
      else
        warn "수동 실행: pkill -f 'case-records/.venv'; rm -rf '$ROOT/.venv'"
      fi
      error "venv 정리 필요."
    fi
    info "✓ 기존 venv 정리 완료"
  fi
fi

info_or_plan "Python 가상환경 생성"
if is_dry_run; then
  if [[ "$PLATFORM" == "linux" ]] && ! run_python -c "import ensurepip" 2>/dev/null; then
    info_or_plan "python3-venv 자동 설치"
  fi
  info_or_plan "venv 생성: $ROOT/.venv"
  info_or_plan "pip install: fastapi uvicorn pydantic sqlite-utils google-genai pypdf numpy python-dotenv python-docx"
else
  # Ubuntu/Debian은 python3-venv 별도 설치 필요
  if [[ "$PLATFORM" == "linux" ]] && ! run_python -c "import ensurepip" 2>/dev/null; then
    info "python3-venv 자동 설치 중..."
    PYV=$(run_python -c 'import sys; print(f"python3.{sys.version_info.minor}-venv")')
    sudo apt-get install -y "$PYV" python3-venv 2>&1 | tail -3 || \
      sudo apt-get install -y python3-venv 2>&1 | tail -3
    run_python -c "import ensurepip" 2>/dev/null || error "python3-venv 설치 실패. 수동: sudo apt install python3-venv"
  fi
  run_python -m venv "$ROOT/.venv"
  # shellcheck disable=SC1091
  source "$ROOT/.venv/$VENV_ACTIVATE"
  info "venv Python 버전: $(python --version 2>&1)"
  python -m pip install --progress-bar on --upgrade pip
  # --only-binary :all: → wheel만 사용 (Windows에 C 컴파일러 없어도 안전)
  # numpy 버전 pin 풀기: Python 3.13+에서도 wheel 있는 최신 사용
  pip install --progress-bar on --only-binary :all: \
    "fastapi>=0.115,<1" "uvicorn>=0.31,<1" "pydantic>=2.12.5,<3" \
    "sqlite-utils>=3.37" "google-genai>=0.3" "pypdf>=5,<6" \
    "numpy>=1.26,<3" "python-dotenv>=1" "python-docx>=1.1"
fi

info_or_plan "SQLite DB 초기화"
if is_dry_run; then
  info_or_plan "SQLite DB 생성: $ROOT/db/cases_fts.db (cases, documents, chunks, chunks_fts 테이블)"
else
  run_python - <<'PY'
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
print("DB 초기화 완료")
PY
fi

# Reuse Gemini key from legal-books if exists. case-records defaults to local FTS;
# Gemini is only needed when the user opts into external embeddings.
SECRETS="$HOME/.jurisupport/secrets.env"
if [[ ! -f "$SECRETS" ]] || ! grep -q "GEMINI_API_KEY" "$SECRETS"; then
  warn "Gemini API 키 미등록 — 기본 case-records는 로컬 FTS만 사용하므로 계속 진행합니다."
  warn "의미 기반 검색을 명시적으로 허용하려면 나중에 $SECRETS 에 GEMINI_API_KEY=xxx 를 추가하세요."
else
  info_or_plan "기존 Gemini API 키 발견: $SECRETS (명시 옵션 사용 시에만 case-records 임베딩에 사용)"
fi

TOKEN_FILE="$HOME/.jurisupport/case-records.token"
info_or_plan "case-records 로컬 API 토큰 준비: $TOKEN_FILE"
run_or_plan mkdir -p "$HOME/.jurisupport"
run_or_plan chmod 700 "$HOME/.jurisupport"
if is_dry_run; then
  info_or_plan "토큰이 없으면 256-bit 랜덤 토큰 생성 후 chmod 600"
else
  if [[ ! -f "$TOKEN_FILE" ]]; then
    umask 077
    run_python - <<'PY' > "$TOKEN_FILE"
import secrets
print(secrets.token_urlsafe(32))
PY
    info "case-records 로컬 API 토큰 생성 완료"
  else
    info "기존 case-records 로컬 API 토큰 재사용"
  fi
  chmod 600 "$TOKEN_FILE"
fi

info_or_plan "서버·스크립트 복사 중"
run_or_plan cp "$TOOLKIT_DIR/server/server.py" "$ROOT/server/server.py"
run_shell_or_plan "cp '$TOOLKIT_DIR/scripts/'*.sh '$TOOLKIT_DIR/scripts/'*.py '$ROOT/scripts/'"
# Windows에선 ps1도 복사 (있다면)
if [[ "$PLATFORM" == "windows" ]] && ls "$TOOLKIT_DIR/scripts/"*.ps1 >/dev/null 2>&1; then
  run_shell_or_plan "cp '$TOOLKIT_DIR/scripts/'*.ps1 '$ROOT/scripts/'"
fi
run_shell_or_plan "chmod +x '$ROOT/scripts/'*.sh '$ROOT/scripts/'*.py 2>/dev/null || true"

# Install skill
info_or_plan "클로드코드 스킬 설치 중"
SKILL_DST="$HOME/.claude/skills/case-records"
run_or_plan mkdir -p "$SKILL_DST"
run_or_plan cp "$TOOLKIT_DIR/../../skills/case-records/SKILL.md" "$SKILL_DST/SKILL.md"

# Start server (Windows는 PowerShell, 그 외는 bash)
info_or_plan "검색 서버 시작 (포트 8767)"
if is_dry_run; then
  info_or_plan "서버 시작 + health check: curl http://localhost:8767/health"
else
  if [[ "$PLATFORM" == "windows" ]]; then
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$ROOT/scripts/server.ps1")" start
  else
    "$ROOT/scripts/server.sh" start
  fi
  sleep 2
  if curl -sf http://localhost:8767/health >/dev/null; then
    info "서버 실행 중 (포트 8767)"
  else
    warn "서버 시작 실패. 로그 확인: $ROOT/logs/server.log"
  fi
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}case-records toolkit 설치 완료 — 검색 서버 가동 중${NC}"
echo -e "${GREEN}========================================${NC}"
cat <<'EOF'

⚠ 현재 사건 DB는 비어 있습니다.
   본 패키지가 변호사의 과거 사건을 갖고 있을 수 없으므로, 사무소 보유
   사건폴더를 직접 인덱싱해야 합니다. 사건이 늘수록 "전에 우리 어떻게
   주장했나" 검색의 정확도가 올라갑니다.

────────────────────────────────────────────────────────────
첫 사건 인덱싱 (1건 기준 1~3분)
────────────────────────────────────────────────────────────

  종결된 사건 1건 선택 후:
    ~/case-records/scripts/ingest_case.sh \
      --case-dir ~/사건/2018가단11111_홍○○_대여금 \
      --case-id 2018가단11111 \
      --case-name "홍○○ 대여금" \
      --status 종결 --result 전부승소

  내부 처리: 사건폴더 안 PDF·DOCX·MD·TXT 텍스트 추출 → 청크 분할 →
            SQLite FTS5 인덱스

  ⚠ 기본값은 사건 본문을 외부 임베딩 API로 보내지 않습니다.
    의미 기반 검색을 위해 Gemini 임베딩을 쓰려면 명시적으로:

    ~/case-records/scripts/ingest_case.sh \
      --case-dir ~/사건/2018가단11111_홍○○_대여금 \
      --case-id 2018가단11111 \
      --case-name "홍○○ 대여금" \
      --allow-external-embedding

────────────────────────────────────────────────────────────
대량 인덱싱 (사무소 누적 사건 한 번에)
────────────────────────────────────────────────────────────

  사건폴더 명명 규약이 '{사건번호}_{이름}_{개요}' 형식이면 일괄 처리 가능:

    ~/case-records/scripts/ingest_all.sh --root ~/사건

  소요 시간: 사건당 1~3분 × 사건 수
    예) 100건 = 약 2~5시간 (백그라운드 진행 가능, 노트북 켜둔 채 외출)
    예) 500건 = 하루 정도

  · 이미 인덱싱된 사건은 자동 건너뜀 (재실행 안전)
  · 중간에 끊겨도 다시 실행하면 이어서

────────────────────────────────────────────────────────────
권장 점진적 추가 흐름
────────────────────────────────────────────────────────────
  1주차: 최근 종결 사건 5~10건 + 진행 중 주요 사건 3건
  1개월: 최근 1~2년 사건 전부
  3개월: 보유 사건 절반 이상
  6개월: 사무소 누적 사건 거의 전부

  → 다음 사건 작업 시 자연스럽게 검색됨. 우선순위는 "유사 쟁점 잦은
    분야 위주"로 시작.

검색 테스트:
   ~/case-records/scripts/search_case_records.py "보증금" --top-k 3

   직접 HTTP 호출이 필요한 경우:
   TOKEN=$(cat ~/.jurisupport/case-records.token)
   curl -X POST http://localhost:8767/search \
     -H "Authorization: Bearer $TOKEN" \
     -H 'Content-Type: application/json' \
     -d '{"query":"보증금","top_k":3}'

클로드코드에서 자연어:
   "보증금 반환 동시이행 사건 우리가 전에 어떻게 주장했어?"

자세한 가이드 (폴더 명명·메타 입력·재인덱싱):
   ~/jurisupport-plugins/guides/03_case_records.md

⚠ 의뢰인 정보: 기본 DB는 로컬 SQLite FTS만 사용합니다. `--allow-external-embedding`
   또는 `CASE_RECORDS_ALLOW_EXTERNAL_EMBEDDING=1`을 사용하면 사건 본문 또는
   검색 쿼리가 Gemini API로 전송될 수 있으므로 사무소 정책을 먼저 확인하세요.
EOF
