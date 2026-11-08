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
#   9. (Optional) court-forms DB toolkit (+ law-forms hwpx form filler)
#   10. (Optional) beopgoeul-search toolkit
#   11. (Optional) clean-legal-db offline legal database
#   12. (Recommended) JuriSupport MCP registration (all folders)
#   Then recommended companions: lawyer profile plugin, legal-terminal app,
#   legal-polish-public plugin, and (optional) e-court tools, followed by a
#   per-tool status table.

set -euo pipefail

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/dry-run.sh
source "$TOOLKIT_DIR/lib/dry-run.sh" "$@"
source "$TOOLKIT_DIR/lib/install-host.sh"
jurisupport_select_host "$@"

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

# Codex uses its native plugin CLI; the full Claude flow remains below.
if jurisupport_has_host codex; then
  source "$TOOLKIT_DIR/lib/install-codex.sh"
  jurisupport_install_codex "$TOOLKIT_DIR" || exit 1
  [[ "$JURISUPPORT_HOST" == codex ]] && exit 0
fi

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

configure_credentials() {
  (
    source "$TOOLKIT_DIR/lib/python-detect.sh"
    select_python 3.9 || { warn "입력창을 열려면 Python 3.9 이상이 필요합니다."; return 1; }
    run_python "$TOOLKIT_DIR/scripts/configure_credentials.py" "$@"
  )
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

SETTINGS="$(jurisupport_path "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/settings.json")"
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
  info_or_plan "korean-law marketplace 등록: $KOREAN_LAW_MARKETPLACE_SOURCE"
  info_or_plan "korean-law 플러그인 설치: $KOREAN_LAW_PLUGIN_REF (OC는 입력창에서 등록)"
  info_or_plan "OC가 없으면 공식 가입 화면을 안내하고 다른 설치는 계속 진행"
else
  if (
    source "$TOOLKIT_DIR/lib/python-detect.sh"
    select_python 3.9 && run_python "$TOOLKIT_DIR/scripts/configure_korean_law.py" --install
  ); then
    if configure_credentials --service korean-law --check >/dev/null 2>&1; then
      info "korean-law OC 설정 있음. 실제 법령 조회는 새 Claude 세션에서 확인하세요."
    else
      prompt_read has_law_key "법제처 Open API 키(OC)를 지금 갖고 있나요? [y/N, 엔터=아니오] "
      if [[ "$has_law_key" =~ ^[Yy]$ ]]; then
        configure_credentials --service korean-law || warn "OC 등록 미완료. 다른 설치는 계속 진행합니다."
      else
        info "OC는 공식 사이트에서 준비한 뒤 입력창에서 등록하세요."
        info "가입·신청 도움: $TOOLKIT_DIR/guides/07_law_openapi_key.md"
        prompt_read open_law_page "법제처 Open API 신청 페이지를 브라우저로 열까요? [y/N] "
        if [[ "$open_law_page" =~ ^[Yy]$ ]]; then
          open_url "$KOREAN_LAW_OPENAPI_URL"
        fi
        info "공용 한도 조회와 본인 OC 설정은 별도입니다. 오프라인 실습은 /jurisupport:offline-law-fallback 사용"
      fi
    fi
  else
    warn "korean-law 설치 미완료. 앱의 플러그인 화면 또는 korean-law-setup.cmd에서 이어가세요."
  fi
fi

# ============================================================
# 5. Skills (always-on guides; beopgoeul toolkit installs later)
# ============================================================
step 5 "가이드 스킬 설치"

# Always-on: lbox-guide and beopgoeul-search appear immediately.
# beopgoeul-search tells the user how to enable the optional Selenium toolkit if missing.
for SKILL in lbox-guide beopgoeul-search; do
  jurisupport_copy_skill "$TOOLKIT_DIR/skills/$SKILL" "$SKILL"
  info_or_plan "스킬 설치: $SKILL ($JURISUPPORT_HOST)"
done
run_or_plan mkdir -p "$(jurisupport_path "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands")"
run_or_plan cp "$TOOLKIT_DIR/skills/beopgoeul-search/SKILL.md" "$(jurisupport_path "${CLAUDE_CONFIG_DIR:-$HOME/.claude}/commands/beopgoeul-search.md")"
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
    LEGAL_BOOKS_REPO="https://github.com/jurisupport/legal-books"
    LEGAL_BOOKS_SRC="$HOME/.jurisupport/legal-books-src"
    if [[ -d "$LEGAL_BOOKS_SRC/.git" ]]; then
      git -C "$LEGAL_BOOKS_SRC" pull --ff-only 2>/dev/null || warn "legal-books 저장소 갱신 실패. 기존 버전으로 진행."
    else
      git clone --depth 1 "$LEGAL_BOOKS_REPO" "$LEGAL_BOOKS_SRC" || warn "legal-books 저장소 clone 실패."
    fi
    if [[ -f "$LEGAL_BOOKS_SRC/toolkit/install.sh" ]]; then
      if configure_credentials --service gemini --check >/dev/null 2>&1 || configure_credentials --service gemini; then
        bash "$LEGAL_BOOKS_SRC/toolkit/install.sh" --with-skill || warn "legal-books 설치 실패. 나중에 다시 시도하세요."
      else
        warn "Gemini 키 입력을 마치지 않아 legal-books 설정을 보류합니다. 터미널로 키를 입력하지 마세요."
      fi
    else
      warn "수동 설치: git clone $LEGAL_BOOKS_REPO && bash legal-books/toolkit/install.sh --with-skill"
    fi
  else
    info "건너뛰기. 나중에 설치: git clone https://github.com/jurisupport/legal-books && bash legal-books/toolkit/install.sh --with-skill"
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

# 9-1. Optional: law-forms toolkit (법령 별지서식·법원 전산양식 hwpx 채우기)
if is_dry_run; then
  info_or_plan "법령·법원 서식 hwpx 채우기 toolkit(law-forms) 설치"
else
  echo ""
  echo "  - 자주 쓰는 서식(열람·등사 신청서, 초본 신청서 등)을 필드 이름만으로 채워 hwpx·PDF로 만듭니다."
  echo "  - 서재에 없는 법령 서식은 법제처에서 받아 kordoc으로 hwpx 변환 후 채웁니다(법제처 OC 필요)."
  echo ""
  read -r -p "law-forms를 설치할까요? [Y/n, 엔터=예] " ans
  if [[ ! "$ans" =~ ^[Nn]$ ]]; then
    bash "$TOOLKIT_DIR/toolkit/law-forms/install.sh" || warn "law-forms 설치 실패. 나중에 다시 시도하세요."
  else
    info "건너뛰기. 나중에 설치: bash $TOOLKIT_DIR/toolkit/law-forms/install.sh"
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
JURI_MCP_LINE=""

if ! is_dry_run; then
  JURI_MCP_LINE="$(claude mcp list 2>&1 | grep "^jurisupport:" || true)"
fi

if is_dry_run; then
  info_or_plan "JuriSupport MCP 입력창 등록 (토큰을 터미널·명령행에 넣지 않음)"
elif [[ "$JURI_MCP_LINE" == *"Connected"* ]] && claude mcp get jurisupport 2>/dev/null | grep -q "Scope: User"; then
  info "기존 JuriSupport MCP 연결 유지 (사용자 범위). 실제 사건 조회는 새 세션에서 확인하세요."
else
  echo ""
  echo "  - 가입 페이지: $JURI_SIGNUP_URL"
  echo "  - 토큰 발급:   $JURI_TOKEN_URL (가입 후)"
  prompt_read ans "JuriSupport 가입/MCP 연동을 진행할까요? [Y/n, 엔터=예] "
  if [[ "$ans" =~ ^[Nn]$ ]]; then
    info "건너뛰기. 나중에 credentials-setup.cmd 또는 입력창 도구의 jurisupport 항목을 사용하세요."
  else
    prompt_read has_token "이미 jurisupport.com 계정 + 토큰이 있으신가요? [y/N, 엔터=아니오] "
    if [[ ! "$has_token" =~ ^[Yy]$ ]]; then
      open_url "$JURI_SIGNUP_URL"
      info "브라우저에서 가입·로그인한 뒤 돌아오세요. 비밀번호를 이 터미널에 입력하지 마세요."
      prompt_read _ "가입 완료 후 엔터: "
      open_url "$JURI_TOKEN_URL"
      info "브라우저에서 토큰을 발급받으세요. 다음 입력창에만 붙여넣습니다."
      prompt_read _ "토큰 준비 완료 후 엔터: "
    fi
    if configure_credentials --service jurisupport; then
      info "JuriSupport 토큰 설정 저장 완료. 인증·실제 조회는 새 Claude 세션에서 확인하세요."
    else
      warn "JuriSupport 토큰 등록 미완료. 기존 설정은 그대로 두고 다른 설치를 계속합니다."
    fi
  fi
fi

# ============================================================
# Recommended: lawyer profile plugin + legal-terminal
# ============================================================
env_truthy() {
  case "${1:-}" in
    1|true|TRUE|yes|YES|y|Y|on|ON) return 0 ;;
    *) return 1 ;;
  esac
}

