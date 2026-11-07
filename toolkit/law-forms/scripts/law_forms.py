#!/usr/bin/env python3
"""법령 별지서식을 요청 시점에 법제처에서 받아 kordoc으로 hwpx 변환·채우기·PDF 렌더까지 한다.

  law_forms.py search 동석신청서 [--law 공소청사건사무규칙]
  law_forms.py get "공소청사건사무규칙:003700"          # 받기 + hwpx 변환 + 칸 목록
  law_forms.py fill "공소청사건사무규칙:003700" --data in.json [--slots slots.json] --out both -o 출력폴더

  서식 서재(자주 쓰는 서식 + 칸 매핑 + 노하우):
  law_forms.py library list
  law_forms.py library show 주민초본-7호
  law_forms.py library add 주민초본-7호 --from "주민등록법 시행규칙:000700" --recipe recipe.json --notes 노하우.md
  law_forms.py library check                           # 서재 서식이 현행 서식과 같은지 확인
  law_forms.py fill 주민초본-7호 --data 값.json -o 출력폴더   # 값.json은 recipe의 필드 이름으로 쓴다

환경변수: LAW_OC(법제처 Open API 인증키), KORDOC(kordoc 실행 파일, 기본 npx -y kordoc@4.24.37),
          CHROME(PDF 렌더용 Chrome 경로), LAW_FORMS_HOME(기본 ~/law-forms),
          LAW_FORMS_LIBRARY(공용 서재, 기본 ~/law-forms/shared-library), LAW_FORMS_MY_LIBRARY(개인 서재, 기본 ~/law-forms/library)
법제처 키는 LAW_OC 환경변수가 없으면 ~/law-forms/config.json의 LAW_OC를 읽는다.
"""
import argparse, hashlib, json, os, re, shlex, shutil, subprocess, sys, tempfile, urllib.parse, urllib.request, zipfile
from pathlib import Path

API = "https://www.law.go.kr/DRF/lawSearch.do"
BASE = "https://www.law.go.kr"
HOME = Path(os.environ.get("LAW_FORMS_HOME", "~/law-forms")).expanduser()
CACHE = Path(os.environ.get("LAW_FORMS_CACHE", HOME / "cache")).expanduser()
_local_kordoc = HOME / "node" / "node_modules" / ".bin" / "kordoc"      # install.sh가 kordoc + puppeteer-core를 여기에 설치
KORDOC = shlex.split(os.environ.get("KORDOC", str(_local_kordoc) if _local_kordoc.exists() else "npx -y kordoc@4.24.37"))
CHROME = os.environ.get("CHROME") or next((c for c in (
    "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
    "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
    "/usr/bin/google-chrome", "/usr/bin/chromium", "/usr/bin/chromium-browser") if Path(c).exists()), "")
LIBRARIES = [Path(os.environ.get("LAW_FORMS_MY_LIBRARY", HOME / "library")).expanduser(),          # 개인 서재(먼저 찾음)
             Path(os.environ.get("LAW_FORMS_LIBRARY", HOME / "shared-library")).expanduser()]   # 공용 서재(플러그인 배포본)


def lib_dir(form_id):
    """개인 서재를 먼저 보고, 없으면 공용 서재를 본다."""
    for lib in LIBRARIES:
        if (lib / form_id / "recipe.json").exists():
            return lib / form_id
    return None


def oc():
    key = os.environ.get("LAW_OC")
    cfg = HOME / "config.json"
    if not key and cfg.exists():
        key = json.loads(cfg.read_text()).get("LAW_OC")
    if not key:
        sys.exit("법제처 Open API 인증키(OC)가 없습니다. LAW_OC 환경변수나 ~/law-forms/config.json에 넣어 주세요.")
    return key


def api(query, search, page=1):
    q = urllib.parse.urlencode({"OC": oc(), "target": "licbyl", "type": "JSON", "search": search,
                                "knd": 2, "display": 100, "page": page, "query": query})
    with urllib.request.urlopen(f"{API}?{q}", timeout=30) as r:
        d = json.load(r)["licBylSearch"]
    rows = d.get("licbyl", [])
    return int(d.get("totalCnt") or 0), [rows] if isinstance(rows, dict) else rows


def byl_label(seq):
    """bylSeq 003700 → 제37호, 022202 → 제222호의2"""
    main, sub = int(seq[:4]), int(seq[4:])
    return f"제{main}호" + (f"의{sub}" if sub else "")


def key_of(r):
    return f"{r['관련법령명']}:{r['별표번호']}"


