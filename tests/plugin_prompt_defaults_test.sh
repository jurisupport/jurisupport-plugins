#!/usr/bin/env bash
# Regression checks for shared model inheritance and JuriSupport safety gates.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PLUGIN_ROOT="$ROOT/plugins/jurisupport"
SKILLS="$PLUGIN_ROOT/skills"
CLAUDE_MANIFEST="$PLUGIN_ROOT/.claude-plugin/plugin.json"
CODEX_MANIFEST="$PLUGIN_ROOT/.codex-plugin/plugin.json"
README="$PLUGIN_ROOT/README.md"
TEMPLATE="$PLUGIN_ROOT/CLAUDE.md.example"

skill_names=(
  brief-protocol
  case-index
  cold-start-interview
  complete-personal-profile
  mock-hearing
  offline-law-fallback
  records-sync
  upload-to-jurisupport
)

for skill_name in "${skill_names[@]}"; do
  skill="$SKILLS/$skill_name/SKILL.md"
  [[ -f "$skill" ]] || { echo "missing skill: $skill" >&2; exit 1; }
  awk '
    NR == 1 && $0 == "---" { in_frontmatter = 1; next }
    in_frontmatter && $0 == "---" { exit }
    in_frontmatter && /^(model|effort|effortLevel):/ { exit 1 }
  ' "$skill" || { echo "model routing must stay session-wide: $skill" >&2; exit 1; }
  grep -q '^name: ' "$skill" || { echo "missing skill name: $skill" >&2; exit 1; }
done

grep -Fq '~/.jurisupport/playbook.md' "$TEMPLATE" || {
  echo "template still points at the legacy playbook path" >&2
  exit 1
}

for skill in \
  "$SKILLS/cold-start-interview/SKILL.md" \
  "$SKILLS/brief-protocol/SKILL.md" \
  "$SKILLS/mock-hearing/SKILL.md" \
  "$SKILLS/case-index/SKILL.md" \
  "$SKILLS/records-sync/SKILL.md"; do
  grep -Fq '~/.jurisupport/playbook.md' "$skill" || {
    echo "canonical playbook path missing: $skill" >&2
    exit 1
  }
  if grep -Fq 'CLAUDE.md §' "$skill"; then
    echo "legacy playbook section reference remains: $skill" >&2
    exit 1
  fi
done

grep -Fq '"model": "opus"' "$README"
grep -Fq '"effortLevel": "high"' "$README"
grep -Fq 'claude --model fable --effort high' "$README"
grep -Fq '삭제하지 않는다' "$SKILLS/cold-start-interview/SKILL.md"
grep -Fq '이 단계는 강제. 절대 스킵하지 않음.' "$SKILLS/brief-protocol/SKILL.md"
grep -Fq '법원 전자제출' "$SKILLS/brief-protocol/SKILL.md"
grep -Fq '정본을 만들거나 외부로 보내지 않는다.' "$SKILLS/mock-hearing/SKILL.md"
grep -Fq 'Do not upload raw case files.' "$SKILLS/complete-personal-profile/SKILL.md"
grep -Fq 'Web consent is mandatory.' "$SKILLS/upload-to-jurisupport/SKILL.md"

version="$(python3 - "$CLAUDE_MANIFEST" "$CODEX_MANIFEST" <<'PY'
import json
import sys

versions = []
for path in sys.argv[1:]:
    with open(path, encoding="utf-8") as handle:
        versions.append(json.load(handle)["version"])
if len(set(versions)) != 1:
    raise SystemExit(f"manifest version mismatch: {versions}")
print(versions[0])
PY
)"
grep -Fq "$version - " "$README" || {
  echo "README does not list manifest version $version" >&2
  exit 1
}

echo "plugin prompt defaults checks passed"
