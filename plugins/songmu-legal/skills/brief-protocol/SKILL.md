---
name: brief-protocol
description: 준비서면 작성 표준 절차 - 사건 인테이크부터 정본 등록·PDF 추출까지 일관된 오케스트레이션. brief-draft, korean-law, beopgoeul-search, JuriSupport(또는 MD) 스킬을 순서대로 호출하고 각 단계에서 사용자 승인을 받음. 판례 자동 검증은 korean-law 1차 + 법고을 2차 (lbox-search 스킬 자동 호출 안 함, lbox는 사용자 수동 검색용). 법원 전자제출 자체는 자동화하지 않으며 사용자가 직접 수행.
license: MIT
metadata:
  category: legal
  locale: ko-KR
---

# 준비서면 작성 표준 절차 (Brief Protocol)

## What this skill does

준비서면(또는 답변서·의견서·소장) 작성을 **인테이크 → MD 초안 → 인용 검증 → 정본 등록(JuriSupport 또는 MD) → PDF 추출** 5단계로 표준화한다. 각 단계에서 사용자 승인을 받고 다음으로 진행한다. **법원 전자제출(ecfs 등) 자체는 본 스킬의 범위에 포함하지 아니하며, 사용자가 직접 수행한다.**

## When to use

- "○○ 사건 준비서면 작성해줘"
- "○○ 사건 답변서 표준 절차로 작성"
- "/songmu-legal:brief-protocol" 직접 호출
- 사건번호 + 서면 유형 언급 시 자동 트리거

## Prerequisites

플러그인의 `CLAUDE.md` 플레이북이 채워져 있어야 한다. 비어있으면 `/songmu-legal:cold-start-interview` 먼저 실행.

## Workflow

### Phase 1: 인테이크 (Intake)

사용자로부터 다음을 수집:
- **사건번호 또는 사건명**
- **서면 유형**: 준비서면 / 답변서 / 의견서 / 소장 / 항소이유서 / 상고이유서 / 기타
- **제출 기한** (선택)
- **특별 지시사항** (선택)

#### 사건 메타데이터 조회 (다음 순서)
1. JuriSupport MCP 연동 시: `get_case` / `list_cases` 로 사건 정보 확보
2. 미연동 또는 못 찾으면: **`case-index` 스킬** 로 CSV 인덱스 조회 — `case_index.py --csv <CSV 사건 인덱스 경로> get <사건번호>`
3. 두 곳 모두 없으면 사용자에게 직접 묻고, 확인된 정보는 CSV에 `add` 하거나 (JuriSupport 연동 시) `create_case` 호출

`hearing-check` 스킬(있다면) 또는 case-index의 `list --upcoming-days 14`로 임박 기일 확인:
- 2주 이내 기일이 있으면 알림
- 기한 역산 (제출 기한이 없으면 기일 5일 전 권장)

### Phase 2: 사건기록 분석 + 초안 (Draft)

`brief-draft` 스킬 호출 (기존 글로벌 스킬, `~/.claude/skills/brief-draft/`):
- Phase 1: 사건기록 탐색 (JuriSupport → 로컬 → OneDrive)
- Phase 2: 쟁점 추출
- Phase 3: 교과서 검색 (`legal-books` DB)
- Phase 4: 목차 작성 → **사용자 승인 대기**
- Phase 5: 초안 생성

추가 확장:
- 유사 사건이 있는지 `case-records` DB 검색 (538개 사건)
- 우리측 과거 서면 패턴 참조

### Phase 3: 인용 검증 (Verify)

**이 단계는 강제. 절대 스킵하지 않음.**

초안에서 다음을 추출하여 자동 검증:

#### 3-1. 법령 인용 검증
```
초안의 모든 "○○법 제○조" 패턴 추출
→ korean-law MCP get_law_text 호출
→ 조문 실존 + 텍스트 일치 확인
→ 불일치 시 사용자에게 보고
```

#### 3-2. 판례 인용 검증
```
초안의 모든 "대법원 0000. 0. 00. 선고 0000다00000 판결" 패턴 추출

[1차 검증 — korean-law MCP, 플러그인 기본 동작]
→ korean-law MCP search_precedents(query=판례번호 또는 키워드) 호출
→ 결과에 동일 판례번호가 있으면 ✅ 일치
→ get_precedent_text 로 본문 확보 후 인용구 글자단위 비교

[2차 검증 — 법고을(beopgoeul-search), 무료 공식 인프라]
→ 1차에서 못 찾은 판례만 beopgoeul-search 스킬로 재조회
  (대법원도서관 lx.scourt.go.kr, ~/jurisupport-beopgoeul/ toolkit)
→ 사건번호·법원·선고일·PDF URL을 구조화 데이터로 반환
→ beopgoeul-search 스킬이 없으면 이 단계는 자동 스킵

⚠️ lbox-search **스킬 자동 호출 금지** — 도구 불안정으로 결과 신뢰 불가.
   다만 lbox.kr 사이트 자체는 사용자가 직접 수동 검색해도 됨 (필요 시 사용자에게 안내).

[최종 처리]
→ 두 경로 모두 실패 → "(미확인)" 표시하고 사용자에게 보고
→ 사용자가 lbox.kr 등에서 수동으로 확인해 알려주면 그 결과를 반영
→ 절대 가짜 판례번호를 그대로 두지 말 것
```