lawyer_profile_plugin_installed() {
  claude plugin list 2>/dev/null | grep -q 'jurisupport-lawyer-profile'
}

install_lawyer_profile_plugin() {
  if env_truthy "${JURISUPPORT_SKIP_LAWYER_PROFILE:-}"; then
    info "변호사 강점찾기 플러그인 추천 설치를 건너뜁니다."
    return
  fi

  if is_dry_run; then
    info_or_plan "변호사 강점찾기 플러그인 추천 설치"
    return
  fi

  if lawyer_profile_plugin_installed; then
    info "변호사 강점찾기 플러그인이 이미 설치된 것으로 보여 건너뜁니다."
    return
  fi

  echo ""
  echo "  - 변호사의 사건자료와 업무 이력을 바탕으로 개인 프로필/강점 카드를 준비하는 플러그인입니다."
  echo "  - 설치 후 /jurisupport-lawyer-profile:complete-personal-profile 로 시작합니다."
  prompt_read ans "변호사 강점찾기 플러그인을 설치할까요? [Y/n, 엔터=예] "
  if [[ "$ans" =~ ^[Nn]$ ]]; then
    info "건너뛰기. 나중에: curl -fsSL https://raw.githubusercontent.com/jurisupport/jurisupport-lawyer-profile-plugin/main/install.sh | bash"
    return
  fi

  curl -fsSL https://raw.githubusercontent.com/jurisupport/jurisupport-lawyer-profile-plugin/main/install.sh \
    | JURISUPPORT_LAWYER_PROFILE_SKIP_JURISUPPORT=1 JURISUPPORT_LAWYER_PROFILE_SKIP_LEGAL_TERMINAL=1 JURISUPPORT_CONNECT_MCP=0 bash
}

