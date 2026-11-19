"""배경(플레이트)과 캐릭터 그림을 따로 만든다(유료 단계).

사용: python3 art.py <작업폴더> [--provider openai|gemini|placeholder] [--only plate:교실,char:교관]
결과: <작업폴더>/art/plate_<이름>.png (사람 없는 배경), art/char_<이름>.png (크로마 초록 위 캐릭터 한 명)
- 이미 있는 파일은 건너뛴다. 다시 만들려면 지우고 --only로 그 그림만 만든다.
- 화풍 시험: 먼저 --only로 배경 1장·캐릭터 1장만 만들어 승인받은 뒤 나머지를 만든다.
- placeholder: API 없이 단순 도형으로 배경·캐릭터를 그린다(무료 시험용, 조각·렌더 단계를 그대로 시험할 수 있다).
- 다른 채널 화면·캐릭터를 참조 이미지로 넣지 않는다. 참조를 넣으면 그대로 베낀다. 화풍은 글로만 지시한다.
"""
import base64
import io
import json
import os
import sys
import time
import urllib.error
import urllib.request

from scene_lib import PH, PW, arg, load_scene, paths
from common import get_key  # noqa: E402  (scene_lib가 tools/video를 경로에 넣는다)

STYLE = ("Flat vector illustration for a Korean legal explainer short. Solid flat colors only: no outlines, "
         "no gradients, no shadows, no texture. Muted palette #9AA9B8 #5E8C8A #E8D9C0 #2E3A59 #9C8DC1. "
         "Friendly simple shapes. ")
NEG = (" Absolutely no text, letters, numbers, signs with writing, logos, insignia, flags or watermarks. "
       "Do not depict real, identifiable people or real brands.")
PLATE = (" Background plate only: NO people, no characters. Straight front view, vertical 9:16. "
         "Keep the bottom third as plain empty floor where characters will stand. "
         "Any board, screen, sign or poster is completely blank: one flat solid color, nothing on it.")
CHAR = (" Exactly one character, full body from head to feet, standing, straight front view, centered, "
        "occupying about 80% of the image height. Pure flat chroma green background #00B140 filling the "
        "whole image edge to edge, no floor, no shadow. Big round head, simple dot eyes, small smile, "
        "salmon skin #F4A39A. Do not use any green on the character.")
ARMLESS = (" The character has NO arms and NO hands at all: draw only smooth rounded shoulders and plain "
           "straight sides of the torso. Arms will be added later by animation.")


def post(url, body, headers):
    for i in range(4):
        try:
            req = urllib.request.Request(url, json.dumps(body).encode(), headers)
            with urllib.request.urlopen(req, timeout=600) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace")[:300]
            if e.code in (401, 403):
                sys.exit(f"[오류] 인증 실패(HTTP {e.code}). API 키를 확인하십시오: {msg}")
            if i == 3 or e.code == 400:
                sys.exit(f"[오류] HTTP {e.code}: {msg}")
        except urllib.error.URLError as e:
            if i == 3:
                sys.exit(f"[오류] 연결 실패: {e}")
        time.sleep(6 * (i + 1))