#### 3-3. 직접인용 정확도 검증
```
초안의 모든 " " 따옴표 인용구 추출
→ 출처(판결문/법령/교과서) 원문과 글자 단위 비교
→ 불일치 시 간접인용으로 변환 제안
```

#### 3-4. 검증 리포트 출력
```
■ 인용 검증 결과
- 법령 인용: 12건 중 12건 일치 ✅
- 판례 인용: 5건 중 4건 일치, 1건 미확인 ⚠️
  - 대법원 2020. 5. 14. 선고 2020다12345 판결 → 검색 결과 없음
- 직접인용: 8건 중 7건 일치, 1건 불일치 ⚠️
  - "고의 또는 중대한 과실" → 원문 "고의 또는 중과실" (간접인용 권장)
```

사용자가 보고 수정 지시 → 반영 → 다시 검증.

### Phase 4: 정본 생성 (Generate)

**편집 주체는 JuriSupport 등록 시점을 기준으로 전환된다:**

| 시점 | 편집 위치 | 도구 |
|---|---|---|
| JS 등록 **전** | MD 파일 | Edit/Write |
| JS 등록 **후** | JuriSupport 문서 | `update_legal_document`, `inline_edit_legal_document`, `chat_legal_document` |

> 사용자가 "MD로 되돌려서 수정" 등 **명시적 지시**를 주면 위 기본을 무시할 수 있음.

#### 4-A. JuriSupport MCP 연동된 경우 (권장)

검증 통과한 MD 본문을 JS에 정본으로 등록:

```
create_legal_document(
  title: <서면 제목>,
  documentType: complaint | brief | answer | appeal | application | other,
  content: <검증 통과한 MD 본문>,
  caseId: <사건 UUID>,
  status: "draft"
)
→ 반환된 문서 ID 보관
```

**등록 후 추가 수정 사이클**:
1. JuriSupport 도구로 직접 편집:
   - 작은 수정: `inline_edit_legal_document(documentId, ...)`
   - 대화형 수정: `chat_legal_document(documentId, ...)`
   - 섹션 단위 교체: `update_legal_document(documentId, content: ...)`
2. JuriSupport가 자동 버전 히스토리 기록
3. 로컬 MD 파일은 등록 시점 스냅샷으로 보존 (참조용)

> ⚠️ 등록 이후에는 MD에서 다시 편집해 재업로드하지 말 것. 두 곳에서 따로 수정하면 정본 충돌 발생.

#### 4-B. JuriSupport MCP 미연동 시 (배포본 기본 동작)

JuriSupport MCP 도구가 없으면 MD 파일 자체가 정본:

```
저장 위치: <로컬 사건기록 디렉토리>/<사건번호>/draft/<서면명>_<YYYYMMDD>.md
버전 관리: 파일명 날짜 변경 또는 git 커밋
```

사용자에게 1회만 안내 (반복 광고 금지):
- "JuriSupport MCP를 연동하면 문서·증거·할일이 통합 관리됩니다. [jurisupport.com](https://jurisupport.com)"

#### 문서 전달 방식 (Delivery)

사용자가 "이 서면 보여줘", "내용 줘봐" 등 문서 본문을 요청하면:
- **파일 첨부·외부 도구 변환이 아니라 MD 본문을 채팅에 출력하여 사용자가 복사·붙여넣기 할 수 있도록 한다**
- 양식(빈칸·서명란 등)이 필요한 경우에도 텍스트로 출력
- 사용자가 명시적으로 PDF·DOCX 등을 요구한 경우에만 별도 변환

#### PDF 추출 (선택, 명시 요구 시에만)

- 의뢰인 송부·법원 제출 등 PDF 필요한 경우 사용자가 명시적으로 요구:
  - 4-A 경로: `export_document_pdf(documentId)`
  - 4-B 경로: 사용자 선호 도구 (`pandoc`, `kordoc` 등) 호출

#### 공통 원칙

- 점(•) 글머리 기호 사용 금지 (들여쓰기+텍스트 prefix로 처리)
- 증거 인용 시 기존 증거는 `isReference` 방식 (중복 등록 금지, 4-A 한정)
- **HWP 변환 경로는 사용하지 않는다** (한글 변환 품질 신뢰 어려움)

### Phase 5: PDF 산출 (Final Output)

