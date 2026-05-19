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

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
TOTAL_STEPS=9
info()  { echo -e "${GREEN}[info]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*"; }
error() { echo -e "${RED}[error]${NC} $*"; exit 1; }
step()  {
  local n="$1"; shift
  local bar=""
  local i
  for ((i=1; i<=TOTAL_STEPS; i++)); do
    if [[ $i -le $n ]]; then bar+="■"; else bar+="□"; fi
  done
  echo ""
  echo -e "${CYAN}┌──────────────────────────────────────────────────────────┐${NC}"
  echo -e "${CYAN}│${NC} ${BLUE}[$n/$TOTAL_STEPS]${NC} $*"
  echo -e "${CYAN}│${NC} 진행: ${GREEN}$bar${NC}"
  echo -e "${CYAN}└──────────────────────────────────────────────────────────┘${NC}"
}

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
║   ⚠️ 설치 전 반드시 읽어야 할 문서:                            ║
║      guides/00_security.md (의뢰인 정보 보호 원칙)             ║
║                                                                ║
║   💡 각 [Y/n] 프롬프트는 엔터만 치면 '예'로 진행됩니다.        ║
║      거부할 때만 'n' 입력.                                     ║
║                                                                ║
║   계속: Enter    취소: Ctrl+C                                  ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

BANNER
read -r -p "" _

OS="$(uname -s)"
case "$OS" in
  Darwin*)              PLATFORM="mac" ;;
  Linux*)               PLATFORM="linux" ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
  *) error "지원하지 않는 OS: $OS. macOS/Linux/Windows(Git Bash)만 지원합니다." ;;
esac

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info "패키지 경로: $TOOLKIT_DIR"
info "플랫폼: $PLATFORM"

# ============================================================
# 1. Prerequisites
# ============================================================
step 1 "필수 도구 확인"

command -v claude >/dev/null || error "클로드코드(CLI) 미설치. 설치: https://docs.claude.com/claude-code"
command -v git >/dev/null || error "git 필요. (먼저 git 설치 후 재실행)"

# jq is required for hook registration — try auto-install
if ! command -v jq >/dev/null 2>&1; then
  warn "jq 미설치 (데이터 보호 Hook에 필요)"
  case "$PLATFORM" in
    mac)
      if command -v brew >/dev/null 2>&1; then
        info "Homebrew로 jq 자동 설치 중..."
        brew install jq >/dev/null 2>&1 && info "✓ jq 설치 완료" || error "jq 설치 실패. 수동 실행: brew install jq"
      else
        error "Homebrew 미설치. https://brew.sh 에서 먼저 설치 후 재실행."
      fi
      ;;
    linux)
      if command -v apt-get >/dev/null 2>&1; then
        info "apt로 jq 자동 설치 중..."
        sudo apt-get install -y jq >/dev/null 2>&1 && info "✓ jq 설치 완료" || error "jq 설치 실패. 수동 실행: sudo apt install jq"
      else
        error "사용 중인 배포판에 jq 설치 후 재실행."
      fi
      ;;
    windows)
      error "jq 미설치. PowerShell에서 'winget install jqlang.jq' 실행 후 새 Git Bash에서 다시 시도하세요."
      ;;
  esac
fi

# ============================================================
# 2. Data protection hook (always installed)
# ============================================================
step 2 "데이터 보호 Hook 설치"

HOOK_SRC="$TOOLKIT_DIR/hooks/pretool_data_protection.sh"
chmod +x "$HOOK_SRC"

SETTINGS="$HOME/.claude/settings.json"
mkdir -p "$(dirname "$SETTINGS")"
[[ -f "$SETTINGS" ]] || echo '{}' > "$SETTINGS"

# Compose hook command (Windows needs Git Bash absolute path)
if [[ "$PLATFORM" == "windows" ]]; then
  # Windows 네이티브 Claude Code는 .sh 직접 실행 불가 → Git Bash로 호출
  BASH_WIN="$(cygpath -w "$(command -v bash)" 2>/dev/null || echo 'C:\Program Files\Git\bin\bash.exe')"
  HOOK_WIN="$(cygpath -w "$HOOK_SRC")"
  HOOK_CMD="\"$BASH_WIN\" \"$HOOK_WIN\""
else
  HOOK_CMD="$HOOK_SRC"
fi

# Add hook entry if not present
if ! grep -q "pretool_data_protection.sh" "$SETTINGS"; then
  TMP=$(mktemp)
  jq --arg cmd "$HOOK_CMD" '
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
step 3 "songmu-legal 플러그인 등록"

SONGMU_LOCAL="$TOOLKIT_DIR/plugins/songmu-legal"
MARKETPLACE_DIR="$TOOLKIT_DIR"   # marketplace.json이 있는 레포 루트

if [[ ! -f "$SONGMU_LOCAL/.claude-plugin/plugin.json" ]]; then
  warn "songmu-legal 플러그인 없음: $SONGMU_LOCAL"
  echo "  전체 리포를 받으셨나요? 다음 실행:"
  echo "    git clone https://github.com/jurisupport/jurisupport-plugins.git"
