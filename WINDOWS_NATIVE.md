# 윈도우 사용자 가이드 — 네이티브 설치 (W1)

> 본 가이드는 **WSL2를 사용하지 않고** 윈도우에 직접 설치하는 방법입니다.
> WSL2를 선호하시면 [WINDOWS_WSL.md](WINDOWS_WSL.md)를 참조하세요.

---

## W1 (네이티브) vs W2 (WSL2) — 어느 쪽?

| 항목 | W1: 네이티브 | W2: WSL2 |
|---|---|---|
| 설치 시간 | 약 10~15분 | 약 30~60분 |
| BIOS 가상화 활성화 | 불필요 | 필요 (회사 노트북 차단 위험) |
| 재부팅 | 불필요 | 필요 (1회) |
| 의존성 설치 도구 | winget | apt + 별도 |
| 사건폴더 위치 | `C:\Users\<계정>\사건\` | `/home/<계정>/사건/` 또는 `/mnt/c/...` |
| 윈도우 OneDrive 폴더 직접 접근 | ✅ 그대로 | ⚠️ `/mnt/c/...`로 우회 |
| 한글 처리 | ✅ 윈도우 네이티브 | ✅ locale 설정 후 OK |
| 검색 서버 백그라운드 실행 | PowerShell 백그라운드 잡 | Linux 데몬 (nohup) |
| Claude Code Hook | Git Bash 호출 | bash 직접 |
| **추천 대상** | 일반 변호사, 첫 도입 | 리눅스 익숙한 개발자, 보안프로그램 우회 필요 |

**대부분의 변호사는 W1(네이티브)을 권합니다.** 회사 노트북에서 BIOS 가상화가 막혀 있어도 동작하고, 재부팅이 필요 없으며, 윈도우 OneDrive·바탕화면을 그대로 쓸 수 있습니다.

---

## 사전 조건

| 항목 | 요구 | 확인 방법 |
|---|---|---|
| Windows 버전 | 10 22H2+ 또는 11 | `Win+R` → `winver` |
| winget | 기본 탑재 (없으면 Microsoft Store에서 "App Installer") | PowerShell에서 `winget --version` |
| 관리자 권한 | UAC 팝업 승인 가능 | — |
| 클로드 Pro/Max | 가입 완료 | https://claude.ai/upgrade |

---

## Step 1. PowerShell 한 줄 — 모든 것 자동

`시작` → `PowerShell` 검색 → **일반 실행** (관리자 권한 불필요) → 다음 한 줄:

```powershell
irm https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/windows-bootstrap.ps1 | iex
```

`irm | iex`가 ExecutionPolicy로 차단되면 두 줄로:

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
iwr https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/windows-bootstrap.ps1 -UseBasicParsing | iex
```

### 제3자 설치 지원 — 실패 로그 자동 리포트

다른 사용자 PC에서 설치를 도와야 하면 진단 리포트 옵션을 켜고 실행하세요.

```powershell
$env:JURISUPPORT_SUPPORT_REPORT = "1"
irm https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/windows-bootstrap.ps1 | iex
```

실패 시 Desktop에 `jurisupport-install-report-YYYYMMDD-HHMMSS.zip`이 생성되고, 기본 업로드 엔드포인트(`https://api.jurisupport.com/support/install-report`)로 전송을 시도합니다. 업로드가 실패하면 ZIP 위치와 메일 작성 창을 열어 수동 전달할 수 있게 합니다.

포함되는 정보: Windows 버전, PowerShell 실행 정책, winget/Git/Node/npm/Python/jq/rclone/Claude Code 상태, PATH, 관련 패키지 목록, bootstrap 로그. 사건자료, `~/.claude/settings.json`, `secrets.env`는 포함하지 않습니다. 자세한 엔드포인트 계약: [SUPPORT_REPORTS.md](SUPPORT_REPORTS.md).

이 한 줄이 자동으로 5단계 전부 진행:

