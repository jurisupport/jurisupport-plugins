"""렌더 엔진(render/render.html)을 Chrome으로 열어 프레임을 뽑고, 효과음·내레이션을 섞어 영상을 만든다.

사용
  python3 render.py <작업폴더> sheet                  장면마다 1프레임씩 모은 점검 시트(out/sheet_N.png)
  python3 render.py <작업폴더> frames 3.2 7.5 …       지정한 시각의 프레임을 한 장에(out/frames.png)
  python3 render.py <작업폴더> video [--fps 30] [--sub 2] [--bgm 음악파일]
                                                      out/silent.mp4 → out/mix.wav → out/video.mp4
필요: playwright(파이썬) + Chromium 또는 Chrome, numpy, ffmpeg

- 효과음(타이핑·등장·X·체크·와이프)은 엔진이 기록한 시각에 코드로 합성해 넣는다. 배경음은 --bgm으로 준다.
- 배경음은 내레이션보다 약 10dB 낮게 두고, 최종 음량은 -14 LUFS로 맞춘다.
"""
import asyncio
import base64
import io
import json
import os
import subprocess
import sys
import wave

import numpy as np

from scene_lib import arg, load_scene, paths
from common import ffmpeg_bin, find_font, run  # noqa: E402

SR = 48000


async def open_page(p, P):
    from playwright.async_api import Error
    args = ["--allow-file-access-from-files"]
    try:
        b = await p.chromium.launch(args=args)
    except Error:
        try:
            b = await p.chromium.launch(channel="chrome", args=args)
        except Error as e:
            sys.exit("[오류] Chromium을 열 수 없습니다. `python3 -m playwright install chromium`을 실행하거나 "
                     f"Chrome을 설치하십시오.\n{str(e)[:300]}")
    pg = await b.new_page(viewport={"width": 1080, "height": 1920})
    pg.on("pageerror", lambda e: print("  [엔진 오류]", e))
    await pg.goto("file://" + os.path.join(os.path.abspath(P["render"]), "render.html"))
    await pg.wait_for_function("window.READY||window.ERR", timeout=120000)
    err = await pg.evaluate("window.ERR")
    if err:
        sys.exit("[오류] 렌더 페이지 로딩 실패: " + err)
    return b, pg


async def grab(pg, t, fps=30, sub=1):
    await pg.evaluate(f"seek({t},{fps},{sub})")
    u = await pg.evaluate("document.getElementById('c').toDataURL('image/png')")
    return base64.b64decode(u.split(",")[1])


