# jurisupport-plugins 언인스톨러 (Windows PowerShell)
#
# 본 패키지가 설치한 모든 것을 단계별로 제거합니다.
# - 데이터·등록: uninstall.sh(Git Bash) 호출
# - Claude Code: npm uninstall -g
# - 시스템 패키지: winget uninstall (선택)
#
# 사용:
#   irm https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/windows-uninstall.ps1 | iex
#
# 또는 로컬:
#   PowerShell에서:
#     & "$env:USERPROFILE\jurisupport-plugins\windows-uninstall.ps1"

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

function Write-Info { param($msg) Write-Host "[uninstall] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[uninstall] $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "[uninstall] $msg" -ForegroundColor Red }
function Write-Step { param($msg) Write-Host "`n--- $msg ---" -ForegroundColor Cyan }

function Confirm-Y { param($prompt)
    $ans = Read-Host "  $prompt [y/N]"
    return ($ans -eq 'y' -or $ans -eq 'Y')
}

# ============================================================
# Banner
# ============================================================
@"

============================================================
  jurisupport-plugins 언인스톨러 (Windows)
============================================================

  진행 단계:
    1. uninstall.sh (Git Bash) — 등록·toolkit 데이터 제거
    2. Claude Code 제거 (npm uninstall -g)
    3. ~/jurisupport-plugins 폴더 제거
    4. winget 시스템 패키지 제거 (선택, 매우 신중)

  ⚠ 시스템 패키지(Git, Node, Python, Chrome 등)는 다른 앱도
    사용할 수 있으므로 기본은 건너뜁니다.
    제거하려면 각 단계에서 'y' 명시 선택.

  계속: Enter   취소: Ctrl+C
============================================================

"@ | Write-Host
Read-Host | Out-Null

# ============================================================
# Step 1. uninstall.sh (Git Bash 통해)
# ============================================================
Write-Step "Step 1/4: 등록·데이터 제거 (uninstall.sh)"

$repoDir = Join-Path $env:USERPROFILE 'jurisupport-plugins'
$uninstallSh = Join-Path $repoDir 'uninstall.sh'

$gitBash = Join-Path $env:ProgramFiles 'Git\bin\bash.exe'
if (-not (Test-Path $gitBash)) {
    $gitBash = Join-Path ${env:ProgramFiles(x86)} 'Git\bin\bash.exe'
}

if ((Test-Path $uninstallSh) -and (Test-Path $gitBash)) {
    Write-Info "Git Bash로 uninstall.sh 실행..."
    & $gitBash $uninstallSh
    Write-Info "Step 1 완료"
} else {
    Write-Warn "uninstall.sh 또는 Git Bash 없음 → 등록·데이터 정리 건너뜀"
    Write-Warn "  uninstall.sh: $uninstallSh"
    Write-Warn "  Git Bash:    $gitBash"
}

# ============================================================
# Step 2. Claude Code (npm 글로벌) 제거
# ============================================================
Write-Step "Step 2/4: Claude Code 제거 (npm uninstall -g)"

if (Get-Command npm -ErrorAction SilentlyContinue) {
    $claudeInstalled = npm list -g --depth=0 2>$null | Select-String '@anthropic-ai/claude-code'
    if ($claudeInstalled) {
        if (Confirm-Y "Claude Code를 npm 글로벌에서 제거할까요?") {
            $prevEAP = $ErrorActionPreference
            $ErrorActionPreference = 'Continue'
            try {
                & npm uninstall -g @anthropic-ai/claude-code 2>&1 | ForEach-Object { Write-Host $_ }
                Write-Info "✓ Claude Code 제거 완료"
            } finally {
                $ErrorActionPreference = $prevEAP
            }
        } else {
            Write-Info "  · 건너뜀"
        }
    } else {
        Write-Info "  · Claude Code 미설치 (이미 제거됨)"
    }
} else {
    Write-Warn "  · npm 명령 없음 → 건너뜀"
}

# ============================================================
# Step 3. 본 레포 폴더
# ============================================================
Write-Step "Step 3/4: 본 레포 폴더 제거 (~/jurisupport-plugins)"

if (Test-Path $repoDir) {
    if (Confirm-Y "$repoDir 폴더를 제거할까요?") {
        Remove-Item -Recurse -Force $repoDir
        Write-Info "✓ 제거 완료: $repoDir"
    } else {
        Write-Info "  · 건너뜀"
    }
} else {
    Write-Info "  · 폴더 없음"
}

# ============================================================
# Step 4. winget 시스템 패키지 (매우 신중)
# ============================================================
Write-Step "Step 4/4: winget 시스템 패키지 제거 (선택)"

@"

⚠ 다음 패키지들은 본 패키지가 설치했지만, 다른 앱이나 개인 용도로
  사용 중일 수 있습니다. 정말 안 쓸 것이 확실한 경우에만 'y' 선택하세요.

"@ | Write-Host -ForegroundColor Yellow

$packages = @(
    @{ Name = 'qpdf (OCRmyPDF 의존성)';          Ids = @('qpdf.qpdf', 'JayBerkenbilt.qpdf') },
    @{ Name = 'Ghostscript (OCRmyPDF 의존성)';   Ids = @('ArtifexSoftware.GhostScript.AGPL', 'ArtifexSoftware.GhostScript') },
    @{ Name = 'Tesseract OCR';                   Ids = @('UB-Mannheim.TesseractOCR') },
    @{ Name = 'jq';                              Ids = @('jqlang.jq') },
    @{ Name = 'Google Chrome';                   Ids = @('Google.Chrome') },
    @{ Name = 'Python 3.12';                     Ids = @('Python.Python.3.12') },
    @{ Name = 'Node.js LTS';                     Ids = @('OpenJS.NodeJS.LTS') },
    @{ Name = 'Git for Windows';                 Ids = @('Git.Git') }
)

foreach ($pkg in $packages) {
    foreach ($id in $pkg.Ids) {
        $installed = & winget list --id $id --exact 2>$null | Select-String $id
        if ($installed) {
            if (Confirm-Y "제거: $($pkg.Name)  [$id]") {
                Write-Host "  → winget uninstall $id" -ForegroundColor DarkGray
                $prevEAP = $ErrorActionPreference
                $ErrorActionPreference = 'Continue'
                try {
                    & winget uninstall --id $id --exact --silent 2>&1 | ForEach-Object { Write-Host $_ }
                    if ($LASTEXITCODE -eq 0) {
                        Write-Info "  ✓ 제거 완료"
                    } else {
                        Write-Warn "  · 제거 실패 (exit $LASTEXITCODE)"
                    }
                } finally {
                    $ErrorActionPreference = $prevEAP
                }
            } else {
                Write-Info "  · 보존: $($pkg.Name)"
            }
            break  # 한 ID라도 처리하면 다음 패키지
        }
    }
}

# ============================================================
# Done
# ============================================================
@"

============================================================
  ✓ 언인스톨 완료
============================================================

남아 있을 수 있는 것:
  - 사용자 사건 자료: ~/사건/
  - Gemini API 키 (Step 1에서 보존 선택 시): ~/.jurisupport/secrets.env
  - 자동 생성된 npm 캐시: ~/AppData/Roaming/npm 또는 ~/AppData/Local/npm-cache
  - winget 캐시: ~/AppData/Local/Microsoft/WinGet

수동 정리 (필요 시):
  rmdir /s `$env:USERPROFILE\사건                          (사건 자료까지 삭제)
  rmdir /s `$env:APPDATA\npm                              (npm 글로벌 잔여)
  rmdir /s `$env:LOCALAPPDATA\npm-cache                    (npm 캐시)

설치를 다시 하려면:
  irm https://raw.githubusercontent.com/jurisupport/jurisupport-plugins/main/windows-bootstrap.ps1 | iex

"@ | Write-Host -ForegroundColor Green
