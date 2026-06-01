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

# 미처리 예외 시 창이 바로 닫히지 않도록 trap
trap {
    Write-Host ""
    Write-Host "[오류] 예상치 못한 에러가 발생했습니다:" -ForegroundColor Red
    Write-Host "  $_" -ForegroundColor Red
    Write-Host ""
    Read-Host "Enter를 누르면 창이 닫힙니다"
}

function Exit-WithPause {
    param([int]$Code = 1)
    Write-Host ""
    if ($Code -ne 0) {
        Write-Host "오류로 중단되었습니다. 위 메시지를 확인하세요." -ForegroundColor Red
    }
    Read-Host "Enter를 누르면 창이 닫힙니다"
    exit $Code
}

# UTF-8 콘솔 출력
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 작업 디렉토리를 사용자 홈으로 고정.
# (PowerShell 현재 위치가 $env:USERPROFILE\jurisupport-plugins 안에 있으면
#  나중에 Move-Item/Remove-Item이 "항목이 사용 중" 에러로 실패함)
Set-Location $env:USERPROFILE

function Write-Info { param($msg) Write-Host "[bootstrap] $msg" -ForegroundColor Green }
function Write-Warn { param($msg) Write-Host "[bootstrap] $msg" -ForegroundColor Yellow }
function Write-Err  { param($msg) Write-Host "[bootstrap] $msg" -ForegroundColor Red }
function Write-Step { param($msg) Write-Host "`n--- $msg ---" -ForegroundColor Cyan }

function Add-PathEntryOnce {
    param([AllowNull()][string]$PathEntry)

    if (-not $PathEntry -or -not (Test-Path $PathEntry)) { return }

    $separator = [IO.Path]::PathSeparator
    $entries = @($env:Path -split [regex]::Escape($separator) | Where-Object { $_ })
    $alreadyPresent = $entries | Where-Object { $_ -ieq $PathEntry } | Select-Object -First 1
    if (-not $alreadyPresent) {
        if ($env:Path) {
            $env:Path = "$PathEntry$separator$env:Path"
        } else {
            $env:Path = $PathEntry
        }
    }
}

function Get-WingetCandidatePaths {
    $paths = @()
    $localAppDataCandidates = @(
        [Environment]::GetFolderPath('LocalApplicationData'),
        $env:LOCALAPPDATA
    ) | Where-Object { $_ } | Select-Object -Unique

    if ($env:USERPROFILE) {
        $localAppDataCandidates += Join-Path $env:USERPROFILE 'AppData\Local'
    }

    foreach ($basePath in ($localAppDataCandidates | Where-Object { $_ } | Select-Object -Unique)) {
        $paths += Join-Path $basePath 'Microsoft\WindowsApps\winget.exe'
    }

    try {
        $appInstaller = Get-AppxPackage -Name Microsoft.DesktopAppInstaller -ErrorAction SilentlyContinue |
            Sort-Object Version -Descending |
            Select-Object -First 1
        if ($appInstaller -and $appInstaller.InstallLocation) {
            $paths += Join-Path $appInstaller.InstallLocation 'winget.exe'
        }
    } catch {
        # Get-AppxPackage is not always available in PowerShell 7 or restricted shells.
    }

    return $paths | Where-Object { $_ } | Select-Object -Unique
}

function Resolve-WingetCommand {
    $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
    if (-not $cmd) {
        $cmd = Get-Command winget -ErrorAction SilentlyContinue
    }
    if ($cmd -and $cmd.Source) { return $cmd.Source }

    foreach ($candidate in Get-WingetCandidatePaths) {
        if (-not (Test-Path $candidate)) { continue }

        $candidateDir = Split-Path -Parent $candidate
        Add-PathEntryOnce $candidateDir

        $cmd = Get-Command winget.exe -ErrorAction SilentlyContinue
        if (-not $cmd) {
            $cmd = Get-Command winget -ErrorAction SilentlyContinue
        }
        if ($cmd -and $cmd.Source) { return $cmd.Source }

        return $candidate
    }

    return $null
}

