#!/usr/bin/env bash
# Regression tests for install.sh browser-opening helper.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="$ROOT/install.sh"
LEGAL_BOOKS_INSTALL="$ROOT/toolkit/legal-books/install.sh"

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

  if rg -q --fixed-strings "$pattern" "$file"; then
    printf 'ok - %s\n' "$name"
  else
    fail "$name: missing $pattern in $file"
  fi
}

expect_failed_browser_is_nonfatal "install.sh" "$INSTALL"
expect_failed_browser_is_nonfatal "legal-books install.sh" "$LEGAL_BOOKS_INSTALL"

expect_contains \
  "korean-law Open API URL is defined" \
  "$INSTALL" \
  'KOREAN_LAW_OPENAPI_URL="https://open.law.go.kr/LSO/openApi/guideList.do"'

expect_contains \
  "korean-law missing-key flow opens browser" \
  "$INSTALL" \
  'open_url "$KOREAN_LAW_OPENAPI_URL"'

expect_contains \
  "JuriSupport signup is default when no token is ready" \
  "$INSTALL" \
  "이미 jurisupport.com 계정 + 토큰이 있으신가요? [y/N, 엔터=아니오]"

expect_contains \
  "Gemini API key URL is defined" \
  "$LEGAL_BOOKS_INSTALL" \
  'GEMINI_API_KEY_URL="https://aistudio.google.com/apikey"'

expect_contains \
  "Gemini key flow opens browser" \
  "$LEGAL_BOOKS_INSTALL" \
  'open_url "$GEMINI_API_KEY_URL"'

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
