"""v3：在一段视频上逐帧比较"只用规则"和"规则 + 多角度分类器"。

用法：python scripts/v3_eval_clip.py <视频> [--labels 秒:标签,秒-秒:标签 ...] [--step 0.2]
例：中文俯拍  --labels 1:stand,2-16:sit
"""

from __future__ import annotations

import argparse
import sys
from collections import Counter
from pathlib import Path

import cv2
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from pawcoach.live.pose_live import PoseEngine  # noqa: E402
from pawcoach.pose.posture_model import PostureCNN, PostureModel, kp_in_model_order  # noqa: E402
from pawcoach.pose.rules import PoseRules, _hybrid, classify_frame  # noqa: E402


def parse_labels(spec: str) -> list[tuple[float, float, str]]:
    out = []
    for part in spec.split(","):
        rng, lab = part.split(":")
        a, _, b = rng.partition("-")
        out.append((float(a), float(b or a) + 0.999, lab))
    return out


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("--labels", default="")
    ap.add_argument("--step", type=float, default=0.2)
    a = ap.parse_args()
    truth = parse_labels(a.labels) if a.labels else []
    eng, model, rules = PoseEngine(), PostureModel(), PoseRules()
    cnn = PostureCNN() if PostureCNN.available() else None
    eng.load()
    names = eng.bodyparts
    ix = {n: i for i, n in enumerate(names)}
    cap = cv2.VideoCapture(a.video)
    dur = cap.get(7) / cap.get(5)
    rows = []
    t = 0.0
    while t < dur:
        cap.set(cv2.CAP_PROP_POS_MSEC, t * 1000)
        ok, bgr = cap.read()
        if not ok:
            break
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        got = eng.keypoints(rgb)
        c_lab = "no_dog"
        if got is None:
            r_lab = h_lab = m_lab = "no_dog"
        else:
            kp, _ = got
            h, w = rgb.shape[:2]
            r_lab, c = classify_frame(kp[:, :2], kp[:, 2], ix, float(min(w, h)), rules)
            h_lab, _ = _hybrid(r_lab, c, kp[:, :2], kp[:, 2], names, model, rules)
            m = model.predict(kp_in_model_order(kp[:, :2], kp[:, 2], names))
            m_lab = f"{m.label}({m.prob:.2f})"
            if cnn is not None:
                cr = cnn.predict(rgb, got[1])
                c_lab = cr.label
                m_lab += f" cnn={cr.label}({cr.prob:.2f})"
        gt = next((lab for x, y, lab in truth if x <= t <= y), "")
        rows.append((t, gt, r_lab, h_lab, m_lab, c_lab))
        t = round(t + a.step, 3)
    for r in rows:
        print(f"{r[0]:5.1f}  truth={r[1]:6s} rules={r[2]:8s} hybrid={r[3]:8s} model={r[4]}")
    lab_rows = [r for r in rows if r[1]]
    if lab_rows:
        for k, name in ((2, "rules"), (3, "hybrid"), (5, "cnn")):
            ok = sum(1 for r in lab_rows if r[k] == r[1])
            unclear = sum(1 for r in lab_rows if r[k] in ("unclear", "no_dog"))
            wrong = len(lab_rows) - ok - unclear
            print(f"{name}: correct {ok}/{len(lab_rows)}  unclear {unclear}  wrong {wrong}")
        print("hybrid labels:", Counter(r[3] for r in lab_rows))


if __name__ == "__main__":
    main()
