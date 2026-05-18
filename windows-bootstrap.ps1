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

# 소스(winget, msstore) agreement 사전 동의 — 안 하면 첫 패키지 설치 시 추가 프롬프트로 멈춤
Write-Info "winget 소스 약관 사전 동의 + 업데이트 중..."
& winget source update --accept-source-agreements 2>&1 | Out-Null
& winget list --accept-source-agreements 2>&1 | Out-Null  # source agreement 트리거

# 첫 패키지 dry-run 검증 — 멈춤 진단용
Write-Info "winget 동작 검증 (Git.Git 패키지 정보 조회)..."
$probe = & winget show --id Git.Git --exact 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Warn "winget show가 실패했습니다. 네트워크 또는 winget 카탈로그 문제."
    Write-Warn "수동 점검: winget search Git.Git"
} else {
    Write-Info "✓ winget 정상 동작 확인"
}

# ============================================================
# 2. 공통 패키지 설치 (winget)
# ============================================================
Write-Step "2. 공통 패키지 설치 (winget)"

@"

⚠ 중요 — UAC 권한 팝업이 여러 번 뜹니다.

  일부 패키지(Git, Chrome, Python 등)는 시스템 영역 설치라 관리자 승격이 필요합니다.
  팝업이 PowerShell 창 뒤에 가려질 수 있으니 작업 표시줄을 확인해 주세요.
  ▶ 노란 방패 아이콘이 깜빡이면 클릭 → "예" 누르기

  팝업을 못 봤거나 차단했다면 설치가 무한 대기 상태로 보일 수 있습니다.
  그럴 땐 Ctrl+C로 중단 후 본 스크립트를 다시 실행하세요.

"@ | Write-Host -ForegroundColor Yellow

# Required: 실패 시 본 패키지 사용 자체가 불가
# Optional: 실패해도 메인 기능은 동작 (legal-books toolkit의 OCR만 영향)
# Ids: winget 카탈로그에서 fallback 후보. 첫 ID부터 순차 시도, 성공한 것 사용.
$packages = @(
    @{ Name = 'Git for Windows (Bash 포함)';    Ids = @('Git.Git');                                                  Required = $true },
    @{ Name = 'Node.js LTS';                     Ids = @('OpenJS.NodeJS.LTS');                                        Required = $true },
    @{ Name = 'Python 3.12';                     Ids = @('Python.Python.3.12');                                       Required = $true },
    @{ Name = 'Google Chrome';                   Ids = @('Google.Chrome');                                            Required = $true },
    @{ Name = 'jq (JSON CLI)';                   Ids = @('jqlang.jq');                                                Required = $true },
    @{ Name = 'Tesseract OCR (한글 포함)';       Ids = @('UB-Mannheim.TesseractOCR');                                 Required = $false },
    @{ Name = 'Ghostscript (OCRmyPDF 의존성)';   Ids = @('ArtifexSoftware.GhostScript.AGPL', 'ArtifexSoftware.GhostScript', 'Ghostscript.Ghostscript'); Required = $false },
    @{ Name = 'qpdf (OCRmyPDF 의존성)';          Ids = @('qpdf.qpdf', 'JayBerkenbilt.qpdf');                          Required = $false }
)

$total = $packages.Count
$i = 0
$failedRequired = @()
$failedOptional = @()

