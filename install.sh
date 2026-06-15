#!/usr/bin/env bash
# jurisupport-plugins one-shot installer (Mac/Linux)
#
# Installs:
#   1. Prerequisite tool check
#   2. Data protection hook
#   3. jurisupport plugin (from git submodule or repo)
#   4. korean-law MCP plugin (public law/precedent verification, if OC is ready)
#   5. lbox-guide and beopgoeul-search skills
#   6. Case info CSV template
#   7. (Optional) legal-books server + skill
#   8. (Optional) case-records server + skill
#   9. (Optional) court-forms DB toolkit
#   10. (Optional) beopgoeul-search toolkit
#   11. (Optional) clean-legal-db offline legal database
#   12. (Recommended) JuriSupport MCP registration

set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/dry-run.sh
source "$TOOLKIT_DIR/lib/dry-run.sh" "$@"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
if [[ ! -t 1 || -n "${NO_COLOR:-}" ]]; then
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; NC=''
fi
TOTAL_STEPS=12
info()  { printf '%b[info]%b %s\n' "$GREEN" "$NC" "$*"; }
warn()  { printf '%b[warn]%b %s\n' "$YELLOW" "$NC" "$*"; }
error() { printf '%b[error]%b %s\n' "$RED" "$NC" "$*"; exit 1; }
step()  {
  local n="$1"; shift
  local bar=""
  local i
  for ((i=1; i<=TOTAL_STEPS; i++)); do
    if [[ $i -le $n ]]; then bar+="#"; else bar+="-"; fi
  done
  printf '\n%b+----------------------------------------------------------+%b\n' "$CYAN" "$NC"
  printf '%b|%b %b[%s/%s]%b %s\n' "$CYAN" "$NC" "$BLUE" "$n" "$TOTAL_STEPS" "$NC" "$*"
  printf '%b|%b 진행: %b%s%b\n' "$CYAN" "$NC" "$GREEN" "$bar" "$NC"
  printf '%b+----------------------------------------------------------+%b\n' "$CYAN" "$NC"
}

# ============================================================
# 0. Banner + safety check
# ============================================================
cat <<'BANNER'

================================================================
  jurisupport-plugins installer
  변호사용 클로드코드 통합 패키지 설치
----------------------------------------------------------------
  [주의] 설치 전 반드시 읽어야 할 문서:
         guides/00_security.md (의뢰인 정보 보호 원칙)

  [팁] [Y/n] 프롬프트는 엔터만 치면 '예'로 진행됩니다.
       [y/N] 프롬프트는 엔터만 치면 '아니오/나중에'로 진행됩니다.

  계속: Enter    취소: Ctrl+C
================================================================

BANNER
if is_dry_run; then
  info "---- DRY-RUN 모드: 실제 변경 없이 설치 계획만 출력합니다 ----"
else
  read -r -p "" _
fi

OS="$(uname -s)"
case "$OS" in
  Darwin*)              PLATFORM="mac" ;;
  Linux*)               PLATFORM="linux" ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
  *) error "지원하지 않는 OS: $OS. macOS/Linux/Windows(Git Bash)만 지원합니다." ;;
esac

info "패키지 경로: $TOOLKIT_DIR"
info "플랫폼: $PLATFORM"

KOREAN_LAW_OPENAPI_URL="https://open.law.go.kr/LSO/openApi/guideList.do"

# 브라우저 자동 열기 함수 (OS별)
open_url() {
  local url="$1"
  local opened=0

  case "$PLATFORM" in
    mac)     open "$url" 2>/dev/null || opened=$? ;;
    linux)   xdg-open "$url" 2>/dev/null || opened=$? ;;
    windows) cmd.exe /c "start $url" 2>/dev/null || powershell.exe -Command "Start-Process '$url'" 2>/dev/null || opened=$? ;;
  esac

  if [[ "$opened" -ne 0 ]]; then
    warn "브라우저 자동 열기 실패. 아래 URL을 직접 열어주세요:"
    echo "  $url"
  fi

  return 0
}

prompt_read() {
  local __var="$1"
  local prompt="$2"
  local value=""

  if [[ -r /dev/tty && -w /dev/tty ]]; then
    printf "%s" "$prompt" > /dev/tty
    IFS= read -r value < /dev/tty || value=""
  else
    IFS= read -r -p "$prompt" value || value=""
  fi

  printf -v "$__var" '%s' "$value"
}

