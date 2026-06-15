#!/usr/bin/env bash
# Regression tests for Windows jq portable fallback wiring.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

failures=0

expect_contains() {
  local name="$1"
  local file="$2"
  local pattern="$3"

  if rg -q --fixed-strings "$pattern" "$ROOT/$file"; then
    printf 'ok - %s\n' "$name"
  else
    printf 'not ok - %s: missing %s in %s\n' "$name" "$pattern" "$file" >&2
    failures=$((failures + 1))
  fi
}

expect_contains "Windows bootstrap defines jq portable fallback" "windows-bootstrap.ps1" "function Install-JqPortable"
expect_contains "Windows bootstrap downloads jq from official releases" "windows-bootstrap.ps1" "https://api.github.com/repos/jqlang/jq/releases/latest"
expect_contains "Windows bootstrap installs portable jq into user-local bin" "windows-bootstrap.ps1" "Programs\\jurisupport-bin"
expect_contains "Windows bootstrap invokes fallback for jqlang.jq" "windows-bootstrap.ps1" "\$pkg.Ids -contains 'jqlang.jq'"
expect_contains "Windows guide documents jq fallback" "WINDOWS_NATIVE.md" "portable fallback"

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
