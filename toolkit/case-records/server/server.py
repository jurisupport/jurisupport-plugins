#!/usr/bin/env python3
"""case-records search API (port 8767). Hybrid FTS5 + cosine."""

import os, sqlite3
from pathlib import Path
import secrets as secrets_lib
import numpy as np
from fastapi import Depends, FastAPI, Header, HTTPException
from pydantic import BaseModel, Field
from dotenv import load_dotenv

ROOT = Path(os.path.expanduser("~/case-records"))
DB_PATH = ROOT / "db" / "cases_fts.db"
SECRETS = Path(os.path.expanduser("~/.jurisupport/secrets.env"))
TOKEN_PATH = Path(os.path.expanduser("~/.jurisupport/case-records.token"))
load_dotenv(SECRETS)

FTS_W = 0.30
COS_W = 0.70
TRUE_VALUES = {"1", "true", "yes", "y", "on"}


def db():
    c = sqlite3.connect(DB_PATH); c.row_factory = sqlite3.Row; return c


def external_embedding_enabled() -> bool:
    return os.environ.get("CASE_RECORDS_ALLOW_EXTERNAL_EMBEDDING", "").lower() in TRUE_VALUES


def configured_api_token() -> str:
    env_token = os.environ.get("CASE_RECORDS_API_TOKEN", "").strip()
    if env_token:
        return env_token
    try:
        return TOKEN_PATH.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def require_api_token(authorization: str | None = Header(default=None)) -> None:
    expected = configured_api_token()
    if not expected:
        raise HTTPException(500, "case-records API token not configured")
    prefix = "Bearer "
    if not authorization or not authorization.startswith(prefix):
        raise HTTPException(401, "missing case-records bearer token")
    provided = authorization[len(prefix):].strip()
    if not secrets_lib.compare_digest(provided, expected):
        raise HTTPException(403, "invalid case-records bearer token")


def embed(q: str) -> np.ndarray:
    from google import genai
    key = os.environ.get("GEMINI_API_KEY") or ""
    if not key: raise HTTPException(500, "GEMINI_API_KEY not set")
    client = genai.Client(api_key=key)
    r = client.models.embed_content(model="text-embedding-004", contents=[q])
    return np.array(r.embeddings[0].values, dtype=np.float32)


def cos(a, b):
    na = np.linalg.norm(a); nb = np.linalg.norm(b)
    return float(np.dot(a, b) / (na * nb)) if na and nb else 0.0


app = FastAPI(title="case-records search")


class Req(BaseModel):
    query: str = Field(..., min_length=1, max_length=500)
    top_k: int = Field(default=5, ge=1, le=20)
    filters: dict = Field(default_factory=dict)


@app.get("/health")
def health():
    c = db()
    cases = c.execute("SELECT COUNT(*) FROM cases").fetchone()[0]
    docs = c.execute("SELECT COUNT(*) FROM documents").fetchone()[0]
    chunks = c.execute("SELECT COUNT(*) FROM chunks").fetchone()[0]
    c.close()
    return {"status": "ok", "cases": cases, "documents": docs, "chunks": chunks}


@app.post("/search")
def search(req: Req, _: None = Depends(require_api_token)):
    if not req.query.strip(): raise HTTPException(400, "empty")
    c = db()

    # FTS
    try:
        fts = c.execute(
            "SELECT chunk_id, bm25(chunks_fts) s FROM chunks_fts WHERE chunks_fts MATCH ? ORDER BY s LIMIT 100",
            (req.query,),
        ).fetchall()
    except sqlite3.OperationalError:
        fts = []
    fts_m = {}
    if fts:
        mx = max(abs(r["s"]) for r in fts) or 1.0
        for r in fts: fts_m[r["chunk_id"]] = 1.0 - abs(r["s"]) / mx

    # Cosine is opt-in because it sends the search query to Gemini.
    cos_m = {}
    top = []
    if external_embedding_enabled():
        qe = embed(req.query)
        rows = c.execute(
            "SELECT chunk_id, doc_id, case_id, chunk_text, embedding FROM chunks WHERE embedding IS NOT NULL"
        ).fetchall()
        cos_s = []
        for r in rows:
            e = np.frombuffer(r["embedding"], dtype=np.float32)
            cos_s.append((r["chunk_id"], cos(qe, e), r))
        cos_s.sort(key=lambda x: x[1], reverse=True)
        top = cos_s[:100]
        cos_m = {cid: s for cid, s, _ in top}

    chunk_map = {r["chunk_id"]: r for _, _, r in top}
    missing = (set(fts_m) | set(cos_m)) - set(chunk_map)
    if missing:
        ph = ",".join("?" * len(missing))
        for r in c.execute(
            f"SELECT chunk_id, doc_id, case_id, chunk_text FROM chunks WHERE chunk_id IN ({ph})",
            tuple(missing),
        ):
            chunk_map[r["chunk_id"]] = r

    # Combine
    combined = []
    for cid in set(fts_m) | set(cos_m):
        combined.append((cid, FTS_W * fts_m.get(cid, 0) + COS_W * cos_m.get(cid, 0)))
    combined.sort(key=lambda x: x[1], reverse=True)

    # Filters
    doc_type_f = req.filters.get("doc_type")
    case_id_f = req.filters.get("case_id")

    cases = {r["case_id"]: dict(r) for r in c.execute("SELECT * FROM cases")}
    docs = {r["doc_id"]: dict(r) for r in c.execute("SELECT * FROM documents")}

    results = []
    for cid, score in combined:
        row = chunk_map[cid]
        doc = docs.get(row["doc_id"], {})
        case = cases.get(row["case_id"], {})
        if doc_type_f and doc.get("doc_type") != doc_type_f: continue
        if case_id_f and case.get("case_id") != case_id_f: continue
        results.append({
            "chunk_id": cid, "score": round(score, 4),
            "case_id": case.get("case_id"),
            "case_name": case.get("case_name"),
            "case_status": case.get("status"),
            "case_result": case.get("result"),
            "doc_type": doc.get("doc_type"),
            "doc_date": doc.get("doc_date"),
            "author_role": doc.get("author_role"),
            "chunk_text": row["chunk_text"],
        })
        if len(results) >= req.top_k: break
    c.close()
    return {"query": req.query, "results": results}


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="127.0.0.1", port=8767)
