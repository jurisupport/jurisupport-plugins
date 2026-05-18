#!/usr/bin/env bash
# jurisupport-plugins bootstrap (Mac/Linux)
#
# 단 한 줄 명령으로 모든 사전 의존성 + 본 패키지를 자동 설치합니다.
#
# 사용:
#   bash <(curl -fsSL https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/bootstrap.sh)
#
# 자동 설치 항목:
#   1. Homebrew (없으면)
#   2. jq, git, python3, node
#   3. Claude Code (npm install -g)
#   4. jurisupport-plugins git clone + install.sh
#
# 인간 입력 필요:
#   - sudo 비밀번호 1회 (Homebrew 설치용)
#   - (강의 후 claude 실행 시) Claude Pro OAuth 로그인
#
# 자동화 불가:
#   - Claude Pro 가입·결제 (https://claude.ai/upgrade 미리 가입)
#   - Gemini API 키 발급 (선택, https://aistudio.google.com/apikey)

set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${GREEN}[bootstrap]${NC} $*"; }
warn()  { echo -e "${YELLOW}[bootstrap]${NC} $*"; }
error() { echo -e "${RED}[bootstrap]${NC} $*" >&2; exit 1; }
step()  { echo -e "\n${BLUE}━━━ $* ━━━${NC}"; }

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
GREEN: bootstrap.sh --plan / --dry-run (no changes will be made)
- Would check OS/platform.
- Would request sudo pre-auth and keepalive for real bootstrap only.
- Would install/check Homebrew or apt packages: jq, git, python3, node.
- Would install Claude Code via npm when missing.
- Would git pull or git clone jurisupport-plugins into $HOME/jurisupport-plugins.
- Would print next-step instructions for running install.sh.
- Guard: in --plan/--dry-run mode this script exits before sudo/brew/apt/curl/npm/git/mv/cd operations.
EOF
}

if is_dry_run; then
  print_plan
fi

# ============================================================
# 0. Banner + OS check
# ============================================================
cat <<'BANNER'

╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║   jurisupport-plugins bootstrap                                ║
║   변호사용 클로드코드 통합 패키지 자동 설치                     ║
║                                                                ║
╠════════════════════════════════════════════════════════════════╣
║                                                                ║
║   진행 단계:                                                   ║
║     1. Homebrew (없으면 자동)                                  ║
║     2. jq · git · python · node                                ║
║     3. Claude Code (npm install -g)                            ║
║     4. jurisupport-plugins git clone + install.sh              ║
║                                                                ║
║   ⚠️  관리자 비밀번호 1회 필요 (Homebrew 설치용)                ║
║   ⚠️  Claude Pro 미가입자는 https://claude.ai/upgrade 먼저      ║
║                                                                ║
║   소요 시간: 약 5~10분                                         ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝

BANNER

OS="$(uname -s)"
case "$OS" in
  Darwin*) PLATFORM="mac" ;;
  Linux*)  PLATFORM="linux" ;;
  *) error "Unsupported OS: $OS. Mac/Linux only. Windows: WSL2 사용 (https://github.com/jurisupport/jurisupport-plugins/blob/main/WINDOWS_WSL.md)" ;;
esac
info "플랫폼: $PLATFORM"

# ============================================================
# 1. sudo pre-auth + background keepalive
# ============================================================
step "1. 관리자 권한 인증 (1회만, 이후 자동 갱신)"

echo ""
echo "  Homebrew 및 시스템 패키지 설치를 위해 비밀번호 1회 입력이 필요합니다."
echo "  이후 약 10분간 자동으로 갱신되어 추가 입력은 없습니다."
echo ""

if is_dry_run; then
  plan "sudo -v"
  plan "start sudo keepalive background loop"
else
  if ! sudo -v; then
    error "sudo 인증 실패. bootstrap 중단."
  fi
  # Background: keep sudo alive every 60s as long as parent is running
  ( while true; do
      sudo -n true 2>/dev/null || exit
      sleep 60
      kill -0 "$$" 2>/dev/null || exit
    done ) &
  SUDO_KEEPALIVE_PID=$!
  trap "kill $SUDO_KEEPALIVE_PID 2>/dev/null || true" EXIT
fi

