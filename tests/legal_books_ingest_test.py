#!/usr/bin/env python3
"""Regression tests for legal-books ingest idempotency."""

from __future__ import annotations

import importlib.util
import sqlite3
import struct
import sys
import tempfile
import types
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
INGEST = ROOT / "toolkit" / "legal-books" / "scripts" / "ingest.py"


def install_import_stubs() -> None:
    np_stub = types.ModuleType("numpy")
    np_stub.float32 = "float32"

    class FakeArray:
        def __init__(self, values):
            self.values = [float(v) for v in values]

        def tobytes(self):
            return struct.pack(f"{len(self.values)}f", *self.values)

    np_stub.array = lambda values, dtype=None: FakeArray(values)
    sys.modules.setdefault("numpy", np_stub)

    pypdf_stub = types.ModuleType("pypdf")
    pypdf_stub.PdfReader = object
    sys.modules.setdefault("pypdf", pypdf_stub)

    dotenv_stub = types.ModuleType("dotenv")
    dotenv_stub.load_dotenv = lambda *args, **kwargs: None
    sys.modules.setdefault("dotenv", dotenv_stub)


def load_ingest_module():
    install_import_stubs()
    spec = importlib.util.spec_from_file_location("legal_books_ingest", INGEST)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def init_db(db_path: Path) -> None:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(db_path)
    con.executescript(
        """
        CREATE TABLE books (
          book_id TEXT PRIMARY KEY,
          author TEXT, title TEXT, edition TEXT, year INTEGER, publisher TEXT,
          added_at TEXT DEFAULT CURRENT_TIMESTAMP
        );
        CREATE TABLE chunks (
          chunk_id TEXT PRIMARY KEY,
          book_id TEXT NOT NULL REFERENCES books(book_id),
          page INTEGER,
          chunk_text TEXT NOT NULL,
          embedding BLOB
        );
        CREATE VIRTUAL TABLE chunks_fts USING fts5(
          chunk_text, chunk_id UNINDEXED, book_id UNINDEXED, page UNINDEXED,
          content='chunks', content_rowid='rowid', tokenize='unicode61'
        );
        """
    )
    con.commit()
    con.close()


def run_ingest(module, tmp: Path, book_id: str, pages, embeddings=None) -> None:
    book_dir = tmp / "books" / f"{book_id}_Author_Title"
    book_dir.mkdir(parents=True, exist_ok=True)
    module.DB_PATH = tmp / "db" / "books_fts.db"
    module.extract_pages = lambda pdf_path: iter(pages)

    def fake_embed(texts):
        if embeddings is not None:
            return embeddings
        return [[float(i + 1), 0.0] for i, _ in enumerate(texts)]

    module.embed_batch = fake_embed
    old_argv = sys.argv[:]
    sys.argv = [
        "ingest.py",
        "--book-id",
        book_id,
        "--pdf",
        str(tmp / f"{book_id}.pdf"),
        "--book-dir",
        str(book_dir),
        "--author",
        "Author",
        "--title",
        "Title",
        "--edition",
        "1st",
        "--year",
        "2026",
        "--publisher",
        "Publisher",
    ]
    try:
        module.main()
    finally:
        sys.argv = old_argv


def run_ingest_md(module, tmp: Path, book_id: str, markdown: str) -> None:
    book_dir = tmp / "books" / f"{book_id}_Author_Title"
    book_dir.mkdir(parents=True, exist_ok=True)
    md_path = tmp / f"{book_id}.md"
    md_path.write_text(markdown, encoding="utf-8")
    module.DB_PATH = tmp / "db" / "books_fts.db"
    module.embed_batch = lambda texts: [[float(i + 1), 0.0] for i, _ in enumerate(texts)]
    old_argv = sys.argv[:]
    sys.argv = [
        "ingest.py",
        "--book-id",
        book_id,
        "--md",
        str(md_path),
        "--book-dir",
        str(book_dir),
        "--author",
        "Author",
        "--title",
        "Title",
        "--edition",
        "1st",
        "--year",
        "2026",
        "--publisher",
        "Publisher",
    ]
    try:
        module.main()
    finally:
        sys.argv = old_argv