| Step | 내용 | 사용자 응답 |
|---|---|---|
| 1 | winget 점검·source 동의 | 없음 |
| 2 | 공통 패키지 9개 winget 설치 (Git/Node/Python/Chrome/jq/Tesseract/qpdf/rclone 등) | **UAC 팝업 "예"** (작업 표시줄 노란 방패) |
| 2-B | Ghostscript GitHub release 자동 다운로드·무인 설치 | UAC 팝업 "예" |
| 3 | Claude Code npm 글로벌 설치 | 없음 |
| 4 | 본 레포 git clone (`C:\Users\<계정>\jurisupport-plugins`) | 없음 |
| 5 | install.sh 자동 실행 (Git Bash 호출) — 10단계 | **각 단계 [Y/n]**, 법제처 Open API 키, (선택) Gemini API 키 |

**소요 시간**: 약 15분 (네트워크 속도 따라).

법제처 Open API 키는 무료 발급입니다. 설치 전에 [법제처 Open API 인증키 발급 가이드](guides/07_law_openapi_key.md)를 보고 `현재 API인증키(OC)` 값을 준비해 두면 설치가 덜 막힙니다.

### install.sh 10단계 내용

| 단계 | 내용 | 필수/선택 |
|---|---|---|
| 1 | 의존성 점검 | 필수 |
| 2 | 데이터 보호 Hook 설치 (Git Bash 절대경로 등록) | 필수 |
| 3 | JuriSupport 플러그인 등록 (Windows는 복사) | 필수 |
| 4 | korean-law MCP 플러그인 설치 | 필수 |
| 5 | lbox-guide + beopgoeul-search 스킬 설치 | 필수 |
| 6 | 사건정보 관리표 CSV (`~/사건/_사건정보관리표.csv`) | 권장 [Y/n] |
| 7 | legal-books 검색 서버 (Python+SQLite+FastAPI) | 선택 [Y/n] |
| 8 | case-records 검색 서버 (Python+SQLite+FastAPI) | 선택 [Y/n] |
| 9 | beopgoeul-search toolkit (Selenium 법고을 자동 검색 실행환경) | 선택 [Y/n] |
| 10 | JuriSupport MCP 등록 | 권장 [Y/n] |

### 첫 실행 시 Windows 방화벽 팝업

검색 서버(6번, 7번)를 설치하면 처음 시작될 때 Windows Defender 방화벽이 "Python.exe가 네트워크에 접근하려고 합니다"라는 팝업을 띄웁니다.

- **"개인 네트워크" 허용**, "공용 네트워크" 차단 권장.
- 서버는 `localhost`(127.0.0.1)에서만 동작하므로 외부 노출은 없습니다.

---

## Step 2. Claude Code 로그인 (1회)

bootstrap이 끝나면 PowerShell 또는 Git Bash에서:

```powershell
# PowerShell
claude.cmd

# Git Bash
claude
```

브라우저가 자동으로 열리며 클로드 Pro/Max 계정으로 OAuth 로그인. 한 번만 하면 영구 유지.

---

## Step 3. 첫 사건 시작

```powershell
mkdir $env:USERPROFILE\사건\2026-001_홍길동_대여금
cd $env:USERPROFILE\사건\2026-001_홍길동_대여금
# (사건 자료를 이 폴더에 넣고)
claude.cmd
```

클로드코드 안에서:

```
이 폴더의 사건기록을 시간순으로 정리하고 핵심 쟁점을 알려줘.
```

---

## Windows 특이사항

### 1. Git Bash 사용 권장

본 패키지의 install.sh, add_book.sh, server.sh 등 모든 진입 스크립트는 **Git Bash에서 실행**합니다. PowerShell에서는 `.sh`가 동작하지 않습니다.

| 작업 | 실행 환경 |
|---|---|
| 본 패키지 설치 (`./install.sh`) | Git Bash |
| 클로드코드 실행 | PowerShell: `claude.cmd` / Git Bash: `claude` |
| 책 추가 (`add_book.sh`) | Git Bash |
| 서버 관리 (수동) | PowerShell (`server.ps1`) |

