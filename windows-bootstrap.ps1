# jurisupport-plugins bootstrap (Windows native)
#
# Windows 10 22H2+ / Windows 11에서 jurisupport-plugins 통합 패키지의
# 모든 사전 의존성과 본 패키지를 자동 설치합니다.
#
# 사용 (PowerShell):
#   irm https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/windows-bootstrap.ps1 | iex
#
# 자동 설치 항목 (winget):
#   - Git for Windows (Git Bash 포함)
#   - Node.js LTS
#   - Python 3.12
#   - Google Chrome
#   - jq
#   - Tesseract OCR (한글 포함)
#   - Ghostscript
#   - qpdf
#   - Claude Code (npm i -g)
#   - jurisupport-plugins git clone
#
# 인간 입력 필요:
#   - winget 설치 동의 (UAC 팝업 여러 번 가능)
#   - 본 패키지 install.sh는 Git Bash에서 별도 실행
#   - Claude Pro/Max OAuth (claude 실행 시)

$ErrorActionPreference = 'Stop'

# UTF-8 콘솔 출력
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Info { param($msg) Write-Host "[bootstrap] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[bootstrap] $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "[bootstrap] $msg" -ForegroundColor Red }
function Write-Step { param($msg) Write-Host "`n--- $msg ---" -ForegroundColor Cyan }

# ============================================================
# 0. Banner
# ============================================================
@"

============================================================
  jurisupport-plugins bootstrap (Windows 네이티브)
  변호사용 클로드코드 통합 패키지 자동 설치
============================================================

  진행 단계:
    1. winget 사전 점검
    2. Git, Node, Python, Chrome, jq, Tesseract, Ghostscript, qpdf
    3. Claude Code (npm install -g)
    4. jurisupport-plugins git clone
    5. 마무리 안내 (Git Bash로 install.sh 실행)

  ⚠ winget 설치 중 UAC 권한 팝업이 여러 번 뜰 수 있습니다.
  ⚠ Claude Pro 미가입자는 https://claude.ai/upgrade 먼저 가입.

  소요 시간: 약 10~15분

============================================================

"@ | Write-Host

# ============================================================
# 1. winget 사전 점검
# ============================================================
Write-Step "1. winget 점검"

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Err "winget이 설치되어 있지 않습니다."
    Write-Host @"

  Windows 10 사용자는 Microsoft Store에서 "App Installer"를 업데이트해 주세요:
  https://apps.microsoft.com/detail/9NBLGGH4NNS1

  Windows 11은 기본 탑재되어 있으나 미설치 시 위 링크에서 설치 가능합니다.
  설치 후 본 스크립트를 다시 실행하세요.

"@
    exit 1
}
Write-Info "winget 확인됨: $(winget --version)"

# winget 사용 약관 사전 동의 (자동 설치 흐름에서 프롬프트 회피)
winget settings --enable LocalManifestFiles 2>$null | Out-Null

# ============================================================
# 2. 공통 패키지 설치 (winget)
# ============================================================
Write-Step "2. 공통 패키지 설치 (winget)"

$packages = @(
    @{ Id = 'Git.Git';                      Name = 'Git for Windows (Bash 포함)' },
    @{ Id = 'OpenJS.NodeJS.LTS';            Name = 'Node.js LTS' },
    @{ Id = 'Python.Python.3.12';           Name = 'Python 3.12' },
    @{ Id = 'Google.Chrome';                Name = 'Google Chrome' },
    @{ Id = 'jqlang.jq';                    Name = 'jq (JSON CLI)' },
    @{ Id = 'UB-Mannheim.TesseractOCR';     Name = 'Tesseract OCR (한글 포함)' },
    @{ Id = 'ArtifexSoftware.GhostScript';  Name = 'Ghostscript (OCRmyPDF 의존성)' },
    @{ Id = 'qpdf.qpdf';                    Name = 'qpdf (OCRmyPDF 의존성)' }
)

