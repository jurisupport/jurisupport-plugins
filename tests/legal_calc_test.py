#!/usr/bin/env python3
"""Regression tests for the legal-calc skill helper (hand-computed expectations)."""

from __future__ import annotations

import os
import subprocess
import sys
import tempfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "plugins" / "jurisupport" / "skills" / "legal-calc" / "legal_calc.py"

CASES = [
    # 항소기간 2주: 송달 10.15.(목) → 기산 10.16. → 말일 10.29.(목)
    ("만료일: 2026. 10. 29.(목)", ["deadline", "2026-10-15", "2", "주"]),
    # 1개월, 최종 월 해당일 없음 → 2.28.(토) → 3.1.(일·삼일절) → 3.2.(대체공휴일) → 3.3.(화)
    ("만료일: 2026. 3. 3.(화)", ["deadline", "2026-01-30", "1", "월"]),
    # 7일, 말일 토요일 → 일요일 → 월요일
    ("만료일: 2026. 10. 26.(월)", ["deadline", "2026-10-17", "7", "일"]),
    # 형사 구속기간 10일: 초일 산입, 토요일이라도 연장 없음
    ("만료일: 2026. 10. 10.(토)", ["deadline", "2026-10-01", "10", "일", "--mode", "criminal", "--crim-kind", "구속기간"]),
    # 1년, 기산일 2.29. 해당일 없음 → 2.28.(금)
    ("만료일: 2025. 2. 28.(금)", ["deadline", "2024-02-28", "1", "년"]),
    # 지연손해금: 16,000,000 × 12% × 359/365 = 1,888,438.35 → 1,888,438원
    ("합계 1,888,438원", ["interest", "16,000,000", "--seg", "2025-11-05:2026-10-29:12"]),
]


def run(args, env):
    return subprocess.run([sys.executable, "-I", str(SCRIPT), *args], capture_output=True, text=True, env=env).stdout


def main() -> int:
    failed = 0
    with tempfile.TemporaryDirectory() as cache:
        # 네트워크 없이, 빈 캐시로 동봉 공휴일 자료만 써서 결과가 재현되는지 본다.
        env = {**os.environ, "LEGAL_CALC_OFFLINE": "1", "LEGAL_CALC_CACHE_DIR": cache, "PYTHONIOENCODING": "utf-8"}
        for expected, args in CASES:
            out = run(args, env)
            if expected in out:
                print(f"PASS: {' '.join(args)}")
            else:
                failed += 1
                print(f"FAIL: {' '.join(args)} (expected {expected!r})\n{out}")
        # 동봉 자료를 쓴 경우 [주의]를 출력해야 한다.
        out = run(["deadline", "2026-01-30", "1", "월"], env)
        if "[주의]" in out and "동봉 자료" in out:
            print("PASS: bundled holiday notice")
        else:
            failed += 1
            print(f"FAIL: bundled holiday notice missing\n{out}")
        # 자료가 없는 연도는 [미확인]을 출력해야 한다.
        out = run(["deadline", "2030-03-01", "7", "일"], env)
        if "[미확인]" in out:
            print("PASS: unknown-year warning")
        else:
            failed += 1
            print(f"FAIL: unknown-year warning missing\n{out}")
    total = len(CASES) + 2
    print(f"{total - failed} / {total} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
