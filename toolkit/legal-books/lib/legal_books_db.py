"""Shared SQLite schema helpers for the legal-books toolkit."""

from __future__ import annotations

import os
import sqlite3
from pathlib import Path


ROOT = Path(os.path.expanduser("~/legal-books"))
DB_PATH = ROOT / "db" / "books_fts.db"

SCHEMA_SQL = """
CREATE TABLE IF NOT EXISTS books (
  book_id TEXT PRIMARY KEY,
  author TEXT, title TEXT, edition TEXT, year INTEGER, publisher TEXT,
  added_at TEXT DEFAULT CURRENT_TIMESTAMP
);
CREATE TABLE IF NOT EXISTS chunks (
  chunk_id TEXT PRIMARY KEY,
  book_id TEXT NOT NULL REFERENCES books(book_id),
  page INTEGER,
  chunk_text TEXT NOT NULL,
  embedding BLOB
);
CREATE VIRTUAL TABLE IF NOT EXISTS chunks_fts USING fts5(
  chunk_text, chunk_id UNINDEXED, book_id UNINDEXED, page UNINDEXED,
  content='chunks', content_rowid='rowid', tokenize='unicode61'
);
"""


def ensure_db(db_path: Path = DB_PATH) -> Path:
    """Create the legal-books DB and FTS schema if they do not exist."""
    db_path = Path(db_path)
    db_path.parent.mkdir(parents=True, exist_ok=True)
    con = sqlite3.connect(db_path)
    try:
        con.executescript(SCHEMA_SQL)
        con.commit()
    finally:
        con.close()
    return db_path
