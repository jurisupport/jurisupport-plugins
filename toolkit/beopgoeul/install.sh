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

# Windows 경로(C:\...)를 Git Bash에서 쓸 수 있는 POSIX(/c/...)로 변환
to_posix() {
  if command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$1" 2>/dev/null || echo "$1"
  else
    echo "$1"
  fi
}

# Python 명령 결정 (Windows: py launcher → cygpath로 POSIX 변환)
if [[ "$PLATFORM" == "windows" ]]; then
  if command -v py >/dev/null 2>&1 && py -3.12 --version >/dev/null 2>&1; then
    PY="$(to_posix "$(py -3.12 -c 'import sys; print(sys.executable)' 2>/dev/null)")"
    info "Python 3.12: $PY"
  elif command -v py >/dev/null 2>&1 && py -3.11 --version >/dev/null 2>&1; then
    PY="$(to_posix "$(py -3.11 -c 'import sys; print(sys.executable)' 2>/dev/null)")"
    info "Python 3.11: $PY (3.12 권장)"
  else
    PY="$(command -v python3 2>/dev/null || command -v python 2>/dev/null)"
    [[ -z "$PY" ]] && error "Python 미설치. PowerShell: winget install Python.Python.3.12"
    info "Python 경로: $PY ($("$PY" --version 2>&1))"
  fi
  VENV_ACTIVATE="Scripts/activate"
else
  PY="python3"
  VENV_ACTIVATE="bin/activate"
fi

# ============================================================
# Check Chrome installed (Selenium needs it)
# ============================================================
info_or_plan "Chrome 확인 중..."
if [[ "$PLATFORM" == "windows" ]]; then
  # Windows: Chrome은 windows-bootstrap.ps1이 winget으로 설치했음. 레지스트리/기본 경로 확인
  CHROME_PATHS=(
    "$PROGRAMFILES/Google/Chrome/Application/chrome.exe"
    "${PROGRAMFILES_X86:-/c/Program Files (x86)}/Google/Chrome/Application/chrome.exe"
    "$LOCALAPPDATA/Google/Chrome/Application/chrome.exe"
  )
  CHROME_FOUND=""
  for p in "${CHROME_PATHS[@]}"; do
    [[ -f "$p" ]] && CHROME_FOUND="$p" && break
  done
  if [[ -z "$CHROME_FOUND" ]]; then
    warn "Chrome을 찾지 못했습니다."
    if ! is_dry_run; then
      error "PowerShell에서 'winget install Google.Chrome' 실행 후 다시 시도하세요."
    fi
  fi
  info_or_plan "Chrome 발견: ${CHROME_FOUND:-미확인}"
elif [[ "$PLATFORM" == "mac" ]]; then
  if [[ ! -d "/Applications/Google Chrome.app" ]]; then
    if is_dry_run; then
      info_or_plan "Chrome 자동 설치: brew install --cask google-chrome"
    elif command -v brew >/dev/null 2>&1; then
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
    if is_dry_run; then
      info_or_plan "Chrome 자동 설치: sudo apt-get install google-chrome-stable"
    else
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
fi
info_or_plan "Chrome 확인됨"

# ============================================================
# Python venv 패키지 확인 (Ubuntu/Debian은 python3-venv 별도 필요)
# ============================================================
if [[ "$PLATFORM" == "linux" ]]; then
  # python3-venv가 없으면 venv 생성 실패. 자동 설치.
  if ! "$PY" -c "import ensurepip" 2>/dev/null; then
    if is_dry_run; then
      info_or_plan "python3-venv 자동 설치"
    else
      info "python3-venv 자동 설치 중..."
      PYV=$("$PY" -c 'import sys; print(f"python3.{sys.version_info.minor}-venv")')
      sudo apt-get install -y "$PYV" python3-venv 2>&1 | tail -3 || \
        sudo apt-get install -y python3-venv 2>&1 | tail -3
      if ! "$PY" -c "import ensurepip" 2>/dev/null; then
        error "python3-venv 설치 실패. 수동 설치 후 다시 실행: sudo apt install python3-venv"
      fi
      info "✓ python3-venv 설치 완료"
    fi
  fi
fi

