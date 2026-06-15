#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""클린 법률 DB 검색 — API 키·인터넷 불필요. SQLite FTS5(trigram) + 짧은어 LIKE 폴백.

사용법:
  python3 search.py "위법수집증거 증거능력"
  python3 search.py "배임"                # 2글자도 가능(LIKE 폴백)
  python3 search.py "유류분" --type 판례 --top 5
  python3 search.py "손해배상" --json
출력: 출처(법령 조문/판례 인용) + 발췌. 모든 자료는 출처표시 하 자유이용(공공누리1유형/§7).

DB 경로 결정 순서:
  1) 환경변수 CLEAN_LEGAL_DB
  2) ~/clean-legal-db/clean_legal.db   (install.sh 기본 설치 위치)
  3) 스크립트와 같은 폴더의 clean_legal.db (터미널 직접 사용·개발용)
"""
import sqlite3, sys, os, json, argparse, re

def _resolve_db():
    env = os.environ.get("CLEAN_LEGAL_DB")
    if env:
        return os.path.expanduser(env)
    home = os.path.expanduser("~/clean-legal-db/clean_legal.db")
    if os.path.exists(home):
        return home
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "clean_legal.db")

DB = _resolve_db()

def snippet(body, terms, width=240):
    pos = -1
    for t in terms:
        i = body.find(t)
        if i != -1 and (pos == -1 or i < pos): pos = i
    if pos == -1: pos = 0
    start = max(0, pos - 40)
    seg = body[start:start+width].replace("\n", " ").strip()
    return ("…" if start > 0 else "") + seg + "…"

def search(query, doctype=None, top=8):
    con = sqlite3.connect(DB); con.row_factory = sqlite3.Row
    terms = [t for t in re.split(r"\s+", query.strip()) if t]
    fts_terms = [t for t in terms if len(t) >= 3]
    rows = []
    if fts_terms:
        match = " AND ".join(f'"{t}"' for t in fts_terms)
        sql = ("SELECT d.*, bm25(docs_fts) AS rank FROM docs_fts "
               "JOIN docs d ON d.id = docs_fts.rowid WHERE docs_fts MATCH ?")
        params = [match]
        if doctype: sql += " AND d.doctype = ?"; params.append(doctype)
        sql += " ORDER BY rank LIMIT 200"
        rows = con.execute(sql, params).fetchall()
        short = [t for t in terms if len(t) < 3]
        if short:
            rows = [r for r in rows if all(s in (r["body"] or "") for s in short)]
    if not rows:  # 전부 짧은어이거나 FTS 무결과 → LIKE 폴백
        sql = "SELECT *, 0 AS rank FROM docs WHERE " + " AND ".join(["body LIKE ?"]*len(terms))
        params = [f"%{t}%" for t in terms]
        if doctype: sql += " AND doctype = ?"; params.append(doctype)
        sql += " ORDER BY length(body) LIMIT 200"
        rows = con.execute(sql, params).fetchall()
    con.close()
    return terms, rows[:top]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("query")
    ap.add_argument("--type", dest="doctype",
                    choices=["법령","자치법규","판례","헌재결정","행정심판재결","조세심판",
                             "노동위판정","행정규칙","개인정보위결정","법령해석"], default=None)
    ap.add_argument("--top", type=int, default=8)
    ap.add_argument("--json", action="store_true")
    a = ap.parse_args()
    if not os.path.exists(DB):
        print(f"DB 없음: {DB}", file=sys.stderr)
        print("설치: bash ~/jurisupport-plugins/toolkit/clean-legal-db/install.sh", file=sys.stderr)
        sys.exit(1)
    terms, rows = search(a.query, a.doctype, a.top)
    if a.json:
        out = [{"doctype":r["doctype"],"field":r["field"],"citation":r["citation"],
                "snippet":snippet(r["body"] or "", terms),"source":r["source"]} for r in rows]
        print(json.dumps(out, ensure_ascii=False, indent=1)); return
    if not rows:
        print(f'검색 결과 없음: "{a.query}"'); return
    print(f'🔎 "{a.query}"  결과 {len(rows)}건\n')
    icons = {"법령":"📘 법령","자치법규":"📙 자치","판례":"⚖️ 판례","헌재결정":"🏛 헌재",
             "행정심판재결":"🧷 재결","조세심판":"💰 조세심판","노동위판정":"👷 노동위","행정규칙":"📕 행정규칙",
             "개인정보위결정":"🔐 개인정보위","법령해석":"📑 해석"}
    for i, r in enumerate(rows, 1):
        tag = icons.get(r["doctype"], r["doctype"])
        print(f"[{i}] {tag} · {r['field']}  —  {r['citation']}")
        print(f"    {snippet(r['body'] or '', terms)}")
        print(f"    └ 출처: {r['source']}\n")

if __name__ == "__main__":
    main()
