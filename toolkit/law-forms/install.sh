#!/usr/bin/env bash
# law-forms toolkit installer
#
# 법령 별지서식·법원 전산양식을 hwpx로 바꿔 채우는 도구를 설치한다.
# - ~/law-forms/scripts/law_forms.py      검색·변환·채우기 스크립트
# - ~/law-forms/shared-library/           자주 쓰는 서식 서재(플러그인 배포본)
# - ~/law-forms/library/                  개인 서재(사용자 노하우, 먼저 찾음)
# - ~/law-forms/node/                     kordoc + puppeteer-core (PDF 렌더용)

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$TOOLKIT_DIR/../../lib/dry-run.sh" "$@"
source "$TOOLKIT_DIR/../../lib/install-host.sh"
jurisupport_select_host "$@"

info()  { echo -e "${GREEN}[info]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*"; }
error() { echo -e "${RED}[error]${NC} $*"; exit 1; }

KORDOC_VERSION="4.24.37"

source "$TOOLKIT_DIR/../../lib/python-detect.sh"
select_python 3.9 || error "Python 미설치. Python 3.9 이상 필요"
info "Python $PY_VERSION: $PY_DISPLAY"
command -v node >/dev/null 2>&1 || warn "Node.js 미설치 — kordoc 실행에 Node.js 18 이상이 필요합니다."

ROOT="${LAW_FORMS_HOME:-$HOME/law-forms}"
ROOT="${ROOT/#\~\//$HOME/}"
ROOT="$(jurisupport_path "$ROOT")"
info_or_plan "설치 위치: $ROOT"
run_or_plan mkdir -p "$ROOT/scripts" "$ROOT/cache" "$ROOT/library" "$ROOT/node"

info_or_plan "스크립트 복사"
run_or_plan cp "$TOOLKIT_DIR/scripts/law_forms.py" "$ROOT/scripts/law_forms.py"
run_shell_or_plan "chmod +x '$ROOT/scripts/law_forms.py' 2>/dev/null || true"

info_or_plan "공용 서재 복사 (개인 서재 ~/law-forms/library 는 건드리지 않음)"
run_or_plan rm -rf "$ROOT/shared-library"
run_or_plan cp -R "$TOOLKIT_DIR/../../data/law-forms/library" "$ROOT/shared-library"

if command -v npm >/dev/null 2>&1; then
  info_or_plan "kordoc@$KORDOC_VERSION + puppeteer-core 설치 (PDF 렌더용)"
  run_shell_or_plan "cd '$ROOT/node' && { [ -f package.json ] || npm init -y >/dev/null; } && npm install --silent kordoc@$KORDOC_VERSION puppeteer-core >/dev/null" \
    || warn "kordoc 설치 실패 — 스크립트는 npx -y kordoc@$KORDOC_VERSION 로 대신 실행합니다(PDF 렌더 불가)."
else
  warn "npm 미설치 — kordoc을 설치하지 못했습니다. Node.js 18 이상을 설치한 뒤 이 스크립트를 다시 실행하세요."
fi

info_or_plan "PyMuPDF 설치 (PDF 안내 쪽 빼기·쪽수 대조용, 선택)"
if is_dry_run; then
  info_or_plan "python -m pip install --user pymupdf"
else
  run_python -m pip install --user --quiet pymupdf >/dev/null 2>&1 || warn "PyMuPDF 설치 실패 — 안내 쪽을 PDF에서 빼는 기능만 쓸 수 없습니다."
fi

info_or_plan "클로드코드/Codex 스킬 설치 중"
SKILL_SRC="$TOOLKIT_DIR/../../skills/law-forms/SKILL.md"
jurisupport_copy_skill "$(dirname "$SKILL_SRC")" law-forms
if jurisupport_has_host claude; then
  run_or_plan mkdir -p "$(jurisupport_path "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands")"
  run_or_plan cp "$SKILL_SRC" "$(jurisupport_path "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands/law-forms.md")"
fi

if is_dry_run; then
  info_or_plan "법제처 OC 미설정이면 보호 입력창에서 등록"
elif [[ -z "${LAW_OC:-}" ]] && ! run_python "$TOOLKIT_DIR/../../scripts/configure_credentials.py" --service law-forms --check >/dev/null 2>&1; then
  info "법제처 OC 입력창을 엽니다. 공용 서재만 쓰려면 입력창을 취소해도 됩니다."
  run_python "$TOOLKIT_DIR/../../scripts/configure_credentials.py" --service law-forms || \
    warn "OC 등록 미완료. 입력창 도구의 law-forms 항목에서 나중에 등록하세요."
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}law-forms toolkit 설치 완료${NC}"
echo -e "${GREEN}========================================${NC}"
cat <<EOF

서재 목록:
  $ROOT/scripts/law_forms.py library list

서재 서식 채우기:
  $ROOT/scripts/law_forms.py library show 주민초본-7호
  $ROOT/scripts/law_forms.py fill 주민초본-7호 --data 값.json --out both -o 출력폴더

서재에 없는 법령 서식 (법제처 OC 필요):
  $ROOT/scripts/law_forms.py search 동석신청서
  $ROOT/scripts/law_forms.py get "경찰수사규칙:002600"

출처:
  법령 별지서식 — 국가법령정보센터(법제처). 법령·고시는 저작권법 제7조의 보호받지 못하는 저작물입니다.
  법원 전산양식 — 대한민국 법원 전자소송포털 양식모음. 산출물에 출처를 남기세요.

EOF