### 2. 심볼릭 링크 대신 복사

윈도우에서 일반 사용자 권한으로는 심볼릭 링크를 만들 수 없습니다. 본 패키지는 JuriSupport 플러그인을 심볼릭 링크 대신 **복사**로 등록합니다.

→ **부작용**: GitHub에서 최신 패키지를 받은 후 `git pull` → 다시 `./install.sh`를 실행해야 등록된 플러그인이 갱신됩니다.

### 3. 검색 서버 백그라운드 관리

```powershell
# legal-books
& "$env:USERPROFILE\legal-books\scripts\server.ps1" start
& "$env:USERPROFILE\legal-books\scripts\server.ps1" status
& "$env:USERPROFILE\legal-books\scripts\server.ps1" stop

# case-records
& "$env:USERPROFILE\case-records\scripts\server.ps1" start
```

윈도우 재부팅 후에는 서버가 자동으로 시작되지 않습니다. 필요 시 작업 스케줄러로 자동 시작 등록 가능 (사후 작업).

### 4. 한글 인코딩

- Git Bash·PowerShell 7+ 모두 UTF-8 기본 지원
- 윈도우 명령 프롬프트(`cmd.exe`)에서 클로드코드 실행은 권장하지 않음 (cp949 인코딩 충돌)

### 5. OneDrive·사건폴더

