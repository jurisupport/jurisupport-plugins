# 법률서적 검색 시스템 — 스캔·OCR·임베딩·검색 (legal-books)

> 본인 사무소 보유 법률서적(교과서)을 클로드코드가 검색하여 출처와 함께 답변하도록 만드는 방법.

---

## 무엇이 가능해지나

설치 + 책 첫 권 추가 후:

```
"이 사건 시효 쟁점에 대해 교과서 바탕으로 정리해줘"
→ 곽윤직 『민법총칙』 제○판, p.○○○ 인용 + 본문 발췌 + 적용
```

```
"부당해고 정당한 이유에 대한 학설 정리"
→ 김형배 『노동법』 p.○○○ + 임종률 『노동법』 p.○○○ + 비교
```

책이 늘어날수록 커버리지·정확도 상승. **콜드스타트 = 책 0권**에서 시작해 점진적으로 추가.

---

## 시스템 구조

```
~/legal-books/
├── books/                                책별 폴더
│   ├── 001_곽윤직_민법총칙_제9판/
│   │   ├── 001.pdf                      ← OCR된 PDF 원본
│   │   ├── 001.md                       ← 마크다운 변환본
│   │   ├── 001.meta.json                ← 책 메타데이터 (저자·서명·판·페이지)
│   │   └── 001.chunks.jsonl             ← 청크 + 임베딩
│   ├── 002_지원림_민법강의_제20판/
│   └── ...
├── db/
│   └── books_fts.db                     ← SQLite FTS5 + 임베딩 DB
├── server/
│   └── server.py                        ← 검색 API (포트 8766)
└── scripts/
    ├── add_book.sh                      ← 책 한 권 추가
    └── reindex.sh                       ← 전체 재인덱싱
```

### 검색 가능한 청킹/인덱싱 불변조건

legal-books DB는 "책 파일이 있다"가 아니라 "검색 API가 청크를 다시 찾을 수 있다"가 기준입니다. 직접 스키마를 바꾸거나 다른 인덱서를 만들 때도 아래 조건을 지켜야 합니다.

- `chunks` 테이블은 청크 1개당 1행이어야 하며, 최소 `chunk_id`, `book_id`, `page`, `chunk_text`, `embedding` 컬럼을 유지합니다.
- `chunk_text`는 검색 결과에서 그대로 인용 검증에 쓰이는 원문 조각입니다. 요약문, 메타데이터 JSON, 페이지 전체 경로만 넣으면 안 됩니다.
- `chunks_fts`는 `chunks`를 external content로 참조하는 FTS5 인덱스여야 합니다. 현재 기준:

```sql
CREATE VIRTUAL TABLE chunks_fts USING fts5(
  chunk_text, chunk_id UNINDEXED, book_id UNINDEXED, page UNINDEXED,
  content='chunks', content_rowid='rowid', tokenize='unicode61'
);
```

- 청크를 삽입·재인덱싱한 뒤에는 반드시 `INSERT INTO chunks_fts(chunks_fts) VALUES('rebuild')`를 실행해 FTS 인덱스와 `chunks` 행을 다시 맞춥니다.
- 검색 API는 FTS5 키워드 검색을 항상 먼저 돌리고, Gemini 쿼리 임베딩이 가능할 때 의미 검색 점수를 섞습니다. Gemini가 일시 실패해도 FTS 결과는 반환되어야 합니다.
- 검증은 `/health`의 청크 수만 보지 말고, 실제 `/search`에서 방금 넣은 `chunk_text`의 핵심 단어가 검색되는지 확인합니다.

---

## 설치 (Mac/Linux)

### Step 1. 의존성

```bash
# macOS
brew install python@3.11 ocrmypdf poppler tesseract tesseract-lang
# Linux (Ubuntu/Debian)
sudo apt install python3.11 python3.11-venv ocrmypdf poppler-utils tesseract-ocr tesseract-ocr-kor
```

### Step 2. Gemini API 키 발급

