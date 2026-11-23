"""v3：在 Mixkit 素材（tests/fixtures/mixkit_pose_labels.json 逐秒标注）上比较"只用规则"和"规则 + 图像分类器"。

用法：python scripts/v3_eval_mixkit.py [--download]
--download：把标注里的视频（360p）下载到 data/datasets/mixkit/（Mixkit License，免费使用，不进仓库）。
"""

from __future__ import annotations

import argparse
import json
import sys
import urllib.request
from collections import Counter, defaultdict
from pathlib import Path

import cv2

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from pawcoach.live.pose_live import PoseEngine  # noqa: E402
from pawcoach.pose.posture_model import CNN_MIN_PROB, PostureCNN  # noqa: E402
from pawcoach.pose.rules import PoseRules, classify_frame, merge_read  # noqa: E402

SPEC = ROOT / "tests/fixtures/mixkit_pose_labels.json"
DATA = ROOT / "data/datasets/mixkit"


def seconds(labels: dict[str, str]):
    for rng, lab in labels.items():
        a, _, b = rng.partition("-")
        for s in range(int(a), int(b or a) + 1):
            yield s, lab


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--download", action="store_true")
    ap.add_argument("--override", type=float, default=None, help="试验：改判站/趴的概率门槛（默认用 rules.OVERRIDE_PROB）")
    a = ap.parse_args()
    spec = json.loads(SPEC.read_text())["clips"]
    if a.override is not None:
        import pawcoach.pose.rules as R

        R.OVERRIDE_PROB = a.override
    DATA.mkdir(parents=True, exist_ok=True)
    eng, rules = PoseEngine(), PoseRules()
    cnn = PostureCNN(min_prob=CNN_MIN_PROB)
    eng.load()
    names = eng.bodyparts
    ix = {n: i for i, n in enumerate(names)}
    tally: dict[tuple[str, str], Counter] = defaultdict(Counter)
    for vid, c in spec.items():
        path = DATA / Path(c["url"]).name
        if not path.exists():
            if not a.download:
                print("missing", path.name, "(run with --download)")
                continue
            urllib.request.urlretrieve(c["url"], path)
        cap = cv2.VideoCapture(str(path))
        row = []
        for s, truth in seconds(c["labels"]):
            cap.set(cv2.CAP_PROP_POS_MSEC, (s + 0.5) * 1000)
            ok, bgr = cap.read()
            if not ok:
                continue
            rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
            got = eng.keypoints(rgb)
            if got is None:
                r = h = "no_dog"
            else:
                kp, box = got
                r, conf = classify_frame(kp[:, :2], kp[:, 2], ix, float(min(rgb.shape[:2])), rules)
                h, _ = (r, conf) if r == "sit" else merge_read(r, conf, cnn.predict(rgb, box), kp[:, 2], rules)
            for name, x in (("rules", r), ("v3", h)):
                tally[(c["view"], name)]["correct" if x == truth else ("unclear" if x in ("unclear", "no_dog") else "wrong")] += 1
            row.append(f"{s}:{truth[:2]}/{r[:2]}/{h[:2]}")
        print(vid, c["view"], " ".join(row))
    print()
    for view in ("side", "front", "top"):
        for name in ("rules", "v3"):
            t = tally[(view, name)]
            n = sum(t.values())
            if n:
                print(f"{view:5s} {name:5s} correct {t['correct']:3d}/{n}  unclear {t['unclear']:3d}  wrong {t['wrong']:3d}")


if __name__ == "__main__":
    main()
