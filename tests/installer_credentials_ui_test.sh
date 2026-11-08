#!/usr/bin/env bash
# Exercise installer UI handoff without real credentials, profiles or network.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/root with spaces/lib"
cat > "$TMP/root with spaces/lib/python-detect.sh" <<'SH'
select_python() { [[ "$1" == 3.9 ]]; }
run_python() {
  printf '%s\n' "$@" > "$TEST_CALLS"
  return "$TEST_UI_EXIT"
}
SH
awk '/^configure_credentials\(\) \{/ { active=1 } active { print } active && /^}/ { exit }' \
  "$ROOT/install.sh" > "$TMP/function.sh"
for result in 0 1 2; do
  actual=0
  TEST_CALLS="$TMP/calls" TEST_UI_EXIT="$result" TOOLKIT_DIR="$TMP/root with spaces" \
    bash -c 'source "$1"; configure_credentials --service jurisupport' _ "$TMP/function.sh" || actual=$?
  [[ "$actual" == "$result" ]]
  [[ "$(sed -n '1p' "$TMP/calls")" == "$TMP/root with spaces/scripts/configure_credentials.py" ]]
  [[ "$(sed -n '2p' "$TMP/calls")" == --service ]]
  [[ "$(sed -n '3p' "$TMP/calls")" == jurisupport ]]
done
printf 'ok - installer UI handoff preserves paths and success/error/cancel status\n'

awk '
  /^JURI_SIGNUP_URL=/ { active=1 }
  active && /^# Recommended:/ { exit }
  active { print }
' "$ROOT/install.sh" > "$TMP/step12.sh"
for result in 0 2; do
  TEST_CALLS="$TMP/step-calls" TEST_UI_EXIT="$result" bash -c '
    is_dry_run() { return 1; }
    claude() { [[ "$*" == "mcp list" ]]; }
    prompt_read() { printf -v "$1" Y; }
    configure_credentials() { printf "%s\n" "$*" >> "$TEST_CALLS"; return "$TEST_UI_EXIT"; }
    open_url() { echo "Unexpected browser launch" >&2; return 99; }
    info() { printf "%s\n" "$*"; }
    warn() { printf "%s\n" "$*"; }
    source "$1"
  ' _ "$TMP/step12.sh" > "$TMP/output"
  grep -qx -- '--service jurisupport' "$TMP/step-calls"
  if [[ "$result" == 0 ]]; then
    grep -q '설정 저장 완료' "$TMP/output"
    ! grep -q '인증 성공' "$TMP/output"
  else
    grep -q '등록 미완료' "$TMP/output"
  fi
done
printf 'ok - JuriSupport step keeps cancellation nonfatal and distinguishes save from authentication\n'

mkdir -p "$TMP/book-source/toolkit"
touch "$TMP/book-source/toolkit/install.sh"
awk '
  /    if \[\[ -f "\$LEGAL_BOOKS_SRC\/toolkit\/install.sh" \]\]; then/ { active=1 }
  active { print }
  active && /^    fi$/ { exit }
' "$ROOT/install.sh" > "$TMP/books.sh"
for scenario in existing saved cancelled; do
  : > "$TMP/book-calls"
  TEST_SCENARIO="$scenario" TEST_CALLS="$TMP/book-calls" LEGAL_BOOKS_SRC="$TMP/book-source" \
    bash -c '
      warn() { :; }
      configure_credentials() {
        printf "%s\n" "$*" >> "$TEST_CALLS"
        if [[ "$*" == *--check ]]; then [[ "$TEST_SCENARIO" == existing ]];
        else [[ "$TEST_SCENARIO" == saved ]]; fi
      }
      bash() { printf "upstream-installer\n" >> "$TEST_CALLS"; }
      source "$1"
    ' _ "$TMP/books.sh"
  if [[ "$scenario" == cancelled ]]; then
    ! grep -qx upstream-installer "$TMP/book-calls"
  else
    grep -qx upstream-installer "$TMP/book-calls"
  fi
  if [[ "$scenario" == existing ]]; then
    ! grep -qx -- '--service gemini' "$TMP/book-calls"
  fi
done
printf 'ok - legal-books never launches its terminal-key installer without a saved Gemini key\n'

awk '/^install_ecourt_tools\(\) \{/ { active=1 } active { print } active && /^}/ { exit }' \
  "$ROOT/install.sh" > "$TMP/ecourt.sh"
mkdir -p "$TMP/ecfs/.git"
touch "$TMP/ecfs/install.sh"
printf 'must-not-reach-upstream\n' | TEST_CALLS="$TMP/ecfs-calls" ECFS_SKILL_DIR="$TMP/ecfs" \
  bash -c '
    PLATFORM=mac
    env_truthy() { return 1; }
    is_dry_run() { return 1; }
    ecourt_tool_installed() { return 1; }
    info() { :; }
    warn() { echo "$*" >&2; }
    prompt_read() { printf -v "$1" Y; }
    git() { return 0; }
    bash() {
      if read -r value; then echo "Upstream received input" >&2; return 1; fi
      printf "runtime-no-stdin\n" >> "$TEST_CALLS"
    }
    configure_credentials() {
      printf "%s\n" "$*" >> "$TEST_CALLS"
      [[ "$*" != *--check ]]
    }
    source "$1"
    install_ecourt_tools
  ' _ "$TMP/ecourt.sh"
grep -qx runtime-no-stdin "$TMP/ecfs-calls"
grep -qx -- '--service ecfs-cert' "$TMP/ecfs-calls"
printf 'ok - ecfs runtime installer gets no terminal input and uses certificate UI afterward\n'
