"""B3：用人工标注评估「狗在不在画面」，并检查检测框能否过滤关键点误检。

用法（.venv-b 里）：
    python scripts/b3_eval.py dog3
标注里 unclear = 画面里没有狗或只露出边缘一小部分；sit / stand = 狗在画面里。
需要先有 data/pose/<名>_dogbox.npy（scripts/b3_detect.py 生成）。
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

import numpy as np

from pawcoach.pose.detect import detect_main_dog, in_frame_mask, visible_mask
from pawcoach.video.probe import load_video

LABEL_OFFSET_S = 0.5  # 标注图是 ffmpeg fps=1 抽的，第 k 张实际是 k+0.5 秒


def evaluate(name: str, fps: float = 30.0, verbose: bool = True, edge_rule: bool = True) -> dict:
    video = load_video(f"data/raw/{name}.mp4")
    track = detect_main_dog(Path(video.path), Path("data/pose"))
    if edge_rule:
        vis = in_frame_mask(track, fps, *video.display_size)
    else:
        vis = visible_mask(track, fps)
    labels = json.load(open(f"tests/fixtures/{name}_pose_labels.json"))["labels"]

    tp = fp = fn = tn = 0
    wrong = []
    for k, lab in sorted(labels.items(), key=lambda kv: int(kv[0])):
        f = min(int((int(k) + LABEL_OFFSET_S) * fps), len(vis) - 1)
        truth_in = lab != "unclear"
        pred_in = bool(vis[f])
        if truth_in and pred_in:
            tp += 1
        elif truth_in and not pred_in:
            fn += 1
            wrong.append((int(k), lab, "判成不在"))
        elif not truth_in and pred_in:
            fp += 1
            wrong.append((int(k), lab, "判成在"))
        else:
            tn += 1
    n = tp + fp + fn + tn
    if verbose:
        print(f"== {name}  {'含贴边小框规则' if edge_rule else '只看有没有框'}")
        print(f"  标注 {n} 秒：狗在画面（标注 sit/stand）{tp + fn}，不在或只露边缘（unclear）{fp + tn}")
        print(f"  正确 {tp + tn}/{n}；漏（狗在，判成不在）{fn}；误（狗不在，判成在）{fp}")
        print(f"  错误的秒：{wrong}")
    return {"tp": tp, "fp": fp, "fn": fn, "tn": tn, "wrong": wrong}


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    name = ap.parse_args().name
    evaluate(name, edge_rule=False)
    evaluate(name, edge_rule=True)