elif [[ ! -f "$MARKETPLACE_DIR/.claude-plugin/marketplace.json" ]]; then
  warn "marketplace.json 없음: $MARKETPLACE_DIR/.claude-plugin/marketplace.json"
else
  # Windows에선 경로를 Windows 형식으로 (Claude Code Windows 빌드는 \ 경로 선호)
  if [[ "$PLATFORM" == "windows" ]] && command -v cygpath >/dev/null 2>&1; then
    MARKETPLACE_PATH="$(cygpath -w "$MARKETPLACE_DIR")"
  else
    MARKETPLACE_PATH="$MARKETPLACE_DIR"
  fi

  # 1) marketplace 등록 (이미 있으면 건너뜀)
  if claude plugin marketplace list 2>/dev/null | grep -q "jurisupport-plugins"; then
    info "marketplace 'jurisupport-plugins' 이미 등록됨"
  else
    info "marketplace 자동 등록 중: $MARKETPLACE_PATH"
    if claude plugin marketplace add "$MARKETPLACE_PATH" 2>&1 | tail -3; then
      info "✓ marketplace 등록 완료"
    else
      warn "marketplace 등록 실패. 수동: claude plugin marketplace add $MARKETPLACE_PATH"
    fi
  fi

  # 2) songmu-legal 플러그인 설치 (이미 있으면 건너뜀)
  if claude plugin list 2>/dev/null | grep -q "songmu-legal"; then
    info "songmu-legal 플러그인 이미 설치됨"
  else
    info "songmu-legal 자동 설치 중..."
    if claude plugin install songmu-legal@jurisupport-plugins 2>&1 | tail -3; then
      info "✓ songmu-legal 설치 완료"
    else
      warn "자동 설치 실패. 수동: claude plugin install songmu-legal@jurisupport-plugins"
    fi
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
step 4 "가이드 스킬 설치"

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
step 5 "사건정보 관리표 템플릿 설정"

if [[ ! -d "$HOME/사건" ]]; then
  read -r -p "~/사건 디렉토리 생성하고 CSV 템플릿 복사? [Y/n, 엔터=예] " ans
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
step 6 "(선택) legal-books 검색 서버 설치"

read -r -p "지금 설치할까요? [Y/n, 엔터=예] " ans
if [[ ! "$ans" =~ ^[Nn]$ ]]; then
  bash "$TOOLKIT_DIR/toolkit/legal-books/install.sh" || warn "legal-books 설치 실패. 나중에 다시 시도하세요."
else
  info "건너뛰기. 나중에 설치: bash $TOOLKIT_DIR/toolkit/legal-books/install.sh"
fi

# ============================================================
# 7. Optional: case-records toolkit
# ============================================================
step 7 "(선택) case-records 검색 서버 설치"

read -r -p "지금 설치할까요? [Y/n, 엔터=예] " ans
if [[ ! "$ans" =~ ^[Nn]$ ]]; then
  bash "$TOOLKIT_DIR/toolkit/case-records/install.sh" || warn "case-records 설치 실패. 나중에 다시 시도하세요."
else
  info "건너뛰기. 나중에 설치: bash $TOOLKIT_DIR/toolkit/case-records/install.sh"
fi

# ============================================================
# 8. Optional: beopgoeul (법고을) auto-search toolkit
# ============================================================
step 8 "(선택) 법고을 자동 검색 toolkit 설치 (Selenium)"

read -r -p "지금 설치할까요? (Chrome도 자동 설치됨) [Y/n, 엔터=예] " ans
if [[ ! "$ans" =~ ^[Nn]$ ]]; then
  # || warn — Chrome 미설치 등 실패해도 main install.sh는 종료되지 않음
  bash "$TOOLKIT_DIR/toolkit/beopgoeul/install.sh" || warn "법고을 toolkit 설치 실패. 수동 검색용 lbox-guide 스킬은 사용 가능."
else
  info "건너뛰기. beopgoeul-search 스킬은 비활성화됩니다."
  info "대신 lbox-guide 스킬(수동 검색)을 사용할 수 있습니다."
  info "나중에 설치: bash $TOOLKIT_DIR/toolkit/beopgoeul/install.sh"
fi

# ============================================================
# 9. Optional: JuriSupport MCP 등록
# ============================================================
step 9 "(권장) JuriSupport 가입·MCP 연동 — 50건까지 무료"

JURI_SIGNUP_URL="https://jurisupport.com"
JURI_TOKEN_URL="https://jurisupport.com/profile"   # 가입 후 이 페이지에서 토큰 발급
JURI_MCP_URL="https://api.jurisupport.com/mcp/sse"

# 브라우저 자동 열기 함수 (OS별)
open_url() {
  case "$PLATFORM" in
    mac)     open "$1" 2>/dev/null ;;
    linux)   xdg-open "$1" 2>/dev/null || true ;;
    windows) cmd.exe /c "start $1" 2>/dev/null || powershell.exe -Command "Start-Process '$1'" 2>/dev/null ;;
  esac
}

