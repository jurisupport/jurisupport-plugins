# jurisupport-plugins

> **변호사용 클로드코드 통합 패키지** — 한국 송무 자동화의 표준 워크플로우
>
> 쥬리서포트 주식회사 ([jurisupport.com](https://jurisupport.com))

![License](https://img.shields.io/badge/License-MIT-blue.svg)
![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey)
![Locale](https://img.shields.io/badge/Locale-ko--KR-red)
![Claude Code](https://img.shields.io/badge/Claude%20Code-Required-orange)

---

## 한 줄 요약

사건폴더를 던지면 **사실관계 정리 → 쟁점 추출 → 법령·판례 검증 → 준비서면 초안·완성본까지** 자동 작성합니다. 모든 단계에 변호사 책임 검증을 거치며, 데이터 보호 Hook은 알려진 외부 도구와 한국형 식별정보 패턴을 탐지하는 보조 안전장치로 작동합니다.

---

## ⚠️ 가장 먼저 읽어야 할 것

| 문서 | 소요 시간 | 내용 |
|---|---|---|
| **[guides/00_security.md](guides/00_security.md)** | 5분 | 의뢰인 정보 보호 원칙 (필독) |
| **[COLD_START.md](COLD_START.md)** | 30분 | 설치 → 첫 사건까지 한 페이지 가이드 |

---

## 빠른 시작

### macOS / Linux — 한 줄 자동 설치

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/bootstrap.sh)
```

위 한 줄이 **Homebrew → jq·git·python·node → Claude Code → 본 패키지 git clone → install.sh 실행**까지 이어서 설치합니다 (약 5~10분).

보안이 엄격한 사무소 환경에서는 한 줄 설치 전에 스크립트를 내려받아 검토하거나, 릴리스 태그를 고정해 수동 설치하는 방식을 권장합니다.

bootstrap 완료 후:
```bash
claude                            # 새 터미널에서 OAuth 로그인 1회
```

### Windows — 한 줄 자동 설치 (PowerShell)

PowerShell 실행 방법:

1. Windows `시작` 메뉴에서 `PowerShell` 검색
2. **Windows PowerShell** 또는 **PowerShell**을 일반 실행 (관리자 권한 불필요)
3. 아래 한 줄을 붙여넣고 `Enter`

```powershell
irm https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/windows-bootstrap.ps1 | iex
```

이 한 줄이 **모든 의존성(Git/Node/Python/Chrome/Tesseract/qpdf/Ghostscript/rclone) + Claude Code + 본 레포 + install.sh까지** 자동으로 끝냅니다 (약 15분).

회사 보안 정책이나 ExecutionPolicy 때문에 `irm | iex`가 차단되면 같은 PowerShell 창에서 아래 두 줄을 대신 실행하세요.

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
iwr https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/windows-bootstrap.ps1 -UseBasicParsing | iex
```

PowerShell 한 줄 설치도 빠른 시작용입니다. 조직 보안 정책이 엄격하면 스크립트 내용을 먼저 검토한 뒤 실행하세요.

사용자가 답할 것: UAC 팝업 "예", install.sh 단계별 `[Y/n]`, korean-law용 법제처 Open API 키([발급 가이드](guides/07_law_openapi_key.md)), (선택) Gemini API 키.

제3자 PC 설치를 지원해야 하면 진단 리포트 옵션을 켠 뒤 실행하세요. 실패 시 설치 로그·Windows 버전·winget/Git/Node/npm/Python/rclone/Claude Code 상태를 ZIP으로 묶고, 업로드 엔드포인트로 전송을 시도합니다.

```powershell
$env:JURISUPPORT_SUPPORT_REPORT = "1"
irm https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/windows-bootstrap.ps1 | iex
```

자세한 포함 정보와 엔드포인트 계약: [SUPPORT_REPORTS.md](SUPPORT_REPORTS.md)

WSL2를 선호하시면 [WINDOWS_WSL.md](WINDOWS_WSL.md) (W2 옵션) 참조 — 회사 보안프로그램이 매우 강한 경우만 권장.

### 사전 준비

- **클로드 Pro/Max 가입** (https://claude.ai/upgrade) — 결제 필요, 자동화 불가
- (Mac/Linux) 관리자 비밀번호 — Homebrew 설치 시 1회 입력
- (Windows) winget 사용 가능한 Windows 10 22H2+ 또는 Windows 11

### 수동 설치 (사전 준비물 직접 설치한 경우)

```bash
git clone https://github.com/jurisupport/jurisupport-plugins.git
cd jurisupport-plugins
./install.sh              # Mac/Linux/Windows(Git Bash) 공통
```

수동 사전 설치 가이드: [AUDIENCE_PRE_INSTALL.md](AUDIENCE_PRE_INSTALL.md) (Mac/Linux) / [WINDOWS_NATIVE.md](WINDOWS_NATIVE.md) (Windows 네이티브) / [WINDOWS_WSL.md](WINDOWS_WSL.md) (Windows WSL2)

---

설치 후 첫 사건폴더에서:

```powershell
cd ~/사건/내사건폴더
# Windows PowerShell이면 claude.cmd
claude.cmd
```

```bash
# Mac/Linux/Git Bash
cd ~/사건/내사건폴더
claude
```

```
/jurisupport:cold-start-interview      # 최초 1회: 사무소 플레이북 학습
/jurisupport:brief-protocol            # 준비서면 작성 표준 절차
```

---

## 무엇이 들어 있나

| 구성요소 | 역할 | 의존성 |
|---|---|---|
| **JuriSupport 플러그인** | 사건 인테이크 → 준비서면 자동 작성 표준 절차 | korean-law MCP (공개) |
| **데이터 보호 Hook** | 외부 API 호출 시 의뢰인 정보 자동 감지·차단 | jq |
| **lbox-guide 스킬** | lbox.kr 판례 검색 워크플로우 | lbox.kr 유료 계정 |
| **beopgoeul-search 스킬 + toolkit** | 법고을(lx.scourt.go.kr) 판례 검색. 스킬은 기본 설치, 자동 검색 toolkit은 선택 설치 | Chrome + Python 3.9+ |
| **legal-books 스킬 + toolkit** | 사무소 보유 법률서적(교과서) 검색 | 사용자 보유 서적 스캔·OCR·임베딩 (책 1권당 5~30분, 점진 추가) |
| **case-records 스킬 + toolkit** | 사무소 과거 사건 검색 | 기본 FTS 인덱싱. Gemini 임베딩은 명시 동의 시만 사용 |
| **사건정보 관리표 템플릿** | JuriSupport 미사용 시 엑셀/CSV 사건관리 | 없음 |

---

## 지원 환경

| OS | 지원 | 비고 |
|---|---|---|
| macOS (Apple Silicon / Intel) | ✅ 완전 지원 | |
| Linux (Ubuntu 22.04+) | ✅ 완전 지원 | |
| Windows 10 22H2+ / 11 (네이티브 W1) | ✅ 완전 지원 | [WINDOWS_NATIVE.md](WINDOWS_NATIVE.md) — winget 기반, BIOS 가상화 불필요 |
| Windows + WSL2 (W2) | ✅ 완전 지원 | [WINDOWS_WSL.md](WINDOWS_WSL.md) — 리눅스 환경 그대로 사용 |

---

## 사전 준비물

1. **클로드 Pro 또는 Max 계정** (월 20달러 이상) — https://claude.ai/upgrade
2. **클로드코드 설치** — https://docs.claude.com/claude-code
3. **Homebrew** (macOS) 또는 apt (Linux)
4. **Python 3.9+** (3.10+ 권장)
5. **법제처 Open API 키** — korean-law MCP 설치 중 입력 ([발급 가이드](guides/07_law_openapi_key.md))
6. **Google Gemini API 키** — https://aistudio.google.com/apikey
   - legal-books·case-records 임베딩 생성용 (해당 toolkit 설치 시만)
   - 테스트·소량 인덱싱은 무료 tier로 가능하나, 교과서 여러 권을 쉽게 인덱싱하려면 결제 연결된 유료 tier 권장
7. **Google Chrome** — beopgoeul-search toolkit용 (Selenium)

---

## 설치 단계 (install.sh 10단계)

| 단계 | 내용 | 필수/선택 |
|---|---|---|
| 1 | 의존성 확인 (Python, jq, git, Claude Code) | 필수 |
| 2 | 데이터 보호 Hook 설치 | 필수 |
| 3 | JuriSupport 플러그인 등록 | 필수 |
| 4 | korean-law MCP 플러그인 설치 | 필수 |
| 5 | lbox-guide + beopgoeul-search 스킬 설치 | 필수 |
| 6 | 사건정보 관리표 템플릿 복사 (~/사건/) | 권장 |
| 7 | legal-books 검색 서버 설치 | 선택 (책 스캔 후) |
| 8 | case-records 검색 서버 설치 | 선택 (사건폴더 인덱싱) |
| 9 | beopgoeul-search 자동 검색 toolkit 설치 | 선택 (Chrome 필요, 스킬은 5단계에서 이미 설치) |
| 10 | JuriSupport MCP 등록 | 권장 |

부분 설치: [INSTALL_PARTIAL.md](INSTALL_PARTIAL.md) 참조.

---

## 사용 시작 (콜드스타트)

설치 후 다음 순서로 시작합니다. 자세한 단계: **[COLD_START.md](COLD_START.md)** 참조.

1. **[guides/00_security.md](guides/00_security.md) 정독** (5분)
2. **[guides/01_jurisupport_alt.md](guides/01_jurisupport_alt.md)** — JuriSupport 미사용 시 사건정보 관리법 (10분)
3. **첫 사건 시도** — `/jurisupport:cold-start-interview` 실행하여 사무소 플레이북 작성
4. **첫 준비서면 작성** — `/jurisupport:brief-protocol` 실행

### legal-books · case-records — 처음엔 빈 DB, 점진적으로 채우기

위 두 toolkit은 설치 직후 **검색 서버·DB만 빈 채로 세워**집니다. 본 패키지가 변호사의 보유 서적·과거 사건을 가져올 방법이 없으므로 사용자가 직접 채워야 합니다.

| 도구 | 1건 추가 시간 | 권장 점진 흐름 |
|---|---|---|
| legal-books | 책 1권 5~30분 (스캔·OCR) | 1주차 자주 보는 책 3권 → 6개월 핵심본 거의 전부 |
| case-records | 사건 1건 1~3분 (자동 인덱싱) | 1주차 최근 종결 5~10건 → 6개월 누적 사건 대부분 |

legal-books는 먼저 무료 로컬 OCR(OCRmyPDF+Tesseract)로 소량 테스트하세요. Adobe Acrobat, Google Cloud Vision/Document AI, NAVER CLOVA OCR 같은 유료 OCR은 책 여러 권을 한꺼번에 처리하면 페이지 수만큼 비용이 빠르게 누적될 수 있고, 인덱싱 단계의 Gemini 임베딩 비용·제한도 별도로 발생합니다.

자세한 가이드: [02_book_scanning.md](guides/02_book_scanning.md), [03_case_records.md](guides/03_case_records.md). install.sh가 toolkit 설치 직후 동일한 안내를 출력합니다.

---

## 문서 인덱스

### 가이드 (guides/)

| 파일 | 내용 |
|---|---|
| [00_security.md](guides/00_security.md) | 의뢰인 정보 보호 원칙 (필독) |
| [01_jurisupport_alt.md](guides/01_jurisupport_alt.md) | JuriSupport 미사용 — CSV 사건정보표 + Obsidian 권장 |
| [02_book_scanning.md](guides/02_book_scanning.md) | 법률서적 스캔·OCR·임베딩 (legal-books) |
| [03_case_records.md](guides/03_case_records.md) | 과거 사건폴더 정리·DB화 (case-records) |
| [04_lbox_workflow.md](guides/04_lbox_workflow.md) | lbox.kr 검색 워크플로우 |
| [05_beopgoeul_workflow.md](guides/05_beopgoeul_workflow.md) | 법고을 직접 검색 워크플로우 (수동) |
| [06_precedent_search.md](guides/06_precedent_search.md) | 판례 검색 통합 — 법고을 → lbox 폴백 |
| [07_law_openapi_key.md](guides/07_law_openapi_key.md) | 법제처 Open API 인증키(OC) 발급·입력 방법 |

### 메타

| 파일 | 내용 |
|---|---|
| [COLD_START.md](COLD_START.md) | 설치 → 첫 사건까지 한 페이지 가이드 |
| [INSTALL_PARTIAL.md](INSTALL_PARTIAL.md) | 부분 설치 (구성요소별) |
| [PUBLISH.md](PUBLISH.md) | (관리자용) GitHub 배포 절차 |
| [CONTRIBUTING.md](CONTRIBUTING.md) | 기여 가이드 |
| [SECURITY.md](SECURITY.md) | 보안 정책 |
| [SUPPORT_REPORTS.md](SUPPORT_REPORTS.md) | Windows 설치 실패 진단 ZIP·업로드 엔드포인트 계약 |
| [LICENSE](LICENSE) | MIT + 한국어 면책 |
| [AUDIENCE_PRE_INSTALL.md](AUDIENCE_PRE_INSTALL.md) | 강의 청중 사전 설치 가이드 (Mac/Linux) |
| [WINDOWS_NATIVE.md](WINDOWS_NATIVE.md) | 윈도우 네이티브 설치 가이드 (W1 권장) |
| [WINDOWS_WSL.md](WINDOWS_WSL.md) | 윈도우 WSL2 설치 가이드 (W2) |

---

## 언인스톨

본 패키지가 만든 등록·데이터를 단계별로 제거할 수 있습니다.

### Mac / Linux / Windows (Git Bash)

```bash
cd ~/jurisupport-plugins
./uninstall.sh           # 각 단계마다 Y/n 확인 (9단계)
./uninstall.sh --yes     # 전 항목 자동 제거 (사용자 데이터는 보존)
./uninstall.sh --dry-run # 미리보기만
```

**제거 대상** (9단계):
1. 데이터 보호 Hook 등록 해제 (settings.json jq 편집)
2. JuriSupport/korean-law 플러그인 + marketplace 등록 해제 (`claude plugin uninstall`)
3. 클로드코드 스킬 (lbox-guide, beopgoeul-search, legal-books, case-records)
4. ~/legal-books/ (서버 stop + 폴더)
5. ~/case-records/ (서버 stop + 폴더)
6. ~/jurisupport-beopgoeul/
7. ~/사건/_사건정보관리표.csv (사용자 데이터 가능성 — 확인 후)
8. ~/.jurisupport/secrets.env (Gemini API 키 — 확인 후)
9. JuriSupport MCP 등록 해제 (`claude mcp remove`)

**보존 대상 (기본)**: `~/사건/` 폴더, Claude Code 자체, 시스템 패키지(brew/apt/winget로 깐 것), jurisupport.com 계정·데이터.

### Mac — 시스템 패키지까지 모두 제거

```bash
# 1) 본 패키지 제거
cd ~/jurisupport-plugins && ./uninstall.sh --yes
rm -rf ~/jurisupport-plugins

# 2) Claude Code (npm 글로벌)
npm uninstall -g @anthropic-ai/claude-code

# 3) Homebrew 시스템 패키지 (다른 용도로 안 쓰면)
brew uninstall jq ocrmypdf tesseract tesseract-lang
brew uninstall --cask google-chrome
# Node·Python은 다른 앱도 쓸 가능성 → 보존 권장
```

### Linux — 시스템 패키지까지

```bash
cd ~/jurisupport-plugins && ./uninstall.sh --yes
rm -rf ~/jurisupport-plugins
npm uninstall -g @anthropic-ai/claude-code
sudo apt remove jq ocrmypdf tesseract-ocr tesseract-ocr-kor google-chrome-stable
```

### Windows — 시스템 패키지까지 모두 제거

```powershell
# PowerShell
irm https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/windows-uninstall.ps1 | iex
```

위 스크립트가 순서대로:
1. `uninstall.sh` 호출 (Git Bash) — 등록·데이터 제거
2. `npm uninstall -g @anthropic-ai/claude-code` — Claude Code 제거
3. `~/jurisupport-plugins/` 폴더 제거
4. winget 시스템 패키지(Git, Node, Python, Chrome, rclone 등) — **개별 Y/n 확인**, 기본 보존

---

## 라이선스 및 책임 면책

MIT License. 본 패키지의 코드·문서·템플릿은 자유롭게 사용·수정·배포할 수 있습니다.

다만 **다음은 본 패키지와 무관하며, 사용 변호사 본인의 절대적 책임**입니다.

- 클로드코드가 생성한 결과물의 정확성·법적 적합성 검증
- 의뢰인 정보 보호·비밀유지의무 (변호사윤리장전·개인정보보호법)
- 법원·의뢰인·상대방 제출·전달 전 최종 검토
- 데이터 보호 Hook은 보조 수단이며 완전한 유출 방지를 보장하지 아니함

---

## 쥬리서포트 (JuriSupport)

본 패키지는 **쥬리서포트 주식회사**가 한국 송무 변호사 커뮤니티에 기여하기 위해 공개 배포합니다.

- 홈페이지: [jurisupport.com](https://jurisupport.com)
- 이슈·문의: [GitHub Issues](https://github.com/jurisupport/jurisupport-plugins/issues)
- 보안 신고: admin@jurisupport.com (공개 issue 금지)
- 회사 소개: 한국 변호사·법무법인 전용 사건 관리 SaaS

### 본 패키지가 권장하는 통합

JuriSupport SaaS와 연동하면 사건·문서·기일·할일·증거를 통합 관리할 수 있습니다. **사건 50건까지 무료**라 부담 없이 시작 가능합니다.

**시작 흐름**:
1. [jurisupport.com](https://jurisupport.com) 가입 (사건 50건까지 무료)
2. [jurisupport.com/profile](https://jurisupport.com/profile) 에서 API 토큰 발급
3. install.sh가 자동으로 MCP 등록 (또는 수동: PowerShell은 `claude.cmd mcp add ...`, Git Bash/Mac/Linux는 `claude mcp add ...`)
4. [jurisupport.com/cases](https://jurisupport.com/cases) 에서 사건 등록 — **전자소송 사건목록 엑셀 업로드하면 자동 일괄 등록**
5. 클로드코드에서 `/jurisupport:brief-protocol` 실행 시 사건 자동 인식

보안 메모: 현재 Claude Code CLI는 HTTP/SSE MCP bearer header를 `--header` 인자로 등록합니다. install.sh는 검증 단계의 argv 노출은 줄이지만, MCP 등록 순간에는 같은 PC의 프로세스 목록에 토큰이 짧게 보일 수 있습니다. 공용 PC나 감염이 의심되는 환경에서는 토큰 등록을 미루고 안전한 장비에서 진행하세요.

SaaS 미사용 시에도 CSV 사건정보 관리표 + [Obsidian](https://obsidian.md)(MD 편집·뷰어) 조합으로 동등한 기능을 활용할 수 있습니다 ([01_jurisupport_alt.md](guides/01_jurisupport_alt.md) 참조).

---

## 기여

PR·이슈 환영합니다. 다만 **의뢰인 정보·API 키 누출 방지**가 최우선 원칙이며, 본 저장소는 한국 송무 실무에 특화되어 있습니다. 자세한 사항은 [CONTRIBUTING.md](CONTRIBUTING.md) 참조.
