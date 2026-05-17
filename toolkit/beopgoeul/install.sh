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
  *) error "지원하지 않는 OS: $OS (macOS/Linux만 지원)" ;;
esac

# ============================================================
# Check Chrome installed (Selenium needs it)
# ============================================================
info "Chrome 확인 중..."
if [[ "$PLATFORM" == "mac" ]]; then
  if [[ ! -d "/Applications/Google Chrome.app" ]]; then
    if command -v brew >/dev/null 2>&1; then
      info "Chrome 자동 설치 중 (Homebrew cask)..."
      brew install --cask google-chrome 2>&1 | tail -3
      if [[ -d "/Applications/Google Chrome.app" ]]; then
        info "✓ Chrome 설치 완료"
      else
        warn "Chrome 자동 설치 실패"
        echo "  수동 다운로드: https://www.google.com/chrome/"
        error "Chrome 설치 후 다시 실행하세요."
      fi
    else
      warn "Homebrew 없음 — Chrome 수동 설치 필요:"
      echo "  https://www.google.com/chrome/"
      error "Chrome 설치 후 다시 실행하세요."
    fi
  fi
else
  if ! command -v google-chrome >/dev/null && ! command -v chromium >/dev/null; then
    info "Chrome 자동 설치 중 (apt + Google 저장소)..."
    # Google 서명키 + 저장소
    if [[ ! -f /etc/apt/trusted.gpg.d/google.gpg ]]; then
      wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/google.gpg
    fi
    if [[ ! -f /etc/apt/sources.list.d/google.list ]]; then
      echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google.list >/dev/null
    fi
    sudo apt-get update -q
    sudo apt-get install -y google-chrome-stable
    if command -v google-chrome >/dev/null; then
      info "✓ Chrome 설치 완료: $(google-chrome --version 2>&1 | head -1)"
    else
      warn "google-chrome-stable 설치 실패 → chromium-browser 시도..."
      sudo apt-get install -y chromium-browser 2>&1 | tail -3
      if command -v chromium-browser >/dev/null || command -v chromium >/dev/null; then
        info "✓ Chromium 설치 완료"
      else
        error "Chrome/Chromium 설치 실패. 수동 설치 후 다시 실행하세요."
      fi
    fi
  fi
fi
info "✓ Chrome 확인됨"

# ============================================================
# Python venv 패키지 확인 (Ubuntu/Debian은 python3-venv 별도 필요)
# ============================================================
if [[ "$PLATFORM" == "linux" ]]; then
  # python3-venv가 없으면 venv 생성 실패. 자동 설치.
  if ! python3 -c "import ensurepip" 2>/dev/null; then
    info "python3-venv 자동 설치 중..."
    # python3.XX-venv 또는 일반 python3-venv 시도
    PYV=$(python3 -c 'import sys; print(f"python3.{sys.version_info.minor}-venv")')
    sudo apt-get install -y "$PYV" python3-venv 2>&1 | tail -3 || \
      sudo apt-get install -y python3-venv 2>&1 | tail -3
    if ! python3 -c "import ensurepip" 2>/dev/null; then
      error "python3-venv 설치 실패. 수동 설치 후 다시 실행: sudo apt install python3-venv"
    fi
    info "✓ python3-venv 설치 완료"
  fi
fi

# ============================================================
# Python version
# ============================================================
PYV=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYMAJ=$(echo "$PYV" | cut -d. -f1)
PYMIN=$(echo "$PYV" | cut -d. -f2)
if [[ "$PYMAJ" -lt 3 ]] || [[ "$PYMAJ" -eq 3 && "$PYMIN" -lt 9 ]]; then
  error "Python 3.9 이상 필요 (현재 $PYV)"
fi

# ============================================================
# Install
# ============================================================
ROOT="$HOME/jurisupport-beopgoeul"
info "설치 위치: $ROOT"
mkdir -p "$ROOT/scripts"

python3 -m venv "$ROOT/.venv"
# shellcheck disable=SC1091
source "$ROOT/.venv/bin/activate"
pip install --quiet --upgrade pip
pip install --quiet selenium==4.25.0
info "Selenium 설치 완료"

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
  info "옛 beopgoeul-guide 스킬 제거 (beopgoeul-search로 교체됨)"
fi

# ============================================================
# Smoke test
# ============================================================
info "작동 확인 중..."
if "$ROOT/scripts/search.sh" "민법 제162조" --max 1 >/dev/null 2>&1; then
  info "✓ 작동 확인 완료"
else
  warn "작동 확인 실패. 수동 시도: $ROOT/scripts/search.sh '키워드'"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}법고을 자동 검색 toolkit 설치 완료${NC}"
echo -e "${GREEN}========================================${NC}"
cat <<EOF

CLI 사용법:
  ~/jurisupport-beopgoeul/scripts/search.sh "소멸시효 채무승인"
  ~/jurisupport-beopgoeul/scripts/search.sh "2024다302217" --max 1
  ~/jurisupport-beopgoeul/scripts/search.sh "민법 750조" --format json

클로드코드에서 (스킬: beopgoeul-search):
  "법고을에서 시효 완성 후 채무승인 판결 찾아줘"
  → 클로드가 자동으로 search.sh 호출, 결과 정리

⚠ 양심적 사용 권장: 정부 사이트 부하 줄이기 위해 결과 캐싱·반복 호출 자제.

EOF
