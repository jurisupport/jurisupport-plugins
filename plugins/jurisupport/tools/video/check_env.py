"""영상 스킬 환경 점검.

사용: python3 check_env.py [--mode explainer|narration]
없는 항목마다 설정 안내 페이지의 해당 절을 알려 준다. 아무것도 설치하지 않는다.
"""
import os
import shutil
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import SETUP_DOC, find_font, get_key, is_mac  # noqa: E402

mode = "explainer"
if "--mode" in sys.argv:
    mode = sys.argv[sys.argv.index("--mode") + 1]

rows = []  # (항목, 상태, 필수 여부, 안내 절)


def add(name, ok, required, anchor, note=""):
    rows.append((name, ok, required, anchor, note))


add("Python 3.9 이상", sys.version_info >= (3, 9), True, "1-python", sys.version.split()[0])

try:
    import PIL  # noqa: F401
    add("Pillow(그림 처리)", True, True, "2-pillow", PIL.__version__)
except ImportError:
    add("Pillow(그림 처리)", False, True, "2-pillow")

ff = shutil.which("ffmpeg")
zoom = False
if ff:
    r = subprocess.run([ff, "-hide_banner", "-filters"], capture_output=True, text=True)
    zoom = " zoompan " in r.stdout
add("ffmpeg(영상 조립)", bool(ff), True, "3-ffmpeg", ff or "")
if ff and mode != "explainer":
    add("ffmpeg zoompan 필터", zoom, True, "3-ffmpeg")

if mode == "explainer":   # 조각 애니메이션: numpy(조각 처리) + Playwright 브라우저(렌더)
    try:
        import numpy  # noqa: F401
        add("numpy(조각 처리)", True, True, "7-cutout", numpy.__version__)
    except ImportError:
        add("numpy(조각 처리)", False, True, "7-cutout")
    try:
        from playwright.sync_api import sync_playwright
        ok, note = False, ""
        with sync_playwright() as p:
            for kw in ({}, {"channel": "chrome"}):
                try:
                    p.chromium.launch(**kw).close()
                    ok, note = True, "Chrome" if kw else "Chromium"
                    break
                except Exception:
                    continue
        add("Playwright(렌더)", True, True, "7-cutout")
        add("렌더용 브라우저(Chromium 또는 Chrome)", ok, True, "7-cutout", note)
    except ImportError:
        add("Playwright(렌더)", False, True, "7-cutout")

font = find_font()
add("한글 글꼴(자막·정보판)", bool(font), True, "4-font", font or "")

g, o = get_key("gemini"), get_key("openai")
add("Gemini API 키(음성·그림)", bool(g), False, "5-api-key", "있음" if g else "")
add("OpenAI API 키(그림·음성 대안)", bool(o), False, "5-api-key", "있음" if o else "")
say = is_mac() and bool(shutil.which("say"))
add("macOS 음성(say, 무료 시험용)", say, False, "6-free-voice")

print(f"영상 스킬 환경 점검 ({mode})\n")
for name, ok, req, anchor, note in rows:
    mark = "OK " if ok else ("없음" if req else "선택")
    print(f"  [{mark}] {name}" + (f"  {note}" if note else ""))

missing = [r for r in rows if r[2] and not r[1]]
voice = bool(g or o or say)
image = bool(g or o)
print()
if missing:
    print("[필수 항목이 없습니다] 아래 안내를 따라 설치한 뒤 다시 점검하십시오.")
    for name, _, _, anchor, _ in missing:
        print(f"  - {name}: {SETUP_DOC}#{anchor}")
if not voice:
    print(f"[음성] 내레이션을 만들 방법이 없습니다. API 키를 넣거나(macOS는 say로 시험 가능): {SETUP_DOC}#5-api-key")
if not image:
    print(f"[그림] 그림 생성 API 키가 없습니다. 이 상태에서는 회색 자리표시 그림으로만 조립됩니다: {SETUP_DOC}#5-api-key")
if not missing and voice and image:
    print("모든 준비가 끝났습니다.")
sys.exit(1 if missing else 0)
