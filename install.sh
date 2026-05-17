#!/usr/bin/env bash
# jurisupport-plugins one-shot installer (Mac/Linux)
#
# Installs:
#   1. Data protection hook
#   2. songmu-legal plugin (from git submodule or repo)
#   3. lbox-guide, beopgoeul-guide skills
#   4. Case info CSV template
#   5. (Optional) legal-books server + skill
#   6. (Optional) case-records server + skill

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${GREEN}[info]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*"; }
error() { echo -e "${RED}[error]${NC} $*"; exit 1; }
step()  { echo -e "\n${BLUE}=== $* ===${NC}"; }

# ============================================================
# 0. Banner + safety check
# ============================================================
cat <<'BANNER'

╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║   jurisupport-plugins installer                                ║
║   변호사용 클로드코드 통합 패키지 설치                          ║
║                                                                ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║   ⚠️ 설치 전 반드시 읽어야 할 문서 / Required reading:         ║
║      guides/00_security.md (의뢰인 정보 보호 원칙)             ║
║                                                                ║
║   계속: Enter / Continue: Enter                                ║
║   취소: Ctrl+C  / Cancel: Ctrl+C                               ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

BANNER
read -r -p "" _

OS="$(uname -s)"
case "$OS" in
  Darwin*) PLATFORM="mac" ;;
  Linux*)  PLATFORM="linux" ;;
  *) error "지원하지 않는 OS: $OS. macOS/Linux만 지원합니다. (Windows는 WSL2 사용)" ;;
esac

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info "패키지 경로: $TOOLKIT_DIR"
info "플랫폼: $PLATFORM"

# ============================================================
# 1. Prerequisites
# ============================================================
step "1. 필수 도구 확인"

command -v claude >/dev/null || error "클로드코드(CLI) 미설치. 설치: https://docs.claude.com/claude-code"
command -v git >/dev/null || error "git 필요. (먼저 git 설치 후 재실행)"

# jq is required for hook registration — try auto-install
if ! command -v jq >/dev/null 2>&1; then
  warn "jq 미설치 (데이터 보호 Hook에 필요)"
  if [[ "$PLATFORM" == "mac" ]]; then
    if command -v brew >/dev/null 2>&1; then
      info "Homebrew로 jq 자동 설치 중..."
      brew install jq >/dev/null 2>&1 && info "✓ jq 설치 완료" || error "jq 설치 실패. 수동 실행: brew install jq"
    else
      error "Homebrew 미설치. https://brew.sh 에서 먼저 설치 후 재실행."
    fi
  else
    if command -v apt-get >/dev/null 2>&1; then
      info "apt로 jq 자동 설치 중..."
      sudo apt-get install -y jq >/dev/null 2>&1 && info "✓ jq 설치 완료" || error "jq 설치 실패. 수동 실행: sudo apt install jq"
    else
      error "사용 중인 배포판에 jq 설치 후 재실행."
    fi
  fi
fi

# ============================================================
# 2. Data protection hook (always installed)
# ============================================================
step "2. 데이터 보호 Hook 설치"

HOOK_SRC="$TOOLKIT_DIR/hooks/pretool_data_protection.sh"
chmod +x "$HOOK_SRC"

SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$(dirname "$SETTINGS")"
[[ -f "$SETTINGS" ]] || echo '{}' > "$SETTINGS"

# Add hook entry if not present
if ! grep -q "pretool_data_protection.sh" "$SETTINGS"; then
  TMP=$(mktemp)
  jq --arg cmd "$HOOK_SRC" '
    .hooks.PreToolUse = (.hooks.PreToolUse // []) + [{
      "matcher": "WebFetch|WebSearch|mcp__google-workspace__gmail_send.*|mcp__google-workspace__chat_.*|mcp__claude_ai_Gmail__.*|mcp__plugin_telegram_telegram__reply",
      "hooks": [{"type": "command", "command": $cmd}]
    }]
  ' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
  info "Hook 등록 완료: $SETTINGS"
else
  info "Hook 이미 등록됨"
fi

# ============================================================
# 3. songmu-legal plugin (same repo — register only)
# ============================================================
step "3. songmu-legal 플러그인 등록"

SONGMU_LOCAL="$TOOLKIT_DIR/plugins/songmu-legal"
SONGMU_DST="$HOME/.claude/plugins/cache/jurisupport-plugins/songmu-legal"

if [[ ! -f "$SONGMU_LOCAL/.claude-plugin/plugin.json" ]]; then
  warn "songmu-legal 플러그인 없음: $SONGMU_LOCAL"
  echo "  전체 리포를 받으셨나요? 다음 실행:"
  echo "    git clone https://github.com/jurisupport/jurisupport-plugins.git"
