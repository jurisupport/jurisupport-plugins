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
#   2. jq, git, python3, node, rclone
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

# lib/dry-run.sh 로드: bash <(curl ...) 실행 시 BASH_SOURCE가 /dev/fd/... 이므로
# 로컬 파일이 없으면 GitHub에서 직접 가져온다.
_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)"
_DRYRUN_LIB="$_SCRIPT_DIR/lib/dry-run.sh"
_DRYRUN_TMP=""
if [[ ! -f "$_DRYRUN_LIB" ]]; then
  _DRYRUN_TMP="$(mktemp)"
  _DRYRUN_LIB="$_DRYRUN_TMP"
  curl -fsSL "https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/lib/dry-run.sh" \
    > "$_DRYRUN_LIB" || { echo "ERROR: lib/dry-run.sh 다운로드 실패" >&2; exit 1; }
fi
source "$_DRYRUN_LIB" "$@"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()  { echo -e "${GREEN}[bootstrap]${NC} $*"; }
warn()  { echo -e "${YELLOW}[bootstrap]${NC} $*"; }
error() { echo -e "${RED}[bootstrap]${NC} $*" >&2; exit 1; }
step()  { echo -e "\n${BLUE}━━━ $* ━━━${NC}"; }

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
║     2. jq · git · python · node · rclone                       ║
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

if is_dry_run; then
  info_or_plan "sudo 인증 건너뜀"
  [[ -n "$_DRYRUN_TMP" ]] && trap "rm -f '$_DRYRUN_TMP'" EXIT
else
  echo ""
  echo "  Homebrew 및 시스템 패키지 설치를 위해 비밀번호 1회 입력이 필요합니다."
  echo "  이후 약 10분간 자동으로 갱신되어 추가 입력은 없습니다."
  echo ""

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
  trap "kill $SUDO_KEEPALIVE_PID 2>/dev/null || true; [[ -n \"\$_DRYRUN_TMP\" ]] && rm -f \"\$_DRYRUN_TMP\"" EXIT
fi

# ============================================================
# 2. Homebrew (macOS only — Linux는 apt 사용)
# ============================================================
if [[ "$PLATFORM" == "mac" ]]; then
  step "2. Homebrew 확인"
  if command -v brew >/dev/null 2>&1; then
    info "✓ Homebrew 이미 설치됨: $(brew --version | head -1)"
  else
    info_or_plan "Homebrew 설치 (3~5분)"
    run_shell_or_plan 'NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'

    # Apple Silicon: brew PATH 추가
    if ! is_dry_run && [[ -d /opt/homebrew/bin ]]; then
      eval "$(/opt/homebrew/bin/brew shellenv)"
      # ~/.zprofile 영구 등록
      if ! grep -q "brew shellenv" "$HOME/.zprofile" 2>/dev/null; then
        echo 'eval "$(/opt/homebrew/bin/brew shellenv)"' >> "$HOME/.zprofile"
        info "PATH 영구 등록: ~/.zprofile"
      fi
    elif is_dry_run && [[ -d /opt/homebrew/bin ]]; then
      info_or_plan "brew shellenv PATH 등록 → ~/.zprofile"
    fi
    info_or_plan "Homebrew 설치 완료"
  fi
else
  step "2. apt 업데이트 (Linux)"
  run_or_plan sudo apt-get update -q
  info_or_plan "apt 패키지 인덱스 업데이트"
fi

# ============================================================
# 3. 시스템 패키지 (jq, git, python, node)
# ============================================================
step "3. 시스템 패키지 설치"

install_pkg() {
  local cmd="$1" pkg_mac="$2" pkg_linux="$3"
  if command -v "$cmd" >/dev/null 2>&1; then
    info "✓ $cmd 이미 설치됨"
    return
  fi
  info_or_plan "$cmd 설치"
  if [[ "$PLATFORM" == "mac" ]]; then
    run_or_plan brew install "$pkg_mac"
  else
    run_or_plan sudo apt-get install -y "$pkg_linux"
  fi
}