# ============================================================
# 2. Homebrew (macOS only — Linux는 apt 사용)
# ============================================================
if [[ "$PLATFORM" == "mac" ]]; then
  step "2. Homebrew 확인"
  if is_dry_run; then
    plan "command -v brew; if present, inspect brew --version"
  elif command -v brew >/dev/null 2>&1; then
    info "✓ Homebrew 이미 설치됨: $(brew --version | head -1)"
  else
    info "Homebrew 설치 중... (3~5분)"
    run_shell_or_plan 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

    # Apple Silicon: brew PATH 추가
    if [[ -d /opt/homebrew/bin ]]; then
      if is_dry_run; then plan "eval /opt/homebrew/bin/brew shellenv"; else eval "$(/opt/homebrew/bin/brew shellenv)"; fi
      # ~/.zprofile 영구 등록
      if ! grep -q "brew shellenv" "$HOME/.zprofile" 2>/dev/null; then
        if is_dry_run; then plan "append brew shellenv to $HOME/.zprofile"; else echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"; fi
        if is_dry_run; then info "PATH 영구 등록 예정: ~/.zprofile (dry-run: 실제 변경 없음)"; else info "PATH 영구 등록: ~/.zprofile"; fi
      fi
    fi
    if is_dry_run; then info "✓ Homebrew 설치 예정 확인 완료 (dry-run: 실제 변경 없음)"; else info "✓ Homebrew 설치 완료"; fi
  fi
else
  step "2. apt 업데이트 (Linux)"
  run_or_plan sudo apt-get update -q
  if is_dry_run; then info "✓ apt 패키지 인덱스 업데이트 예정 (dry-run: 실제 변경 없음)"; else info "✓ apt 패키지 인덱스 업데이트"; fi
fi

# ============================================================
# 3. 시스템 패키지 (jq, git, python, node)
# ============================================================
step "3. 시스템 패키지 설치"

install_pkg() {
  local cmd="$1" pkg_mac="$2" pkg_linux="$3"
  if is_dry_run; then
    plan "command -v $cmd; install $pkg_mac/$pkg_linux if missing"
    info "✓ $cmd 설치 상태 확인 예정 (dry-run: 실제 변경 없음)"
    return
  elif command -v "$cmd" >/dev/null 2>&1; then
    info "✓ $cmd 이미 설치됨"
    return
  fi
  info "$cmd 설치 중..."
  if [[ "$PLATFORM" == "mac" ]]; then
    run_shell_or_plan "brew install '$pkg_mac' >/dev/null"
  else
    run_shell_or_plan "sudo apt-get install -y '$pkg_linux' >/dev/null"
  fi
  if is_dry_run; then info "✓ $cmd 설치 예정 확인 완료 (dry-run: 실제 변경 없음)"; else info "✓ $cmd 설치 완료"; fi
}

install_pkg "jq"      "jq"          "jq"
install_pkg "git"     "git"         "git"
install_pkg "python3" "python@3.11" "python3"
install_pkg "node"    "node"        "nodejs"

# Ubuntu/Debian은 python3-venv 별도 패키지
if [[ "$PLATFORM" == "linux" ]] && is_dry_run; then
  plan "python3 -c 'import ensurepip'; install python3-venv with apt-get if missing"
elif [[ "$PLATFORM" == "linux" ]] && ! python3 -c "import ensurepip" 2>/dev/null; then
  info "python3-venv 설치 중..."
  PYV=$(python3 -c 'import sys; print(f"python3.{sys.version_info.minor}-venv")')
  run_shell_or_plan "sudo apt-get install -y '$PYV' python3-venv >/dev/null 2>&1 || sudo apt-get install -y python3-venv >/dev/null 2>&1"
  if is_dry_run; then info "✓ python3-venv 설치 예정 확인 완료 (dry-run: 실제 변경 없음)"; else info "✓ python3-venv 설치 완료"; fi
fi

