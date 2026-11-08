"""No real keys, GUI interaction, or user settings are used by these tests."""
import contextlib
import importlib.util
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))

spec = importlib.util.spec_from_file_location(
    "configure_korean_law", Path(__file__).resolve().parents[1] / "scripts/configure_korean_law.py"
)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class ConfigureTest(unittest.TestCase):
    def test_cli_explicit_path_wins_without_discovery(self):
        with patch.object(helper.sys, "argv", ["helper", "--claude", "/chosen/claude", "--check"]), \
                patch.object(helper, "find_claude") as discover, \
                patch.object(helper, "check_configuration", return_value=0) as check:
            self.assertEqual(helper.main(), 0)
        discover.assert_not_called()
        check.assert_called_once_with("/chosen/claude")

    def test_cli_on_path_wins_over_desktop_search(self):
        with patch.object(helper.shutil, "which", return_value="/path/claude"), \
                patch.object(helper.subprocess, "run") as run:
            self.assertEqual(helper.find_claude(), "/path/claude")
        run.assert_not_called()

    def test_bundled_cli_selection(self):
        with tempfile.TemporaryDirectory(prefix="claude bundles ") as tmp:
            root = Path(tmp) / "Claude-Data"

            def bundle(org, version, digest="hash"):
                path = root / org / "claude-code" / version / digest / "claude.exe"
                path.parent.mkdir(parents=True, exist_ok=True)
                path.touch()
                return path

            with patch.object(helper.sys, "platform", "win32"), \
                    patch.object(helper.shutil, "which", return_value=None), \
                    patch.dict(os.environ, {"LOCALAPPDATA": tmp}), \
                    patch.object(helper.subprocess, "run", return_value=
                                 subprocess.CompletedProcess([], 0, "[]", "")) as run:
                self.assertIsNone(helper.find_claude())
                old = bundle("org-a", "2.1.9")
                self.assertEqual(helper.find_claude(), str(old))
                newest = bundle("org-a", "2.1.317")
                self.assertEqual(helper.find_claude(), str(newest))
                run.return_value.stdout = json.dumps([str(old)])
                self.assertEqual(helper.find_claude(), str(old))
                other = bundle("org-b", "2.1.400")
                self.assertEqual(helper.find_claude(), str(old))
                run.return_value.stdout = json.dumps([str(old), str(other)])
                with self.assertRaises(ValueError):
                    helper.find_claude()
                run.return_value.stdout = "[]"
                with self.assertRaises(ValueError):
                    helper.find_claude()

    def test_key_state_uses_metadata_and_never_prints_values(self):
        for configured, unconfigured, status in [(["api_key"], [], 0), ([], ["api_key"], 2), ([], [], 1)]:
            data = {"configured": configured, "unconfigured": unconfigured,
                    "inputs": {"api_key": "TEST_ONLY_SECRET"}}
            with self.subTest(status=status), patch.object(helper, "cli_json", return_value=data), \
                    contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(helper.check_configuration("cli"), status)
            self.assertNotIn("TEST_ONLY_SECRET", output.getvalue())

    def test_state_query_failure_does_not_print_cli_exception(self):
        with patch.object(helper, "cli_json", side_effect=ValueError("TEST_ONLY_SECRET")), \
                contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(helper.check_configuration("cli"), 1)
        self.assertNotIn("TEST_ONLY_SECRET", output.getvalue())

    def test_install_new_plugin_and_stop_if_marketplace_fails(self):
        for returncode in (0, 1):
            with self.subTest(returncode=returncode), \
                    patch.object(helper, "cli_json", side_effect=[[], []]), \
                    patch.object(helper.subprocess, "run", side_effect=[
                        subprocess.CompletedProcess([], returncode),
                        subprocess.CompletedProcess([], 0, "--config", ""),
                        subprocess.CompletedProcess([], 0),
                    ]) as run, \
                    contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(helper.install_plugin("cli"), returncode)
            self.assertEqual(run.call_count, 3 if returncode == 0 else 1)
            self.assertEqual(run.call_args_list[0].args[0], ["cli", "plugin", "marketplace", "add",
                             "https://github.com/chrisryugj/korean-law-mcp.git"])
            if not returncode:
                self.assertEqual(run.call_args.args[0], ["cli", "plugin", "install", helper.PLUGIN, "--scope", "user", "--config", "api_key="])

    def test_existing_install_is_not_replaced(self):
        market = {"name": "korean-law-marketplace", "repo": "chrisryugj/korean-law-mcp"}
        with patch.object(helper, "cli_json", side_effect=[[market], [{"id": helper.PLUGIN}]]), \
                patch.object(helper.subprocess, "run") as run, \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(helper.install_plugin("cli"), 0)
        run.assert_not_called()

    def test_foreign_marketplace_and_failed_inventory_never_install(self):
        foreign = [{"name": "korean-law-marketplace", "repo": "other/repo"}]
        for results in ([foreign, []], ValueError("list failed")):
            with patch.object(helper, "cli_json", side_effect=results), \
                    patch.object(helper.subprocess, "run") as run, \
                    contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(helper.install_plugin("cli"), 1)
            run.assert_not_called()

    def run_configure(self, key, final_result):
        output = io.StringIO()
        with patch.object(helper.subprocess, "run", side_effect=[
            subprocess.CompletedProcess([], 0, "--values-stdin", ""), final_result,
        ]) as run, contextlib.redirect_stdout(output):
            status = helper.configure("/fake/claude", prompt=lambda: key)
        return status, output.getvalue(), run

    def test_key_uses_stdin_and_child_output_is_hidden(self):
        key = 'TEST_ONLY_OC_"한글"'
        for code in (0, 1):
            with self.subTest(code=code):
                status, output, run = self.run_configure(
                    key, subprocess.CompletedProcess([], code, key, key)
                )
                self.assertEqual(status, code)
                call = run.call_args
                self.assertEqual(json.loads(call.kwargs["input"]), {"api_key": key})
                self.assertNotIn(key, str(call.args))
                self.assertNotIn(key, output)
                self.assertTrue(call.kwargs["capture_output"])

    def test_cancel_and_invalid_values_never_configure(self):
        for key in ("", " ", "line\nbreak", "line\rbreak", "null\0byte"):
            with self.subTest(key=repr(key)):
                status, _, run = self.run_configure(key, None)
                self.assertNotEqual(status, 0)
                self.assertEqual(run.call_count, 1)

    def test_timeout_does_not_print_secret(self):
        key = "TEST_ONLY_SECRET"
        status, output, _ = self.run_configure(
            key, subprocess.TimeoutExpired("cli", 60, output=key, stderr=key)
        )
        self.assertEqual(status, 1)
        self.assertNotIn(key, output)

    def test_unsupported_cli_does_not_prompt(self):
        prompt = Mock()
        with patch.object(helper.subprocess, "run", return_value=
                          subprocess.CompletedProcess([], 0, "old CLI", "")), \
                contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(helper.configure("cli", prompt), 1)
        prompt.assert_not_called()

    def test_native_dialog_values_stay_inside_helper(self):
        for platform in ("darwin", "win32"):
            with self.subTest(platform=platform), patch.object(helper.sys, "platform", platform), \
                    patch.object(helper.subprocess, "run", return_value=
                                 subprocess.CompletedProcess([], 0, "TEST_ONLY_OC\n", "")) as run:
                self.assertEqual(helper.ask_oc(), "TEST_ONLY_OC")
                self.assertTrue(run.call_args.kwargs["capture_output"])
                self.assertNotIn("TEST_ONLY_OC", str(run.call_args.args))

    @unittest.skipUnless(sys.platform in ("darwin", "win32"), "Native desktop dialog")
    def test_native_dialog_source_without_showing_a_window(self):
        with patch.object(helper.subprocess, "run", return_value=
                          subprocess.CompletedProcess([], 0, "", "")) as run:
            helper.ask_oc()
            command = run.call_args.args[0]
        if sys.platform == "win32":
            # Build and dispose the real Windows form without waiting for input.
            command[-1] = command[-1].replace(
                "$form.ShowDialog()", "[System.Windows.Forms.DialogResult]::Cancel"
            )
            result = subprocess.run(command, capture_output=True, timeout=30)
        else:
            with tempfile.TemporaryDirectory() as tmp:
                source = Path(tmp) / "dialog.applescript"
                source.write_text(command[-1], encoding="utf-8")
                result = subprocess.run(
                    ["osacompile", "-o", str(Path(tmp) / "dialog.scpt"), str(source)],
                    capture_output=True, timeout=30,
                )
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
