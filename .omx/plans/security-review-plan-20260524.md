# jurisupport-plugins 보안 취약점 점검 계획

작성일: 2026-05-24
범위: 점검 계획 수립만 포함합니다. 이 문서는 소스 코드 수정이나 취약점 보완 작업을 포함하지 않습니다.

## 1. 점검 목적

이 저장소는 법률 실무용 Claude Code 플러그인과 로컬 검색 도구를 배포하는 프로젝트입니다. 따라서 일반 웹 애플리케이션 보안뿐 아니라 변호사 비밀유지의무, 사건자료 외부 전송, 로컬 검색 서버 노출, 설치 스크립트 안전성, API 키와 MCP 토큰 관리, 플러그인/스킬 프롬프트 안전성을 함께 점검해야 합니다.

이번 보안 점검의 핵심 목표는 다음과 같습니다.

1. 의뢰인 정보, 사건기록, 법률 검토 결과물이 승인되지 않은 외부 서비스로 전송되지 않도록 확인합니다.
2. Gemini API 키, JuriSupport MCP 토큰, 인증서, 로컬 플레이북, 사건 DB가 저장소나 로그에 남지 않도록 확인합니다.
3. `legal-books`와 `case-records` 로컬 검색 서버가 외부 네트워크에 노출되지 않고 입력값 제한과 오남용 방어를 갖췄는지 확인합니다.
4. 설치 스크립트와 bootstrap 스크립트가 사용자 환경을 안전하게 변경하는지 확인합니다.
5. 의존성 취약점과 공급망 위험을 점검합니다.
6. 스킬/플러그인 지침이 prompt injection, 외부 전송, 법률 사이트 자동화 제한을 안전하게 다루는지 확인합니다.

## 2. 현재 확인한 프로젝트 사실

- `install.sh`는 `~/.claude/settings.json`에 PreToolUse hook을 등록하고, 스킬/플러그인을 설치하며, 선택적으로 toolkit 서버를 실행하고 JuriSupport MCP 토큰을 등록합니다 (`install.sh:112`, `install.sh:129`, `install.sh:232`, `install.sh:249`, `install.sh:267`, `install.sh:337`).
- 데이터 보호 hook은 주민등록번호, 한국 사건번호, 휴대전화번호, `lbox.kr` 자동 접근을 일부 외부 도구에 대해 탐지합니다 (`hooks/pretool_data_protection.sh:31`, `hooks/pretool_data_protection.sh:45`, `hooks/pretool_data_protection.sh:74`, `hooks/pretool_data_protection.sh:107`).
- 보안 가이드는 사건폴더 파일 업로드 차단을 설명하지만, 실제 hook 구현과 일치하는지 별도 확인이 필요합니다 (`guides/00_security.md:48`, `guides/00_security.md:54`).
- `legal-books`와 `case-records`는 FastAPI 로컬 검색 서버를 띄우고, 검색 결과로 저장된 텍스트 chunk를 반환합니다 (`toolkit/legal-books/server/server.py:139`, `toolkit/case-records/server/server.py:118`).
- 두 서버는 코드상 `127.0.0.1`에 bind합니다 (`toolkit/legal-books/server/server.py:158`, `toolkit/case-records/server/server.py:134`).
- `legal-books`와 `case-records` ingestion은 텍스트 chunk를 Gemini 임베딩 API로 전송합니다 (`toolkit/legal-books/scripts/ingest.py:63`, `toolkit/legal-books/scripts/ingest.py:141`, `toolkit/case-records/scripts/ingest_case.py:84`, `toolkit/case-records/scripts/ingest_case.py:162`).
- toolkit 설치 스크립트는 Python venv를 만들고 네트워크 패키지를 설치하며, `~/.jurisupport/secrets.env`에 `GEMINI_API_KEY`를 저장하고 로컬 서버를 시작합니다 (`toolkit/legal-books/install.sh:167`, `toolkit/legal-books/install.sh:182`, `toolkit/legal-books/install.sh:227`, `toolkit/legal-books/install.sh:275`, `toolkit/case-records/install.sh:92`, `toolkit/case-records/install.sh:99`, `toolkit/case-records/install.sh:144`, `toolkit/case-records/install.sh:174`).
- `.gitignore`는 secret 파일, 로컬 DB, 사용자별 `plugins/songmu-legal/CLAUDE.md`를 제외합니다 (`.gitignore:1`, `.gitignore:6`, `.gitignore:32`).
- 현재 테스트 파일은 파일명 패턴 기준으로 발견되지 않았습니다. 보완 작업 전 보호 로직에 대한 회귀 테스트 또는 수동 검증표를 먼저 마련해야 합니다.

