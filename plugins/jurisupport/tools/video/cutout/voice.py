"""문장별 내레이션을 만들고 하나로 이어 글자별 발화 시각을 잰다(음성 생성은 유료).

사용: python3 voice.py <작업폴더> [--provider gemini|openai|say] [--voice 이름] [--speed 1.1] [--only 3,5]
결과: audio/NN.wav(문장별 원본), audio/master.wav(속도 조정·무음 정리 후 이어 붙인 것), audio/timing.json
- 이미 있는 NN.wav는 건너뛴다. 다시 만들 문장은 파일을 지우고 --only로 만든다.
- 문장에 "voice"를 따로 적으면 그 문장만 그 목소리로 만든다(인물 대사는 인물 목소리로).
- 문장에 "tts"를 적으면 화면 자막은 text, 읽기는 tts로 한다(예: "9,749일" → "구천칠백사십구 일").
- 글자별 시각은 발화 구간을 글자 수에 비례해 나눈 추정값이다. 쉼표·마침표 뒤에는 쉼을 조금 더 준다.
"""
import json
import os
import sys
import wave

import numpy as np

from scene_lib import STRIP, arg, load_scene, paths, plain
import tts as T  # noqa: E402  tools/video/tts.py의 제공자 함수를 그대로 쓴다
from common import ffmpeg_bin, get_key, run  # noqa: E402

SR = 24000
GAP = 0.22        # 문장 사이 쉼(초)
LEAD = 0.35       # 영상 시작 전 여유


def read(path):
    with wave.open(path) as w:
        sr, n, ch, sw = w.getframerate(), w.getnframes(), w.getnchannels(), w.getsampwidth()
        raw = w.readframes(n)
    x = np.frombuffer(raw, np.int16 if sw == 2 else np.int32).astype(np.float32)
    x /= 32768.0 if sw == 2 else 2147483648.0
    if ch > 1:
        x = x.reshape(-1, ch).mean(1)
    return x, sr


def to24k(src, dst, speed):
    af = f"atempo={speed}" if abs(speed - 1) > 0.01 else "anull"
    run([ffmpeg_bin(), "-y", "-loglevel", "error", "-i", src, "-af", af, "-ar", str(SR), "-ac", "1", dst])


def trim(x):
    """앞뒤 무음을 자른다(20ms 창 RMS가 최대치의 4% 미만인 구간)."""
    win = int(SR * 0.02)
    n = len(x) // win
    if n < 3:
        return x
    r = np.sqrt((x[:n * win].reshape(n, win) ** 2).mean(1))
    on = np.where(r > r.max() * 0.04)[0]
    if not len(on):
        return x
    a, b = max(0, on[0] - 1) * win, min(n, on[-1] + 2) * win
    return x[a:b]


def char_times(text, t0, t1):
    """발화 구간 [t0, t1]을 글자에 나눠 plain 글자마다 시작 시각을 준다."""
    w, keep = [], []
    for c in text:
        if STRIP.match(c):
            if w:
                w[-1] += 1.6 if c in ",·" else 2.2 if c in ".?!…" else 0.25 if c.isspace() else 0
            continue
        w.append(1.0)
        keep.append(c)
    tot = sum(w) or 1
    ts, acc = [], 0.0
    for v in w:
        ts.append(round(t0 + (t1 - t0) * acc / tot, 3))
        acc += v
    return ts


def chunks(text, ts, end, limit=16):
    """자막 조각: 어절을 모아 공백 뺀 16자 이내로 끊는다. 쉼표·마침표에서 먼저 끊는다."""
    words = text.split()
    out, cur, pos = [], [], 0
    for wd in words:
        n = len(plain(wd))
        if cur and (sum(len(plain(x)) for x in cur) + n > limit):
            out.append(cur)
            cur = []
        cur.append(wd)
        if wd[-1:] in ",.?!" and sum(len(plain(x)) for x in cur) >= 6:
            out.append(cur)
            cur = []
    if cur:
        out.append(cur)
    res = []
    for ws in out:
        n = sum(len(plain(x)) for x in ws)
        st = ts[pos] if pos < len(ts) else end
        pos += n
        en = ts[pos] if pos < len(ts) else end
        res.append({"start": st, "end": en, "text": " ".join(ws)})
    return res


def main():
    proj = sys.argv[1]
    sc = load_scene(proj)
    P = paths(proj)
    os.makedirs(P["audio"], exist_ok=True)
    provider = arg("--provider") or sc.get("tts_provider")
    if not provider:
        provider = "gemini" if get_key("gemini") else "openai" if get_key("openai") else "say"
    if provider in ("gemini", "openai") and not get_key(provider):
        sys.exit(f"[오류] {provider} API 키가 없습니다. check_env.py를 실행해 설정 안내를 보십시오.")
    voice = arg("--voice") or sc.get("voice")
    speed = float(arg("--speed") or sc.get("speed") or 1.1)
    only = {int(x) for x in (arg("--only") or "").split(",") if x}
    fn = {"gemini": T.gemini, "openai": T.openai, "say": T.say}[provider]
    print(f"음성: {provider}, 속도 {speed}배")
    for s in sc["sentences"]:
        out = os.path.join(P["audio"], f"{s['n']:02d}.wav")
        if (only and s["n"] not in only) or (os.path.exists(out) and not (only and s["n"] in only)):
            continue
        if os.path.exists(out):
            os.remove(out)
        v = s.get("voice") or voice
        fn(s.get("tts") or s["text"], out, None if provider == "say" else v)   # say는 macOS 기본 한국어 목소리
        print(f"  문장{s['n']:02d} 생성  {s['text'][:30]}")
    # 이어 붙이기
    parts, sents, subs, t = [np.zeros(int(SR * LEAD), np.float32)], [], [], LEAD
    tmp = os.path.join(P["audio"], "_tmp.wav")
    for s in sc["sentences"]:
        src = os.path.join(P["audio"], f"{s['n']:02d}.wav")
        if not os.path.exists(src):
            sys.exit(f"[오류] {src} 가 없습니다. voice.py를 다시 실행하십시오.")
        to24k(src, tmp, speed)
        x, _ = read(tmp)
        x = trim(x)
        d = len(x) / SR
        ts = char_times(s["text"], t, t + d)
        sents.append({"n": s["n"], "text": s["text"], "plain": plain(s["text"]), "start": round(t, 3),
                      "end": round(t + d, 3), "t": ts})
        subs += chunks(s.get("subtitle") or s["text"], ts, round(t + d, 3)) if not s.get("subtitle") else \
            [{"start": round(t, 3), "end": round(t + d, 3), "text": s["subtitle"]}]
        parts += [x, np.zeros(int(SR * GAP), np.float32)]
        t += d + GAP
        print(f"  문장{s['n']:02d} {t - d - GAP:6.2f}~{t - GAP:6.2f}초")
    os.remove(tmp)
    y = np.concatenate(parts)
    pk = np.abs(y).max() or 1
    y = (y / pk * 0.89 * 32767).astype(np.int16)
    with wave.open(os.path.join(P["audio"], "master.wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(y.tobytes())
    with open(os.path.join(P["audio"], "timing.json"), "w", encoding="utf-8") as f:
        json.dump({"duration": round(t, 3), "sentences": sents, "subs": subs}, f, ensure_ascii=False, indent=1)
    print(f"[완료] 내레이션 {t:.1f}초. 다음: timeline.py")


if __name__ == "__main__":
    main()
