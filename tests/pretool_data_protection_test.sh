#!/usr/bin/env bash
# Regression tests for hooks/pretool_data_protection.sh.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
HOOK="$ROOT/hooks/pretool_data_protection.sh"

failures=0

expect_exit() {
  local name="$1"
  local expected="$2"
  local payload="$3"
  local actual=0

  set +e
  printf '%s' "$payload" | bash "$HOOK" >/tmp/jurisupport-hook-test.out 2>/tmp/jurisupport-hook-test.err
  actual=$?
  set -e

  if [[ "$actual" == "$expected" ]]; then
    printf 'ok - %s\n' "$name"
  else
    printf 'not ok - %s: expected exit %s, got %s\n' "$name" "$expected" "$actual" >&2
    sed -n '1,8p' /tmp/jurisupport-hook-test.err >&2
    failures=$((failures + 1))
  fi
}

expect_exit \
  "WebSearch blocks Korean RRN" \
  2 \
  '{"tool_name":"WebSearch","tool_input":{"query":"홍길동 700101-1234567"}}'

expect_exit \
  "WebFetch blocks lbox.kr" \
  2 \
  '{"tool_name":"WebFetch","tool_input":{"url":"https://lbox.kr/search"}}'

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

rm -f /tmp/jurisupport-hook-test.out /tmp/jurisupport-hook-test.err

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