def search(query, law=None):
    total, rows = api(query, 1)
    rows = [r for r in rows if not r["별표명"].startswith("삭제")]
    if law:
        rows = [r for r in rows if law in r["관련법령명"]]
    return total, rows


def find(key):
    law, seq = key.rsplit(":", 1)
    page = 1
    while True:
        total, rows = api(law, 2, page)
        for r in rows:
            if r["관련법령명"] == law and r["별표번호"] == seq:
                return r
        if page * 100 >= total:
            sys.exit(f"서식을 찾지 못했습니다: {key}")
        page += 1


def download(url, out):
    req = urllib.request.Request(BASE + url, headers={"User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=60) as r:
        out.write_bytes(r.read())


def kordoc(*args, capture=False):
    p = subprocess.run([*KORDOC, *map(str, args)], capture_output=True, text=True)
    if p.returncode not in (0, 2):
        sys.exit(f"kordoc 실패: {' '.join(map(str, args[:2]))}\n{p.stderr[-800:]}")
    return p.stdout if capture else p.stderr.strip().splitlines()[-1:]


def get_local(path):
    """법원 전산양식처럼 법제처 밖에서 받은 hwp·hwpx 파일. 같은 이름의 PDF가 옆에 있으면 공식 PDF로 쓴다."""
    import hashlib
    src = Path(path)
    sha = hashlib.sha256(src.read_bytes()).hexdigest()
    d = CACHE / "local" / sha[:16]
    d.mkdir(parents=True, exist_ok=True)
    form = d / "form.hwpx"
    if not form.exists():
        if zipfile.is_zipfile(src):
            form.write_bytes(src.read_bytes())
        else:
            kordoc("to-hwpx", src, "-o", form)
        pdf = src.with_suffix(".pdf")
        if pdf.exists():
            (d / "official.pdf").write_bytes(pdf.read_bytes())
        meta = {"key": str(src), "별지": "", "서식명": src.stem, "원본형식": "hwpx" if zipfile.is_zipfile(src) else "hwp",
                "sha256": sha}
        (d / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1))
    return d


def get(key):
    if lib_dir(key):
        d = lib_dir(key)
        meta = json.loads((d / "meta.json").read_text())
        meta["폴더"] = str(d)
        meta["서재"] = True
        return meta, d
    if Path(key).is_file():
        d = get_local(key)
        form = d / "form.hwpx"
    else:
        d, form = get_law(key)
    meta = json.loads((d / "meta.json").read_text())
    meta["폴더"] = str(d)
    out = kordoc("fill", form, "--dry-run", "--silent", capture=True)
    try:
        meta["칸"] = [f["label"] for f in json.loads(out)["fields"]]
    except Exception:
        meta["칸"] = []                         # 표가 없는 서식: 본문 빈칸(slots)으로만 채운다
    return meta, d


def get_law(key):
    r = find(key)
    d = CACHE / r["관련법령ID"] / r["별표번호"] / r["공포일자"]
    d.mkdir(parents=True, exist_ok=True)
    meta = {"key": key_of(r), "법령명": r["관련법령명"], "법령종류": r["법령종류"], "별지": byl_label(r["별표번호"]),
            "서식명": r["별표명"], "공포일자": r["공포일자"], "소관부처": r["소관부처명"]}
    form = d / "form.hwpx"
    if not form.exists():
        src = d / "source.bin"
        download(r["별표서식파일링크"], src)
        if r.get("별표서식PDF파일링크"):
            download(r["별표서식PDF파일링크"], d / "official.pdf")
        if zipfile.is_zipfile(src):            # 이미 hwpx로 받은 경우
            src.rename(form)
            meta["원본형식"] = "hwpx"
        else:
            hwp = src.rename(d / "source.hwp")
            kordoc("to-hwpx", hwp, "-o", form)
            meta["원본형식"] = "hwp"
        (d / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1))
    return d, form


def fill_slots(src, out, slots):
    """본문의 공백 빈칸을 값으로 바꾼다. 빈칸 폭(한글 2, 그 외 1)을 유지한다."""
    import unicodedata
    width = lambda s: sum(2 if unicodedata.east_asian_width(c) in "WF" else 1 for c in s)
    zin = zipfile.ZipFile(src)
    xml = zin.read("Contents/section0.xml").decode("utf-8")
    missed = []
    for s in slots:
        m = re.search("(" + re.escape(s["before"]) + r")( {2,})(?=" + re.escape(s["after"]) + ")", xml)
        if not m:
            missed.append(s); continue
        blank = m.group(2)
        val = " " + s["value"] + " " * max(len(blank) - width(s["value"]) - 1, 1)
        xml = xml[:m.start(2)] + val + xml[m.end(2):]
    xml = re.sub(r"<hp:linesegarray>.*?</hp:linesegarray>", "", xml, flags=re.S)
    with zipfile.ZipFile(out, "w") as z:
        for i in zin.infolist():
            data = xml.encode() if i.filename == "Contents/section0.xml" else zin.read(i.filename)
            z.writestr(i, data, compress_type=zipfile.ZIP_STORED if i.filename == "mimetype" else zipfile.ZIP_DEFLATED)
    return missed


