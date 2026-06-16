# 사건기록 검색 시스템 — 과거 사건 자산화 (case-records)

> 본인 사무소가 과거에 작성·수령한 서면·증거·판결을 클로드코드가 검색하여 "비슷한 사건 있었나?", "전에 우리는 뭐라고 주장했나?", "법원은 어떻게 판단했나?" 질문에 답하게 만드는 방법.

---

## 무엇이 가능해지나

```
"보증금 반환 동시이행 사건 우리가 전에 어떻게 주장했어?"
→ 2023가단12345 (박○○ 사건) 준비서면 p.4 ~ 5 발췌 + 결과(전부승소)
→ 2022가단67890 (이○○ 사건) 답변서 p.2 발췌 + 결과(일부조정)

"이 쟁점에서 우리는 어떤 신청을 했어?"
→ 과거 문서제출명령신청서·사실조회신청서 5건 + 공통 구조 요약
```

---

## legal-books와의 차이

| 항목 | legal-books | case-records |
|---|---|---|
| 자료 | 교과서 | 우리 사무소 사건기록 |
| 답변 | "법리가 무엇인가" | "우리가 어떻게 주장했고 법원이 어떻게 판단했는가" |
| 포트 | 8766 | 8767 |
| 입력 단위 | 책 1권 | 사건 1건 |

→ **서면 작성 시 둘 다 검색** 권장 (법리 + 실제 적용례).

---

## 시스템 구조

```
~/case-records/
├── cases/                                사건별 폴더 (사용자가 직접 두거나 인덱싱)
│   ├── 2018가단11111_홍○○_대여금/
│   │   ├── 01_위임계약/
│   │   ├── 02_의뢰인자료/
│   │   ├── 03_소송서류/
│   │   │   ├── 001_소장.pdf
│   │   │   ├── 020_준비서면.pdf
│   │   │   └── 090_판결문.pdf
│   │   └── _사건메모.md
│   └── ...
├── db/
│   └── cases_fts.db                      ← SQLite FTS5 + 임베딩
├── server/
│   └── server.py                         ← 검색 API (포트 8767)
└── scripts/
    ├── ingest_case.sh                    ← 사건 1건 인덱싱
    ├── ingest_all.sh                     ← 사건폴더 일괄 인덱싱
    ├── search_case_records.py            ← 토큰 포함 검색 helper
    └── sync_records.sh                   ← 사건기록+작성서류 동시 인덱싱
```

---

## 설치 (Mac/Linux)

본 패키지의 자동 설치 스크립트:

```bash
cd ~/jurisupport-plugins/toolkit/case-records
./install.sh
```

내부적으로 legal-books toolkit과 거의 동일한 구조 (Python venv, SQLite, 선택적 Gemini 임베딩). 검색 API는 설치 시 생성되는 `~/.jurisupport/case-records.token` 로컬 bearer token이 있어야 `/search` 결과를 반환합니다. 일반 사용은 helper 스크립트가 토큰을 자동으로 읽으므로 직접 입력할 필요가 없습니다.

---

## 사건 인덱싱

### 단일 사건

```bash
~/case-records/scripts/ingest_case.sh \
  --case-dir "~/사건/2018가단11111_홍○○_대여금" \
  --case-id "2018가단11111" \
  --case-name "홍○○ 대여금" \
  --status "종결" \
  --result "전부승소"
```

스크립트가 자동으로:
1. 사건폴더의 주장서면·신청서면만 우선 탐색
2. PDF·DOCX·DOC·HWPX·MD·TXT 텍스트 추출 (HWP는 `hwpjs` 설치 시)
3. 파일명 메타파싱 (사건번호·문서종류·일자·당사자 추출) + 파일명 기반 문서분류
4. 청크 분할 (1500자, 300자 오버랩)
5. DB 삽입 + FTS 인덱스 생성

기본값은 사건 본문을 외부 임베딩 API로 보내지 않습니다. 의미 기반 검색을 위해 Gemini 임베딩을 사용하려면 `--allow-external-embedding` 옵션을 명시해야 하며, 이 경우 사건기록 본문 청크가 Gemini API로 전송됩니다.

### 사건폴더 전체 일괄

```bash
~/case-records/scripts/ingest_all.sh --root "~/사건"
```

`~/사건/` 하위 모든 사건폴더를 자동 감지 후 미인덱싱 사건만 추가.

기본값은 주장서면(`argument`)과 신청서면(`application`)만 인덱싱합니다. 증거·계약서·등본까지 모두 넣어야 하면:

```bash
~/case-records/scripts/ingest_all.sh --root "~/사건" --doc-scope all
```

### 사건기록 폴더 + 작성서류 폴더 동시 인덱싱

받은 자료와 작성문서가 분리된 사무소는 이 경로를 사용합니다.

```bash
~/case-records/scripts/sync_records.sh \
  --record-root "~/사건기록" \
  --draft-root "~/작성문서"
```

저장 방식:

- 원본 파일은 복사하지 않음
- DB에는 텍스트 청크, 원본 경로, `source_kind`, `doc_category`만 저장
- `source_kind=record`: 사건기록 폴더에서 온 문서
- `source_kind=draft`: 작성서류 폴더에서 온 문서
- `doc_category=argument`: 소장·답변서·준비서면·의견서 등 주장서면
- `doc_category=application`: 문서제출명령·사실조회·증거신청·보정서 등 신청서면

