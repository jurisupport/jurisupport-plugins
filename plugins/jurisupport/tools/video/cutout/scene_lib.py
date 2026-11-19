"""조각 애니메이션 공용 함수: scene.json 읽기, 작업 폴더 경로, 어절 앵커 → 초 변환.

작업 폴더(promo/<슬러그>/video/) 구조
  scene.json            장면 정의(SKILL.md 형식)
  art/                  생성한 원본 그림: plate_<이름>.png, char_<이름>.png
  audio/                문장별 음성 NN.wav, master.wav, timing.json
  render/               engine.js, render.html, timeline.json, assets/(오려 낸 조각과 meta.json)
  out/                  점검 시트, 무음 영상, 믹스, 최종 video.mp4
"""
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.dirname(HERE))   # tools/video (common.py, tts.py)

PW, PH = 1152, 2048          # 배경 그림 좌표계
STRIP = re.compile(r"[\s,.?!·\"'“”‘’…:;()\[\]「」『』~\-]")


def arg(name, default=None):
    return sys.argv[sys.argv.index(name) + 1] if name in sys.argv else default


def paths(proj):
    p = {k: os.path.join(proj, k) for k in ("art", "audio", "render", "out")}
    p["assets"] = os.path.join(p["render"], "assets")
    p["scene"] = os.path.join(proj, "scene.json")
    return p


def load_scene(proj):
    path = os.path.join(proj, "scene.json")
    if not os.path.exists(path):
        sys.exit(f"[오류] {path} 가 없습니다. SKILL.md의 scene.json 형식으로 먼저 만드십시오.")
    with open(path, encoding="utf-8") as f:
        sc = json.load(f)
    sents = sc.get("sentences") or []
    if not sents:
        sys.exit("[오류] scene.json에 sentences(읽을 문장)가 없습니다.")
    for i, s in enumerate(sents, 1):
        s.setdefault("n", i)
        if not s.get("text"):
            sys.exit(f"[오류] 문장 {s['n']}에 text가 없습니다.")
    if not sc.get("shots"):
        sys.exit("[오류] scene.json에 shots(장면)가 없습니다.")
    sc.setdefault("plates", {})
    sc.setdefault("characters", {})
    return sc


def plain(text):
    """앵커 비교용: 공백·문장부호를 뺀 글자열."""
    return STRIP.sub("", text)


class Anchors:
    """timing.json의 글자별 발화 시각으로 [문장번호, "어절", ("start"|"end")] 앵커를 초로 바꾼다.

    어절에 "#2"를 붙이면 그 문장에서 두 번째로 나오는 위치를 쓴다(예: "법원#2").
    """

    def __init__(self, timing):
        self.s = {str(x["n"]): x for x in timing["sentences"]}

    def __call__(self, a, where=""):
        if isinstance(a, (int, float)):
            return float(a)
        if isinstance(a, str):          # "3:벌금형" 형식도 받는다
            n, _, w = a.partition(":")
            a = [int(n), w]
        n, word = a[0], a[1]
        pos = a[2] if len(a) > 2 else "start"
        g = self.s.get(str(n))
        if not g:
            sys.exit(f"[오류] {where} 앵커 {a}: {n}번 문장이 없습니다.")
        k = 1
        if "#" in word:
            word, kk = word.rsplit("#", 1)
            k = int(kk)
        sub, txt, i = plain(word), g["plain"], -1
        for _ in range(k):
            i = txt.find(sub, i + 1)
            if i < 0:
                sys.exit(f"[오류] {where} 앵커 {a}: {n}번 문장에 \"{word}\"가 {k}번째로 없습니다. 문장: {g['text']}")
        if pos == "end":
            j = i + len(sub)
            return round(g["t"][j] if j < len(g["t"]) else g["end"], 3)
        return round(g["t"][i], 3)
