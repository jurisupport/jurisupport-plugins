"""No real keys, GUI interaction, or user settings are used by these tests."""
import contextlib
import importlib.util
import io
import json
from pathlib import Path
import subprocess
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location(
    "configure_korean_law", Path(__file__).resolve().parents[1] / "scripts/configure_korean_law.py"
)
helper = importlib.util.module_from_spec(spec)
spec.loader.exec_module(helper)


class ConfigureTest(unittest.TestCase):
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


if __name__ == "__main__":
    unittest.main()
