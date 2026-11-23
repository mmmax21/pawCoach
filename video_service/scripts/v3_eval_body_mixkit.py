"""v3 身体信号：在按标题分组的 Mixkit 素材上跑 /body-check 同一套取样，看各组信号是否符合预期。"""

from __future__ import annotations

import glob
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from pawcoach.body.check import check_video  # noqa: E402
from pawcoach.live.pose_live import shared_engine  # noqa: E402


def main() -> None:
    groups = json.loads((ROOT / "tests/fixtures/mixkit_body_groups.json").read_text())["groups"]
    eng = shared_engine()
    eng.load()
    for g, ids in groups.items():
        print("##", g)
        for vid in ids:
            fs = glob.glob(str(ROOT / f"data/datasets/mixkit/{vid}-*.mp4"))
            if not fs:
                continue
            r = check_video(eng, fs[0], fps=5.0, max_s=12.0)
            c = {}
            for s in r["signals"]:
                c[s["id"]] = c.get(s["id"], 0) + 1
            m = r["metrics"]
            print(f"  {vid}: usable {r['usable']}/{r['frames']} motion {m.get('motion_mean')} pant {m.get('panting_ratio')} "
                  f"post {r['postures']} signals {c}")


if __name__ == "__main__":
    main()
