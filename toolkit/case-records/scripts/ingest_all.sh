#!/usr/bin/env bash
# Batch-index all case folders under a root directory.
# Detects already-indexed cases and skips them.

set -euo pipefail

ROOT_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --root) ROOT_DIR="$2"; shift 2 ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "${ROOT_DIR:-}" ]]; then
  echo "Required: --root <path>" >&2; exit 1
fi
ROOT_DIR="${ROOT_DIR/#\~/$HOME}"

CASE_ROOT="$HOME/case-records"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Pull list of already-indexed case_ids (Python으로 sqlite3 CLI 의존성 제거 — Windows 호환)
case "$(uname -s)" in
  MINGW*|MSYS*|CYGWIN*) PY=python ;;
  *)                    PY=python3 ;;
esac
INDEXED=$("$PY" -c "
import sqlite3
try:
    con = sqlite3.connect(r'$CASE_ROOT/db/cases_fts.db')
    for (cid,) in con.execute('SELECT case_id FROM cases'):
        print(cid)
except Exception:
    pass
" 2>/dev/null || echo "")

shopt -s nullglob
for CDIR in "$ROOT_DIR"/*/; do
  # Folder name pattern: {case_id}_{name}_{summary} OR {case_id}_{rest}
  BASE=$(basename "$CDIR")
  CASE_ID=$(echo "$BASE" | cut -d_ -f1)
  CASE_NAME=$(echo "$BASE" | cut -d_ -f2- | tr '_' ' ')

  # Skip non-case folders (e.g. starts with _)
  [[ "$BASE" == _* ]] && continue

  # Skip if already indexed
  if echo "$INDEXED" | grep -qx "$CASE_ID"; then
    echo "[skip] $CASE_ID (already indexed)"
    continue
  fi

  echo "[ingest] $CASE_ID — $CASE_NAME"
  "$SCRIPT_DIR/ingest_case.sh" \
    --case-dir "$CDIR" \
    --case-id "$CASE_ID" \
    --case-name "$CASE_NAME" || echo "[warn] failed: $CASE_ID"
done