1. https://aistudio.google.com/apikey 접속
2. Google 계정으로 로그인
3. **Create API key** 클릭
4. 기존 Google Cloud 프로젝트를 선택하거나 새 프로젝트 생성
5. 발급된 키 복사
6. 본 패키지 설치 중 입력하거나, 나중에 아래 파일에 저장

```bash
mkdir -p ~/.jurisupport
chmod 700 ~/.jurisupport
printf 'GEMINI_API_KEY=%s\n' '발급받은_키' >> ~/.jurisupport/secrets.env
chmod 600 ~/.jurisupport/secrets.env
```

무료 tier로도 테스트와 소량 인덱싱은 가능합니다. 다만 교과서 1권은 수백~수천 개 청크로 나뉘어 임베딩 API를 반복 호출하므로, 여러 권을 연속으로 넣으면 무료 tier의 RPM/TPM/RPD 제한에 걸려 중간에 멈출 수 있습니다. 사무소 서가를 쉽게 인덱싱하려면 Google AI Studio/Google Cloud 프로젝트에 결제를 연결한 **유료 tier**를 권장합니다.

### Step 3. 본 패키지의 자동 설치 스크립트 실행

```bash
cd ~/jurisupport-plugins/toolkit/legal-books
./install.sh
```

이 스크립트가:
- `~/legal-books/` 디렉토리 생성
- Python venv + 의존성 설치
- 빈 SQLite DB 초기화
- Gemini API 키 등록 (입력 요구)
- 검색 서버 자동 실행 등록 (launchd / systemd)

### Step 4. 검색 서버 작동 확인

```bash
curl -s http://localhost:8766/health
# → {"status":"ok","books":0,"chunks":0}
```

---

## 첫 책 추가

### Step 1. 책 스캔

#### 권장 스캐너

| 환경 | 추천 도구 |
|---|---|
| 사무실 (고용량) | 후지쯔 ScanSnap iX1600 (양면·자동급지·1분 40장) |
| 휴대용 | Adobe Scan (iPhone/Android 무료 앱) |
| 이미 PDF 있음 | 그대로 사용 |

#### 스캔 설정

- 해상도 300dpi 이상 (한글 OCR 정확도)
- 컬러 또는 그레이스케일 (흑백은 그림 손실)
- 양면 (양면 인쇄 책)
- 자동 보정 (기울기·여백)

#### 권장 분할

500페이지 이상은 챕터별로 분할 권장 (한 PDF 100MB 미만으로 유지).

### Step 2. OCR 처리

본 toolkit은 **OCRmyPDF** 사용 (오프라인, 무료, 한글 지원).

```bash
~/jurisupport-plugins/toolkit/legal-books/scripts/add_book.sh \
  --pdf "~/scan/곽윤직_민법총칙_제9판.pdf" \
  --author "곽윤직" \
  --title "민법총칙" \
  --edition "제9판" \
  --year 2018 \
  --publisher "박영사"
```

이 명령이 자동으로:
1. PDF에 OCR 적용 (한국어)
2. 마크다운 변환 (구조 인식)
3. 청크 분할 (1000자 단위, 200자 오버랩)
4. Gemini로 임베딩 생성
5. DB에 삽입

중간에 Gemini rate limit이나 네트워크 오류가 나면 같은 명령을 다시 실행하면 됩니다. 실패한 임시 폴더는 기본적으로 정리되고, DB 반영은 마지막 단계에서만 이루어집니다.

진행 시간 (대략):
- 500쪽 책: OCR 10분 + 임베딩 5분 = 15분

### Step 3. 검색 확인

```bash
curl -s -X POST http://localhost:8766/search \
  -H "Content-Type: application/json" \
  -d '{"query": "소멸시효 채무승인", "top_k": 5}'
```

→ 책 ID + 페이지 + 발췌 + 유사도 점수

### Step 4. 클로드코드 스킬 활성화

```bash
# 본 패키지 install.sh가 이미 등록함. 확인:
ls ~/.claude/skills/legal-books/SKILL.md
```

이제 클로드코드에서:
```
민법 시효 쟁점에 대해 교과서 바탕으로 정리해줘
```
→ 자동으로 legal-books 검색 + 출처 인용 답변.