install_legal_terminal_app() {
  if env_truthy "${JURISUPPORT_SKIP_LEGAL_TERMINAL:-}"; then
    info "legal-terminal 추천 설치를 건너뜁니다."
    return
  fi

  if [[ "$PLATFORM" == "linux" ]]; then
    info "legal-terminal은 현재 macOS/Windows 배포만 있어 Linux에서는 추천 설치를 건너뜁니다."
    return
  fi

  if is_dry_run; then
    info_or_plan "legal-terminal 추천 설치"
    return
  fi

  echo ""
  echo "  - legal-terminal은 사건 폴더, 전자소송기록, 서면 에디터, Claude/Codex 작업 탭을 한 화면에 묶습니다."
  prompt_read ans "legal-terminal 앱을 설치할까요? [Y/n, 엔터=예] "
  if [[ "$ans" =~ ^[Nn]$ ]]; then
    info "건너뛰기. 나중에: https://github.com/jurisupport/legal-terminal/releases/latest"
    return
  fi

  case "$PLATFORM" in
    mac)
      curl -fsSL https://raw.githubusercontent.com/jurisupport/legal-terminal/main/install-mac.sh \
        | LEGAL_TERMINAL_INSTALL_JURI_SUPPORT=0 LEGAL_TERMINAL_INSTALL_LAWYER_PROFILE=0 bash
      ;;
    windows)
      powershell.exe -NoProfile -ExecutionPolicy Bypass -Command '$env:LEGAL_TERMINAL_INSTALL_JURI_SUPPORT="0"; $env:LEGAL_TERMINAL_INSTALL_LAWYER_PROFILE="0"; irm https://raw.githubusercontent.com/jurisupport/legal-terminal/main/install.ps1 | iex'
      ;;
  esac
}

legal_polish_installed() {
  claude plugin list 2>/dev/null | grep -q 'legal-polish-public'
}