if claude mcp list 2>&1 | grep -q "^jurisupport:"; then
  info "JuriSupport MCP 이미 등록됨"
else
  echo ""
  echo "  JuriSupport SaaS — 사건·문서·기일·할일·증거 통합 관리 (한국 변호사 전용)"
  echo "  💡 사건 50건까지 무료. 본격 송무 환경 갖추는 데 부담 없이 시작 가능합니다."
  echo ""
  echo "  · 가입 페이지: $JURI_SIGNUP_URL"
  echo "  · 토큰 발급:   $JURI_TOKEN_URL  (가입 후)"
  echo "  · MCP 엔드포인트: $JURI_MCP_URL"
  echo ""
  read -r -p "JuriSupport 가입·MCP 연동을 진행할까요? [Y/n, 엔터=예] " ans
  if [[ "$ans" =~ ^[Nn]$ ]]; then
    info "건너뛰기. 나중에:  claude mcp add --transport sse jurisupport $JURI_MCP_URL --header 'Authorization: Bearer <token>'"
    info "(JuriSupport 없이도 본 패키지 모든 기능 사용 가능. CSV 사건 인덱스로 대체)"
  else
    read -r -p "이미 jurisupport.com 계정 + 토큰이 있으신가요? [Y/n, 엔터=예] " has_token
    if [[ "$has_token" =~ ^[Nn]$ ]]; then
      info "가입 페이지를 브라우저로 엽니다..."
      open_url "$JURI_SIGNUP_URL"
      echo ""
      echo "  ────────────────────────────────────────────────────────────"
      echo "  1. 브라우저에서 jurisupport.com 가입 (사건 50건까지 무료)"
      echo "  2. 가입·로그인 완료되면 엔터 → 프로필 페이지 자동으로 열립니다"
      echo "  ────────────────────────────────────────────────────────────"
      read -r -p "가입 완료 후 엔터: " _
      info "프로필 페이지(토큰 발급)를 엽니다..."
      open_url "$JURI_TOKEN_URL"
      echo ""
      echo "  ────────────────────────────────────────────────────────────"
      echo "  3. 프로필 페이지($JURI_TOKEN_URL)에서 API 토큰 발급"
      echo "  4. 토큰을 복사한 뒤 이 터미널로 돌아오세요"
      echo "  ────────────────────────────────────────────────────────────"
      read -r -p "토큰 복사 완료되면 엔터: " _
    fi

    echo ""
    echo "  토큰을 붙여넣어 주세요 (입력은 화면에 표시되지 않습니다, 보안):"
    read -r -s -p "  토큰: " JURI_TOKEN
    echo ""

    if [[ -z "$JURI_TOKEN" ]]; then
      warn "토큰 미입력 → MCP 등록 건너뜀."
      info "나중에 등록:  claude mcp add --transport sse jurisupport $JURI_MCP_URL --header 'Authorization: Bearer <token>'"
    else
      info "MCP 등록 중..."
      if claude mcp add --transport sse jurisupport "$JURI_MCP_URL" --header "Authorization: Bearer $JURI_TOKEN" 2>&1 | tail -3; then
        info "✓ JuriSupport MCP 등록 완료"
        info "→ 'claude' 안에서 mcp__jurisupport__* 도구 즉시 사용 가능"
      else
        warn "등록 실패. 토큰을 다시 확인하고 수동 등록:"
        warn "  claude mcp add --transport sse jurisupport $JURI_MCP_URL --header 'Authorization: Bearer <token>'"
      fi
      unset JURI_TOKEN  # 셸 환경에서 토큰 흔적 제거
    fi
  fi
fi

# ============================================================
# Done
# ============================================================
# MARKETPLACE_PATH 미정의 시 fallback
MARKETPLACE_PATH="${MARKETPLACE_PATH:-$TOOLKIT_DIR}"

cat <<EOF

$(printf '\033[0;32m')========================================
✓ 설치 완료
========================================$(printf '\033[0m')

다음 단계:
  1. 필독: $TOOLKIT_DIR/guides/00_security.md (5분)
  2. 새 터미널에서 클로드코드 시작:
       claude
  3. (JuriSupport 등록한 경우) 첫 도구 호출 시 자동으로 브라우저 OAuth 열림
  4. 시작 명령:
       "안녕. 설치된 스킬과 플러그인 보여줘."
  5. 첫 사건 설정: /songmu-legal:cold-start-interview
  6. 첫 준비서면: /songmu-legal:brief-protocol

플러그인 자동 설치 안 됐다면 (드물지만) 클로드코드 안에서 수동 실행:
       /plugin marketplace add $MARKETPLACE_PATH
       /plugin install songmu-legal

전체 가이드: $TOOLKIT_DIR/README.md

⚠ /songmu-legal:cold-start-interview 가 "Unknown command"로 뜨면
   plugin 자동 설치가 실패한 것 — 위 수동 명령 두 줄 실행하세요.

EOF
