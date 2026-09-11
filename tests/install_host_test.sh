#!/usr/bin/env bash
# Fake-host regression checks; never write to an actual client profile.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DEST="$(mktemp -d)"
trap 'rm -rf "$TEST_DEST"' EXIT
source "$ROOT/lib/dry-run.sh"
source "$ROOT/lib/install-host.sh"

# Detection is isolated from clients installed on the test machine.
command() {
  if [[ "${1:-}" == -v && ( "${2:-}" == claude || "${2:-}" == codex ) ]]; then
    [[ " $TEST_CLIENTS " == *" $2 "* ]]
  else
    builtin command "$@"
  fi
}
for TEST_CLIENTS in claude codex 'claude codex'; do
  JURISUPPORT_HOST=auto
  jurisupport_select_host
  expected="${TEST_CLIENTS/claude codex/both}"
  [[ "$JURISUPPORT_HOST" == "$expected" ]]
done
JURISUPPORT_HOST=claude
jurisupport_select_host --host codex
[[ "$JURISUPPORT_HOST" == codex ]]
jurisupport_select_host --host=both
[[ "$JURISUPPORT_HOST" == both ]]
if jurisupport_select_host --host unknown 2>/dev/null; then exit 1; fi
if jurisupport_select_host --host 2>/dev/null; then exit 1; fi
TEST_CLIENTS=''
if JURISUPPORT_HOST=auto jurisupport_select_host </dev/null 2>/dev/null; then exit 1; fi
(DRY_RUN=1; JURISUPPORT_HOST=auto; jurisupport_select_host </dev/null; [[ "$JURISUPPORT_HOST" == both ]]) 2>/dev/null
printf 'ok - host auto detection, explicit override, and invalid host rejection\n'

for selected in claude codex both; do
  JURISUPPORT_HOST="$selected"
  jurisupport_copy_skill "$ROOT/skills/lbox-guide" lbox-guide \
    "$TEST_DEST/$selected/claude/skills" "$TEST_DEST/$selected/codex/skills"
done
[[ -f "$TEST_DEST/claude/claude/skills/lbox-guide/SKILL.md" && ! -e "$TEST_DEST/claude/codex" ]]
[[ -f "$TEST_DEST/codex/codex/skills/lbox-guide/SKILL.md" && ! -e "$TEST_DEST/codex/claude" ]]
[[ -f "$TEST_DEST/both/codex/skills/lbox-guide/SKILL.md" && -f "$TEST_DEST/both/claude/skills/lbox-guide/SKILL.md" ]]
printf 'ok - only selected skill roots are created\n'
(
  cygpath() { [[ "$1" == -u && "$2" == 'C:\Users\Example\codex/skills' ]] && printf '/c/Users/Example/codex/skills\n'; }
  [[ "$(jurisupport_path 'C:\Users\Example\codex/skills')" == '/c/Users/Example/codex/skills' ]]
)

TEST_CLIENTS=codex
source "$ROOT/lib/install-codex.sh"
info() { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
codex() {
  printf '%s\n' "$*" >> "$TEST_DEST/codex-calls"
  [[ -z "${TEST_CODEX_FAIL:-}" || "$*" != "$TEST_CODEX_FAIL"* ]] || return 1
  if [[ "$*" == 'plugin marketplace list --json' ]]; then
    if [[ "${TEST_EXISTING_MARKETPLACE:-missing}" == missing ]]; then
      printf '{"marketplaces":[]}\n'
    else
      printf '{"marketplaces":[{"name":"jurisupport-plugins","root":"/existing/source","marketplaceSource":{"sourceType":"%s"}}]}\n' "$TEST_EXISTING_MARKETPLACE"
    fi
  fi
  return 0
}
claude() { printf 'Claude must not run\n' >&2; exit 99; }
JURISUPPORT_HOST=codex
jurisupport_install_codex "$ROOT" "$TEST_DEST/native-skills" > "$TEST_DEST/native-output"
grep -q '^plugin marketplace add ' "$TEST_DEST/codex-calls"
grep -qx 'plugin add jurisupport@jurisupport-plugins' "$TEST_DEST/codex-calls"
for skill in lbox-guide beopgoeul-search court-forms case-records clean-legal-db; do
  [[ -f "$TEST_DEST/native-skills/$skill/SKILL.md" ]]
done
[[ ! -e "$TEST_DEST/native-skills/legal-books" ]]
grep -q 'https://github.com/jurisupport/legal-books' "$TEST_DEST/native-output"
! grep -q 'toolkit/legal-books/install.sh' "$TEST_DEST/native-output"
! grep -q 'legal-books' "$TEST_DEST/codex-calls"
for TEST_CODEX_FAIL in 'plugin --help' 'plugin marketplace list' 'plugin marketplace add' 'plugin add'; do
  if jurisupport_install_codex "$ROOT" "$TEST_DEST/failure-skills" 2>/dev/null; then exit 1; fi
  [[ ! -e "$TEST_DEST/failure-skills" ]]
done
TEST_CODEX_FAIL=''
TEST_EXISTING_MARKETPLACE=git
: > "$TEST_DEST/codex-calls"
jurisupport_install_codex "$ROOT" "$TEST_DEST/existing-skills" > "$TEST_DEST/existing-output"
grep -qx 'plugin marketplace upgrade jurisupport-plugins' "$TEST_DEST/codex-calls"
! grep -q '^plugin marketplace add ' "$TEST_DEST/codex-calls"
TEST_CODEX_FAIL='plugin marketplace upgrade'
if jurisupport_install_codex "$ROOT" "$TEST_DEST/failure-skills" > /dev/null; then exit 1; fi
[[ ! -e "$TEST_DEST/failure-skills" ]]
TEST_CODEX_FAIL=''
TEST_EXISTING_MARKETPLACE=local
: > "$TEST_DEST/codex-calls"
jurisupport_install_codex "$ROOT" "$TEST_DEST/local-skills" > /dev/null
! grep -Eq '^plugin marketplace (add|upgrade) ' "$TEST_DEST/codex-calls"
TEST_EXISTING_MARKETPLACE=missing
printf 'ok - native Codex registration and error propagation without Claude\n'

output="$(
  export TEST_DEST
  export -f codex claude
  # Record destination writes, keeping the real user profile untouched.
  mkdir() { printf 'mkdir %s\n' "$*" >> "$TEST_DEST/file-calls"; }
  cp() { printf 'cp %s\n' "$*" >> "$TEST_DEST/file-calls"; }
  export -f mkdir cp
  TEST_CODEX_FAIL='' JURISUPPORT_HOST=codex bash "$ROOT/install.sh" </dev/null
)"
[[ "$output" == *'Codex 기본 플러그인과 보조 스킬 설치 완료'* ]]
! grep -q '/\.claude/' "$TEST_DEST/file-calls"
! grep -q 'legal-books' "$TEST_DEST/file-calls"
grep -Fq "${CODEX_HOME:-$HOME/.codex}/skills/clean-legal-db" "$TEST_DEST/file-calls"
printf 'ok - unattended Codex entry point uses fake client and only Codex destinations\n'

