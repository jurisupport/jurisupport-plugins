#!/usr/bin/env python3
"""
legal-books search API (port 8766)

Endpoints:
  GET  /health              → {"status":"ok", "books":N, "chunks":N}
  POST /search              → hybrid search (FTS5 30% + cosine 70%)
    body: {"query": str, "top_k": int=5}
"""

import os
import re
import sqlite3
import sys
from pathlib import Path

import numpy as np
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field
from dotenv import load_dotenv

LIB_DIR = Path(__file__).resolve().parents[1] / "lib"
if LIB_DIR.exists():
    sys.path.insert(0, str(LIB_DIR))

from legal_books_db import DB_PATH, ensure_db

SECRETS = Path(os.path.expanduser("~/.jurisupport/secrets.env"))
load_dotenv(SECRETS)

FTS_WEIGHT = 0.30
COSINE_WEIGHT = 0.70
FTS_CANDIDATE_LIMIT = 100
TOKEN_RE = re.compile(r"[0-9A-Za-z가-힣_]+")


def get_db():
    ensure_db(DB_PATH)
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


def build_fts_query(query: str) -> str:
    """Build a safe high-recall FTS5 query from user text."""
    tokens = TOKEN_RE.findall(query)
    return " OR ".join(f'"{token}"' for token in tokens[:32])


def normalize_bm25(rows) -> dict[str, float]:
    """Normalize FTS5 bm25 scores to [0, 1]. Lower bm25 is better."""
    if not rows:
        return {}
    scores = [float(r["score"]) for r in rows]
    best = min(scores)
    worst = max(scores)
    if best == worst:
        return {r["chunk_id"]: 1.0 for r in rows}
    return {
        r["chunk_id"]: (worst - float(r["score"])) / (worst - best)
        for r in rows
    }


def fetch_fts_candidates(con: sqlite3.Connection, query: str):
    match_query = build_fts_query(query)
    if not match_query:
        return []
    try:
        return con.execute(
            """
            SELECT chunk_id, bm25(chunks_fts) AS score
            FROM chunks_fts
            WHERE chunks_fts MATCH ?
            ORDER BY score
            LIMIT ?
            """,
            (match_query, FTS_CANDIDATE_LIMIT),
        ).fetchall()
    except sqlite3.OperationalError:
        return []


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
    warnings = []

    # 1) FTS5 candidates. This path must work even when Gemini is unavailable.
    fts_rows = fetch_fts_candidates(con, req.query)
    fts_score_map = normalize_bm25(fts_rows)

    # 2) Cosine similarity over all chunks, when query embedding is available.
    cos_score_map = {}
    chunk_map = {}
    try:
        qemb = embed_query(req.query)
    except Exception as exc:
        qemb = None
        warnings.append(f"semantic embedding unavailable; used FTS only: {exc}")
    if qemb is not None:
        all_chunks = con.execute(
            "SELECT chunk_id, book_id, page, chunk_text, embedding "
            "FROM chunks WHERE embedding IS NOT NULL"
        ).fetchall()
        cos_scores = []
        for row in all_chunks:
            emb = np.frombuffer(row["embedding"], dtype=np.float32)
            if emb.shape != qemb.shape:
                warnings.append(f"embedding dimension mismatch skipped: {row['chunk_id']}")
                continue
            s = cosine(qemb, emb)
            cos_scores.append((row["chunk_id"], s, row))
        cos_scores.sort(key=lambda x: x[1], reverse=True)

        # Take top cosine candidates only; FTS-only hits are fetched below.
        top_cos = cos_scores[:FTS_CANDIDATE_LIMIT]
        cos_score_map = {cid: s for cid, s, _ in top_cos}
        chunk_map = {row["chunk_id"]: row for _, _, row in top_cos}

    # 3) Combine
    all_ids = set(fts_score_map.keys()) | set(cos_score_map.keys())
    combined = []
    # Pull rows we do not have yet (usually FTS-only hits).
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
        if qemb is None:
            score = fs
        elif cid in fts_score_map and cid in cos_score_map:
            score = FTS_WEIGHT * fs + COSINE_WEIGHT * cs
        elif cid in fts_score_map:
            score = FTS_WEIGHT * fs
        else:
            score = COSINE_WEIGHT * cs
        combined.append((cid, score))
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
    response = {"query": req.query, "results": results}
    if warnings:
        response["warnings"] = warnings[:5]
    return response


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8766)
