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
║   jurisupport-plugins installer                              ║
║   변호사용 클로드코드 통합 패키지 설치                          ║
║                                                                ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║   ⚠️ 설치 전 반드시 읽어야 할 문서:                            ║
║      guides/00_security.md (의뢰인 정보 보호 원칙)             ║
║                                                                ║
║   설치를 계속하시려면 Enter, 취소하려면 Ctrl+C.                ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

BANNER
read -r -p "" _

OS="$(uname -s)"
case "$OS" in
  Darwin*) PLATFORM="mac" ;;
  Linux*)  PLATFORM="linux" ;;
  *) error "Unsupported OS: $OS. Mac/Linux only. Windows: use WSL2." ;;
esac

TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
info "Toolkit directory: $TOOLKIT_DIR"
info "Platform: $PLATFORM"

# ============================================================
# 1. Prerequisites
# ============================================================
step "1. Checking prerequisites"

command -v claude >/dev/null || error "Claude Code (CLI) not installed. See https://docs.claude.com/claude-code"
command -v git >/dev/null || error "git required"

# jq is required for hook registration — try auto-install
if ! command -v jq >/dev/null 2>&1; then
  warn "jq not installed (required for data protection hook)"
  if [[ "$PLATFORM" == "mac" ]]; then
    if command -v brew >/dev/null 2>&1; then
      info "Auto-installing jq via Homebrew..."
      brew install jq >/dev/null 2>&1 && info "✓ jq installed" || error "jq install failed. Run manually: brew install jq"
    else
      error "Homebrew not installed. Install from https://brew.sh first, then re-run."
    fi
  else
    if command -v apt-get >/dev/null 2>&1; then
      info "Auto-installing jq via apt..."
      sudo apt-get install -y jq >/dev/null 2>&1 && info "✓ jq installed" || error "jq install failed. Run manually: sudo apt install jq"
    else
      error "Please install jq for your distro and re-run."
    fi
  fi
fi

# ============================================================
# 2. Data protection hook (always installed)
# ============================================================
step "2. Installing data protection hook"

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
  info "Hook registered in $SETTINGS"
else
  info "Hook already registered"
fi

# ============================================================
# 3. songmu-legal plugin (same repo — register only)
# ============================================================
step "3. Registering songmu-legal plugin"

SONGMU_LOCAL="$TOOLKIT_DIR/plugins/songmu-legal"
SONGMU_DST="$HOME/.claude/plugins/cache/jurisupport-plugins/songmu-legal"

if [[ ! -f "$SONGMU_LOCAL/.claude-plugin/plugin.json" ]]; then
  warn "songmu-legal plugin not found at $SONGMU_LOCAL"
  echo "  Did you clone the full repo? Run:"
  echo "    git clone https://github.com/jurisupport/jurisupport-plugins.git"
else
  mkdir -p "$(dirname "$SONGMU_DST")"
  if [[ -L "$SONGMU_DST" || -e "$SONGMU_DST" ]]; then
    info "songmu-legal already registered"
  else
    ln -s "$SONGMU_LOCAL" "$SONGMU_DST"
    info "songmu-legal registered"
  fi

  # Bootstrap CLAUDE.md from CLAUDE.md.example if missing
  if [[ ! -f "$SONGMU_LOCAL/CLAUDE.md" ]] && [[ -f "$SONGMU_LOCAL/CLAUDE.md.example" ]]; then
    cp "$SONGMU_LOCAL/CLAUDE.md.example" "$SONGMU_LOCAL/CLAUDE.md"
    info "Created $SONGMU_LOCAL/CLAUDE.md from template"
    info "→ Run '/songmu-legal:cold-start-interview' in Claude Code to fill it"
  fi
fi

# ============================================================
# 4. Skills (lbox-guide always; beopgoeul-search if toolkit installed later)
# ============================================================
step "4. Installing guide skills"

SKILLS_DST="$HOME/.claude/skills"
mkdir -p "$SKILLS_DST"

# Always-on: lbox-guide (manual, no automation)
for SKILL in lbox-guide; do
  mkdir -p "$SKILLS_DST/$SKILL"
  cp "$TOOLKIT_DIR/skills/$SKILL/SKILL.md" "$SKILLS_DST/$SKILL/SKILL.md"
  info "Installed skill: $SKILL"
done
# beopgoeul-search is installed conditionally below (Step 8)

# ============================================================
# 5. CSV template
# ============================================================
step "5. Setting up case info CSV template"

if [[ ! -d "$HOME/사건" ]]; then
  read -r -p "Create ~/사건 directory and copy CSV template? [Y/n] " ans
  if [[ "$ans" =~ ^[Nn]$ ]]; then
    info "Skipped. You can run: mkdir -p ~/사건 && cp $TOOLKIT_DIR/templates/사건정보_관리표.csv ~/사건/"
  else
    mkdir -p "$HOME/사건"
    cp "$TOOLKIT_DIR/templates/사건정보_관리표.csv" "$HOME/사건/_사건정보관리표.csv"
    cp "$TOOLKIT_DIR/templates/사건정보_입력가이드.md" "$HOME/사건/_입력가이드.md"
    info "Templates copied to ~/사건/"
  fi
else
  info "~/사건 already exists. Templates available at $TOOLKIT_DIR/templates/"
fi

# ============================================================
# 6. Optional: legal-books toolkit
# ============================================================
step "6. (Optional) legal-books search server"

read -r -p "Install legal-books search server now? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  bash "$TOOLKIT_DIR/toolkit/legal-books/install.sh"
else
  info "Skipped. Run later: bash $TOOLKIT_DIR/toolkit/legal-books/install.sh"
fi

# ============================================================
# 7. Optional: case-records toolkit
# ============================================================
step "7. (Optional) case-records search server"

read -r -p "Install case-records search server now? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  bash "$TOOLKIT_DIR/toolkit/case-records/install.sh"
else
  info "Skipped. Run later: bash $TOOLKIT_DIR/toolkit/case-records/install.sh"
fi

# ============================================================
# 8. Optional: beopgoeul (법고을) auto-search toolkit
# ============================================================
step "8. (Optional) 법고을 (lx.scourt.go.kr) auto-search via Selenium"

read -r -p "Install 법고을 auto-search toolkit? [y/N] " ans
if [[ "$ans" =~ ^[Yy]$ ]]; then
  bash "$TOOLKIT_DIR/toolkit/beopgoeul/install.sh"
else
  info "Skipped. Without this, beopgoeul-search skill will be unavailable."
  info "Use lbox-guide skill (manual search) as fallback."
  info "Install later: bash $TOOLKIT_DIR/toolkit/beopgoeul/install.sh"
fi

# ============================================================
# Done
# ============================================================
cat <<EOF

${GREEN}========================================
✓ jurisupport-plugins installation complete.
========================================${NC}

Next steps:
  1. Read: $TOOLKIT_DIR/guides/00_security.md (5 min)
  2. Open a new Claude Code session in any directory:
       claude
  3. Try: "안녕. 설치된 스킬과 플러그인 보여줘."
  4. First real case: /songmu-legal:cold-start-interview
  5. First brief: /songmu-legal:brief-protocol

Full guide: $TOOLKIT_DIR/README.md

EOF
