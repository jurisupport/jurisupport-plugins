# 보안 보장범위 조정안

작성일: 2026-05-24
대상 보고서: `.omx/reports/security-review-20260524.md`

## 기준

보안 이슈를 두 갈래로 나눈다.

1. **보장범위를 줄여도 되는 것**
   - 현재 문서나 README가 실제 구현보다 강하게 말한 경우.
   - 사용자가 기능을 잃지 않고, 더 정직한 설명만으로 위험을 줄일 수 있는 경우.
   - 즉시 조치: 문서/문구 수정, 과장 표현 제거, 미구현 옵션 삭제.

2. **보장범위를 바꿔서 해결할 것**
   - 단순히 "보장하지 않음"으로 낮추면 제품 신뢰나 변호사 비밀유지에 치명적인 경우.
   - 보장 문구를 더 정확한 형태로 재정의하고, 그 보장을 실제 코드로 맞춰야 하는 경우.
   - 즉시 조치: 정책 재정의 + 코드/테스트 보완.

## A. 보장범위를 줄여도 되는 것

### A-1. "데이터 보호 Hook이 외부 유출을 자동 차단" 표현

현재 표현:
- README는 의뢰인 정보가 데이터 보호 Hook으로 외부 유출 자동 차단된다고 설명한다.

줄일 보장:
- "데이터 보호 Hook은 알려진 외부 도구와 일부 한국형 식별정보 패턴을 탐지해 차단하는 보조 안전장치입니다. 완전한 유출 방지 장치가 아닙니다."

이유:
- 모든 외부 도구, 모든 파일 업로드, 모든 비정형 개인정보를 차단한다고 보장하기 어렵다.
- README 하단에는 이미 "완전한 유출 방지를 보장하지 않음" 면책이 있으므로 상단 문구도 같은 톤으로 맞추면 된다.

관련 이슈:
- H-1, H-2

### A-2. 파일 업로드 도구의 사건폴더 차단 보장

현재 표현:
- `guides/00_security.md`는 사건폴더 파일을 외부로 업로드하면 hook이 차단한다고 설명한다.

줄일 보장:
- "현재 hook은 파일 경로 기반 업로드 차단을 보장하지 않습니다. 외부 발송/업로드 전 사용자가 사건자료 포함 여부를 확인해야 합니다."

이유:
- 현재 구현에는 파일 업로드 도구 분류와 사건폴더 경로 검사가 없다.
- 파일 업로드 차단을 제대로 하려면 도구별 `tool_input` 구조를 알아야 하므로 별도 구현 과제로 분리하는 편이 안전하다.

관련 이슈:
- H-2

### A-3. lbox Bash/curl 자동화 hook 차단 보장

현재 표현:
- `guides/06_precedent_search.md`는 Bash 접근도 hook이 차단한다고 설명한다.

줄일 보장:
- "hook은 현재 WebFetch/WebSearch의 lbox.kr 접근을 차단합니다. Bash/curl/playwright 접근은 스킬 정책상 금지하며, 별도 hook 강화 전까지 기술적으로 완전 차단하지 않습니다."

이유:
- Bash 명령 문자열 전체를 안전하게 판정하는 것은 오탐과 누락이 모두 있다.
- lbox 자동화 금지는 스킬 hard stop과 문서 지침으로 유지하되, hook 보장은 현재 구현 수준으로 낮춘다.

관련 이슈:
- M-4

### A-4. `legal-books`의 "책 본문 외부 전송 없음" 표현

현재 표현:
- `guides/02_book_scanning.md`는 책 PDF·청크는 모두 로컬 저장이고 검색 시 쿼리만 Gemini로 간다고 설명한다.

줄일 보장:
- "책 추가/인덱싱 단계에서는 책 본문 chunk가 Gemini 임베딩 API로 전송됩니다. 검색 단계에서는 query만 전송됩니다."

이유:
- 법률서적은 사건기록보다 비밀정보 위험은 낮지만, 저작권·계약상 위험은 남는다.
- 외부 임베딩을 계속 쓰려면 전송 시점을 정확히 알리는 것이 핵심이다.

관련 이슈:
- L-1

### A-5. 미구현 옵션 문서

현재 표현:
- `install.sh`에서 로컬 임베딩 모델을 선택할 수 있다고 설명한다.
- `--meta-from-filename none` 옵션이 있다고 설명한다.
- HWP를 자체 변환한다고 설명한다.

줄일 보장:
- 구현 전까지 해당 옵션 설명을 제거한다.
- HWP/HWPX는 "현재 자동 추출하지 않고 건너뜀"으로 설명한다.

이유:
- 보안 기능 선택지가 있다고 믿게 만드는 문서는 실제 위험 판단을 흐린다.

관련 이슈:
- L-2

### A-6. 한 줄 설치의 신뢰 보장

현재 표현:
- README는 `curl | bash`, `irm | iex`를 빠른 시작으로 전면 배치한다.

줄일 보장:
- "빠른 설치용이며, 보안이 엄격한 환경에서는 tag 고정 다운로드, 스크립트 사전 검토, 수동 설치를 권장합니다."

이유:
- 공급망 전체를 이 저장소가 보장할 수 없다.
- 기업/사무소용 secure install path를 별도로 두는 것이 현실적이다.

관련 이슈:
- M-5

## B. 보장범위를 바꿔서 해결할 것

### B-1. `case-records` 외부 전송 보장

