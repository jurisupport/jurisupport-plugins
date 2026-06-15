#!/usr/bin/env bash
# Regression checks for the professional legal-reasoning mock-hearing workflow.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$ROOT/plugins/jurisupport/skills/mock-hearing/SKILL.md"
QUESTIONS="$ROOT/plugins/jurisupport/skills/mock-hearing/question-bank.md"
RUBRIC="$ROOT/plugins/jurisupport/skills/mock-hearing/evaluation-rubric.md"
VOICE="$ROOT/plugins/jurisupport/skills/mock-hearing/adversary-voice.md"
PLUGIN="$ROOT/plugins/jurisupport/.claude-plugin/plugin.json"
README="$ROOT/plugins/jurisupport/README.md"

for file in "$SKILL" "$QUESTIONS" "$RUBRIC" "$VOICE" "$PLUGIN" "$README"; do
  [[ -f "$file" ]] || { echo "missing file: $file" >&2; exit 1; }
done

grep -q "전문 법적 사고 계약" "$SKILL"
grep -q "청구권규범 카드" "$SKILL"
grep -q "요건사실 매트릭스" "$SKILL"
grep -q "항변·재항변 트리" "$SKILL"
grep -q "판결 유추·구별 메모" "$SKILL"
grep -q "플러그인 오케스트레이션 순서" "$SKILL"
grep -q "case-records" "$SKILL"
grep -q "court-forms" "$SKILL"

grep -q "결론→규범→요건→사실→증거→입증책임→항변/재항변→판결 유추·구별" "$QUESTIONS"
grep -q "이 결론을 허용하는 조문, 계약 조항, 법리는 무엇인가요" "$QUESTIONS"
grep -q "증거가 비는 요건은 어떤 절차로 메울 수 있나요" "$QUESTIONS"

grep -q "법적 사고 하드캡" "$RUBRIC"
grep -q "청구권규범 부재" "$RUBRIC"
grep -q "재항변 공백" "$RUBRIC"
grep -q "보강 절차 부재" "$RUBRIC"

grep -q "법적 사고 단위를 유지" "$VOICE"
grep -q "근거 없이 역할극만 하지 말 것" "$VOICE"

grep -q '"version": "0.2.9"' "$PLUGIN"
grep -q "0.2.9 - mock-hearing 법적 사고 프로토콜 강화" "$README"

echo "mock-hearing legal reasoning checks passed"