# Linux Node가 너무 오래된 버전이면 NodeSource로 재설치
if [[ "$PLATFORM" == "linux" ]]; then
  if is_dry_run; then
    plan "node -v; install NodeSource LTS with curl/sudo apt-get if Node.js major < 20"
    NODE_MAJOR=20
  else
    NODE_MAJOR=$(node -v 2>/dev/null | sed 's/v\([0-9]*\).*/\1/' || echo 0)
  fi
  if [[ "$NODE_MAJOR" -lt 20 ]]; then
    info "Node.js 버전이 오래됨 ($NODE_MAJOR). NodeSource LTS 설치..."
    run_shell_or_plan "curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash - >/dev/null"
    run_or_plan sudo apt-get install -y nodejs
    if is_dry_run; then info "✓ Node.js LTS 설치 예정 확인 완료 (dry-run: 실제 변경 없음)"; else info "✓ Node.js LTS 설치 완료: $(node -v)"; fi
  fi
fi

# ============================================================
# 4. Claude Code (npm install -g)
# ============================================================
step "4. Claude Code 설치"

if is_dry_run; then
  plan "command -v claude; if present, inspect claude --version"
elif command -v claude >/dev/null 2>&1; then
  info "✓ Claude Code 이미 설치됨: $(claude --version 2>&1 | head -1 || echo 'version unknown')"
else
  info "Claude Code 설치 중... (npm install -g @anthropic-ai/claude-code)"
  if [[ "$PLATFORM" == "mac" ]]; then
    run_or_plan npm install -g @anthropic-ai/claude-code
  else
    # Linux: npm global이 보통 /usr/lib/node_modules — sudo 필요
    run_or_plan sudo npm install -g @anthropic-ai/claude-code
  fi
  if is_dry_run; then info "✓ Claude Code 설치 예정 확인 완료 (dry-run: 실제 변경 없음)"; else info "✓ Claude Code 설치 완료"; fi
fi

# ============================================================
# 5. jurisupport-plugins 패키지
# ============================================================
step "5. jurisupport-plugins 다운로드 + 설치"

CLONE_DIR="$HOME/jurisupport-plugins"

if [[ -d "$CLONE_DIR/.git" ]]; then
  if is_dry_run; then info "clone 상태 확인 예정 → git pull 최신화 예정 (dry-run: 실제 변경 없음)"; else info "이미 clone 되어 있음 → git pull로 최신화"; fi
  run_shell_or_plan "cd '$CLONE_DIR' && git pull --rebase >/dev/null 2>&1" || warn "git pull 실패 (네트워크?)"
else
  if [[ -d "$CLONE_DIR" ]]; then
    warn "$CLONE_DIR 가 이미 존재 (git 저장소 아님). 백업: ${CLONE_DIR}.backup-$(date +%Y%m%d-%H%M%S)"
    run_or_plan mv "$CLONE_DIR" "${CLONE_DIR}.backup-$(date +%Y%m%d-%H%M%S)"
  fi
  info "git clone https://github.com/jurisupport/jurisupport-plugins.git"
  run_shell_or_plan "git clone https://github.com/jurisupport/jurisupport-plugins.git '$CLONE_DIR' >/dev/null"
fi

if is_dry_run; then info "✓ $CLONE_DIR 준비 예정 확인 완료 (dry-run: 실제 변경 없음)"; else info "✓ $CLONE_DIR 준비됨"; fi

# ============================================================
# 6. install.sh 실행 안내 (interactive 부분이라 자동 실행은 안 함)
# ============================================================
step "6. 다음 단계"

cat <<EOF

${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$(if is_dry_run; then printf '✓ Bootstrap PLAN 완료 (dry-run: 실제 변경 없음). 다음 단계 안내입니다.'; else printf '✓ Bootstrap 완료. 이제 두 가지만 남았습니다.'; fi)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}

${BLUE}[1/2] Claude Code 로그인${NC}
새 터미널에서 다음 실행 (브라우저 OAuth 1회):

    claude

→ Claude Pro/Max 계정으로 로그인. "안녕하세요" 입력해서 한국어 답 확인.

${BLUE}[2/2] 본 패키지 설치 (install.sh)${NC}

    cd ~/jurisupport-plugins
    ./install.sh

→ 데이터 보호 Hook + songmu-legal 플러그인 + 스킬 자동 등록.
   legal-books·case-records·법고을 toolkit은 선택 설치 (Gemini API 키·Chrome 필요).

자세한 가이드:
  - 콜드스타트:        ~/jurisupport-plugins/COLD_START.md
  - 보안 원칙 (필독):  ~/jurisupport-plugins/guides/00_security.md

문의: admin@jurisupport.com
EOF
