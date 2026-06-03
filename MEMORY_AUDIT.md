# 메모리 vs 프로젝트 교차 대조 감사 보고서

> 원격 서버(182.225.243.14) 메모리 51개 + 로컬 2개 = 53개 메모리를 플러그인 프로젝트 파일과 대조
> 작성일: 2026-05-24
> **반영 완료: 2026-05-24** (CLAUDE.md.example v0.2.0, brief-protocol, cold-start-interview, install.sh)

---

## 1. CLAUDE.md.example에 반영 필요 (높음)

다른 사용자도 받게 될 템플릿에 빠져 있는 보편적 송무 규칙들.

### 1-1. "서면 작성 규칙" 섹션 자체가 없음

CLAUDE.md.example에 작성 스타일 섹션이 없어서, 아래 보편적 규칙들이 누락:

| Memory 파일 | 규칙 |
|---|---|
| `feedback_outline_hierarchy` | 목차 6단계: 1. -> 가. -> 1) -> 가) -> (1) -> (가) |
| `feedback_abbreviation_expansion` | 영문 약어 첫 등장 시 풀어쓰기 + 한글 의미 병기 |
| `feedback_foreign_quote_translation` | 외국어 원문 직접인용 시 한글 번역 병기 필수 |
| `feedback_honorific_abbreviation` | 약칭 도입 시 "이하 'OO'라 합니다" 경어체 |
| `feedback_inline_evidence_title` | 서증 인용 형식: "(갑 제n호증, 문서제목)" |
| `feedback_party_naming_no_number` | "피고 1/2" 번호 금지, 이름 병기 |
| `feedback_no_panrye` | "판례" 표현 금지, "판결" 또는 "판단" 사용 |
| `feedback_no_em_dash` | em-dash(—) 사용 금지 (Claude 작성 티 남) |
| `feedback_no_wiki_citation` | 나무위키/위키백과 인용 금지, 1차 출처 사용 |

**조치**: CLAUDE.md.example에 "서면 작성 규칙" 섹션 신설

### 1-2. SS8(서면 유형별 구조)에 누락된 유형 3개

| Memory 파일 | 누락된 서면 유형 |
|---|---|
| `feedback_correction_attachments` | **보정서**: 갑호증 없이 첨부서류(소명자료)로만 구성 |
| `feedback_cost_determination_format` | **소송비용액확정신청서**: 신청취지에 1·2·3심 사건번호 모두 기재 |
| `feedback_prosecution_record_request` | **검찰 기록열람등사 신청서**: 사건별 별도 작성, 형제번호 기재 |

### 1-3. JuriSupport 워크플로우 순서 규칙 누락

- `feedback_jurisupport_workflow`: **당사자 등록 -> 사건 등록 -> 본 업무** 순서
- SS10에 추가 필요

### 1-4. 의뢰인 보고서 톤 규칙 누락

- `feedback_client_report_tone`: 자기측 절차 비판/비유 제거, 행정사항 미포함, 표 정렬
- 의뢰인 커뮤니케이션 섹션 신설 필요

### 1-5. Obsidian 날짜 이스케이프 (SS4-7 Obsidian 사용자용)

- `feedback_date_escape_obsidian`: `2025\. 6. 20.` 형식 (연도 첫 점 이스케이프)

---

## 2. 스킬/템플릿 개선 필요 (중간)

### 2-1. brief-protocol SKILL.md 문체 오류 (버그)

**현재**: 준비서면 문체가 `~한다 / ~이다 체`로 기재됨 (253행 부근)
**올바른 값**: `~합니다 / ~입니다 체` (CLAUDE.md SS10 톤 규칙과 모순)

파일: `plugins/jurisupport/skills/brief-protocol/SKILL.md`

### 2-2. cold-start-interview에 작성 스타일 인터뷰 단계 누락

현재 cold-start는 사무소 정보, 호칭, 인용 정책, 파일 포맷만 물어봄.
아래 규칙들의 기본값 ON 제시 + 변경 여부 확인 필요:

- em-dash 금지
- 목차 6단계 체계
- 약어 풀어쓰기
- "판례" -> "판결" 용어

파일: `plugins/jurisupport/skills/cold-start-interview/SKILL.md`

### 2-3. brief-protocol에 보정서 유형 분기 미구현

보정서 작성 시 갑호증 대신 첨부서류(소명자료)로 구성하는 분기 없음.

