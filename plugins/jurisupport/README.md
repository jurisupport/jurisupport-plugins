# JuriSupport

한국 송무 워크플로우와 변호사 개인 프로필 완성 플러그인. 사건 인테이크부터 서면 정본 등록·PDF 추출까지 일관된 절차로 처리하고, 본인의 업무 경험과 자료를 바탕으로 스스로 읽고 활용할 수 있는 개인 프로필을 완성해 원하면 JuriSupport에도 올릴 수 있게 돕는다. 법원 전자제출 자체는 자동화하지 않으며, 사용자가 직접 수행한다.

## 무엇이 들어있나

### 스킬 (이 플러그인)
- **`/jurisupport:cold-start-interview`** - 사무소 플레이북 학습 (최초 1회). 의뢰인 호칭 규칙, 인용 표기 정책, 파일 포맷, 사건기록 저장 위치, CSV 사건 인덱스 경로 등을 인터뷰하여 CLAUDE.md를 채운다.
- **`/jurisupport:brief-protocol`** - 준비서면 작성 표준 절차 (intake → 사건기록 → 쟁점 → 교과서·판결 검증 → MD 초안 → 정본 등록 → PDF 추출까지의 오케스트레이션).
- **`/jurisupport:mock-hearing`** - 모의변론. 제출 전 서면·사건이론을 상대방 대리인·재판부 관점에서 검토하고, 구상 단계부터 법령·판결·교과서 근거 정리표를 만든 뒤 강도 채점과 구조화된 평결(제출가능/보강/재구성/출구)·보강 과제를 낸다. 다중파일 구조(질문 목록·채점루브릭·어조 규칙). brief-protocol 인용 검증 통과 후 선택 단계로 연계.
- **`/jurisupport:case-index`** - CSV 한 파일(`_index.csv`)로 사건 목록·다음기일을 관리. JuriSupport MCP 미사용자용 정본, 또는 연동자의 백업·오프라인 뷰. list/get/add/update/close 명령 제공.
- **`/jurisupport:complete-personal-profile`** - 변호사가 본인의 사건자료·작성서류·판결문을 바탕으로 직접 읽고 활용할 수 있는 개인 프로필을 완성한다. 원하면 JuriSupport에 올릴 수 있도록 이어서 정리한다.
- **`/jurisupport:upload-to-jurisupport`** - 변호사가 확인한 완성 프로필을 웹 동의 후 JuriSupport에 올린다. 공개 승인이나 노출 시작은 별도 검토 절차를 따른다.
- **`/jurisupport:offline-law-fallback`** - 법제처 OC 키 발급 전 시연·실습용 오프라인 법령 전문 스냅샷. 헌법, 민법, 민사소송법, 형법, 형사소송법, 상법, 주요 특별형법을 포함한다. 실제 제출 전에는 온라인 재검증 필수.

### 참조하는 공개 인프라
- **korean-law MCP** - 법령·판결 실존 확인 (정식 1차 검증 경로, 법제처 OC 필요)
  - `search_law`, `get_law_text` - 법령
  - `search_precedents`, `get_precedent_text` - 판결
- **offline-law-fallback** - OC 발급 전에도 설치·강의·실습을 진행하기 위한 플러그인 내장 법령 전문 스냅샷. 판례는 포함하지 않으며, 실제 사건 제출 전에는 `korean-law` MCP 또는 국가법령정보센터로 최신 조문을 재검증한다.
- **beopgoeul-search 스킬** - 법고을(대법원도서관 lx.scourt.go.kr) 무료 공식 판결 검색 (2차 검증, korean-law에서 못 찾았을 때)
- **로컬 파일 시스템** - 초안·정본 모두 Markdown 파일로 저장 (기본값)

### 경량 대안: CSV 사건 인덱스 (배포본 포함)

JuriSupport를 쓰지 않는 사용자는 `case-index` 스킬로 CSV 한 파일에 사건 목록을 유지할 수 있습니다. 컬럼: `사건번호,법원,사건명,의뢰인,상대방,진행단계,다음기일,비고`. 엑셀로 직접 열어 편집해도 되고, 헬퍼 스크립트로 add/update/close 가능. 콜드스타트에서 경로를 설정합니다 (기본 제안: `<클라우드 사건폴더 경로>/_index.csv`).

### 개인 프로필 완성

`/jurisupport:complete-personal-profile`은 송무 작업과 별개로, 변호사가 본인의 프로필을 완성하기 위한 도구입니다. "앞으로 어떤 질문을 한 의뢰인을 만나고 싶은지", "어떤 사건을 더 받고 싶은지", "어떤 강점은 공개해도 괜찮고 어떤 표현은 피해야 하는지"를 정리합니다. 완성된 프로필은 자기소개, 홈페이지·블로그 소개글, 상담 분야 점검, 앞으로 받을 사건 방향 정리에 활용할 수 있습니다.

원하면 완성한 프로필을 JuriSupport에 올릴 수 있습니다. 먼저 JuriSupport 웹에서 가입·로그인 후 `/lawyer-search/profile/consent` 동의 페이지를 완료해야 합니다. 시작 URL은 `https://jurisupport.com/signup?redirect=/lawyer-search/profile/consent` 입니다.

JuriSupport에 올린 프로필은 의뢰인이 상담 가능한 변호사 목록을 볼 때, 의뢰인의 질문과 변호사 프로필의 상담 분야·강점이 얼마나 가까운지에 따라 노출에 반영됩니다. 이 스킬은 프로필을 자동 공개하거나 의뢰인을 배정하지 않습니다. 원본 사건기록 파일은 자동 업로드하지 않고, 변호사가 확인한 프로필 내용만 선택적으로 올립니다. 웹 동의가 없으면 업로드가 거절됩니다.