- `C:\Users\<계정>\OneDrive\사건\` 형태로 OneDrive 안에 두면 자동 백업
- 단, OneDrive "사용 시에만 다운로드" 옵션이 켜져 있으면 클로드가 파일을 못 읽을 수 있음 → 사건폴더는 "항상 이 디바이스에 보관" 으로 설정

---

## 문제 해결

### 부트스트랩 단계 (windows-bootstrap.ps1)

| 증상 | 원인 | 해결 |
|---|---|---|
| **1/8 단계에서 멈춤** (Git for Windows) | UAC 팝업이 다른 모니터·작업 표시줄 뒤에 가려짐 | 작업 표시줄에서 노란 방패 아이콘 클릭 → "예". 또는 `Alt+Tab`으로 창 전환 |
| Node.js 등 `winget install` 중 화면 변화 없이 멈춘 듯함 | UAC 승인 창이 뜬 게 아니라 작업 표시줄 방패 아이콘으로만 대기 중 | 하단 작업 표시줄의 방패 아이콘을 클릭해 UAC 창을 열고 "예" 선택. 새 스크립트는 20초 이상 대기 시 이 안내를 반복 표시 |
| 1/8에서 멈춤, UAC 없음 | winget 첫 호출 시 source agreement 동의 대기 | 새 버전(d59fcb4+)에서 사전 동의 자동 처리. `irm "...?t=$(Get-Random)" \| iex`로 캐시 우회 |
| `입력 조건과 일치하는 패키지를 찾을 수 없습니다` (exit -1978335212) | winget 카탈로그 ID가 변경되었거나 오기 | 새 버전에서 fallback ID 자동 시도. 직접 확인은 `winget search <키워드>` |
| Ghostscript / qpdf / rclone 설치 실패 | winget 카탈로그에 ID 없을 수 있음 (라이선스 별 갈래) | **선택 패키지라 진행 OK**. OCRmyPDF 책 스캔 또는 클라우드 동기화 사용 시만 영향. 수동 설치: [Ghostscript](https://ghostscript.com/releases/gsdnld.html), [qpdf](https://github.com/qpdf/qpdf/releases), `winget install Rclone.Rclone` |
| `npm notice ...`가 빨갛게 RemoteException으로 표시 | npm 정보 메시지가 stderr로 출력 → PowerShell이 에러로 오인 | **정상 동작**. 새 버전에서 화면 표시 정상화. PowerShell에서 `claude.cmd --version`이 잘 나오면 설치 성공 |
| `npm.ps1 파일을 로드할 수 없습니다` / ExecutionPolicy 오류 | PowerShell이 `npm.cmd` 대신 `npm.ps1`을 먼저 실행함 | 최신 스크립트는 `npm.cmd`를 우선 사용. 캐시 우회 명령으로 재실행: `irm "...?t=$(Get-Random)" \| iex` |
| `claude.ps1 파일을 로드할 수 없습니다` / ExecutionPolicy 오류 | PowerShell이 npm의 `claude.ps1` shim을 먼저 실행함 | PowerShell에서는 `claude.cmd`를 실행하세요. Git Bash에서는 `claude` 그대로 사용 가능합니다. |
| `irm \| iex`가 ExecutionPolicy로 막힘 | 회사 보안 정책 | `Set-ExecutionPolicy Bypass -Scope Process -Force` 먼저 |
| winget 명령 없음 | Windows 10 구버전, App Installer 미설치, 또는 WindowsApps 앱 실행 별칭이 현재 PowerShell PATH에서 빠짐 | 최신 스크립트는 WindowsApps/앱 설치 위치를 자동 탐색. 계속 실패하면 Microsoft Store에서 "App Installer" 업데이트 또는 https://apps.microsoft.com/detail/9NBLGGH4NNS1 |
| winget이 설치돼 있는데 "설치되어 있지 않습니다" 표시 | 앱 실행 별칭이 꺼져 있거나 현재 PowerShell 창의 PATH가 오래됨 | Windows 설정 → 앱 → 고급 앱 설정 → 앱 실행 별칭에서 `Windows Package Manager Client`/`winget`을 켠 뒤 새 PowerShell 창에서 재실행 |
| `npm install -g` 권한 오류 | npm 글로벌 prefix가 보호된 경로 | PowerShell **관리자 권한**으로 재시도 또는 `npm config set prefix "$env:LOCALAPPDATA\npm"` 후 재시도 |
| `claude.cmd --version` "명령을 찾을 수 없음" | PATH가 갱신되지 않음 | 새 PowerShell 창을 열어주세요 |

### 진단 리포트 단계

| 증상 | 해결 |
|---|---|
| 업로드 실패 | Desktop의 `jurisupport-install-report-*.zip`을 이메일 또는 메신저로 전달 |
| 메일 창이 열리지 않음 | ZIP 파일 경로가 화면에 출력됨. 해당 파일을 직접 첨부 |
| 사내 보안망에서 업로드 차단 | `$env:JURISUPPORT_SUPPORT_UPLOAD_URL = "off"`로 업로드를 끄고 ZIP만 생성 |
| 지원 받을 이메일 변경 | `$env:JURISUPPORT_SUPPORT_EMAIL = "support@example.com"` 설정 후 실행 |

### install.sh 단계 (Git Bash)

| 증상 | 원인 | 해결 |
|---|---|---|
| **PowerShell에서 `./install.sh` 입력 시 "이 sh 파일을 열 앱 선택" 대화상자** | PowerShell은 `.sh`를 실행 파일로 인식 못함 | (A) **Git Bash 실행** (시작 메뉴 → Git Bash 검색) 후 `cd ~/jurisupport-plugins && ./install.sh`<br>(B) PowerShell에서 `bash install.sh` 직접 호출<br>(C) 탐색기에서 폴더 우클릭 → "Open Git Bash Here" |
| `$'\r': command not found` 또는 `set: invalid option name` | Windows core.autocrlf=true가 .sh를 CRLF로 변환 | 새 버전(228c569+)은 `.gitattributes`로 자동 방지. 이전에 받은 경우 다음 실행: `cd ~/jurisupport-plugins && git config core.autocrlf false && git rm --cached -r . && git reset --hard` |
| `./install.sh: bad interpreter` | Git Bash가 아닌 다른 셸 | Git Bash로 다시 실행 |
| Git Bash에서 한글 깨짐 | 콘솔 인코딩 | Git Bash 옵션 → Text → Locale "ko_KR", Character set "UTF-8" |
| `step` 함수 색 코드가 raw text로 보임 | 콘솔 ANSI 미지원 | Windows Terminal 설치 권장 |
| `[error] ocrmypdf 필요` (legal-books 6단계) | OCRmyPDF는 책 스캔 시점에만 필요 | 새 버전(4470c54+)에서 warn으로 강등. 검색 서버는 가동됨. 책 추가 시 `add_book.sh`가 다시 안내 |
| `winget install` 후 Git Bash가 명령을 못 찾음 (`tesseract: command not found` 등) | Git Bash가 PATH를 캐시 | **Git Bash 창을 닫고 새로 열기** (PowerShell PATH 변경은 새 셸 필요) |

### 사용 단계

| 증상 | 해결 |
|---|---|
| ChromeDriver 버전 충돌 | Selenium Manager가 자동 처리. 안 되면 Chrome 업데이트 또는 `pip install -U selenium` |
| Tesseract에 한국어 없음 | UB-Mannheim 빌드 재설치 — 설치 마법사에서 "Korean" 체크 |
| OCRmyPDF "Could not find gs/qpdf" | Ghostscript·qpdf 수동 설치 (위 부트스트랩 표 참조) |

### 진단 체크리스트 (멈춤·실패 시)

부트스트랩이 정상적이지 않으면 다음 순서로 확인하세요.

```powershell
# 1. winget 버전 (v1.6 이상 권장)
winget --version