function Invoke-WingetInstallWithReminder {
    param(
        [string]$WingetCommand,
        [string]$PackageId
    )

    $arguments = @(
        'install',
        '--id', $PackageId,
        '--exact',
        '--silent',
        '--accept-package-agreements',
        '--accept-source-agreements'
    )

    $process = Start-Process -FilePath $WingetCommand -ArgumentList $arguments -NoNewWindow -PassThru
    $nextReminder = (Get-Date).AddSeconds(20)

    while (-not $process.HasExited) {
        $now = Get-Date
        if ($now -ge $nextReminder) {
            Write-Warn "설치가 아직 진행 중입니다. 화면 아래 작업 표시줄의 방패 아이콘/UAC 창이 깜빡이면 열어서 '예'를 클릭하세요."
            Write-Warn "UAC 창이 PowerShell 뒤에 가려질 수 있습니다. Alt+Tab으로 숨은 창도 확인하세요."
            $nextReminder = $now.AddSeconds(45)
        }

        Start-Sleep -Seconds 2
        $process.Refresh()
    }

    $process.WaitForExit()
    return $process.ExitCode
}

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

$WingetCommand = Resolve-WingetCommand
if (-not $WingetCommand) {
    Write-Err "winget이 설치되어 있지 않습니다."
    Write-Host @"

  Windows 10 사용자는 Microsoft Store에서 "App Installer"를 업데이트해 주세요:
  https://apps.microsoft.com/detail/9NBLGGH4NNS1

  Windows 11은 기본 탑재되어 있으나 미설치 시 위 링크에서 설치 가능합니다.
  이미 설치되어 있는데도 이 메시지가 보이면 Windows 설정 → 앱 → 고급 앱 설정 →
  앱 실행 별칭에서 "Windows Package Manager Client" 또는 "winget"을 켠 뒤
  새 PowerShell 창에서 다시 실행하세요.

  설치 후 본 스크립트를 다시 실행하세요.

"@
    Exit-WithPause 1
}

Set-Alias -Name winget -Value $WingetCommand -Scope Script -Force
$wingetVersion = & $WingetCommand --version 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Err "winget 실행 파일은 찾았지만 정상 실행에 실패했습니다: $WingetCommand"
    Write-Host ($wingetVersion | Out-String).TrimEnd() -ForegroundColor Red
    Write-Host @"

  Microsoft Store에서 "App Installer"를 업데이트한 뒤 새 PowerShell 창에서 다시 실행하세요:
  https://apps.microsoft.com/detail/9NBLGGH4NNS1

"@
    Exit-WithPause 1
}
Write-Info "winget 확인됨: $wingetVersion ($WingetCommand)"

# winget 사용 약관 사전 동의 (자동 설치 흐름에서 프롬프트 회피)
& $WingetCommand settings --enable LocalManifestFiles 2>$null | Out-Null

# 소스(winget, msstore) agreement 사전 동의 — 안 하면 첫 패키지 설치 시 추가 프롬프트로 멈춤
Write-Info "winget 소스 약관 사전 동의 + 업데이트 중..."
& $WingetCommand source update --accept-source-agreements 2>&1 | Out-Null
& $WingetCommand list --accept-source-agreements 2>&1 | Out-Null  # source agreement 트리거

# 첫 패키지 dry-run 검증 — 멈춤 진단용
Write-Info "winget 동작 검증 (Git.Git 패키지 정보 조회)..."
$probe = & $WingetCommand show --id Git.Git --exact 2>&1
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
# 주의: Ghostscript는 winget 카탈로그에 없어 별도 함수로 GitHub release에서 자동 설치.
$packages = @(
    @{ Name = 'Git for Windows (Bash 포함)';    Ids = @('Git.Git');                  Required = $true },
    @{ Name = 'Node.js LTS';                     Ids = @('OpenJS.NodeJS.LTS');        Required = $true },
    @{ Name = 'Python 3.12';                     Ids = @('Python.Python.3.12');       Required = $true },
    @{ Name = 'Google Chrome';                   Ids = @('Google.Chrome');            Required = $true },
    @{ Name = 'jq (JSON CLI)';                   Ids = @('jqlang.jq');                Required = $true },
    @{ Name = 'Tesseract OCR (한글 포함)';       Ids = @('UB-Mannheim.TesseractOCR'); Required = $false },
    @{ Name = 'qpdf (OCRmyPDF 의존성)';          Ids = @('QPDF.QPDF');                Required = $false }
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
        $hit = & $WingetCommand list --id $id --exact 2>$null | Select-String $id
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
        $probe = & $WingetCommand show --id $id --exact 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  · ID 후보 없음(카탈로그): $id" -ForegroundColor DarkYellow
            continue
        }

        Write-Host "  → winget install $id (UAC 팝업이 뜨면 '예' 클릭)" -ForegroundColor DarkGray
        Write-Host "    설치가 멈춘 듯하면 하단 작업 표시줄의 방패 아이콘을 열어 UAC에서 '예'를 누르세요." -ForegroundColor Yellow
        $installExitCode = Invoke-WingetInstallWithReminder -WingetCommand $WingetCommand -PackageId $id

        if ($installExitCode -eq 0 -or $installExitCode -eq -1978335189) {
            # -1978335189 = APPINSTALLER_CLI_ERROR_UPDATE_NOT_APPLICABLE (이미 최신)
            Write-Host "  ✓ 설치 완료: $id" -ForegroundColor Green
            $installedOk = $true
            break
        } else {
            Write-Host "  · 설치 실패: $id (exit $installExitCode) — 다음 후보 시도" -ForegroundColor DarkYellow
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
    Exit-WithPause 1
}
if ($failedOptional.Count -gt 0) {
    Write-Warn "선택 패키지 미설치: $($failedOptional -join ', ')"
    Write-Warn "  → OCRmyPDF(책 스캔용)만 영향. 다른 기능은 정상 동작합니다."
}

