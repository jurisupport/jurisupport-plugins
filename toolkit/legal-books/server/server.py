#!/usr/bin/env python3
"""
legal-books search API (port 8766)

Endpoints:
  GET  /health              → {"status":"ok", "books":N, "chunks":N}
  POST /search              → hybrid search (FTS5 30% + cosine 70%)
    body: {"query": str, "top_k": int=5}
"""

import os
import sqlite3
import time
from contextlib import asynccontextmanager
from pathlib import Path

import numpy as np
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from dotenv import load_dotenv

ROOT = Path(os.path.expanduser("~/legal-books"))
DB_PATH = ROOT / "db" / "books_fts.db"
SECRETS = Path(os.path.expanduser("~/.jurisupport/secrets.env"))
load_dotenv(SECRETS)

FTS_WEIGHT = 0.30
COSINE_WEIGHT = 0.70


def get_db():
    con = sqlite3.connect(DB_PATH)
    con.row_factory = sqlite3.Row
    return con


def embed_query(q: str) -> np.ndarray:
    """Get single embedding from Gemini."""
    from google import genai
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise HTTPException(500, "GEMINI_API_KEY not set")
    client = genai.Client(api_key=api_key)
    result = client.models.embed_content(
        model="text-embedding-004",
        contents=[q],
    )
    return np.array(result.embeddings[0].values, dtype=np.float32)


def cosine(a: np.ndarray, b: np.ndarray) -> float:
    na = np.linalg.norm(a)
    nb = np.linalg.norm(b)
    if na == 0 or nb == 0:
        return 0.0
    return float(np.dot(a, b) / (na * nb))


app = FastAPI(title="legal-books search")


class SearchReq(BaseModel):
    query: str = Field(..., min_length=1, max_length=500)
    top_k: int = Field(default=5, ge=1, le=20)


@app.get("/health")
def health():
    con = get_db()
    books = con.execute("SELECT COUNT(*) FROM books").fetchone()[0]
    chunks = con.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
    con.close()
    return {"status": "ok", "books": books, "chunks": chunks}


@app.post("/search")
def search(req: SearchReq):
    if not req.query.strip():
        raise HTTPException(400, "query is empty")
    con = get_db()

    # 1) FTS5 candidates (top 100)
    try:
        fts_rows = con.execute("""
            SELECT chunk_id, bm25(chunks_fts) AS score
            FROM chunks_fts
            WHERE chunks_fts MATCH ?
            ORDER BY score
            LIMIT 100
        """, (req.query,)).fetchall()
    except sqlite3.OperationalError:
        fts_rows = []
    fts_score_map = {}
    if fts_rows:
        # bm25: lower=better. Invert and normalize to [0,1]
        max_bm25 = max(abs(r["score"]) for r in fts_rows) or 1.0
        for r in fts_rows:
            fts_score_map[r["chunk_id"]] = 1.0 - (abs(r["score"]) / max_bm25)

    # 2) Cosine similarity over all chunks
    qemb = embed_query(req.query)
    all_chunks = con.execute(
        "SELECT chunk_id, book_id, page, chunk_text, embedding FROM chunks WHERE embedding IS NOT NULL"
    ).fetchall()
    cos_scores = []
    for row in all_chunks:
        emb = np.frombuffer(row["embedding"], dtype=np.float32)
        s = cosine(qemb, emb)
        cos_scores.append((row["chunk_id"], s, row))
    cos_scores.sort(key=lambda x: x[1], reverse=True)

    # Take top 100 by cosine
    top_cos = cos_scores[:100]
    cos_score_map = {cid: s for cid, s, _ in top_cos}

    # 3) Combine
    all_ids = set(fts_score_map.keys()) | set(cos_score_map.keys())
    combined = []
    chunk_map = {row["chunk_id"]: row for _, _, row in top_cos}
    # also pull rows we don't have yet (FTS-only hits)
    missing = all_ids - set(chunk_map.keys())
    if missing:
        placeholders = ",".join("?" * len(missing))
        for r in con.execute(
            f"SELECT chunk_id, book_id, page, chunk_text FROM chunks WHERE chunk_id IN ({placeholders})",
            tuple(missing),
        ):
            chunk_map[r["chunk_id"]] = r

    for cid in all_ids:
        fs = fts_score_map.get(cid, 0.0)
        cs = cos_score_map.get(cid, 0.0)
        combined.append((cid, FTS_WEIGHT * fs + COSINE_WEIGHT * cs))
    combined.sort(key=lambda x: x[1], reverse=True)

    # Lookup book metadata
    books = {b["book_id"]: dict(b) for b in con.execute("SELECT * FROM books")}

    results = []
    for cid, score in combined[: req.top_k]:
        row = chunk_map[cid]
        book = books.get(row["book_id"], {})
        results.append({
            "chunk_id": cid,
            "score": round(score, 4),
            "book_id": row["book_id"],
            "author": book.get("author"),
            "title": book.get("title"),
            "edition": book.get("edition"),
            "year": book.get("year"),
            "page": row["page"],
            "chunk_text": row["chunk_text"],
        })
    con.close()
    return {"query": req.query, "results": results}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8766)
