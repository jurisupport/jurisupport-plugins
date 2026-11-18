"""영상 스킬 공용 함수: 설정 읽기, API 키, 한글 글꼴, ffmpeg 실행.

Python 3.9 이상, 표준 라이브러리 + Pillow만 쓴다.
"""
import json
import os
import platform
import shutil
import subprocess
import sys

SETUP_DOC = "https://github.com/jurisupport/jurisupport-plugins/blob/main/plugins/jurisupport/docs/video-setup.md"
CONF_DIR = os.path.expanduser("~/.jurisupport")


def load_project(proj):
    """프로젝트 폴더의 cuts.json을 읽는다."""
    path = os.path.join(proj, "cuts.json")
    if not os.path.exists(path):
        sys.exit(f"[오류] {path} 가 없습니다. SKILL.md의 cuts.json 형식으로 먼저 만드십시오.")
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    cuts = data.get("cuts") or []
    if not cuts:
        sys.exit("[오류] cuts.json에 cuts 항목이 없습니다.")
    for i, c in enumerate(cuts, 1):
        c.setdefault("n", i)
        if not c.get("narration"):
            sys.exit(f"[오류] 컷 {c['n']}에 narration(읽을 문장)이 없습니다.")
    return data, cuts


def get_key(name):
    """API 키를 환경변수 → ~/.jurisupport/<name> 파일 순으로 찾는다. 없으면 None."""
    env = {"gemini": "GEMINI_API_KEY", "openai": "OPENAI_API_KEY"}[name]
    v = os.environ.get(env)
    if v:
        return v.strip()
    p = os.path.join(CONF_DIR, f"{name}_api_key")
    if os.path.exists(p):
        with open(p, encoding="utf-8") as f:
            return f.read().strip() or None
    return None


FONT_CANDIDATES = [
    "/System/Library/Fonts/AppleSDGothicNeo.ttc",
    "/System/Library/Fonts/Supplemental/AppleGothic.ttf",
    "C:/Windows/Fonts/malgunbd.ttf",
    "C:/Windows/Fonts/malgun.ttf",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
    "/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc",
    "/usr/share/fonts/truetype/nanum/NanumGothicBold.ttf",
    "/usr/share/fonts/truetype/nanum/NanumGothic.ttf",
]


def find_font(explicit=None):
    if explicit and os.path.exists(explicit):
        return explicit
    env = os.environ.get("JURISUPPORT_FONT")
    if env and os.path.exists(env):
        return env
    for p in FONT_CANDIDATES:
        if os.path.exists(p):
            return p
    return None


def ffmpeg_bin():
    return shutil.which("ffmpeg")


def run(cmd):
    """명령을 실행하고 실패하면 마지막 출력과 함께 멈춘다."""
    r = subprocess.run(cmd, capture_output=True, text=True)
    if r.returncode != 0:
        tail = (r.stderr or r.stdout)[-1500:]
        sys.exit(f"[오류] 명령 실패: {' '.join(cmd[:4])} …\n{tail}")
    return r


def audio_seconds(path):
    """wav 길이(초). ffprobe가 있으면 그것을, 없으면 wave 모듈을 쓴다."""
    probe = shutil.which("ffprobe")
    if probe:
        r = subprocess.run([probe, "-v", "error", "-show_entries", "format=duration",
                            "-of", "default=nw=1:nk=1", path], capture_output=True, text=True)
        try:
            return float(r.stdout.strip())
        except ValueError:
            pass
    import wave
    with wave.open(path) as w:
        return w.getnframes() / w.getframerate()


def is_mac():
    return platform.system() == "Darwin"
