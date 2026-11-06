#!/usr/bin/env bash
# Regression tests for hooks/pretool_data_protection.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/hooks/pretool_data_protection.sh"

failures=0
TEST_TMP=$(mktemp -d)
trap 'rm -rf "$TEST_TMP"' EXIT

expect_exit() {
  local name="$1"
  local expected="$2"
  local payload="$3"
  local actual locale_mode
  local -a hook_env
  for locale_mode in inherited unset C C.UTF-8; do
    hook_env=(env)
    case "$locale_mode" in
      unset) hook_env+=(-u LANG -u LC_ALL -u LC_CTYPE) ;;
      C|C.UTF-8) hook_env+=(LC_ALL="$locale_mode") ;;
    esac
    actual=0
    printf '%s' "$payload" | "${hook_env[@]}" bash "$HOOK" >"$TEST_TMP/out" 2>"$TEST_TMP/err" || actual=$?
    if [[ "$actual" == "$expected" ]]; then
      printf 'ok - %s (%s)\n' "$name" "$locale_mode"
    else
      printf 'not ok - %s (%s): expected exit %s, got %s\n' "$name" "$locale_mode" "$expected" "$actual" >&2
      sed -n '1,8p' "$TEST_TMP/err" >&2
      failures=$((failures + 1))
    fi
  done
}

expect_exit \
  "WebSearch blocks Korean RRN" \
  2 \
  '{"tool_name":"WebSearch","tool_input":{"query":"홍길동 700101-1234567"}}'

expect_exit \
  "WebFetch allows lbox.kr without PII" \
  0 \
  '{"tool_name":"WebFetch","tool_input":{"url":"https://lbox.kr/search"}}'

expect_exit \
  "WebFetch blocks Korean case number on external URL" \
  2 \
  '{"tool_name":"WebFetch","tool_input":{"url":"https://example.com/search","query":"2025가합10737"}}'

expect_exit \
  "Bash remains local for PII pattern" \
  0 \
  '{"tool_name":"Bash","tool_input":{"command":"echo 700101-1234567"}}'

expect_exit \
  "Google Drive search is treated as external" \
  2 \
  '{"tool_name":"mcp__claude_ai_Google_Drive__search_files","tool_input":{"query":"홍길동 700101-1234567"}}'

expect_exit \
  "Claude Gmail variants are treated as external" \
  2 \
  '{"tool_name":"mcp__claude_ai_Gmail__send_email","tool_input":{"body":"홍길동 700101-1234567"}}'

expect_exit \
  "invalid JSON blocks" \
  2 \
  '{bad json'

expect_exit "WebSearch blocks single Hangul case code" 2 \
  '{"tool_name":"WebSearch","tool_input":{"query":"2025다12345"}}'
expect_exit "Gmail blocks three Hangul case code" 2 \
  '{"tool_name":"mcp__claude_ai_Gmail__send_email","tool_input":{"body":"2025카단12345"}}'
expect_exit "Unicode-escaped case number blocks" 2 \
  '{"tool_name":"WebFetch","tool_input":{"query":"2025\uac00\ud56910737"}}'
expect_exit "Non-Hangul case-like text passes" 0 \
  '{"tool_name":"WebSearch","tool_input":{"query":"2025ABC10737 2025中文10737"}}'
expect_exit "Korean phone blocks" 2 \
  '{"tool_name":"WebSearch","tool_input":{"query":"010-0000-0000"}}'
expect_exit "Local case number passes" 0 \
  '{"tool_name":"Read","tool_input":{"file_path":"2025가합10737.md"}}'

mkdir "$TEST_TMP/bin"
cat > "$TEST_TMP/bin/jq" <<'SH'
#!/usr/bin/env bash
if [[ "${1:-}" == -Rse ]]; then exit 3; fi
exec "$JURISUPPORT_TEST_REAL_JQ" "$@"
SH
chmod +x "$TEST_TMP/bin/jq"
JURISUPPORT_TEST_REAL_JQ=$(command -v jq) PATH="$TEST_TMP/bin:$PATH" \
  expect_exit "Matcher error blocks instead of allowing" 2 \
  '{"tool_name":"WebSearch","tool_input":{"query":"public information"}}'

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
