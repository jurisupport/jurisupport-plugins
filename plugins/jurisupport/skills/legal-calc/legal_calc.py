#!/usr/bin/env python3
"""법률 날짜·금액 계산기. 결과마다 계산식과 근거 조문을 출력한다.

근거(국가법령정보센터 원문, 2026. 10. 29. 확인):
- 민법 제157조: 일·주·월·연 기간은 초일 불산입. 오전 0시부터 시작하면 산입.
- 민법 제159조: 기간말일의 종료로 만료.
- 민법 제160조: 주·월·연은 역에 의함. 최후의 주·월·연에서 기산일에 해당한 날의 전일로 만료. 해당일이 없으면 그 월의 말일.
- 민법 제161조: 말일이 토요일·공휴일이면 그 익일로 만료.
- 민사소송법 제170조: 기간 계산은 민법에 따름.
- 형사소송법 제66조: 초일 불산입. 다만 시효·구속기간은 초일을 1일로 산정. 말일이 공휴일·토요일이면 산입하지 않음(시효·구속기간 예외).
- 민법 제379조: 법정이율 연 5푼.
"""
import argparse, calendar, datetime as dt, json, os, sys, urllib.request
from decimal import Decimal, ROUND_FLOOR

D = dt.date
WD = "월화수목금토일"
CACHE = os.environ.get("LEGAL_CALC_CACHE_DIR") or os.path.join(os.path.expanduser("~"), ".cache", "legal-calc")
BUNDLED = os.path.join(os.path.dirname(os.path.abspath(__file__)), "holidays")
OFFLINE = os.environ.get("LEGAL_CALC_OFFLINE") == "1"

def p(s): return dt.date.fromisoformat(s.replace(".", "-").replace(" ", "").rstrip("-"))
def f(d): return f"{d.year}. {d.month}. {d.day}.({WD[d.weekday()]})"

# ---- 공휴일 ----
def _load(path):
    with open(path, encoding="utf-8") as fp: return json.load(fp)

def fetch_holidays(year):
    """한국천문연구원 특일정보(getRestDeInfo)를 k-skill-proxy로 받는다. 실패하면 None."""
    import re as _re
    base = os.environ.get("KSKILL_PROXY_BASE_URL", "https://k-skill-proxy.nomadamas.org")
    url = f"{base}/v1/korean-holiday/calendar?operation=rest&year={year}"
    try:
        with urllib.request.urlopen(url, timeout=20) as r: xml = r.read().decode()
        if "<resultCode>00</resultCode>" not in xml: return None
        out = []
        for it in _re.findall(r"<item>(.*?)</item>", xml):
            g = lambda k: (_re.search(f"<{k}>(.*?)</{k}>", it) or [None, ""])[1]
            if g("isHoliday") == "Y":
                ld = g("locdate"); out.append({"date": f"{ld[:4]}-{ld[4:6]}-{ld[6:]}", "name": g("dateName")})
        return out
    except Exception:
        return None

SOURCE = {}
def holidays(year):
    """공휴일 목록. 순서: 사용자 캐시 → 서버 조회(캐시에 저장) → 플러그인 동봉 자료. 모두 없으면 None."""
    c = os.path.join(CACHE, f"{year}.json")
    if os.path.exists(c):
        SOURCE[year] = "캐시"; return _load(c)
    if not OFFLINE:
        out = fetch_holidays(year)
        if out is not None:
            try:
                os.makedirs(CACHE, exist_ok=True)
                with open(c, "w", encoding="utf-8") as fp: json.dump(out, fp, ensure_ascii=False)
            except OSError:
                pass
            SOURCE[year] = "서버 조회"; return out
    b = os.path.join(BUNDLED, f"{year}.json")
    if os.path.exists(b):
        SOURCE[year] = "동봉 자료"; return _load(b)
    return None

HOL = {}
def hol_info(d, extra):
    if d.isoformat() in extra: return extra[d.isoformat()]
    if d.year not in HOL: HOL[d.year] = holidays(d.year)
    h = HOL[d.year]
    if h is None: return None  # 모름
    for x in h:
        if x["date"] == d.isoformat(): return x["name"] or "공휴일"
    return ""

def add_months(d, n):
    y, m = divmod(d.month - 1 + n, 12); y += d.year; m += 1
    last = calendar.monthrange(y, m)[1]
    return D(y, m, min(d.day, last)), d.day > last

