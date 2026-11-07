#!/usr/bin/env python3
"""Collect OC in a native dialog and send it directly to Claude's config stdin."""

import argparse
import json
import shutil
import subprocess
import sys


def ask_oc():
    if sys.platform == "darwin":
        command = ["osascript", "-e", '''
try
    set answer to display dialog "법제처 OC를 입력하세요. 값은 이 컴퓨터의 Claude 플러그인 설정에 저장됩니다. 채팅에는 표시하지 않습니다." default answer "" with hidden answer buttons {"취소", "등록"} default button "등록" cancel button "취소" with title "JuriSupport · korean-law 설정"
    return text returned of answer
on error number -128
    return ""
end try
''']
    elif sys.platform == "win32":
        command = ["powershell.exe", "-NoProfile", "-STA", "-Command", '''
Add-Type -AssemblyName System.Windows.Forms
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$form = New-Object System.Windows.Forms.Form
$form.Text = 'JuriSupport · korean-law 설정'
$form.ClientSize = New-Object System.Drawing.Size(440, 150)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$label = New-Object System.Windows.Forms.Label
$label.Text = "법제처 OC를 입력하세요. 이 컴퓨터의 Claude 설정에 저장됩니다.`n입력값은 채팅에 표시하지 않습니다."
$label.SetBounds(16, 16, 408, 40)
$inputBox = New-Object System.Windows.Forms.TextBox
$inputBox.UseSystemPasswordChar = $true
$inputBox.SetBounds(16, 62, 408, 24)
$ok = New-Object System.Windows.Forms.Button
$ok.Text = '등록'
$ok.SetBounds(250, 104, 80, 28)
$ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
$cancel = New-Object System.Windows.Forms.Button
$cancel.Text = '취소'
$cancel.SetBounds(344, 104, 80, 28)
$cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.AddRange(@($label, $inputBox, $ok, $cancel))
$form.AcceptButton = $ok
$form.CancelButton = $cancel
if ($form.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::Write($inputBox.Text)
}
$inputBox.Clear()
$form.Dispose()
''']
    else:
        raise OSError("Native dialog unavailable")
    result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8")
    if result.returncode:
        raise OSError("Dialog failed")
    return result.stdout.rstrip("\r\n")


def configure(claude, prompt=ask_oc):
    try:
        help_result = subprocess.run(
            [claude, "plugin", "configure", "--help"],
            capture_output=True, text=True, encoding="utf-8", timeout=30,
        )
        if help_result.returncode or "--values-stdin" not in help_result.stdout:
            print("이 Claude CLI는 보호된 설정 입력을 지원하지 않습니다. 최신 CLI 또는 플러그인 설정 화면을 사용하세요.")
            return 1
        key = prompt()
        if not key:
            print("입력이 취소되었거나 비어 있습니다. 설정을 변경하지 않았습니다.")
            return 2
        if not key.strip() or any(c in key for c in "\r\n\0"):
            print("OC는 비어 있지 않은 한 줄 값이어야 합니다. 설정을 변경하지 않았습니다.")
            return 1
        result = subprocess.run(
            [claude, "plugin", "configure", "korean-law@korean-law-marketplace", "--values-stdin"],
            input=json.dumps({"api_key": key}),
            capture_output=True, text=True, encoding="utf-8", timeout=60,
        )
        # Never echo child output: even a failed CLI may include the supplied key.
        if result.returncode:
            print("OC 등록을 확인하지 못했습니다. 플러그인 설치·설정 상태를 확인하세요. 입력값은 출력하지 않습니다.")
            return 1
        print("OC 설정 저장 요청이 성공했습니다. 플러그인을 다시 로드하고 실제 법령 조회를 확인하세요.")
        return 0
    except (OSError, UnicodeError, subprocess.SubprocessError):
        print("입력창 또는 설정 명령을 실행하지 못했습니다. 로컬 데스크톱과 Claude 실행 경로를 확인하세요.")
        return 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--claude", default=shutil.which("claude"), help="Claude CLI 실행 파일 경로")
    args = parser.parse_args()
    if not args.claude:
        print("Claude CLI를 찾지 못했습니다. --claude로 확인한 실행 파일 경로를 지정하세요.")
        return 1
    return configure(args.claude)


if __name__ == "__main__":
    sys.exit(main())