prompt_secret() {
  local __var="$1"
  local prompt="$2"
  local value=""

  if [[ -r /dev/tty && -w /dev/tty ]]; then
    printf "%s" "$prompt" > /dev/tty
    IFS= read -r -s value < /dev/tty || value=""
    printf "\n" > /dev/tty
  else
    IFS= read -r -s -p "$prompt" value || value=""
    echo ""
  fi

  printf -v "$__var" '%s' "$value"
}

# ============================================================
# 1. Prerequisites
# ============================================================
step 1 "필수 도구 확인"

if is_dry_run; then
  info "필수 도구 확인 예정: claude, git, jq"
else
  command -v claude >/dev/null || error "클로드코드(CLI) 미설치. 설치: https://docs.claude.com/claude-code"
  command -v git >/dev/null || error "git 필요. (먼저 git 설치 후 재실행)"
fi

# jq is required for hook registration — try auto-install
if is_dry_run; then
  : # jq check skipped in dry-run
elif ! command -v jq >/dev/null 2>&1; then
  warn "jq 미설치 (데이터 보호 Hook에 필요)"
  case "$PLATFORM" in
    mac)
      if command -v brew >/dev/null 2>&1; then
        info "Homebrew로 jq 자동 설치 중..."
        brew install jq >/dev/null 2>&1 && info "[ok] jq 설치 완료" || error "jq 설치 실패. 수동 실행: brew install jq"
      else
        error "Homebrew 미설치. https://brew.sh 에서 먼저 설치 후 재실행."
      fi
      ;;
    linux)
      if command -v apt-get >/dev/null 2>&1; then
        info "apt로 jq 자동 설치 중..."
        sudo apt-get install -y jq >/dev/null 2>&1 && info "[ok] jq 설치 완료" || error "jq 설치 실패. 수동 실행: sudo apt install jq"
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
run_or_plan chmod +x "$HOOK_SRC"

SETTINGS="$HOME/.claude/settings.json"
run_or_plan mkdir -p "$(dirname "$SETTINGS")"
if ! is_dry_run; then
  [[ -f "$SETTINGS" ]] || echo '{}' > "$SETTINGS"
fi

# Compose hook command (Windows needs Git Bash absolute path)
if [[ "$PLATFORM" == "windows" ]]; then
  # Windows 네이티브 Claude Code는 .sh 직접 실행 불가 -> Git Bash로 호출
  BASH_WIN="$(cygpath -w "$(command -v bash)" 2>/dev/null || echo 'C:\Program Files\Git\bin\bash.exe')"
  HOOK_WIN="$(cygpath -w "$HOOK_SRC")"
  HOOK_CMD="\"$BASH_WIN\" \"$HOOK_WIN\""
else
  HOOK_CMD="$HOOK_SRC"
fi

# Add hook entry if not present
if is_dry_run; then
  info_or_plan "Hook 등록: pretool_data_protection -> $SETTINGS"
elif ! grep -q "pretool_data_protection.sh" "$SETTINGS"; then
  TMP=$(mktemp)
  jq --arg cmd "$HOOK_CMD" '
    .hooks.PreToolUse = (.hooks.PreToolUse // []) + [{
      "matcher": "WebFetch|WebSearch|mcp__google-workspace__gmail_send.*|mcp__google-workspace__chat_.*|mcp__claude_ai_Gmail__.*|mcp__claude_ai_Google_Drive__search_files|mcp__plugin_telegram_telegram__reply",
      "hooks": [{"type": "command", "command": $cmd}]
    }]
  ' "$SETTINGS" > "$TMP" && mv "$TMP" "$SETTINGS"
  info "Hook 등록 완료: $SETTINGS"
else
  info "Hook 이미 등록됨"
fi

# ============================================================
# 3. JuriSupport plugin (same repo - register only)
# ============================================================
step 3 "JuriSupport 플러그인 등록"

JURISUPPORT_PLUGIN_LOCAL="$TOOLKIT_DIR/plugins/jurisupport"
MARKETPLACE_DIR="$TOOLKIT_DIR"   # marketplace.json이 있는 레포 루트

