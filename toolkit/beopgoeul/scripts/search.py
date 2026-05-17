#!/usr/bin/env python3
"""
법고을 (lx.scourt.go.kr) 판례 자동 검색.

Usage:
    python3 search.py "소멸시효 채무승인"
    python3 search.py "민법 750조" --max 10 --format json
    python3 search.py "2024다302217"   # 사건번호 직접

Output:
    기본 (text): 표 형식
    json: JSON 배열

Selenium + Chrome headless 사용. 사이트 부하 고려하여 결과는 최대 20건으로 제한.
"""

import argparse
import json
import re
import sys
import time
from typing import List, Dict, Optional
from urllib.parse import unquote

from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC

BASE_URL = "https://lx.scourt.go.kr"
MAX_RESULTS_HARD_CAP = 20


def parse_pdf_url(href: str) -> Optional[str]:
    """showPrecedentPDFView('/data_lib/.../filename.pdf', `name`) → 절대 URL."""
    m = re.search(r"showPrecedentPDFView\(['\"]([^'\"]+)['\"]", href or "")
    if not m:
        return None
    return BASE_URL + m.group(1)


def parse_meta_from_title(title: str) -> Dict[str, str]:
    """e.g. '서울고등법원 2020. 5. 27. 자 2019라2172 결정 [소송비용액확정]'
    → court, decided_date, case_no, decision_type, case_name."""
    out = {"court": "", "decided_date": "", "case_no": "", "decision_type": "", "case_name": ""}
    if not title:
        return out
    # case_name in brackets
    m = re.search(r"\[(.+?)\]\s*$", title)
    if m:
        out["case_name"] = m.group(1).strip()
        title_wo = title[: m.start()].strip()
    else:
        title_wo = title
    # case_no: pattern like 2019라2172 / 2024다302217
    m = re.search(r"(20[0-9]{2}[가-힣]{1,3}[0-9]+)", title_wo)
    if m:
        out["case_no"] = m.group(1)
    # decided_date: YYYY. M. D.
    m = re.search(r"(\d{4}\.\s*\d{1,2}\.\s*\d{1,2}\.)", title_wo)
    if m:
        out["decided_date"] = m.group(1).replace(" ", "")
    # decision_type: 판결 / 결정 / 명령
    m = re.search(r"(판결|결정|명령|선고)", title_wo)
    if m:
        out["decision_type"] = m.group(1)
    # court: 첫 단어 (e.g. 서울고등법원)
    m = re.match(r"(\S+법원|대법원|헌법재판소)", title_wo)
    if m:
        out["court"] = m.group(1)
    return out


def search(query: str, max_results: int = 5) -> List[Dict]:
    max_results = min(max_results, MAX_RESULTS_HARD_CAP)

    opts = Options()
    opts.add_argument("--headless=new")
    opts.add_argument("--disable-gpu")
    opts.add_argument("--no-sandbox")
    opts.add_argument("--window-size=1400,1800")
    opts.add_argument(
        "--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        "AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
    )

    driver = webdriver.Chrome(options=opts)
    driver.set_page_load_timeout(30)
    results = []

    try:
        driver.get(BASE_URL + "/")
        time.sleep(1.5)

        # Search
        si = WebDriverWait(driver, 10).until(
            EC.presence_of_element_located((By.ID, "search_txt"))
        )
        si.clear()
        si.send_keys(query)
        driver.find_element(By.ID, "btn_search").click()

        # Wait for result container — search results live under .search_result_list or similar
        time.sleep(2)
        # Wait until at least one javascript:showPrecedentPDFView link exists (result loaded)
        try:
            WebDriverWait(driver, 15).until(
                lambda d: len(d.find_elements(By.CSS_SELECTOR, "a[href*='showPrecedentPDFView']")) > 0
            )
        except Exception:
            pass
        time.sleep(2)  # extra settle

        # Result cards: each .tit that contains a precedent link
        all_tits = driver.find_elements(By.CSS_SELECTOR, ".tit")
        cards = []
        for t in all_tits:
            links = t.find_elements(By.CSS_SELECTOR, "a[href*='showPrecedentPDFView']")
            if links:
                cards.append(t)
        if not cards:
            # fallback: any a tag with showPrecedentPDFView
            link_elems = driver.find_elements(By.CSS_SELECTOR, "a[href*='showPrecedentPDFView']")
            cards = [le.find_element(By.XPATH, "./..") for le in link_elems[: max_results * 2]]
        for card in cards[: max_results * 2]:  # over-fetch then filter
            try:
                # court badge
                try:
                    court_span = card.find_element(By.CSS_SELECTOR, "span.ctg")
                    court = court_span.text.strip()
                except Exception:
                    court = ""
                # title link
                try:
                    link = card.find_element(By.CSS_SELECTOR, "a")
                except Exception:
                    continue
                title = link.text.strip()
                if not title:
                    continue
                href = link.get_attribute("href") or ""
                pdf_url = parse_pdf_url(href)

                meta = parse_meta_from_title(title)
                if court and not meta["court"]:
                    meta["court"] = court

                # Summary (sibling .txt_wrap)
                summary = ""
                try:
                    parent = card.find_element(By.XPATH, "./..")
                    sib = parent.find_element(By.CSS_SELECTOR, ".txt_wrap")
                    summary = sib.text.strip()[:400]
                except Exception:
                    pass

                results.append({
                    "title": title,
                    "court": meta["court"],
                    "case_no": meta["case_no"],
                    "decided_date": meta["decided_date"],
                    "decision_type": meta["decision_type"],
                    "case_name": meta["case_name"],
                    "pdf_url": pdf_url,
                    "summary": summary,
                })
                if len(results) >= max_results:
                    break
            except Exception as e:
                print(f"  [warn] card parse failed: {e}", file=sys.stderr)
                continue
    finally:
        driver.quit()

    return results


def format_text(results: List[Dict]) -> str:
    if not results:
        return "검색 결과 없음."
    out = []
    for i, r in enumerate(results, 1):
        out.append(f"\n[{i}] {r['title']}")
        out.append(f"    법원        : {r['court']}")
        out.append(f"    사건번호    : {r['case_no']}")
        out.append(f"    선고/결정일 : {r['decided_date']} ({r['decision_type']})")
        if r['case_name']:
            out.append(f"    사건명      : {r['case_name']}")
        if r['pdf_url']:
            out.append(f"    PDF URL     : {r['pdf_url']}")
        if r['summary']:
            out.append(f"    요약        : {r['summary'][:200]}")
    return "\n".join(out)


def main():
    ap = argparse.ArgumentParser(description="법고을 판례 검색 (Selenium 자동)")
    ap.add_argument("query", help="검색어 또는 사건번호")
    ap.add_argument("--max", type=int, default=5, help=f"최대 결과 (기본 5, 최대 {MAX_RESULTS_HARD_CAP})")
    ap.add_argument("--format", choices=["text", "json"], default="text")
    args = ap.parse_args()

    try:
        results = search(args.query, max_results=args.max)
    except Exception as e:
        print(f"[error] {e}", file=sys.stderr)
        sys.exit(1)

    if args.format == "json":
        print(json.dumps(results, ensure_ascii=False, indent=2))
    else:
        print(format_text(results))
        print(f"\n총 {len(results)}건. PDF는 위 URL을 브라우저에서 직접 다운로드하세요.")


if __name__ == "__main__":
    main()
