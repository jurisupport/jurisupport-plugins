"""정보판(숫자·금액·항목 화면)을 직접 그린다. AI 그림에 글자를 만들게 하지 않기 위해서다.

사용: python3 boards.py <프로젝트폴더> [--font 경로]
cuts.json의 컷에 "board": {"title": "...", "lines": ["...", "..."]} 가 있으면 <프로젝트>/boards/NN.png 를 만든다.
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import find_font, load_project  # noqa: E402


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def wrap(draw, text, font, width):
    lines, cur = [], ""
    for ch in text:
        if draw.textlength(cur + ch, font=font) > width and cur:
            lines.append(cur)
            cur = ch.lstrip()
        else:
            cur += ch
    if cur:
        lines.append(cur)
    return lines


def render(board, out, font_path, theme):
    from PIL import Image, ImageDraw, ImageFont
    bg, fg, accent = theme
    im = Image.new("RGB", (1080, 1920), bg)
    d = ImageDraw.Draw(im)
    ft = ImageFont.truetype(font_path, 78)
    fl = ImageFont.truetype(font_path, 60)
    y = 520
    for line in wrap(d, board.get("title", ""), ft, 900):
        d.text((540, y), line, font=ft, fill=accent, anchor="mm")
        y += 104
    y += 50
    d.line([(160, y), (920, y)], fill=accent, width=4)
    y += 90
    for item in board.get("lines", []):
        for line in wrap(d, item, fl, 880):
            d.text((540, y), line, font=fl, fill=fg, anchor="mm")
            y += 86
        y += 30
    im.save(out)


def main():
    proj = sys.argv[1]
    data, cuts = load_project(proj)
    font = find_font(arg("--font"))
    if not font:
        sys.exit("[오류] 한글 글꼴을 찾지 못했습니다. --font 로 글꼴 파일 경로를 주십시오(설정 안내 4절).")
    theme = ((246, 243, 236), (35, 40, 48), (31, 58, 95)) if data.get("style", "flat") == "flat" \
        else ((22, 26, 33), (240, 242, 245), (250, 204, 21))
    os.makedirs(os.path.join(proj, "boards"), exist_ok=True)
    k = 0
    for c in cuts:
        if c.get("board"):
            render(c["board"], os.path.join(proj, "boards", f"{c['n']:02d}.png"), font, theme)
            k += 1
    print(f"[완료] 정보판 {k}장")


if __name__ == "__main__":
    main()
