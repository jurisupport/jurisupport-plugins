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

PLAN_MODE=0
for arg in "$@"; do
  case "$arg" in
    --plan|--dry-run) PLAN_MODE=1 ;;
    *) error "unknown option: $arg (supported: --plan, --dry-run)" ;;
  esac
done

DRY_RUN="${DRY_RUN:-${JURISUPPORT_DRY_RUN:-0}}"
if [[ "$PLAN_MODE" -eq 1 ]]; then
  DRY_RUN=1
fi
is_dry_run() { [[ "${DRY_RUN:-0}" == "1" || "${DRY_RUN:-0}" == "true" || "${DRY_RUN:-0}" == "yes" ]]; }
plan() { echo "PLAN: $*"; }
run_or_plan() {
  if is_dry_run; then
    plan "$*"
  else
    "$@"
  fi
}
run_shell_or_plan() {
  if is_dry_run; then
    plan "$*"
  else
    bash -c "$*"
  fi
}

print_plan() {
  cat <<'EOF'
GREEN: toolkit/beopgoeul/install.sh --plan / --dry-run (no changes will be made)
- Would check OS/platform, Chrome/Chromium availability, python3, and python3-venv.
- Would install Chrome through brew/apt only in real mode when missing.
- Would create $HOME/jurisupport-beopgoeul layout, Python venv, and install Selenium.
- Would copy search.py, create search.sh wrapper, and install beopgoeul-search Claude Code skill.
- Would remove old beopgoeul-guide skill and run a live smoke search only in real mode.
- Guard: in --plan/--dry-run mode this script exits before brew/apt/wget/sudo/mkdir/venv/pip/cp/rm/search operations.
EOF
}

if is_dry_run; then
  print_plan
fi

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
if is_dry_run; then
  plan "check Chrome/Chromium availability; install via brew/apt if missing"
elif [[ "$PLATFORM" == "mac" ]]; then
  if [[ ! -d "/Applications/Google Chrome.app" ]]; then
    if command -v brew >/dev/null 2>&1; then
      info "Chrome 자동 설치 중 (Homebrew cask)..."
      run_shell_or_plan "brew install --cask google-chrome 2>&1 | tail -3"
      if [[ -d "/Applications/Google Chrome.app" ]]; then
        if is_dry_run; then info "✓ Chrome 설치 예정 확인 완료 (dry-run: 실제 변경 없음)"; else info "✓ Chrome 설치 완료"; fi
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
      run_shell_or_plan "wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/google.gpg"
    fi
    if [[ ! -f /etc/apt/sources.list.d/google.list ]]; then
      run_shell_or_plan "echo deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main | sudo tee /etc/apt/sources.list.d/google.list >/dev/null"
    fi
    run_or_plan sudo apt-get update -q
    run_or_plan sudo apt-get install -y google-chrome-stable
    if command -v google-chrome >/dev/null; then
      if is_dry_run; then info "✓ Chrome 설치 예정 확인 완료 (dry-run: 실제 변경 없음)"; else info "✓ Chrome 설치 완료: $(google-chrome --version 2>&1 | head -1)"; fi
    else
      warn "google-chrome-stable 설치 실패 → chromium-browser 시도..."
      run_shell_or_plan "sudo apt-get install -y chromium-browser 2>&1 | tail -3"
      if command -v chromium-browser >/dev/null || command -v chromium >/dev/null; then
        if is_dry_run; then info "✓ Chromium 설치 예정 확인 완료 (dry-run: 실제 변경 없음)"; else info "✓ Chromium 설치 완료"; fi
      else
        error "Chrome/Chromium 설치 실패. 수동 설치 후 다시 실행하세요."
      fi
    fi
  fi
fi
if is_dry_run; then info "✓ Chrome 확인 예정 (dry-run: 실제 변경 없음)"; else info "✓ Chrome 확인됨"; fi

# ============================================================
# Python venv 패키지 확인 (Ubuntu/Debian은 python3-venv 별도 필요)
# ============================================================
if [[ "$PLATFORM" == "linux" ]] && is_dry_run; then
  plan "python3 -c 'import ensurepip'; install python3-venv with apt-get if missing"