def test_reingest_removes_stale_chunks() -> None:
    module = load_ingest_module()
    with tempfile.TemporaryDirectory() as d:
        tmp = Path(d)
        db_path = tmp / "db" / "books_fts.db"
        init_db(db_path)

        run_ingest(
            module,
            tmp,
            "001",
            [(1, "alpha first page"), (2, "stale second page")],
        )
        run_ingest(module, tmp, "001", [(1, "replacement only page")])

        con = sqlite3.connect(db_path)
        chunks = con.execute(
            "SELECT page, chunk_text FROM chunks WHERE book_id = '001' ORDER BY page"
        ).fetchall()
        stale_fts = con.execute(
            "SELECT COUNT(*) FROM chunks_fts WHERE chunks_fts MATCH 'stale'"
        ).fetchone()[0]
        con.close()

        assert chunks == [(1, "replacement only page")]
        assert stale_fts == 0


def test_embedding_count_mismatch_rolls_back() -> None:
    module = load_ingest_module()
    with tempfile.TemporaryDirectory() as d:
        tmp = Path(d)
        db_path = tmp / "db" / "books_fts.db"
        init_db(db_path)

        try:
            run_ingest(
                module,
                tmp,
                "002",
                [(1, "one"), (2, "two")],
                embeddings=[[1.0, 0.0]],
            )
        except RuntimeError as exc:
            assert "Embedding count mismatch" in str(exc)
        else:
            raise AssertionError("ingest accepted a partial embedding response")

        con = sqlite3.connect(db_path)
        book_count = con.execute("SELECT COUNT(*) FROM books").fetchone()[0]
        chunk_count = con.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
        con.close()

        assert book_count == 0
        assert chunk_count == 0


def test_markdown_input_indexes_page_headings() -> None:
    module = load_ingest_module()
    with tempfile.TemporaryDirectory() as d:
        tmp = Path(d)
        db_path = tmp / "db" / "books_fts.db"
        init_db(db_path)

        run_ingest_md(
            module,
            tmp,
            "003",
            "# Author - Title\n\n## p.12\n\nfirst page text\n\n## p.13\n\nsecond page text\n",
        )

        con = sqlite3.connect(db_path)
        chunks = con.execute(
            "SELECT page, chunk_text FROM chunks WHERE book_id = '003' ORDER BY page"
        ).fetchall()
        con.close()

        assert chunks == [(12, "first page text"), (13, "second page text")]


def test_markdown_input_requires_page_headings() -> None:
    module = load_ingest_module()
    with tempfile.TemporaryDirectory() as d:
        tmp = Path(d)
        db_path = tmp / "db" / "books_fts.db"
        init_db(db_path)

        try:
            run_ingest_md(module, tmp, "004", "# Author - Title\n\n본문만 있음\n")
        except RuntimeError as exc:
            assert "page headings" in str(exc)
        else:
            raise AssertionError("ingest accepted markdown without page headings")

        con = sqlite3.connect(db_path)
        book_count = con.execute("SELECT COUNT(*) FROM books").fetchone()[0]
        chunk_count = con.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
        con.close()

        assert book_count == 0
        assert chunk_count == 0


def main() -> None:
    test_reingest_removes_stale_chunks()
    print("ok - legal-books reingest removes stale chunks")
    test_embedding_count_mismatch_rolls_back()
    print("ok - legal-books embedding mismatch rolls back")
    test_markdown_input_indexes_page_headings()
    print("ok - legal-books markdown input indexes page headings")
    test_markdown_input_requires_page_headings()
    print("ok - legal-books markdown input requires page headings")


if __name__ == "__main__":
    main()
