# jurisupport-plugins 보안 취약점 점검 보고서

작성일: 2026-05-24
대상: `/Users/haheebong/Documents/jurisupport plugin`
범위: 저장소 내 코드·문서·설치 스크립트 정적 점검, 일부 hook 동작 검증. 실제 소스 보완은 수행하지 않음.

## 요약

전체 보안 자세는 "기능 의도는 보안 친화적이나, 구현·문서 불일치가 의뢰인 비밀정보 보호에 직접 영향을 줄 수 있는 상태"입니다.

가장 시급한 문제는 `case-records`입니다. 문서는 사건 본문이 외부로 나가지 않는다고 설명하지만, 실제 ingestion은 사건기록 chunk 전체를 Gemini 임베딩 API로 전송합니다. 또한 데이터 보호 hook은 일부 외부 도구명에서 PII를 차단하지 못했고, `.gitignore`가 `SECURITY.md`의 secret 차단 정책을 충분히 반영하지 못하고 있습니다.

## 검증 결과

- `git status --short`: 점검 중 `.omx/`, `MEMORY_AUDIT.md`, `lib/`, 수정된 `install.sh`가 보였음. 이 리뷰가 직접 만든 산출물은 `.omx/plans/security-review-plan-20260524.md`와 `.omx/reports/security-review-20260524.md`임.
- `git ls-files` 기준으로 `CLAUDE.md`, `.env`, `secrets.env`, `.pem`, `.p12`, `.db` 등 고위험 파일이 tracked 된 증거는 발견하지 못함.
- `bash -n`으로 모든 `.sh` 문법 검사 통과.
- `python3 -m py_compile`로 모든 `.py` 문법 검사 통과.
- hook smoke test:
  - `WebSearch` + 주민등록번호 패턴: exit `2`, 차단 확인.
  - `WebFetch` + `lbox.kr`: exit `2`, 차단 확인.
  - `Bash` + 주민등록번호 패턴: exit `0`, 로컬 도구로 허용.
  - `mcp__claude_ai_Google_Drive__search_files` + 주민등록번호 패턴: exit `0`, 우회 확인.
  - `mcp__claude_ai_Gmail__send_email` + 주민등록번호 패턴: exit `0`, 우회 확인.
  - `Bash` + `curl https://lbox.kr/...`: exit `0`, 우회 확인.
- `127.0.0.1:8766`, `127.0.0.1:8767` 런타임 서버는 현재 환경에서 listen 중이 아니었음. 코드상 직접 실행 경로는 `127.0.0.1` bind 확인.
- `shellcheck`, `pip-audit`, `osv-scanner`, `pwsh`는 현재 환경에 없어 실행하지 못함.

## CRITICAL

### C-1. 사건기록 본문이 Gemini API로 전송되지만 문서는 외부 전송이 없다고 설명함

근거:
- [guides/03_case_records.md](/Users/haheebong/Documents/jurisupport%20plugin/guides/03_case_records.md:171)는 "사건기록은 모두 로컬 저장 (외부 전송 없음)"이라고 설명합니다.
- [guides/03_case_records.md](/Users/haheebong/Documents/jurisupport%20plugin/guides/03_case_records.md:172)는 "검색 시 쿼리만 Gemini 임베딩 변환 (사건 본문은 전송 X)"이라고 설명합니다.
- 실제 구현은 [toolkit/case-records/scripts/ingest_case.py](/Users/haheebong/Documents/jurisupport%20plugin/toolkit/case-records/scripts/ingest_case.py:91)에서 chunk batch를 Gemini API에 보냅니다.
- [toolkit/case-records/scripts/ingest_case.py](/Users/haheebong/Documents/jurisupport%20plugin/toolkit/case-records/scripts/ingest_case.py:162)는 전체 사건 chunk를 embedding 대상으로 넘깁니다.

영향:
의뢰인 이름, 사건번호, 주장 내용, 증거 요지, 상대방 정보 등 attorney-client confidential information이 사용자의 명확한 인지 없이 외부 AI API로 전송될 수 있습니다. 문서가 반대로 설명하고 있어 사용자가 잘못된 보안 판단을 할 위험이 큽니다.

권장 조치:
- `case-records`는 기본값을 외부 임베딩 비활성으로 바꾸거나, 최초 ingestion 전에 명시적 동의 gate를 둡니다.
- Gemini 사용 시 어떤 텍스트가 전송되는지 문서와 CLI 프롬프트에 명확히 표시합니다.
- 선택지로 로컬 임베딩 모델을 실제 구현하거나, 구현 전까지 문서에서 해당 대안을 제거합니다.
- 사건기록 ingestion 전 redaction 또는 민감정보 탐지/마스킹 옵션을 제공합니다.