# ============================================================
# 2-B. Ghostscript (winget 카탈로그에 없음 → GitHub release 직접 다운로드)
# ============================================================
Write-Host ""
Write-Host "[추가] Ghostscript (OCRmyPDF 의존성, winget 카탈로그 부재)" -ForegroundColor Cyan

$gsInstalled = Get-Command gswin64c -ErrorAction SilentlyContinue
if ($gsInstalled) {
    Write-Host "  ✓ Ghostscript 이미 설치됨: $($gsInstalled.Source)" -ForegroundColor DarkGray
} else {
    Write-Host "  → GitHub release에서 자동 다운로드 시도..." -ForegroundColor DarkGray
    try {
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        $api = 'https://api.github.com/repos/ArtifexSoftware/ghostpdl-downloads/releases/latest'
        $rel = Invoke-RestMethod -Uri $api -TimeoutSec 30 -UserAgent 'jurisupport-bootstrap'
        $asset = $rel.assets | Where-Object { $_.name -match '^gs\d+w64\.exe$' } | Select-Object -First 1
        if (-not $asset) {
            Write-Warn "  · Ghostscript Windows 64-bit installer를 release에서 찾지 못했습니다."
            Write-Warn "    수동: https://ghostscript.com/releases/gsdnld.html"
        } else {
            $url = $asset.browser_download_url
            $tmp = Join-Path $env:TEMP $asset.name
            Write-Host "  → 다운로드: $($asset.name) ($([math]::Round($asset.size / 1MB, 1)) MB)" -ForegroundColor DarkGray
            Invoke-WebRequest -Uri $url -OutFile $tmp -UseBasicParsing
            Write-Host "  → 무인 설치 중 (UAC 팝업 가능)..." -ForegroundColor DarkGray
            $proc = Start-Process -FilePath $tmp -ArgumentList '/S' -Wait -PassThru
            Remove-Item $tmp -Force -ErrorAction SilentlyContinue
            if ($proc.ExitCode -eq 0) {
                Write-Host "  ✓ Ghostscript 설치 완료" -ForegroundColor Green
                # 일반 설치 경로 PATH 추가 (현재 세션)
                $gsDir = Get-ChildItem 'C:\Program Files\gs' -Directory -ErrorAction SilentlyContinue |
                         Sort-Object Name -Descending | Select-Object -First 1
                if ($gsDir) {
                    $gsBin = Join-Path $gsDir.FullName 'bin'
                    if (Test-Path $gsBin) {
                        $env:Path = "$gsBin;$env:Path"
                        Write-Host "  · PATH 추가(현재 세션): $gsBin" -ForegroundColor DarkGray
                    }
                }
            } else {
                Write-Warn "  · 설치 실패 (exit $($proc.ExitCode)). 수동: https://ghostscript.com/releases/gsdnld.html"
            }
        }
    } catch {
        Write-Warn "  · 자동 다운로드 실패: $($_.Exception.Message)"
        Write-Warn "    수동 설치: https://ghostscript.com/releases/gsdnld.html"
    } finally {
        $ErrorActionPreference = $prevEAP
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
    Exit-WithPause 1
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
    # 기존 디렉토리 점검 — .git이 없거나 손상되면 in-place 복구 시도
    # (백업·삭제는 폴더 잠금 시 실패하므로, 폴더 이동 없이 그 자리에서 git 저장소로 복구)
    $needsInPlaceRecovery = $false
    if (Test-Path $repoDir) {
        $isValidRepo = Test-Path (Join-Path $repoDir '.git')
        if (-not $isValidRepo) {
            Write-Warn "디렉토리는 있는데 git 저장소가 아닙니다: $repoDir"
            Write-Info "  → 폴더 이동 없이 그 자리에서 git 저장소로 복구합니다 (in-place recovery)."
            $needsInPlaceRecovery = $true
        }
    }

    if ($needsInPlaceRecovery) {
        # In-place 복구: git init + remote add + fetch + reset --hard
        # 기존 파일은 reset --hard로 GitHub 상태로 덮어써짐
        # git의 stderr를 정보 출력으로 처리하기 위해 EAP 임시 변경
        $prevEAP = $ErrorActionPreference
        $ErrorActionPreference = 'Continue'
        Push-Location $repoDir
        try {
            & git init --quiet 2>&1 | Out-Null
            & git remote remove origin 2>$null | Out-Null
            & git remote add origin https://github.com/jurisupport/jurisupport-plugins.git
            & git config core.autocrlf false
            Write-Host "[git fetch] origin에서 최신 받는 중..." -ForegroundColor Cyan
            & git fetch origin --progress 2>&1 | ForEach-Object { Write-Host $_ }
            if ($LASTEXITCODE -ne 0) {
                Pop-Location
                $ErrorActionPreference = $prevEAP
                Write-Err "git fetch 실패. 네트워크/방화벽 확인 후 재시도."
                Exit-WithPause 1
            }
            Write-Host "[git reset --hard] origin/main으로 정규화..." -ForegroundColor Cyan
            & git reset --hard origin/main 2>&1 | ForEach-Object { Write-Host $_ }
            & git branch --set-upstream-to=origin/main main 2>$null | Out-Null
        } finally {
            Pop-Location
            $ErrorActionPreference = $prevEAP
        }
        Write-Info "✓ in-place 복구 완료: $repoDir"
    } elseif (Test-Path $repoDir) {
        # 정상 git 저장소 → pull + line ending 정규화
        Write-Info "기존 git 저장소 발견: $repoDir"
        Write-Host "[git config] core.autocrlf=false 강제" -ForegroundColor DarkGray
        Push-Location $repoDir
        & git config core.autocrlf false
        Write-Host "[git pull] 최신화 중..." -ForegroundColor Cyan
        & git pull --progress 2>&1 | ForEach-Object { Write-Host $_ }
        Write-Host "[git checkout] .gitattributes 기준으로 line ending 정상화..." -ForegroundColor DarkGray
        & git rm --cached -r . --quiet 2>&1 | Out-Null
        & git reset --hard HEAD 2>&1 | ForEach-Object { Write-Host $_ }
        Pop-Location
    } else {
        # 새 clone
        Write-Host "[git clone] https://github.com/jurisupport/jurisupport-plugins.git" -ForegroundColor Cyan
        Write-Host "  (core.autocrlf=false 강제 — .sh 파일 CRLF 손상 방지)" -ForegroundColor DarkGray
        & git clone --progress -c core.autocrlf=false https://github.com/jurisupport/jurisupport-plugins.git $repoDir 2>&1 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -eq 0) {
            Write-Info "✓ Clone 완료: $repoDir"
        } else {
            Write-Err "Clone 실패. 수동 실행: git clone -c core.autocrlf=false https://github.com/jurisupport/jurisupport-plugins.git $repoDir"
            Exit-WithPause 1
        }
    }

    if (Test-Path $repoDir) {
        # 정상 git 저장소 → pull + line ending 정규화
        Write-Info "기존 git 저장소 발견: $repoDir"
        Write-Host "[git config] core.autocrlf=false 강제 (Windows .sh CRLF 손상 방지)" -ForegroundColor DarkGray
        Push-Location $repoDir
        & git config core.autocrlf false
        Write-Host "[git pull] 최신화 중..." -ForegroundColor Cyan
        & git pull --progress 2>&1 | ForEach-Object { Write-Host $_ }
        Write-Host "[git checkout] .gitattributes 기준으로 line ending 정상화..." -ForegroundColor DarkGray
        & git rm --cached -r . --quiet 2>&1 | Out-Null
        & git reset --hard HEAD 2>&1 | ForEach-Object { Write-Host $_ }
        Pop-Location
    } else {
        # 새 clone
        Write-Host "[git clone] https://github.com/jurisupport/jurisupport-plugins.git" -ForegroundColor Cyan
        Write-Host "  (core.autocrlf=false 강제 — .sh 파일 CRLF 손상 방지)" -ForegroundColor DarkGray
        & git clone --progress -c core.autocrlf=false https://github.com/jurisupport/jurisupport-plugins.git $repoDir 2>&1 | ForEach-Object { Write-Host $_ }
        if ($LASTEXITCODE -eq 0) {
            Write-Info "✓ Clone 완료: $repoDir"
        } else {
            Write-Err "Clone 실패. 수동 실행: git clone -c core.autocrlf=false https://github.com/jurisupport/jurisupport-plugins.git $repoDir"
            Exit-WithPause 1
        }
    }
} finally {
    $ErrorActionPreference = $prevEAP
}
Write-Progress -Id 1 -Activity "Step 4/4: jurisupport-plugins git clone" -Completed