현재 문제:
- 문서는 사건 본문 외부 전송이 없다고 말하지만, 실제 ingestion은 사건기록 chunk를 Gemini로 보낸다.

바꿀 보장:
- 기본 보장: "case-records는 기본 설정에서 사건 본문을 외부 임베딩 API로 보내지 않는다."
- 선택 보장: "사용자가 명시 동의하면 Gemini 임베딩을 사용할 수 있고, 그때 어떤 자료가 전송되는지 사전에 표시한다."

필요 조치:
- `case-records` ingestion 기본값을 외부 임베딩 비활성 또는 명시 동의 필수로 변경.
- `--allow-external-embedding` 같은 명시 플래그 추가.
- 동의 없이 `embed_content(contents=batch)`가 호출되지 않는 테스트 추가.
- 로컬 임베딩 옵션을 실제 구현하거나, 구현 전에는 "검색 품질 제한"을 명확히 안내.

관련 이슈:
- C-1

### B-2. 데이터 보호 hook의 외부 도구 판정 보장

현재 문제:
- 설치 matcher와 hook 내부 외부도구 목록이 달라, hook이 호출되어도 내부에서 통과시키는 도구가 있다.

바꿀 보장:
- "hook이 호출된 도구는 기본적으로 외부 전송 후보로 간주하고 PII 검사를 수행한다. 명시적으로 안전한 로컬 도구만 예외 처리한다."

필요 조치:
- 설치 matcher와 hook 내부 정책을 하나의 source of truth로 통합.
- Google Drive, Claude Gmail 변형, workspace 도구를 fixture로 테스트.
- 알 수 없는 `mcp__...` 외부 도구는 fail-safe 방향으로 처리.

관련 이슈:
- H-1

### B-3. secret 파일 커밋 방지 보장

현재 문제:
- `SECURITY.md`는 여러 secret 파일을 차단한다고 말하지만 `.gitignore`는 일부만 막는다.

바꿀 보장:
- "`SECURITY.md`에 적힌 절대 커밋 금지 파일 패턴은 `.gitignore`와 pre-commit/CI scan으로 실제 차단한다."

필요 조치:
- `.gitignore`를 `SECURITY.md` 표와 일치시킴.
- 허용 예외는 `CLAUDE.md.example`, `.env.example`, `.env.template`만 둠.
- secret scan 명령을 CI 또는 pre-commit에 추가.

관련 이슈:
- H-3

### B-4. `case-records` 로컬 API 접근 보장

현재 문제:
- loopback bind만으로는 같은 PC의 다른 프로세스가 사건 chunk를 읽을 수 있다.

바꿀 보장:
- "case-records API는 loopback에만 bind하고, 설치 시 생성한 로컬 token 없이는 검색 결과를 반환하지 않는다."

필요 조치:
- 설치 시 `~/.jurisupport/case-records.token` 같은 권한 제한 token 생성.
- server와 skill curl 예시에 `Authorization` header 추가.
- `top_k`, query 길이, 응답 chunk 길이 제한 추가.

관련 이슈:
- H-4, M-1

### B-5. JuriSupport MCP 토큰 처리 보장

현재 문제:
- bearer token이 command line 인자로 전달된다.

바꿀 보장:
- "설치 스크립트는 JuriSupport bearer token을 shell history나 process argv에 노출하지 않는다."

필요 조치:
- Claude CLI가 stdin/secret file/env var 등록을 지원하는지 확인.
- 지원하지 않으면 임시 파일 권한 `600`, 즉시 삭제, 경고 문구를 적용.
- README 수동 등록 명령도 안전한 흐름으로 교체.

관련 이슈:
- M-2

### B-6. hook 장애 시 동작 보장

현재 문제:
- `jq`가 없으면 hook이 exit `0`으로 허용한다.

바꿀 보장:
- "외부 전송 후보 도구에서 hook이 정상 판정하지 못하면 기본 차단 또는 명시 확인으로 전환한다."

필요 조치:
- `jq` 부재/JSON parse 실패 시 fail-closed로 바꿈.
- 설치 후 self-test를 자동 실행.
- troubleshooting 문서에 복구 방법 제공.

관련 이슈:
- M-3

## C. 1차 보완 순서 제안

1. **문서 보장 축소 먼저**
   - README, `guides/00_security.md`, `guides/02_book_scanning.md`, `guides/03_case_records.md`, `guides/06_precedent_search.md`의 과장/미구현 문구를 바로 낮춘다.
   - 이 단계만으로도 사용자의 잘못된 보안 판단을 줄인다.

2. **secret ignore 정합성**
   - `.gitignore`를 `SECURITY.md`에 맞춘다.
   - 작고 즉시 검증 가능하다.

3. **hook 정책 통합**
   - matcher와 hook 내부 판정을 일치시킨다.
   - fixture 기반 테스트를 같이 추가한다.

4. **case-records 외부 임베딩 gate**
   - 가장 큰 비밀정보 리스크이므로 별도 작업으로 잡는다.
   - 기본값 변경은 사용자 경험에 영향이 있어 명확한 migration 안내가 필요하다.

5. **case-records 로컬 API token**
   - 보안상 필요하지만 skill curl 예시와 설치 흐름까지 같이 바꿔야 하므로 2차 작업으로 둔다.

6. **MCP 토큰 전달·공급망 hardening**
   - CLI 지원 여부 확인이 필요하므로 조사 후 적용한다.
