---
name: cold-start-interview
description: 송무 플러그인 최초 1회 설정 - 사무소 플레이북(CLAUDE.md)을 인터뷰로 채운다. 의뢰인 호칭 규칙, 인용 정책, 파일 포맷 정책, 사건기록 저장 위치 등을 학습.
license: MIT
metadata:
  category: legal
  locale: ko-KR
  one-shot: true
---

# 송무 플러그인 콜드스타트 인터뷰

## What this skill does

송무 플러그인을 처음 설치한 변호사에게 사무소 운영 정책을 묻고, 그 답변으로 `CLAUDE.md`(실무 플레이북)를 갱신한다. 이후 모든 송무 작업에 이 플레이북이 적용된다.

## When to use

- `/songmu-legal:cold-start-interview` 직접 호출
- "송무 플러그인 처음 설정", "플레이북 학습" 등의 키워드

## Workflow

### Step 0: Template/Instance 상태 확인

플러그인 디렉토리 구조:
```
<plugin-dir>/
├── CLAUDE.md.example    ← 공개 배포 템플릿 (placeholder)
└── CLAUDE.md             ← 사용자 로컬 인스턴스 (.gitignore됨, 개인정보 포함)
```

다음 순서로 점검:

**Case A: CLAUDE.md 없음 + CLAUDE.md.example 있음** (신규 설치)
1. `cp CLAUDE.md.example CLAUDE.md` 자동 실행
2. 사용자에게 안내: "템플릿을 복사해서 로컬 인스턴스를 생성했습니다. 이제 인터뷰로 채우겠습니다."
3. Step 1로 진행

**Case B: CLAUDE.md 있음 + 채워진 값 있음** (재실행)
1. 현재 채워진 값 요약 출력
2. 선택지 제공:
   - "기존 값 유지 + 비어있는 부분만 채우기" (기본)
   - "전체 다시 채우기" (덮어쓰기)
   - "특정 섹션만 갱신" (섹션 번호 지정)
3. 사용자 선택대로 진행

**Case C: 두 파일 모두 없음** (비정상)
- 플러그인 설치가 손상됨. 사용자에게 재설치 권장 후 종료.

⚠️ **절대 CLAUDE.md.example를 직접 수정하지 말 것.** template는 공개 배포본이며, 모든 변경은 사용자 인스턴스(CLAUDE.md)에만 가해진다.

### Step 1: 사무소 정보

다음 질문을 순서대로 묻는다 (AskUserQuestion 사용).

1. **사무소명**
2. **담당 변호사 이름·이메일** (이미 메모리에 있으면 확인만)
3. **업무 외 개인 일정 이메일** (선택)

### Step 2: 의뢰인 호칭

- "특별한 호칭 규칙이 필요한 의뢰인이 있나요? (예: 친분 있는 의뢰인 → '○○ 형님', 회사 대표 → '○○ 대표님')"
- 기존 메모리(`project_client_*`)에서 자동 추출하여 표로 정리

### Step 3: 인용·검증 정책

기본값 제시 + 변경 여부 확인:

- 법령 인용 시 `korean-law` MCP 검증 **필수** (기본 ON)
- 판례 인용 자동 검증: `korean-law` 1차 + `beopgoeul-search`(법고을) 2차 **필수** (기본 ON)
  - ⚠️ `lbox-search` 스킬은 자동 호출하지 않음(도구 불안정). lbox.kr 사이트 자체는 사용자가 직접 수동 검색해 결과를 알려주는 방식으로만 활용
- 직접인용은 원문 글자 단위 일치, 못 맞추면 간접인용 (기본 ON)
- 교과서 인용 시 저자·서명·페이지 명시 (기본 ON)

각 항목 "유지 / 완화 / 강화" 선택.

### Step 4: 파일 포맷 정책

- **모든 작업(초안·수정·검토)은 Markdown**
- **최종본 확정 시 JuriSupport에 서류 유형별로 등록** (`create_legal_document`)
  - 서류 유형: 준비서면 / 답변서 / 의견서 / 소장 / 항소이유서 / 상고이유서 / 보정서 / 기타
- 법원 제출용: JuriSupport에서 PDF 추출 (사용자 명시 요구 시)
- HWP 변환은 비활성 (한글 품질 신뢰 어려움)
- docx 변환 시 점(•) 글머리 사용? (기본 OFF)

