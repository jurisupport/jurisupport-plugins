"""컷별 음성·그림·정보판·자막을 세로 영상(1080×1920, 30fps)으로 조립한다.

사용: python3 assemble.py <프로젝트폴더> [--font 경로] [--bgm 음악파일] [--pad 0.3]
- 컷 길이 = 음성 길이 + pad(기본 0.3초). 화면은 clip(직접 넣은 영상) → boards/NN.png → images/NN.png 순으로 고른다.
- 그림은 천천히 확대·축소(켄 번스)하고, 자막은 Pillow로 그려 얹는다(ffmpeg drawtext가 없어도 된다).
- cuts.json의 top_title이 있으면 화면 위쪽에 계속 띄운다. end_card가 있으면 끝에 2.5초 붙인다.
결과: <프로젝트>/out/video.mp4, 확인용 장면 사진 out/check_NN.jpg
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from boards import render as render_board, wrap  # noqa: E402
from common import audio_seconds, ffmpeg_bin, find_font, load_project, run  # noqa: E402

W, H, FPS = 1080, 1920, 30


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def overlay_png(path, subtitle, top_title, font_path):
    """자막(아래)과 상단 제목을 그린 투명 PNG."""
    from PIL import Image, ImageDraw, ImageFont
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if top_title:
        ft = ImageFont.truetype(font_path, 64)
        lines = wrap(d, top_title, ft, 960)[:2]
        y = 170
        for line in lines:
            d.text((W // 2, y), line, font=ft, fill="white", anchor="mm", stroke_width=6, stroke_fill="black")
            y += 84
    if subtitle:
        fs = ImageFont.truetype(font_path, 58)
        lines = wrap(d, subtitle, fs, 940)[:3]
        y = 1560 - (len(lines) - 1) * 40
        for line in lines:
            d.text((W // 2, y), line, font=fs, fill="white", anchor="mm", stroke_width=6, stroke_fill="black")
            y += 80
    im.save(path)


def visual_filter(kind, n, frames):
    cover = f"scale={W}:{H}:force_original_aspect_ratio=increase,crop={W}:{H},setsar=1"
    if kind == "image":
        z = "min(zoom+0.0007,1.10)" if n % 2 else "if(eq(on,0),1.10,max(zoom-0.0007,1.0))"
        return (f"{cover},scale={W*2}:{H*2},zoompan=z='{z}':d={frames}:s={W}x{H}:fps={FPS}"
                ":x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)'")
    return f"{cover},fps={FPS}"


def segment(ff, src, kind, wav, ovl, dur, n, out):
    frames = int(round(dur * FPS))
    if kind == "clip":
        vin = ["-stream_loop", "-1", "-i", src]
    else:
        vin = ["-loop", "1", "-framerate", str(FPS), "-i", src]
    ain = ["-i", wav] if wav else ["-f", "lavfi", "-i", "anullsrc=r=48000:cl=stereo"]
    fc = (f"[0:v]{visual_filter(kind, n, frames)}[bg];[bg][2:v]overlay=0:0,format=yuv420p[v];"
          f"[1:a]aresample=48000,aformat=channel_layouts=stereo,apad[a]")
    run([ff, "-y", "-loglevel", "error", *vin, *ain, "-i", ovl, "-filter_complex", fc,
         "-map", "[v]", "-map", "[a]", "-t", f"{dur:.3f}", "-r", str(FPS),
         "-c:v", "libx264", "-preset", "medium", "-crf", "20", "-c:a", "aac", "-b:a", "192k", out])


def main():
    proj = os.path.abspath(sys.argv[1])
    data, cuts = load_project(proj)
    ff = ffmpeg_bin()
    if not ff:
        sys.exit("[오류] ffmpeg가 없습니다. check_env.py를 실행해 설정 안내를 보십시오.")
    font = find_font(arg("--font"))
    if not font:
        sys.exit("[오류] 한글 글꼴을 찾지 못했습니다. --font 로 경로를 주십시오.")
    pad = float(arg("--pad", data.get("pad", 0.3)))
    bgm = arg("--bgm") or data.get("bgm")
    if bgm and not os.path.isabs(bgm) and os.path.exists(os.path.join(proj, bgm)):
        bgm = os.path.join(proj, bgm)
    if bgm and not os.path.exists(bgm):
        sys.exit(f"[오류] 배경음악 파일이 없습니다: {bgm}")
    top = data.get("top_title")
    work = os.path.join(proj, "out", "_seg")
    os.makedirs(work, exist_ok=True)
    segs, total = [], 0.0
    for c in cuts:
        n = c["n"]
        wav = os.path.join(proj, "audio", f"{n:02d}.wav")
        if not os.path.exists(wav):
            sys.exit(f"[오류] 컷 {n} 음성이 없습니다: {wav} (tts.py를 먼저 실행)")
        if c.get("clip"):
            src, kind = os.path.join(proj, c["clip"]), "clip"
        elif os.path.exists(os.path.join(proj, "boards", f"{n:02d}.png")):
            src, kind = os.path.join(proj, "boards", f"{n:02d}.png"), "board"
        else:
            src, kind = os.path.join(proj, "images", f"{n:02d}.png"), "image"
        if not os.path.exists(src):
            sys.exit(f"[오류] 컷 {n} 화면 파일이 없습니다: {src} (images.py 또는 boards.py를 먼저 실행)")
        dur = audio_seconds(wav) + pad
        ovl = os.path.join(work, f"ovl_{n:02d}.png")
        overlay_png(ovl, c.get("subtitle", c["narration"]), top, font)
        out = os.path.join(work, f"seg_{n:02d}.mp4")
        segment(ff, src, kind, wav, ovl, dur, n, out)
        segs.append(out)
        total += dur
        print(f"  컷{n:02d} {kind:5s} {dur:4.1f}초")
    if data.get("end_card"):
        card = os.path.join(work, "end.png")
        render_board(data["end_card"], card, font,
                     ((246, 243, 236), (35, 40, 48), (31, 58, 95)))
        blank = os.path.join(work, "ovl_end.png")
        overlay_png(blank, "", None, font)
        out = os.path.join(work, "seg_end.mp4")
        segment(ff, card, "board", None, blank, 2.5, 0, out)
        segs.append(out)
        total += 2.5
    lst = os.path.join(work, "list.txt")
    with open(lst, "w", encoding="utf-8") as f:
        for s in segs:
            f.write(f"file '{s}'\n")
    joined = os.path.join(work, "joined.mp4")
    run([ff, "-y", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", lst, "-c", "copy", joined])
    final = os.path.join(proj, "out", "video.mp4")
    if bgm:
        vol = data.get("bgm_volume", 0.12)
        run([ff, "-y", "-loglevel", "error", "-i", joined, "-stream_loop", "-1", "-i", bgm,
             "-filter_complex", f"[1:a]volume={vol}[b];[0:a][b]amix=inputs=2:duration=first:normalize=0[a]",
             "-map", "0:v", "-map", "[a]", "-c:v", "copy", "-c:a", "aac", "-b:a", "192k", final])
    else:
        os.replace(joined, final)
    t = 0.0
    for i, c in enumerate(cuts):
        d = audio_seconds(os.path.join(proj, "audio", f"{c['n']:02d}.wav")) + pad
        run([ff, "-y", "-loglevel", "error", "-ss", f"{t + d / 2:.2f}", "-i", final, "-frames:v", "1",
             "-vf", "scale=360:-1", os.path.join(proj, "out", f"check_{c['n']:02d}.jpg")])
        t += d
    print(f"[완료] {final}  ({total:.1f}초, 컷 {len(cuts)}개). out/check_NN.jpg로 장면을 확인하십시오.")


if __name__ == "__main__":
    main()