install_legal_polish_plugin() {
  if env_truthy "${JURISUPPORT_SKIP_LEGAL_POLISH:-}"; then
    info "문서 다듬기 플러그인 추천 설치를 건너뜁니다."
    return
  fi

  if is_dry_run; then
    info_or_plan "문서 다듬기(legal-polish-public) 플러그인 추천 설치"
    return
  fi

  if legal_polish_installed; then
    info "문서 다듬기 플러그인이 이미 설치되어 있습니다."
    return
  fi

  echo ""
  echo "  - 이미 쓴 준비서면·답변서의 법리·사실·숫자는 그대로 두고 문장과 표현만 다듬는 플러그인입니다."
  prompt_read ans "문서 다듬기 플러그인을 설치할까요? [Y/n, 엔터=예] "
  if [[ "$ans" =~ ^[Nn]$ ]]; then
    info "건너뛰기. 나중에: claude plugin install legal-polish-public@jurisupport-plugins"
    return
  fi

  claude plugin install legal-polish-public@jurisupport-plugins \
    || warn "설치 실패. 수동: claude plugin install legal-polish-public@jurisupport-plugins"
}

# 전자소송 도구는 운영체제마다 다르다: Windows는 기록 자동 받기(ecourt-cli),
# macOS는 제출·송달 확인 스킬(ecfs-skill). 둘 다 전자소송 아이디와 인증서 암호를
# 내 컴퓨터에 암호화해 저장하므로 기본값은 '설치 안 함'이다.
ECFS_SKILL_DIR="$HOME/.claude/skills/ecfs"

ecourt_tool_installed() {
  case "$PLATFORM" in
    windows) [[ -f "$HOME/ecourt-cli/ecourt_download.py" && -f "$HOME/ecourt-cli/.venv/Scripts/python.exe" ]] ;;
    mac) [[ -f "$ECFS_SKILL_DIR/SKILL.md" ]] ;;
    *) return 1 ;;
  esac
}

