#!/usr/bin/env python3
"""Collect OC in a native dialog and send it directly to Claude's config stdin."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

from credential_dialog import ask_secret

PLUGIN = "korean-law@korean-law-marketplace"


def find_claude():
    executable = shutil.which("claude")
    if executable or sys.platform != "win32":
        return executable
    local_app_data = os.environ.get("LOCALAPPDATA")
    if not local_app_data:
        return None
    root = Path(local_app_data) / "Claude-Data"
    candidates = [p for p in root.glob("*/claude-code/*/*/claude.exe") if p.is_file()]
    if not candidates:
        return None
    # Prefer the running app's CLI over an old or unrelated organization bundle.
    try:
        result = subprocess.run(
            ["powershell.exe", "-NoProfile", "-Command",
             "[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false); "
             "@(Get-Process -Name claude -ErrorAction SilentlyContinue | "
             "Select-Object -ExpandProperty Path -Unique) | ConvertTo-Json -Compress"],
            capture_output=True, text=True, encoding="utf-8", timeout=10,
        )
        running = json.loads(result.stdout) if result.returncode == 0 and result.stdout.strip() else []
        if isinstance(running, str):
            running = [running]
        active = [p for p in candidates if isinstance(running, list) and
                  any(str(p).casefold() == str(value).casefold() for value in running)]
        if len(active) == 1:
            return str(active[0])
        if len(active) > 1:
            raise ValueError("Multiple active Claude bundles")
    except (OSError, UnicodeError, subprocess.SubprocessError, json.JSONDecodeError):
        pass
    if len(candidates) == 1:
        return str(candidates[0])
    if len({p.relative_to(root).parts[0] for p in candidates}) != 1:
        raise ValueError("Multiple Claude organizations")
    versions = [(tuple(map(int, p.parents[1].name.split("."))), p) for p in candidates
                if re.fullmatch(r"\d+\.\d+\.\d+", p.parents[1].name)]
    if len(versions) != len(candidates):
        raise ValueError("Unknown Claude version")
    newest = max(version for version, _ in versions)
    matches = [p for version, p in versions if version == newest]
    if len(matches) != 1:
        raise ValueError("Ambiguous Claude bundle")
    return str(matches[0])


def cli_json(claude, *arguments):
    result = subprocess.run([claude, *arguments, "--json"], capture_output=True,
                            text=True, encoding="utf-8", timeout=30)
    if result.returncode:
        raise ValueError("CLI query failed")
    return json.loads(result.stdout)


def check_configuration(claude):
    try:
        data = cli_json(claude, "plugin", "configure", PLUGIN)
        configured = data.get("configured")
        unconfigured = data.get("unconfigured")
        if not isinstance(configured, list) or not isinstance(unconfigured, list):
            raise ValueError("Unknown configuration response")
        if "api_key" in configured and "api_key" not in unconfigured:
            print("OC 설정: 저장됨. 실제 MCP 조회와 본인 한도 사용 여부는 별도 확인이 필요합니다.")
            return 0
        if "api_key" in unconfigured and "api_key" not in configured:
            print("OC 설정: 미설정. 입력창에서 등록하세요.")
            return 2
        raise ValueError("OC configuration state unknown")
    except (OSError, UnicodeError, subprocess.SubprocessError, ValueError, AttributeError):
        print("OC 설정 상태를 확인하지 못했습니다. CLI의 플러그인 설정 화면을 확인하세요. 값은 출력하지 않습니다.")
        return 1


def install_plugin(claude):
    try:
        marketplaces = cli_json(claude, "plugin", "marketplace", "list")
        plugins = cli_json(claude, "plugin", "list")
        if not isinstance(marketplaces, list) or not isinstance(plugins, list):
            raise ValueError("Unknown CLI response")
        market = next((p for p in marketplaces if p.get("name") == "korean-law-marketplace"), None)
        if market is not None:
            source = market.get("repo") or market.get("url")
            if source not in ("chrisryugj/korean-law-mcp", "https://github.com/chrisryugj/korean-law-mcp",
                              "https://github.com/chrisryugj/korean-law-mcp.git"):
                print("기존 korean-law 마켓플레이스 출처를 앱에서 확인하세요. 등록을 변경하지 않았습니다.")
                return 1
        else:
            result = subprocess.run([claude, "plugin", "marketplace", "add",
                                     "https://github.com/chrisryugj/korean-law-mcp.git"])
            if result.returncode:
                return 1
        existing = next((p for p in plugins if p.get("id") == PLUGIN), None)
        if existing:
            print("korean-law 플러그인이 이미 설치되어 있습니다. 활성 상태와 OC 설정을 확인하세요.")
            return 0
        capability = subprocess.run([claude, "plugin", "install", "--help"],
                                    capture_output=True, text=True, encoding="utf-8", timeout=30)
        if capability.returncode or "--config" not in capability.stdout:
            print("이 CLI에서는 앱의 플러그인 화면으로 설치한 뒤 보호 입력창으로 OC를 등록하세요.")
            return 1
        result = subprocess.run([claude, "plugin", "install", PLUGIN, "--scope", "user", "--config", "api_key="])
        if result.returncode:
            return 1
        print("플러그인 설치 명령이 성공했습니다. OC 입력창에서 설정하고 새 세션에서 조회를 확인하세요.")
        return 0
    except (OSError, UnicodeError, subprocess.SubprocessError, ValueError, AttributeError):
        print("플러그인 설치 상태를 확인하지 못했습니다. 앱의 플러그인 화면에서 설치를 진행하세요.")
        return 1


def ask_oc():
    return ask_secret("JuriSupport · korean-law 설정",
                      "법제처 OC를 입력하세요. Claude 플러그인 설정에 저장됩니다. 채팅에는 표시하지 않습니다.")


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
            [claude, "plugin", "configure", PLUGIN, "--values-stdin"],
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
    parser.add_argument("--claude", help="Claude CLI 실행 파일 경로 (생략 시 자동 탐색)")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--install", action="store_true", help="korean-law 플러그인 설치")
    mode.add_argument("--check", action="store_true", help="OC 설정 여부만 확인 (값은 출력하지 않음)")
    args = parser.parse_args()
    try:
        claude = args.claude or find_claude()
    except ValueError:
        print("여러 Claude 설치본이 있어 자동 선택하지 않았습니다. 사용할 앱의 경로를 --claude로 지정하세요.")
        return 1
    if not claude:
        print("Claude CLI를 찾지 못했습니다. --claude로 확인한 실행 파일 경로를 지정하세요.")
        return 1
    if args.install:
        return install_plugin(claude)
    if args.check:
        return check_configuration(claude)
    return configure(claude)


if __name__ == "__main__":
    sys.exit(main())