foreach ($pkg in $packages) {
    $i++
    $percent = [int](($i - 1) / $total * 100)

    # 상단 PowerShell 네이티브 progress bar
    Write-Progress -Id 1 -Activity "Step 2/4: 공통 패키지 설치 ($i / $total)" `
                   -Status "$($pkg.Name)" -CurrentOperation "winget id 후보: $($pkg.Ids -join ', ')" `
                   -PercentComplete $percent

    $tag = if ($pkg.Required) { '[필수]' } else { '[선택]' }
    Write-Host ""
    Write-Host "[$i/$total] $tag $($pkg.Name)" -ForegroundColor Cyan

    # 이미 설치된 ID가 있는지 먼저 확인
    $alreadyInstalled = $false
    foreach ($id in $pkg.Ids) {
        $hit = & winget list --id $id --exact 2>$null | Select-String $id
        if ($hit) {
            Write-Host "  ✓ 이미 설치됨: $id" -ForegroundColor DarkGray
            $alreadyInstalled = $true
            break
        }
    }
    if ($alreadyInstalled) { continue }

    # ID 후보를 순차 시도
    $installedOk = $false
    foreach ($id in $pkg.Ids) {
        # 카탈로그에 ID가 있는지 먼저 확인 (없으면 건너뜀)
        $probe = & winget show --id $id --exact 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  · ID 후보 없음(카탈로그): $id" -ForegroundColor DarkYellow
            continue
        }

        Write-Host "  → winget install $id (UAC 팝업이 뜨면 '예' 클릭)" -ForegroundColor DarkGray
        & winget install --id $id --exact --silent `
            --accept-package-agreements --accept-source-agreements

        if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq -1978335189) {
            # -1978335189 = APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE (이미 최신)
            Write-Host "  ✓ 설치 완료: $id" -ForegroundColor Green
            $installedOk = $true
            break
        } else {
            Write-Host "  · 설치 실패: $id (exit $LASTEXITCODE) — 다음 후보 시도" -ForegroundColor DarkYellow
        }
    }

    if (-not $installedOk) {
        if ($pkg.Required) {
            Write-Host "  ✗ [필수] $($pkg.Name) 설치 실패 — 진행 중단" -ForegroundColor Red
            $failedRequired += $pkg.Name
        } else {
            Write-Host "  ⚠ [선택] $($pkg.Name) 설치 실패 — 메인 기능엔 영향 없음" -ForegroundColor Yellow
            $failedOptional += $pkg.Name
        }
    }
}
Write-Progress -Id 1 -Activity "Step 2/4: 공통 패키지 설치" -Completed

if ($failedRequired.Count -gt 0) {
    Write-Err "다음 필수 패키지 설치 실패: $($failedRequired -join ', ')"
    Write-Err "수동 설치 후 본 스크립트를 다시 실행하세요."
    Write-Err "수동 검색: winget search <키워드>"
    exit 1
}
if ($failedOptional.Count -gt 0) {
    Write-Warn "선택 패키지 미설치: $($failedOptional -join ', ')"
    Write-Warn "  → OCRmyPDF(책 스캔용)만 영향. 다른 기능은 정상 동작합니다."
    Write-Warn "  수동 설치 필요 시:"
    Write-Warn "    Ghostscript : https://ghostscript.com/releases/gsdnld.html"
    Write-Warn "    qpdf        : https://github.com/qpdf/qpdf/releases"
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

# npm은 정보 메시지(npm notice)를 stderr로 보내는데, PowerShell의
# $ErrorActionPreference='Stop' 환경에서는 이걸 진짜 에러처럼 빨갛게 표시함.
# → 이 단계만 임시로 Continue로 바꾸고, 실제 성공 여부는 exit code로 판단.
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $claudeInstalled = npm list -g --depth=0 2>$null | Select-String '@anthropic-ai/claude-code'
    if ($claudeInstalled) {
        Write-Info "Claude Code 이미 설치됨"
    } else {
        Write-Host "[npm] @anthropic-ai/claude-code 다운로드·설치 중 (약 1~2분)..." -ForegroundColor Cyan
        Write-Host "       (npm notice 빨간 메시지가 보여도 정상입니다 — 정보 출력일 뿐)" -ForegroundColor DarkGray
        Write-Progress -Id 1 -Activity "Step 3/4: Claude Code" -Status "npm install -g" -PercentComplete 40

        # stderr를 stdout으로 합쳐서 PowerShell RemoteException 회피
        & npm install -g @anthropic-ai/claude-code --loglevel http 2>&1 | ForEach-Object { Write-Host $_ }

        if ($LASTEXITCODE -eq 0) {
            $ver = & claude --version 2>$null
            Write-Info "✓ Claude Code 설치 완료: $ver"
        } else {
            Write-Err "Claude Code 설치 실패 (exit $LASTEXITCODE)"
            Write-Err "수동 실행: 새 PowerShell(관리자)에서  npm install -g @anthropic-ai/claude-code"
        }
    }
} finally {
    $ErrorActionPreference = $prevEAP
}
Write-Progress -Id 1 -Activity "Step 3/4: Claude Code" -Completed

# ============================================================
# 4. 본 레포 clone
# ============================================================
Write-Step "4. jurisupport-plugins git clone"

Write-Progress -Id 1 -Activity "Step 4/4: jurisupport-plugins git clone" -Status "확인 중" -PercentComplete 10

# git도 progress 출력을 stderr로 보냄 → 임시 EAP 변경
$prevEAP = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
    $repoDir = Join-Path $env:USERPROFILE 'jurisupport-plugins'
    if (Test-Path $repoDir) {
        Write-Info "기존 디렉토리 발견: $repoDir"
        Write-Host "[git pull] 최신화 중..." -ForegroundColor Cyan
        Push-Location $repoDir
        & git pull --progress 2>&1 | ForEach-Object { Write-Host $_ }
        Pop-Location
    } else {
        Write-Host "[git clone] https://github.com/jurisupport/jurisupport-plugins.git" -ForegroundColor Cyan
        & git clone --progress https://github.com/jurisupport/jurisupport-plugins.git $repoDir 2>&1 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -eq 0) {
            Write-Info "✓ Clone 완료: $repoDir"
        } else {
            Write-Err "Clone 실패. 수동 실행: git clone https://github.com/jurisupport/jurisupport-plugins.git $repoDir"
        }
    }
} finally {
    $ErrorActionPreference = $prevEAP
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