### Step 5: 사건기록 저장소 + CSV 사건 인덱스

#### 5-1. 저장소 경로
- JuriSupport (기본, 연동된 경우)
- 로컬 디렉토리 경로 확인 (`~/법원기록_md/`, `~/법원기록/`)
- OneDrive rclone 리모트명 확인 (`onedrive:`)
- 구글드라이브 사용 여부 (기본 OFF)

#### 5-2. CSV 사건 인덱스 (JuriSupport 미사용자 또는 보조 사용자)
JuriSupport를 쓰지 않으면 `case-index` 스킬이 정본. 다음 항목 확인:

- "CSV 사건 인덱스를 사용하시겠습니까?"
  - **사용 (JuriSupport 미연동자 기본)**: 경로를 묻는다. 기본 제안: `<클라우드 사건폴더 경로>/_index.csv`
  - **사용 (JuriSupport 보조)**: 사용자가 명시 요청한 경우에만. 백업·오프라인 뷰 용도
  - **미사용 (JuriSupport 전용자 기본)**: JuriSupport가 정본
- CSV 경로 확정되면:
  - 파일이 없으면 `python3 <plugin>/skills/case-index/case_index.py --csv <경로> init` 으로 헤더만 생성
  - CLAUDE.md §5에 경로 기록 (`<CSV 사건 인덱스 경로>` placeholder 치환)
- 컬럼은 고정: `사건번호,법원,사건명,의뢰인,상대방,진행단계,다음기일,비고`

### Step 6: 법원 제출 정책 안내

- 본 플러그인은 **법원 전자제출 자체를 자동화하지 아니함**을 사용자에게 명시
- 플러그인 책임 범위: 사건기록 분석 → 서면 초안 → 인용 검증 → 정본 등록 → PDF 추출까지
- 이후 ecfs.scourt.go.kr 등 법원 전자제출 시스템 로그인·서명·제출은 사용자가 직접 수행
- 인터뷰에서는 이 정책을 안내만 하고, 사용자 입력은 받지 아니함

### Step 7: 제출 범위 정책

- 이메일·서면 제출 시 "발송 직전 재확인" 필수? (기본 ON)

### Step 8: 안전 가드

기본 Hard Stop 목록 제시, 추가 항목 있는지 확인:
- 법원 전자제출
- 이메일 발송
- JuriSupport status 변경
- 사건 status 변경
- 파일 삭제

### Step 9: CLAUDE.md (로컬 인스턴스) 갱신

수집한 답변으로 **`CLAUDE.md`** (사용자 인스턴스, .gitignore됨) 섹션을 채운다. Edit 도구로 각 섹션을 수정.

**절대 `CLAUDE.md.example`를 수정하지 말 것.** template는 공개 배포본이다.

치환할 placeholder 예시:
- `<사무소명>` → 사용자 입력
- `<변호사명>` → 사용자 입력 또는 메모리에서 추출
- `<업무 이메일>` / `<개인 이메일>` → 입력
- `<로컬 사건기록 디렉토리 경로>` → 입력 (예: `/Users/xxx/법원기록_md/`)
- `<클라우드 사건폴더 경로>` → 입력 (예: `onedrive:진행중사건/`)
- `<CSV 사건 인덱스 경로>` → 입력 (예: `onedrive:진행중사건/_index.csv`) 또는 "사용 안함"

### Step 10: 메모리 동기화

CLAUDE.md에 새로 들어간 규칙 중 **다른 플러그인에도 적용될 만한 것**은 글로벌 메모리(`~/.claude/projects/-Users-<your-username>/memory/`)에도 저장 여부 확인:
- 의뢰인 호칭 → `project_client_*`
- 인용 정책 → `feedback_*`
- 파일 포맷 → `feedback_*`

### Step 11: 완료 메시지

```
✅ 송무 플러그인 설정 완료
- 플레이북: <플러그인>/CLAUDE.md
- 메모리 동기화: <건>
- 다음: /songmu-legal:brief-protocol 으로 첫 서면 작성
```

## Notes

- 이 스킬은 **최초 1회 + 정책 변경 시** 호출. 매번 호출하지 않음.
- 인터뷰 도중 사용자가 "기본값 그대로" 답하면 default 적용.
- 메모리에 이미 있는 값은 default로 미리 채워서 제시.
- 인터뷰가 길어지면 중간에 "여기서 일단 멈출까요?" 옵션 제공.