# 2. winget source 정상?
winget source list
winget source update

# 3. 개별 패키지 ID 존재 확인
winget search Git.Git
winget search ArtifexSoftware.GhostScript
winget search qpdf

# 4. 수동 설치 시 진행률 확인 (--silent 빼고)
winget install --id Git.Git --accept-package-agreements --accept-source-agreements

# 5. PATH 갱신 확인 (새 PowerShell 창)
git --version; node --version; python --version
```

---

## 언인스톨

### 데이터·등록만 제거 (시스템 패키지 보존)

Git Bash에서:

```bash
cd ~/jurisupport-plugins
./uninstall.sh           # 단계별 Y/n
./uninstall.sh --yes     # 자동
./uninstall.sh --dry-run # 미리보기
```

제거: Hook, 플러그인 등록, 스킬, `~/legal-books`, `~/case-records`, `~/jurisupport-beopgoeul`, 검색 서버 stop.
보존: `~/사건/`, Gemini API 키 (확인 후 선택 제거).

### Claude Code · 본 레포 · winget 시스템 패키지까지 모두 제거

PowerShell에서:

```powershell
irm https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/windows-uninstall.ps1 | iex
```

또는 로컬:

```powershell
& "$env:USERPROFILE\jurisupport-plugins\windows-uninstall.ps1"
```

4단계 순차 (각 단계 Y/n):
1. `uninstall.sh` 호출 (Git Bash)
2. `npm uninstall -g @anthropic-ai/claude-code`
3. `~/jurisupport-plugins/` 폴더 삭제
4. winget 패키지 9개 (Git/Node/Python/Chrome/rclone 등) — 다른 앱이 쓸 수 있으니 각각 명시 Y 필요

---

## 막혔을 때

- 이메일: admin@jurisupport.com
- 윈도우 버전 + 에러 메시지 캡처 첨부

---

## 완성도 — Mac과의 차이

윈도우 네이티브 설치 시 Mac과 다른 점은 다음뿐입니다.

| 항목 | Mac | Windows 네이티브 |
|---|---|---|
| 플러그인 등록 방식 | 심볼릭 링크 | 복사 (업데이트 시 install.sh 재실행) |
| 서버 백그라운드 | nohup | PowerShell Start-Process Hidden |
| Hook 호출 | `.sh` 직접 | Git Bash 절대경로로 호출 |
| 사용자 체감 | — | 동일 |

기능적으로는 **완전히 동등**합니다.
