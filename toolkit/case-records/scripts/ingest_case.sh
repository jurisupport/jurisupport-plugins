#!/usr/bin/env bash
# Index a single case folder into case-records DB.

set -euo pipefail

ROOT="$HOME/case-records"
VENV="$ROOT/.venv/bin/activate"

CASE_DIR=""; CASE_ID=""; CASE_NAME=""; STATUS=""; RESULT=""; COURT=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --case-dir)   CASE_DIR="$2"; shift 2 ;;
    --case-id)    CASE_ID="$2"; shift 2 ;;
    --case-name)  CASE_NAME="$2"; shift 2 ;;
    --status)     STATUS="$2"; shift 2 ;;
    --result)     RESULT="$2"; shift 2 ;;
    --court)      COURT="$2"; shift 2 ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

for v in CASE_DIR CASE_ID CASE_NAME; do
  if [[ -z "${!v}" ]]; then
    echo "Required: --case-dir --case-id --case-name" >&2; exit 1
  fi
done

# Expand ~
CASE_DIR="${CASE_DIR/#\~/$HOME}"
[[ -d "$CASE_DIR" ]] || { echo "Case dir not found: $CASE_DIR" >&2; exit 1; }

# shellcheck disable=SC1090
source "$VENV"
python3 "$ROOT/scripts/ingest_case.py" \
  --case-dir "$CASE_DIR" \
  --case-id "$CASE_ID" \
  --case-name "$CASE_NAME" \
  --status "${STATUS:-진행중}" \
  --result "${RESULT:-}" \
  --court "${COURT:-}"
