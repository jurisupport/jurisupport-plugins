#!/usr/bin/env bash
# jurisupport-plugins 언인스톨러 (Mac/Linux/Windows Git Bash 공통)
#
# 본 패키지가 만든 등록·데이터를 단계별로 제거합니다.
# 시스템 패키지(Git, Node, Python 등)와 사용자 데이터(~/사건/)는
# 기본적으로 건드리지 않습니다.
#
# 사용:
#   ./uninstall.sh          # 대화식 (각 단계마다 Y/n 확인)
#   ./uninstall.sh --yes    # 모든 항목 자동 제거 (사용자 데이터는 여전히 보존)
#   ./uninstall.sh --dry-run # 무엇이 제거될지 미리보기만

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'
info()  { echo -e "${GREEN}[uninstall]${NC} $*"; }
warn()  { echo -e "${YELLOW}[uninstall]${NC} $*"; }
error() { echo -e "${RED}[uninstall]${NC} $*"; exit 1; }
step()  {
  echo ""
  echo -e "${CYAN}┌─ Step $1 ─────────────────────────────────${NC}"
  shift
  echo -e "${CYAN}│${NC} $*"
  echo -e "${CYAN}└──────────────────────────────────────────────${NC}"
}

AUTO_YES=false
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    --yes|-y)  AUTO_YES=true ;;
    --dry-run) DRY_RUN=true ;;
    --help|-h)
      grep '^#' "$0" | sed 's/^# \?//'; exit 0 ;;
  esac
done

ask() {
  local prompt="$1"
  if $AUTO_YES; then echo "  [auto-yes] $prompt"; return 0; fi
  read -r -p "  $prompt [y/N] " ans
  [[ "$ans" =~ ^[Yy]$ ]]
}

do_rm() {
  local target="$1"
  if [[ ! -e "$target" && ! -L "$target" ]]; then
    info "  · 없음 (건너뜀): $target"
    return
  fi
  if $DRY_RUN; then
    warn "  [dry-run] 제거 예정: $target"
  else
    rm -rf "$target"
    info "  ✓ 제거: $target"
  fi
}

# ============================================================
# Banner
# ============================================================
cat <<'BANNER'

╔════════════════════════════════════════════════════════════════╗
║   jurisupport-plugins 언인스톨러                                ║
║                                                                ║
║   본 스크립트가 제거하는 것:                                    ║
║     - 데이터 보호 Hook 등록                                     ║
║     - JuriSupport / korean-law 플러그인 등록                   ║
║     - 설치된 클로드코드 스킬 (lbox-guide, beopgoeul-search 등)  ║
║     - toolkit 데이터 폴더 (~/legal-books, ~/case-records 등)    ║
║                                                                ║
║   제거하지 않는 것 (기본):                                      ║
║     - ~/사건/ 폴더 (사용자 사건 자료)                            ║
║     - ~/.jurisupport/secrets.env (Gemini API 키)               ║
║     - Claude Code 자체 (npm 글로벌)                             ║
║     - 시스템 패키지 (Git, Node, Python, Chrome 등)              ║
║                                                                ║
║   ⚠ Windows 시스템 패키지·Claude Code 제거는                    ║
║     windows-uninstall.ps1 별도 실행                            ║
║                                                                ║
║   계속: Enter   취소: Ctrl+C                                    ║
╚════════════════════════════════════════════════════════════════╝

BANNER
$AUTO_YES || read -r -p "" _

OS="$(uname -s)"
case "$OS" in
  Darwin*)              PLATFORM="mac" ;;
  Linux*)               PLATFORM="linux" ;;
  MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
  *) error "지원하지 않는 OS: $OS" ;;
esac
info "플랫폼: $PLATFORM"
$DRY_RUN && warn "*** DRY-RUN 모드 (실제로 제거하지 않음) ***"

# ============================================================
# Step 1. Hook 등록 해제
# ============================================================
step 1 "데이터 보호 Hook 등록 해제"

