#!/usr/bin/env python3
"""
Ingest a single case directory into case-records DB.

- Walks case_dir, finds PDF/DOCX/MD/TXT files.
- Extracts text per file.
- Parses filename for metadata (doc_type, doc_date, author_role).
- Chunks, embeds, inserts.
"""

import argparse
import json
import os
import re
import sqlite3
import sys
import time
from pathlib import Path

import numpy as np
from pypdf import PdfReader
from dotenv import load_dotenv

ROOT = Path(os.path.expanduser("~/case-records"))
DB_PATH = ROOT / "db" / "cases_fts.db"
SECRETS = Path(os.path.expanduser("~/.jurisupport/secrets.env"))
load_dotenv(SECRETS)

CHUNK_SIZE = 1500
CHUNK_OVERLAP = 300

# Filename pattern: {case#}_{idx}_{YYYY.MM.DD}_{doctype}_..._{author}.pdf
FILENAME_RE = re.compile(
    r"^([^_]+)_(\d+)_(\d{4}\.\d{1,2}\.\d{1,2})_([^_]+)(?:_.*?)?(?:_([^_.]+))?\.(pdf|docx?|md|txt|hwp|hwpx)$",
    re.IGNORECASE,
)


def parse_filename(fname: str):
    m = FILENAME_RE.match(fname)
    if not m:
        return None
    return {
        "case_no": m.group(1),
        "seq": m.group(2),
        "doc_date": m.group(3).replace(".", "-"),
        "doc_type": m.group(4),
        "author_role": m.group(5) or "",
    }


def extract_text(path: Path) -> str:
    ext = path.suffix.lower()
    try:
        if ext == ".pdf":
            return "\n".join((p.extract_text() or "") for p in PdfReader(str(path)).pages)
        if ext in (".docx",):
            from docx import Document
            return "\n".join(p.text for p in Document(str(path)).paragraphs)
        if ext in (".md", ".txt"):
            return path.read_text(encoding="utf-8", errors="ignore")
        # HWP support: skip silently (use kordoc MCP via Claude Code instead)
        return ""
    except Exception as e:
        print(f"  [warn] extract failed {path.name}: {e}", file=sys.stderr)
        return ""


def chunk_text(text: str, size: int = CHUNK_SIZE, overlap: int = CHUNK_OVERLAP):
    text = text.strip()
    if not text:
        return []
    out = []
    i = 0
    while i < len(text):
        end = min(i + size, len(text))
        out.append(text[i:end])
        if end == len(text):
            break
        i += size - overlap
    return out


def embed_batch(texts: list[str]) -> list[list[float]]:
    from google import genai
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        raise RuntimeError("GEMINI_API_KEY not set in ~/.jurisupport/secrets.env")
    client = genai.Client(api_key=key)
    out = []
    for i in range(0, len(texts), 100):
        batch = texts[i:i + 100]
        r = client.models.embed_content(model="text-embedding-004", contents=batch)
        out.extend([e.values for e in r.embeddings])
        time.sleep(0.5)
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--case-dir", required=True, type=Path)
    ap.add_argument("--case-id", required=True)
    ap.add_argument("--case-name", required=True)
    ap.add_argument("--status", default="진행중")
    ap.add_argument("--result", default="")
    ap.add_argument("--court", default="")
    args = ap.parse_args()

    con = sqlite3.connect(DB_PATH)
    con.execute(
        "INSERT OR REPLACE INTO cases (case_id, case_name, status, result, court) VALUES (?,?,?,?,?)",
        (args.case_id, args.case_name, args.status, args.result, args.court),
    )

    # Walk case dir
    docs = []
    for p in args.case_dir.rglob("*"):
        if not p.is_file():
            continue
        if p.suffix.lower() not in (".pdf", ".docx", ".md", ".txt", ".hwp", ".hwpx"):
            continue
        meta = parse_filename(p.name) or {}
        text = extract_text(p)
        if not text.strip():
            continue
        doc_id = f"{args.case_id}__{p.name[:80]}"
        docs.append({
            "doc_id": doc_id,
            "case_id": args.case_id,
            "doc_type": meta.get("doc_type", "기타"),
            "doc_date": meta.get("doc_date", ""),
            "author_role": meta.get("author_role", ""),
            "source_file": str(p),
            "text": text,
        })

    if not docs:
        print(f"  [warn] no text extracted from {args.case_dir}", file=sys.stderr)
        con.commit(); con.close()
        return

    print(f"  [ingest] {len(docs)} documents found")

    all_chunks = []
    for d in docs:
        con.execute(
            "INSERT OR REPLACE INTO documents (doc_id, case_id, doc_type, doc_date, author_role, source_file) VALUES (?,?,?,?,?,?)",
            (d["doc_id"], d["case_id"], d["doc_type"], d["doc_date"], d["author_role"], d["source_file"]),
        )
        for j, c in enumerate(chunk_text(d["text"])):
            all_chunks.append({
                "chunk_id": f"{d['doc_id']}__{j:04d}",
                "doc_id": d["doc_id"],
                "case_id": d["case_id"],
                "chunk_text": c,
            })

    if not all_chunks:
        con.commit(); con.close()
        return

    print(f"  [ingest] {len(all_chunks)} chunks → embedding")
    embs = embed_batch([c["chunk_text"] for c in all_chunks])

    for c, e in zip(all_chunks, embs):
        blob = np.array(e, dtype=np.float32).tobytes()
        con.execute(
            "INSERT OR REPLACE INTO chunks (chunk_id, doc_id, case_id, chunk_text, embedding) VALUES (?,?,?,?,?)",
            (c["chunk_id"], c["doc_id"], c["case_id"], c["chunk_text"], blob),
        )

    con.execute("INSERT INTO chunks_fts(chunks_fts) VALUES('rebuild')")
    con.commit()
    con.close()
    print(f"  [done] case {args.case_id} indexed.")


if __name__ == "__main__":
    main()
