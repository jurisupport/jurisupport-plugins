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
│   │   ├── 001.pdf                      ← OCR된 PDF 원본 (PDF 입력 시)
│   │   ├── 001.md                       ← 마크다운 변환본 또는 직접 입력본
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

### OCR 비용 경고와 추천 순서

교과서 OCR은 페이지 수가 많아지면 돈과 시간이 빠르게 늘어납니다. 처음부터 사무소 서가 전체를 클라우드 OCR에 올리지 말고, **10~20쪽 샘플 → 책 1권 → 자주 쓰는 책 3권** 순서로 품질과 비용을 확인하세요.

추천 순서:

1. **무료 로컬 OCR: OCRmyPDF + Tesseract (기본 권장)**
   - 본 toolkit의 `add_book.sh --pdf`가 쓰는 방식입니다.
   - 소프트웨어 비용은 없고, 책 본문을 외부 OCR 서비스로 보내지 않습니다.
   - 단점: 스캔 품질이 나쁘거나 2단 편집·각주가 복잡하면 오타와 순서 뒤섞임이 생길 수 있습니다.
   - 참고: [OCRmyPDF 문서](https://ocrmypdf.readthedocs.io/en/latest/introduction.html), [Tesseract](https://github.com/tesseract-ocr/tesseract)

2. **이미 쓰는 PDF 프로그램의 OCR: Adobe Acrobat 등**
   - 사무소에 이미 구독이 있으면 추가 API 비용 없이 가장 편할 수 있습니다.
   - OCR 후 **검색 가능한 PDF**로 저장한 뒤 아래 `add_book.sh --pdf`로 추가하세요. MD를 직접 만들 필요가 없습니다.
   - 단점: 구독 비용이 있고, 플랜·지역·계정 유형별 가격이 바뀝니다. 작업 전 [Adobe 공식 가격표](https://www.adobe.com/acrobat/pricing.html)를 확인하세요.

3. **클라우드 OCR: Google Cloud Vision/Document AI, NAVER CLOVA OCR 등**
   - 스캔 품질이 나쁘거나 대량 자동화가 필요할 때만 검토하세요.
   - 페이지 단위 과금이라 교과서 여러 권을 넣으면 예상보다 커질 수 있습니다. Google 공식 요금표 기준 Document OCR 계열은 페이지/단위 사용량으로 과금되고, 부가 옵션은 별도 비용이 붙을 수 있습니다. NAVER CLOVA OCR도 종량제 안내가 있으므로 포털 요금표를 확인해야 합니다.
   - 참고: [Google Cloud Vision 가격](https://cloud.google.com/vision/pricing), [Google Document AI 가격](https://cloud.google.com/document-ai/pricing), [NAVER CLOVA OCR](https://www.ncloud.com/product/aiService/ocr)

비용을 줄이는 원칙:

- 먼저 무료 로컬 OCR로 20쪽만 시험합니다.
- OCR 결과가 검색 가능한 PDF로 나오면 MD를 만들지 말고 `--pdf`로 추가합니다.
- 클라우드 OCR은 꼭 필요한 책만, 책 1권 단위로 비용을 확인하면서 진행합니다.
- OCR 비용과 별개로, 인덱싱 단계에서 Gemini 임베딩 API 호출도 발생합니다. 여러 권을 한꺼번에 넣으면 이 비용·제한도 같이 커집니다.

### Step 2-A. PDF로 추가 (권장)

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

### Step 2-B. MD로 직접 추가 (최후 수단)

일반 사용자에게 처음부터 MD 작성을 맡기는 방식은 권장하지 않습니다. 가능하면 무료 로컬 OCR이나 이미 쓰는 PDF 프로그램으로 **검색 가능한 PDF**를 만든 뒤 `--pdf`로 넣으세요.

그래도 스캔 PDF가 없고 텍스트만 남아 있거나, 특정 챕터만 사람이 정리해야 하는 경우에는 `.md` 파일을 만든 뒤 `--md`로 넣을 수 있습니다. 이 방식은 페이지 번호를 사람이 책임지는 방식입니다. 검색 결과의 인용 페이지가 이 MD의 `## p.숫자` 머리글을 그대로 따라가므로, 페이지 구분이 가장 중요합니다.

#### 최소 템플릿

파일명 예시: `~/scan/곽윤직_민법총칙_제9판.md`

```md
# 곽윤직 - 민법총칙 (제9판)

## p.1

1쪽에 실제로 있는 본문을 그대로 붙여넣습니다.
머리말, 목차, 각주도 검색에 필요하면 그대로 둡니다.

## p.2

2쪽 본문을 붙여넣습니다.
줄바꿈은 너무 신경 쓰지 않아도 되지만, 문장 순서는 원문과 같게 둡니다.

## p.3

3쪽 본문을 붙여넣습니다.
```

#### 작성 규칙

- 각 실제 책 페이지마다 반드시 `## p.1`, `## p.2`처럼 페이지 머리글을 둡니다.
- 본문은 요약하지 말고 원문 텍스트를 넣습니다. 검색 결과의 `chunk_text`가 직접 인용 검증에 쓰입니다.
- 쪽수가 로마숫자이거나 목차 페이지이면 실제 인용에 쓸 번호를 정해 `## p.i`, `## p.목차`가 아니라 `## p.1`처럼 숫자로 맞춥니다. 숫자가 애매하면 본문 시작 페이지부터 넣는 편이 안전합니다.
- 한 페이지 안에서 제목, 본문, 각주 순서가 크게 뒤섞이지 않게 합니다. OCR이 단을 섞은 경우 문장 흐름만 바로잡습니다.
- OCR 오타는 눈에 띄는 법률용어와 조문번호 위주로 고칩니다. 모든 띄어쓰기까지 완벽히 고치려고 시작하면 너무 오래 걸립니다.
- 판권지, 광고, 빈 페이지처럼 검색 가치가 낮은 페이지는 생략해도 됩니다. 다만 생략한 페이지 번호를 건너뛰어도 됩니다.

#### MD 추가 명령

```bash
~/jurisupport-plugins/toolkit/legal-books/scripts/add_book.sh \
  --md "~/scan/곽윤직_민법총칙_제9판.md" \
  --author "곽윤직" \
  --title "민법총칙" \
  --edition "제9판" \
  --year 2018 \
  --publisher "박영사"
```

처리 흐름:
1. MD의 `## p.숫자` 머리글 기준으로 페이지 분리
2. 청크 분할 (1000자 단위, 200자 오버랩)
3. Gemini로 임베딩 생성
4. DB에 삽입

#### 사용자가 직접 확인할 체크리스트

- 첫 3페이지와 중간 1페이지를 열어 `## p.숫자`가 실제 책 페이지와 맞는지 확인
- 핵심 법률용어 5개 정도를 골라 OCR 오타가 없는지 확인
- 각주가 본문과 완전히 섞여 의미가 깨지는 페이지가 있으면 그 페이지만 정리
- 저장 인코딩은 UTF-8로 유지
- 추가 후 아래 검색 테스트에서 방금 넣은 책 제목이나 핵심어가 검색되는지 확인

너무 완벽하게 만들려고 하지 않아도 됩니다. 첫 권은 "검색 가능한 초안"을 만든 뒤, 실제 사건에서 자주 검색되는 부분부터 조금씩 보강하는 방식이 가장 덜 힘듭니다.

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

책 추가가 중간에 실패했거나 검색 결과가 이상하면, 책 폴더의 `001.pdf` 또는 `001.md`를 기준으로 DB 청크와 FTS 인덱스를 다시 만들 수 있습니다.

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
