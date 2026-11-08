"""Native credential entry. Values stay in this local process, never the agent output."""
import json
import shutil
import subprocess
import sys


def native_input(title, message, choices=None):
    if sys.platform == "darwin":
        action = ('choose from list {' + ', '.join(json.dumps(s, ensure_ascii=False) for s in choices) +
                  '} with title __TITLE__ with prompt __MESSAGE__\n'
                  'if answer is false then return ""\nreturn item 1 of answer') if choices else (
                  'display dialog __MESSAGE__ default answer "" with hidden answer '
                  'buttons {"취소", "등록"} default button "등록" cancel button "취소" '
                  'with title __TITLE__\nreturn text returned of answer')
        source = 'try\nset answer to ' + action + '\non error number -128\nreturn ""\nend try'
        source = source.replace('__TITLE__', json.dumps(title, ensure_ascii=False)).replace(
            '__MESSAGE__', json.dumps(message, ensure_ascii=False))
        command = ["osascript", "-e", source]
    elif sys.platform == "win32":
        def literal(value):
            return "'" + value.replace("'", "''") + "'"

        control = '''$inputBox = New-Object System.Windows.Forms.TextBox
$inputBox.UseSystemPasswordChar = $true'''
        read_value = '$inputBox.Text'
        if choices:
            control = '''$inputBox = New-Object System.Windows.Forms.ComboBox
$inputBox.DropDownStyle = 'DropDownList'
$inputBox.Items.AddRange([object[]]@(''' + ','.join(map(literal, choices)) + '''))
$inputBox.SelectedIndex = 0'''
            read_value = '$inputBox.SelectedItem'
        source = '''Add-Type -AssemblyName System.Windows.Forms
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
$form = New-Object System.Windows.Forms.Form
$form.Text = __TITLE__
$form.ClientSize = New-Object System.Drawing.Size(520, 200)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
$label = New-Object System.Windows.Forms.Label
$label.Text = __MESSAGE__
$label.SetBounds(16, 16, 488, 90)
__CONTROL__
$inputBox.SetBounds(16, 112, 488, 24)
$ok = New-Object System.Windows.Forms.Button
$ok.Text = '확인'
$ok.SetBounds(330, 156, 80, 28)
$ok.DialogResult = [System.Windows.Forms.DialogResult]::OK
$cancel = New-Object System.Windows.Forms.Button
$cancel.Text = '취소'
$cancel.SetBounds(424, 156, 80, 28)
$cancel.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$form.Controls.AddRange(@($label, $inputBox, $ok, $cancel))
$form.AcceptButton = $ok
$form.CancelButton = $cancel
if ($form.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    [Console]::Write(__VALUE__)
}
$inputBox.Text = ''
$form.Dispose()
'''
        source = source.replace('__TITLE__', literal(title)).replace('__MESSAGE__', literal(message))
        source = source.replace('__CONTROL__', control).replace('__VALUE__', read_value)
        command = ["powershell.exe", "-NoProfile", "-STA", "-Command", source]
    elif shutil.which("zenity"):
        command = ["zenity", "--title", title, "--text", message]
        command += (["--list", "--column", "서비스", *choices] if choices else ["--password"])
    else:
        raise OSError("No supported graphical input")
    result = subprocess.run(command, capture_output=True, text=True, encoding="utf-8")
    if result.returncode:
        # Zenity returns 1 for cancel; never fall back to a terminal secret prompt.
        if command[0] == "zenity" and result.returncode == 1:
            return ""
        raise OSError("Dialog failed")
    return result.stdout.rstrip("\r\n")


def ask_secret(title, message):
    return native_input(title, message)