else
  mkdir -p "$(dirname "$SONGMU_DST")"
  if [[ -L "$SONGMU_DST" || -e "$SONGMU_DST" ]]; then
    info "songmu-legal 이미 등록됨"
  else
    ln -s "$SONGMU_LOCAL" "$SONGMU_DST"
    info "songmu-legal 등록 완료"
  fi

  # Bootstrap CLAUDE.md from CLAUDE.md.example if missing
  if [[ ! -f "$SONGMU_LOCAL/CLAUDE.md" ]] && [[ -f "$SONGMU_LOCAL/CLAUDE.md.example" ]]; then
    cp "$SONGMU_LOCAL/CLAUDE.md.example" "$SONGMU_LOCAL/CLAUDE.md"
    info "템플릿에서 CLAUDE.md 생성: $SONGMU_LOCAL/CLAUDE.md"
    info "→ 클로드코드에서 /songmu-legal:cold-start-interview 실행하여 채우세요"
  fi
fi

# ============================================================
# 4. Skills (lbox-guide always; beopgoeul-search if toolkit installed later)
# ============================================================
step "4. 가이드 스킬 설치"

SKILLS_DST="$HOME/.claude/skills"
mkdir -p "$SKILLS_DST"

# Always-on: lbox-guide (manual, no automation)
for SKILL in lbox-guide; do
  mkdir -p "$SKILLS_DST/$SKILL"
  cp "$TOOLKIT_DIR/skills/$SKILL/SKILL.md" "$SKILLS_DST/$SKILL/SKILL.md"
  info "스킬 설치 완료: $SKILL"
done
# beopgoeul-search is installed conditionally below (Step 8)

# ============================================================
# 5. CSV template
# ============================================================
step "5. 사건정보 관리표 템플릿 설정"

if [[ ! -d "$HOME/사건" ]]; then
  read -r -p "~/사건 디렉토리 생성하고 CSV 템플릿 복사? [Y/n] " ans
  if [[ "$ans" =~ ^[Nn]$ ]]; then
    info "건너뛰기. 나중에 실행: mkdir -p ~/사건 && cp $TOOLKIT_DIR/templates/사건정보_관리표.csv ~/사건/"
  else
    mkdir -p "$HOME/사건"
    cp "$TOOLKIT_DIR/templates/사건정보_관리표.csv" "$HOME/사건/_사건정보관리표.csv"
    cp "$TOOLKIT_DIR/templates/사건정보_입력가이드.md" "$HOME/사건/_입력가이드.md"
    info "템플릿을 ~/사건/ 에 복사 완료"
  fi
else
  info "~/사건 이미 존재. 템플릿은 $TOOLKIT_DIR/templates/ 에 있음"
fi

# ============================================================
# 6. Optional: legal-books toolkit
# ============================================================
step "6. (선택) legal-books 검색 서버 설치"

read -r -p "지금 설치할까요? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  bash "$TOOLKIT_DIR/toolkit/legal-books/install.sh" || warn "legal-books 설치 실패. 나중에 다시 시도하세요."
else
  info "건너뛰기. 나중에 설치: bash $TOOLKIT_DIR/toolkit/legal-books/install.sh"
fi

# ============================================================
# 7. Optional: case-records toolkit
# ============================================================
step "7. (선택) case-records 검색 서버 설치"

read -r -p "지금 설치할까요? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  bash "$TOOLKIT_DIR/toolkit/case-records/install.sh" || warn "case-records 설치 실패. 나중에 다시 시도하세요."
else
  info "건너뛰기. 나중에 설치: bash $TOOLKIT_DIR/toolkit/case-records/install.sh"
fi

# ============================================================
# 8. Optional: beopgoeul (법고을) auto-search toolkit
# ============================================================
step "8. (선택) 법고을 자동 검색 toolkit 설치 (Selenium)"

read -r -p "지금 설치할까요? (Chrome도 자동 설치됨) [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  # || warn — Chrome 미설치 등 실패해도 main install.sh는 종료되지 않음
  bash "$TOOLKIT_DIR/toolkit/beopgoeul/install.sh" || warn "법고을 toolkit 설치 실패. 수동 검색용 lbox-guide 스킬은 사용 가능."
else
  info "건너뛰기. beopgoeul-search 스킬은 비활성화됩니다."
  info "대신 lbox-guide 스킬(수동 검색)을 사용할 수 있습니다."
  info "나중에 설치: bash $TOOLKIT_DIR/toolkit/beopgoeul/install.sh"
fi

# ============================================================
# Done
# ============================================================
cat <<EOF

$(printf '\033[0;32m')========================================
✓ 설치 완료
========================================$(printf '\033[0m')

다음 단계:
  1. 필독: $TOOLKIT_DIR/guides/00_security.md (5분)
  2. 새 터미널에서 클로드코드 시작:
       claude
  3. 시작 명령:
       "안녕. 설치된 스킬과 플러그인 보여줘."
  4. 첫 사건 설정: /songmu-legal:cold-start-interview
  5. 첫 준비서면: /songmu-legal:brief-protocol

전체 가이드: $TOOLKIT_DIR/README.md

EOF
