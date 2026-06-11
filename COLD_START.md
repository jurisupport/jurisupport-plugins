# 콜드스타트 — 패키지 설치 직후, 첫 사건까지 한 페이지로

> 본 패키지를 처음 설치한 변호사를 위한 0 → 1 가이드.
> 약 30분 ~ 1시간 안에 첫 사건을 클로드코드로 처리하는 데까지 갑니다.

---

## 0. 준비물

- 클로드 Pro 또는 Max 계정 (월 20달러 이상)
- Mac 또는 Linux 노트북 (Windows는 WSL2)
- Homebrew (Mac) 또는 apt (Linux)
- 법제처 Open API 인증키(OC) ([발급 가이드](guides/07_law_openapi_key.md))
- 첫 사건 1개 (현재 작업 중인 진짜 사건)
- 약 30분 ~ 1시간

---

## Step 1. 패키지 설치 (15분)

```bash
git clone https://github.com/jurisupport/jurisupport-plugins.git
cd jurisupport-plugins
./install.sh
```

### install.sh가 묻는 것들 (순서대로 답)

| 질문 | 답 |
|---|---|
| 데이터 보호 Hook 설치 | Yes (자동) |
| 법제처 Open API 키 | [발급 가이드](guides/07_law_openapi_key.md)의 `OC` 값 입력 |
| ~/사건 디렉토리 + CSV 템플릿 복사 | **Yes** (권장) |
| legal-books 검색 서버 설치 | **첫날은 No** (책 스캔이 안 끝났으므로) |
| case-records 검색 서버 설치 | **첫날은 No** (과거 사건 인덱싱이 안 끝났으므로) |

→ legal-books·case-records는 둘째 주 이후 추가 설치 가능 (가이드 02·03 참조).

### 설치 후 확인

```bash
# 데이터 보호 Hook 작동 확인
ls ~/.claude/settings.json && grep -q "pretool_data_protection" ~/.claude/settings.json && echo "✅ Hook OK"

# 가이드 스킬 4개 설치 확인
ls ~/.claude/skills | grep -E "lbox-guide|beopgoeul-guide|legal-books|case-records"

# JuriSupport 플러그인 등록 확인
ls ~/.claude/plugins/cache/jurisupport-plugins/jurisupport/.claude-plugin/plugin.json
```

---

## Step 2. 보안 가이드 정독 (5분)

```
~/jurisupport-plugins/guides/00_security.md
```

특히 다음 5가지 절대 금지 사항을 기억:

1. AI에 사건자료 학습 동의 절대 거부
2. 무료 번역기·OCR에 사건자료 업로드 금지
3. 사건폴더 외부 공유링크 금지
4. 클로드코드에 "외부로 보내달라" 요청 금지
5. 일반 카톡·텔레그램으로 사건자료 송수신 금지

---

## Step 3. 사건정보 관리표 첫 행 작성 (5분)

엑셀에서 `~/사건/_사건정보관리표.csv`를 열고 **SAMPLE-001 행을 본인 첫 사건 정보로 덮어쓰기**.

또는 클로드코드에서:

```bash
cd ~/사건
claude
```

```
~/사건/_사건정보관리표.csv 에 새 행 추가해줘.
나에게 하나씩 질문해줘.
```

클로드코드가 사건ID·의뢰인·사건명·법원·쟁점 등을 순서대로 물어보고 자동 입력.

---

## Step 4. JuriSupport 콜드스타트 인터뷰 (15분)

사무소 운영 정책(의뢰인 호칭, 인용 표기, 파일 포맷 등)을 한 번 학습시킵니다. **최초 1회만 필요**.

```bash
cd ~/사건
claude
```

```
/jurisupport:cold-start-interview
```

클로드코드가 다음을 인터뷰:

- 의뢰인 호칭 규칙 (예: "○○님" / "선생님" / "원고")
- 직접인용 정책 (큰따옴표 사용·번역 병기 등)
- 본문 표현 정책 (예: "판례" 금지, "판결" 사용)
- 사건기록 저장 위치 (~/사건/)
- 전자소송 계정 (선택)
- 사무소 표준 서면 양식

답변이 끝나면 `~/사건/CLAUDE.md` 파일이 자동 생성/갱신됩니다. 이후 모든 송무 작업에 이 플레이북이 적용됩니다.

