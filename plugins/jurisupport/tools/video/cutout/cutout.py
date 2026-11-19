"""캐릭터 그림에서 초록 배경을 지우고 머리·몸통 조각으로 나눈 뒤 부위를 잰다. 배경의 빈 보드 사각형을 잰다.

사용: python3 cutout.py <작업폴더>
입력: art/plate_*.png, art/char_*.png (art.py 결과)
결과: render/assets/ (plate_*.png, <이름>_head.png, <이름>_body.png, meta.json), out/check_cutout.png(점검 시트)
필요: numpy, Pillow

규칙(실제 제작에서 지적받아 고친 것)
- 초록 제거: 테두리와 이어진 초록 + 캐릭터 안에 갇힌 작은 초록 조각(500px 미만)도 배경으로 본다.
  가장자리 2px 띠에서는 초록 번짐을 없앤다(G를 max(R,B)+6 이하로).
- 목선은 살몬 피부색으로만 찾는다. 베이지 옷을 피부로 잡으면 목선이 가슴까지 내려가 팔이 갈비뼈에서 나온다.
- 어깨 윗선 = 목 아래에서 몸 폭이 최대 폭의 85%에 처음 닿는 행. 팔은 그 바깥 모서리에서 시작한다.
"""
import json
import os
import shutil
import sys
from collections import deque

import numpy as np
from PIL import Image, ImageDraw, ImageFont

from scene_lib import PH, PW, load_scene, paths
from common import find_font  # noqa: E402


def label(mask):
    """4방향 연결 성분. (라벨 배열, [(x, y, w, h, 넓이, cx, cy), ...]) 라벨은 1부터."""
    H, W = mask.shape
    lab = np.zeros(H * W, np.int32)
    m = mask.ravel()
    stats = []
    cur = 0
    for start in np.flatnonzero(m):
        if lab[start]:
            continue
        cur += 1
        lab[start] = cur
        q = deque([start])
        xs = []
        ys = []
        while q:
            i = q.popleft()
            y, x = divmod(i, W)
            xs.append(x)
            ys.append(y)
            for j, ok in ((i - 1, x > 0), (i + 1, x < W - 1), (i - W, y > 0), (i + W, y < H - 1)):
                if ok and m[j] and not lab[j]:
                    lab[j] = cur
                    q.append(j)
        xa, ya = np.array(xs), np.array(ys)
        stats.append((int(xa.min()), int(ya.min()), int(xa.max() - xa.min() + 1), int(ya.max() - ya.min() + 1),
                      len(xs), float(xa.mean()), float(ya.mean())))
    return lab.reshape(H, W), stats


def chroma(path):
    """크로마 초록을 지운 RGBA 배열을 돌려준다."""
    im = np.array(Image.open(path).convert("RGB")).astype(np.int32)
    R, G, B = im[..., 0], im[..., 1], im[..., 2]
    green = (G - np.maximum(R, B)) > 40
    if green.sum() < 1000:
        sys.exit(f"[오류] {os.path.basename(path)}: 초록 배경이 없습니다. 캐릭터는 #00B140 초록 배경 위에 다시 만드십시오.")
    med = np.median(im[green], 0)
    green &= (np.abs(im - med).max(-1) < 110)
    lab, st = label(green)
    H, W = green.shape
    border = set(np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))) - {0}
    bg = np.zeros_like(green)
    for k, s in enumerate(st, 1):
        if k in border or s[4] < 500:
            bg |= lab == k
    fg = ~bg
    a = np.where(fg, 255, 0).astype(np.uint8)
    # 가장자리 2px 띠의 초록 번짐 제거
    band = fg.copy()
    inner = fg.copy()
    for _ in range(2):
        inner = inner & np.roll(inner, 1, 0) & np.roll(inner, -1, 0) & np.roll(inner, 1, 1) & np.roll(inner, -1, 1)
    band &= ~inner
    lim = np.maximum(R, B) + 6
    G2 = np.where(band & (G > lim), lim, G)
    out = np.dstack([R, G2, B, a]).astype(np.int32)
    left = int((fg & ((G2 - np.maximum(R, B)) > 40)).sum())   # 번짐 제거 뒤에도 남은 초록
    return out, left