def pages(pdf):
    try:
        import fitz
        with fitz.open(pdf) as doc:
            return doc.page_count
    except ImportError:
        pass
    try:
        out = subprocess.run(["pdfinfo", str(pdf)], capture_output=True, text=True).stdout
    except FileNotFoundError:
        return None                             # 쪽수 대조를 건너뛴다
    m = re.search(r"Pages:\s+(\d+)", out)
    return int(m.group(1)) if m else None


def compile_recipe(recipe, values):
    """recipe 필드 이름으로 쓴 값을 kordoc fill JSON과 바꾸기 목록으로 바꾼다."""
    fill_json, spec, warns = {}, {"replace": [], "slots": []}, []
    for name, v in values.items():
        f = recipe["fields"].get(name)
        if f is None:
            warns.append(f"recipe에 없는 필드: {name}"); continue
        if f.get("limit") and isinstance(v, str) and len(v) > f["limit"]:
            warns.append(f"{name}: {len(v)}자 — 권장 {f['limit']}자 이하({f.get('limit_note', '칸이 좁음')})")
        how = f["how"]
        if how == "fill":
            arr = fill_json.setdefault(f["key"], [])
            arr.extend([""] * (f.get("index", 0) + 1 - len(arr)))
            arr[f.get("index", 0)] = v
        elif how == "fill_list":                # 표의 열 제목 아래로 행마다 하나씩 (예: 서류 등의 목록)
            if f.get("max_rows") and len(v) > f["max_rows"]:
                warns.append(f"{name}: {len(v)}행 — 표는 {f['max_rows']}행까지")
            fill_json[f["key"]] = list(v)
        elif how == "replace":
            text = v.replace("\n", "<br>- ") if isinstance(v, str) else v  # 줄마다 「- 」를 붙여 같은 모양을 유지
            spec["replace"].append({"find": f["find"], "value": f["template"].replace("{value}", text), "count": f.get("count", 1)})
        elif how == "slot":
            spec["slots"].append({"before": f["before"], "after": f["after"], "value": v})
        elif how == "check":                    # v: 고를 항목 목록. 그 줄의 「□ 항목」·「[ ]항목」을 체크로 바꾼다
            line, opts = f["line"], f["options"]
            for opt in ([v] if isinstance(v, str) else v):
                if opt not in opts:
                    warns.append(f"{name}: 고를 수 없는 항목 {opt} (가능: {', '.join(opts)})"); continue
                text = opts[opt] if isinstance(opts, dict) else opt   # dict면 별칭 → 서식 문구
                line = line.replace(f["mark"] + text, f["checked"] + text, 1)
            spec["replace"].append({"find": f["line"], "value": line})
    for k, arr in fill_json.items():            # 배열이 1칸이면 값 하나로
        if isinstance(arr, list) and len(arr) == 1 and not any(recipe["fields"][n]["how"] == "fill_list" and recipe["fields"][n]["key"] == k for n in recipe["fields"]):
            fill_json[k] = arr[0]
    for f in recipe.get("defaults", []):        # 늘 같은 값(날짜 형식 등)은 recipe에 둔다
        spec["replace"].append(f)
    spec["drop"] = recipe.get("빼는_부분", [])   # 내지 않아도 되는 안내 쪽(처리절차·유의사항 등)
    return fill_json, spec, warns


def drop_parts(md, drops):
    """표 단위(표_포함) 또는 표시 문구부터 끝까지(부터) 마크다운에서 지운다."""
    missed = []
    for dp in drops:
        if "pdf_쪽" in dp:                      # hwpx에서 못 지우는 쪽은 PDF에서만 뺀다
            continue
        if "표_포함" in dp:
            hit = next((m for m in re.finditer(r"<table>.*?</table>", md, flags=re.S) if dp["표_포함"] in m.group(0)), None)
            if hit:
                md = md[:hit.start()] + md[hit.end():]; continue
        elif "부터" in dp and dp["부터"] in md:
            md = md[:md.index(dp["부터"])].rstrip() + "\n"; continue
        missed.append(dp)
    return md, missed


