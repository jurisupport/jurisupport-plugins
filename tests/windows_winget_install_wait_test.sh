#!/usr/bin/env bash
# Regression tests for winget install waiting and success detection.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
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

winget_install_function="$(
  awk '
    /^function Invoke-WingetInstallWithReminder / { in_func = 1 }
    in_func { print }
    in_func && /^}/ { exit }
  ' "$WINDOWS_BOOTSTRAP"
)"

if rg -q --fixed-strings 'Start-Process' <<<"$winget_install_function"; then
  fail "winget install function must not use Start-Process"
else
  printf 'ok - winget install function avoids Start-Process\n'
fi

if rg -q --fixed-strings '& $WingetCommand @arguments' <<<"$winget_install_function"; then
  printf 'ok - winget install function invokes winget directly\n'
else
  fail "winget install function does not invoke winget directly"
fi

expect_contains \
  "Windows bootstrap can verify package installation after odd winget exit" \
  "$WINDOWS_BOOTSTRAP" \
  "function Test-WingetPackageInstalled"

expect_contains \
  "Windows bootstrap treats installed package as success after nonzero exit" \
  "$WINDOWS_BOOTSTRAP" \
  "설치 확인됨:"

expect_contains \
  "Windows bootstrap reuses package verification before install" \
  "$WINDOWS_BOOTSTRAP" \
  "Test-WingetPackageInstalled -WingetCommand \$WingetCommand -PackageId \$id"

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
