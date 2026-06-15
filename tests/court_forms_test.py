#!/usr/bin/env python3
"""Regression tests for the court-forms local DB helper."""

from __future__ import annotations

import importlib.util
import json
import sqlite3
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "toolkit" / "court-forms" / "scripts" / "court_forms.py"


def load_module():
    spec = importlib.util.spec_from_file_location("court_forms", SCRIPT)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def sample_rows():
    return [
        {
            "gubun": 17,
            "minGubun": "b",
            "title": "[신청] 주택임차권등기명령신청서",
            "fileOrgName": "주택임차권등기명령신청서.hwp",
            "fileSysName": "1111111111111_111111.hwp",
            "fileOrgName2": None,
            "fileSysName2": None,
            "fileOrgName3": "주택임차권등기명령신청서.pdf",
            "fileSysName3": "2222222222222_222222.pdf",
        },
        {
            "gubun": 17,
            "minGubun": "a",
            "title": "[민사] 주소보정서",
            "fileOrgName": "주소보정서.hwp",
            "fileSysName": "3333333333333_333333.hwp",
            "fileOrgName3": "주소보정서.pdf",
            "fileSysName3": "4444444444444_444444.pdf",
        },
    ]


def test_cp949_download_url_matches_scourt_encoding() -> None:
    module = load_module()
    url = module.build_download_url("1671586920435_104200.hwp", "인지.hwp")

    assert "file=1671586920435_104200.hwp" in url
    assert "downFile=%C0%CE%C1%F6.hwp" in url


def test_store_and_search_supports_korean_substrings() -> None:
    module = load_module()
    with tempfile.TemporaryDirectory() as d:
        db_path = Path(d) / "forms.db"
        con = sqlite3.connect(db_path)
        con.row_factory = sqlite3.Row
        module.ensure_schema(con)
        module.upsert_categories(
            con,
            [
                {"scode": "a", "scodeKname": "민사"},
                {"scode": "b", "scodeKname": "신청"},
            ],
        )
        stored = module.store_rows(
            con,
            sample_rows(),
            {"a": "민사", "b": "신청"},
            source_page=1,
        )
        module.rebuild_fts(con)
        con.commit()

        results = module.search_db(con, "임차권등기명령", 5)
        address_results = module.search_db(con, "주소보정", 5)
        attachments = module.attachments_for_form(con, results[0]["form_id"])
        con.close()

        assert stored == 2
        assert results[0]["title"] == "[신청] 주택임차권등기명령신청서"
        assert address_results[0]["title"] == "[민사] 주소보정서"
        assert [a["kind"] for a in attachments] == ["hwp", "pdf"]
        assert attachments[0]["download_url"].startswith("https://file.scourt.go.kr/AttachDownload?")


def test_export_markdown_uses_relative_manifest_paths() -> None:
    module = load_module()
    with tempfile.TemporaryDirectory() as d:
        tmp = Path(d)
        db_path = tmp / "forms.db"
        files_dir = tmp / "files"
        export_dir = tmp / "export"
        files_dir.mkdir()
        local_hwp = files_dir / "주소보정서.hwp"
        local_hwp.write_bytes(b"fake hwp")

        con = sqlite3.connect(db_path)
        con.row_factory = sqlite3.Row
        module.ensure_schema(con)
        module.upsert_categories(con, [{"scode": "a", "scodeKname": "민사"}])
        module.store_rows(con, [sample_rows()[1]], {"a": "민사"}, source_page=1)
        form_id = con.execute("SELECT form_id FROM forms").fetchone()[0]
        con.execute(
            """
            UPDATE attachments
            SET local_path = ?, sha256 = ?, size_bytes = ?
            WHERE form_id = ? AND kind = 'hwp'
            """,
            (str(local_hwp), "abc123", local_hwp.stat().st_size, form_id),
        )
        con.commit()
        con.close()

        module.extract_text = lambda path, kind: ("주소보정서 본문   \n공백 제거\t", None)
        args = type(
            "Args",
            (),
            {
                "db": db_path,
                "files_dir": files_dir,
                "output": export_dir,
                "copy_files": True,
                "download_missing": False,
                "force": False,
                "delay": 0,
            },
        )()
        result = module.export_markdown(args)

        manifest = json.loads((export_dir / "forms.jsonl").read_text(encoding="utf-8").splitlines()[0])
        md_path = export_dir / manifest["markdown_path"]
        hwp = next(a for a in manifest["attachments"] if a["kind"] == "hwp")

        assert result["forms"] == 1
        assert md_path.exists()
        md_text = md_path.read_text(encoding="utf-8")
        assert "주소보정서 본문\n공백 제거" in md_text
        assert not any(line.endswith((" ", "\t")) for line in md_text.splitlines())
        assert hwp["export_path"].startswith("forms/")
        assert str(tmp) not in json.dumps(manifest, ensure_ascii=False)


def main() -> None:
    test_cp949_download_url_matches_scourt_encoding()
    print("ok - court-forms download URLs use cp949 downFile encoding")
    test_store_and_search_supports_korean_substrings()
    print("ok - court-forms stores and searches Korean form metadata")
    test_export_markdown_uses_relative_manifest_paths()
    print("ok - court-forms exports repo-safe Markdown manifests")


if __name__ == "__main__":
    main()