SETTINGS="$HOME/.claude/settings.json"
if [[ -f "$SETTINGS" ]] && grep -q "pretool_data_protection.sh" "$SETTINGS"; then
  if ask "settings.json에서 본 패키지 Hook 항목을 제거할까요?"; then
    if command -v jq >/dev/null 2>&1; then
      if $DRY_RUN; then
        warn "  [dry-run] settings.json에서 Hook 항목 제거 예정"
      else
        TMP=$(mktemp)
        jq '.hooks.PreToolUse = ((.hooks.PreToolUse // []) | map(select(
          (.hooks // []) | map(.command // "") | any(test("pretool_data_protection")) | not
        )))' "$SETTINGS" > "$TMP"
        # 빈 배열이 되면 키 자체 삭제
        jq 'if (.hooks.PreToolUse | length) == 0 then del(.hooks.PreToolUse) else . end | if (.hooks | length // 0) == 0 then del(.hooks) else . end' "$TMP" > "$SETTINGS"
        rm -f "$TMP"
        info "  ✓ Hook 등록 해제 완료"
      fi
    else
      warn "  jq 없음 → 수동으로 $SETTINGS 편집 필요"
    fi
  else
    info "  · 건너뜀"
  fi
else
  info "  · 등록된 Hook 없음"
fi

# ============================================================
# Step 2. JuriSupport/korean-law 플러그인·marketplace 등록 해제 (Claude Code CLI)
# ============================================================
step 2 "JuriSupport/korean-law 플러그인·marketplace 등록 해제"

if ! command -v claude >/dev/null 2>&1; then
  warn "claude CLI 없음 → 플러그인 등록 해제 건너뜀"
else
  # 1) JuriSupport plugin uninstall. Also remove the legacy songmu-legal ID.
  for PLUGIN_NAME in jurisupport songmu-legal; do
    if claude plugin list 2>/dev/null | grep -q "$PLUGIN_NAME"; then
      if ask "$PLUGIN_NAME 플러그인을 제거할까요?"; then
        if $DRY_RUN; then
          warn "  [dry-run] claude plugin uninstall $PLUGIN_NAME"
        else
          claude plugin uninstall "$PLUGIN_NAME" 2>&1 | tail -3 || warn "  플러그인 제거 실패. 수동: claude plugin uninstall $PLUGIN_NAME"
          info "  ✓ $PLUGIN_NAME 제거"
        fi
      fi
    else
      info "  · 등록된 $PLUGIN_NAME 플러그인 없음"
    fi
  done

  # 1-B) korean-law 플러그인 uninstall
  if claude plugin list 2>/dev/null | grep -q "korean-law@"; then
    if ask "korean-law 플러그인을 제거할까요?"; then
      if $DRY_RUN; then
        warn "  [dry-run] claude plugin uninstall korean-law"
      else
        claude plugin uninstall korean-law 2>&1 | tail -3 || warn "  플러그인 제거 실패. 수동: claude plugin uninstall korean-law"
        info "  ✓ korean-law 제거"
      fi
    fi
  else
    info "  · 등록된 korean-law 플러그인 없음"
  fi

  # 2-A) marketplace remove
  if claude plugin marketplace list 2>/dev/null | grep -q "jurisupport-plugins"; then
    if ask "marketplace 'jurisupport-plugins' 등록도 제거할까요?"; then
      if $DRY_RUN; then
        warn "  [dry-run] claude plugin marketplace remove jurisupport-plugins"
      else
        claude plugin marketplace remove jurisupport-plugins 2>&1 | tail -3 || warn "  marketplace 제거 실패."
        info "  ✓ marketplace 제거"
      fi
    fi
  else
    info "  · 등록된 jurisupport-plugins marketplace 없음"
  fi

  # 2-B) korean-law marketplace remove
  if claude plugin marketplace list 2>/dev/null | grep -q "korean-law-marketplace"; then
    if ask "marketplace 'korean-law-marketplace' 등록도 제거할까요?"; then
      if $DRY_RUN; then
        warn "  [dry-run] claude plugin marketplace remove korean-law-marketplace"
      else
        claude plugin marketplace remove korean-law-marketplace 2>&1 | tail -3 || warn "  marketplace 제거 실패."
        info "  ✓ korean-law marketplace 제거"
      fi
    fi
  else
    info "  · 등록된 korean-law marketplace 없음"
  fi
fi