install_ecourt_tools() {
  if env_truthy "${JURISUPPORT_SKIP_ECOURT:-}"; then
    info "전자소송 도구 설치를 건너뜁니다."
    return
  fi

  if [[ "$PLATFORM" != "windows" && "$PLATFORM" != "mac" ]]; then
    info "전자소송 도구는 Windows·macOS용만 있어 건너뜁니다."
    return
  fi

  if is_dry_run; then
    info_or_plan "(선택) 전자소송 도구 설치"
    return
  fi

  if ecourt_tool_installed; then
    info "전자소송 도구가 이미 설치되어 있습니다."
    if [[ "$PLATFORM" == windows ]]; then
      configure_credentials --service ecourt-cert --check >/dev/null 2>&1 || \
        configure_credentials --service ecourt-cert || warn "인증서 암호 등록 대기. 기존 도구 설치는 유지합니다."
    else
      configure_credentials --service ecfs-cert --check >/dev/null 2>&1 || \
        configure_credentials --service ecfs-cert || warn "인증서 암호 등록 대기. 기존 도구 설치는 유지합니다."
    fi
    return
  fi

  echo ""
  if [[ "$PLATFORM" == "windows" ]]; then
    echo "  - ecourt-cli: 매일 전자소송에 로그인해 진행중 사건의 새 기록을 사건 폴더로 받아 둡니다."
  else
    echo "  - ecfs-skill: Claude Code에서 전자소송 송달문서 확인, 서면 임시저장·제출, 소송비용 계산을 돕습니다."
  fi
  echo "  - 프로그램 설치 후 인증서 암호는 보호 입력창에서 암호화해 저장합니다. 실제 로그인·기록 수집은 실행하지 않습니다."
  prompt_read ans "전자소송 도구를 설치할까요? [y/N, 엔터=아니오] "
  if [[ ! "$ans" =~ ^[Yy]$ ]]; then
    if [[ "$PLATFORM" == "windows" ]]; then
      info "건너뛰기. 나중에: https://github.com/jurisupport/ecourt-cli"
    else
      info "건너뛰기. 나중에: https://github.com/jurisupport/ecfs-skill"
    fi
    return
  fi

  case "$PLATFORM" in
    windows)
      # The upstream setup_env.ps1 prompts for secrets; install only its runtime here.
      if (
        set -e
        local ecourt_root="$HOME/ecourt-cli" remote
        if [[ -d "$ecourt_root/.git" ]]; then
          remote="$(git -C "$ecourt_root" config --get remote.origin.url)"
          [[ "$remote" == https://github.com/jurisupport/ecourt-cli || "$remote" == https://github.com/jurisupport/ecourt-cli.git ]] || {
            warn "기존 ecourt-cli 저장소 출처를 확인하세요."; exit 1;
          }
          git -C "$ecourt_root" pull --ff-only || exit 1
        elif [[ -e "$ecourt_root" ]]; then
          warn "기존 ecourt-cli 폴더를 덮어쓰지 않습니다. 설치 상태를 확인하세요."; exit 1
        else
          git clone -c core.longpaths=true --depth 1 https://github.com/jurisupport/ecourt-cli.git "$ecourt_root" || exit 1
        fi
        source "$TOOLKIT_DIR/lib/python-detect.sh"
        select_python 3.10 || exit 1
        [[ -f "$ecourt_root/.venv/Scripts/python.exe" ]] || run_python -m venv "$ecourt_root/.venv" || exit 1
        "$ecourt_root/.venv/Scripts/python.exe" -m pip install -r "$ecourt_root/requirements.txt" || exit 1
        "$ecourt_root/.venv/Scripts/python.exe" -m playwright install msedge || exit 1
      ); then
        configure_credentials --service ecourt-cert --check >/dev/null 2>&1 || \
          configure_credentials --service ecourt-cert || warn "인증서 암호 등록 대기. 입력창에서 나중에 등록하세요."
        info "전자소송 아이디·인증서 경로 등 일반 설정은 별도 확인하세요. 로그인·자동 수집은 시작하지 않았습니다."
      else
        warn "ecourt-cli 설치 미완료. 안내: https://github.com/jurisupport/ecourt-cli"
      fi
      ;;
    mac)
      if [[ -d "$ECFS_SKILL_DIR/.git" ]]; then
        git -C "$ECFS_SKILL_DIR" pull --ff-only || warn "ecfs-skill 갱신 실패. 기존 버전으로 진행."
      else
        git clone --depth 1 https://github.com/jurisupport/ecfs-skill.git "$ECFS_SKILL_DIR" \
          || { warn "ecfs-skill 내려받기 실패. 안내: https://github.com/jurisupport/ecfs-skill"; return; }
      fi
      if (cd "$ECFS_SKILL_DIR" && bash install.sh </dev/null); then
        configure_credentials --service ecfs-cert --check >/dev/null 2>&1 || \
          configure_credentials --service ecfs-cert || warn "인증서 암호 등록 대기. 입력창에서 나중에 등록하세요."
        info "전자소송 일반 설정은 별도 확인하세요. 자동 실행 예약은 설정하지 않았습니다."
      else
        warn "ecfs-skill 설치 미완료. 암호를 터미널에 입력하지 말고 입력창 설정으로 이어가세요."
      fi
      ;;
  esac
}

legal_terminal_installed() {
  case "$PLATFORM" in
    mac) [[ -d "/Applications/legal-terminal.app" || -d "$HOME/Applications/legal-terminal.app" ]] ;;
    windows) [[ -n "${LOCALAPPDATA:-}" && -d "$(jurisupport_path "$LOCALAPPDATA")/Programs/legal-terminal" ]] ;;
    *) return 1 ;;
  esac
}

install_lawyer_profile_plugin
install_legal_terminal_app
install_legal_polish_plugin
install_ecourt_tools

# ============================================================
# Done
# ============================================================
# MARKETPLACE_PATH 미정의 시 fallback
MARKETPLACE_PATH="${MARKETPLACE_PATH:-$TOOLKIT_DIR}"

if is_dry_run; then
  JURI_MCP_STATUS="DRY-RUN: 등록 여부 확인 안 함"
else
  JURI_MCP_LINE="$(claude mcp list 2>&1 | grep "^jurisupport:" || true)"
  if [[ "$JURI_MCP_LINE" == *"Connected"* ]] && claude mcp get jurisupport 2>/dev/null | grep -q "Scope: User"; then
    JURI_MCP_STATUS="등록됨 (모든 폴더)"
  elif [[ "$JURI_MCP_LINE" == *"Connected"* ]]; then
    JURI_MCP_STATUS="이 폴더에서만 연결됨 - 입력창 도구에서 사용자 범위 연결을 준비하세요"
  elif [[ -n "$JURI_MCP_LINE" ]]; then
    JURI_MCP_STATUS="항목은 있으나 연결 확인 필요 - 토큰으로 재등록 권장"
  else
    JURI_MCP_STATUS="미등록 - 입력창 도구의 jurisupport 항목에서 등록"
  fi
