#!/usr/bin/env python3
"""
Ingest a single OCRed PDF into legal-books DB.

Steps:
1. Extract text from PDF (page-by-page)
2. Write markdown (1 file per book)
3. Chunk text (~1000 chars, 200 overlap)
4. Generate Gemini embeddings (batched, retrying transient failures)
5. Insert into SQLite (books + chunks + FTS5)
"""

import argparse
import json
import os
import pathlib
import sqlite3
import sys
import time
from pathlib import Path

import numpy as np
from pypdf import PdfReader
from dotenv import load_dotenv

ROOT = Path(os.path.expanduser("~/legal-books"))
DB_PATH = ROOT / "db" / "books_fts.db"
SECRETS = Path(os.path.expanduser("~/.jurisupport/secrets.env"))

CHUNK_SIZE = 1000
CHUNK_OVERLAP = 200
EMBEDDING_MODEL = "text-embedding-004"
DEFAULT_EMBED_BATCH_SIZE = 100
DEFAULT_EMBED_MAX_RETRIES = 5

load_dotenv(SECRETS)


def env_int(name: str, default: int, minimum: int = 1) -> int:
    try:
        value = int(os.environ.get(name, str(default)))
    except ValueError:
        return default
    return max(minimum, value)


def extract_pages(pdf_path: Path):
    """Yield (page_number, text) for each page."""
    reader = PdfReader(str(pdf_path))
    for i, page in enumerate(reader.pages, start=1):
        try:
            yield i, page.extract_text() or ""
        except Exception as e:
            print(f"  page {i}: extract failed ({e})", file=sys.stderr)
            yield i, ""


def chunk_text(text: str, size: int = CHUNK_SIZE, overlap: int = CHUNK_OVERLAP):
    """Greedy sliding-window chunker."""
    text = text.strip()
    if not text:
        return []
    chunks = []
    i = 0
    while i < len(text):
        end = min(i + size, len(text))
        chunks.append(text[i:end])
        if end == len(text):
            break
        i += size - overlap
    return chunks


