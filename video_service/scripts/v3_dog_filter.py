"""v3 俯拍标注辅助：用 YOLO 过滤出含有一只够大的狗的图片，输出 {文件: [x1,y1,x2,y2]}。

用法：python scripts/v3_dog_filter.py <图片目录> <输出 json> [--min-area 0.04]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("out")
    ap.add_argument("--min-area", type=float, default=0.04)
    a = ap.parse_args()
    from ultralytics import YOLO

    from pawcoach.pose.detect import DEFAULT_WEIGHTS

    model = YOLO(DEFAULT_WEIGHTS if Path(ROOT / DEFAULT_WEIGHTS).exists() else "yolov8n.pt")
    keep = {}
    files = sorted(Path(a.src).glob("*.jpg"))
    for f in files:
        try:
            r = model.predict(str(f), classes=[16], conf=0.4, verbose=False)[0]
        except Exception:
            continue
        if not len(r.boxes):
            continue
        h, w = r.orig_shape
        best = max(range(len(r.boxes)), key=lambda i: float((r.boxes.xyxy[i][2] - r.boxes.xyxy[i][0]) * (r.boxes.xyxy[i][3] - r.boxes.xyxy[i][1])))
        x1, y1, x2, y2 = (float(v) for v in r.boxes.xyxy[best])
        if (x2 - x1) * (y2 - y1) / (w * h) >= a.min_area:
            keep[f.name] = [x1, y1, x2, y2]
    Path(a.out).write_text(json.dumps(keep))
    print(f"{len(keep)} / {len(files)} images kept")


if __name__ == "__main__":
    main()
