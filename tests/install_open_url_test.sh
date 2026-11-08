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
  local script="$1"
  awk '
    /^open_url\(\) \{/ { in_func = 1 }
    in_func { print }
    in_func && /^}/ { exit }
  ' "$script"
}

expect_failed_browser_is_nonfatal() {
  local name="$1"
  local script="$2"
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
      $(extract_open_url "$script")
      open_url 'https://example.test/signup'
    " 2>&1
  )
  actual=$?
  set -e

  if [[ "$actual" -ne 0 ]]; then
    fail "$name open_url returns success when browser launcher fails: exit $actual"
  elif [[ "$output" != *"브라우저 자동 열기 실패"* || "$output" != *"https://example.test/signup"* ]]; then
    fail "$name open_url prints manual fallback URL"
    printf '%s\n' "$output" >&2
  else
    printf 'ok - %s open_url browser launch failure is nonfatal\n' "$name"
  fi
}

expect_contains() {
  local name="$1"
  local file="$2"
  local pattern="$3"

  if grep -Fq -- "$pattern" "$file"; then
    printf 'ok - %s\n' "$name"
  else
    fail "$name: missing $pattern in $file"
  fi
}

expect_not_contains() {
  local name="$1"
  local file="$2"
  local pattern="$3"

  if grep -Fq -- "$pattern" "$file"; then
    fail "$name: unexpected $pattern in $file"
  else
    printf 'ok - %s\n' "$name"
  fi
}

expect_failed_browser_is_nonfatal "install.sh" "$INSTALL"

expect_contains \
  "korean-law Open API URL is defined" \
  "$INSTALL" \
  'KOREAN_LAW_OPENAPI_URL="https://open.law.go.kr/LSO/openApi/guideList.do"'

expect_contains \
  "korean-law missing-key flow opens browser" \
  "$INSTALL" \
  'open_url "$KOREAN_LAW_OPENAPI_URL"'

expect_contains \
  "korean-law plugin install uses non-secret setup helper" \
  "$INSTALL" \
  'run_python "$TOOLKIT_DIR/scripts/configure_korean_law.py" --install'

expect_not_contains \
  "korean-law plugin install is not piped" \
  "$INSTALL" \
  'claude plugin install "$KOREAN_LAW_PLUGIN_REF" 2>&1 | tail'

expect_contains \
  "JuriSupport plugin install keeps terminal prompts" \
  "$INSTALL" \
  'if claude plugin install jurisupport@jurisupport-plugins; then'

expect_contains \
  "JuriSupport signup is default when no token is ready" \
  "$INSTALL" \
  "이미 jurisupport.com 계정 + 토큰이 있으신가요? [y/N, 엔터=아니오]"

expect_contains \
  "JuriSupport token input uses protected UI" \
  "$INSTALL" \
  'configure_credentials --service jurisupport'

expect_not_contains \
  "installer never passes tokens as authorization arguments" \
  "$INSTALL" \
  '--header'

expect_not_contains \
  "installer no longer has a terminal secret prompt" \
  "$INSTALL" \
  'prompt_secret'

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