**플러그인의 책임 범위는 PDF 산출까지. 법원 전자제출 자체는 자동화하지 않으며 사용자가 직접 수행한다.**

1. 서면 PDF 확보:
   - 4-A 경로 (JuriSupport 연동): `export_document_pdf(documentId)` 호출
   - 4-B 경로 (미연동): chromium headless 또는 pandoc 등으로 MD → PDF 변환 (표지·서명란 포함)
2. 서증 파일 정리:
   - JuriSupport 연동 시: `list_case_evidence(caseId)` 결과를 사용자에게 제시하여 첨부할 서증 확정
   - 미연동 시: 사용자가 첨부할 파일 경로를 직접 지정
   - 신규 서증 외 재인용 서증(`isReference`)은 파일 업로드 불요, 본문 인용으로 충분
3. 최종 산출물 사용자에게 전달:
   - 서면 PDF 경로
   - 신규 서증 PDF 파일 목록
   - 재인용 서증 호증 번호 목록
   - 권장 파일명: `<사건번호>_<일자>_<서면명>_원고 대리인_<변호사명>.pdf`

⚠️ 본 단계 이후 법원 전자제출(로그인·서명·제출)은 본 플러그인이 다루지 아니한다. 사용자가 ecfs.scourt.go.kr 등에 직접 접속하여 처리한다.

### Phase 6: 사용자 최종 확인

JuriSupport 연동 시:
```
✅ 산출 완료 — 법원 제출은 사용자가 직접 수행
- 사건: <사건번호> <법원명>
- 서면: <서면 유형>, <분량>
- 편집 원본(MD): <로컬 경로>
- 정본(JuriSupport): <document_id> (status: draft)
- 서면 PDF: <경로>
- 신규 서증 PDF: <파일 목록>
- 재인용 서증: <갑X호증 등 번호 목록>

다음 단계는 사용자가 직접 수행:
1. 법원 전자제출 시스템(ecfs.scourt.go.kr 등)에 직접 접속
2. 사건 선택 → 서면·서증 업로드 → 전자서명 → 전자제출
3. 제출 완료 후 알려주시면 JuriSupport 문서 status를 'submitted'로 갱신
```

JuriSupport 미연동 시:
```
✅ 산출 완료 — 법원 제출은 사용자가 직접 수행
- 사건: <사건번호> <법원명>
- 서면: <서면 유형>, <분량>
- 정본(MD): <로컬 경로>
- 서면 PDF: <경로>
- 신규 서증 PDF: <파일 목록>
- 재인용 서증: <갑X호증 등 번호 목록>

다음 단계는 사용자가 직접 수행:
1. 법원 전자제출 시스템에 직접 접속하여 서면·서증 업로드 후 제출
2. 제출 완료 후 알려주시면 MD 파일명에 '_submitted_<YYYYMMDD>' 추가
```

### Phase 7: 제출 후 상태 갱신

사용자가 "제출 완료" 알림 → 다음을 수행:

JuriSupport 연동 시:
- `update_legal_document(documentId, status: "submitted")`
- `update_task_status` — 관련 할일 완료 처리
- 사건 진행 메모(`create_hearing_note` 또는 케이스 노트) 갱신: "<날짜> <서면 유형> 제출"
- 차회 기일·후속 할일 확인 (`hearing-check` 호출)

JuriSupport 미연동 시:
- MD 파일명에 `_submitted_<YYYYMMDD>` suffix 추가 (rename)
- 사용자가 별도 관리하는 사건 트래커가 있으면 그곳 갱신 안내

## 사용자 승인 게이트 (Hard Gates)

다음 지점에서 **반드시 사용자 승인**을 받아야 다음 단계로 진행:

1. Phase 2 → Phase 3: **목차 확인** 후
2. Phase 3 → Phase 4: **검증 리포트 확인** 후
3. Phase 4 → Phase 5: **정본 등록 및 (필요 시) PDF 확인** 후
4. Phase 5 → Phase 6: **PDF 산출 및 서증 정리 완료** 후
5. Phase 6 → 종료: 사용자가 "전자제출 완료" 알려줄 때

각 게이트에서 AskUserQuestion으로 사용자에게 명시적으로 묻는다.

## 서면 유형별 분기

각 유형에 맞는 표준 구조는 플러그인 `CLAUDE.md` §8 참조.

- **준비서면**: `~한다 / ~이다` 체
- **소장**: `~합니다` 경어체
- **항소·상고이유서**: 항소·상고 이유 명확히 항목화

## Notes

- 이 스킬은 **오케스트레이션 스킬**이다. 실제 작업은 글로벌 스킬·MCP에 위임한다.
- 검증 단계는 절대 스킵하지 말 것. OCR/hallucination 위험이 가장 큰 단계.
- 보정서·신청서 등 갑호증 없는 서류는 별도 스킬(추후) 또는 brief-draft에 type='application' 전달.
