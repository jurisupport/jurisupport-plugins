# 윈도우 사용자 가이드 — WSL2 (Windows Subsystem for Linux)

> 본 패키지는 macOS/Linux 전용입니다. 윈도우 사용자는 **WSL2의 Ubuntu** 환경에서 사용합니다.
> 윈도우 환경 자체에서 직접 설치는 지원하지 않습니다 (Mac/Linux로 통일하여 강의 효율 확보).

---

## 결론: WSL만 설치하면 끝나나?

**아니요.** WSL2는 단순히 "Linux 환경을 윈도우에서 쓸 수 있게 해 주는" 껍데기일 뿐, 그 안에서 다시 사전 설치 6가지를 진행해야 합니다.

흐름:

```
1. WSL2 설치 (Windows 단)            ← 본 가이드 Step 1~2
2. Ubuntu 배포판 설치 + 사용자 설정    ← Step 3
3. Ubuntu 안에서 의존성 설치           ← Step 4 (AUDIENCE_PRE_INSTALL.md의 Linux 버전)
4. 본 패키지 설치 (./install.sh)       ← 강의 당일
```

WSL2 설치 자체는 5~15분, 안의 의존성 설치까지 합치면 30~60분 정도 걸립니다.

---

## Step 1. WSL2 설치 가능 여부 확인

### 윈도우 버전 확인

`Win + R` → `winver` 입력 → Enter.

| OS | WSL2 지원 |
|---|---|
| Windows 11 (모든 버전) | ✅ |
| Windows 10 21H2 이상 | ✅ |
| Windows 10 21H1 이하 | ⚠️ Windows Update 먼저 |
| Windows 7/8 | ❌ 지원 안 됨 |

### 가상화 활성화 확인

`Ctrl + Shift + Esc` → 작업 관리자 → **성능 탭** → **CPU** → "가상화"가 "사용" 상태여야 함.

"사용 안 함"이면 BIOS에서 활성화 필요:

1. 재부팅 → 부팅 직후 `Del` 또는 `F2` 또는 `F10` (제조사별 다름)
2. BIOS 설정에서 `Virtualization Technology (VT-x)` 또는 `SVM Mode (AMD)` → Enabled
3. 저장 + 재부팅

---

## Step 2. WSL2 설치 (PowerShell 한 줄)

### 윈도우 11 또는 윈도우 10 22H2+

`시작` → `PowerShell` 검색 → **관리자 권한으로 실행** → 다음 한 줄:

```powershell
wsl --install
```

자동으로 다음이 진행됩니다.

1. WSL 기능 활성화
2. 가상 머신 플랫폼 활성화
3. WSL2 커널 다운로드
4. Ubuntu 22.04 자동 설치
5. **재부팅 안내** → 재부팅 후 자동으로 Ubuntu 설치 계속

### 재부팅 후 Ubuntu 첫 실행

1. 자동으로 Ubuntu 창이 열림 (안 열리면 시작 메뉴 → "Ubuntu" 검색)
2. **사용자명·비밀번호 설정** 요청 → 입력 (영문 권장)
   - 이 비밀번호는 `sudo` 사용 시 필요. 잊지 말 것.
3. 프롬프트가 `username@hostname:~$` 형태로 보이면 설치 성공.

### 윈도우 10 21H2 ~ 22H1 (구버전)

`wsl --install`이 안 되면:

```powershell
# 관리자 PowerShell
dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart
```

재부팅 후 https://aka.ms/wsl2kernel 에서 WSL2 커널 다운로드 설치.

```powershell
wsl --set-default-version 2
wsl --install -d Ubuntu-22.04
```

---

## Step 3. Ubuntu 첫 설정 (WSL Ubuntu 터미널에서)

### 패키지 목록 업데이트

```bash
sudo apt update && sudo apt upgrade -y
```

### 시스템 한국어 처리 확인 (선택)

```bash
locale
```

`LANG=en_US.UTF-8`이거나 `LANG=ko_KR.UTF-8`이면 OK. 빈 값이면:

```bash
sudo apt install -y language-pack-ko
sudo locale-gen ko_KR.UTF-8
```

---

## Step 4. 의존성 6가지 설치 (Ubuntu)

### 4-1. 기본 도구