검증 방법:
사건기록 fixture로 ingestion을 dry-run 하여 외부 API 호출 여부를 테스트하고, 동의 없이 `embed_content(contents=batch)`가 호출되지 않는지 확인합니다.

## HIGH

### H-1. 데이터 보호 hook의 설치 matcher와 내부 외부도구 목록이 달라 PII가 통과함

근거:
- `install.sh`는 Google Drive 검색과 Claude Gmail 계열 도구까지 matcher에 포함합니다 ([install.sh](/Users/haheebong/Documents/jurisupport%20plugin/install.sh:148)).
- hook 내부 외부도구 목록에는 Google Drive 검색이 없고, Claude Gmail도 `create_draft`만 있습니다 ([hooks/pretool_data_protection.sh](/Users/haheebong/Documents/jurisupport%20plugin/hooks/pretool_data_protection.sh:45)).
- 실제 테스트에서 `mcp__claude_ai_Google_Drive__search_files`와 `mcp__claude_ai_Gmail__send_email`은 주민등록번호 패턴을 포함해도 exit `0`으로 통과했습니다.

영향:
사용자는 hook이 외부 전송을 차단한다고 믿지만, 일부 외부 MCP 도구는 hook이 실행되어도 내부 분류에서 "로컬 도구"로 처리되어 PII가 외부 서비스로 전송될 수 있습니다.

권장 조치:
- hook 내부 목록을 설치 matcher와 동일한 정규식 기반 정책으로 통합합니다.
- allowlist보다는 "matcher로 hook이 호출된 도구는 기본 외부 도구"로 처리하는 구조가 안전합니다.
- 모든 외부 전송 도구에 대한 회귀 테스트를 추가합니다.

### H-2. 문서가 사건폴더 파일 업로드 차단을 보장하지만 구현이 없음

근거:
- 보안 가이드는 파일 업로드 도구가 사건폴더 파일을 외부로 전송하면 차단된다고 설명합니다 ([guides/00_security.md](/Users/haheebong/Documents/jurisupport%20plugin/guides/00_security.md:54)).
- hook 구현은 RRN, 사건번호, 휴대전화번호, `lbox.kr` 도메인만 검사하며 사건폴더 경로 패턴이나 파일 업로드 도구 분류가 없습니다 ([hooks/pretool_data_protection.sh](/Users/haheebong/Documents/jurisupport%20plugin/hooks/pretool_data_protection.sh:31), [hooks/pretool_data_protection.sh](/Users/haheebong/Documents/jurisupport%20plugin/hooks/pretool_data_protection.sh:45)).

영향:
문서가 제공하는 보호 약속보다 실제 보호 범위가 좁습니다. 사건번호나 전화번호가 포함되지 않은 파일명·파일본문 또는 경로 기반 업로드는 차단되지 않을 수 있습니다.

권장 조치:
- 파일 업로드/첨부 계열 도구명을 외부 도구로 등록합니다.
- `tool_input`에서 파일 경로를 추출해 `*/진행중사건/*`, `*/사건기록/*`, `~/사건/*`, 사용자 설정 사건폴더를 차단하거나 확인 gate를 둡니다.
- 구현 전까지 문서에서 "차단" 표현을 "현재 미구현"으로 수정합니다.

### H-3. `.gitignore`가 `SECURITY.md`의 secret 차단 정책을 충족하지 못함

근거:
- `SECURITY.md`는 `**/CLAUDE.md`, `.env.*`, `*.key`, `*.pem`, `*.p12`, `credentials.json`, `token.json`, `.netrc`, `*.local` 등을 차단 대상으로 명시합니다 ([SECURITY.md](/Users/haheebong/Documents/jurisupport%20plugin/SECURITY.md:11), [SECURITY.md](/Users/haheebong/Documents/jurisupport%20plugin/SECURITY.md:12), [SECURITY.md](/Users/haheebong/Documents/jurisupport%20plugin/SECURITY.md:13), [SECURITY.md](/Users/haheebong/Documents/jurisupport%20plugin/SECURITY.md:14), [SECURITY.md](/Users/haheebong/Documents/jurisupport%20plugin/SECURITY.md:15), [SECURITY.md](/Users/haheebong/Documents/jurisupport%20plugin/SECURITY.md:16)).
- 현재 `.gitignore`는 일부만 제외합니다 ([.gitignore](/Users/haheebong/Documents/jurisupport%20plugin/.gitignore:1), [.gitignore](/Users/haheebong/Documents/jurisupport%20plugin/.gitignore:32)).
- `git check-ignore` 결과 `foo.pem`, `foo.p12`, `credentials.json`, `token.json`, `.netrc`, `.env.production`, 루트 `CLAUDE.md` 등이 ignore 되지 않았습니다.

