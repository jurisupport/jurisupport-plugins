#!/usr/bin/env python3
"""Regression tests for legal-books search ranking and fallback."""

from __future__ import annotations

import importlib.util
import sqlite3
import struct
import sys
import tempfile
import types
from pathlib import Path

import numpy as np


ROOT = Path(__file__).resolve().parents[1]
SERVER = ROOT / "toolkit" / "legal-books" / "server" / "server.py"


def install_import_stubs() -> None:
    fastapi_stub = types.ModuleType("fastapi")

    class HTTPException(Exception):
        def __init__(self, status_code, detail=None):
            super().__init__(detail or status_code)
            self.status_code = status_code
            self.detail = detail

    class FastAPI:
        def __init__(self, *args, **kwargs):
            pass

        def get(self, *args, **kwargs):
            return lambda fn: fn

        def post(self, *args, **kwargs):
            return lambda fn: fn

    fastapi_stub.FastAPI = FastAPI
    fastapi_stub.HTTPException = HTTPException
    sys.modules.setdefault("fastapi", fastapi_stub)

    dotenv_stub = types.ModuleType("dotenv")
    dotenv_stub.load_dotenv = lambda *args, **kwargs: None
    sys.modules.setdefault("dotenv", dotenv_stub)


def load_server_module():
    install_import_stubs()
    spec = importlib.util.spec_from_file_location("legal_books_server", SERVER)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def embedding_blob(values) -> bytes:
    return struct.pack(f"{len(values)}f", *[float(v) for v in values])


def init_db(db_path: Path, with_embeddings: bool = True) -> None:
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
    con.execute(
        "INSERT INTO books(book_id, author, title, edition, year, publisher) "
        "VALUES ('001', '저자', '민법총칙', '제1판', 2026, '출판사')"
    )
    rows = [
        (
            "exact",
            "001",
            10,
            "소멸시효 채무승인 소멸시효 채무승인 시효이익 포기",
            embedding_blob([1.0, 0.0]) if with_embeddings else None,
        ),
        (
            "loose",
            "001",
            20,
            "소멸시효 일반론과 권리행사 기간",
            embedding_blob([1.0, 0.0]) if with_embeddings else None,
        ),
    ]
    con.executemany(
        "INSERT INTO chunks(chunk_id, book_id, page, chunk_text, embedding) "
        "VALUES (?,?,?,?,?)",
        rows,
    )
    con.execute("INSERT INTO chunks_fts(chunks_fts) VALUES('rebuild')")
    con.commit()
    con.close()


def search(module, query: str, top_k: int = 2):
    req = types.SimpleNamespace(query=query, top_k=top_k)
    return module.search(req)


def test_exact_fts_hit_wins_when_cosine_ties() -> None:
    module = load_server_module()
    with tempfile.TemporaryDirectory() as d:
        db_path = Path(d) / "books_fts.db"
        init_db(db_path, with_embeddings=True)
        module.DB_PATH = db_path
        module.embed_query = lambda q: np.array([1.0, 0.0], dtype=np.float32)

        result = search(module, "소멸시효")

        assert result["results"][0]["chunk_id"] == "exact"


def test_search_falls_back_to_fts_when_query_embedding_fails() -> None:
    module = load_server_module()
    with tempfile.TemporaryDirectory() as d:
        db_path = Path(d) / "books_fts.db"
        init_db(db_path, with_embeddings=False)
        module.DB_PATH = db_path

        def fail_embed(query):
            raise RuntimeError("Gemini unavailable")

        module.embed_query = fail_embed

        result = search(module, "소멸시효 (채무승인)")

        assert result["results"]
        assert result["results"][0]["chunk_id"] == "exact"
        assert "warnings" in result


def main() -> None:
    test_exact_fts_hit_wins_when_cosine_ties()
    print("ok - exact FTS hit wins when cosine ties")
    test_search_falls_back_to_fts_when_query_embedding_fails()
    print("ok - search falls back to FTS when query embedding fails")


if __name__ == "__main__":
    main()