### 권장 통합: JuriSupport MCP

문서·증거·할일·기일을 한 곳에서 관리하려면 [**JuriSupport**](https://jurisupport.com) 연동을 권장합니다. 한국 변호사·법무법인 전용 사건 관리 SaaS이며, MCP를 통해 다음을 자동화합니다:

- 사건·의뢰인·상대방·증거 통합 관리
- 서면 정본 보관 + 자동 버전 히스토리 (`create_legal_document`, `update_legal_document`)
- PDF 추출 (`export_document_pdf`)
- 할일·기일·연락 이력 추적
- 사건 간 관계 그래프

**연동 시 흐름 변화**:
| 단계 | JuriSupport 미연동 (기본) | JuriSupport 연동 |
|---|---|---|
| 정본 보관 | 로컬 MD 파일 | JuriSupport 문서 (source of truth) |
| 등록 전 편집 | MD 파일 | MD 파일 |
| 등록 후 편집 | MD 파일 (계속) | **JuriSupport에서 직접 편집** (`inline_edit_legal_document` 등). MD에서 별도 수정 금지 |
| PDF 추출 | 사용자 수동 | `export_document_pdf` 자동 |

연동 방법: [jurisupport.com](https://jurisupport.com) 가입 → MCP 토큰 발급 → Claude 설정에 추가.

### 사용자 로컬 확장 (Optional, 배포본에 포함 안 됨)
사용자 개인 계정·DB에 묶인 자원. **설치되어 있으면 자동 활용, 없으면 자동 스킵**:
- **case-records** (글로벌 스킬) - 과거 사건 DB 하이브리드 검색
- **legal-books** (글로벌 스킬) - 교과서 DB 검색 (사용자 보유 서적)
- **google-workspace MCP** - 개인 캘린더·Gmail

> 위 항목들은 사용자가 별도로 설정해야 작동합니다. 플러그인은 이들의 부재를 감지하고 graceful하게 동작합니다.

## 실무 플레이북 (Template/Instance 분리)

이 플러그인은 **공개 배포 템플릿**과 **사용자 로컬 인스턴스**를 분리한다:

| 파일 | 역할 | git 추적 |
|---|---|---|
| `CLAUDE.md.example` | 공개 배포본. 모든 개인정보는 `<placeholder>` 형태 | ✅ 커밋됨 |
| `CLAUDE.md` | 사용자 로컬 인스턴스. 콜드스타트로 채워진 실제 운영 규칙 | ❌ `.gitignore` |

이 플러그인이 활성화되면 모든 송무 작업에 다음 규칙이 적용된다:
- 법령 인용 시 `korean-law` MCP로 실존 확인 (필수)
- 판결 인용은 `korean-law` MCP `search_precedents`가 1차 검증, 법고을(`beopgoeul-search`)이 2차 검증
- 직접인용(" ")은 원문과 글자 단위로 일치, 아니면 간접인용
- 출처 표기 필수 (저자, 서명, 페이지)
- 소송서류 MD는 사람이 읽기 쉬운 본문을 우선하며, 필요 시 상단 `<!-- jurisupport ... -->` 힌트 태그로 서면유형·출력형식·JuriSupport 등록 의사를 적는다. 이는 개발 문법 요구가 아니라 변환 보조 정보다.
- 서면 제출은 사용자 명시 허락 후 (전자서명·전자제출 직전 정지)

## 설치

### 최초 설치

```bash
# 마켓플레이스 등록
/plugin marketplace add ~/jurisupport-plugins

# 플러그인 설치
/plugin install jurisupport@jurisupport-plugins

# korean-law MCP 설치 (법령·판결 정식 1차 검증, OC 발급 후)
# OC 발급 전 실습은 /jurisupport:offline-law-fallback 사용
/plugin marketplace add chrisryugj/korean-law-mcp
/plugin install korean-law@korean-law-marketplace

# 사무소 플레이북 학습 (콜드스타트가 자동으로 CLAUDE.md.example → CLAUDE.md 복사 후 인터뷰)
/jurisupport:cold-start-interview
```

### 정책 변경 시

```bash
/jurisupport:cold-start-interview
# → 기존 CLAUDE.md 감지 → "기존 값 유지 / 전체 재설정 / 특정 섹션만 갱신" 선택
```

### 개발자가 git에 push할 때

```bash
# CLAUDE.md는 .gitignore되어 자동 제외됨. CLAUDE.md.example만 커밋
git add CLAUDE.md.example
git commit -m "Update template"
```

⚠️ **절대 `CLAUDE.md`를 git에 커밋하지 말 것.** 개인정보 노출 위험.

## 버전

0.2.8 - OC 발급 전 시연·실습용 오프라인 법령 전문 폴백 추가(헌/민/형/상법, 소송법, 주요 특별형법)
0.2.7 - 개인 프로필 설명을 사용자 친화적 문구로 정리
0.2.6 - 프로필 업로드 전 웹 동의 절차 반영
0.2.5 - 개인 프로필 완성 및 선택적 JuriSupport 업로드 스킬 추가
0.2.4 - 소송문서 Markdown 작성 규칙과 JuriSupport 힌트 태그 보강
0.2.3 - mock-hearing 추가, 구상 단계 자료 확인, §5 인덱스 보강
0.2.0 - 서면 작성 규칙·서면 유형·JuriSupport 순서 규칙 보강
0.1.0 - 프로토타입 (2026-05-15)

## 제작

쥬리서포트 (admin@jurisupport.com)