if [[ ! -f "$JURISUPPORT_PLUGIN_LOCAL/.claude-plugin/plugin.json" ]]; then
  warn "JuriSupport 플러그인 없음: $JURISUPPORT_PLUGIN_LOCAL"
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

  if is_dry_run; then
    info_or_plan "marketplace 등록: $MARKETPLACE_PATH"
    info_or_plan "legacy songmu-legal 플러그인 등록 정리"
    info_or_plan "JuriSupport 플러그인 설치/갱신"
    if [[ "$PLATFORM" == "windows" ]]; then
      info_or_plan "Windows 기존 설치본 재설치(--keep-data)"
    fi
    info_or_plan "CLAUDE.md 템플릿 복사"
  else
    # 1) marketplace 등록 (이미 있으면 건너뜀)
    if claude plugin marketplace list 2>/dev/null | grep -q "jurisupport-plugins"; then
      info "marketplace 'jurisupport-plugins' 이미 등록됨"
    else
      info "marketplace 자동 등록 중: $MARKETPLACE_PATH"
      if claude plugin marketplace add "$MARKETPLACE_PATH" 2>&1 | tail -3; then
        info "[ok] marketplace 등록 완료"
      else
        warn "marketplace 등록 실패. 수동: claude plugin marketplace add \"$MARKETPLACE_PATH\""
      fi
    fi

    # 2) legacy plugin cleanup. The old command prefix was /songmu-legal:*.
    if claude plugin list 2>/dev/null | grep -q "songmu-legal"; then
      info "legacy songmu-legal 플러그인 등록 정리 중..."
      claude plugin uninstall songmu-legal 2>&1 | tail -3 || warn "legacy songmu-legal 제거 실패. 수동: claude plugin uninstall songmu-legal"
    fi

    install_jurisupport_plugin() {
      info "JuriSupport 자동 설치 중..."
      # Keep plugin installs attached to the terminal so Claude can show
      # interactive trust/config prompts.
      if claude plugin install jurisupport@jurisupport-plugins; then
        info "[ok] JuriSupport 설치 완료"
      else
        warn "자동 설치 실패. 수동: claude plugin install jurisupport@jurisupport-plugins"
      fi
    }

    # 3) JuriSupport 플러그인 설치/갱신
    if claude plugin list 2>/dev/null | grep -q "jurisupport"; then
      if [[ "$PLATFORM" == "windows" ]]; then
        info "Windows는 플러그인을 복사본으로 보관하므로 최신 파일로 재설치합니다"
        claude plugin marketplace update jurisupport-plugins 2>&1 | tail -3 || \
          warn "marketplace 갱신 실패. 수동: claude plugin marketplace update jurisupport-plugins"
        if claude plugin uninstall --keep-data -y jurisupport; then
          install_jurisupport_plugin
        else
          warn "기존 JuriSupport 제거 실패. 수동: claude plugin uninstall --keep-data -y jurisupport"
          warn "그 다음 실행: claude plugin install jurisupport@jurisupport-plugins"
        fi
      else
        info "JuriSupport 플러그인 이미 설치됨"
      fi
    else
      install_jurisupport_plugin
    fi

    # Bootstrap CLAUDE.md from CLAUDE.md.example if missing
    if [[ ! -f "$JURISUPPORT_PLUGIN_LOCAL/CLAUDE.md" ]] && [[ -f "$JURISUPPORT_PLUGIN_LOCAL/CLAUDE.md.example" ]]; then
      cp "$JURISUPPORT_PLUGIN_LOCAL/CLAUDE.md.example" "$JURISUPPORT_PLUGIN_LOCAL/CLAUDE.md"
      info "템플릿에서 CLAUDE.md 생성: $JURISUPPORT_PLUGIN_LOCAL/CLAUDE.md"
      info "-> 클로드코드에서 /jurisupport:cold-start-interview 실행하여 채우세요"
    fi
  fi
fi

# ============================================================
# 4. korean-law MCP plugin or offline fallback
# ============================================================
step 4 "korean-law MCP 설치 또는 오프라인 법령 폴백 안내"

KOREAN_LAW_MARKETPLACE_SOURCE="chrisryugj/korean-law-mcp"
KOREAN_LAW_MARKETPLACE_NAME="korean-law-marketplace"
KOREAN_LAW_PLUGIN_REF="korean-law@$KOREAN_LAW_MARKETPLACE_NAME"