## 3. 단계별 점검 계획

### 0단계 - 자산과 데이터 흐름 파악

- 주요 entrypoint를 목록화합니다: `install.sh`, `bootstrap.sh`, `windows-bootstrap.ps1`, toolkit 설치 스크립트, 서버 스크립트, hook 스크립트, 스킬 파일, 플러그인 manifest.
- 데이터 흐름을 그립니다: 사용자 사건폴더 -> ingestion -> Gemini 임베딩 -> SQLite DB -> 로컬 FastAPI -> Claude Code 스킬 응답.
- 신뢰 경계를 표시합니다: 로컬 파일시스템, `~/.claude/settings.json`, `~/.jurisupport/secrets.env`, JuriSupport MCP, Gemini API, 법률 사이트, Selenium 브라우저 자동화.
- 현재 테스트 공백과 실행 가능한 검증 명령을 정리합니다.

### 1단계 - secret 및 저장소 위생 점검

- tracked, staged, untracked 파일에서 API 키, bearer token, private key, 실제 `CLAUDE.md`, 로컬 절대경로, 이메일, 휴대전화번호, 사건번호, `GEMINI_API_KEY` 값을 검색합니다.
- `.gitignore`가 `SECURITY.md` 정책과 맞는지 확인합니다. 특히 `.env.*`, 인증서/개인키, `CLAUDE.md`, 로컬 DB, 로그, toolkit 산출물 폴더를 확인합니다.
- 현재 untracked인 `MEMORY_AUDIT.md`는 초기 grep에서 민감 키워드가 잡혔으므로 별도 점검합니다.
- 필요하면 git history secret scan을 별도 선택 작업으로 수행합니다.

### 2단계 - 데이터 보호 hook 점검

- 다음 fixture 테스트를 만듭니다.
  - 주민등록번호, 한국 사건번호, 휴대전화번호 탐지
  - `WebFetch`, `WebSearch`에서 `lbox.kr` 차단
  - Gmail, chat, telegram MCP 도구명이 설치 스크립트 matcher와 실제 hook 목록에서 일치하는지
  - 문서에 적힌 사건폴더 파일 업로드 차단이 실제로 동작하는지
  - 알 수 없는 외부 전송 도구명에 대한 우회 가능성
  - `jq`가 없거나 입력 JSON이 깨진 경우 fail-open이 허용 가능한지
- `guides/00_security.md`의 설명과 `hooks/pretool_data_protection.sh` 구현을 대조합니다. 구현되지 않은 보호 기능은 코드 보완 또는 문서 수정 대상으로 분류합니다.
- hook exit code가 의도대로 동작하는지 확인합니다: `0`은 허용, `2`는 차단.

### 3단계 - 설치 스크립트와 bootstrap hardening