# 옛 cache 심볼릭 링크가 남아있으면 정리 (구버전 install.sh로 깔린 흔적)
PLUGIN_CACHE_PARENT="$HOME/.claude/plugins/cache/jurisupport-plugins"
for PLUGIN_CACHE_NAME in jurisupport songmu-legal; do
  PLUGIN_CACHE_DIR="$PLUGIN_CACHE_PARENT/$PLUGIN_CACHE_NAME"
  if [[ -L "$PLUGIN_CACHE_DIR" || -e "$PLUGIN_CACHE_DIR" ]]; then
    info "  cache 잔여 정리: $PLUGIN_CACHE_DIR"
    do_rm "$PLUGIN_CACHE_DIR"
  fi
done
if [[ -d "$PLUGIN_CACHE_PARENT" ]] && [[ -z "$(ls -A "$PLUGIN_CACHE_PARENT" 2>/dev/null)" ]]; then
  do_rm "$PLUGIN_CACHE_PARENT"
fi

# ============================================================
# Step 3. 클로드코드 스킬 제거
# ============================================================
step 3 "클로드코드 스킬 제거"

for SKILL in lbox-guide beopgoeul-search court-forms legal-books case-records beopgoeul-guide; do
  SKILL_DIR="$HOME/.claude/skills/$SKILL"
  if [[ -d "$SKILL_DIR" ]]; then
    if ask "스킬 제거: $SKILL"; then
      do_rm "$SKILL_DIR"
    fi
  fi
done
for COMMAND in beopgoeul-search court-forms beopgoeul-guide; do
  COMMAND_FILE="$HOME/.claude/commands/$COMMAND.md"
  if [[ -f "$COMMAND_FILE" ]]; then
    if ask "클로드코드 명령 제거: /$COMMAND"; then
      do_rm "$COMMAND_FILE"
    fi
  fi
done

# ============================================================
# Step 4. legal-books toolkit (서버 stop + 폴더 제거)
# ============================================================
step 4 "legal-books toolkit 제거 (책 DB 포함)"

if [[ -d "$HOME/legal-books" ]]; then
  warn "  ⚠ ~/legal-books 안에 책 스캔 데이터·임베딩 DB가 있습니다."
  warn "    제거 후 책 다시 스캔·임베딩하려면 시간이 다시 듭니다."
  if ask "~/legal-books/ 전체를 제거할까요?"; then
    # 서버 stop 먼저
    if [[ "$PLATFORM" == "windows" ]] && [[ -f "$HOME/legal-books/scripts/server.ps1" ]]; then
      powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$HOME/legal-books/scripts/server.ps1")" stop 2>/dev/null || true
    elif [[ -f "$HOME/legal-books/scripts/server.sh" ]]; then
      bash "$HOME/legal-books/scripts/server.sh" stop 2>/dev/null || true
    fi
    do_rm "$HOME/legal-books"
  fi
else
  info "  · 없음"
fi

# ============================================================
# Step 5. case-records toolkit
# ============================================================
step 5 "case-records toolkit 제거 (사건 인덱싱 DB 포함)"

if [[ -d "$HOME/case-records" ]]; then
  warn "  ⚠ ~/case-records 안에 사건 인덱싱 데이터가 있습니다."
  if ask "~/case-records/ 전체를 제거할까요?"; then
    if [[ "$PLATFORM" == "windows" ]] && [[ -f "$HOME/case-records/scripts/server.ps1" ]]; then
      powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$(cygpath -w "$HOME/case-records/scripts/server.ps1")" stop 2>/dev/null || true
    elif [[ -f "$HOME/case-records/scripts/server.sh" ]]; then
      bash "$HOME/case-records/scripts/server.sh" stop 2>/dev/null || true
    fi
    do_rm "$HOME/case-records"
  fi
else
  info "  · 없음"
fi

# ============================================================
# Step 6. court-forms toolkit
# ============================================================
step 6 "court-forms toolkit 제거 (법원 양식 DB 포함)"

if [[ -d "$HOME/court-forms" ]]; then
  warn "  ⚠ ~/court-forms 안에 법원 양식 메타DB와 다운로드 캐시가 있습니다."
  if ask "~/court-forms/ 전체를 제거할까요?"; then
    do_rm "$HOME/court-forms"
  fi
else
  info "  · 없음"
fi

# ============================================================
# Step 7. beopgoeul toolkit
# ============================================================
step 7 "beopgoeul-search toolkit 제거"

if [[ -d "$HOME/jurisupport-beopgoeul" ]]; then
  if ask "~/jurisupport-beopgoeul/ 전체를 제거할까요?"; then
    do_rm "$HOME/jurisupport-beopgoeul"
  fi