if is_dry_run; then
  info_or_plan "법제처 OC가 있으면 korean-law marketplace 등록: $KOREAN_LAW_MARKETPLACE_SOURCE"
  info_or_plan "법제처 OC가 있으면 korean-law 플러그인 설치: $KOREAN_LAW_PLUGIN_REF"
  info_or_plan "OC가 없으면 설치는 계속 진행하고 /jurisupport:offline-law-fallback 사용"
else
  if claude plugin list 2>/dev/null | grep -q "korean-law@"; then
    info "korean-law 플러그인 이미 설치됨"
    info "-> 법령/판례 검증 시 korean-law MCP 도구 사용 가능"
  else
    echo ""
    echo "  korean-law MCP는 법제처 Open API 키(OC)가 있어야 실제 법령·판례 조회가 됩니다."
    echo "  OC 발급 전에도 JuriSupport 설치는 계속되며,"
    echo "  플러그인에 포함된 /jurisupport:offline-law-fallback 으로 헌/민/형/상법 및 주요 특별형법 전문 실습이 가능합니다."
    echo ""
    read -r -p "법제처 Open API 키(OC)를 지금 갖고 있나요? [y/N, 엔터=아니오] " has_law_key
    if [[ "$has_law_key" =~ ^[Yy]$ ]]; then
      if claude plugin marketplace list 2>/dev/null | grep -q "$KOREAN_LAW_MARKETPLACE_NAME"; then
        info "marketplace '$KOREAN_LAW_MARKETPLACE_NAME' 이미 등록됨"
      else
        info "korean-law marketplace 자동 등록 중: $KOREAN_LAW_MARKETPLACE_SOURCE"
        if claude plugin marketplace add "$KOREAN_LAW_MARKETPLACE_SOURCE" 2>&1 | tail -3; then
          info "[ok] korean-law marketplace 등록 완료"
        else
          warn "korean-law marketplace 등록 실패. 수동: claude plugin marketplace add $KOREAN_LAW_MARKETPLACE_SOURCE"
        fi
      fi

      info "korean-law 자동 설치 중..."
      info "설치 승인 및 법제처 OC 입력 프롬프트가 나오면 그대로 진행하세요."
      if claude plugin install "$KOREAN_LAW_PLUGIN_REF"; then
        info "[ok] korean-law 설치 완료"
        info "-> 법령/판례 검증 시 korean-law MCP 도구 사용 가능"
      else
        warn "korean-law 자동 설치가 완료되지 않았습니다. JuriSupport 설치는 계속 진행합니다."
        warn "수동 재시도: claude plugin install $KOREAN_LAW_PLUGIN_REF"
      fi
    else
      warn "OC 미준비 -> korean-law MCP 설치는 건너뜁니다."
      info "오프라인 실습: 클로드코드에서 /jurisupport:offline-law-fallback 사용"
      info "포함 범위: 대한민국헌법, 민법, 민사소송법, 형법, 형사소송법, 상법, 주요 특별형법 전문"
      read -r -p "법제처 Open API 신청 페이지를 브라우저로 열까요? [y/N] " open_law_page
      if [[ "$open_law_page" =~ ^[Yy]$ ]]; then
        info "법제처 Open API 신청 페이지를 브라우저로 엽니다..."
        open_url "$KOREAN_LAW_OPENAPI_URL"
      fi
      echo ""
      echo "  OC 발급 후 수동 설치:"
      echo "    claude plugin marketplace add $KOREAN_LAW_MARKETPLACE_SOURCE"
      echo "    claude plugin install $KOREAN_LAW_PLUGIN_REF"
      echo "  발급 가이드: $TOOLKIT_DIR/guides/07_law_openapi_key.md"
    fi
  fi
fi

# ============================================================
# 5. Skills (always-on guides; beopgoeul toolkit installs later)
# ============================================================
step 5 "가이드 스킬 설치"

# Always-on: lbox-guide and beopgoeul-search appear immediately.
# beopgoeul-search tells the user how to enable the optional Selenium toolkit if missing.
for SKILLS_ROOT in "$HOME/.claude/skills" "$HOME/.codex/skills"; do
  run_or_plan mkdir -p "$SKILLS_ROOT"
  for SKILL in lbox-guide beopgoeul-search; do
    run_or_plan mkdir -p "$SKILLS_ROOT/$SKILL"
    run_or_plan cp "$TOOLKIT_DIR/skills/$SKILL/SKILL.md" "$SKILLS_ROOT/$SKILL/SKILL.md"
    info_or_plan "스킬 설치: $SKILL ($SKILLS_ROOT)"
  done