파일: `plugins/jurisupport/skills/brief-protocol/SKILL.md`

### 2-4. 증거조사 경로 우선순위 가이드 없음

- `feedback_evidence_collection_routes`: 사실조회보다 문서제출명령 우선 (공적 기록)
- brief-protocol Phase 2 또는 별도 가이드에 추가

### 2-5. 의뢰인 서류 요청 범위 최소화

- `feedback_client_document_request`: 변호사 발급 가능 서류는 요청 X, 주소/식별정보만
- brief-protocol Phase 1 인테이크 참고사항에 추가

---

## 3. install.sh / 설정 개선 (낮음)

### 3-1. Hook에 drive_search 차단 패턴 누락

CLAUDE.md.example SS5에 "금지"로 명시되어 있지만, install.sh Hook matcher에 `mcp__claude_ai_Google_Drive__search_files` 패턴 없음.

파일: `install.sh` 130행 부근

### 3-2. 텔레그램 사용자용 AskUserQuestion 금지 규칙

텔레그램 연동 사용자가 있을 경우, cold-start에서 해당 규칙을 CLAUDE.md에 자동 기록하도록.

### 3-3. toolkit 서버 재부팅 후 자동 시작 미지원

legal-books(8766), case-records(8767) 서버가 재부팅 시 수동 재시작 필요.
launchd(macOS) / systemd(Linux) 등록 옵션 제안.

---

## 4. 이미 반영됨 (확인 완료)

| Memory 파일 | 반영 위치 |
|---|---|
| `feedback_cite_sources` | CLAUDE.md.example SS3-4, legal-books SKILL.md |
| `feedback_direct_quote_accuracy` | CLAUDE.md.example SS3-3 |
| `feedback_verify_law_mcp` | CLAUDE.md.example SS3-2, brief-protocol Phase 3 |
| `feedback_verify_precedent_numbers` | CLAUDE.md.example SS3-2 |
| `feedback_draft_format_md` | CLAUDE.md.example SS4-1, SS4-6 |
| `feedback_no_bullet_in_docx` | CLAUDE.md.example SS4-5 |
| `feedback_submission_scope` | CLAUDE.md.example SS7 |
| `feedback_jurisupport_doc_update` | CLAUDE.md.example SS10 |
| `feedback_jurisupport_evidence` | CLAUDE.md.example SS10, brief-protocol Phase 5-C |
| `feedback_no_drive_search` | CLAUDE.md.example SS5 (텍스트만, Hook 미반영) |
| `feedback_onedrive_rclone` | CLAUDE.md.example SS5 클라우드 경로 |

---

## 5. 플러그인과 무관 (사용자 개인 워크플로우)

총 17개: `feedback_susayeongu_format`, `feedback_column_save_location`, `feedback_column_search_range`, `feedback_daily_todo_workflow`, `feedback_personal_calendar`, `feedback_ecfs_submission`, `feedback_show_undated_tasks`, `feedback_session_mapping_*`, `feedback_writing_lint_guides`, `feedback_julgi_ilgwan`, `feedback_dunggibu_termin`, `project_skt_case_analysis`, `project_client_choi_jaehyuk`, `project_llm_wiki`, `project_gcal_gmail_mcp`, `secrets_email_api`, `workflow_parallel_sessions`

---

## 우선순위 요약

| 순위 | 항목 | 영향 범위 |
|---|---|---|
| **1** | CLAUDE.md.example "서면 작성 규칙" 섹션 신설 (1-1) | 모든 신규 사용자 서면 품질 |
| **2** | brief-protocol 문체 오류 수정 (2-1, 버그) | 준비서면 톤 불일치 |
| **3** | JuriSupport 워크플로우 순서 규칙 (1-3) | JuriSupport 사용자 전체 |
| **4** | SS8 서면 유형 3종 추가 (1-2) | 보정서/비용확정/기록열람등사 |
| **5** | cold-start 작성 스타일 인터뷰 추가 (2-2) | 신규 설치 사용자 |
| **6** | 의뢰인 보고서 톤 규칙 (1-4) | 의뢰인 커뮤니케이션 |
| **7** | brief-protocol 보정서 분기 + 증거 경로 가이드 (2-3~2-5) | 서면 작성 워크플로우 |
| **8** | Hook drive_search 차단 (3-1) | 데이터 보호 |
| **9** | toolkit 서버 자동시작 (3-3) | 인프라 안정성 |