elif [[ "$PLATFORM" == "linux" ]]; then
  # python3-venv가 없으면 venv 생성 실패. 자동 설치.
  if ! python3 -c "import ensurepip" 2>/dev/null; then
    info "python3-venv 자동 설치 중..."
    # python3.XX-venv 또는 일반 python3-venv 시도
    PYV=$(python3 -c 'import sys; print(f"python3.{sys.version_info.minor}-venv")')
    run_shell_or_plan "sudo apt-get install -y '$PYV' python3-venv 2>&1 | tail -3 || sudo apt-get install -y python3-venv 2>&1 | tail -3"
    if ! python3 -c "import ensurepip" 2>/dev/null; then
      error "python3-venv 설치 실패. 수동 설치 후 다시 실행: sudo apt install python3-venv"
    fi
    if is_dry_run; then info "✓ python3-venv 설치 예정 확인 완료 (dry-run: 실제 변경 없음)"; else info "✓ python3-venv 설치 완료"; fi
  fi
fi

# ============================================================
# Python version
# ============================================================
if is_dry_run; then
  plan "python3 -c <check Python version >= 3.9>"
else
  PYV=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
  PYMAJ=$(echo "$PYV" | cut -d. -f1)
  PYMIN=$(echo "$PYV" | cut -d. -f2)
  if [[ "$PYMAJ" -lt 3 ]] || [[ "$PYMAJ" -eq 3 && "$PYMIN" -lt 9 ]]; then
    error "Python 3.9 이상 필요 (현재 $PYV)"
  fi
fi

# ============================================================
# Install
# ============================================================
ROOT="$HOME/jurisupport-beopgoeul"
info "설치 위치: $ROOT"
run_or_plan mkdir -p "$ROOT/scripts"

run_or_plan python3 -m venv "$ROOT/.venv"
# shellcheck disable=SC1091
if is_dry_run; then plan "source $ROOT/.venv/bin/activate"; else source "$ROOT/.venv/bin/activate"; fi
run_or_plan pip install --quiet --upgrade pip
run_or_plan pip install --quiet selenium==4.25.0
if is_dry_run; then info "Selenium 설치 예정 (dry-run: 실제 변경 없음)"; else info "Selenium 설치 완료"; fi

# Copy search script
TOOLKIT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
run_or_plan cp "$TOOLKIT_DIR/scripts/search.py" "$ROOT/scripts/search.py"

# Create wrapper sh for easy CLI use
if is_dry_run; then
  plan "write wrapper script $ROOT/scripts/search.sh"
else
cat > "$ROOT/scripts/search.sh" <<'WRAP'
#!/usr/bin/env bash
# Wrapper: activate venv and run search.py
ROOT="$HOME/jurisupport-beopgoeul"
# shellcheck disable=SC1090
if is_dry_run; then plan "source $ROOT/.venv/bin/activate"; else source "$ROOT/.venv/bin/activate"; fi
exec python3 "$ROOT/scripts/search.py" "$@"
WRAP
fi
run_or_plan chmod +x "$ROOT/scripts/search.sh"

# ============================================================
# Install Claude Code skill (replaces beopgoeul-guide)
# ============================================================
SKILL_DST="$HOME/.claude/skills/beopgoeul-search"
run_or_plan mkdir -p "$SKILL_DST"
run_or_plan cp "$TOOLKIT_DIR/../../skills/beopgoeul-search/SKILL.md" "$SKILL_DST/SKILL.md"

# Remove old beopgoeul-guide if exists (replaced by beopgoeul-search)
if [[ -d "$HOME/.claude/skills/beopgoeul-guide" ]]; then
  run_or_plan rm -rf "$HOME/.claude/skills/beopgoeul-guide"
  if is_dry_run; then info "옛 beopgoeul-guide 스킬 제거 예정 (dry-run: 실제 변경 없음)"; else info "옛 beopgoeul-guide 스킬 제거 (beopgoeul-search로 교체됨)"; fi
fi

# ============================================================
# Smoke test
# ============================================================
info "작동 확인 중..."
if is_dry_run; then
  plan "$ROOT/scripts/search.sh 민법 제162조 --max 1"
elif "$ROOT/scripts/search.sh" "민법 제162조" --max 1 >/dev/null 2>&1; then
  if is_dry_run; then info "✓ 작동 확인 예정 (dry-run: 실제 변경 없음)"; else info "✓ 작동 확인 완료"; fi
else
  warn "작동 확인 실패. 수동 시도: $ROOT/scripts/search.sh '키워드'"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
if is_dry_run; then echo -e "${GREEN}법고을 자동 검색 toolkit PLAN 완료 (dry-run: 실제 변경 없음)${NC}"; else echo -e "${GREEN}법고을 자동 검색 toolkit 설치 완료${NC}"; fi
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