```bash
sudo apt install -y jq git python3 python3-pip python3-venv build-essential curl wget
```

### 4-2. Node.js LTS (NodeSource 저장소)

```bash
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt install -y nodejs
node --version    # v22.x 또는 v20.x 확인
```

### 4-3. Claude Code

```bash
sudo npm install -g @anthropic-ai/claude-code
claude --version
```

> `sudo` 없이 `npm install -g`하면 EACCES 권한 오류 가능. WSL Ubuntu는 일반적으로 `sudo`로 글로벌 설치.

### 4-4. Google Chrome (Selenium용 — 법고을 자동 검색)

```bash
# Google 서명키 + 저장소 추가
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/google.gpg
echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" | sudo tee /etc/apt/sources.list.d/google.list

sudo apt update
sudo apt install -y google-chrome-stable

# 확인
google-chrome --version
```

> **WSL에서 Chrome은 headless로만 사용**됩니다 (GUI 없이 백그라운드 작동). Selenium 기본 동작이라 별도 설정 불요.

### 4-5. (선택) OCRmyPDF + Tesseract 한글 (legal-books toolkit용)

책 스캔 OCR을 WSL에서 하실 경우만:

```bash
sudo apt install -y ocrmypdf tesseract-ocr tesseract-ocr-kor
```

### 4-6. (선택) Google Gemini API 키 발급

https://aistudio.google.com/apikey 에서 키 발급. 강의에서 등록.

---

## Step 5. 검증 (강의 전날 셀프 점검)

WSL Ubuntu 터미널에서 다음을 모두 실행:

```bash
jq --version
git --version
python3 --version    # 3.9 이상
node --version       # 20 이상
npm --version
claude --version
google-chrome --version
```

전부 버전이 표시되면 준비 완료.

---

## Step 6. 강의 당일 라이브 단계

다른 Mac/Linux 청중과 동일:

```bash
# Ubuntu 터미널에서
claude            # Pro OAuth 로그인 1회
# (브라우저가 자동으로 열림 — 윈도우 기본 브라우저)

git clone https://github.com/jurisupport/jurisupport-plugins.git
cd jurisupport-plugins
./install.sh
```

---

## WSL 사용 팁

### 윈도우 ↔ WSL 파일 교환

| 방향 | 방법 |
|---|---|
| 윈도우 → WSL | WSL 안에서 `/mnt/c/Users/<윈도우계정>/Downloads/` 로 접근 |
| WSL → 윈도우 | 파일 탐색기 주소창에 `\\wsl$\Ubuntu\home\<리눅스계정>\` |

사건폴더는 WSL Ubuntu 안 (`~/사건/`)에 두는 게 가장 안정적. 또는 Windows OneDrive 폴더 (`/mnt/c/Users/<계정>/OneDrive/사건/`)에 두어도 가능.

### 터미널 추천

기본 WSL 터미널보다 **Windows Terminal** (Microsoft Store 무료)이 한글·색상·탭 모두 훨씬 좋습니다. 강의 전에 미리 설치 권장.

---

## 문제 해결

| 증상 | 해결 |
|---|---|
| `wsl --install` 실패 | Windows Update 먼저, 가상화 BIOS 활성화 |
| Ubuntu 첫 실행 시 `Installing, this may take a few minutes…` 멈춤 | 10~20분 기다림. 안 되면 `wsl --unregister Ubuntu` 후 재설치 |
| `sudo` 비밀번호 모름 | WSL 초기 설정 시 만든 비밀번호. 잊었으면 `wsl --user root` 후 `passwd <user>` |
| `npm install -g` 권한 오류 | `sudo` 추가 |
| `google-chrome` 실행 시 sandbox 오류 | 헤드리스 사용 시는 무관. GUI 띄울 때만 `--no-sandbox` |
| 한글 깨짐 | Windows Terminal 사용, locale 설정 (Step 3) |

---

## 막혔을 때

- 이메일: admin@jurisupport.com
- WSL 자체 설치 막힘 → Windows 버전·BIOS 캡처 첨부해서 문의
- 강의 전날까지 완료 못 한 분은 강의 당일 보조 진행자 도움 받기 어렵습니다. **반드시 사전 완료** 필요.