---

## 책 추가 (콜드스타트 이후)

같은 명령 반복:

```bash
~/jurisupport-plugins/toolkit/legal-books/scripts/add_book.sh \
  --pdf "~/scan/김형배_노동법_제29판.pdf" \
  --author "김형배" \
  --title "노동법" \
  --edition "제29판" \
  --year 2024 \
  --publisher "박영사"
```

추가 즉시 검색 가능 (서버 재시작 불요).

## 재인덱싱/복구

책 추가가 중간에 실패했거나 검색 결과가 이상하면, OCR된 책 폴더를 기준으로 DB 청크와 FTS 인덱스를 다시 만들 수 있습니다.

```bash
# 특정 책만 재인덱싱
~/legal-books/scripts/reindex.sh --book-id 001

# 전체 책 재인덱싱
~/legal-books/scripts/reindex.sh
```

재인덱싱은 같은 `book_id`의 기존 청크를 먼저 지운 뒤 새 청크를 한 트랜잭션으로 넣습니다. 중간에 실패하면 기존 DB 상태가 깨지지 않습니다.

---

## 빈도 높은 책 우선 추천

처음 추가할 때 어떤 책부터?

| 분야 | 입문 1순위 |
|---|---|
| 민법 | 곽윤직 『민법총칙』, 지원림 『민법강의』 |
| 민사소송법 | 이시윤 『민사소송법』 |
| 형법 | 이재상 『형법총론』·『형법각론』 |
| 형사소송법 | 이재상 『형사소송법』 |
| 행정법 | 박균성 『행정법강의』 |
| 노동법 | 김형배 『노동법』 |
| 회사법 | 송옥렬 『상법강의』 |
| 가족법 | 신영호 『가족법강의』 |

본인 전문 분야부터 시작해 5~10권 정도 채우면 실무 활용도 급상승.

---

## 데이터 보호

- 책 PDF·추출 텍스트·청크 파일·SQLite DB는 로컬 `~/legal-books/`에 저장됩니다.
- 책 추가/인덱싱 단계에서는 책 본문 청크가 Gemini 임베딩 API로 전송됩니다.
- 검색 단계에서는 검색 쿼리만 Gemini API로 임베딩 변환됩니다.
- Gemini 검색 임베딩이 실패하면 서버는 로컬 FTS5 검색 결과만 반환합니다. 이 경우 응답에 `warnings`가 포함될 수 있습니다.
- Gemini 학습 옵트인 OFF 여부를 확인하세요.

저작권·계약상 외부 API 전송이 곤란한 서적은 이 toolkit에 추가하지 마세요. 로컬 임베딩 모델 선택지는 아직 기본 설치 흐름에 구현되어 있지 않습니다.

---

## 문제 해결

| 증상 | 해결 |
|---|---|
| OCR이 한글 깨짐 | `tesseract-ocr-kor` 설치 확인 |
| 임베딩 API 호출 실패 | Gemini API 키 만료/오타 확인 (`~/.jurisupport/secrets.env`), 무료 tier rate limit이면 유료 tier 결제 연결 또는 잠시 후 재시도 |
| 검색 결과 0건 | DB 빈 상태 → 책 추가 / 또는 쿼리 키워드 변경 |
| 중간 실패 후 검색 결과가 이상함 | `~/legal-books/scripts/reindex.sh --book-id 001` 로 해당 책 재인덱싱 |
| 서버 죽음 | `~/jurisupport-plugins/toolkit/legal-books/scripts/server.sh restart` |

---

## 관련 파일

- 자동 설치: [toolkit/legal-books/install.sh](../toolkit/legal-books/install.sh)
- 책 추가: [toolkit/legal-books/scripts/add_book.sh](../toolkit/legal-books/scripts/add_book.sh)
- 재인덱싱: [toolkit/legal-books/scripts/reindex.sh](../toolkit/legal-books/scripts/reindex.sh)
- 스킬 정의: [skills/legal-books/SKILL.md](../skills/legal-books/SKILL.md)
