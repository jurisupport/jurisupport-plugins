# Run the real batch menu with fake executables; no installation or user config.
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$temp = Join-Path ([IO.Path]::GetTempPath()) ('juri setup ' + [guid]::NewGuid().ToString('N'))
$oldPath = $env:PATH
New-Item -ItemType Directory -Path $temp | Out-Null
try {
    Copy-Item (Join-Path $root 'korean-law-setup.cmd') $temp
    Copy-Item (Join-Path $root 'credentials-setup.cmd') $temp
    $stub = Join-Path $temp 'stub.exe'
    Add-Type -OutputAssembly $stub -OutputType ConsoleApplication -TypeDefinition @'
using System;
using System.IO;
public class LauncherStub {
    public static int Main(string[] args) {
        string name = Path.GetFileNameWithoutExtension(Environment.GetCommandLineArgs()[0]);
        if (name == "choice") {
            string state = Environment.GetEnvironmentVariable("JURI_TEST_CHOICE_STATE");
            if (File.Exists(state)) return 4;
            File.WriteAllText(state, "seen");
            return int.Parse(Environment.GetEnvironmentVariable("JURI_TEST_CHOICE"));
        }
        if (Array.IndexOf(args, "-c") >= 0) return 0;
        File.AppendAllText(Environment.GetEnvironmentVariable("JURI_TEST_LOG"), string.Join("|", args) + "\n");
        return 0;
    }
}
'@
    foreach ($name in @('py.exe', 'python.exe', 'choice.exe')) {
        Copy-Item $stub (Join-Path $temp $name)
    }
    $env:PATH = "$temp;$oldPath"
    $env:JURI_TEST_LOG = Join-Path $temp 'calls.txt'
    $env:JURI_TEST_CHOICE_STATE = Join-Path $temp 'choice.txt'
    foreach ($selection in @(1, 2, 3, 4)) {
        Remove-Item $env:JURI_TEST_LOG, $env:JURI_TEST_CHOICE_STATE -ErrorAction SilentlyContinue
        $env:JURI_TEST_CHOICE = [string]$selection
        $start = New-Object System.Diagnostics.ProcessStartInfo
        $start.FileName = $env:ComSpec
        $start.Arguments = '/d /c korean-law-setup.cmd'
        $start.WorkingDirectory = $temp
        $start.UseShellExecute = $false
        $start.RedirectStandardInput = $true
        $start.RedirectStandardOutput = $true
        $start.RedirectStandardError = $true
        $process = [System.Diagnostics.Process]::Start($start)
        $process.StandardInput.Close()
        if (-not $process.WaitForExit(15000)) {
            $process.Kill()
            throw "Menu hung for selection $selection"
        }
        if ($process.ExitCode -ne 0) { throw "Menu failed for selection $selection" }
        if ($selection -eq 4) {
            if (Test-Path $env:JURI_TEST_LOG) { throw 'Quit started configuration' }
        } else {
            $expected = '-3|scripts\configure_korean_law.py'
            if ($selection -eq 1) { $expected += '|--install' }
            if ($selection -eq 3) { $expected += '|--check' }
            $actual = (Get-Content $env:JURI_TEST_LOG -Raw).Trim()
            if ($actual -ne $expected) { throw "Wrong command for selection $selection : $actual" }
        }
        $process.Dispose()
    }
    Remove-Item $env:JURI_TEST_LOG -ErrorAction SilentlyContinue
    $start.Arguments = '/d /c credentials-setup.cmd'
    $process = [System.Diagnostics.Process]::Start($start)
    $process.StandardInput.Close()
    if (-not $process.WaitForExit(15000)) { $process.Kill(); throw 'Credential chooser launcher hung' }
    if ($process.ExitCode -ne 0) { throw 'Credential chooser launcher failed' }
    $actual = (Get-Content $env:JURI_TEST_LOG -Raw).Trim()
    if ($actual -ne '-3|scripts\configure_credentials.py') { throw 'Incorrect credential chooser command' }
    $process.Dispose()
    Write-Output 'ok - Windows setup menu install, popup, check and quit with space-containing path'
} finally {
    $env:PATH = $oldPath
    Remove-Item Env:JURI_TEST_LOG, Env:JURI_TEST_CHOICE_STATE, Env:JURI_TEST_CHOICE -ErrorAction SilentlyContinue
    Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue
}