# ============================================================
# 5. install.sh 자동 실행 (Git Bash)
# ============================================================
Write-Step "Step 5/5: install.sh 자동 실행 (Git Bash)"

if (-not (Test-Path $gitBash)) {
    Write-Err "Git Bash를 찾지 못해 install.sh를 자동 실행하지 못합니다."
    Write-Err "수동: 시작 메뉴 → Git Bash → cd ~/jurisupport-plugins && ./install.sh"
} elseif (-not (Test-Path "$repoDir\install.sh")) {
    Write-Err "install.sh를 찾지 못함: $repoDir\install.sh"
} else {
    @"

  install.sh가 곧 시작됩니다. 8단계 대화식 설치:
    1~4. 의존성 점검, Hook, 플러그인, 스킬 (자동/Enter)
    5~8. CSV 템플릿·검색 서버 (각 단계 [Y/n] 응답)

  Gemini API 키(무료): https://aistudio.google.com/apikey
  (6, 7번 단계에서 사용. 건너뛰려면 Enter)

  3초 후 시작...
"@ | Write-Host -ForegroundColor Cyan
    Start-Sleep -Seconds 3

    # PowerShell의 stdin을 그대로 bash에 전달 → 대화식 [Y/n] 정상 동작
    # 임시로 EAP=Continue (bash가 stderr로 정보 보낼 수 있음)
    $prevEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        Push-Location $repoDir
        & $gitBash './install.sh'
        $installExit = $LASTEXITCODE
        Pop-Location
    } finally {
        $ErrorActionPreference = $prevEAP
    }

    if ($installExit -eq 0) {
        Write-Host ""
        Write-Host "✓ install.sh 완료" -ForegroundColor Green
    } else {
        Write-Warn "install.sh 비정상 종료 (exit $installExit). 수동 재실행 가능:"
        Write-Warn "  Git Bash → cd ~/jurisupport-plugins && ./install.sh"
    }
}

