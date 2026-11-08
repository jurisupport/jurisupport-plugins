"""Synthetic-only credential persistence, cancellation and output boundaries."""
import base64
import contextlib
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
import configure_credentials as helper
import credential_dialog


class CredentialsTest(unittest.TestCase):
    def setUp(self):
        self.desktop_environment = dict(os.environ)
        self.temp = tempfile.TemporaryDirectory(prefix="juri-credentials-test-")
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        home = patch.object(helper.Path, "home", return_value=self.root)
        home.start()
        self.addCleanup(home.stop)
        environment = patch.dict(os.environ, {}, clear=True)
        environment.start()
        self.addCleanup(environment.stop)

    def run_service(self, service, secret="TEST_ONLY_SECRET", **kwargs):
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            status = helper.configure_service(service, prompt=lambda *args: secret, **kwargs)
        if secret.strip():
            self.assertNotIn(secret, output.getvalue())
        return status, output.getvalue()

    def seed(self, service, content):
        path = helper.target_file(service)
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")
        return path

    def test_jurisupport_preserves_other_settings_and_headers(self):
        data = {"theme": "dark", "projects": {"/sample": {}}, "mcpServers": {
            "other": {"command": "keep"}, "jurisupport": {"type": "http",
            "url": "https://api.jurisupport.com/mcp", "headers": {"authorization": "old", "X-Test": "keep"}}}}
        path = self.seed("jurisupport", json.dumps(data))
        self.assertEqual(self.run_service("jurisupport")[0], 0)
        actual = json.loads(path.read_text())
        self.assertEqual(actual["theme"], "dark")
        self.assertEqual(actual["projects"], data["projects"])
        self.assertEqual(actual["mcpServers"]["other"], data["mcpServers"]["other"])
        self.assertEqual(actual["mcpServers"]["jurisupport"]["headers"],
                         {"Authorization": "Bearer TEST_ONLY_SECRET", "X-Test": "keep"})
        self.assertTrue(list(path.parent.glob('.' + path.name + '.backup-*')))
        if os.name != "nt":
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual(self.run_service("jurisupport", check=True)[0], 0)

    def test_custom_config_roots(self):
        with patch.dict(os.environ, {"CLAUDE_CONFIG_DIR": str(self.root / "custom"),
                                    "LAW_FORMS_HOME": str(self.root / "forms")}):
            self.assertEqual(self.run_service("jurisupport")[0], 0)
            self.assertEqual(self.run_service("law-forms")[0], 0)
            self.assertTrue((self.root / "custom/.claude.json").exists())
            self.assertTrue((self.root / "forms/config.json").exists())

    def test_invalid_or_foreign_settings_are_not_overwritten(self):
        for content in ('{bad', '[]', '{"mcpServers":[]}',
                        '{"mcpServers":{"jurisupport":{"type":"http","url":"https://other.invalid"}}}'):
            path = self.seed("jurisupport", content)
            self.assertEqual(self.run_service("jurisupport")[0], 1)
            self.assertEqual(path.read_text(), content)

    def test_cancellation_and_bad_values_preserve_settings(self):
        path = self.seed("law-forms", '{"LAW_OC":"original","other":42}')
        for value in ("", " ", "bad\nvalue", "bad\rvalue", "bad\0value"):
            self.assertNotEqual(self.run_service("law-forms", value)[0], 0)
            self.assertEqual(json.loads(path.read_text())["LAW_OC"], "original")
        self.assertEqual(self.run_service("law-forms")[0], 0)
        self.assertEqual(json.loads(path.read_text())["other"], 42)

    def test_env_file_preserved_and_no_automatic_embedding(self):
        path = self.seed("gemini", '# retained\nOTHER=keep\nGEMINI_API_KEY=old\nexport GEMINI_API_KEY=older\n')
        self.assertEqual(self.run_service("legal-books")[0], 0)
        text = path.read_text()
        self.assertIn('# retained\nOTHER=keep\n', text)
        self.assertEqual(text.count('GEMINI_API_KEY='), 1)
        self.assertNotIn('ALLOW_EXTERNAL_EMBEDDING', text)
        self.assertEqual(self.run_service("gemini", check=True)[0], 0)
        path.write_bytes(b'GEMINI_API_KEY="TEST_ONLY_SECRET" # comment\r\nOTHER=keep\r\n')
        self.assertEqual(self.run_service("gemini", check=True)[0], 0)
        for value in ('GEMINI_API_KEY=\nOTHER=value\n', 'GEMINI_API_KEY=""\n',
                      'GEMINI_API_KEY=okay\nGEMINI_API_KEY=\n', 'GEMINI_API_KEY=" "\n'):
            path.write_text(value)
            self.assertEqual(self.run_service("gemini", check=True)[0], 2)

    def test_concurrent_change_aborts_and_symlink_is_rejected(self):
        path = self.seed("case-records", "old")
        with self.assertRaises(ValueError):
            helper.write_private(path, "new", b"not-current")
        self.assertEqual(path.read_text(), "old")
        self.assertFalse(list(path.parent.glob('.juri-*')))
        if os.name != "nt":
            link = path.parent / "link"
            link.symlink_to(path)
            with self.assertRaises(ValueError):
                helper.read_existing(link)

    def test_multiline_existing_target_is_preserved(self):
        original = 'OTHER=keep\nGEMINI_API_KEY="old\nvalue"\n'
        path = self.seed("gemini", original)
        self.assertEqual(self.run_service("gemini")[0], 1)
        self.assertEqual(path.read_text(), original)

    def test_telegram_and_local_token_registration(self):
        path = self.seed("telegram", 'OTHER=keep\nTELEGRAM_BOT_TOKEN=old\n')
        self.assertEqual(self.run_service("telegram", "123456:TEST_ONLY_TOKEN")[0], 0)
        self.assertEqual(helper.env_value(path.read_text(), 'TELEGRAM_BOT_TOKEN'), "123456:TEST_ONLY_TOKEN")
        self.assertIn('OTHER=keep', path.read_text())
        self.assertEqual(self.run_service("telegram", check=True)[0], 0)
        self.assertEqual(self.run_service("telegram", "not-a-telegram-token")[0], 1)
        self.assertEqual(self.run_service("case-records")[0], 0)
        self.assertEqual(helper.target_file("case-records").read_text(), "TEST_ONLY_SECRET\n")

    def test_ecourt_uses_existing_encryptor_stdin_without_plaintext_fallback(self):
        path = self.seed("ecourt-cert", 'OTHER=keep\nECFS_CERT_PW=old\n')
        (path.parent / "secret_store.py").touch()
        ciphertext = base64.b64encode(b"encrypted-fixture").decode()
        with patch.object(helper.sys, "platform", "win32"), patch.object(helper.subprocess, "run", return_value=
                          subprocess.CompletedProcess([], 0, ciphertext, "TEST_ONLY_SECRET")) as run:
            self.assertEqual(self.run_service("ecourt-cert")[0], 0)
        self.assertEqual(run.call_args.kwargs["input"], "TEST_ONLY_SECRET")
        self.assertNotIn("TEST_ONLY_SECRET", str(run.call_args.args))
        self.assertIn('ECFS_CERT_PW_ENC=', path.read_text())
        self.assertNotIn('ECFS_CERT_PW=', path.read_text())
        before = path.read_bytes()
        with patch.object(helper.sys, "platform", "win32"), patch.object(helper.subprocess, "run", return_value=
                          subprocess.CompletedProcess([], 1, "TEST_ONLY_SECRET", "TEST_ONLY_SECRET")):
            self.assertEqual(self.run_service("ecourt-cert")[0], 1)
        self.assertEqual(path.read_bytes(), before)

    def test_sops_uses_stdin_and_never_emits_child_output(self):
        path = self.seed("ecfs-cert", 'sops_mac=encrypted\nECFS_CERT_PW=ENC[fixture]\n')
        (path.parent / "age").mkdir()
        (path.parent / "age/keys.txt").touch()
        with patch.object(helper.sys, "platform", "darwin"), patch.object(helper.shutil, "which", return_value="/sops"), \
                patch.object(helper.subprocess, "run", return_value=
                             subprocess.CompletedProcess([], 0, "TEST_ONLY_SECRET", "TEST_ONLY_SECRET")) as run:
            self.assertEqual(self.run_service("ecfs-cert")[0], 0)
        self.assertEqual(json.loads(run.call_args.kwargs['input']), "TEST_ONLY_SECRET")
        self.assertNotIn("TEST_ONLY_SECRET", str(run.call_args.args))
        self.assertIn('--value-stdin', run.call_args.args[0])
        before = path.read_bytes()
        with patch.object(helper.sys, "platform", "darwin"), patch.object(helper.shutil, "which", return_value="/sops"), \
                patch.object(helper.subprocess, "run", return_value=
                             subprocess.CompletedProcess([], 1, "TEST_ONLY_SECRET", "TEST_ONLY_SECRET")):
            self.assertEqual(self.run_service("ecfs-cert")[0], 1)
        self.assertEqual(path.read_bytes(), before)

    def test_missing_encrypted_runtime_does_not_collect_password(self):
        prompt = Mock()
        with contextlib.redirect_stdout(io.StringIO()), patch.object(helper.sys, "platform", "linux"):
            self.assertEqual(helper.configure_service("ecourt-cert", prompt=prompt), 1)
            self.assertEqual(helper.configure_service("ecfs-cert", prompt=prompt), 1)
        prompt.assert_not_called()

    def test_website_passwords_go_only_to_official_ui(self):
        prompt = Mock()
        with patch.object(helper.webbrowser, "open", return_value=True) as browser, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(helper.configure_service("law-login", prompt=prompt), 0)
        browser.assert_called_once_with("https://open.law.go.kr/LSO/login.do", new=2)
        prompt.assert_not_called()
        with patch.object(helper.webbrowser, "open") as browser, contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(helper.configure_service("law-login", check=True, prompt=prompt), 2)
        browser.assert_not_called()

    @unittest.skipUnless(sys.platform in ("darwin", "win32"), "Native desktop UI")
    def test_service_selector_native_source(self):
        with patch.object(credential_dialog.subprocess, "run", return_value=
                          subprocess.CompletedProcess([], 0, "", "")) as run:
            credential_dialog.native_input("서비스 선택", "등록할 항목", list(helper.SERVICES.values()))
            command = run.call_args.args[0]
        if sys.platform == "win32":
            command[-1] = command[-1].replace('$form.ShowDialog()', '[System.Windows.Forms.DialogResult]::Cancel')
            # Windows resolves the executable using the parent's PATH, not env=.
            with patch.dict(os.environ, self.desktop_environment, clear=True):
                result = subprocess.run(command, capture_output=True, timeout=30)
        else:
            source = self.root / "selector.applescript"
            source.write_text(command[-1], encoding="utf-8")
            # Restore PATH removed by the private-file fixtures.
            result = subprocess.run(['/usr/bin/osacompile', '-o', str(self.root/'selector.scpt'), str(source)],
                                    capture_output=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == '__main__':
    unittest.main()