async def sheet(P):
    from PIL import Image, ImageDraw, ImageFont
    from playwright.async_api import async_playwright
    tl = json.load(open(os.path.join(P["render"], "timeline.json"), encoding="utf-8"))
    ts = [(s["id"], round(s["start"] + (s["end"] - s["start"]) * 0.7, 2)) for s in tl["shots"]]
    fp = find_font()
    font = ImageFont.truetype(fp, 22) if fp else ImageFont.load_default()
    async with async_playwright() as p:
        b, pg = await open_page(p, P)
        for k in range(0, len(ts), 16):
            part = ts[k:k + 16]
            sh = Image.new("RGB", (4 * 270, ((len(part) + 3) // 4) * 512), "white")
            d = ImageDraw.Draw(sh)
            for i, (sid, t) in enumerate(part):
                im = Image.open(io.BytesIO(await grab(pg, t))).convert("RGB").resize((270, 480))
                x, y = (i % 4) * 270, (i // 4) * 512
                sh.paste(im, (x, y + 32))
                d.text((x + 6, y + 4), f"{sid} {t:.2f}s", fill="black", font=font)
            out = os.path.join(P["out"], f"sheet_{k // 16 + 1}.png")
            sh.save(out)
            print("  시트", out)
        await b.close()


async def frames(P, ts):
    from PIL import Image
    from playwright.async_api import async_playwright
    async with async_playwright() as p:
        b, pg = await open_page(p, P)
        sh = Image.new("RGB", (360 * len(ts), 640))
        for i, t in enumerate(ts):
            sh.paste(Image.open(io.BytesIO(await grab(pg, t))).convert("RGB").resize((360, 640)), (i * 360, 0))
        out = os.path.join(P["out"], "frames.png")
        sh.save(out)
        print("  프레임", out)
        await b.close()


async def video(P, fps, sub):
    from playwright.async_api import async_playwright
    out = os.path.join(P["out"], "silent.mp4")
    async with async_playwright() as p:
        b, pg = await open_page(p, P)
        D = await pg.evaluate("window.DURATION")
        # 효과음 시각 수집(그리기만 하고 저장하지 않는다)
        evs = await pg.evaluate(f"(()=>{{window.COLLECT=true;for(let i=0;i<=DURATION*{fps};i++)seek(i/{fps});window.COLLECT=false;return window.EV}})()")
        json.dump(evs, open(os.path.join(P["render"], "ev.json"), "w"))
        n = int(D * fps)
        ff = subprocess.Popen([ffmpeg_bin(), "-y", "-loglevel", "error", "-f", "image2pipe", "-framerate", str(fps), "-i", "-",
                               "-c:v", "libx264", "-crf", "17", "-pix_fmt", "yuv420p", "-preset", "medium", out], stdin=subprocess.PIPE)
        for i in range(n):
            ff.stdin.write(await grab(pg, i / fps, fps, sub))
            if i % (fps * 10) == 0:
                print(f"  프레임 {i}/{n}", flush=True)
        ff.stdin.close()
        ff.wait()
        await b.close()
    return D, evs


# ---------- 효과음 합성 ----------
def env(n, a=0.002, d=0.08):
    t = np.arange(n) / SR
    return np.minimum(1, t / a) * np.exp(-t / d)


def sfx(kind):
    rng = np.random.default_rng(len(kind))
    if kind == "tick":
        n = int(SR * 0.03)
        return rng.normal(0, 1, n) * env(n, 0.0005, 0.006) * 0.35
    if kind == "pop":
        n = int(SR * 0.12)
        t = np.arange(n) / SR
        return np.sin(2 * np.pi * (500 + 900 * t / 0.12) * t) * env(n, 0.002, 0.04) * 0.5
    if kind == "hit":
        n = int(SR * 0.25)
        t = np.arange(n) / SR
        return (np.sin(2 * np.pi * 90 * t) * 0.9 + rng.normal(0, 0.3, n)) * env(n, 0.001, 0.06) * 0.8
    if kind == "ding":
        n = int(SR * 0.9)
        t = np.arange(n) / SR
        return (np.sin(2 * np.pi * 1318 * t) + 0.5 * np.sin(2 * np.pi * 1976 * t)) * env(n, 0.003, 0.3) * 0.3
    if kind == "whoosh":
        n = int(SR * 0.4)
        x = rng.normal(0, 1, n)
        k = np.linspace(2, 60, n).astype(int)
        y = np.array([x[max(0, i - k[i]):i + 1].mean() for i in range(n)])
        return y * np.sin(np.linspace(0, np.pi, n)) * 1.2
    return np.zeros(1)


def load_wav(path):
    with wave.open(path) as w:
        sr, n, ch = w.getframerate(), w.getnframes(), w.getnchannels()
        x = np.frombuffer(w.readframes(n), np.int16).astype(np.float32) / 32768
    if ch > 1:
        x = x.reshape(-1, ch).mean(1)
    if sr != SR:
        x = np.interp(np.arange(int(len(x) * SR / sr)) * sr / SR, np.arange(len(x)), x)
    return x


def mix(P, D, evs, bgm):
    N = int(D * SR) + SR
    v = np.zeros(N, np.float32)
    x = load_wav(os.path.join(P["audio"], "master.wav"))
    v[:len(x)] = x[:N]
    fx = np.zeros(N, np.float32)
    gain = {"tick": 0.18, "pop": 0.35, "hit": 0.5, "ding": 0.35, "whoosh": 0.25}
    cache = {}
    last = {}
    for e in evs:
        if e["type"] == "tick" and e["t"] - last.get("tick", -1) < 0.05:
            continue
        last[e["type"]] = e["t"]
        s = cache.setdefault(e["type"], sfx(e["type"]))
        st = max(0, int(e["t"] * SR))
        seg = s[:max(0, N - st)] * gain.get(e["type"], 0.3)
        fx[st:st + len(seg)] += seg
    bg = np.zeros(N, np.float32)
    if bgm:
        tmp = os.path.join(P["out"], "_bgm.wav")
        run([ffmpeg_bin(), "-y", "-loglevel", "error", "-i", bgm, "-ar", str(SR), "-ac", "1", tmp])
        b0 = load_wav(tmp)
        os.remove(tmp)
        while len(b0) < N:
            b0 = np.concatenate([b0, b0])
        b0 = b0[:N]
        rv = np.sqrt(np.mean(v[v != 0] ** 2) + 1e-9)
        rb = np.sqrt(np.mean(b0 ** 2) + 1e-9)
        bg = b0 * (rv / rb) * 10 ** (-10.5 / 20)
        bg[-2 * SR:] *= np.linspace(1, 0, 2 * SR)
    m = v + fx + bg
    m = m / max(1, np.abs(m).max() * 1.05)
    raw = os.path.join(P["out"], "mix_raw.wav")
    with wave.open(raw, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((m * 32767).astype(np.int16).tobytes())
    r = subprocess.run([ffmpeg_bin(), "-hide_banner", "-i", raw, "-af", "loudnorm=I=-14:TP=-1.5:LRA=11:print_format=json",
                        "-f", "null", "-"], capture_output=True, text=True).stderr
    j = json.loads(r[r.rindex("{"):r.rindex("}") + 1])
    af = (f"loudnorm=I=-14:TP=-1.5:LRA=11:measured_I={j['input_i']}:measured_TP={j['input_tp']}:"
          f"measured_LRA={j['input_lra']}:measured_thresh={j['input_thresh']}:offset={j['target_offset']}:linear=true")
    out = os.path.join(P["out"], "mix.wav")
    run([ffmpeg_bin(), "-y", "-loglevel", "error", "-i", raw, "-af", af, "-ar", str(SR), out])
    os.remove(raw)
    return out


def main():
    proj, mode = sys.argv[1], sys.argv[2]
    sc = load_scene(proj)
    P = paths(proj)
    os.makedirs(P["out"], exist_ok=True)
    if not os.path.exists(os.path.join(P["render"], "timeline.json")):
        sys.exit("[오류] render/timeline.json이 없습니다. timeline.py를 먼저 실행하십시오.")
    if mode == "sheet":
        asyncio.run(sheet(P))
        print("[완료] 시트를 열어 빈 보드·넘치는 글자·가려진 얼굴·팔 위치를 확인하십시오.")
    elif mode == "frames":
        asyncio.run(frames(P, [float(x) for x in sys.argv[3:] if not x.startswith("-")]))
    elif mode == "video":
        fps, sub = int(arg("--fps", 30)), int(arg("--sub", 2))
        D, evs = asyncio.run(video(P, fps, sub))
        bgm = arg("--bgm") or sc.get("bgm")
        mixed = mix(P, D, evs, os.path.expanduser(bgm) if bgm else None)
        out = os.path.join(P["out"], "video.mp4")
        run([ffmpeg_bin(), "-y", "-loglevel", "error", "-i", os.path.join(P["out"], "silent.mp4"), "-i", mixed,
             "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", "-shortest", out])
        print(f"[완료] {out} ({D:.1f}초). 효과음 {len(evs)}개")
    else:
        sys.exit("[오류] 모드는 sheet, frames, video 중 하나입니다.")


if __name__ == "__main__":
    main()
