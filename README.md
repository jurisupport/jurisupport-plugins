# jurisupport-plugins

> **Claude Code와 Codex를 위한 법률 업무 플러그인** — 사건자료 검토부터 서면 작성·인용 검증까지
>
> 쥬리서포트 주식회사 ([jurisupport.com](https://jurisupport.com))

![License](https://img.shields.io/badge/License-MIT-blue.svg)
![Platform](https://img.shields.io/badge/Platform-macOS%20%7C%20Linux%20%7C%20Windows-lightgrey)
![Locale](https://img.shields.io/badge/Locale-ko--KR-red)
![Claude Code](https://img.shields.io/badge/Claude%20Code-Supported-orange)
![Codex](https://img.shields.io/badge/Codex-Supported-blue)
![Version](https://img.shields.io/badge/Version-0.2.12-green)

---

## 한 줄 요약

사건자료를 바탕으로 **사실관계 정리 → 쟁점 추출 → 법령·판결 검증 → 서면 작성**을 지원합니다. Claude Code와 Codex 중 사용하는 환경에 설치하면 됩니다. 법률 근거 확인과 변호사의 최종 검토가 필요하며, 법원 전자제출은 사용자가 직접 수행합니다.

> 🏆 **제15회 변호사시험 선택형 3과목 평가에서 각각 3회 만점** — JuriSupport 법률 리서치 도구 사용 조건에서 [공법 40/40](https://github.com/jurisupport/korean-bar-exam-agent-eval)·[민사법 70/70](https://github.com/jurisupport/korean-bar-exam-agent-eval-civil)·[형사법 40/40](https://github.com/jurisupport/korean-bar-exam-agent-eval-criminal)을 각각 3회 모두 기록했습니다.

---

## 0.2.12: Claude·Codex 공통 지원

| 사용하는 환경 | 설치 대상 | 확인한 모델 |
|---|---|---|
| Claude Code | `--host claude` | Claude Opus 5 |
| Codex | `--host codex` | GPT-6 Astra · GPT-5.6 Sol |
| 두 환경 함께 | `--host both` | 각 세션에서 선택한 모델 상속 |

- **Codex 전용 설치에 Claude 계정·프로그램을 요구하지 않습니다.**
- 질문·파일 경로·MCP 도구를 실제 실행 환경에 맞추고, 승인된 작성·검증 작업은 불필요한 중간 승인 없이 이어갑니다.
- 프로필 웹 동의, 외부 전송 승인, 개인정보 보호와 법률 근거 검증은 유지합니다.
- 세 모델의 가상 사건 조회·도구 선택·동의 경계 검사를 통과했습니다. 전체 법률 업무나 모든 운영체제 설치를 보증하는 결과는 아닙니다. [검증 범위](plugins/jurisupport/COMPATIBILITY.md)

## 그간의 주요 업데이트

JuriSupport는 초기 프로토타입 이후, 설치 안정성·송무 작성 흐름·법률자료 검증·개인정보 보호를 중심으로 개선되어 왔습니다.

- **Claude/Codex 공통 실행 지원**: 호스트별 설치 경로, 세션 모델 상속, 공통 플레이북과 도구 스키마 확인을 지원합니다.
- **Claude Opus 5/high 지원**: JuriSupport 스킬이 현재 세션의 Opus 5/high 설정을 일관되게 상속하고, 사무소별 로컬 플레이북에서 문체·검증 기준·저장 경로를 불러옵니다.
- **한 줄 설치 안정화**: macOS/Linux/Windows 설치 흐름을 정리하고, Windows winget·긴 경로·PowerShell·의존성 설치 실패 케이스를 보강했습니다.
- **송무 워크플로우 통합**: 사건 인테이크부터 쟁점 정리, 법령·판례 검증, 준비서면 초안·정본·PDF 흐름까지 JuriSupport 플러그인 중심으로 통합했습니다.
- **모의변론 강화**: mock-hearing이 청구권규범, 요건사실, 입증책임, 항변·재항변, 판결 유추·구별 순서로 서면을 점검하도록 개선했습니다.
- **로컬 법률자료 확장**: 법제처 OC 키가 없어도 실습 가능한 오프라인 법령 폴백과 clean-legal-db 오프라인 검색을 추가했습니다.
- **과거 사건 활용 개선**: case-records 검색이 실제 준비서면·신청서면 등 재사용 가능한 서면 중심으로 작동하도록 정리했습니다.
- **법원 양식·판례 검색 보강**: court-forms, beopgoeul-search, lbox-guide 등 공개·로컬 자료 기반의 보조 검색 흐름을 추가했습니다.
- **개인 프로필 완성 기능**: 변호사가 자신의 사건자료와 작성 이력을 바탕으로 프로필을 정리하고, 명시적 동의 후 JuriSupport에 업로드할 수 있게 했습니다.
- **보안·동의 흐름 정리**: 의뢰인 정보 보호, 외부 업로드 전 웹 동의, 로컬 토큰 처리, 설치 진단 리포트 흐름을 보강했습니다.

---

## 그간의 주요 업데이트

JuriSupport는 초기 프로토타입 이후, 설치 안정성·송무 작성 흐름·법률자료 검증·개인정보 보호를 중심으로 개선되어 왔습니다.

- **Claude Opus 5/high 지원**: JuriSupport 스킬이 현재 세션의 Opus 5/high 설정을 일관되게 상속하고, 사무소별 로컬 플레이북에서 문체·검증 기준·저장 경로를 불러옵니다.
- **한 줄 설치 안정화**: macOS/Linux/Windows 설치 흐름을 정리하고, Windows winget·긴 경로·PowerShell·의존성 설치 실패 케이스를 보강했습니다.
- **송무 워크플로우 통합**: 사건 인테이크부터 쟁점 정리, 법령·판례 검증, 준비서면 초안·정본·PDF 흐름까지 JuriSupport 플러그인 중심으로 통합했습니다.
- **모의변론 강화**: mock-hearing이 청구권규범, 요건사실, 입증책임, 항변·재항변, 판결 유추·구별 순서로 서면을 점검하도록 개선했습니다.
- **로컬 법률자료 확장**: 법제처 OC 키가 없어도 실습 가능한 오프라인 법령 폴백과 clean-legal-db 오프라인 검색을 추가했습니다.
- **과거 사건 활용 개선**: case-records 검색이 실제 준비서면·신청서면 등 재사용 가능한 서면 중심으로 작동하도록 정리했습니다.
- **법원 양식·판례 검색 보강**: court-forms, beopgoeul-search, lbox-guide 등 공개·로컬 자료 기반의 보조 검색 흐름을 추가했습니다.
- **개인 프로필 완성 기능**: 변호사가 자신의 사건자료와 작성 이력을 바탕으로 프로필을 정리하고, 명시적 동의 후 JuriSupport에 업로드할 수 있게 했습니다.
- **보안·동의 흐름 정리**: 의뢰인 정보 보호, 외부 업로드 전 웹 동의, 로컬 토큰 처리, 설치 진단 리포트 흐름을 보강했습니다.

---

## ⚠️ 가장 먼저 읽어야 할 것

| 문서 | 소요 시간 | 내용 |
|---|---|---|
| **[클로드코드 시작 안내서 (웹)](https://jurisupport.github.io/jurisupport-plugins/)** | 30분 | 클로드코드를 처음 쓰는 분용 — 설치부터 가상사건 실습까지 클릭·복사만으로 |
| **[guides/00_security.md](guides/00_security.md)** | 5분 | 의뢰인 정보 보호 원칙 (필독) |
| **[COLD_START.md](COLD_START.md)** | 30분 | 설치 → 첫 사건까지 한 페이지 가이드 |

---

## 빠른 시작

**Claude Code 또는 Codex 중 사용하는 환경을 선택할 수 있습니다.** Codex만 사용하는 경우 Claude 설치·계정은 필요하지 않습니다. 플러그인은 현재 세션의 모델을 상속하며 Codex의 GPT-6 Astra·GPT-5.6 Sol을 특정 모델로 바꾸지 않습니다.

### Codex에서 플러그인만 설치

```bash
git clone https://github.com/jurisupport/jurisupport-plugins.git
cd jurisupport-plugins
codex plugin marketplace add .
codex plugin add jurisupport@jurisupport-plugins
```

새 Codex 작업에서 **“JuriSupport 콜드스타트로 설정해줘”**라고 요청하세요. 외부 계정·MCP·서적/사건 DB는 필요할 때 별도로 설정하며, 미설정 상태를 설치 실패로 처리하지 않습니다.

보조 스킬까지 설치하려면 저장소 루트에서 `bash install.sh --host codex`를 실행하세요. Claude Code는 `--host claude`, 두 환경은 `--host both`를 사용합니다. 상세 범위와 모델·보안 경계는 [플러그인 사용 안내](plugins/jurisupport/README.md), 실제 검사 결과는 [호환성 확인 기록](plugins/jurisupport/COMPATIBILITY.md)을 참조하세요.


### macOS / Linux — 한 줄 자동 설치

Codex만 설치하려면 앞에 `JURISUPPORT_HOST=codex`를 지정하세요. Claude만은 `claude`, 두 호스트는 `both`를 선택합니다. 지정하지 않으면 설치된 CLI를 감지합니다.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/bootstrap.sh)
```

위 한 줄은 필요한 Git·Node와 선택한 CLI를 준비하고 저장소를 내려받아 설치를 이어갑니다. Codex 경로는 핵심 플러그인·보조 스킬을 설치하며, Claude 경로에는 기존 Python·jq·rclone 준비와 선택 도구 설정이 포함됩니다.

보안이 엄격한 사무소 환경에서는 한 줄 설치 전에 스크립트를 내려받아 검토하거나, 릴리스 태그를 고정해 수동 설치하는 방식을 권장합니다.

설치 후 선택한 앱을 열어 로그인하세요. Codex는 새 작업에서 **“JuriSupport 콜드스타트로 설정해줘”**, Claude Code는 `/jurisupport:cold-start-interview`로 시작합니다. 새 GPT 모델을 구버전 CLI가 거절하면 Codex를 최신 버전으로 갱신하세요. 이번 모델 검사는 Codex CLI 0.154.0에서 수행했습니다.

### Windows — 한 줄 자동 설치 (PowerShell)

Codex 전용 설치는 먼저 `$env:JURISUPPORT_HOST = "codex"`를 설정한 뒤 아래 명령을 실행하세요. 로컬 스크립트 실행에서는 `-PluginHost codex`도 사용할 수 있습니다.

PowerShell 실행 방법:

1. Windows `시작` 메뉴에서 `PowerShell` 검색
2. **Windows PowerShell** 또는 **PowerShell**을 일반 실행 (관리자 권한 불필요)
3. 아래 한 줄을 붙여넣고 `Enter`

```powershell
irm https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/windows-bootstrap.ps1 | iex
```

이 한 줄이 **선택한 Claude Code/Codex + 본 레포 + install.sh까지** 자동으로 이어집니다. Codex 전용 설치는 기본 경로에 집중하며, Claude 경로에는 기존 보조 도구(Git/Node/Python/Chrome/Tesseract/qpdf/Ghostscript/rclone) 설치가 포함됩니다.

회사 보안 정책이나 ExecutionPolicy 때문에 `irm | iex`가 차단되면 같은 PowerShell 창에서 아래 두 줄을 대신 실행하세요.

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
iwr https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/windows-bootstrap.ps1 -UseBasicParsing | iex
```

PowerShell 한 줄 설치도 빠른 시작용입니다. 조직 보안 정책이 엄격하면 스크립트 내용을 먼저 검토한 뒤 실행하세요.

필요한 운영체제 설치 승인과 선택한 앱의 로그인을 완료하세요. Claude 전체 설치 흐름에서는 단계별 `[Y/n]`, 법제처 `OC`, 선택한 기능의 API 키를 추가로 묻습니다. Codex 핵심 설치는 외부 계정을 자동 연결하지 않습니다.

제3자 PC 설치를 지원해야 하면 진단 리포트 옵션을 켠 뒤 실행하세요. 실패 시 설치 로그·Windows 버전·공통 도구와 선택한 Claude Code/Codex 상태를 ZIP으로 묶고, 업로드 엔드포인트로 전송을 시도합니다.

```powershell
$env:JURISUPPORT_SUPPORT_REPORT = "1"
irm https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/windows-bootstrap.ps1 | iex
```

자세한 포함 정보와 엔드포인트 계약: [SUPPORT_REPORTS.md](SUPPORT_REPORTS.md)

WSL2를 선호하시면 [WINDOWS_WSL.md](WINDOWS_WSL.md) (W2 옵션) 참조 — 회사 보안프로그램이 매우 강한 경우만 권장.

### 사전 준비

- 사용할 **Claude Code 또는 Codex의 설치·로그인** — 해당 서비스에서 사용할 수 있는 계정 필요
- (Mac/Linux) 관리자 비밀번호 — Homebrew 설치 시 1회 입력
- (Windows) winget 사용 가능한 Windows 10 22H2+ 또는 Windows 11

### 수동 설치 (사전 준비물 직접 설치한 경우)

```bash
git clone -c core.autocrlf=false -c core.longpaths=true https://github.com/jurisupport/jurisupport-plugins.git
cd jurisupport-plugins
./install.sh              # Mac/Linux/Windows(Git Bash) 공통
```

Claude Code 사용 중 Windows에서 플러그인이 계속 예전 버전으로 보이면 PowerShell에서 갱신:

```powershell
cd $env:USERPROFILE\jurisupport-plugins
git config core.autocrlf false
git config core.longpaths true
git fetch origin main
git reset --hard origin/main
claude.cmd plugin marketplace update jurisupport-plugins
claude.cmd plugin uninstall --keep-data -y jurisupport
claude.cmd plugin install jurisupport@jurisupport-plugins
```

수동 사전 설치 가이드: [AUDIENCE_PRE_INSTALL.md](AUDIENCE_PRE_INSTALL.md) (Mac/Linux) / [WINDOWS_NATIVE.md](WINDOWS_NATIVE.md) (Windows 네이티브) / [WINDOWS_WSL.md](WINDOWS_WSL.md) (Windows WSL2)

---

Claude Code 설치 후 첫 사건폴더에서 (Codex는 앱의 새 작업에서 같은 스킬 이름으로 요청):

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

## 설치기 하나로 함께 설치되는 도구

Claude 설치 경로의 한 줄 설치는 이 패키지 외에 아래 JuriSupport 도구도 차례로 물어보고 설치합니다. 이미 설치된 것은 건너뛰고, 끝에 도구별 설치 상태를 한 화면에 보여 줍니다. 빠진 도구가 있으면 설치기를 다시 실행하면 됩니다.

| 도구 | 하는 일 | 기본값 | 건너뛰기 환경변수 |
|---|---|---|---|
| JuriSupport 사건 연결 (MCP) | 모든 사건 폴더의 Claude Code와 legal-terminal에서 사건·기일·문서 조회 | 권장 (토큰 입력) | — |
| [변호사 강점찾기 플러그인](https://github.com/jurisupport/jurisupport-lawyer-profile-plugin) | 내 사건자료로 개인 프로필 완성 | 설치 | `JURISUPPORT_SKIP_LAWYER_PROFILE=1` |
| [legal-terminal](https://github.com/jurisupport/legal-terminal) | 기록을 옆에 두고 서면을 쓰는 데스크톱 앱 (macOS·Windows) | 설치 | `JURISUPPORT_SKIP_LEGAL_TERMINAL=1` |
| [문서 다듬기](https://github.com/jurisupport/legal-polish-public) | 의미는 그대로, 문장·표현만 윤문 | 설치 | `JURISUPPORT_SKIP_LEGAL_POLISH=1` |
| 전자소송 도구 | Windows: [ecourt-cli](https://github.com/jurisupport/ecourt-cli) 새 기록 자동 받기 / macOS: [ecfs-skill](https://github.com/jurisupport/ecfs-skill) 송달 확인·제출 | 설치 안 함 (전자소송 아이디·인증서 암호 필요) | `JURISUPPORT_SKIP_ECOURT=1` |

## 무엇이 들어 있나

| 구성요소 | 역할 | 의존성 |
|---|---|---|
| **JuriSupport 플러그인** | 사건 인테이크 → 준비서면 자동 작성 표준 절차 | korean-law MCP (공개), OC 발급 전 오프라인 법령 폴백 |
| **Claude용 데이터 보호 Hook** | Claude 외부 도구 호출의 의뢰인 정보 감지 보조. Codex에 같은 Hook을 적용하지 않음 | jq |
| **lbox-guide 스킬** | lbox.kr 판례 검색 워크플로우 | lbox.kr 유료 계정 |
| **beopgoeul-search 스킬 + toolkit** | 법고을(lx.scourt.go.kr) 판례 검색. 스킬은 기본 설치, 자동 검색 toolkit은 선택 설치 | Chrome + Python 3.9+ |
| **court-forms toolkit** | 대한민국 법원 전자소송포털 공개 양식모음 로컬 DB·검색·공식 HWP/PDF 다운로드 | Python 3.9+ |
| **legal-books 플러그인** ([별도 저장소](https://github.com/jurisupport/legal-books)) | 사무소 보유 법률서적(교과서) 검색 | 사용자 보유 서적 스캔·OCR·임베딩 (책 1권당 5~30분, 점진 추가) |
| **case-records 스킬 + toolkit** | 사무소 과거 사건 검색 | 기본 FTS 인덱싱. Gemini 임베딩은 명시 동의 시만 사용 |
| **clean-legal-db 스킬 + toolkit** | 저작권 청정 법령·판례 DB(18,150여 건) **오프라인** 키워드 검색 | Python 3.8+ (DB 약 235MB 1회 다운로드, API 키·인터넷 불필요) |
| **사건정보 관리표 템플릿** | JuriSupport 미사용 시 엑셀/CSV 사건관리 | 없음 |

---

## 지원 환경

| OS | 지원 | 비고 |
|---|---|---|
| macOS (Apple Silicon / Intel) | 설치 경로 제공 | |
| Linux (Ubuntu 22.04+) | 설치 경로 제공 | |
| Windows 10 22H2+ / 11 (네이티브 W1) | 설치 경로 제공 | [WINDOWS_NATIVE.md](WINDOWS_NATIVE.md) — winget 기반, BIOS 가상화 불필요 |
| Windows + WSL2 (W2) | 설치 경로 제공 | [WINDOWS_WSL.md](WINDOWS_WSL.md) — 리눅스 환경 그대로 사용 |

---

## 사전 준비물

1. **사용할 호스트의 계정** — Claude Code 또는 Codex에서 로그인 가능해야 함
2. **선택한 호스트 설치** — Claude Code 또는 Codex CLI. 플러그인 설치만으로 다른 호스트를 요구하지 않음
3. **Homebrew** (macOS) 또는 apt (Linux)
4. **Python 3.9+** (3.10+ 권장)
5. **법제처 Open API 키** — korean-law MCP 정식 법령·판례 조회용. 발급 전에도 설치와 실습은 가능하며, 오프라인 법령 폴백을 사용합니다 ([발급 가이드](guides/07_law_openapi_key.md))
6. **Google Gemini API 키** — https://aistudio.google.com/apikey
   - legal-books·case-records 임베딩 생성용 (해당 toolkit 설치 시만)
   - 테스트·소량 인덱싱은 무료 tier로 가능하나, 교과서 여러 권을 쉽게 인덱싱하려면 결제 연결된 유료 tier 권장
7. **Google Chrome** — beopgoeul-search toolkit용 (Selenium)

---

## Claude 설치 단계 (install.sh 12단계)

Codex 전용 경로는 핵심 플러그인과 보조 스킬 등록을 수행하고 필요한 외부 도구를 선택 설정하도록 안내합니다. 아래는 기존 Claude 설치 경로의 단계입니다.

| 단계 | 내용 | 필수/선택 |
|---|---|---|
| 1 | 의존성 확인 (Python, jq, git, Claude Code) | 필수 |
| 2 | 데이터 보호 Hook 설치 | 필수 |
| 3 | JuriSupport 플러그인 등록 | 필수 |
| 4 | korean-law MCP 설치 또는 오프라인 법령 폴백 안내 | 권장 |
| 5 | lbox-guide + beopgoeul-search 스킬 설치 | 필수 |
| 6 | 사건정보 관리표 템플릿 복사 (~/사건/) | 권장 |
| 7 | 별도 legal-books 플러그인·검색 서버 설치 | 선택 (별도 저장소, 책 준비 후) |
| 8 | case-records 검색 서버 설치 | 선택 (사건폴더 인덱싱) |
| 9 | court-forms 법원 양식 DB toolkit 설치 | 선택 (공개 양식 메타DB, 파일은 필요 시 다운로드) |
| 10 | beopgoeul-search 자동 검색 toolkit 설치 | 선택 (Chrome 필요, 스킬은 5단계에서 이미 설치) |
| 11 | clean-legal-db 오프라인 법률 DB 설치 | 선택 (DB 약 235MB 다운로드) |
| 12 | JuriSupport MCP 등록 | 권장 (토큰 입력 필요) |

부분 설치: [INSTALL_PARTIAL.md](INSTALL_PARTIAL.md) 참조.

### 법원 양식 전체 자산화

전자소송포털 공개 양식모음 전체를 원본 파일 + Markdown 파생물로 레포에 넣으려면:

```bash
bash toolkit/court-forms/install.sh
~/court-forms/scripts/court_forms.py sync --download all --continue-on-error
~/court-forms/scripts/court_forms.py export-md \
  --output data/court-forms \
  --copy-files \
  --download-missing \
  --continue-on-error
```

생성물은 `data/court-forms/forms/<분야>/<form_id>_<제목>/` 아래에 들어갑니다. `index.md`는 검색·초안 작성용이고, `original/`의 공식 HWP/PDF/DOC 파일을 제출·편집 기준으로 둡니다.

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

자세한 가이드: [legal-books docs/book-scanning.md](https://github.com/jurisupport/legal-books/blob/main/docs/book-scanning.md), [03_case_records.md](guides/03_case_records.md). install.sh가 toolkit 설치 직후 동일한 안내를 출력합니다.

---

## 문서 인덱스

### 가이드 (guides/)

| 파일 | 내용 |
|---|---|
| [00_security.md](guides/00_security.md) | 의뢰인 정보 보호 원칙 (필독) |
| [01_jurisupport_alt.md](guides/01_jurisupport_alt.md) | JuriSupport 미사용 — CSV 사건정보표 + Obsidian 권장 |
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
./uninstall.sh           # 각 단계마다 Y/n 확인 (10단계)
./uninstall.sh --host codex --dry-run # Codex 제거 범위 미리보기
./uninstall.sh --dry-run # 미리보기만
```

Codex만 제거하려면 `bash uninstall.sh --host codex`를 사용합니다. 핵심 플러그인과 이 저장소에서 설치한 보조 스킬을 제거하며, DB·MCP 인증 설정은 보존합니다. 먼저 `--dry-run`으로 확인할 수 있습니다.

아래는 **Claude 전체 제거 경로**입니다. `--yes`는 데이터 폴더 제거 질문도 승인하므로 백업 여부를 확인한 경우에만 사용하세요.

**제거 대상** (10단계):
1. 데이터 보호 Hook 등록 해제 (settings.json jq 편집)
2. JuriSupport/korean-law 플러그인 + marketplace 등록 해제 (`claude plugin uninstall`)
3. 클로드코드 스킬 (lbox-guide, beopgoeul-search, court-forms, legal-books, case-records)
4. ~/legal-books/ (서버 stop + 폴더)
5. ~/case-records/ (서버 stop + 폴더)
6. ~/court-forms/ (법원 양식 메타DB·다운로드 캐시)
7. ~/jurisupport-beopgoeul/
8. ~/사건/_사건정보관리표.csv (사용자 데이터 가능성 — 확인 후)
9. ~/.jurisupport/secrets.env (Gemini API 키 — 확인 후)
10. JuriSupport MCP 등록 해제 (`claude mcp remove`)

**보존 대상 (기본)**: `~/사건/` 폴더, Claude Code·Codex 자체, 시스템 패키지(brew/apt/winget로 깐 것), jurisupport.com 계정·데이터.

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

- 선택한 AI가 생성한 결과물의 정확성·법적 적합성 검증
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
3. 토큰을 한 번만 등록합니다. Claude 전체 설치는 입력을 안내하고, 나중에 등록하거나 30일 뒤 갱신할 때는 아래 한 줄을 씁니다. Claude Code(모든 폴더)와 Codex에 함께 등록되고, [legal-terminal](https://github.com/jurisupport/legal-terminal) 사건 대시보드도 이 등록을 그대로 씁니다.

   ```bash
   # macOS / Linux
   curl -fsSL https://raw.githubusercontent.com/jurisupport/jurisupport-lawyer-profile-plugin/main/connect-mcp.sh | bash
   ```

   ```powershell
   # Windows PowerShell
   irm https://raw.githubusercontent.com/jurisupport/jurisupport-lawyer-profile-plugin/main/connect-mcp.ps1 | iex
   ```
4. [jurisupport.com/cases](https://jurisupport.com/cases) 에서 사건 등록 — **전자소송 사건목록 엑셀 업로드하면 자동 일괄 등록**
5. Claude의 `/jurisupport:brief-protocol` 또는 Codex의 “JuriSupport 준비서면 작성” 요청으로 시작

보안 메모: 현재 Claude Code CLI는 HTTP/SSE MCP bearer header를 `--header` 인자로 등록합니다. install.sh는 검증 단계의 argv 노출은 줄이지만, MCP 등록 순간에는 같은 PC의 프로세스 목록에 토큰이 짧게 보일 수 있습니다. 공용 PC나 감염이 의심되는 환경에서는 토큰 등록을 미루고 안전한 장비에서 진행하세요.

SaaS 미사용 시에도 CSV 사건정보 관리표 + [Obsidian](https://obsidian.md)(MD 편집·뷰어) 조합으로 동등한 기능을 활용할 수 있습니다 ([01_jurisupport_alt.md](guides/01_jurisupport_alt.md) 참조).

---

## 기여

PR·이슈 환영합니다. 다만 **의뢰인 정보·API 키 누출 방지**가 최우선 원칙이며, 본 저장소는 한국 송무 실무에 특화되어 있습니다. 자세한 사항은 [CONTRIBUTING.md](CONTRIBUTING.md) 참조.
