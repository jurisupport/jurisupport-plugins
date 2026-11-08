#!/usr/bin/env python3
"""Register supported credentials through native UI, returning status only."""
import argparse
import base64
import json
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
import webbrowser

from credential_dialog import ask_secret, native_input
import configure_korean_law as korean_law

SERVICES = {
    "jurisupport": "JuriSupport MCP 토큰 (Claude)",
    "korean-law": "korean-law 플러그인 OC",
    "law-forms": "법령·법원 서식 OC",
    "gemini": "Gemini API 키 (서적·사건 검색 공용)",
    "case-records": "사건 검색 로컬 API 토큰 교체",
    "ecourt-cert": "Windows 전자소송 인증서 암호",
    "ecourt-telegram": "Windows 전자소송 Telegram 토큰",
    "ecfs-cert": "macOS 전자소송 인증서 암호",
    "ecfs-gmail": "macOS 전자소송 Gmail 앱 비밀번호",
    "telegram": "Claude Telegram 봇 토큰",
    "law-login": "법제처 로그인·비밀번호 (공식 브라우저)",
    "jurisupport-login": "JuriSupport 로그인·비밀번호 (공식 브라우저)",
}
LOGIN_URLS = {"law-login": "https://open.law.go.kr/LSO/login.do",
              "jurisupport-login": "https://jurisupport.com"}


def claude_root():
    return Path(os.environ.get("CLAUDE_CONFIG_DIR", str(Path.home() / ".claude"))).expanduser()


def target_file(service):
    home = Path.home()
    if service == "jurisupport":
        return claude_root() / ".claude.json" if os.environ.get("CLAUDE_CONFIG_DIR") else home / ".claude.json"
    if service == "law-forms":
        return Path(os.environ.get("LAW_FORMS_HOME", str(home / "law-forms"))).expanduser() / "config.json"
    if service == "gemini":
        return home / ".jurisupport/secrets.env"
    if service == "case-records":
        return home / ".jurisupport/case-records.token"
    if service.startswith("ecourt-"):
        return home / "ecourt-cli/.env"
    if service.startswith("ecfs-"):
        return home / ".config/k-skill/secrets.env"
    if service == "telegram":
        return claude_root() / "channels/telegram/.env"
    raise ValueError("Unknown destination")


def read_existing(path):
    if path.is_symlink():
        raise ValueError("Symlink destination")
    return path.read_bytes() if path.exists() else None


def write_private(path, text, original):
    path.parent.mkdir(parents=True, exist_ok=True, mode=0o700)
    fd, name = tempfile.mkstemp(prefix=".juri-", dir=path.parent)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(text.encode("utf-8"))
            stream.flush()
            os.fsync(stream.fileno())
        if read_existing(path) != original:
            raise ValueError("Configuration changed")
        if original is not None:
            backup_fd, _ = tempfile.mkstemp(prefix=f".{path.name}.backup-", dir=path.parent)
            with os.fdopen(backup_fd, "wb") as backup:
                backup.write(original)
        if read_existing(path) != original:
            raise ValueError("Configuration changed")
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def env_value(text, key):
    matches = re.findall(r"^[ \t]*(?:export[ \t]+)?" + re.escape(key) + r"[ \t]*=[ \t]*([^\r\n]*)\r?$", text, re.M)
    if not matches:
        return ""
    parts = shlex.split(matches[-1], comments=True)
    return parts[0] if len(parts) == 1 else ""


def replace_env(text, key, value, remove=()):
    names = (key, *remove)
    pattern = r"^[ \t]*(?:export[ \t]+)?(?:" + "|".join(map(re.escape, names)) + r")[ \t]*="
    lines = []
    for line in text.splitlines():
        if re.match(pattern, line):
            # Reject multiline quoted assignments rather than leaving orphaned lines.
            shlex.split(line.split("=", 1)[1], comments=True)
        else:
            lines.append(line)
    return "\n".join([*lines, f"{key}={value}", ""])


