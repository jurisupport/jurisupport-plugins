#!/usr/bin/env bash
# Regression tests for Windows update/refresh behavior.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$ROOT/install.sh"
WINDOWS_BOOTSTRAP="$ROOT/windows-bootstrap.ps1"

failures=0

fail() {
  printf 'not ok - %s\n' "$1" >&2
  failures=$((failures + 1))
}

expect_contains() {
  local name="$1"
  local file="$2"
  local pattern="$3"

  if rg -q --fixed-strings "$pattern" "$file"; then
    printf 'ok - %s\n' "$name"
  else
    fail "$name: missing $pattern in $file"
  fi
}

expect_contains \
  "Windows bootstrap fetches origin/main directly" \
  "$WINDOWS_BOOTSTRAP" \
  "git fetch --progress origin main:refs/remotes/origin/main"

expect_contains \
  "Windows bootstrap resets repo to origin/main" \
  "$WINDOWS_BOOTSTRAP" \
  "git reset --hard origin/main"

expect_contains \
  "Windows plugin refresh updates marketplace first" \
  "$INSTALL" \
  "claude plugin marketplace update jurisupport-plugins"

expect_contains \
  "Windows plugin refresh reinstalls while keeping data" \
  "$INSTALL" \
  "claude plugin uninstall --keep-data -y jurisupport"

expect_contains \
  "Windows bootstrap refreshes Claude Code even when present" \
  "$WINDOWS_BOOTSTRAP" \
  "Claude Code 이미 설치됨 - 최신 버전 확인/갱신 중..."

expect_contains \
  "Windows bootstrap runs install.sh through terminal input" \
  "$WINDOWS_BOOTSTRAP" \
  "./install.sh < /dev/tty"

expect_contains \
  "Windows bootstrap reports current install step count" \
  "$WINDOWS_BOOTSTRAP" \
  "install.sh가 곧 시작됩니다. 12단계 대화식 설치:"

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
