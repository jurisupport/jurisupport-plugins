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

$total = $packages.Count
$i = 0
$failed = @()
foreach ($pkg in $packages) {
    $i++
    $percent = [int](($i - 1) / $total * 100)

    # 상단 PowerShell 네이티브 progress bar
    Write-Progress -Id 1 -Activity "Step 2/4: 공통 패키지 설치 ($i / $total)" `
                   -Status "$($pkg.Name)" -CurrentOperation "winget id: $($pkg.Id)" `
                   -PercentComplete $percent

    Write-Host ""
    Write-Host "[$i/$total] $($pkg.Name) ($($pkg.Id))" -ForegroundColor Cyan

    $installed = winget list --id $pkg.Id --exact 2>$null | Select-String $pkg.Id
    if ($installed) {
        Write-Host "  ✓ 이미 설치됨, 건너뜀" -ForegroundColor DarkGray
        continue
    }

    # winget 실시간 출력 그대로 노출 (다운로드 % · 설치 진행)
    # --silent: 패키지 인스톨러 GUI 숨김 / winget 자체 progress는 유지됨
    & winget install --id $pkg.Id --exact --silent `
        --accept-package-agreements --accept-source-agreements --disable-interactivity

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  ✓ $($pkg.Name) 설치 완료" -ForegroundColor Green
    } else {
        Write-Host "  ✗ $($pkg.Name) 설치 실패 (exit $LASTEXITCODE)" -ForegroundColor Yellow
        $failed += $pkg.Name
    }
}
Write-Progress -Id 1 -Activity "Step 2/4: 공통 패키지 설치" -Completed

if ($failed.Count -gt 0) {
    Write-Warn "다음 패키지 설치 실패: $($failed -join ', ')"
    Write-Warn "수동 설치 후 본 스크립트를 다시 실행하세요."
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

Write-Progress -Id 1 -Activity "Step 3/4: Claude Code" -Status "npm 패키지 확인" -PercentComplete 10

$claudeInstalled = npm list -g --depth=0 2>$null | Select-String '@anthropic-ai/claude-code'
if ($claudeInstalled) {
    Write-Info "Claude Code 이미 설치됨"
} else {
    Write-Host "[npm] @anthropic-ai/claude-code 다운로드·설치 중 (약 1~2분)..." -ForegroundColor Cyan
    Write-Progress -Id 1 -Activity "Step 3/4: Claude Code" -Status "npm install -g" -PercentComplete 40
    # npm 자체 progress 출력 유지 (--loglevel http로 다운로드 표시)
    & npm install -g @anthropic-ai/claude-code --loglevel http
    if ($LASTEXITCODE -eq 0) {
        Write-Info "✓ Claude Code 설치 완료: $(claude --version 2>$null)"
    } else {
        Write-Err "Claude Code 설치 실패. 새 PowerShell(관리자)에서 직접 실행: npm install -g @anthropic-ai/claude-code"
    }
}
Write-Progress -Id 1 -Activity "Step 3/4: Claude Code" -Completed

# ============================================================
# 4. 본 레포 clone
# ============================================================
Write-Step "4. jurisupport-plugins git clone"

Write-Progress -Id 1 -Activity "Step 4/4: jurisupport-plugins git clone" -Status "확인 중" -PercentComplete 10

$repoDir = Join-Path $env:USERPROFILE 'jurisupport-plugins'
if (Test-Path $repoDir) {
    Write-Info "기존 디렉토리 발견: $repoDir"
    Write-Host "[git pull] 최신화 중..." -ForegroundColor Cyan
    Push-Location $repoDir
    & git pull --progress
    Pop-Location
} else {
    Write-Host "[git clone] https://github.com/jurisupport/jurisupport-plugins.git" -ForegroundColor Cyan
    # --progress: 압축 해제·다운로드 진행 표시
    & git clone --progress https://github.com/jurisupport/jurisupport-plugins.git $repoDir
    if ($LASTEXITCODE -eq 0) {
        Write-Info "✓ Clone 완료: $repoDir"
    } else {
        Write-Err "Clone 실패. 수동 실행: git clone https://github.com/jurisupport/jurisupport-plugins.git $repoDir"
    }
}
Write-Progress -Id 1 -Activity "Step 4/4: jurisupport-plugins git clone" -Completed

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