def field_name(service):
    return {"gemini": "GEMINI_API_KEY", "telegram": "TELEGRAM_BOT_TOKEN",
            "ecourt-cert": "ECFS_CERT_PW", "ecourt-telegram": "TELEGRAM_BOT_TOKEN",
            "ecfs-cert": "ECFS_CERT_PW", "ecfs-gmail": "GMAIL_APP_PW"}[service]


def prerequisites(service, path):
    if service.startswith("ecourt-"):
        if sys.platform != "win32" or not (path.parent / "secret_store.py").is_file():
            raise ValueError("Install ecourt on Windows first")
    if service.startswith("ecfs-"):
        key = path.parent / "age/keys.txt"
        if sys.platform != "darwin" or not path.is_file() or not key.is_file() or not shutil.which("sops"):
            raise ValueError("Set up ecfs encrypted vault first")
    if service == "telegram" and not path.parent.is_dir():
        raise ValueError("Install Telegram channel first")


def save_secret(service, value, path, original):
    text = original.decode("utf-8-sig") if original is not None else ""
    if service in ("jurisupport", "law-forms"):
        data = json.loads(text) if text else {}
        if not isinstance(data, dict):
            raise ValueError("Invalid configuration")
        if service == "law-forms":
            data["LAW_OC"] = value
        else:
            servers = data.setdefault("mcpServers", {})
            if not isinstance(servers, dict):
                raise ValueError("Invalid MCP settings")
            server = servers.setdefault("jurisupport", {"type": "http", "url": "https://api.jurisupport.com/mcp"})
            if (not isinstance(server, dict) or server.get("url") != "https://api.jurisupport.com/mcp"
                    or server.get("type") not in ("http", "sse")):
                raise ValueError("Existing server differs")
            headers = server.setdefault("headers", {})
            if not isinstance(headers, dict):
                raise ValueError("Invalid headers")
            for key in list(headers):
                if key.lower() == "authorization":
                    del headers[key]
            headers["Authorization"] = "Bearer " + value
        write_private(path, json.dumps(data, ensure_ascii=False, indent=2) + "\n", original)
    elif service.startswith("ecfs-"):
        environment = dict(os.environ, SOPS_AGE_KEY_FILE=str(path.parent / "age/keys.txt"))
        result = subprocess.run(
            [shutil.which("sops"), "set", "--input-type", "dotenv", "--output-type", "dotenv",
             "--value-stdin", str(path), json.dumps([field_name(service)])],
            input=json.dumps(value), text=True, encoding="utf-8", capture_output=True, env=environment, timeout=30,
        )
        if result.returncode:
            raise ValueError("Encrypted update failed")
    elif service.startswith("ecourt-"):
        python = path.parent / ".venv/Scripts/python.exe"
        result = subprocess.run(
            [str(python) if python.exists() else sys.executable, str(path.parent / "secret_store.py"), "encrypt"],
            input=value, text=True, encoding="utf-8", capture_output=True, timeout=30,
        )
        encrypted = result.stdout.strip()
        if result.returncode or not encrypted:
            raise ValueError("Encryption failed")
        base64.b64decode(encrypted, validate=True)
        field = field_name(service)
        write_private(path, replace_env(text, field + "_ENC", encrypted, remove=(field,)), original)
    elif service in ("gemini", "telegram"):
        pattern = r"[A-Za-z0-9_-]+" if service == "gemini" else r"[0-9]+:[A-Za-z0-9_-]+"
        if not re.fullmatch(pattern, value):
            raise ValueError("Invalid key format")
        write_private(path, replace_env(text, field_name(service), value), original)
    elif service == "case-records":
        write_private(path, value + "\n", original)


def is_set(service, path, original):
    text = original.decode("utf-8-sig") if original is not None else ""
    if service == "jurisupport":
        data = json.loads(text) if text else {}
        server = data.get("mcpServers", {}).get("jurisupport", {})
        return (server.get("url") == "https://api.jurisupport.com/mcp" and
                any(k.lower() == "authorization" and bool(v) for k, v in server.get("headers", {}).items()))
    if service == "law-forms":
        return bool(json.loads(text).get("LAW_OC")) if text else False
    if service == "case-records":
        return bool(text.strip())
    field = field_name(service)
    if service.startswith("ecourt-"):
        field += "_ENC"
    value = env_value(text, field)
    if service == "gemini":
        return bool(re.fullmatch(r"[A-Za-z0-9_-]+", value))
    return bool(value)


