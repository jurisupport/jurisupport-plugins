"""컷별 장면 그림 만들기(유료 단계).

사용: python3 images.py <프로젝트폴더> [--provider gemini|openai|placeholder] [--only 1,3]
결과: <프로젝트>/images/NN.png (세로 9:16). 이미 있는 파일은 건너뛴다.
- 컷에 board(정보판)나 clip(직접 넣은 영상)이 있으면 그림을 만들지 않는다.
- 프롬프트 = cuts.json의 style_prompt + 컷의 image_prompt + 공통 금지문(글자·로고·실존 인물 금지).
- gemini 기본 모델 gemini-3.1-flash-image, openai 기본 모델 gpt-image-2 (환경변수 IMAGE_MODEL로 바꿀 수 있다).
- placeholder: API 없이 회색 자리표시 그림을 만든다(조립 시험용).
"""
import base64
import json
import os
import sys
import time
import urllib.error
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import find_font, get_key, load_project  # noqa: E402

NEG = (" No text, no letters, no numbers, no captions, no logos, no watermarks anywhere in the image. "
       "Do not depict real, identifiable people or real brands. Vertical 9:16 composition.")


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


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


def openai(prompt):
    key = get_key("openai")
    model = os.environ.get("IMAGE_MODEL", "gpt-image-2")
    d = post("https://api.openai.com/v1/images/generations",
             {"model": model, "prompt": prompt, "size": "1024x1536", "n": 1},
             {"Authorization": "Bearer " + key, "Content-Type": "application/json"})
    it = d["data"][0]
    if it.get("b64_json"):
        return base64.b64decode(it["b64_json"])
    return urllib.request.urlopen(it["url"], timeout=300).read()


def placeholder(n, out):
    from PIL import Image, ImageDraw, ImageFont
    im = Image.new("RGB", (1080, 1920), (200, 205, 212))
    d = ImageDraw.Draw(im)
    f = find_font()
    font = ImageFont.truetype(f, 90) if f else ImageFont.load_default()
    d.text((540, 900), f"장면 {n}", fill=(90, 95, 105), font=font, anchor="mm")
    im.save(out)


def main():
    proj = sys.argv[1]
    data, cuts = load_project(proj)
    provider = arg("--provider") or data.get("image_provider")
    if not provider:
        provider = "gemini" if get_key("gemini") else "openai" if get_key("openai") else "placeholder"
    if provider in ("gemini", "openai") and not get_key(provider):
        sys.exit(f"[오류] {provider} API 키가 없습니다. check_env.py를 실행해 설정 안내를 보십시오.")
    only = {int(x) for x in arg("--only", "").split(",") if x}
    style = data.get("style_prompt", "")
    os.makedirs(os.path.join(proj, "images"), exist_ok=True)
    print(f"그림: {provider}")
    made = 0
    for c in cuts:
        if only and c["n"] not in only:
            continue
        if c.get("board") or c.get("clip"):
            continue
        out = os.path.join(proj, "images", f"{c['n']:02d}.png")
        if os.path.exists(out):
            print(f"  컷{c['n']:02d} 있음, 건너뜀")
            continue
        if provider == "placeholder":
            placeholder(c["n"], out)
            made += 1
        else:
            if not c.get("image_prompt"):
                sys.exit(f"[오류] 컷 {c['n']}에 image_prompt가 없습니다.")
            prompt = (style + " " + c["image_prompt"]).strip() + NEG
            raw = (gemini if provider == "gemini" else openai)(prompt)
            open(out, "wb").write(raw)
            made += 1
        print(f"  컷{c['n']:02d} 완료")
    print(f"[완료] 새로 만든 그림 {made}장. 다음: 정보판(boards.py) → 조립(assemble.py)")


if __name__ == "__main__":
    main()