def measure(im, animate_arms):
    """잘라 낸 캐릭터(RGBA)에서 목·눈·어깨·피부색·윤곽을 잰다."""
    a = im[..., 3]
    ys, xs = np.where(a > 128)
    im = im[ys.min():ys.max() + 1, xs.min():xs.max() + 1].copy()
    a = im[..., 3]
    H, Wd = a.shape
    rgb = im[..., :3]
    R_, G_, B_ = rgb[..., 0], rgb[..., 1], rgb[..., 2]
    sk = (R_ > 225) & (G_ < 190) & (B_ < 175) & ((R_ - G_) > 45) & (a > 200)
    skin = np.median(rgb[sk], 0).astype(int).tolist() if sk.sum() > 50 else [244, 163, 154]
    upper = sk & (np.arange(H)[:, None] < H * 0.42)
    lab, st = label(upper)
    if st:
        k = max(range(len(st)), key=lambda i: st[i][4])
        fx, fy, fw, fh = st[k][:4]
    else:   # 피부를 못 찾으면 위쪽 22%를 머리로 본다
        fx, fy, fw, fh = int(Wd * 0.25), 0, int(Wd * 0.5), int(H * 0.22)
        print("    [주의] 얼굴 피부색을 못 찾았습니다. 머리 구간을 추정값으로 씁니다.")
    neck = int(fy + fh)
    dark = (rgb.sum(-1) < 150) & (a > 200)
    box = np.zeros_like(dark)
    box[fy:fy + fh, fx:fx + fw] = True
    _, s2 = label(dark & box)
    eyes = [[c[5], c[6], int(max(c[2], c[3]))] for c in s2
            if 80 < c[4] < 4000 and 0.5 < c[2] / max(1, c[3]) < 2 and c[6] < fy + fh * 0.8]
    if len(eyes) > 2:
        import itertools
        eyes = list(min(itertools.combinations(eyes, 2), key=lambda p: abs(p[0][1] - p[1][1]) - 0.01 * (p[0][2] + p[1][2])))
    head = im.copy()
    head[neck + 8:, :, 3] = 0
    body = im.copy()
    body[:neck, :, 3] = 0
    ab = body[..., 3] > 128
    srows = [(y, int(np.where(ab[y])[0].min()), int(np.where(ab[y])[0].max()))
             for y in range(neck, min(H, neck + int(H * 0.2))) if ab[y].any()]
    if not srows:
        sys.exit("    [오류] 목 아래 몸통을 찾지 못했습니다. 캐릭터 그림을 확인하십시오.")
    Wm = max(r[2] - r[1] for r in srows)
    shoulder = list([r for r in srows if (r[2] - r[1]) >= 0.85 * Wm][0])
    exl, exr = [], []
    for yy in range(0, H, 4):
        r_ = np.where(ab[yy])[0]
        exl.append(int(r_.min()) if len(r_) else -1)
        exr.append(int(r_.max()) if len(r_) else -1)
    sy = shoulder[0]
    sleeve = np.median(rgb[sy + 10:sy + 40, shoulder[1] + 10:shoulder[1] + 40].reshape(-1, 3), 0).astype(int).tolist()
    sock = [[shoulder[1], sy], [shoulder[2], sy]] if animate_arms else None
    meta = {"shoulder": shoulder, "edge": {"step": 4, "xl": exl, "xr": exr}, "sleeve": sleeve, "cloth": sleeve,
            "w": Wd, "h": H, "neck": neck, "neckx": int(fx + fw / 2), "eyes": eyes, "skin": skin,
            "sockets": sock, "face": [int(fx), int(fy), int(fw), int(fh)]}
    return head, body, meta


def board_rect(path, hint):
    """빈 보드: 힌트 사각형 가운데 색과 같은 색 덩어리의 경계 상자. 실패하면 힌트를 쓴다."""
    im = np.array(Image.open(path).convert("RGB").resize((PW, PH))).astype(int)
    x0, y0, x1, y1 = [int(v * (PW if i % 2 == 0 else PH)) for i, v in enumerate(hint)]
    cx, cy = (x0 + x1) // 2, (y0 + y1) // 2
    c = im[cy, cx]
    m = np.abs(im - c).sum(-1) < 30
    sub = np.zeros_like(m)
    pad = 0.6
    X0, Y0 = max(0, int(x0 - (x1 - x0) * pad)), max(0, int(y0 - (y1 - y0) * pad))
    X1, Y1 = min(PW, int(x1 + (x1 - x0) * pad)), min(PH, int(y1 + (y1 - y0) * pad))
    sub[Y0:Y1, X0:X1] = m[Y0:Y1, X0:X1]
    lab, st = label(sub)
    k = lab[cy, cx]
    ok = False
    if k:
        bx, by, bw, bh = st[k - 1][:4]
        ok = (x1 - x0) * 0.5 < bw < (x1 - x0) * 1.6 and bh < (y1 - y0) * 1.6 and bh > (y1 - y0) * 0.4
    r = [bx, by, bw, bh] if ok else [x0, y0, x1 - x0, y1 - y0]
    lum = float((c * [.299, .587, .114]).sum())
    return {"rect": [int(v) for v in r], "color": c.tolist(), "dark": lum < 120, "measured": bool(ok)}


