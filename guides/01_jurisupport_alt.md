# JuriSupport 미사용 시 — CSV 기반 사건관리

> JuriSupport(사건관리 SaaS)를 쓰지 않아도 본 패키지의 모든 기능을 활용할 수 있도록 하는 방법.

---

## 핵심 결정

본 패키지는 두 가지 사건관리 방식을 지원합니다.

### 옵션 A. CSV 기반 (무료, 권장 시작점)

- `~/사건/_사건정보관리표.csv` 한 파일 + 사건폴더들
- 엑셀에서 편집 가능
- 클로드코드가 CSV를 읽어 검색·정리·필터링
- 본 가이드 + [templates/사건정보_입력가이드.md](../templates/사건정보_입력가이드.md) 참조

### 옵션 B. JuriSupport SaaS

- 가입: https://jurisupport.com
- MCP 토큰 발급 후 Claude Code에 등록
- 사건·문서·기일·할일·관계 DB 통합 관리
- 본 패키지의 songmu-legal 플러그인이 자동 통합

→ **시작은 옵션 A로**, 사건수·인원 증가하면 옵션 B로 마이그레이션.

---

## 옵션 A 설치 (3분)

### Step 1. 사건 최상위 폴더 만들기

```bash
mkdir -p ~/사건
```

원하는 다른 위치도 가능 (예: `~/OneDrive/사건`, `~/Documents/Cases`).

### Step 2. 템플릿 복사

```bash
cp ~/jurisupport-plugins/templates/사건정보_관리표.csv ~/사건/_사건정보관리표.csv
cp ~/jurisupport-plugins/templates/사건정보_입력가이드.md ~/사건/_입력가이드.md
```

### Step 3. (선택) 엑셀 사본 만들기

엑셀에서 `_사건정보관리표.csv`를 열고 `다른 이름으로 저장` → `xlsx`. 작업은 xlsx로, 저장 시 CSV로도 내보내기 (둘 다 갱신).

### Step 4. 첫 사건 등록

엑셀에서 SAMPLE 행을 본인 첫 사건 정보로 덮어쓰거나, 클로드코드에게 단계별 질문받으며 추가:

```
~/사건/_사건정보관리표.csv 에 새 행 추가해줘.
하나씩 질문해줘.
```

---

## 옵션 A 사용 예시

### "오늘 할 일 정리"

```
~/사건/_사건정보관리표.csv 읽고,
다음기일이 오늘부터 14일 이내인 사건만 추려서 표로 보여줘.
각 사건의 사건폴더 안 가장 최근 서면도 확인해줘.
```

### "신규 사건 인테이크"

```
오늘 새 의뢰인 박○○가 부동산 명도 사건으로 상담왔어.
사건정보관리표에 등록해줘. 사건ID는 2026-006으로.

그리고 ~/사건/2026-006_박○○_부동산명도/ 폴더 만들어줘.
표준 하위 구조(01_위임계약/, 02_의뢰인자료/, ...)도 같이.
```

### "유사 사건 검색"

```
관리표에서 주된쟁점에 '소멸시효'가 들어간 종결 사건들 모두 보여줘.
각 사건폴더의 최종 준비서면 위치도 알려줘.
```

---

## CSV vs JuriSupport 기능 매핑

| JuriSupport 기능 | CSV 기반 대안 |
|---|---|
| `list_cases` | `_사건정보관리표.csv` 전체 |
| `get_case` | 특정 행 + 사건폴더 읽기 |
| `list_legal_documents` | 사건폴더의 `03_소송서류/` 나열 |
| `list_case_evidence` | 사건폴더의 `04_갑호증/`, `05_을호증/` 나열 |
| `update_case_status` | CSV `상태` 컬럼 수정 |
| `create_legal_document` | 사건폴더에 MD 또는 DOCX 저장 |
| `update_legal_document` | 같은 파일 덮어쓰기 (git 사용 시 버전 관리) |
| `list_hearings` | CSV `다음기일` 컬럼 정렬 |
| `create_task` | 사건폴더 `_사건메모.md`에 체크리스트 |

전부 옵션 A로 대체 가능. 다만 다음은 수동 보완 필요:

- **기일 알림** → Google Calendar 별도 등록 (또는 클로드코드가 매일 아침 자동 점검)
- **버전 히스토리** → 사건폴더를 git 저장소로 두면 자동 (단 PDF는 diff 안 됨, MD는 가능)
- **다중 사용자 동시 편집** → 클라우드 동기화 (OneDrive·iCloud) + 동시 편집 충돌 주의

---

## songmu-legal 플러그인과의 통합

`/songmu-legal:brief-protocol` 같은 명령을 사용할 때:

- JuriSupport 연동 O → 정본을 JuriSupport 문서로 저장
- 연동 X → 사건폴더 안 MD 파일로 저장 (기본)

본 옵션 A를 쓰면 자동으로 후자 경로 사용.

추가로 `_사건정보관리표.csv`에 등록된 사건이면 사건 메타정보(사건번호·법원·재판부 등)도 클로드가 자동 인식·반영합니다.

---

## 마이그레이션 (CSV → JuriSupport)

나중에 JuriSupport로 옮기고 싶다면:

1. JuriSupport 가입
2. JuriSupport MCP 등록
3. 클로드코드에게 다음 명령:
   ```
   ~/사건/_사건정보관리표.csv 의 진행중 사건 모두를
   JuriSupport에 등록해줘. mcp__jurisupport__create_case 사용.
   ```
4. 사건폴더 문서들도 일괄 등록 (선택)

기존 CSV는 백업으로 보관.
