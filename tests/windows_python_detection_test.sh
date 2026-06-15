#!/usr/bin/env bash
# Regression tests for Windows Python launcher detection.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

failures=0

fail() {
  printf 'not ok - %s\n' "$1" >&2
  failures=$((failures + 1))
}

expect_contains() {
  local name="$1"
  local file="$2"
  local pattern="$3"

  if rg -q --fixed-strings "$pattern" "$ROOT/$file"; then
    printf 'ok - %s\n' "$name"
  else
    fail "$name: missing $pattern in $file"
  fi
}

expect_windows_launcher_survives_empty_sys_executable() {
  local tmpdir
  local output
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' RETURN

  cat > "$tmpdir/py" <<'SH'
#!/usr/bin/env bash
if [[ "${1:-}" != "-3.12" ]]; then
  exit 2
fi
shift

case "${1:-}" in
  --version)
    printf 'Python 3.12.8\n'
    ;;
  -)
    cat >/dev/null
    printf '3.12.8\t\n'
    ;;
  *)
    exit 2
    ;;
esac
SH
  chmod +x "$tmpdir/py"

  output=$(
    PATH="$tmpdir:$PATH" PLATFORM=windows bash <<SH
source "$ROOT/lib/python-detect.sh"
select_python 3.10 || exit 1
printf '%s\n' "\${PY_CMD[*]}"
printf '%s\n' "\$PY_DISPLAY"
run_python --version
SH
  )

  if [[ "$output" == $'py -3.12\npy -3.12\nPython 3.12.8' ]]; then
    printf 'ok - Windows py launcher remains usable when sys.executable is empty\n'
  else
    fail "Windows py launcher fallback output mismatch"
    printf '%s\n' "$output" >&2
  fi
}

expect_windows_launcher_survives_empty_sys_executable

expect_contains "legal-books uses shared Python detection" "toolkit/legal-books/install.sh" 'source "$TOOLKIT_DIR/../../lib/python-detect.sh"'
expect_contains "case-records uses shared Python detection" "toolkit/case-records/install.sh" 'source "$TOOLKIT_DIR/../../lib/python-detect.sh"'
expect_contains "beopgoeul uses shared Python detection" "toolkit/beopgoeul/install.sh" 'source "$TOOLKIT_DIR/../../lib/python-detect.sh"'
expect_contains "court-forms uses shared Python detection" "toolkit/court-forms/install.sh" 'source "$TOOLKIT_DIR/../../lib/python-detect.sh"'

if [[ "$failures" -gt 0 ]]; then
  exit 1
fi