# ============================================================
# 6. 마무리 안내
# ============================================================
Write-Step "마무리"

@"

╔════════════════════════════════════════════════════════════╗
║   ✓ 설치 완료!                                              ║
╚════════════════════════════════════════════════════════════╝

남은 2단계:

[1] Claude Code 로그인 (1회):

    claude

    → 브라우저가 자동으로 열리며 Claude Pro/Max OAuth 진행.
    → 한 번만 로그인하면 이후 영구 유지.

  플러그인·JuriSupport MCP 모두 install.sh가 자동 등록.
  자동 설치가 실패한 경우에만 수동 명령:

    [수동 fallback A] 플러그인:
      claude plugin marketplace add $repoDir
      claude plugin install songmu-legal@jurisupport-plugins

    [수동 fallback B] JuriSupport MCP (사건 50건까지 무료):
      1) https://jurisupport.com 가입
      2) https://jurisupport.com/profile 에서 API 토큰 발급
      3) claude mcp add --transport sse jurisupport https://api.jurisupport.com/mcp/sse ``
           --header "Authorization: Bearer <발급받은_토큰>"

첫 사건 시작:

    mkdir `$env:USERPROFILE\사건\2026-001_홍길동_대여금
    cd `$env:USERPROFILE\사건\2026-001_홍길동_대여금
    claude

    클로드코드 안에서:
      /songmu-legal:cold-start-interview   (최초 1회: 사무소 플레이북)
      /songmu-legal:brief-protocol         (준비서면 작성 표준 절차)

전체 가이드: $repoDir\WINDOWS_NATIVE.md
GitHub:      https://github.com/jurisupport/jurisupport-plugins
문의:        admin@jurisupport.com

"@ | Write-Host -ForegroundColor Green

Read-Host "Enter를 누르면 창이 닫힙니다"
