#!/usr/bin/env bash
# Data Protection PreToolUse Hook
#
# Detects attempts to send Korean PII (RRN, case numbers, phone) or upload
# case-file contents to external services. Blocks or warns the user.
#
# Install: see hooks/INSTALL.md (registers in ~/.claude/settings.json under
# hooks.PreToolUse). Make this file executable: chmod +x pretool_data_protection.sh

set -euo pipefail

# Hook input is JSON via stdin
INPUT="$(cat)"

# Parse fields with jq (required)
if ! command -v jq >/dev/null 2>&1; then
  echo "data-protection hook: jq is required but not installed. Run: brew install jq" >&2
  exit 0   # do not block; just warn
fi

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""')
TOOL_INPUT=$(echo "$INPUT" | jq -r '.tool_input // {} | tostring')

# Combine all tool input fields into one searchable string
HAYSTACK="$TOOL_INPUT"

# ============================================================
# Detection patterns
# ============================================================

# Korean RRN: 6 digits - 7 digits
PATTERN_RRN='[0-9]{6}-[0-9]{7}'

# Korean case number: YYYY + Korean characters + digits
# 예: 2025가합10737, 2024구합76188, 2025느합1050
PATTERN_CASE='[0-9]{4}[가-힣]{1,3}[0-9]{3,}'

# Korean mobile: 01X-XXXX-XXXX (with or without hyphens)
PATTERN_PHONE='01[0-9][- ]?[0-9]{3,4}[- ]?[0-9]{4}'

# ============================================================
# Tool classification
# ============================================================

# Tools that send data to external services
EXTERNAL_TOOLS=(
  "WebFetch"
  "WebSearch"
  "mcp__google-workspace__gmail_send"
  "mcp__google-workspace__gmail_sendDraft"
  "mcp__google-workspace__chat_sendMessage"
  "mcp__google-workspace__chat_sendDm"
  "mcp__claude_ai_Gmail__create_draft"
  "mcp__plugin_telegram_telegram__reply"
)

is_external_tool=false
for t in "${EXTERNAL_TOOLS[@]}"; do
  if [[ "$TOOL_NAME" == "$t" ]]; then
    is_external_tool=true
    break
  fi
done

# ============================================================
# Decision
# ============================================================

if ! $is_external_tool; then
  # Local tool — no check
  exit 0
fi

# ============================================================
# (1) Restricted domain check — lbox.kr only
# lbox.kr 자동화는 이용약관 위반 위험. 법고을(lx.scourt.go.kr)은
# 검색 URL 생성·페이지 조회까지는 허용 (정부 공개 사이트).
# ============================================================
RESTRICTED_DOMAINS=("lbox.kr")

if [[ "$TOOL_NAME" == "WebFetch" || "$TOOL_NAME" == "WebSearch" ]]; then
  for DOMAIN in "${RESTRICTED_DOMAINS[@]}"; do
    if echo "$HAYSTACK" | grep -qiE "$DOMAIN"; then
      cat <<EOF >&2
╔══════════════════════════════════════════════════════════════╗
║  🚫 lbox.kr 자동화 접근 차단                                  ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  lbox.kr에 LLM이 자동 접근하는 것은 이용약관 위반            ║
║  위험이 있어 차단됩니다.                                     ║
║                                                              ║
║  사용자가 직접 브라우저로 lbox.kr에 로그인하여 검색하고,     ║
║  결과 PDF를 사건폴더에 저장한 뒤 클로드에 분석을 요청하세요. ║
║                                                              ║
║  무료 대안: 법고을(https://lx.scourt.go.kr) 우선 시도        ║
║                                                              ║
║  안내: skills/lbox-guide/SKILL.md                            ║
║         guides/06_precedent_search.md                        ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF
      exit 2
    fi
  done
fi

# ============================================================
# (2) Korean PII pattern check
# ============================================================
DETECTED=()
if echo "$HAYSTACK" | grep -qE "$PATTERN_RRN"; then
  DETECTED+=("주민등록번호 (RRN)")
fi
if echo "$HAYSTACK" | grep -qE "$PATTERN_CASE"; then
  DETECTED+=("사건번호")
fi
if echo "$HAYSTACK" | grep -qE "$PATTERN_PHONE"; then
  DETECTED+=("휴대전화번호")
fi

if [[ ${#DETECTED[@]} -eq 0 ]]; then
  # No PII detected
  exit 0
fi

# ============================================================
# Block & warn
# ============================================================

DETECTED_LIST=$(printf '%s, ' "${DETECTED[@]}")
DETECTED_LIST="${DETECTED_LIST%, }"

cat <<EOF >&2
╔══════════════════════════════════════════════════════════════╗
║  ⚠️  데이터 보호 Hook 차단                                    ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  외부 서비스로 전송하려는 데이터에 다음 개인정보 패턴이      ║
║  감지되었습니다:                                             ║
║                                                              ║
║    감지: $DETECTED_LIST
║                                                              ║
║  도구: $TOOL_NAME
║                                                              ║
║  외부 전송 시 의뢰인 정보가 노출될 위험이 있습니다.          ║
║  정말 전송하려면 의뢰인 정보를 마스킹하거나 제거한 뒤       ║
║  다시 시도하세요.                                            ║
║                                                              ║
║  자세한 안내: ~/jurisupport-plugins/guides/00_security.md  ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
EOF

# Exit code 2 → block the tool call (Claude Code convention)
exit 2