def embed_batch(texts: list[str]) -> list[list[float]]:
    """Get Gemini embeddings from Gemini with bounded retries."""
    from google import genai

    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise RuntimeError(
            "GEMINI_API_KEY not set. Add to ~/.jurisupport/secrets.env"
        )
    client = genai.Client(api_key=api_key)
    batch_size = env_int("LEGAL_BOOKS_EMBED_BATCH_SIZE", DEFAULT_EMBED_BATCH_SIZE)
    max_retries = env_int("LEGAL_BOOKS_EMBED_MAX_RETRIES", DEFAULT_EMBED_MAX_RETRIES)
    out = []
    for i in range(0, len(texts), batch_size):
        batch = texts[i:i + batch_size]
        batch_no = (i // batch_size) + 1
        for attempt in range(1, max_retries + 1):
            try:
                result = client.models.embed_content(
                    model=EMBEDDING_MODEL,
                    contents=batch,
                )
                batch_embeddings = [e.values for e in result.embeddings]
                if len(batch_embeddings) != len(batch):
                    raise RuntimeError(
                        f"Gemini returned {len(batch_embeddings)} embeddings "
                        f"for {len(batch)} chunks"
                    )
                out.extend(batch_embeddings)
                break
            except Exception as exc:
                if attempt == max_retries:
                    raise RuntimeError(
                        f"Gemini embedding failed for batch {batch_no} "
                        f"after {max_retries} attempts: {exc}"
                    ) from exc
                wait = min(60, 2 ** attempt)
                print(
                    "  [ingest] Gemini embedding retry "
                    f"{attempt}/{max_retries} for batch {batch_no} "
                    f"in {wait}s ({exc})",
                    file=sys.stderr,
                    flush=True,
                )
                time.sleep(wait)
        time.sleep(0.5)  # rate limit cushion
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--book-id", required=True)
    ap.add_argument("--pdf", required=True, type=Path)
    ap.add_argument("--book-dir", required=True, type=Path)
    ap.add_argument("--author", required=True)
    ap.add_argument("--title", required=True)
    ap.add_argument("--edition", default="")
    ap.add_argument("--year", type=int, default=0)
    ap.add_argument("--publisher", default="")
    args = ap.parse_args()

    # Extract pages
    print("  [ingest] Extracting text from PDF...", flush=True)
    pages = list(extract_pages(args.pdf))
    print(f"  [ingest] {len(pages)} pages extracted", flush=True)

    # Write markdown (one file, page headers)
    md_path = args.book_dir / f"{args.book_id}.md"
    with open(md_path, "w", encoding="utf-8") as f:
        f.write(f"# {args.author} — {args.title} ({args.edition})\n\n")
        for page_no, text in pages:
            f.write(f"\n## p.{page_no}\n\n{text}\n")
    print(f"  [ingest] Markdown saved: {md_path.name}", flush=True)

    # Metadata file
    meta = {
        "book_id": args.book_id,
        "author": args.author,
        "title": args.title,
        "edition": args.edition,
        "year": args.year,
        "publisher": args.publisher,
        "page_count": len(pages),
    }
    with open(args.book_dir / f"{args.book_id}.meta.json", "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False, indent=2)

    # Chunk
    print("  [ingest] Chunking...", flush=True)
    all_chunks = []
    for page_no, text in pages:
        for j, c in enumerate(chunk_text(text)):
            all_chunks.append({
                "chunk_id": f"{args.book_id}_{page_no:04d}_{j:03d}",
                "book_id": args.book_id,
                "page": page_no,
                "chunk_text": c,
            })
    print(f"  [ingest] {len(all_chunks)} chunks", flush=True)

    if not all_chunks:
        print("  [ingest] No text extracted. Skipping embedding.", file=sys.stderr)
        sys.exit(1)

    # Embed
    print("  [ingest] Generating embeddings (Gemini)...", flush=True)
    texts = [c["chunk_text"] for c in all_chunks]
    embeddings = embed_batch(texts)
    print(f"  [ingest] {len(embeddings)} embeddings generated", flush=True)

    if len(embeddings) != len(all_chunks):
        raise RuntimeError(
            "Embedding count mismatch: "
            f"{len(all_chunks)} chunks but {len(embeddings)} embeddings"
        )

    # Write chunks.jsonl for archival before changing DB. If this fails, DB stays untouched.
    jsonl_path = args.book_dir / f"{args.book_id}.chunks.jsonl"
    with open(jsonl_path, "w", encoding="utf-8") as f:
        for c, emb in zip(all_chunks, embeddings):
            row = {**c, "embedding_dim": len(emb)}
            f.write(json.dumps(row, ensure_ascii=False) + "\n")

    # Insert into DB atomically. Reindexing the same book removes stale chunks first.
    print("  [ingest] Inserting into DB...", flush=True)
    con = sqlite3.connect(DB_PATH)
    try:
        con.execute("BEGIN")
        con.execute("DELETE FROM chunks WHERE book_id = ?", (args.book_id,))
        con.execute(
            "INSERT OR REPLACE INTO books "
            "(book_id, author, title, edition, year, publisher) "
            "VALUES (?,?,?,?,?,?)",
            (
                args.book_id,
                args.author,
                args.title,
                args.edition,
                args.year,
                args.publisher,
            ),
        )
        for c, emb in zip(all_chunks, embeddings):
            emb_blob = np.array(emb, dtype=np.float32).tobytes()
            con.execute(
                "INSERT INTO chunks "
                "(chunk_id, book_id, page, chunk_text, embedding) "
                "VALUES (?,?,?,?,?)",
                (c["chunk_id"], c["book_id"], c["page"], c["chunk_text"], emb_blob),
            )
        con.execute("INSERT INTO chunks_fts(chunks_fts) VALUES('rebuild')")
        con.commit()
    except Exception:
        con.rollback()
        raise
    finally:
        con.close()

    print(f"  [ingest] Done. {len(all_chunks)} chunks indexed for book {args.book_id}", flush=True)


if __name__ == "__main__":
    main()