foreach ($pkg in $packages) {
    Write-Info "$($pkg.Name) ..."
    $installed = winget list --id $pkg.Id --exact 2>$null | Select-String $pkg.Id
    if ($installed) {
        Write-Info "  이미 설치됨, 건너뜀"
        continue
    }
    try {
        winget install --id $pkg.Id --exact --silent --accept-package-agreements --accept-source-agreements --disable-interactivity 2>&1 | ForEach-Object {
            if ($_ -match 'Installer hash|Successfully installed|already installed|Found') {
                Write-Host "    $_" -ForegroundColor DarkGray
            }
        }
        Write-Info "  ✓ 설치 완료"
    } catch {
        Write-Warn "  $($pkg.Name) 설치 실패 — 수동 설치 후 다시 시도하세요"
    }
}

# 새 셸 PATH 갱신 (현재 세션에서 즉시 활용)
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + `
            [System.Environment]::GetEnvironmentVariable("Path","User")

# Git Bash 경로 (보통 C:\Program Files\Git\bin\bash.exe)
$gitBash = Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
if (-not (Test-Path $gitBash)) {
    $gitBash = Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe'
}
if (Test-Path $gitBash) {
    Write-Info "Git Bash 경로: $gitBash"
} else {
    Write-Warn "Git Bash를 찾지 못했습니다. Git 재설치 후 새 PowerShell에서 다시 시도하세요."
}

# ============================================================
# 3. Claude Code (npm 글로벌)
# ============================================================
Write-Step "3. Claude Code (npm install -g)"

if (-not (Get-Command npm -ErrorAction SilentlyContinue)) {
    Write-Err "npm을 찾을 수 없습니다. 새 PowerShell 창에서 다시 실행해 주세요 (PATH 갱신 필요)."
    exit 1
}

$claudeInstalled = npm list -g --depth=0 2>$null | Select-String '@anthropic-ai/claude-code'
if ($claudeInstalled) {
    Write-Info "Claude Code 이미 설치됨"
} else {
    Write-Info "Claude Code 설치 중..."
    npm install -g @anthropic-ai/claude-code
    Write-Info "✓ Claude Code 설치 완료: $(claude --version 2>$null)"
}

# ============================================================
# 4. 본 레포 clone
# ============================================================
Write-Step "4. jurisupport-plugins git clone"

$repoDir = Join-Path $env:USERPROFILE 'jurisupport-plugins'
if (Test-Path $repoDir) {
    Write-Info "기존 디렉토리 발견: $repoDir"
    Write-Info "  git pull로 최신화 시도..."
    Push-Location $repoDir
    git pull 2>&1 | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
    Pop-Location
} else {
    git clone https://github.com/jurisupport/jurisupport-plugins.git $repoDir
    Write-Info "✓ Clone 완료: $repoDir"
}

# ============================================================
# 5. 마무리 안내
# ============================================================
Write-Step "5. 다음 단계"

@"

✓ 사전 설치 모두 완료!

이제 다음 두 단계만 남았습니다:

  [1] Claude Code 로그인 (1회)
      PowerShell 또는 Git Bash에서:
        claude
      → 브라우저가 열리며 Claude Pro/Max OAuth 진행

  [2] 본 패키지 install.sh 실행 (Git Bash 사용)
      시작 메뉴 → "Git Bash" 검색 → 실행 → 다음 입력:

        cd ~/jurisupport-plugins
        ./install.sh

      → 데이터 보호 Hook, songmu-legal 플러그인, 스킬, 검색 서버 등이
         대화식으로 설치됩니다 (약 10분).

설치 후 첫 사건 시작:
  Git Bash에서  cd ~/사건/{사건폴더}  →  claude

전체 가이드: $repoDir\WINDOWS_NATIVE.md
GitHub:      https://github.com/jurisupport/jurisupport-plugins
문의:        admin@jurisupport.com

"@ | Write-Host -ForegroundColor Green