def main():
    proj = sys.argv[1]
    sc = load_scene(proj)
    P = paths(proj)
    os.makedirs(P["assets"], exist_ok=True)
    os.makedirs(P["out"], exist_ok=True)
    meta = {"chars": {}, "plates": {}}
    thumbs = []
    for name, spec in sc["plates"].items():
        src = os.path.join(P["art"], f"plate_{name}.png")
        if not os.path.exists(src):
            sys.exit(f"[오류] {src} 가 없습니다. art.py를 먼저 실행하십시오.")
        Image.open(src).convert("RGB").resize((PW, PH)).save(os.path.join(P["assets"], f"plate_{name}.png"))
        hint = spec.get("board")
        info = board_rect(src, hint) if hint else {"rect": [int(PW * 0.15), int(PH * 0.15), int(PW * 0.7), int(PH * 0.25)],
                                                    "color": [255, 255, 255], "dark": False, "measured": False, "no_board": True}
        meta["plates"][name] = info
        tag = "실측" if info.get("measured") else ("보드 없음" if info.get("no_board") else "힌트값 사용")
        print(f"  배경 {name}: 보드 {info['rect']} ({tag})")
        t = Image.open(os.path.join(P["assets"], f"plate_{name}.png")).convert("RGB")
        if not info.get("no_board"):
            x, y, w, h = info["rect"]
            ImageDraw.Draw(t).rectangle([x, y, x + w, y + h], outline=(255, 0, 0), width=8)
        thumbs.append((f"배경 {name}", t))
    for name, spec in sc["characters"].items():
        src = os.path.join(P["art"], f"char_{name}.png")
        if not os.path.exists(src):
            sys.exit(f"[오류] {src} 가 없습니다. art.py를 먼저 실행하십시오.")
        rgba, left = chroma(src)
        head, body, m = measure(rgba, spec.get("animate_arms", False))
        Image.fromarray(head.astype(np.uint8), "RGBA").save(os.path.join(P["assets"], f"{name}_head.png"))
        Image.fromarray(body.astype(np.uint8), "RGBA").save(os.path.join(P["assets"], f"{name}_body.png"))
        meta["chars"][name] = m
        warn = f"  [주의] 캐릭터 안 초록 픽셀 {left}개" if left else ""
        print(f"  캐릭터 {name}: {m['w']}×{m['h']} 목 {m['neck']} 눈 {len(m['eyes'])}개 어깨 {m['shoulder']}"
              f" 팔 {'코드로 움직임' if m['sockets'] else '그림 그대로'}{warn}")
        if len(m["eyes"]) != 2:
            print(f"    [주의] 눈을 {len(m['eyes'])}개 찾았습니다. 눈 깜빡임이 어색하면 캐릭터를 다시 만드십시오.")
        full = Image.fromarray(np.dstack([np.maximum(head[..., :3], body[..., :3]), np.maximum(head[..., 3], body[..., 3])]).astype(np.uint8), "RGBA")
        bg = Image.new("RGB", full.size, (230, 230, 230))
        bg.paste(full, (0, 0), full)
        d = ImageDraw.Draw(bg)
        d.line([0, m["neck"], m["w"], m["neck"]], fill=(255, 0, 0), width=4)
        sy, xl, xr = m["shoulder"]
        d.line([xl, sy, xr, sy], fill=(0, 90, 255), width=4)
        for ex, ey, r in m["eyes"]:
            d.ellipse([ex - r, ey - r, ex + r, ey + r], outline=(255, 0, 255), width=4)
        thumbs.append((f"캐릭터 {name}", bg))
    with open(os.path.join(P["assets"], "meta.json"), "w", encoding="utf-8") as f:
        json.dump(meta, f, ensure_ascii=False)
    # 점검 시트: 배경은 빨간 사각형 = 보드, 캐릭터는 빨간 선 = 목, 파란 선 = 어깨, 분홍 원 = 눈
    tw, th = 270, 480
    cols = 4
    rows = (len(thumbs) + cols - 1) // cols
    sheet = Image.new("RGB", (cols * tw, rows * (th + 30)), "white")
    d = ImageDraw.Draw(sheet)
    fp = find_font()
    font = ImageFont.truetype(fp, 20) if fp else ImageFont.load_default()
    for i, (cap, im) in enumerate(thumbs):
        im = im.copy()
        im.thumbnail((tw, th))
        x, y = (i % cols) * tw, (i // cols) * (th + 30)
        sheet.paste(im, (x + (tw - im.width) // 2, y + 30))
        d.text((x + 6, y + 4), cap, fill="black", font=font)
    sheet.save(os.path.join(P["out"], "check_cutout.png"))
    for f in ("engine.js", "render.html"):
        shutil.copy(os.path.join(os.path.dirname(os.path.abspath(__file__)), f), os.path.join(P["render"], f))
    print("[완료] out/check_cutout.png를 열어 보드 사각형·목선·어깨선·눈 위치를 확인하십시오. 다음: voice.py")


if __name__ == "__main__":
    main()