output="$(JURISUPPORT_HOST=codex bash "$ROOT/install.sh" --plan)"
[[ "$output" == *'codex plugin add jurisupport@jurisupport-plugins'* ]]
[[ "$output" != *'claude plugin'* && "$output" != *'.claude/'* ]]
output="$(JURISUPPORT_HOST=codex bash "$ROOT/bootstrap.sh" --plan)"
[[ "$output" != *'@anthropic-ai/claude-code'* && "$output" == *'--host codex'* ]]
output="$(JURISUPPORT_HOST=claude bash "$ROOT/install.sh" --plan)"
[[ "$output" == *'Hook 등록'* && "$output" != *'codex plugin add'* ]]
[[ "$output" != *"${CODEX_HOME:-$HOME/.codex}/skills/"* ]]
output="$(JURISUPPORT_HOST=codex bash "$ROOT/uninstall.sh" --yes --dry-run)"
[[ "$output" == *'codex plugin remove jurisupport@jurisupport-plugins'* ]]
[[ "$output" != *'claude plugin'* && "$output" != *'.claude/'* ]]
for toolkit in case-records clean-legal-db court-forms beopgoeul; do
  output="$(JURISUPPORT_HOST=codex bash "$ROOT/toolkit/$toolkit/install.sh" --plan)"
  [[ "$output" != *'.claude/'* ]]
  [[ "$output" == *"${CODEX_HOME:-$HOME/.codex}/skills/"* ]]
done
printf 'ok - Codex installer, bootstrap, and toolkit plans avoid Claude destinations\n'

# A Codex failure must not skip the selected Claude uninstall lane.
status=0
output="$(
  export TEST_DEST
  codex() { printf 'codex %s\n' "$*" >> "$TEST_DEST/uninstall-calls"; return 42; }
  claude() {
    printf 'claude %s\n' "$*" >> "$TEST_DEST/uninstall-calls"
    [[ "$*" != 'plugin list' ]] || printf 'jurisupport\n'
    return 0
  }
  # Redirect client filesystem checks and block every destructive operation.
  cygpath() { printf '%s/empty-profile\n' "$TEST_DEST"; }
  rm() { printf 'blocked rm %s\n' "$*" >> "$TEST_DEST/uninstall-calls"; }
  bash() { printf 'blocked toolkit script %s\n' "$*" >> "$TEST_DEST/uninstall-calls"; }
  export -f codex claude cygpath rm bash
  JURISUPPORT_HOST=auto /bin/bash "$ROOT/uninstall.sh" --yes
)" || status=$?
[[ "$status" == 42 ]]
grep -qx 'claude plugin uninstall jurisupport' "$TEST_DEST/uninstall-calls"
grep -qx 'claude mcp list' "$TEST_DEST/uninstall-calls"
[[ "$output" != *'Codex 처리 완료'* && "$output" != *'✓ 본 패키지 등록·데이터 제거 완료'* ]]
printf 'ok - both-host uninstall finishes Claude cleanup and preserves Codex failure status\n'
