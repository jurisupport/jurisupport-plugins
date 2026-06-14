#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/plugins/jurisupport/skills/offline-law-fallback/SKILL.md"
STATUTES="$ROOT/plugins/jurisupport/skills/offline-law-fallback/references/statutes"
INDEX="$STATUTES/INDEX.md"

[[ -f "$SKILL" ]] || { echo "missing skill: $SKILL" >&2; exit 1; }
[[ -f "$INDEX" ]] || { echo "missing index: $INDEX" >&2; exit 1; }

core_count=$(find "$STATUTES/core" -type f -name '*.md' | wc -l | tr -d ' ')
special_count=$(find "$STATUTES/special-criminal" -type f -name '*.md' | wc -l | tr -d ' ')
total_count=$(find "$STATUTES" -type f -name '*.md' ! -name 'INDEX.md' | wc -l | tr -d ' ')

[[ "$core_count" == "6" ]] || { echo "expected 6 core statutes, got $core_count" >&2; exit 1; }
[[ "$special_count" == "22" ]] || { echo "expected 22 special criminal statutes, got $special_count" >&2; exit 1; }
[[ "$total_count" == "28" ]] || { echo "expected 28 statute snapshots, got $total_count" >&2; exit 1; }

grep -q "대한민국헌법" "$INDEX"
grep -q "형사소송법" "$INDEX"
grep -q "특정범죄 가중처벌 등에 관한 법률" "$INDEX"
grep -q "제출 전.*재검증" "$SKILL"
grep -q "목차" "$STATUTES/core/criminal-act.md"
grep -q "목차" "$STATUTES/core/civil-act.md"
grep -q "목차" "$STATUTES/core/commercial-act.md"

echo "offline-law-fallback snapshot check passed"