done
run_or_plan mkdir -p "$HOME/.claude/commands"
run_or_plan cp "$TOOLKIT_DIR/skills/beopgoeul-search/SKILL.md" "$HOME/.claude/commands/beopgoeul-search.md"
info_or_plan "명령 설치: beopgoeul-search"
# Step 10 installs the runnable Selenium toolkit for beopgoeul-search.

# ============================================================
# 6. CSV template
# ============================================================
step 6 "사건정보 관리표 템플릿 설정"

if [[ ! -d "$HOME/사건" ]]; then
  if is_dry_run; then
    info_or_plan "~/사건 디렉토리 생성 + CSV 템플릿 복사"
  else
    read -r -p "~/사건 디렉토리 생성하고 CSV 템플릿 복사? [Y/n, 엔터=예] " ans
    if [[ "$ans" =~ ^[Nn]$ ]]; then
      info "건너뛰기. 나중에 실행: mkdir -p ~/사건 && cp $TOOLKIT_DIR/templates/사건정보_관리표.csv ~/사건/"
    else
      mkdir -p "$HOME/사건"
      cp "$TOOLKIT_DIR/templates/사건정보_관리표.csv" "$HOME/사건/_사건정보관리표.csv"
      cp "$TOOLKIT_DIR/templates/사건정보_입력가이드.md" "$HOME/사건/_입력가이드.md"
      info "템플릿을 ~/사건/ 에 복사 완료"
    fi
  fi
else
  info "~/사건 이미 존재. 템플릿은 $TOOLKIT_DIR/templates/ 에 있음"
fi

# ============================================================
# 7. Optional: legal-books toolkit
# ============================================================
step 7 "(선택) legal-books 검색 서버 설치"

if is_dry_run; then
  info_or_plan "legal-books 검색 서버 설치"
else
  echo ""
  echo "  - 사무소 보유 교과서를 검색/인용하게 해주는 도구입니다."
  echo "  - 지금은 서버/DB 틀만 세움. 책은 설치 후 add_book.sh로 한 권씩 추가."
  echo "  - 보유 책이 없거나 당장 OCR 시간 없으면 건너뛰고 나중에 재설치 가능."
  echo ""
  read -r -p "지금 설치할까요? [Y/n, 엔터=예] " ans
  if [[ ! "$ans" =~ ^[Nn]$ ]]; then
    bash "$TOOLKIT_DIR/toolkit/legal-books/install.sh" || warn "legal-books 설치 실패. 나중에 다시 시도하세요."
  else
    info "건너뛰기. 나중에 설치: bash $TOOLKIT_DIR/toolkit/legal-books/install.sh"
  fi
fi

# ============================================================
# 8. Optional: case-records toolkit
# ============================================================
step 8 "(선택) case-records 검색 서버 설치"

if is_dry_run; then
  info_or_plan "case-records 검색 서버 설치"
else
  echo ""
  echo "  - 사무소 과거 사건 서면/판결문을 검색하게 해주는 도구입니다."
  echo "  - 지금은 서버/DB 틀만 세움. 사건은 설치 후 ingest_case.sh / ingest_all.sh로 인덱싱."
  echo "  - 사건폴더가 정리되어 있으면 일괄 인덱싱(1건 1~3분) 가능."
  echo "  - 당장 인덱싱 시간 없으면 건너뛰고 나중에 재설치 가능."
  echo ""
  read -r -p "지금 설치할까요? [Y/n, 엔터=예] " ans
  if [[ ! "$ans" =~ ^[Nn]$ ]]; then
    bash "$TOOLKIT_DIR/toolkit/case-records/install.sh" || warn "case-records 설치 실패. 나중에 다시 시도하세요."
  else
    info "건너뛰기. 나중에 설치: bash $TOOLKIT_DIR/toolkit/case-records/install.sh"
  fi
fi

# ============================================================
# 9. Optional: court-forms toolkit
# ============================================================
step 9 "(선택) 법원 양식 DB toolkit 설치"

