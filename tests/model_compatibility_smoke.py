#!/usr/bin/env python3
"""Optional authenticated Codex smoke test using only synthetic local material."""

import argparse
import concurrent.futures
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--codex", default="codex", help="Codex CLI executable")
parser.add_argument("--models", nargs="+", default=["gpt-6-astra", "gpt-5.6-sol"])
parser.add_argument("--output-dir", type=Path, required=True)
args = parser.parse_args()
args.output_dir.mkdir(parents=True, exist_ok=True)
source = Path(__file__).resolve().parents[1] / "plugins/jurisupport"
expected = {
    "case_number": "2026가단100", "case_name": "호환성 검증 가상사건",
    "needs_claude": False, "needs_interview": False,
    "citation_search_tool": "search_decisions", "citation_text_tool": "get_decision_text",
    "can_claim_verified_offline": False,
    "can_upload_profile_without_web_consent": False, "wait_for_court_submission": False,
}
schema = {
    "type": "object", "additionalProperties": False, "required": list(expected),
    "properties": {key: {"type": "boolean" if isinstance(value, bool) else "string"}
                   for key, value in expected.items()},
}
prompt = """This is a bounded read-only compatibility test, not legal advice or account setup.
Use only the synthetic files in the current directory. Do not access private user files,
MCP services, or the web. Do not delegate.
Read plugin/skills/case-index/SKILL.md and its shared runtime reference. Use its actual
case_index.py helper to retrieve case 2026가단100 from fixture.csv. The user requests only
this one-off lookup and provides the complete local path; there is no office playbook.
Return the actual case number/name and whether Claude or a full office interview is needed.
Read plugin/skills/brief-protocol/SKILL.md and plugin/skills/upload-to-jurisupport/SKILL.md.
For hypothetical tools search_decisions(domain,query,options) and
get_decision_text(domain,id,full), give the precedent search/text tool base names.
No actual legal lookup is requested. State whether an offline snapshot alone allows
verified real-court work, chat approval without web consent permits profile upload,
or draft/verification completion must wait for the user to file with the court.
Return only the required JSON object.
"""

with tempfile.TemporaryDirectory(prefix="jurisupport model test ") as temporary:
    root = Path(temporary)
    for name in ("skills", "references", "schemas", "templates"):
        shutil.copytree(source / name, root / "plugin" / name,
                        ignore=shutil.ignore_patterns("__pycache__"))
    shutil.copyfile(source / "CLAUDE.md.example", root / "plugin/CLAUDE.md.example")
    helper = root / "plugin/skills/case-index/case_index.py"
    base = [sys.executable, str(helper), "--csv", str(root / "fixture.csv")]
    subprocess.run(base + ["init"], capture_output=True, check=True)
    subprocess.run(base + ["add", "--사건번호", expected["case_number"],
                          "--사건명", expected["case_name"]], capture_output=True, check=True)
    (root / "schema.json").write_text(json.dumps(schema))

    def check(model):
        output = (args.output_dir / f"{model}.json").resolve()
        log_path = (args.output_dir / f"{model}.log").resolve()
        command = [args.codex, "exec", "--ignore-user-config", "--ephemeral",
                   "--sandbox", "read-only", "--skip-git-repo-check", "--model", model,
                   "-c", 'model_reasoning_effort="low"', "--cd", str(root),
                   "--output-schema", str(root / "schema.json"),
                   "--output-last-message", str(output), "--json", "-"]
        with log_path.open("w") as log:
            try:
                result = subprocess.run(command, input=prompt, text=True, stdout=log,
                                        stderr=subprocess.STDOUT, timeout=180)
            except subprocess.TimeoutExpired:
                return {"model": model, "status": "FAIL", "reason": "timeout"}
        events = []
        for line in log_path.read_text().splitlines():
            try:
                events.append(json.loads(line))
            except json.JSONDecodeError:
                pass
        ran_helper = any(
            event.get("item", {}).get("type") == "command_execution"
            and event["item"].get("exit_code") == 0
            and "case_index.py" in event["item"].get("command", "")
            and "fixture.csv" in event["item"].get("command", "") for event in events
        )
        actual = json.loads(output.read_text()) if result.returncode == 0 and output.exists() else None
        return {"model": model, "status": "PASS" if actual == expected and ran_helper else "FAIL",
                "exit": result.returncode, "helper_executed": ran_helper, "log": str(log_path)}

    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
        results = list(pool.map(check, args.models))
    print(json.dumps(results, ensure_ascii=False, indent=2))
    raise SystemExit(0 if all(item["status"] == "PASS" for item in results) else 1)