def configure_service(service, check=False, claude=None, prompt=ask_secret):
    service = "gemini" if service == "legal-books" else service
    try:
        if service in LOGIN_URLS:
            if check:
                print("웹사이트 로그인 상태는 공식 브라우저에서 확인해야 합니다. 비밀번호를 별도로 보관하지 않습니다.")
                return 2
            if not webbrowser.open(LOGIN_URLS[service], new=2):
                raise OSError("Browser unavailable")
            print("공식 로그인 화면을 열었습니다. 비밀번호는 그 화면에 입력하세요. 로그인 성공은 별도 확인하세요.")
            return 0
        if service == "korean-law":
            executable = claude or korean_law.find_claude()
            if not executable:
                raise ValueError("Claude unavailable")
            return korean_law.check_configuration(executable) if check else korean_law.configure(executable)
        path = target_file(service)
        original = read_existing(path)
        if check:
            saved = is_set(service, path, original)
            print("등록 상태: " + ("설정 있음" if saved else "미설정") + ". 실제 인증·연결 성공과는 별개입니다.")
            return 0 if saved else 2
        prerequisites(service, path)
        storage = "기존 도구의 암호화 저장소" if service.startswith(("ecourt-", "ecfs-")) else "기존 앱의 로컬 설정 파일 (평문 형식)"
        value = prompt(SERVICES[service], storage + "에 등록·교체합니다.\n취소하면 기존 값을 유지합니다. 채팅에는 값을 표시하지 않습니다.")
        if not value:
            print("입력을 취소했습니다. 기존 설정을 유지합니다.")
            return 2
        if not value.strip() or any(ord(c) < 32 or ord(c) == 127 for c in value):
            raise ValueError("Single-line value required")
        # A dialog can stay open while Claude updates unrelated settings.
        original = read_existing(path)
        save_secret(service, value, path, original)
        print("설정을 저장했습니다. 해당 앱·서버를 다시 열고 실제 연결을 확인하세요. 값은 출력하지 않습니다.")
        override = {"law-forms": "LAW_OC", "gemini": "GEMINI_API_KEY", "case-records": "CASE_RECORDS_API_TOKEN"}.get(service)
        if override and os.environ.get(override):
            print("현재 실행 환경에 별도 인증값이 있어 파일보다 우선할 수 있습니다. 앱의 환경 설정도 확인하세요.")
        if service == "jurisupport":
            print("Claude 사용자 범위에 저장했습니다. 폴더별 같은 서버 설정이 있으면 그 설정이 우선할 수 있습니다.")
        return 0
    except (OSError, UnicodeError, ValueError, TypeError, AttributeError, subprocess.SubprocessError):
        print("등록을 완료하지 못했습니다. 대상 도구 설치·설정 형식·입력값·권한을 확인하세요. 비밀값과 오류 원문은 출력하지 않습니다.")
        return 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--service", choices=[*SERVICES, "legal-books"])
    parser.add_argument("--check", action="store_true", help="값 없이 등록 상태만 확인")
    parser.add_argument("--claude", help="korean-law용 Claude 실행 파일")
    args = parser.parse_args()
    service = args.service
    if not service:
        try:
            selected = native_input("JuriSupport · 인증정보 등록", "등록할 서비스를 선택하세요.", list(SERVICES.values()))
            service = next((key for key, label in SERVICES.items() if label == selected), None)
        except (OSError, UnicodeError, subprocess.SubprocessError):
            print("입력창을 열지 못했습니다. 로컬 데스크톱에서 실행하세요. 비밀값을 채팅이나 터미널에 입력하지 마세요.")
            return 1
        if not service:
            return 2
    return configure_service(service, args.check, args.claude)


if __name__ == "__main__":
    sys.exit(main())