if is_dry_run; then
  info_or_plan "법원 전자소송포털 공개 양식 DB toolkit 설치"
else
  echo ""
  echo "  - 전자소송포털 공개 양식모음 메타데이터를 로컬 SQLite DB로 검색합니다."
  echo "  - 기본 동기화는 HWP/PDF 원본을 받지 않고 목록과 다운로드 URL만 저장합니다."
  echo "  - 양식 작성 시 필요한 공식 서식을 검색하고 필요한 파일만 다운로드합니다."
  echo ""
  read -r -p "지금 설치할까요? [Y/n, 엔터=예] " ans
  if [[ ! "$ans" =~ ^[Nn]$ ]]; then
    bash "$TOOLKIT_DIR/toolkit/court-forms/install.sh" || warn "court-forms 설치 실패. 나중에 다시 시도하세요."
  else
    info "건너뛰기. 나중에 설치: bash $TOOLKIT_DIR/toolkit/court-forms/install.sh"
  fi
fi

# ============================================================
# 10. Optional: beopgoeul (법고을) auto-search toolkit
# ============================================================
step 10 "(선택) 법고을 자동 검색 toolkit 설치 (Selenium)"

if is_dry_run; then
  info_or_plan "법고을 자동 검색 toolkit 설치"
else
  read -r -p "지금 설치할까요? (Chrome도 자동 설치됨) [Y/n, 엔터=예] " ans
  if [[ ! "$ans" =~ ^[Nn]$ ]]; then
    # || warn — Chrome 미설치 등 실패해도 main install.sh는 종료되지 않음
    bash "$TOOLKIT_DIR/toolkit/beopgoeul/install.sh" || warn "법고을 toolkit 설치 실패. beopgoeul-search 스킬은 설치됐지만 자동 검색은 나중에 재시도해야 합니다."
  else
    info "건너뛰기. beopgoeul-search 스킬은 설치되어 있지만 자동 검색 toolkit은 비활성화됩니다."
    info "대신 lbox-guide 스킬을 사용할 수 있습니다."
    info "나중에 설치: bash $TOOLKIT_DIR/toolkit/beopgoeul/install.sh"
  fi
fi

# 11. Optional: clean-legal-db (오프라인 법률 DB 검색)
# ============================================================
step 11 "(선택) 클린 법률 DB 설치 (오프라인 SQLite, 약 235MB)"

if is_dry_run; then
  info_or_plan "clean-legal-db 설치 (DB 다운로드 + 스킬 등록)"
else
  echo ""
  echo "  · 저작권 청정 법령·판례 DB(18,150여 건)를 오프라인 검색하게 해주는 도구입니다."
  echo "  · API 키·인터넷 불필요. 설치 시 DB(약 235MB)를 1회 다운로드합니다."
  echo "  · 다운로드 시간·용량 부담되면 건너뛰고 나중에 재설치 가능."
  echo ""
  read -r -p "지금 설치할까요? [Y/n, 엔터=예] " ans
  if [[ ! "$ans" =~ ^[Nn]$ ]]; then
    bash "$TOOLKIT_DIR/toolkit/clean-legal-db/install.sh" || warn "clean-legal-db 설치 실패. 나중에 다시 시도하세요."
  else
    info "건너뛰기. 나중에 설치: bash $TOOLKIT_DIR/toolkit/clean-legal-db/install.sh"
  fi
fi

# ============================================================
# 12. Optional: JuriSupport MCP 등록
# ============================================================
step 12 "(권장) JuriSupport 가입/MCP 연동 - 50건까지 무료"

JURI_SIGNUP_URL="https://jurisupport.com"
JURI_TOKEN_URL="https://jurisupport.com/profile"   # 가입 후 이 페이지에서 토큰 발급
JURI_MCP_URL="https://api.jurisupport.com/mcp/sse"

if is_dry_run; then
  info_or_plan "JuriSupport MCP 등록 (가입/토큰 발급/MCP add)"
elif claude mcp list 2>&1 | grep -q "^jurisupport:"; then
  info "JuriSupport MCP 이미 등록됨"