def openai(prompt):
    key = get_key("openai")
    model = os.environ.get("IMAGE_MODEL", "gpt-image-2")
    d = post("https://api.openai.com/v1/images/generations",
             {"model": model, "prompt": prompt, "size": os.environ.get("IMAGE_SIZE", f"{PW}x{PH}"), "n": 1},
             {"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    it = d["data"][0]
    return base64.b64decode(it["b64_json"]) if it.get("b64_json") else urllib.request.urlopen(it["url"], timeout=300).read()


def gemini(prompt):
    key = get_key("gemini")
    model = os.environ.get("IMAGE_MODEL", "gemini-3.1-flash-image")
    body = {"contents": [{"parts": [{"text": prompt}]}],
            "generationConfig": {"responseModalities": ["IMAGE"], "imageConfig": {"aspectRatio": "9:16"}}}
    d = post(f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}",
             body, {"Content-Type": "application/json"})
    for c in d.get("candidates", []):
        for p in c.get("content", {}).get("parts", []):
            if "inlineData" in p:
                return base64.b64decode(p["inlineData"]["data"])
    sys.exit("[오류] 그림이 오지 않았습니다: " + json.dumps(d, ensure_ascii=False)[:300])


def save_resized(raw, out):
    from PIL import Image
    im = Image.open(io.BytesIO(raw)).convert("RGB")
    if im.size != (PW, PH):
        im = im.resize((PW, PH), Image.LANCZOS)
    im.save(out)


# ---------- 무료 자리표시 그림 ----------
def ph_plate(name, spec, out):
    from PIL import Image, ImageDraw
    seed = sum(map(ord, name))
    walls = [(154, 169, 184), (232, 217, 192), (94, 140, 138), (156, 141, 193)]
    im = Image.new("RGB", (PW, PH), walls[seed % 4])
    d = ImageDraw.Draw(im)
    d.rectangle([0, int(PH * 0.66), PW, PH], fill=(120, 110, 100))
    b = spec.get("board") or [0.18, 0.14, 0.82, 0.42]
    dark = (46, 58, 89) if seed % 2 else (42, 157, 143)
    light = (244, 241, 232)
    d.rectangle([int(b[0] * PW) - 18, int(b[1] * PH) - 18, int(b[2] * PW) + 18, int(b[3] * PH) + 18], fill=(201, 166, 107))
    d.rectangle([int(b[0] * PW), int(b[1] * PH), int(b[2] * PW), int(b[3] * PH)], fill=dark if seed % 3 else light)
    d.rectangle([80, int(PH * 0.5), 300, int(PH * 0.66)], fill=(201, 166, 107))
    im.save(out)


def ph_char(name, spec, out):
    from PIL import Image, ImageDraw
    seed = sum(map(ord, name))
    cloth = [(46, 58, 89), (94, 140, 138), (156, 141, 193), (201, 120, 90)][seed % 4]
    im = Image.new("RGB", (PW, PH), (0, 177, 64))
    d = ImageDraw.Draw(im)
    cx, top, hh = PW // 2, 260, 1500
    hr = int(hh * 0.15)
    by0 = top + 2 * hr + 10
    d.rounded_rectangle([cx - int(hr * 1.05), by0, cx + int(hr * 1.05), top + int(hh * 0.78)], radius=int(hr * 0.6), fill=cloth)
    d.rectangle([cx - int(hr * 0.9), top + int(hh * 0.74), cx - 20, top + hh], fill=(43, 45, 66))
    d.rectangle([cx + 20, top + int(hh * 0.74), cx + int(hr * 0.9), top + hh], fill=(43, 45, 66))
    if not spec.get("animate_arms"):   # 팔을 코드로 움직이지 않는 캐릭터는 그림에 팔을 붙여 둔다
        for s in (-1, 1):
            x0 = cx + s * int(hr * 1.05)
            d.rounded_rectangle([min(x0, x0 + s * int(hr * 0.42)), by0 + 30, max(x0, x0 + s * int(hr * 0.42)), top + int(hh * 0.6)],
                                radius=36, fill=tuple(int(c * 0.88) for c in cloth))
    d.ellipse([cx - hr, top, cx + hr, top + 2 * hr], fill=(244, 163, 154))
    for s in (-1, 1):
        d.ellipse([cx + s * int(hr * 0.38) - 14, top + int(hr * 0.95) - 14, cx + s * int(hr * 0.38) + 14, top + int(hr * 0.95) + 14], fill=(30, 30, 40))
    d.arc([cx - 40, top + int(hr * 1.2), cx + 40, top + int(hr * 1.5)], 20, 160, fill=(30, 30, 40), width=8)
    im.save(out)


def main():
    proj = sys.argv[1]
    sc = load_scene(proj)
    P = paths(proj)
    os.makedirs(P["art"], exist_ok=True)
    provider = arg("--provider") or sc.get("image_provider")
    if not provider:
        provider = "openai" if get_key("openai") else "gemini" if get_key("gemini") else "placeholder"
    if provider in ("gemini", "openai") and not get_key(provider):
        sys.exit(f"[오류] {provider} API 키가 없습니다. check_env.py를 실행해 설정 안내를 보십시오.")
    only = {x.strip() for x in (arg("--only") or "").split(",") if x.strip()}
    style = sc.get("style_prompt") or STYLE
    jobs = [("plate", n, s) for n, s in sc["plates"].items()] + [("char", n, s) for n, s in sc["characters"].items()]
    print(f"그림: {provider}")
    made = 0
    for kind, name, spec in jobs:
        if only and f"{kind}:{name}" not in only:
            continue
        out = os.path.join(P["art"], f"{kind}_{name}.png")
        if os.path.exists(out):
            print(f"  {kind}:{name} 있음, 건너뜀")
            continue
        if provider == "placeholder":
            (ph_plate if kind == "plate" else ph_char)(name, spec, out)
        else:
            if not spec.get("prompt"):
                sys.exit(f"[오류] {kind}:{name}에 prompt가 없습니다.")
            if kind == "plate":
                prompt = style + spec["prompt"] + PLATE + NEG
            else:
                prompt = style + spec["prompt"] + CHAR + (ARMLESS if spec.get("animate_arms") else "") + NEG
            raw = (openai if provider == "openai" else gemini)(prompt)
            save_resized(raw, out)
        made += 1
        print(f"  {kind}:{name} 완료")
    print(f"[완료] 새로 만든 그림 {made}장. 다음: 그림을 열어 확인 → cutout.py")


if __name__ == "__main__":
    main()
