#!/usr/bin/env bash
# Regression tests for Windows rclone bootstrap wiring.

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

expect_contains "Windows bootstrap installs rclone via winget" "windows-bootstrap.ps1" "Rclone.Rclone"
expect_contains "Windows bootstrap captures rclone version" "windows-bootstrap.ps1" "rclone version"
expect_contains "Windows uninstall can remove rclone" "windows-uninstall.ps1" "Rclone.Rclone"
expect_contains "Windows guide documents rclone" "WINDOWS_NATIVE.md" "qpdf/rclone"
expect_contains "README documents Windows rclone install" "README.md" "Ghostscript/rclone"

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