- shell/PowerShell 스크립트에서 command injection, 위험한 경로 확장, 과도한 삭제, token echo, temp file 처리, 중복 실행 안전성을 확인합니다.
- `install.sh`의 MCP 토큰 처리 흐름을 점검합니다: 숨김 입력, 검증 요청, `claude mcp add --header` 실행 시 process argv 노출 가능성, 에러 출력, shell history, 변수 cleanup.
- `~/.claude/settings.json` hook 등록이 중복되지 않는지, matcher와 실제 hook tool 목록이 어긋나지 않는지, Windows quoting이 안전한지 확인합니다.
- 로컬에 도구가 있으면 `shellcheck`, PowerShell parser, `PSScriptAnalyzer`를 실행합니다.
- README의 `curl | bash`, PowerShell `irm | iex` 설치 방식에 무결성 확인, pinning, 사용자 경고가 충분한지 검토합니다.

### 4단계 - 로컬 FastAPI와 SQLite 점검

- request model에 입력 제한이 있는지 확인합니다: `query` 길이, `top_k` 최대값, `filters` 형태, JSON body 크기, 빈 DB 또는 대형 DB 동작.
- 서버 시작 경로 전체에서 `127.0.0.1`에만 bind하는지 확인합니다.
- CORS 기본값, `/docs` 노출, exception detail, 로그에 민감 텍스트가 남는지 확인합니다.
- 같은 사용자 PC의 다른 프로세스나 브라우저 페이지가 `localhost:8766`, `localhost:8767`을 호출해 저장된 사건/서적 chunk를 빼낼 수 있는지 threat model을 세웁니다.
- FTS query, parameterized SQL, dynamic placeholder 생성이 안전한지 확인합니다.
- 전체 chunk cosine search와 제한 없는 `top_k`로 인한 DoS 가능성을 검토합니다.

### 5단계 - ingestion 및 외부 AI 전송 점검

- `legal-books` ingestion에서 저작권 자료 처리, Gemini 전송 범위, 생성되는 markdown/JSONL 파일 권한, 경로 처리 안전성을 점검합니다.
- `case-records` ingestion에서 의뢰인 비밀정보, 파일 유형별 추출 위험, HWP skip 동작과 문서 설명의 일치 여부, DB에 원본 경로가 남는 문제, 파일명 기반 chunk id 노출을 점검합니다.
- 문서가 “임베딩 생성 시 텍스트 chunk가 Gemini로 전송된다”는 사실을 충분히 명시하는지 확인합니다.
- 사건기록 ingestion은 가장 민감하므로 사전 동의 gate, redaction, 또는 별도 경고 보강이 필요한지 판단합니다.

### 6단계 - 의존성 및 공급망 점검

- 스크립트가 설치하는 런타임 의존성을 목록화합니다: FastAPI, Uvicorn, Pydantic, sqlite-utils, google-genai, pypdf, numpy, python-dotenv, python-docx, selenium, OCR 도구, Chrome/Chromium, jq, Claude Code.
- 저장소에 새 의존성을 추가하지 않고 가능한 범위에서 `pip-audit` 또는 `osv-scanner`를 실행합니다. 도구가 없으면 정확히 어떤 검증을 못 했는지 기록합니다.
- version range가 너무 넓지 않은지, release packaging에 lockfile 또는 hash pinning이 필요한지 검토합니다.
- 외부 설치 표면을 점검합니다: Homebrew 설치 스크립트, NodeSource setup script, Google apt key/repo, GitHub Ghostscript release fetch, winget package id, npm global Claude Code 설치.

### 7단계 - 플러그인/스킬 프롬프트 안전성 점검

- `skills/*/SKILL.md`와 `plugins/songmu-legal/skills/*/SKILL.md`에서 도구 사용 권한, 외부 전송 지침, 법률 사이트 자동화 제한, 사건기록을 읽을 때 prompt injection 방어 문구를 확인합니다.
- 사용자 로컬 파일인 `plugins/songmu-legal/CLAUDE.md`는 명시 허락 없이 읽지 않습니다. 공개 템플릿인 `CLAUDE.md.example`만 점검 대상으로 삼습니다.
- `lbox-guide`, `beopgoeul-search`, README, hook 구현 사이에서 법률 사이트 자동화 제한이 일관되는지 확인합니다.

