#!/usr/bin/env bash
# Shared dry-run helpers for all jurisupport-plugins installers.
# Usage: source "$(dirname "${BASH_SOURCE[0]}")/../lib/dry-run.sh" "$@"
#
# Provides:
#   is_dry_run          — returns 0 if --plan/--dry-run/DRY_RUN env is set
#   run_or_plan CMD...  — execute CMD or print "PLAN: CMD"
#   run_shell_or_plan S — execute string via bash -c or print "PLAN: S"
#   info_or_plan MSG    — print info MSG, auto-appending "(dry-run)" suffix

_DRYRUN_PLAN_MODE=0
_DRYRUN_REMAINING_ARGS=()
for _arg in "$@"; do
  case "$_arg" in
    --plan|--dry-run) _DRYRUN_PLAN_MODE=1 ;;
    *) _DRYRUN_REMAINING_ARGS+=("$_arg") ;;
  esac
done
set -- ${_DRYRUN_REMAINING_ARGS[@]+"${_DRYRUN_REMAINING_ARGS[@]}"}

DRY_RUN="${DRY_RUN:-${JURISUPPORT_DRY_RUN:-0}}"
if [[ "$_DRYRUN_PLAN_MODE" -eq 1 ]]; then
  DRY_RUN=1
fi
export DRY_RUN

is_dry_run() {
  [[ "$DRY_RUN" == "1" || "$DRY_RUN" == "true" || "$DRY_RUN" == "yes" ]]
}

run_or_plan() {
  if is_dry_run; then
    echo "PLAN: $*"
  else
    "$@"
  fi
}

run_shell_or_plan() {
  if is_dry_run; then
    echo "PLAN: $*"
  else
    bash -c "$*"
  fi
}

info_or_plan() {
  local msg="$1"
  if is_dry_run; then
    echo -e "${GREEN:-}[info]${NC:-} $msg (dry-run: 실제 변경 없음)"
  else
    echo -e "${GREEN:-}[info]${NC:-} $msg"
  fi
}
