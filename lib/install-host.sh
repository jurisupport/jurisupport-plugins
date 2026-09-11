#!/usr/bin/env bash
# Shared host selection for installers. Does not load or change a client profile.
jurisupport_select_host() {
  local selected="${JURISUPPORT_HOST:-auto}"
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --host)
        [[ $# -gt 1 ]] || { echo 'ERROR: --host claude|codex|both' >&2; return 1; }
        selected="$2"; shift ;;
      --host=*) selected="${1#*=}" ;;
    esac
    shift
  done
  if [[ "$selected" == auto ]]; then
    selected=''
    command -v claude >/dev/null 2>&1 && selected=claude
    if command -v codex >/dev/null 2>&1; then
      if [[ "$selected" == claude ]]; then selected=both; else selected=codex; fi
    fi
    if [[ -z "$selected" ]]; then
      if [[ "${DRY_RUN:-0}" =~ ^(1|true|yes)$ ]]; then
        selected=both
        echo 'PLAN: 설치된 CLI가 없어 두 호스트의 계획을 표시합니다. --host로 선택할 수 있습니다.' >&2
      elif [[ -t 0 ]]; then
        read -r -p '사용할 앱을 선택하세요 (claude/codex/both): ' selected || return 1
      else
        echo 'ERROR: 설치 대상이 필요합니다. --host claude|codex|both 또는 JURISUPPORT_HOST를 지정하세요.' >&2
        return 1
      fi
    fi
  fi
  case "$selected" in
    claude|codex|both) export JURISUPPORT_HOST="$selected" ;;
    *) echo "ERROR: 알 수 없는 호스트: $selected (claude|codex|both)" >&2; return 1 ;;
  esac
}

jurisupport_has_host() {
  [[ "$JURISUPPORT_HOST" == "$1" || "$JURISUPPORT_HOST" == both ]]
}

# Windows desktop config roots may use C:\... while these installers use Git Bash.
jurisupport_path() {
  if command -v cygpath >/dev/null 2>&1; then cygpath -u "$1"; else printf '%s\n' "$1"; fi
}

jurisupport_skill_roots() {
  if jurisupport_has_host claude; then jurisupport_path "${1:-${CLAUDE_CONFIG_DIR:-$HOME/.claude}/skills}"; fi
  if jurisupport_has_host codex; then jurisupport_path "${2:-${CODEX_HOME:-$HOME/.codex}/skills}"; fi
}

jurisupport_copy_skill() {
  local source_dir="$1" name="$2" skill_root
  while IFS= read -r skill_root; do
    run_or_plan mkdir -p "$skill_root/$name" || return 1
    run_or_plan cp -R "$source_dir/." "$skill_root/$name/" || return 1
  done < <(jurisupport_skill_roots "${3:-}" "${4:-}")
}
