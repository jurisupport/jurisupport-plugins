#!/usr/bin/env python3
"""Search the local case-records API without exposing the API token in argv."""

from __future__ import annotations

import argparse
import json
import os
import sys
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path


TOKEN_PATH = Path(os.path.expanduser("~/.jurisupport/case-records.token"))
LOOPBACK_HOSTS = {"localhost", "127.0.0.1", "::1"}


def read_token() -> str:
    token = os.environ.get("CASE_RECORDS_API_TOKEN", "").strip()
    if token:
        return token
    try:
        return TOKEN_PATH.read_text(encoding="utf-8").strip()
    except OSError:
        return ""


def main() -> int:
    parser = argparse.ArgumentParser(description="Search the local case-records API.")
    parser.add_argument("query", nargs="?", help="Search query.")
    parser.add_argument("--query", dest="query_opt", help="Search query.")
    parser.add_argument("--top-k", type=int, default=5)
    parser.add_argument("--doc-type", default="")
    parser.add_argument("--case-id", default="")
    parser.add_argument("--url", default="http://localhost:8767/search")
    args = parser.parse_args()

    query = args.query_opt or args.query
    if not query:
        parser.error("query is required")

    token = read_token()
    if not token:
        print(
            "case-records API token not found. Re-run toolkit/case-records/install.sh.",
            file=sys.stderr,
        )
        return 2

    parsed_url = urllib.parse.urlparse(args.url)
    if parsed_url.scheme != "http" or parsed_url.hostname not in LOOPBACK_HOSTS:
        print(
            "refusing to send case-records token to a non-loopback URL",
            file=sys.stderr,
        )
        return 2

    filters = {}
    if args.doc_type:
        filters["doc_type"] = args.doc_type
    if args.case_id:
        filters["case_id"] = args.case_id

    payload = {"query": query, "top_k": args.top_k, "filters": filters}
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        args.url,
        data=body,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        method="POST",
    )

    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            sys.stdout.buffer.write(response.read())
            sys.stdout.write("\n")
        return 0
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        print(f"case-records search failed: HTTP {exc.code} {detail}", file=sys.stderr)
        return 1
    except urllib.error.URLError as exc:
        print(f"case-records server unavailable: {exc.reason}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