영향:
사용자가 보안 정책을 믿고 작업해도 실제 git 차단이 동작하지 않아 인증서, token, 로컬 플레이북이 실수로 커밋될 수 있습니다.

권장 조치:
- `SECURITY.md`의 차단 표를 `.gitignore`에 그대로 반영합니다.
- `CLAUDE.md.example`, `.env.example`, `.env.template`만 negation으로 허용합니다.
- pre-commit 또는 CI secret scan을 추가합니다.

### H-4. `case-records` 로컬 API가 인증 없이 민감 chunk를 그대로 반환함

근거:
- 검색 응답에 사건번호, 사건명, 문서 메타데이터, `chunk_text`가 포함됩니다 ([toolkit/case-records/server/server.py](/Users/haheebong/Documents/jurisupport%20plugin/toolkit/case-records/server/server.py:118)).
- 서버는 loopback bind이지만 별도 인증, local token, origin 제한, rate limit이 없습니다 ([toolkit/case-records/server/server.py](/Users/haheebong/Documents/jurisupport%20plugin/toolkit/case-records/server/server.py:134)).

영향:
같은 사용자 세션의 다른 로컬 프로세스가 `localhost:8767/search`를 호출하면 사건기록 chunk를 대량으로 추출할 수 있습니다. 악성 로컬 프로세스 방어는 한계가 있지만, 변호사 업무용 민감 DB라는 점에서 방어층이 부족합니다.

권장 조치:
- 설치 시 로컬 random token을 생성하고 `Authorization` 또는 Unix domain socket 등으로 접근을 제한합니다.
- `top_k` 상한과 query 길이 제한을 둡니다.
- 최소한 case-records에는 응답 chunk 길이 제한과 audit log 옵션을 둡니다.

## MEDIUM

### M-1. 검색 API 입력값 제한 부재로 비용·성능 DoS가 가능함

근거:
- `top_k`는 제한 없는 정수입니다 ([toolkit/legal-books/server/server.py](/Users/haheebong/Documents/jurisupport%20plugin/toolkit/legal-books/server/server.py:62), [toolkit/case-records/server/server.py](/Users/haheebong/Documents/jurisupport%20plugin/toolkit/case-records/server/server.py:41)).
- 검색 시 모든 embedding chunk를 메모리로 읽어 cosine을 계산합니다 ([toolkit/legal-books/server/server.py](/Users/haheebong/Documents/jurisupport%20plugin/toolkit/legal-books/server/server.py:100), [toolkit/case-records/server/server.py](/Users/haheebong/Documents/jurisupport%20plugin/toolkit/case-records/server/server.py:75)).
- 모든 검색 query는 Gemini embedding API 호출을 유발합니다 ([toolkit/legal-books/server/server.py](/Users/haheebong/Documents/jurisupport%20plugin/toolkit/legal-books/server/server.py:101), [toolkit/case-records/server/server.py](/Users/haheebong/Documents/jurisupport%20plugin/toolkit/case-records/server/server.py:76)).

영향:
대형 DB에서 긴 query와 큰 `top_k`를 반복 호출하면 로컬 CPU/메모리 사용량과 Gemini API 비용이 커질 수 있습니다.

권장 조치:
- `query` 길이, `top_k` 최대값, 요청 빈도 제한을 둡니다.
- embedding 결과 query cache를 도입합니다.
- 대형 DB에서는 vector index 또는 후보군 축소 전략을 사용합니다.

### M-2. JuriSupport MCP 토큰이 command line 인자로 전달됨

근거:
- 토큰은 숨김 입력으로 받지만, 등록 시 `claude mcp add ... --header "Authorization: Bearer $JURI_TOKEN"` 형태로 실행됩니다 ([install.sh](/Users/haheebong/Documents/jurisupport%20plugin/install.sh:370), [install.sh](/Users/haheebong/Documents/jurisupport%20plugin/install.sh:422)).
- README도 수동 등록 명령에 bearer token을 command line에 넣도록 안내합니다 ([README.md](/Users/haheebong/Documents/jurisupport%20plugin/README.md:290)).

영향:
일부 OS/환경에서는 process argv, shell history, 터미널 로그, crash report를 통해 bearer token이 노출될 수 있습니다.