---

## Step 5. 첫 사건폴더 만들기 (5분)

`~/사건/` 아래에 첫 사건폴더 생성:

```bash
mkdir -p ~/사건/2026-001_홍길동_대여금/{01_위임계약,02_의뢰인자료,03_소송서류,04_갑호증,05_을호증,06_참고판례,07_의뢰인소통}
```

또는 클로드코드에서:

```
~/사건/2026-001_홍길동_대여금 폴더 만들어줘.
표준 하위 구조(01_위임계약/, 02_의뢰인자료/, ...)도 같이.
```

이제 본인이 가진 사건자료(PDF·DOCX·HWP)를 해당 하위 폴더에 넣으면 됩니다.

---

## Step 6. 첫 준비서면 작성 (15분)

사건폴더에 자료가 들어 있는 상태에서:

```bash
cd ~/사건/2026-001_홍길동_대여금
claude
```

다음 명령을 하나씩 던지며 진행:

### A. 사건 파악

```
이 폴더의 사건기록을 시간순으로 정리하고
이 사건의 핵심 쟁점을 알려줘.
```

### B. 법령 검증

```
korean-law MCP로 위 쟁점과 관련된 민법 조문을 가져와줘.
```

### C. (선택) 판례 검색

본 패키지의 `lbox-guide` 또는 `beopgoeul-guide` 스킬을 활용:

```
lbox-guide 스킬로 검색 키워드 3개 추천해줘.
나는 그걸로 lbox에서 직접 검색해서 PDF를 06_참고판례/ 폴더에 저장할게.
```

→ 사용자가 직접 lbox / 법고을 검색 후 PDF 저장 → 다시 클로드에 분석 요청

### D. 준비서면 초안 작성

```
위 사건 파악 + 법령 + 판례 분석을 토대로
원고 대리인 입장에서 준비서면 1차 초안을 마크다운으로 작성해줘.
03_소송서류/030_준비서면_1차초안_2026-05-19.md로 저장.
```

### E. 검증 + 완성본

```
초안에서 인용한 법령 조문번호와 판결번호를
korean-law MCP로 모두 재확인해줘.
실존하지 않는 항목이 있으면 알려줘.
```

→ 검증 통과 후 변호사 검토·수정 → 정본 등록

---

## 첫 사건 완료 후 (둘째 주부터)

| 추가 작업 | 가이드 |
|---|---|
| 책 스캔하여 legal-books DB 구축 시작 | `guides/02_book_scanning.md` |
| 과거 종결 사건 인덱싱 | `guides/03_case_records.md` |
| 2세션 병렬 시도 (다른 사건 2개 동시) | 시연스크립트 참조 |
| 사무소 CLAUDE.md 다듬기 | `~/사건/CLAUDE.md` 직접 편집 |

legal-books는 무료 로컬 OCR로 10~20쪽 샘플부터 확인하세요. 유료 OCR과 Gemini 임베딩은 페이지·청크 수가 늘면 비용이 커질 수 있으므로, 책 1권씩 점진적으로 진행하는 것을 권장합니다.

---

## 문제 발생 시

| 증상 | 해결 |
|---|---|
| `install.sh` 실패 | `INSTALL_PARTIAL.md` 참조 — 부분 설치 |
| 데이터 보호 Hook 차단됨 (의도한 작업인데도) | 의뢰인 정보 마스킹하거나 외부 도구 사용 안 함 |
| `/jurisupport:cold-start-interview` 실행 안 됨 | 플러그인 등록 확인 (Step 1 마지막 검증) |
| 클로드코드 한글로 답 안 함 | "한국어로 답해주세요" 명시 |
| 검색 서버 (legal-books/case-records) 응답 없음 | `~/legal-books/scripts/server.sh restart` |

---

## 핵심 메시지

> 1주차: 한 사건 한 세션, 첫 준비서면 작성
> 2주차: 2 사건 2 세션 동시 진행
> 3주차: legal-books·lbox-guide·beopgoeul-guide 적극 활용
> 4주차: 본인 사무소 워크플로우 일부를 cold-start-interview로 추가 학습
>
> 그리고 본인 사무소만의 플러그인을 만들어볼 단계입니다.
