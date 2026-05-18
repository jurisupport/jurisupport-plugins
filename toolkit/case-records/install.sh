#!/usr/bin/env bash
# case-records toolkit installer (Mac/Linux)
#
# Same structure as legal-books but for case files. Port 8767.

set -euo pipefail

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
GREEN: toolkit/case-records/install.sh --plan / --dry-run (no changes will be made)
- Would check OS/platform, python3, and curl.
- Would create $HOME/case-records layout, Python venv, and install FastAPI/uvicorn/Gemini/pdf/docx dependencies.
- Would initialize SQLite FTS DB and optionally write/reuse Gemini API key under $HOME/.jurisupport/secrets.env.
- Would copy server/scripts and Claude Code case-records skill.
- Would start search server on port 8767 and health-check with curl.
- Guard: in --plan/--dry-run mode this script exits before mkdir/venv/pip/python DB/secrets/cp/chmod/server/curl operations.
EOF
}

if is_dry_run; then
  print_plan
fi

OS="$(uname -s)"
case "$OS" in
  Darwin*) PLATFORM="mac" ;;
  Linux*)  PLATFORM="linux" ;;
  *) error "지원하지 않는 OS: $OS (macOS/Linux만 지원)" ;;
esac
info "플랫폼: $PLATFORM"

# Prerequisites
if is_dry_run; then plan "command -v python3"; else command -v python3 >/dev/null || error "Python 3.10 이상 필요"; fi
if is_dry_run; then plan "command -v curl"; else command -v curl >/dev/null || error "curl 필요"; fi

ROOT="$HOME/case-records"
info "디렉토리 생성: $ROOT"
run_or_plan mkdir -p "$ROOT/cases" "$ROOT/db" "$ROOT/server" "$ROOT/scripts" "$ROOT/logs"

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
run_or_plan pip install --quiet --upgrade pip
run_or_plan pip install --quiet \
  fastapi==0.115.0 uvicorn==0.31.0 pydantic==2.9.2 \
  sqlite-utils==3.37 google-genai==0.3.0 pypdf==5.0.1 \
  numpy==1.26.4 python-dotenv==1.0.1 python-docx==1.1.2

info "SQLite DB 초기화"
if is_dry_run; then
  plan "python3 initialize SQLite FTS DB"
else
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
print("DB 초기화 완료")
PY
fi

# Reuse Gemini key from legal-books if exists
SECRETS="$HOME/.jurisupport/secrets.env"
if [[ ! -f "$SECRETS" ]] || ! grep -q "GEMINI_API_KEY" "$SECRETS"; then
  run_or_plan mkdir -p "$(dirname "$SECRETS")"; run_or_plan chmod 700 "$(dirname "$SECRETS")"
  echo ""
  echo "Gemini API 키 미등록 (임베딩에 사용)."
  echo "무료 키 발급: https://aistudio.google.com/apikey"
  if is_dry_run; then plan "read Gemini API key prompt; default skip"; GEMINI_KEY=""; else read -r -p "Gemini API 키 입력 (건너뛰려면 Enter): " GEMINI_KEY; fi
  if [[ -n "${GEMINI_KEY:-}" ]]; then
    if is_dry_run; then plan "append GEMINI_API_KEY to $SECRETS"; else echo "GEMINI_API_KEY=${GEMINI_KEY}" >> "$SECRETS"; fi
    run_or_plan chmod 600 "$SECRETS"
  fi
else
  if is_dry_run; then info "기존 Gemini API 키 확인 예정: $SECRETS (dry-run: 실제 변경 없음)"; else info "기존 Gemini API 키 재사용: $SECRETS"; fi
fi

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
run_or_plan cp "$TOOLKIT_DIR/server/server.py" "$ROOT/server/server.py"
run_or_plan cp "$TOOLKIT_DIR/scripts/"*.{sh,py} "$ROOT/scripts/"
run_or_plan chmod +x "$ROOT/scripts/"*.sh

# Install skill
SKILL_DST="$HOME/.claude/skills/case-records"
run_or_plan mkdir -p "$SKILL_DST"
run_or_plan cp "$TOOLKIT_DIR/../../skills/case-records/SKILL.md" "$SKILL_DST/SKILL.md"

# Start server
run_or_plan "$ROOT/scripts/server.sh" start
if is_dry_run; then plan "sleep 2"; else sleep 2; fi
if is_dry_run; then
  plan "curl -sf http://localhost:8767/health"
elif curl -sf http://localhost:8767/health >/dev/null; then
  if is_dry_run; then info "서버 실행 확인 예정 (포트 8767, dry-run: 실제 변경 없음)"; else info "서버 실행 중 (포트 8767)"; fi
else
  warn "서버 시작 실패. 로그 확인: $ROOT/logs/server.log"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
if is_dry_run; then echo -e "${GREEN}case-records toolkit PLAN 완료 (dry-run: 실제 변경 없음)${NC}"; else echo -e "${GREEN}case-records toolkit 설치 완료${NC}"; fi
echo -e "${GREEN}========================================${NC}"
cat <<EOF

다음 단계:
  1. 첫 사건 인덱싱:
       ~/case-records/scripts/ingest_case.sh \\
         --case-dir ~/사건/2018가단11111_홍○○_대여금 \\
         --case-id 2018가단11111 \\
         --case-name "홍○○ 대여금" \\
         --status 종결 --result 전부승소

  2. 또는 ~/사건/ 아래 모든 사건 일괄 인덱싱:
       ~/case-records/scripts/ingest_all.sh --root ~/사건

  3. 검색 테스트:
       curl -X POST http://localhost:8767/search \\
         -H 'Content-Type: application/json' \\
         -d '{"query":"보증금","top_k":3}'

가이드: ~/jurisupport-plugins/guides/03_case_records.md
EOF