권장 조치:
- token을 stdin, 임시 권한 제한 파일, 또는 Claude Code의 secret 저장 메커니즘으로 전달합니다.
- 수동 등록 문서도 command line token 입력 대신 안전한 절차로 바꿉니다.
- 설치 후 토큰 저장 위치와 권한을 검증합니다.

### M-3. `jq` 부재 시 hook이 fail-open으로 동작함

근거:
- hook은 `jq`가 없으면 경고만 출력하고 exit `0`으로 허용합니다 ([hooks/pretool_data_protection.sh](/Users/haheebong/Documents/jurisupport%20plugin/hooks/pretool_data_protection.sh:16)).

영향:
설치 후 환경 변경으로 `jq`가 사라지거나 PATH에서 빠지면 모든 외부 전송 보호가 조용히 약화됩니다.

권장 조치:
- 외부 도구 matcher로 호출된 상황에서는 `jq` 부재 시 fail-closed 또는 사용자 확인으로 전환합니다.
- install 후 self-test를 실행해 hook 정상 동작을 확인합니다.

### M-4. lbox 자동화 금지 hook이 Bash/curl 경로를 차단하지 못함

근거:
- `lbox-guide`는 Bash, curl, wget, playwright, selenium 자동 접속을 hard stop으로 금지합니다 ([skills/lbox-guide/SKILL.md](/Users/haheebong/Documents/jurisupport%20plugin/skills/lbox-guide/SKILL.md:20)).
- 통합 가이드는 Bash 접근도 hook이 차단한다고 설명합니다 ([guides/06_precedent_search.md](/Users/haheebong/Documents/jurisupport%20plugin/guides/06_precedent_search.md:82), [guides/06_precedent_search.md](/Users/haheebong/Documents/jurisupport%20plugin/guides/06_precedent_search.md:92)).
- 실제 hook 테스트에서 `Bash`로 `curl https://lbox.kr/...` 명령은 exit `0`으로 통과했습니다.

영향:
LLM 또는 사용자가 Bash 경로로 lbox 자동화를 시도하면 약관 위반 방어가 hook 단계에서 작동하지 않습니다.

권장 조치:
- Bash tool도 hook matcher에 포함하고, command 문자열에서 restricted domain 및 자동화 도구 호출을 검사합니다.
- 또는 문서에서 "hook은 WebFetch/WebSearch만 차단하며 Bash는 스킬 지침으로만 금지"라고 정확히 고칩니다.

### M-5. 공급망 설치 표면이 넓고 무결성 검증이 약함

근거:
- README는 `bash <(curl -fsSL ...)`, PowerShell `irm ... | iex` 한 줄 설치를 안내합니다 ([README.md](/Users/haheebong/Documents/jurisupport%20plugin/README.md:33), [README.md](/Users/haheebong/Documents/jurisupport%20plugin/README.md:48)).
- bootstrap은 Homebrew install script, NodeSource setup script, npm global install을 실행합니다 ([bootstrap.sh](/Users/haheebong/Documents/jurisupport%20plugin/bootstrap.sh:98), [bootstrap.sh](/Users/haheebong/Documents/jurisupport%20plugin/bootstrap.sh:156), [bootstrap.sh](/Users/haheebong/Documents/jurisupport%20plugin/bootstrap.sh:175)).
- Windows bootstrap은 GitHub latest release에서 Ghostscript installer를 받아 무인 실행합니다 ([windows-bootstrap.ps1](/Users/haheebong/Documents/jurisupport%20plugin/windows-bootstrap.ps1:229), [windows-bootstrap.ps1](/Users/haheebong/Documents/jurisupport%20plugin/windows-bootstrap.ps1:239), [windows-bootstrap.ps1](/Users/haheebong/Documents/jurisupport%20plugin/windows-bootstrap.ps1:241)).

영향:
초기 설치 과정이 여러 외부 공급망에 의존하며, hash/pinning 없이 latest artifact를 실행합니다.

권장 조치:
- 릴리스 태그와 SHA256 checksum을 문서화하고 검증합니다.
- 기업/사무소용 보안 설치 절차를 별도로 제공합니다.
- 최소 권한 설치와 dry-run 모드를 강화합니다.

## LOW / INFO

### L-1. `legal-books` 문서도 외부 전송 범위를 부정확하게 설명함