install_pkg "jq"      "jq"          "jq"
install_pkg "git"     "git"         "git"
install_pkg "python3" "python@3.11" "python3"
install_pkg "node"    "node"        "nodejs"
install_pkg "rclone"  "rclone"      "rclone"

# Ubuntu/Debian은 python3-venv 별도 패키지
if [[ "$PLATFORM" == "linux" ]] && ! python3 -c "import ensurepip" 2>/dev/null; then
  info_or_plan "python3-venv 설치"
  if is_dry_run; then
    echo "PLAN: sudo apt-get install -y python3.XX-venv python3-venv"
  else
    PYV=$(python3 -c 'import sys; print(f"python3.{sys.version_info.minor}-venv")')
    sudo apt-get install -y "$PYV" python3-venv >/dev/null 2>&1 || \
      sudo apt-get install -y python3-venv >/dev/null 2>&1
  fi
fi

# Linux Node가 너무 오래된 버전이면 NodeSource로 재설치
if [[ "$PLATFORM" == "linux" ]]; then
  NODE_MAJOR=$(node -v 2>/dev/null | sed 's/v\([0-9]*\).*/\1/' || echo 0)
  if [[ "$NODE_MAJOR" -lt 20 ]]; then
    info_or_plan "Node.js 버전이 오래됨 ($NODE_MAJOR). NodeSource LTS 설치"
    run_shell_or_plan "curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -"
    run_or_plan sudo apt-get install -y nodejs
  fi
fi

# ============================================================
# 4. Claude Code (npm install -g)
# ============================================================
step "4. Claude Code 설치"

if command -v claude >/dev/null 2>&1; then
  info "✓ Claude Code 이미 설치됨: $(claude --version 2>&1 | head -1 || echo 'version unknown')"
else
  info_or_plan "Claude Code 설치 (npm install -g @anthropic-ai/claude-code)"
  if [[ "$PLATFORM" == "mac" ]]; then
    run_or_plan npm install -g @anthropic-ai/claude-code
  else
    # Linux: npm global이 보통 /usr/lib/node_modules — sudo 필요
    run_or_plan sudo npm install -g @anthropic-ai/claude-code
  fi
fi

# ============================================================
# 5. jurisupport-plugins 패키지
# ============================================================
step "5. jurisupport-plugins 다운로드 + 설치"

CLONE_DIR="$HOME/jurisupport-plugins"

if [[ -d "$CLONE_DIR/.git" ]]; then
  info_or_plan "이미 clone 되어 있음 → git pull로 최신화"
  if ! is_dry_run; then
    cd "$CLONE_DIR" && git pull --rebase >/dev/null 2>&1 || warn "git pull 실패 (네트워크?)"
  else
    echo "PLAN: cd $CLONE_DIR && git pull --rebase"
  fi
else
  if [[ -d "$CLONE_DIR" ]]; then
    warn "$CLONE_DIR 가 이미 존재 (git 저장소 아님). 백업: ${CLONE_DIR}.backup-\$(date +%Y%m%d-%H%M%S)"
    run_or_plan mv "$CLONE_DIR" "${CLONE_DIR}.backup-$(date +%Y%m%d-%H%M%S)"
  fi
  info_or_plan "git clone https://github.com/jurisupport/jurisupport-plugins.git"
  run_or_plan git clone https://github.com/jurisupport/jurisupport-plugins.git "$CLONE_DIR"
fi

info_or_plan "$CLONE_DIR 준비됨"

# ============================================================
# 6. install.sh 실행 안내 (interactive 부분이라 자동 실행은 안 함)
# ============================================================
step "6. 다음 단계"

if is_dry_run; then
cat <<EOF

${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ DRY-RUN 완료. 위 PLAN: 목록이 실제 실행될 명령입니다.
  실제 설치하려면 --plan / --dry-run 없이 다시 실행하세요.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}
EOF
else
cat <<EOF

${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
✓ Bootstrap 완료. 이제 두 가지만 남았습니다.
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
fi
