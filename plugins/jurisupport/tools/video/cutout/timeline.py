"""scene.json의 장면·효과 앵커(문장번호+어절)를 실제 발화 시각(초)으로 바꿔 render/timeline.json을 만든다.

사용: python3 timeline.py <작업폴더>
- 장면의 "at" = 그 장면이 시작하는 어절. 첫 장면은 0초에 시작한다.
- 효과·보드 줄·자세 변경의 "at" → "t", "flip_at" → "flip_t"처럼 "_at"으로 끝나는 키는 "_t"로 바뀐다. "until"도 초로 바뀐다.
- 앵커 대신 숫자를 쓰면 그 장면 시작부터의 초다(예: "at": 0.4).
"""
import json
import os
import shutil
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))   # python3 -I로 실행해도 같은 폴더 모듈을 찾게
from scene_lib import Anchors, load_scene, paths

TAIL = 1.0        # 마지막 문장 뒤 여유
END_CARD = 2.6    # 끝 카드 길이


def resolve(obj, A, start, where):
    if isinstance(obj, list):
        return [resolve(x, A, start, where) for x in obj]
    if not isinstance(obj, dict):
        return obj
    out = {}
    for k, v in obj.items():
        if k == "at" or k.endswith("_at") or k == "until":
            t = start + float(v) if isinstance(v, (int, float)) else A(v, where)
            out["t" if k == "at" else ("until" if k == "until" else k[:-3] + "_t")] = t
        else:
            out[k] = resolve(v, A, start, where)
    return out


def main():
    proj = sys.argv[1]
    sc = load_scene(proj)
    P = paths(proj)
    tp = os.path.join(P["audio"], "timing.json")
    if not os.path.exists(tp):
        sys.exit("[오류] audio/timing.json이 없습니다. voice.py를 먼저 실행하십시오.")
    timing = json.load(open(tp, encoding="utf-8"))
    A = Anchors(timing)
    shots = []
    for i, s in enumerate(sc["shots"]):
        sid = s.get("id") or f"s{i + 1:02d}"
        where = f"장면 {sid}:"
        if not s.get("headline") and s.get("plate") not in sc["plates"]:
            sys.exit(f"[오류] {where} plate \"{s.get('plate')}\"가 plates에 없습니다.")
        for c in (s.get("chars") or []) + (s.get("behind") or []):
            if c.get("name") not in sc["characters"]:
                sys.exit(f"[오류] {where} 캐릭터 \"{c.get('name')}\"가 characters에 없습니다.")
        st = 0.0 if i == 0 else A(s["at"], where) if "at" in s else None
        if st is None:
            sys.exit(f"[오류] {where} 시작 어절 at이 없습니다.")
        body = {k: v for k, v in s.items() if k != "at"}
        sh = resolve(body, A, st, where)
        sh.update({"id": sid, "start": round(st, 3)})
        shots.append(sh)
    for a, b in zip(shots, shots[1:]):
        if b["start"] <= a["start"]:
            sys.exit(f"[오류] 장면 {b['id']}가 앞 장면 {a['id']}보다 먼저 시작합니다. at 어절을 확인하십시오.")
    end = round(timing["duration"] + TAIL, 3)
    for i, s in enumerate(shots):
        s["end"] = shots[i + 1]["start"] if i + 1 < len(shots) else end
    if sc.get("end_card"):
        shots.append({"id": "end", "end_card": True, "start": end, "end": round(end + END_CARD, 3)})
    wipes = [s["start"] for s in shots[1:] if s.get("wipe") or s.get("end_card")]
    tl = {"duration": shots[-1]["end"], "shots": shots, "wipes": wipes, "subs": timing["subs"],
          "top_title": sc.get("top_title"), "end_card": sc.get("end_card")}
    if sc.get("font"):
        f = os.path.expanduser(sc["font"])
        if not os.path.exists(f):
            sys.exit(f"[오류] 글꼴 파일이 없습니다: {f}")
        name = "font" + os.path.splitext(f)[1]
        shutil.copy(f, os.path.join(P["render"], name))
        tl["font"] = name
    os.makedirs(P["render"], exist_ok=True)
    with open(os.path.join(P["render"], "timeline.json"), "w", encoding="utf-8") as fp:
        json.dump(tl, fp, ensure_ascii=False, indent=1)
    for s in shots:
        print(f"  {s['id']:12} {s['start']:6.2f}~{s['end']:6.2f} ({s['end'] - s['start']:4.2f}초)")
    short = [s["id"] for s in shots if s["end"] - s["start"] < 0.9 and not s.get("end_card")]
    if short:
        print(f"[주의] 0.9초보다 짧은 장면: {', '.join(short)}. 앵커를 옮기거나 장면을 합치십시오.")
    print(f"[완료] 영상 길이 {tl['duration']:.1f}초. 다음: render.py sheet")


if __name__ == "__main__":
    main()