### 8단계 - 보고서와 보완 backlog 작성

- 최종 보안 보고서는 `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`, `INFO`로 나눠 작성합니다.
- 각 finding은 파일/라인, 영향, 악용 또는 오사용 시나리오, 영향을 받는 데이터, 권장 수정, 검증 방법을 포함해야 합니다.
- 확인된 취약점, 정책/문서 불일치, 방어 강화 권고를 분리합니다.
- 보완 우선순위는 다음 순서로 둡니다.
  1. 의뢰인 비밀정보 또는 secret 노출
  2. 데이터 보호 hook 우회
  3. 설치 스크립트와 토큰 처리 위험
  4. 로컬 API를 통한 정보 유출 또는 DoS
  5. 의존성 CVE와 공급망 hardening
  6. 문서 정확성 및 사용자 경고 보강

## 4. 완료 기준

- 최종 보안 보고서가 존재하고, 모든 확인 이슈에 severity, 근거, 보완책이 포함되어야 합니다.
- hook 동작은 실행 가능한 fixture 또는 명확한 수동 테스트표로 검증되어야 합니다.
- secret scan은 tracked 파일, untracked 고위험 파일, 필요 시 git history까지 포함해야 합니다.
- dependency scan을 수행하거나, 못 했으면 사용 불가 도구와 남은 gap을 기록해야 합니다.
- `legal-books`와 `case-records` 서버 노출 범위는 코드 기준으로 확인하고, 설치된 환경에서는 runtime으로도 확인해야 합니다.
- 문서와 코드의 불일치, 특히 파일 업로드 차단과 Gemini 텍스트 전송 안내는 반드시 확인되어야 합니다.
- 사용자 로컬 `CLAUDE.md`나 실제 의뢰인 자료는 명시 허락 없이 읽거나 복사하지 않아야 합니다.

## 5. 권장 검증 명령

저장소 루트에서 실행합니다.

```bash
git status --short
rg -n "(GEMINI_API_KEY|Authorization: Bearer|password|secret|token|BEGIN .*PRIVATE KEY|[0-9]{6}-[0-9]{7}|[0-9]{4}[가-힣]{1,3}[0-9]{3,})" -S .
git ls-files | rg "(CLAUDE\.md$|secrets\.env$|\.env$|\.p12$|\.pfx$|\.pem$|\.key$|cases_fts\.db$|books_fts\.db$)"
find . -name '*.sh' -print0 | xargs -0 -n1 bash -n
find . -name '*.py' -print0 | xargs -0 python3 -m py_compile
```

hook smoke test:

```bash
printf '{"tool_name":"WebSearch","tool_input":{"query":"홍길동 700101-1234567"}}' | bash hooks/pretool_data_protection.sh; echo $?
printf '{"tool_name":"WebFetch","tool_input":{"url":"https://lbox.kr/search"}}' | bash hooks/pretool_data_protection.sh; echo $?
printf '{"tool_name":"Bash","tool_input":{"command":"echo 700101-1234567"}}' | bash hooks/pretool_data_protection.sh; echo $?
```

선택 검증:

```bash
shellcheck install.sh bootstrap.sh hooks/pretool_data_protection.sh toolkit/*/install.sh toolkit/*/scripts/*.sh
pip-audit
osv-scanner --recursive .
```

## 6. 계획 단계에서 남은 리스크

- 이 문서는 아직 실제 취약점 점검 보고서가 아니라, 코드 구조를 근거로 만든 점검 계획입니다.
- dependency CVE 결과는 최신 scanner DB와 네트워크 상태에 따라 달라질 수 있습니다.
- optional toolkit의 runtime 노출 여부는 해당 서버가 실제 설치 및 실행된 환경에서 확인해야 합니다.
- 변호사 비밀유지의무와 개인정보보호법 관점의 최종 판단은 내부 책임자 또는 법률/개인정보보호 담당자가 검토해야 합니다.