# ---- 기간 만료일 ----
def deadline(a):
    start = p(a.start); n = a.n; unit = a.unit; steps = []
    crim = a.mode == "criminal"; special = crim and a.crim_kind in ("시효", "구속기간")
    include_first = a.include_first or special
    if include_first:
        base = start
        steps.append(f"기산일 {f(base)}: 초일 산입" + (f"(형사소송법 제66조 제1항 단서: {a.crim_kind})" if special else "(민법 제157조 단서 또는 지정)"))
    else:
        base = start + dt.timedelta(days=1)
        steps.append(f"사건일 {f(start)} → 초일 불산입, 기산일 {f(base)} ({'형사소송법 제66조 제1항' if crim else '민법 제157조'})")
    if unit == "일":
        end = base + dt.timedelta(days=n - 1)
        steps.append(f"말일 = 기산일 + {n}일 - 1일 = {f(end)}")
    elif unit == "주":
        end = base + dt.timedelta(days=7 * n - 1)
        steps.append(f"말일 = 기산일 + {n}주 - 1일 = {f(end)} (민법 제160조 제1항·제2항)")
    else:
        months = n * (12 if unit == "년" else 1)
        same, _ = add_months(base, months)
        # 기산일에 해당한 날이 최종 월에 있는지
        y, m = divmod(base.month - 1 + months, 12); y += base.year; m += 1
        last = calendar.monthrange(y, m)[1]
        if base.day == 1:
            end = D(y, m, 1) - dt.timedelta(days=1)
            steps.append(f"기산일이 월 초일 → {n}{unit} 뒤 전월 말일 {f(end)} (민법 제160조 제1항)")
        elif base.day > last:
            end = D(y, m, last)
            steps.append(f"최종 월에 기산일 해당일({base.day}일)이 없음 → 그 월 말일 {f(end)} (민법 제160조 제3항)")
        else:
            end = D(y, m, base.day) - dt.timedelta(days=1)
            steps.append(f"최종 월의 기산일 해당일 {f(D(y, m, base.day))}의 전일 = {f(end)} (민법 제160조 제2항)")
    raw = end
    extra = {}
    if a.holidays:
        for line in open(a.holidays, encoding="utf-8"):
            line = line.strip()
            if line and not line.startswith("#"): extra[line.split()[0]] = " ".join(line.split()[1:]) or "공휴일"
    unknown = False
    if special:
        steps.append(f"말일 연장 없음 (형사소송법 제66조 제3항 단서: {a.crim_kind})")
    else:
        while True:
            name = hol_info(end, extra)
            if end.weekday() == 5: why = "토요일"
            elif end.weekday() == 6: why = "일요일(공휴일)"
            elif name: why = f"공휴일({name})"
            else:
                if name is None: unknown = True
                break
            nxt = end + dt.timedelta(days=1)
            steps.append(f"말일 {f(end)}이 {why} → 다음 날 {f(nxt)} ({'형사소송법 제66조 제3항' if crim else '민법 제161조'})")
            end = nxt
    print("[기간 만료일]")
    for s in steps: print(" -", s)
    print(f"=> 만료일: {f(end)} 24:00" + (" (역 계산상 말일 " + f(raw) + ")" if end != raw else ""))
    if unknown: print(f"[미확인] {end.year}년 공휴일 목록을 받지 못했다. 만료일이 임시공휴일·대체공휴일인지 확인해야 한다. --holidays 파일로 넣을 수 있다.")
    used = sorted(y for y, s in SOURCE.items() if s == "동봉 자료")
    if used: print(f"[주의] {', '.join(map(str, used))}년 공휴일은 플러그인 동봉 자료(한국천문연구원 특일정보, 2026. 10. 29. 수신)로 판단했다. 그 뒤 지정된 임시공휴일은 반영되지 않았다.")

# ---- 일수 ----
def days(a):
    s, e = p(a.start), p(a.end)
    n = (e - s).days + (1 if a.inclusive else 0)
    print("[일수]")
    print(f" - {f(s)} ~ {f(e)}" + (": 양 끝 포함" if a.inclusive else ": 시작일 제외, 종료일 포함"))
    print(f" - ({e.isoformat()} - {s.isoformat()}){' + 1' if a.inclusive else ''} = {n}일")
    print(f"=> {n}일")

# ---- 이자·지연손해금 ----
def won(x): return f"{int(x):,}원"
def interest(a):
    principal = Decimal(a.principal.replace(",", ""))
    segs = []
    for s in a.seg:
        fr, to, rate = s.split(":")
        segs.append((p(fr), p(to), Decimal(rate)))
    total = Decimal(0)
    print("[이자·지연손해금] 일할 계산, 1년 = 365일(윤년도 365일), 구간마다 원 미만 버림")
    print(f" - 원금 {won(principal)}")
    for fr, to, rate in segs:
        n = (to - fr).days + 1
        v = (principal * rate / 100 * n / 365).quantize(Decimal(1), ROUND_FLOOR)
        total += v
        print(f" - {f(fr)} ~ {f(to)} ({n}일, 양 끝 포함) × 연 {rate}%: {int(principal):,} × {rate}% × {n}/365 = {won(v)}")
    print(f"=> 합계 {won(total)}" + (f", 원금 포함 {won(total + principal)}" if a.with_principal else ""))
    print("주의: 기간 양 끝 포함 여부, 윤년 366일 적용 여부, 단수 처리는 판결 주문·약정에 맞춰 확인한다. 이율은 근거 조문·판결을 따로 확인해 넣는다(민법 제379조 연 5%만 확인됨).")

def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sp = ap.add_subparsers(dest="cmd", required=True)
    d = sp.add_parser("deadline", help="기간 만료일")
    d.add_argument("start", help="사건일(송달일·고지일 등) YYYY-MM-DD")
    d.add_argument("n", type=int); d.add_argument("unit", choices=["일", "주", "월", "년"])
    d.add_argument("--mode", choices=["civil", "criminal"], default="civil")
    d.add_argument("--crim-kind", choices=["일반", "시효", "구속기간"], default="일반")
    d.add_argument("--include-first", action="store_true", help="초일 산입(오전 0시 시작 등)")
    d.add_argument("--holidays", help="추가 공휴일 파일(줄마다 'YYYY-MM-DD 이름')")
    d.set_defaults(fn=deadline)
    y = sp.add_parser("days", help="두 날짜 사이 일수")
    y.add_argument("start"); y.add_argument("end"); y.add_argument("--inclusive", action="store_true")
    y.set_defaults(fn=days)
    i = sp.add_parser("interest", help="이자·지연손해금")
    i.add_argument("principal")
    i.add_argument("--seg", action="append", required=True, help="시작:끝:연이율%% (예: 2025-11-05:2026-10-29:12)")
    i.add_argument("--with-principal", action="store_true")
    i.set_defaults(fn=interest)
    a = ap.parse_args(); a.fn(a)

if __name__ == "__main__":
    main()