근거:
- [guides/02_book_scanning.md](/Users/haheebong/Documents/jurisupport%20plugin/guides/02_book_scanning.md:199)는 책 PDF·청크가 모두 로컬 저장이라고 설명합니다.
- [guides/02_book_scanning.md](/Users/haheebong/Documents/jurisupport%20plugin/guides/02_book_scanning.md:200)는 검색 시 쿼리만 Gemini로 간다고 설명합니다.
- 실제 책 추가 시 chunk 전체가 Gemini embedding API로 전송됩니다 ([toolkit/legal-books/scripts/ingest.py](/Users/haheebong/Documents/jurisupport%20plugin/toolkit/legal-books/scripts/ingest.py:75), [toolkit/legal-books/scripts/ingest.py](/Users/haheebong/Documents/jurisupport%20plugin/toolkit/legal-books/scripts/ingest.py:143)).

영향:
사건기록보다는 민감도가 낮을 수 있지만, 저작권 자료의 외부 API 전송 범위를 사용자가 오해할 수 있습니다.

권장 조치:
문서를 실제 동작과 맞추고, 보유 서적 본문을 외부 API로 보내는 것의 저작권·계약상 위험을 안내합니다.

### L-2. 문서에 구현되지 않은 옵션이 남아 있음

근거:
- `guides/02_book_scanning.md`는 `install.sh` 실행 시 로컬 임베딩 모델 선택 옵션이 있다고 설명하지만 관련 구현을 찾지 못했습니다 ([guides/02_book_scanning.md](/Users/haheebong/Documents/jurisupport%20plugin/guides/02_book_scanning.md:203)).
- `guides/03_case_records.md`는 `--meta-from-filename none` 옵션을 설명하지만 `ingest_case.sh`와 `ingest_case.py`에는 해당 옵션이 없습니다 ([guides/03_case_records.md](/Users/haheebong/Documents/jurisupport%20plugin/guides/03_case_records.md:118)).
- HWP를 처리한다고 설명하지만 실제 `extract_text`는 HWP/HWPX를 빈 문자열로 skip합니다 ([toolkit/case-records/scripts/ingest_case.py](/Users/haheebong/Documents/jurisupport%20plugin/toolkit/case-records/scripts/ingest_case.py:62)).

영향:
보안 기능 선택지나 데이터 처리 범위를 사용자가 잘못 이해할 수 있습니다.

권장 조치:
미구현 기능은 문서에서 제거하거나 실제 옵션으로 구현합니다.

### I-1. 의존성 CVE 스캔 미수행

근거:
현재 환경에 `pip-audit`, `osv-scanner`가 없어 CVE 스캔을 수행하지 못했습니다. 또한 Python 의존성은 설치 스크립트 안의 version range로만 관리되고 lockfile이 없습니다.

권장 조치:
CI 또는 릴리스 전 절차에 `pip-audit`/OSV 스캔을 추가하고, 배포용 lockfile 또는 hash-pinned constraints를 고려합니다.

### I-2. untracked `MEMORY_AUDIT.md`는 커밋 전 별도 검토 필요

근거:
`MEMORY_AUDIT.md`는 untracked 상태이며, targeted scan에서 실제 secret 값은 발견하지 못했지만 `secrets_email_api`, `project_client_*` 같은 민감해 보이는 식별자 라벨이 포함되어 있습니다.

권장 조치:
커밋 전 사람이 내용을 검토하고, 필요하면 `.gitignore`에 audit 산출물 패턴을 추가합니다.

## 보완 우선순위

1. `case-records` 외부 전송 문제: 문서 수정 + 명시 동의 gate + 로컬 임베딩 또는 redaction 옵션.
2. 데이터 보호 hook 정책 통합: 설치 matcher와 내부 외부도구 목록 일치, 파일 업로드 경로 차단 구현.
3. `.gitignore`를 `SECURITY.md` 정책과 일치시키고 secret scan을 CI/pre-commit에 추가.
4. `case-records` 로컬 API에 token 인증, 입력 제한, 응답 제한 추가.
5. JuriSupport MCP token 등록 방식을 command line 인자에서 제거.
6. 공급망 설치 스크립트에 version pinning/checksum 검증 추가.
7. 문서의 미구현 옵션과 부정확한 보안 설명 정리.

## 점검 한계

- 실제 사용자 사건자료와 사용자 로컬 `CLAUDE.md`는 점검하지 않았습니다.
- optional toolkit 서버가 현재 실행 중이 아니어서 runtime API 응답은 확인하지 못했습니다.
- 외부 dependency CVE 스캔은 도구 부재로 수행하지 못했습니다.
- 법률·개인정보보호법상 최종 판단은 내부 책임자 또는 개인정보보호 담당자의 검토가 필요합니다.
