#!/usr/bin/env bash
# Regression tests for install.sh browser-opening helper.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$ROOT/install.sh"

failures=0

fail() {
  printf 'not ok - %s\n' "$1" >&2
  failures=$((failures + 1))
}

extract_open_url() {
  awk '
    /^open_url\(\) \{/ { in_func = 1 }
    in_func { print }
    in_func && /^}/ { exit }
  ' "$INSTALL"
}

expect_failed_browser_is_nonfatal() {
  local tmpdir
  local output
  local actual

  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  cat > "$tmpdir/open" <<'SH'
#!/usr/bin/env bash
exit 42
SH
  chmod +x "$tmpdir/open"

  set +e
  output=$(
    PLATFORM=mac PATH="$tmpdir:$PATH" bash -c "
      warn() { printf '[warn] %s\n' \"\$*\"; }
      $(extract_open_url)
      open_url 'https://example.test/signup'
    " 2>&1
  )
  actual=$?
  set -e

  if [[ "$actual" -ne 0 ]]; then
    fail "open_url returns success when browser launcher fails: exit $actual"
  elif [[ "$output" != *"브라우저 자동 열기 실패"* || "$output" != *"https://example.test/signup"* ]]; then
    fail "open_url prints manual fallback URL"
    printf '%s\n' "$output" >&2
  else
    printf 'ok - open_url browser launch failure is nonfatal\n'
  fi
}

expect_failed_browser_is_nonfatal

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
