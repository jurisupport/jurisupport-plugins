#!/usr/bin/env python3
"""Check the portable plugin package and run its helper outside a host cache."""

import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PLUGIN = ROOT / "plugins/jurisupport"
RUNTIME = PLUGIN / "references/runtime.md"

assert RUNTIME.is_file(), "shared Claude/Codex runtime contract is missing"
for host in ("claude", "codex"):
    manifest = json.loads((PLUGIN / f".{host}-plugin/plugin.json").read_text())
    assert manifest["name"] == PLUGIN.name
    assert (PLUGIN / manifest.get("skills", "skills")).is_dir()

skills = list((PLUGIN / "skills").glob("*/SKILL.md"))
assert len(skills) >= 8
for skill in skills:
    text = skill.read_text()
    assert "../../references/runtime.md" in text, f"runtime not loaded: {skill}"
    assert "AskUserQuestion" not in text, f"host-specific question tool: {skill}"
    assert not re.search(r"(?:~/|/Users/).*?\.claude/", text), f"Claude path required: {skill}"
    frontmatter = text.split("---", 2)[1]
    assert not re.search(r"^(model|effort|effortLevel):", frontmatter, re.M)
    for target in re.findall(r"\]\(([^)]+\.md)\)", text):
        if "://" not in target:
            resolved = (skill.parent / target).resolve()
            assert resolved.is_relative_to(PLUGIN.resolve()), f"reference escapes package: {target}"
            assert resolved.is_file(), f"broken packaged reference: {skill}: {target}"

runtime = RUNTIME.read_text()
assert 'domain="precedent"' in runtime
assert "search_decisions" in runtime and "get_decision_text" in runtime
assert "실제로" in runtime and "스키마" in runtime

cold_start = (PLUGIN / "skills/cold-start-interview/SKILL.md").read_text()
assert "로컬 CSV 경로" in cold_start and "Python 3" in cold_start
assert "CSV 경로로 자동 채택" not in cold_start
assert not re.search(r"onedrive:[^`\n]*_index\.csv", cold_start)

brief = (PLUGIN / "skills/brief-protocol/SKILL.md").read_text()
assert "search_decisions" in brief and "get_decision_text" in brief
assert "각 게이트에서" not in brief
assert '사용자가 "전자제출 완료" 알려줄 때' not in brief

# A plugin cache may live anywhere, contain spaces, and have no Claude install.
with tempfile.TemporaryDirectory(prefix="jurisupport codex only ") as tmp:
    cache = Path(tmp) / "plugin cache" / "jurisupport"
    shutil.copytree(PLUGIN / "skills/case-index", cache / "skills/case-index")
    helper = cache / "skills/case-index/case_index.py"
    csv = Path(tmp) / "사건 자료" / "_index.csv"
    csv.parent.mkdir()

    def run(*args):
        return subprocess.run(
            [sys.executable, str(helper), "--csv", str(csv), *args],
            cwd=tmp, text=True, capture_output=True, check=True,
        ).stdout

    run("init")
    run("add", "--사건번호", "2026가단100", "--사건명", "설치 검증용 가상사건")
    assert "2026가단100" in run("get", "2026가단100")
    assert csv.read_bytes().startswith(b"\xef\xbb\xbf")
    assert not (Path(tmp) / ".claude").exists()

print("Claude/Codex package and portable case-index checks passed")
