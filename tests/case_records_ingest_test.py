#!/usr/bin/env python3
"""Minimal checks for case-records ingest filtering."""

from __future__ import annotations

import importlib.util
import sqlite3
import sys
import tempfile
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "toolkit/case-records/scripts/ingest_case.py"


def load_ingest():
    spec = importlib.util.spec_from_file_location("case_records_ingest", SCRIPT)
    assert spec and spec.loader
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def write_hwpx(path: Path, text: str) -> None:
    with zipfile.ZipFile(path, "w") as z:
        z.writestr("Contents/section0.xml", f"<root><p><t>{text}</t></p></root>")


def test_target_ingest_keeps_only_argument_and_application() -> None:
    ingest = load_ingest()
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        db_path = tmp_path / "cases_fts.db"
        case_dir = tmp_path / "2026가단1_홍길동_대여금"
        case_dir.mkdir()

        (case_dir / "2026가단1_001_2026.01.01_준비서면_원고.md").write_text(
            "소멸시효 항변에 대한 주장", encoding="utf-8"
        )
        (case_dir / "2026가단1_002_2026.01.02_문서제출명령신청서_원고.txt").write_text(
            "금융거래내역 문서제출명령 신청", encoding="utf-8"
        )
        write_hwpx(case_dir / "2026가단1_003_2026.01.03_의견서_원고.hwpx", "의견서 본문")
        (case_dir / "2026가단1_004_2026.01.04_계약서.txt").write_text(
            "증거 계약서", encoding="utf-8"
        )

        ingest.DB_PATH = db_path
        old_argv = sys.argv
        try:
            sys.argv = [
                "ingest_case.py",
                "--case-dir",
                str(case_dir),
                "--case-id",
                "2026가단1",
                "--case-name",
                "홍길동 대여금",
                "--source-kind",
                "draft",
            ]
            ingest.main()
        finally:
            sys.argv = old_argv

        con = sqlite3.connect(db_path)
        rows = con.execute(
            "SELECT doc_type, doc_category, source_kind, source_file FROM documents ORDER BY doc_type"
        ).fetchall()
        chunks = con.execute("SELECT chunk_text FROM chunks ORDER BY chunk_text").fetchall()
        con.close()

        assert {r[1] for r in rows} == {"argument", "application"}
        assert {r[2] for r in rows} == {"draft"}
        assert len(rows) == 3
        assert all("계약서" not in r[3] for r in rows)
        assert any("의견서 본문" in c[0] for c in chunks)


if __name__ == "__main__":
    test_target_ingest_keeps_only_argument_and_application()
    print("ok - case-records ingest filters target pleadings")
