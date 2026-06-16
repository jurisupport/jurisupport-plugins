#!/usr/bin/env bash
# Index matching case folders from received records and office-authored drafts.

set -euo pipefail

ROOT="$HOME/case-records"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RECORD_ROOT=""
DRAFT_ROOT=""
DOC_SCOPE="target"
ALLOW_EXTERNAL_EMBEDDING=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --record-root) RECORD_ROOT="$2"; shift 2 ;;
    --draft-root)  DRAFT_ROOT="$2"; shift 2 ;;
    --doc-scope)   DOC_SCOPE="$2"; shift 2 ;;
    --allow-external-embedding) ALLOW_EXTERNAL_EMBEDDING=1; shift ;;
    *) echo "Unknown: $1" >&2; exit 1 ;;
  esac
done

if [[ -z "$RECORD_ROOT" && -z "$DRAFT_ROOT" ]]; then
  echo "Required: --record-root and/or --draft-root" >&2
  exit 1
fi

RECORD_ROOT="${RECORD_ROOT/#\~/$HOME}"
DRAFT_ROOT="${DRAFT_ROOT/#\~/$HOME}"

case_id_from_dir() {
  basename "$1" | cut -d_ -f1
}

case_name_from_dir() {
  basename "$1" | cut -d_ -f2- | tr '_' ' '
}

ingest_root() {
  local root="$1"
  local source_kind="$2"
  [[ -n "$root" ]] || return 0
  [[ -d "$root" ]] || { echo "[warn] root not found: $root" >&2; return 0; }

  shopt -s nullglob
  for cdir in "$root"/*/; do
    local base case_id case_name
    base="$(basename "$cdir")"
    [[ "$base" == _* ]] && continue
    case_id="$(case_id_from_dir "$cdir")"
    case_name="$(case_name_from_dir "$cdir")"
    [[ -n "$case_name" && "$case_name" != "$case_id" ]] || case_name="$case_id"

    echo "[sync] $source_kind $case_id — $case_name"
    extra=()
    if [[ "$ALLOW_EXTERNAL_EMBEDDING" == "1" ]]; then
      extra+=(--allow-external-embedding)
    fi
    "$SCRIPT_DIR/ingest_case.sh" \
      --case-dir "$cdir" \
      --case-id "$case_id" \
      --case-name "$case_name" \
      --source-kind "$source_kind" \
      --doc-scope "$DOC_SCOPE" \
      "${extra[@]}" || echo "[warn] failed: $source_kind $case_id" >&2
  done
}

[[ -d "$ROOT" ]] || { echo "case-records is not installed. Run toolkit/case-records/install.sh first." >&2; exit 1; }
ingest_root "$RECORD_ROOT" record
ingest_root "$DRAFT_ROOT" draft