fi

# 설치된 JuriSupport 도구를 한 화면에 모아 보여준다. 빠진 도구는 다시 설치기를 돌리면 이어서 설치된다.
tool_status_line() {
  local name="$1" state="$2" hint="$3"
  if [[ "$state" == ok ]]; then
    printf '  [설치됨]  %s\n' "$name"
  else
    printf '  [ 없음 ]  %s  -> %s\n' "$name" "$hint"
  fi
}

print_tool_status() {
  local plugins="" st
  plugins="$(claude plugin list 2>/dev/null || true)"
  echo "JuriSupport 도구 상태:"
  command -v claude >/dev/null 2>&1 && st=ok || st=no
  tool_status_line "Claude Code" "$st" "https://claude.com/claude-code"
  grep -q 'jurisupport@jurisupport-plugins' <<<"$plugins" && st=ok || st=no
  tool_status_line "JuriSupport 송무 플러그인" "$st" "claude plugin install jurisupport@jurisupport-plugins"
  [[ "$JURI_MCP_STATUS" == 등록됨* ]] && st=ok || st=no
  tool_status_line "JuriSupport 사건 연결 (모든 폴더)" "$st" "아래 MCP 안내 참고"
  legal_terminal_installed && st=ok || st=no
  tool_status_line "legal-terminal 앱" "$st" "https://github.com/jurisupport/legal-terminal"
  grep -q 'jurisupport-lawyer-profile' <<<"$plugins" && st=ok || st=no
  tool_status_line "변호사 강점찾기 플러그인" "$st" "https://github.com/jurisupport/jurisupport-lawyer-profile-plugin"
  grep -q 'legal-polish-public' <<<"$plugins" && st=ok || st=no
  tool_status_line "문서 다듬기 플러그인" "$st" "claude plugin install legal-polish-public@jurisupport-plugins"
  [[ -d "$HOME/legal-books" ]] && st=ok || st=no
  tool_status_line "법률서적 검색 (legal-books, 선택)" "$st" "https://github.com/jurisupport/legal-books"
  if [[ "$PLATFORM" == windows || "$PLATFORM" == mac ]]; then
    ecourt_tool_installed && st=ok || st=no
    tool_status_line "전자소송 도구 (선택)" "$st" "설치기 재실행 또는 https://github.com/jurisupport/$( [[ "$PLATFORM" == windows ]] && echo ecourt-cli || echo ecfs-skill )"
  fi
}

if is_dry_run; then
  TOOL_STATUS="JuriSupport 도구 상태: DRY-RUN이라 확인하지 않음"
else
  TOOL_STATUS="$(print_tool_status)"
fi

cat <<EOF

========================================
$(if is_dry_run; then printf '[ok] DRY-RUN 완료 (실제 변경 없음)'; else printf '[ok] 설치 완료'; fi)
========================================

$TOOL_STATUS

JuriSupport MCP: $JURI_MCP_STATUS
  credentials-setup.cmd 또는 scripts/configure_credentials.py --service jurisupport 입력창 사용

다음 단계:
  1. 필독: $TOOLKIT_DIR/guides/00_security.md (5분)
  2. 새 터미널에서 클로드코드 시작:
       claude
  3. JuriSupport 사건 연동을 쓸 경우 위 MCP 등록 상태 확인
  4. 시작 명령:
       "안녕. 설치된 스킬과 플러그인 보여줘."
  5. 첫 사건 설정: /jurisupport:cold-start-interview
  6. 첫 준비서면: /jurisupport:brief-protocol

플러그인 자동 설치 안 됐다면 (드물지만) 클로드코드 안에서 수동 실행:
       /plugin marketplace add "$MARKETPLACE_PATH"
       /plugin install jurisupport@jurisupport-plugins

korean-law MCP 설치·OC 설정을 이어가려면 korean-law-setup.cmd 또는 앱의 플러그인 화면 사용:
       /plugin marketplace add $KOREAN_LAW_MARKETPLACE_SOURCE
       /plugin install $KOREAN_LAW_PLUGIN_REF
       OC는 credentials-setup.cmd의 korean-law 입력창에서 등록
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