def fill(key, data, slots, out_kind, outdir, all_pages=False):
    meta, d = get(key)
    outdir.mkdir(parents=True, exist_ok=True)
    name = re.sub(r"[\\/:*?\"<>|]", "_", "_".join(x for x in (meta["별지"], meta["서식명"]) if x))[:80]
    hwpx = outdir / f"{name}.hwpx"
    tmp = Path(tempfile.mkdtemp(prefix="law-forms-"))
    stage = tmp / "stage.hwpx"
    warns = []
    recipe = json.loads((d / "recipe.json").read_text()) if (d / "recipe.json").exists() else None
    spec = json.load(open(slots)) if slots else {}
    if isinstance(spec, list):                  # 예전 형식: 공백 빈칸 목록만
        spec = {"slots": spec}
    if meta.get("서재") and data:               # 서재 서식: recipe 필드 이름으로 쓴 값을 바꾼다
        fill_json, rspec, warns = compile_recipe(recipe, json.load(open(data)))
        data = tmp / "fill.json"; data.write_text(json.dumps(fill_json, ensure_ascii=False))
        for k in ("replace", "slots"):
            spec[k] = rspec[k] + spec.get(k, [])
        spec["drop"] = rspec["drop"]
    if data:
        kordoc("fill", d / "form.hwpx", "-j", data, "-o", stage, "--silent")
    else:
        stage.write_bytes((d / "form.hwpx").read_bytes())
    missed = []
    drops = [] if all_pages else spec.get("drop", [])
    if spec.get("replace") or drops:            # 자리표시 글자(000, 0000-00000 등)는 kordoc patch로 바꾼다
        md = kordoc(stage, "--keep-layout-tables", capture=True)
        for r in spec.get("replace", []):
            if r["find"] in md:
                md = md.replace(r["find"], r["value"], r.get("count", 1))
            else:
                missed.append(r)
        md, dmiss = drop_parts(md, drops)
        missed += dmiss
        edit = tmp / "stage.md"; edit.write_text(md)
        patched = tmp / "stage.patched.hwpx"
        kordoc("patch", stage, edit, "-o", patched, "--silent")
        patched.replace(stage)
    if spec.get("slots"):
        missed += fill_slots(stage, hwpx, spec["slots"])
    else:
        hwpx.write_bytes(stage.read_bytes())
    shutil.rmtree(tmp)
    kordoc("validate", hwpx)
    result = {"hwpx": str(hwpx), "못_채운_빈칸": missed}
    if warns:
        result["주의"] = warns
    if out_kind in ("pdf", "both"):
        pdf = outdir / f"{name}.pdf"
        if not CHROME:
            sys.exit("PDF 렌더에 쓸 Chrome/Chromium을 찾지 못했습니다. CHROME 환경변수로 경로를 지정하거나 --out hwpx로 실행하세요.")
        kordoc("render", hwpx, "--format", "pdf", "--browser", CHROME, "-o", pdf)
        result["pdf"] = str(pdf)
        pdf_drop = sorted({n for dp in drops for n in dp.get("pdf_쪽", [])}, reverse=True)
        if pdf_drop:
            try:
                import fitz
            except ImportError:
                sys.exit("PDF 쪽 빼기에 PyMuPDF가 필요합니다: python3 -m pip install --user pymupdf")
            doc = fitz.open(pdf)
            for n in pdf_drop:
                if n <= doc.page_count:
                    doc.delete_page(n - 1)
            doc.save(str(pdf) + ".tmp"); doc.close(); os.replace(str(pdf) + ".tmp", pdf)
        off = d / "official.pdf"
        base = (pages(off) if off.exists() else None) or (recipe or {}).get("기준_쪽수")   # 공식 PDF가 없으면 recipe 기준
        if base and pages(pdf):
            expect = base - sum(dp.get("쪽", 1) for dp in drops)
            if expect != pages(pdf):
                result["경고"] = f"쪽수가 예상과 다릅니다: 기준 {base}쪽에서 안내 쪽 {base - expect}쪽을 빼면 {expect}쪽, 결과 {pages(pdf)}쪽"
        if drops:
            result["뺀_쪽"] = [dp.get("설명", "") for dp in drops]
    if out_kind == "pdf":
        hwpx.unlink(); result.pop("hwpx")
    return result


