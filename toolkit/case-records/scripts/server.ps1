# case-records search server manager (Windows PowerShell)
# Port 8767
# Usage: server.ps1 {start|stop|restart|status}

param([string]$Action = 'status')

$ErrorActionPreference = 'Stop'

$ROOT    = Join-Path $env:USERPROFILE 'case-records'
$VENV_PY = Join-Path $ROOT '.venv\Scripts\python.exe'
$SERVER  = Join-Path $ROOT 'server\server.py'
$PIDFILE = Join-Path $ROOT 'logs\server.pid'
$LOGFILE = Join-Path $ROOT 'logs\server.log'
$ERRFILE = Join-Path $ROOT 'logs\server.err.log'
$PORT    = 8767

function Get-ServerPid {
    if (Test-Path $PIDFILE) {
        $serverPid = (Get-Content $PIDFILE -ErrorAction SilentlyContinue).Trim()
        if ($serverPid -and (Get-Process -Id $serverPid -ErrorAction SilentlyContinue)) {
            return [int]$serverPid
        }
    }
    return $null
}

function Start-Server {
    $running = Get-ServerPid
    if ($running) {
        Write-Host "Server already running (PID $running)"
        return
    }
    if (-not (Test-Path $VENV_PY)) {
        Write-Error "venv Python을 찾지 못했습니다: $VENV_PY"
        return
    }
    New-Item -ItemType Directory -Force -Path (Split-Path $LOGFILE) | Out-Null

    $proc = Start-Process -FilePath $VENV_PY -ArgumentList $SERVER `
        -RedirectStandardOutput $LOGFILE -RedirectStandardError $ERRFILE `
        -WindowStyle Hidden -PassThru
    $proc.Id | Out-File -Encoding ascii $PIDFILE
    Write-Host "Server started (PID $($proc.Id)). Log: $LOGFILE"
}

function Stop-Server {
    $running = Get-ServerPid
    if ($running) {
        Stop-Process -Id $running -Force -ErrorAction SilentlyContinue
        Remove-Item $PIDFILE -Force -ErrorAction SilentlyContinue
        Write-Host "Server stopped (PID $running)"
    } else {
        Write-Host "Server not running"
    }
}

function Get-ServerStatus {
    $running = Get-ServerPid
    if ($running) {
        Write-Host "Running (PID $running)"
        try {
            $resp = Invoke-RestMethod -Uri "http://localhost:$PORT/health" -TimeoutSec 2
            $resp | ConvertTo-Json -Compress
        } catch {
            Write-Host "(health 응답 없음 — 서버 초기화 중일 수 있음)"
        }
    } else {
        Write-Host "Not running"
    }
}

switch ($Action) {
    'start'   { Start-Server }
    'stop'    { Stop-Server }
    'restart' { Stop-Server; Start-Sleep -Seconds 1; Start-Server }
    'status'  { Get-ServerStatus }
    default   { Write-Host "Usage: server.ps1 {start|stop|restart|status}"; exit 1 }
}