HWP 계열:

- `.hwpx`: 별도 의존성 없이 zip/xml로 본문 추출
- `.hwp`: `hwpjs` 명령이 설치되어 있으면 본문 추출, 없으면 건너뜀
- `.doc`: macOS `textutil` 또는 `antiword`가 있으면 본문 추출

### 파일명 규칙 (메타파싱용)

본 toolkit의 자동 파싱은 다음 패턴을 따른다 가정:

```
{사건번호}_{문서순번}_{날짜}_{문서종류}_{작성자/대리인}.pdf
```

예:
```
2018가단11111_001001_2018.03.15_소장_원고 대리인_김변호사.pdf
2018가단11111_007001_2018.09.20_준비서면_피고 대리인_이변호사.pdf
2018가단11111_009001_2019.02.10_판결문.pdf
```

→ 이 형식이면 자동으로 사건번호·문서종류·일자가 메타로 추출됨.

다른 형식이면 자동 메타 추출이 제한됩니다. 현재 `--meta-from-filename none` 옵션은 제공하지 않습니다.

---

## 마스킹 정책

본 패키지 기본값: **마스킹 X** (메모리: `project_case_record_db`)

이유:
- 사무소 내부 검색용이며 외부 노출 없음
- 마스킹하면 검색 정확도 저하
- 의뢰인 실명·사건번호·금액 그대로 두어야 "어떤 사건이었는지" 빠르게 식별

**단**, 다음의 경우는 마스킹 필요:
- 사건기록을 외부 강의·논문에 인용 시
- 다른 변호사·직원과 공유 시 (단, 변호사윤리 검토 필수)

---

## 활용 예시 (클로드코드)

### 비슷한 사건 검색

```
보증금 반환 청구 사건 우리가 전에 처리한 적 있는지 case-records에서 찾아줘.
사건번호 + 결과 + 핵심 쟁점 표로 정리.
```

### 우리 측 주장 패턴 재사용

```
2018가단11111 사건의 준비서면에서 동시이행 항변 반박 부분 가져와줘.
지금 작성 중인 사건(2026가단99999)에 맞게 수정.
```

### 상대측 패턴 학습

```
대형 보험사가 피고일 때 보통 답변서에서 어떤 항변을 했어?
지난 3년치 사건 검색해서 정리.
```

### 판결문 기반 학습 (`--doc-scope all`로 판결문까지 인덱싱한 경우)

```
환경 분쟁 사건에서 우리가 패소한 사건들 모아서 패소 이유 정리해줘.
다음에 비슷한 사건에서 피해야 할 주장 패턴이 뭔지.
```

---

## 직접 검색 테스트

```bash
~/case-records/scripts/search_case_records.py "보증금 반환" --top-k 3 --doc-category argument
~/case-records/scripts/search_case_records.py "문서제출명령" --top-k 3 --doc-category application
~/case-records/scripts/search_case_records.py "소멸시효" --source-kind draft --top-k 5
```

직접 HTTP 호출이 필요한 경우:

```bash
TOKEN="$(cat ~/.jurisupport/case-records.token)"
curl -s -X POST http://localhost:8767/search \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"query":"보증금 반환","top_k":3}'
```

---

## 데이터 보호

- 기본 인덱싱은 사건기록 본문을 로컬 SQLite DB와 FTS 인덱스에만 저장합니다.
- `--allow-external-embedding`을 명시하면 사건 본문 청크가 Gemini 임베딩 API로 전송됩니다.
- 검색 서버는 기본적으로 FTS 검색을 수행합니다. 외부 query 임베딩을 허용하려면 서버 환경변수 `CASE_RECORDS_ALLOW_EXTERNAL_EMBEDDING=1`을 별도로 설정해야 합니다.
- `/search` API는 설치 시 생성되는 로컬 bearer token 없이는 결과를 반환하지 않습니다. `search_case_records.py` helper를 쓰면 토큰 입력 없이 검색할 수 있습니다.
- 데이터 보호 Hook은 보조 안전장치입니다. 외부 도구로 사건자료를 보내기 전에는 사용자가 직접 전송 범위를 확인해야 합니다.

---

## 콜드스타트 (처음 시작 시)

기본은 빈 DB. 사건 0건 상태에서:

- 검색 호출 → 결과 0건 + 사용자에게 사건 추가 안내

처음 인덱싱할 사건 추천 우선순위:
1. **최근 종결된 사건 10건** (기억이 생생하고 검증 가능)
2. **반복적 사건 유형** (대여금·임대차·노동·이혼 등 사무소 주력 분야)
3. **승소·일부승소 사건** (재사용 가치 큰 주장 포함)

5건 정도부터 검색 결과 의미 있어지고, 50건 넘으면 본격 활용 가능.

---

## 관련 파일

- 자동 설치: [toolkit/case-records/install.sh](../toolkit/case-records/install.sh)
- 사건 추가: [toolkit/case-records/scripts/ingest_case.sh](../toolkit/case-records/scripts/ingest_case.sh)
- 일괄 인덱싱: [toolkit/case-records/scripts/ingest_all.sh](../toolkit/case-records/scripts/ingest_all.sh)
- 검색 helper: [toolkit/case-records/scripts/search_case_records.py](../toolkit/case-records/scripts/search_case_records.py)
- 스킬 정의: [skills/case-records/SKILL.md](../skills/case-records/SKILL.md)
