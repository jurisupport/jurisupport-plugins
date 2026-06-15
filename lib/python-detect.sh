#!/usr/bin/env bash
# Shared Python detection for installers.
#
# Windows Git Bash can run `py -3.12` even when `sys.executable` is empty or
# awkward to convert. Keep the selected command as an argv array instead of
# trying to collapse it into one executable path.

PY_CMD=()
PY_VERSION=""
PY_EXE=""
PY_DISPLAY=""

_try_python_candidate() {
  local min_version="$1"
  shift

  command -v "$1" >/dev/null 2>&1 || return 1

  local probe
  if ! probe="$("$@" - <<'PY' 2>/dev/null
import sys
print(f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}\t{sys.executable or ''}")
PY
)"; then
    return 1
  fi

  if ! "$@" - "$min_version" <<'PY' >/dev/null 2>&1; then
import sys

want = tuple(int(part) for part in sys.argv[1].split("."))
have = sys.version_info[: len(want)]
raise SystemExit(0 if have >= want else 1)
PY
    return 1
  fi

  probe="${probe//$'\r'/}"
  [[ "$probe" == *$'\t'* ]] || return 1
  PY_VERSION="${probe%%$'\t'*}"
  PY_EXE="${probe#*$'\t'}"
  PY_CMD=("$@")
  PY_DISPLAY="${PY_EXE:-$*}"
  return 0
}

select_python() {
  local min_version="${1:-3.10}"
  PY_CMD=()
  PY_VERSION=""
  PY_EXE=""
  PY_DISPLAY=""

  if [[ "${PLATFORM:-}" == "windows" ]]; then
    _try_python_candidate "$min_version" py -3.12 ||
      _try_python_candidate "$min_version" py -3.11 ||
      _try_python_candidate "$min_version" py -3 ||
      _try_python_candidate "$min_version" python3 ||
      _try_python_candidate "$min_version" python
  else
    _try_python_candidate "$min_version" python3 ||
      _try_python_candidate "$min_version" python
  fi
}

run_python() {
  if [[ "${#PY_CMD[@]}" -eq 0 ]]; then
    echo "Python command not selected. Call select_python first." >&2
    return 127
  fi
  "${PY_CMD[@]}" "$@"
}
