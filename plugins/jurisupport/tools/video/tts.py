"""컷별 내레이션 음성 만들기.

사용: python3 tts.py <프로젝트폴더> [--provider gemini|openai|say] [--voice 이름] [--only 1,3]
결과: <프로젝트>/audio/NN.wav (24kHz 모노). 이미 있는 파일은 건너뛴다(다시 만들려면 지운다).
- gemini: 기본 모델 gemini-3.8-flash-tts (환경변수 TTS_MODEL로 바꿀 수 있다), 기본 목소리 Zephyr
- openai: 기본 모델 gpt-4o-mini-tts (TTS_MODEL), 기본 목소리 alloy
- say: macOS 내장 음성(Yuna). 무료이며 시험용이다
"""
import base64
import json
import os
import shutil
import sys
import time
import urllib.error
import urllib.request
import wave

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from common import ffmpeg_bin, get_key, is_mac, load_project, run  # noqa: E402

PROFILE = ("Korean short-video narration for a law firm. A calm, trustworthy lawyer explains a legal point "
           "to ordinary viewers. Clear, natural, a little brisk, no hype. Read exactly the transcript.\n\nTRANSCRIPT:\n")


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def write_pcm(path, pcm, rate=24000):
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(pcm)


def post(url, body, headers, raw=False):
    for i in range(4):
        try:
            req = urllib.request.Request(url, json.dumps(body).encode(), headers)
            with urllib.request.urlopen(req, timeout=300) as r:
                return r.read() if raw else json.load(r)
        except urllib.error.HTTPError as e:
            msg = e.read().decode(errors="replace")[:300]
            if e.code in (401, 403):
                sys.exit(f"[오류] 인증 실패(HTTP {e.code}). API 키를 확인하십시오: {msg}")
            if i == 3:
                sys.exit(f"[오류] HTTP {e.code}: {msg}")
        except urllib.error.URLError as e:
            if i == 3:
                sys.exit(f"[오류] 연결 실패: {e}")
        time.sleep(4 * (i + 1))


def gemini(text, out, voice):
    key = get_key("gemini")
    model = os.environ.get("TTS_MODEL", "gemini-3.8-flash-tts")
    body = {"contents": [{"parts": [{"text": PROFILE + text}]}],
            "generationConfig": {"responseModalities": ["AUDIO"],
                                 "speechConfig": {"voiceConfig": {"prebuiltVoiceConfig": {"voiceName": voice or "Zephyr"}}}}}
    d = post(f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}",
             body, {"Content-Type": "application/json"})
    data = base64.b64decode(d["candidates"][0]["content"]["parts"][0]["inlineData"]["data"])
    if data[:4] == b"RIFF":
        open(out, "wb").write(data)
    else:
        write_pcm(out, data)


def openai(text, out, voice):
    key = get_key("openai")
    model = os.environ.get("TTS_MODEL", "gpt-4o-mini-tts")
    body = {"model": model, "voice": voice or "alloy", "input": text, "response_format": "wav",
            "instructions": "Calm, clear Korean narration by a lawyer. No hype."}
    raw = post("https://api.openai.com/v1/audio/speech", body,
               {"Authorization": "Bearer " + key, "Content-Type": "application/json"}, raw=True)
    open(out, "wb").write(raw)


def say(text, out, voice):
    if not (is_mac() and shutil.which("say")):
        sys.exit("[오류] say는 macOS에서만 됩니다. --provider gemini 또는 openai를 쓰십시오.")
    tmp = out[:-4] + ".aiff"
    run(["say", "-v", voice or "Yuna", "-o", tmp, text])
    run([ffmpeg_bin(), "-y", "-loglevel", "error", "-i", tmp, "-ar", "24000", "-ac", "1", out])
    os.remove(tmp)


def main():
    proj = sys.argv[1]
    data, cuts = load_project(proj)
    provider = arg("--provider") or data.get("tts_provider")
    if not provider:
        provider = "gemini" if get_key("gemini") else "openai" if get_key("openai") else "say"
    if provider in ("gemini", "openai") and not get_key(provider):
        sys.exit(f"[오류] {provider} API 키가 없습니다. check_env.py를 실행해 설정 안내를 보십시오.")
    voice = arg("--voice") or data.get("voice")
    only = {int(x) for x in arg("--only", "").split(",") if x}
    fn = {"gemini": gemini, "openai": openai, "say": say}[provider]
    os.makedirs(os.path.join(proj, "audio"), exist_ok=True)
    print(f"음성: {provider}")
    for c in cuts:
        if only and c["n"] not in only:
            continue
        out = os.path.join(proj, "audio", f"{c['n']:02d}.wav")
        if os.path.exists(out):
            print(f"  컷{c['n']:02d} 있음, 건너뜀")
            continue
        fn(c.get("tts") or c["narration"], out, voice)
        with wave.open(out) as w:
            sec = w.getnframes() / w.getframerate()
        print(f"  컷{c['n']:02d} {sec:4.1f}초  {c['narration'][:30]}")
    print("[완료] 다음: 그림(images.py) 또는 조립(assemble.py)")


if __name__ == "__main__":
    main()