# ============================================================
# Python version
# ============================================================
PYV=$("$PY" -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
PYMAJ=$(echo "$PYV" | cut -d. -f1)
PYMIN=$(echo "$PYV" | cut -d. -f2)
if [[ "$PYMAJ" -lt 3 ]] || [[ "$PYMAJ" -eq 3 && "$PYMIN" -lt 9 ]]; then
  error "Python 3.9 이상 필요 (현재 $PYV)"
fi

# ============================================================
# Install
# ============================================================
ROOT="$HOME/jurisupport-beopgoeul"
info_or_plan "설치 위치: $ROOT"
run_or_plan mkdir -p "$ROOT/scripts"

# 기존 venv 정리 (재실행 시 Permission denied 방지)
if [[ -d "$ROOT/.venv" ]]; then
  info_or_plan "기존 venv 발견 — 정리 시도"
  if is_dry_run; then
    info_or_plan "기존 venv 삭제"
  else
    sleep 1
    if ! rm -rf "$ROOT/.venv" 2>/dev/null; then
      warn "기존 venv 삭제 실패. Python 프로세스가 잡고 있을 수 있음."
      case "$PLATFORM" in
        windows)
          warn "PowerShell에서 다음 실행 후 재시도:"
          warn "  Get-Process python,pythonw -ErrorAction SilentlyContinue | Stop-Process -Force"
          warn "  Remove-Item -Recurse -Force '$ROOT/.venv'"
          ;;
        *)
          warn "수동 실행: pkill -f 'jurisupport-beopgoeul/.venv'; rm -rf '$ROOT/.venv'"
          ;;
      esac
      error "venv 정리 필요."
    fi
    info "✓ 기존 venv 정리 완료"
  fi
fi

info_or_plan "Python 가상환경 생성"
if is_dry_run; then
  info_or_plan "venv 생성: $ROOT/.venv"
  info_or_plan "pip install: selenium==4.25.0"
else
  "$PY" -m venv "$ROOT/.venv"
  # shellcheck disable=SC1091
  source "$ROOT/.venv/$VENV_ACTIVATE"
  info "venv Python 버전: $(python --version 2>&1)"
  python -m pip install --progress-bar on --upgrade pip
  pip install --progress-bar on --only-binary :all: selenium==4.25.0
  info "Selenium 설치 완료"
fi

# Copy search script
info_or_plan "검색 스크립트 복사 + 래퍼 생성"
run_or_plan cp "$TOOLKIT_DIR/scripts/search.py" "$ROOT/scripts/search.py"

# Create wrapper sh for easy CLI use (OS-aware activate path + python command)
if is_dry_run; then
  info_or_plan "search.sh 래퍼 생성: $ROOT/scripts/search.sh"
else
  cat > "$ROOT/scripts/search.sh" <<WRAP
#!/usr/bin/env bash
# Wrapper: activate venv and run search.py
ROOT="\$HOME/jurisupport-beopgoeul"
# shellcheck disable=SC1090
source "\$ROOT/.venv/$VENV_ACTIVATE"
exec python "\$ROOT/scripts/search.py" "\$@"
WRAP
  chmod +x "$ROOT/scripts/search.sh"
fi

# Windows: PowerShell wrapper도 함께 생성 (Git Bash 미사용 시)
if [[ "$PLATFORM" == "windows" ]]; then
  if is_dry_run; then
    info_or_plan "search.ps1 래퍼 생성: $ROOT/scripts/search.ps1"
  else
    cat > "$ROOT/scripts/search.ps1" <<'PS1'
# search.ps1 — PowerShell wrapper
$ROOT = Join-Path $env:USERPROFILE 'jurisupport-beopgoeul'
& "$ROOT\.venv\Scripts\python.exe" "$ROOT\scripts\search.py" @args
PS1
  fi
fi

# ============================================================
# Install Claude Code skill (replaces beopgoeul-guide)
# ============================================================
info_or_plan "클로드코드 스킬 설치 중"
SKILL_DST="$HOME/.claude/skills/beopgoeul-search"
run_or_plan mkdir -p "$SKILL_DST"
run_or_plan cp "$TOOLKIT_DIR/../../skills/beopgoeul-search/SKILL.md" "$SKILL_DST/SKILL.md"

# Remove old beopgoeul-guide if exists (replaced by beopgoeul-search)
if [[ -d "$HOME/.claude/skills/beopgoeul-guide" ]]; then
  run_or_plan rm -rf "$HOME/.claude/skills/beopgoeul-guide"
  info_or_plan "옛 beopgoeul-guide 스킬 제거 (beopgoeul-search로 교체됨)"
fi

# ============================================================
# Smoke test
# ============================================================
info_or_plan "작동 확인 중..."
if is_dry_run; then
  info_or_plan "smoke test: $ROOT/scripts/search.sh '민법 제162조' --max 1"
else
  if "$ROOT/scripts/search.sh" "민법 제162조" --max 1 >/dev/null 2>&1; then
    info "✓ 작동 확인 완료"
  else
    warn "작동 확인 실패. 수동 시도: $ROOT/scripts/search.sh '키워드'"
  fi
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
