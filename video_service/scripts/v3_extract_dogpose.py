"""v3 多角度姿态：在 DogPoseCV（Stanford Dogs 子集，Apache-2.0）上跑 YOLO + SuperAnimal，存关键点。

数据集：https://huggingface.co/datasets/stockeh/dog-pose-cv
  data/labels/*.csv（id,label：standing / sitting / lying / undefined）+ data/images/<类>/<id>
输出：data/datasets/dogposecv/keypoints.npz（kp N×39×3、box N×4、wh N×2、label N、id N）

用法：python scripts/v3_extract_dogpose.py [--limit-per-class 0]
"""

from __future__ import annotations

import argparse
import csv
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from pawcoach.live.pose_live import PoseEngine  # noqa: E402

DS = ROOT / "data/datasets/dogposecv/data"
LABELS = {"standing": "stand", "sitting": "sit", "lying": "down"}


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--limit-per-class", type=int, default=0)
    ap.add_argument("--out", default=str(ROOT / "data/datasets/dogposecv/keypoints.npz"))
    a = ap.parse_args()

    images = {p.name: p for p in (DS / "images").rglob("*.jpg")}
    rows: list[tuple[str, str]] = []
    count: dict[str, int] = {}
    for f in sorted((DS / "labels").glob("*.csv")):
        for r in csv.DictReader(f.open()):
            lab = LABELS.get(r["label"])
            if lab is None or r["id"] not in images:
                continue
            if a.limit_per_class and count.get(lab, 0) >= a.limit_per_class:
                continue
            count[lab] = count.get(lab, 0) + 1
            rows.append((r["id"], lab))
    print("images:", len(images), "labeled:", count, flush=True)

    eng = PoseEngine()
    eng.load()
    kps, boxes, whs, labels, ids = [], [], [], [], []
    t0 = time.time()
    for n, (iid, lab) in enumerate(rows):
        try:
            rgb = np.asarray(Image.open(images[iid]).convert("RGB"))
        except Exception:
            continue
        got = eng.keypoints(rgb)
        if got is None:
            continue
        kp, box = got
        kps.append(kp.astype(np.float32))
        boxes.append(box)
        whs.append((rgb.shape[1], rgb.shape[0]))
        labels.append(lab)
        ids.append(iid)
        if n % 500 == 0:
            print(f"{n}/{len(rows)} {time.time() - t0:.0f}s", flush=True)
    np.savez_compressed(
        a.out, kp=np.stack(kps), box=np.array(boxes, np.float32), wh=np.array(whs, np.float32),
        label=np.array(labels), id=np.array(ids), names=np.array(eng.bodyparts),
    )
    print("saved", a.out, len(kps))


if __name__ == "__main__":
    main()
