#!/usr/bin/env bash
# clean-legal-db toolkit installer (Mac/Linux/Windows Git Bash)
#
# Sets up:
# - ~/clean-legal-db/  (search.py + COPYRIGHT.md + clean_legal.db)
# - clean_legal.db 다운로드(GitHub Release 자산) + sha256 검증
# - ~/.claude/skills/clean-legal-db/SKILL.md 설치
#
# DB 본체는 git에 없음 — GitHub Release 자산에서 받는다.

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$TOOLKIT_DIR/../.." && pwd)"
source "$REPO_ROOT/lib/dry-run.sh" "$@"

info()  { echo -e "${GREEN}[info]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*"; }
error() { echo -e "${RED}[error]${NC} $*"; exit 1; }

# ============================================================
# 설정
# ============================================================
DEST="$HOME/clean-legal-db"
DB_PATH="$DEST/clean_legal.db"
SKILL_DST="$HOME/.claude/skills/clean-legal-db"

# 다운로드 URL (환경변수로 교체 가능)
CLEAN_LEGAL_DB_URL="${CLEAN_LEGAL_DB_URL:-https://github.com/jurisupport/jurisupport-plugins/releases/download/clean-legal-db-v1/clean_legal.db}"
# DB 무결성 해시 — DB 갱신 시 README.md의 gh release 절차대로 함께 갱신할 것
EXPECTED_SHA256="597b81f84edbb1d2c9ac61aec02360e2ed5b78a9fdfe4f5a493bd767275b4577"

# ============================================================
# 필수 도구 확인
# ============================================================
command -v python3 >/dev/null 2>&1 || error "Python 3.8+ 필요."
command -v curl    >/dev/null 2>&1 || error "curl 필요."

# sha256 도구 선택 (mac: shasum / linux: sha256sum)
if command -v sha256sum >/dev/null 2>&1; then
  sha256_of() { sha256sum "$1" | awk '{print $1}'; }
elif command -v shasum >/dev/null 2>&1; then
  sha256_of() { shasum -a 256 "$1" | awk '{print $1}'; }
else
  sha256_of() { echo ""; }   # 검증 도구 없으면 빈 값 → 검증 건너뜀(경고)
fi

# ============================================================
# 디렉토리 + 코드 배치
# ============================================================
info_or_plan "설치 위치: $DEST"
run_or_plan mkdir -p "$DEST"
run_or_plan cp "$TOOLKIT_DIR/search.py"    "$DEST/search.py"
run_or_plan cp "$TOOLKIT_DIR/COPYRIGHT.md" "$DEST/COPYRIGHT.md"

# ============================================================
# DB 다운로드 (이미 있고 해시 일치하면 건너뜀)
# ============================================================
need_download=1
if [[ -f "$DB_PATH" ]]; then
  cur="$(sha256_of "$DB_PATH")"
  if [[ -n "$cur" && "$cur" == "$EXPECTED_SHA256" ]]; then
    info "DB 이미 설치됨(해시 일치) — 다운로드 건너뜀: $DB_PATH"
    need_download=0
  else
    warn "기존 DB 해시 불일치 또는 미검증 — 재다운로드합니다."
  fi
fi

if [[ "$need_download" == "1" ]]; then
  if is_dry_run; then
    info_or_plan "clean_legal.db 다운로드(약 235MB): $CLEAN_LEGAL_DB_URL → $DB_PATH"
  else
    info "clean_legal.db 다운로드 중(약 235MB, 이어받기 지원)…"
    # -C - : 중단 시 이어받기 / --fail : HTTP 에러 시 비정상 종료 / -L : 리다이렉트 추적
    curl -L --fail -C - -o "$DB_PATH" "$CLEAN_LEGAL_DB_URL" \
      || error "다운로드 실패: $CLEAN_LEGAL_DB_URL (Release 자산이 올라가 있는지 확인하세요)"

    cur="$(sha256_of "$DB_PATH")"
    if [[ -z "$cur" ]]; then
      warn "sha256 도구 없음 — 무결성 검증 건너뜀."
    elif [[ "$cur" != "$EXPECTED_SHA256" ]]; then
      error "해시 불일치! 받은 파일 손상 가능. 기대=$EXPECTED_SHA256 실제=$cur"
    else
      info "sha256 검증 통과."
    fi
  fi
fi

# ============================================================
# SKILL.md 설치
# ============================================================
run_or_plan mkdir -p "$SKILL_DST"
run_or_plan cp "$REPO_ROOT/skills/clean-legal-db/SKILL.md" "$SKILL_DST/SKILL.md"
info_or_plan "스킬 설치: clean-legal-db"

# ============================================================
# 동작 확인
# ============================================================
if ! is_dry_run; then
  info "검색 테스트…"
  python3 "$DEST/search.py" "손해배상" --top 1 >/dev/null \
    && info "정상 동작 확인 ✓" \
    || warn "검색 테스트 실패 — DB 또는 Python 환경을 확인하세요."
fi

info "완료. 사용: python3 ~/clean-legal-db/search.py \"검색어\""