else
  info "  · 없음"
fi

# ============================================================
# Step 8. CSV 템플릿 (사용자 데이터일 수 있음)
# ============================================================
step 8 "사건정보 관리표 CSV (사용자 데이터 가능성)"

CSV="$HOME/사건/_사건정보관리표.csv"
CSV_GUIDE="$HOME/사건/_입력가이드.md"
if [[ -f "$CSV" ]] || [[ -f "$CSV_GUIDE" ]]; then
  warn "  ⚠ ~/사건/_사건정보관리표.csv 는 사용자가 직접 채워넣는 파일입니다."
  warn "    내용을 확인 후 제거 여부 결정하세요."
  if ask "_사건정보관리표.csv / _입력가이드.md 를 제거할까요?"; then
    [[ -f "$CSV" ]]       && do_rm "$CSV"
    [[ -f "$CSV_GUIDE" ]] && do_rm "$CSV_GUIDE"
  fi
else
  info "  · 없음"
fi

# ============================================================
# Step 9. Gemini API 키 (사용자 자격증명)
# ============================================================
step 9 "Gemini API 키 (~/.jurisupport/secrets.env)"

SECRETS="$HOME/.jurisupport/secrets.env"
if [[ -f "$SECRETS" ]]; then
  warn "  ⚠ Gemini API 키는 본 패키지 재설치 시에도 재사용됩니다."
  if ask "API 키 파일 ($SECRETS)을 제거할까요?"; then
    do_rm "$SECRETS"
    # 부모 폴더가 비면 정리
    if [[ -d "$HOME/.jurisupport" ]] && [[ -z "$(ls -A "$HOME/.jurisupport" 2>/dev/null)" ]]; then
      do_rm "$HOME/.jurisupport"
    fi
  fi
else
  info "  · 없음"
fi

# ============================================================
# Step 10. JuriSupport MCP 등록 해제
# ============================================================
step 10 "JuriSupport MCP 등록 해제"

if ! command -v claude >/dev/null 2>&1; then
  warn "claude CLI 없음 → MCP 제거 건너뜀"
elif claude mcp list 2>&1 | grep -q "^jurisupport:"; then
  warn "  ⚠ JuriSupport 토큰은 본 명령 후에도 jurisupport.com 계정에 남아있습니다."
  warn "  토큰 자체 무효화는 https://jurisupport.com/profile 에서 별도 진행."
  if ask "JuriSupport MCP 등록을 클로드코드에서 제거할까요?"; then
    if $DRY_RUN; then
      warn "  [dry-run] claude mcp remove jurisupport"
    else
      claude mcp remove jurisupport 2>&1 | tail -3 || warn "  MCP 제거 실패. 수동: claude mcp remove jurisupport"
      info "  ✓ JuriSupport MCP 등록 해제"
    fi
  fi
else
  info "  · 등록된 JuriSupport MCP 없음"
fi

# ============================================================
# Done
# ============================================================
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ 본 패키지 등록·데이터 제거 완료${NC}"
echo -e "${GREEN}========================================${NC}"

cat <<EOF

남아 있는 것 (의도적으로 보존):
  - ~/사건/ 폴더 (사용자 사건 자료)
  - 본 레포 자체 (~/jurisupport-plugins/) — 다시 install 가능
  - 클라우드 측 JuriSupport 계정·데이터 (jurisupport.com 직접 관리)

추가로 제거하려면:

  본 레포 폴더:
    rm -rf ~/jurisupport-plugins

  Claude Code 자체 (npm 글로벌):
    npm uninstall -g @anthropic-ai/claude-code

  [Mac] 시스템 패키지 (brew):
    brew uninstall jq ocrmypdf tesseract tesseract-lang
    brew uninstall --cask google-chrome
    # Node·Python은 다른 용도로도 쓰면 보존:
    #   brew uninstall node python@3.12

  [Linux] 시스템 패키지 (apt):
    sudo apt remove jq ocrmypdf tesseract-ocr tesseract-ocr-kor
    sudo apt remove google-chrome-stable
    # Node·Python은 보존 권장

  [Windows] 시스템 패키지:
    PowerShell에서 windows-uninstall.ps1 실행
    또는 winget uninstall <패키지>

EOF