def lib_add(form_id, src_key, recipe, notes, shared):
    """현재 서식(법제처 키 또는 파일)을 서재에 넣는다. recipe와 노하우를 함께 둔다."""
    meta, d = get(src_key)
    lib = LIBRARIES[-1] if shared and len(LIBRARIES) > 1 else LIBRARIES[0]
    dest = lib / form_id
    dest.mkdir(parents=True, exist_ok=True)
    for f in ("form.hwpx", "official.pdf"):
        if (d / f).exists():
            shutil.copy2(d / f, dest / f)
    meta = {k: v for k, v in meta.items() if k not in ("폴더", "칸")}
    meta["form_sha256"] = hashlib.sha256((dest / "form.hwpx").read_bytes()).hexdigest()
    (dest / "meta.json").write_text(json.dumps(meta, ensure_ascii=False, indent=1))
    shutil.copy2(recipe, dest / "recipe.json")
    if notes:
        shutil.copy2(notes, dest / "노하우.md")
    return dest


def lib_list():
    rows = []
    for lib in LIBRARIES:
        for r in sorted(lib.glob("*/recipe.json")):
            if any(x["id"] == r.parent.name for x in rows):
                continue                        # 개인 서재가 공용 서재보다 먼저
            rc = json.loads(r.read_text()); meta = json.loads((r.parent / "meta.json").read_text())
            rows.append({"id": r.parent.name, "서식": "_".join(x for x in (meta.get("별지"), meta.get("서식명")) if x),
                         "출처": meta.get("법령명") or rc.get("출처", ""), "언제": rc.get("언제", ""), "서재": str(lib)})
    return rows


def lib_check():
    """법제처 서식은 현행 공포일자와 서재 공포일자를 비교한다."""
    out = []
    for row in lib_list():
        meta = json.loads((lib_dir(row["id"]) / "meta.json").read_text())
        if not meta.get("공포일자"):
            out.append((row["id"], "법제처 밖 서식 — 원 출처에서 직접 확인")); continue
        cur = find(meta["key"])["공포일자"]
        out.append((row["id"], "현행과 같음" if cur == meta["공포일자"] else f"개정됨: 서재 {meta['공포일자']} → 현행 {cur}"))
    return out


def main():
    ap = argparse.ArgumentParser(description="법령 별지서식 검색·변환·채우기")
    sub = ap.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("search"); s.add_argument("query"); s.add_argument("--law")
    g = sub.add_parser("get"); g.add_argument("key")
    f = sub.add_parser("fill"); f.add_argument("key"); f.add_argument("--data"); f.add_argument("--slots")
    f.add_argument("--out", choices=["hwpx", "pdf", "both"], default="both"); f.add_argument("-o", default=".")
    f.add_argument("--all-pages", action="store_true", help="처리절차·유의사항 같은 안내 쪽도 남긴다")
    lb = sub.add_parser("library"); lsub = lb.add_subparsers(dest="lcmd", required=True)
    lsub.add_parser("list"); lsub.add_parser("check")
    ls = lsub.add_parser("show"); ls.add_argument("id")
    la = lsub.add_parser("add"); la.add_argument("id"); la.add_argument("--from", dest="src", required=True)
    la.add_argument("--recipe", required=True); la.add_argument("--notes"); la.add_argument("--shared", action="store_true")
    a = ap.parse_args()
    if a.cmd == "library":
        if a.lcmd == "list":
            for r in lib_list():
                print(f"  {r['id']}\t{r['서식']}\t{r['언제']}")
        elif a.lcmd == "check":
            for i, msg in lib_check():
                print(f"  {i}\t{msg}")
        elif a.lcmd == "show":
            d = lib_dir(a.id) or sys.exit(f"서재에 없습니다: {a.id}")
            rc = json.loads((d / "recipe.json").read_text())
            print(f"# {a.id}\n언제: {rc.get('언제', '')}\n\n## 필드")
            for k, f in rc["fields"].items():
                extra = f" (고를 수 있는 항목: {', '.join(f['options'])})" if f["how"] == "check" else ""
                print(f"- {k}: {f.get('설명', '')}{extra}" + (f" [권장 {f['limit']}자 이하]" if f.get("limit") else ""))
            if (d / "노하우.md").exists():
                print("\n" + (d / "노하우.md").read_text())
        else:
            print(lib_add(a.id, a.src, a.recipe, a.notes, a.shared))
        return
    if a.cmd == "search":
        total, rows = search(a.query, a.law)
        print(f"검색 결과 {len(rows)}건 (삭제 서식 제외, 법제처 전체 {total}건)")
        for r in rows:
            print(f"  {key_of(r)}\t{byl_label(r['별표번호'])}\t{r['별표명']}\t공포 {r['공포일자']}")
    elif a.cmd == "get":
        meta, _ = get(a.key)
        print(json.dumps(meta, ensure_ascii=False, indent=1))
    else:
        print(json.dumps(fill(a.key, a.data, a.slots, a.out, Path(a.o), a.all_pages), ensure_ascii=False, indent=1))


if __name__ == "__main__":
    main()
