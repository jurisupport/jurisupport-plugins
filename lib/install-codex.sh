#!/usr/bin/env bash
# Native core install; optional toolkit runtimes and MCP credentials are separate.
jurisupport_install_codex() {
  local repo="$1" skills_root="${2:-${CODEX_HOME:-$HOME/.codex}/skills}" skill marketplaces source_type
  skills_root="$(jurisupport_path "$skills_root")" || return 1
  if ! is_dry_run; then
    command -v codex >/dev/null 2>&1 || { warn 'Codex CLI가 필요합니다. bootstrap.sh --host codex로 설치하세요.'; return 1; }
    command -v node >/dev/null 2>&1 || { warn '설치 확인에 Node.js가 필요합니다. bootstrap.sh --host codex로 준비하세요.'; return 1; }
    [[ -f "$repo/.agents/plugins/marketplace.json" && -f "$repo/plugins/jurisupport/.codex-plugin/plugin.json" ]] || {
      warn 'Codex 플러그인 설치 정의가 없습니다. 전체 저장소를 다시 받으세요.'; return 1;
    }
    codex plugin --help >/dev/null 2>&1 || { warn '플러그인을 지원하는 최신 Codex CLI로 업데이트하세요.'; return 1; }
  fi
  if is_dry_run; then
    info_or_plan '기존 Git 소스는 갱신(upgrade), 로컬 소스는 유지; 등록이 없으면 이 저장소 추가'
    run_or_plan codex plugin marketplace add "$repo"
  else
    marketplaces="$(codex plugin marketplace list --json)" || return 1
    source_type="$(printf '%s' "$marketplaces" | node -e '
      const data = JSON.parse(require("fs").readFileSync(0, "utf8"));
      const entry = data.marketplaces.find(item => item.name === "jurisupport-plugins");
      console.log(entry ? (entry.marketplaceSource?.sourceType || "unknown") : "missing");
    ')" || return 1
    case "$source_type" in
      missing) codex plugin marketplace add "$repo" || return 1 ;;
      git)
        info '기존 jurisupport-plugins Git 소스를 유지하여 갱신합니다. 로컬 저장소로 교체하지 않습니다.'
        codex plugin marketplace upgrade jurisupport-plugins || return 1 ;;
      local) info '기존 jurisupport-plugins 로컬 소스를 그대로 사용합니다.' ;;
      *) warn '기존 marketplace 소스를 확인하지 못했습니다. codex plugin marketplace list --json 으로 확인하세요.'; return 1 ;;
    esac
  fi
  run_or_plan codex plugin add jurisupport@jurisupport-plugins || return 1
  for skill in lbox-guide beopgoeul-search court-forms case-records clean-legal-db; do
    run_or_plan mkdir -p "$skills_root/$skill" || return 1
    run_or_plan cp -R "$repo/skills/$skill/." "$skills_root/$skill/" || return 1
  done
  info_or_plan 'Codex 기본 플러그인과 보조 스킬 설치 완료'
  cat <<EOF

다음 단계: Codex에서 새 작업을 열고 “JuriSupport 콜드스타트를 시작해줘”라고 요청하세요.
현재 작업의 모델(Astra/Sol 등)을 그대로 사용합니다.
검색 서버·DB·Chrome 등 선택 toolkit은 이 단계에서 설치하지 않았습니다.
필요한 도구만 추가 설치하세요 (기존 데이터/설치 여부는 각 도구에서 확인):
  bash "$repo/toolkit/case-records/install.sh" --host codex
  bash "$repo/toolkit/court-forms/install.sh" --host codex
  bash "$repo/toolkit/beopgoeul/install.sh" --host codex
  bash "$repo/toolkit/clean-legal-db/install.sh" --host codex

legal-books는 선택 외부 플러그인입니다: https://github.com/jurisupport/legal-books
이번 설치에서는 추가하지 않았습니다. 해당 저장소에서 Codex 지원 여부와 설치 방법을 확인하세요.

JuriSupport / korean-law MCP는 별도 계정·키 연결이며 이번 단계에서는 변경하지 않았습니다.
토큰 연결은 아래 한 줄이 Claude Code·Codex에 함께 등록합니다 (토큰 갱신도 같은 명령):
  curl -fsSL https://raw.githubusercontent.com/jurisupport/jurisupport-lawyer-profile-plugin/main/connect-mcp.sh | bash
환경변수 방식을 쓰려면 Codex 앱을 시작하는 환경에 JURISUPPORT_MCP_TOKEN이 유지되어야 합니다:
  codex mcp add jurisupport --url https://api.jurisupport.com/mcp --bearer-token-env-var JURISUPPORT_MCP_TOKEN
단순 등록/목록 조회는 인증 성공이 아닙니다. 새 작업에서 실제 조회로 확인하세요.
법령 API 미연결 시 offline-law-fallback은 실습용이며 실제 제출 전 공식 근거를 재검증하세요.
데이터 보호 Hook은 Claude 전용입니다. Codex에서는 호스트 권한 정책과 공통 스킬 지침을 따릅니다.
EOF
}