else
  echo ""
  echo "  JuriSupport SaaS - 사건/문서/기일/할일/증거 통합 관리 (한국 변호사 전용)"
  echo "  [팁] 사건 50건까지 무료. 본격 송무 환경 갖추는 데 부담 없이 시작 가능합니다."
  echo ""
  echo "  - 가입 페이지: $JURI_SIGNUP_URL"
  echo "  - 토큰 발급:   $JURI_TOKEN_URL  (가입 후)"
  echo "  - MCP 엔드포인트: $JURI_MCP_URL"
  echo ""
  prompt_read ans "JuriSupport 가입/MCP 연동을 진행할까요? [Y/n, 엔터=예] "
  if [[ "$ans" =~ ^[Nn]$ ]]; then
    info "건너뛰기. 나중에:  claude mcp add --transport sse jurisupport $JURI_MCP_URL --header 'Authorization: Bearer <token>'"
    info "(JuriSupport 없이도 본 패키지 모든 기능 사용 가능. CSV 사건 인덱스로 대체)"
  else
    echo ""
    echo "  [팁] 토큰은 $JURI_TOKEN_URL 에서 발급받을 수 있습니다."
    echo "     (가입 후 위 페이지 접속 -> API 토큰 생성)"
    echo ""
    prompt_read has_token "이미 jurisupport.com 계정 + 토큰이 있으신가요? [y/N, 엔터=아니오] "
    if [[ ! "$has_token" =~ ^[Yy]$ ]]; then
      info "가입 페이지를 브라우저로 엽니다..."
      open_url "$JURI_SIGNUP_URL"
      echo ""
      echo "  ------------------------------------------------------------"
      echo "  1. 브라우저에서 jurisupport.com 가입 (사건 50건까지 무료)"
      echo "  2. 가입/로그인 완료되면 엔터 -> 프로필 페이지 자동으로 열립니다"
      echo "  ------------------------------------------------------------"
      prompt_read _ "가입 완료 후 엔터: "
      info "프로필 페이지(토큰 발급)를 엽니다..."
      open_url "$JURI_TOKEN_URL"
      echo ""
      echo "  ------------------------------------------------------------"
      echo "  3. 프로필 페이지($JURI_TOKEN_URL)에서 API 토큰 발급"
      echo "  4. 토큰을 복사한 뒤 이 터미널로 돌아오세요"
      echo "  ------------------------------------------------------------"
      prompt_read _ "토큰 복사 완료되면 엔터: "
    fi

    # 토큰 입력 + 검증 (최대 3회 재시도)
    JURI_TOKEN=""
    attempt=0
    while [[ $attempt -lt 3 ]]; do
      echo ""
      if [[ $attempt -eq 0 ]]; then
        echo "  토큰을 붙여넣어 주세요 (입력은 화면에 표시되지 않습니다, 보안):"
      else
        echo "  토큰을 다시 입력하세요 (시도 $((attempt+1))/3, 건너뛰려면 Enter):"
      fi
      prompt_secret JURI_TOKEN "  토큰: "

      if [[ -z "$JURI_TOKEN" ]]; then
        warn "토큰 미입력 -> MCP 등록 건너뜀."
        break
      fi

      # jurisupport.com 토큰 검증 (SSE 엔드포인트에 인증 헤더만 보내 응답 코드 확인)
      info "토큰 검증 중..."
      HTTP_CODE=$(
        CURL_CONFIG="$(mktemp)"
        chmod 600 "$CURL_CONFIG"
        trap 'rm -f "$CURL_CONFIG"' EXIT
        {
          printf 'silent\n'
          printf 'output = "/dev/null"\n'
          printf 'write-out = "%%{http_code}"\n'
          printf 'max-time = 6\n'
          printf 'connect-timeout = 4\n'
          printf 'header = "Authorization: Bearer %s"\n' "$JURI_TOKEN"
          printf 'header = "Accept: text/event-stream"\n'
          printf 'url = "%s"\n' "$JURI_MCP_URL"
        } > "$CURL_CONFIG"
        curl --config "$CURL_CONFIG" 2>/dev/null || echo "000"
      )

      case "$HTTP_CODE" in
        200|204|000)
          # 000 = curl timeout: SSE 스트림이 정상 응답하면 keep-alive로 잡힘. 일단 진행.
          if [[ "$HTTP_CODE" == "000" ]]; then
            info "[ok] 토큰 응답 정상 (SSE keep-alive, HTTP 000)"
          else
            info "[ok] 토큰 검증 성공 (HTTP $HTTP_CODE)"
          fi
          break
          ;;
        401|403)
          attempt=$((attempt+1))
          warn "[fail] 토큰 인증 실패 (HTTP $HTTP_CODE)"
          if [[ $attempt -lt 3 ]]; then
            warn "  $JURI_TOKEN_URL 에서 토큰을 다시 확인/재발급 후 입력하세요."
          else
            warn "  3회 모두 실패. MCP 등록 건너뜀."
            JURI_TOKEN=""
          fi
          ;;
        404|405)
          warn "검증 엔드포인트 응답 형식 변경 가능성 (HTTP $HTTP_CODE) - 그대로 등록 진행"
          break
          ;;
        *)
          warn "검증 응답 모호 (HTTP $HTTP_CODE) - 그대로 등록 진행"
          break
          ;;
      esac
    done

    if [[ -z "$JURI_TOKEN" ]]; then
      info "나중에 등록:  claude mcp add --transport sse jurisupport $JURI_MCP_URL --header 'Authorization: Bearer <token>'"
    else
      info "MCP 등록 중..."
      warn "Claude Code CLI는 bearer header 등록 시 --header 인자를 사용합니다. 등록 순간 같은 PC의 프로세스 목록에 토큰이 짧게 보일 수 있습니다."
      if claude mcp add --transport sse jurisupport "$JURI_MCP_URL" --header "Authorization: Bearer $JURI_TOKEN"; then
        info "[ok] JuriSupport MCP 등록 완료"
        info "-> 'claude' 안에서 mcp__jurisupport__* 도구 즉시 사용 가능"
        echo ""
        echo -e "${CYAN}  다음 단계 (사건 작업 시작 전):${NC}"
        echo "    - https://jurisupport.com/cases 에서 사건을 등록한 뒤 진행하시면 좋습니다."
        echo "    - 전자소송 사건목록 엑셀을 업로드하면 사건이 자동으로 일괄 등록됩니다."
        echo "    - 사건번호만 있으면 클로드코드 안에서 mcp__jurisupport__create_case 로도 추가 가능."
        echo ""
      else
        warn "등록 실패. 수동: claude mcp add --transport sse jurisupport $JURI_MCP_URL --header 'Authorization: Bearer <token>'"
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

