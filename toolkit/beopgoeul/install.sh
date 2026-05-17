#!/usr/bin/env bash
# 법고을 (lx.scourt.go.kr) 자동 검색 toolkit installer (Mac/Linux)
#
# Sets up:
# - ~/jurisupport-beopgoeul/ directory
# - Python venv with Selenium
# - Search wrapper script
# - Claude Code skill: beopgoeul-search (replaces beopgoeul-guide)

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'
info()  { echo -e "${GREEN}[info]${NC} $*"; }
warn()  { echo -e "${YELLOW}[warn]${NC} $*"; }
error() { echo -e "${RED}[error]${NC} $*"; exit 1; }

OS="$(uname -s)"
case "$OS" in
  Darwin*) PLATFORM="mac" ;;
  Linux*)  PLATFORM="linux" ;;
  *) error "Unsupported OS: $OS (Mac/Linux only)" ;;
esac

# ============================================================
# Check Chrome installed (Selenium needs it)
# ============================================================
info "Chrome 확인 중 / Checking Chrome installation..."
if [[ "$PLATFORM" == "mac" ]]; then
  if [[ ! -d "/Applications/Google Chrome.app" ]]; then
    warn "Google Chrome이 없습니다. 다음에서 다운로드 / Not found. Download from:"
    echo "  https://www.google.com/chrome/"
    error "Chrome 설치 후 다시 실행 / Install Chrome and re-run."
  fi
else
  if ! command -v google-chrome >/dev/null && ! command -v chromium >/dev/null; then
    warn "Chrome/Chromium 미설치 / not installed."
    read -r -p "지금 자동 설치할까요? / Install Google Chrome now via apt? [Y/n]: " ans
    if [[ ! "$ans" =~ ^[Nn]$ ]]; then
      info "Chrome 자동 설치 중 / Installing Chrome..."
      wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/google.gpg
      echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google.list >/dev/null
      sudo apt-get update -q
      sudo apt-get install -y google-chrome-stable
      if command -v google-chrome >/dev/null; then
        info "✓ Chrome 설치 완료 / installed: $(google-chrome --version)"
      else
        error "Chrome 설치 실패 / install failed. 수동 설치 후 다시 실행 / Install manually and re-run."
      fi
    else
      error "Chrome 없이는 beopgoeul-search toolkit 사용 불가 / Cannot install toolkit without Chrome."
    fi
  fi
fi
info "✓ Chrome 확인됨 / found"

# ============================================================
# Python version
# ============================================================
PYV=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYMAJ=$(echo "$PYV" | cut -d. -f1)
PYMIN=$(echo "$PYV" | cut -d. -f2)
if [[ "$PYMAJ" -lt 3 ]] || [[ "$PYMAJ" -eq 3 && "$PYMIN" -lt 9 ]]; then
  error "Python 3.9+ required (found $PYV)"
fi

# ============================================================
# Install
# ============================================================
ROOT="$HOME/jurisupport-beopgoeul"
info "Installing to $ROOT"
mkdir -p "$ROOT/scripts"

python3 -m venv "$ROOT/.venv"
# shellcheck disable=SC1091
source "$ROOT/.venv/bin/activate"
pip install --quiet --upgrade pip
pip install --quiet selenium==4.25.0
info "Selenium installed"

# Copy search script
TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cp "$TOOLKIT_DIR/scripts/search.py" "$ROOT/scripts/search.py"

# Create wrapper sh for easy CLI use
cat > "$ROOT/scripts/search.sh" <<'WRAP'
#!/usr/bin/env bash
# Wrapper: activate venv and run search.py
ROOT="$HOME/jurisupport-beopgoeul"
# shellcheck disable=SC1090
source "$ROOT/.venv/bin/activate"
exec python3 "$ROOT/scripts/search.py" "$@"
WRAP
chmod +x "$ROOT/scripts/search.sh"

# ============================================================
# Install Claude Code skill (replaces beopgoeul-guide)
# ============================================================
SKILL_DST="$HOME/.claude/skills/beopgoeul-search"
mkdir -p "$SKILL_DST"
cp "$TOOLKIT_DIR/../../skills/beopgoeul-search/SKILL.md" "$SKILL_DST/SKILL.md"

# Remove old beopgoeul-guide if exists (replaced by beopgoeul-search)
if [[ -d "$HOME/.claude/skills/beopgoeul-guide" ]]; then
  rm -rf "$HOME/.claude/skills/beopgoeul-guide"
  info "Removed old beopgoeul-guide skill (replaced by beopgoeul-search)"
fi

# ============================================================
# Smoke test
# ============================================================
info "Smoke test..."
if "$ROOT/scripts/search.sh" "민법 제162조" --max 1 >/dev/null 2>&1; then
  info "✓ Smoke test passed"
else
  warn "Smoke test failed. Try manually: $ROOT/scripts/search.sh '키워드'"
fi

cat <<EOF

${GREEN}========================================
법고을 자동 검색 toolkit installed.
========================================${NC}

CLI usage:
  ~/jurisupport-beopgoeul/scripts/search.sh "소멸시효 채무승인"
  ~/jurisupport-beopgoeul/scripts/search.sh "2024다302217" --max 1
  ~/jurisupport-beopgoeul/scripts/search.sh "민법 750조" --format json

In Claude Code (skill: beopgoeul-search):
  "법고을에서 시효 완성 후 채무승인 판결 찾아줘"
  → 클로드가 자동으로 search.sh 호출, 결과 정리

⚠ 양심적 사용 권장: 정부 사이트 부하 줄이기 위해 결과 캐싱·반복 호출 자제.

EOF
