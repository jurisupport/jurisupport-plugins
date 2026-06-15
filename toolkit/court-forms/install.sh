#!/usr/bin/env bash
# court-forms toolkit installer
#
# Sets up a local SQLite database and helper script for public court forms.

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
select_python 3.9 || error "Python 미설치. Python 3.9 이상 필요"
info "Python $PY_VERSION: $PY_DISPLAY"

run_python --version >/dev/null 2>&1 || error "Python 실행 실패: $PY_DISPLAY"
command -v curl >/dev/null 2>&1 || warn "curl 미설치 — 설치에는 불필요하지만 수동 점검에 유용합니다."

ROOT="$HOME/court-forms"
info_or_plan "설치 위치: $ROOT"
run_or_plan mkdir -p "$ROOT/db" "$ROOT/files" "$ROOT/scripts" "$ROOT/logs"

info_or_plan "스크립트 복사"
run_or_plan cp "$TOOLKIT_DIR/scripts/court_forms.py" "$ROOT/scripts/court_forms.py"
run_shell_or_plan "chmod +x '$ROOT/scripts/court_forms.py' 2>/dev/null || true"

info_or_plan "SQLite DB 초기화"
if is_dry_run; then
  info_or_plan "DB 생성: $ROOT/db/forms.db"
else
  run_python "$ROOT/scripts/court_forms.py" init --db "$ROOT/db/forms.db" >/dev/null
fi

info_or_plan "클로드코드/Codex 스킬 설치 중"
SKILL_SRC="$TOOLKIT_DIR/../../skills/court-forms/SKILL.md"
for SKILLS_ROOT in "$HOME/.claude/skills" "$HOME/.codex/skills"; do
  SKILL_DST="$SKILLS_ROOT/court-forms"
  run_or_plan mkdir -p "$SKILL_DST"
  run_or_plan cp "$SKILL_SRC" "$SKILL_DST/SKILL.md"
done
run_or_plan mkdir -p "$HOME/.claude/commands"
run_or_plan cp "$SKILL_SRC" "$HOME/.claude/commands/court-forms.md"

if is_dry_run; then
  info_or_plan "공개 양식 메타데이터 동기화: $ROOT/scripts/court_forms.py sync"
else
  echo ""
  echo "  법원 전자소송포털 공개 양식 메타데이터를 동기화합니다."
  echo "  - 기본 동기화는 목록/다운로드 URL만 저장합니다."
  echo "  - 원본 HWP/PDF 파일은 필요할 때 download 명령으로 받습니다."
  echo "  - 출처: 대한민국 법원 전자소송포털 양식모음"
  echo ""
  read -r -p "지금 메타데이터 동기화할까요? [Y/n, 엔터=예] " ans
  if [[ ! "$ans" =~ ^[Nn]$ ]]; then
    if run_python "$ROOT/scripts/court_forms.py" sync --db "$ROOT/db/forms.db" --files-dir "$ROOT/files"; then
      info "court-forms 메타데이터 동기화 완료"
    else
      warn "동기화 실패. 나중에 다시 실행:"
      warn "  $ROOT/scripts/court_forms.py sync"
    fi
  else
    info "건너뛰기. 나중에 실행: $ROOT/scripts/court_forms.py sync"
  fi
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}court-forms toolkit 설치 완료${NC}"
echo -e "${GREEN}========================================${NC}"
cat <<EOF

상태 확인:
  $ROOT/scripts/court_forms.py info

검색:
  $ROOT/scripts/court_forms.py search "주소보정" --top-k 5

원본 양식 다운로드:
  $ROOT/scripts/court_forms.py download --query "주소보정" --kind hwp --out-dir .

레포에 Markdown+원본 파일로 내보내기:
  cd ~/jurisupport-plugins
  $ROOT/scripts/court_forms.py sync --download all --continue-on-error
  $ROOT/scripts/court_forms.py export-md --output data/court-forms --copy-files --download-missing --continue-on-error

저작권/출처:
  전자소송포털 저작권보호정책상 자유이용 가능 자료도 출처 표시가 필요합니다.
  산출물에는 "출처: 대한민국 법원 전자소송포털 양식모음"을 남기세요.

EOF