========================================
$(if is_dry_run; then printf '[ok] DRY-RUN 완료 (실제 변경 없음)'; else printf '[ok] 설치 완료'; fi)
========================================

다음 단계:
  1. 필독: $TOOLKIT_DIR/guides/00_security.md (5분)
  2. 새 터미널에서 클로드코드 시작:
       claude
  3. (JuriSupport 등록한 경우) 첫 도구 호출 시 자동으로 브라우저 OAuth 열림
  4. 시작 명령:
       "안녕. 설치된 스킬과 플러그인 보여줘."
  5. 첫 사건 설정: /jurisupport:cold-start-interview
  6. 첫 준비서면: /jurisupport:brief-protocol

플러그인 자동 설치 안 됐다면 (드물지만) 클로드코드 안에서 수동 실행:
       /plugin marketplace add "$MARKETPLACE_PATH"
       /plugin install jurisupport@jurisupport-plugins

korean-law MCP는 법제처 OC 발급 후 클로드코드 안에서 수동 설치:
       /plugin marketplace add $KOREAN_LAW_MARKETPLACE_SOURCE
       /plugin install $KOREAN_LAW_PLUGIN_REF
       (법제처 OC 발급 방법: $TOOLKIT_DIR/guides/07_law_openapi_key.md)

OC 발급 전 시연/실습:
       /jurisupport:offline-law-fallback
       (헌법, 민법, 민사소송법, 형법, 형사소송법, 상법, 주요 특별형법 전문 스냅샷 포함)

전체 가이드: $TOOLKIT_DIR/README.md

[주의] /jurisupport:cold-start-interview 가 "Unknown command"로 뜨면
   plugin 자동 설치가 실패한 것 - 위 수동 명령 두 줄 실행하세요.

[주의] korean-law 도구가 보이지 않아도 OC 발급 전이면 정상입니다.
   실습은 /jurisupport:offline-law-fallback 으로 진행하고, 실제 사건 제출 전에는 korean-law MCP를 설치해 재검증하세요.

EOF
