"""B2：用逐秒人工标注评估姿态规则。

用法（.venv-b 里，因为要读 H5）：
    python scripts/b2_eval.py dog3
    python scripts/b2_eval.py dog2
读 data/raw/<name>.mp4、data/pose/<name>_superanimal*.h5、tests/fixtures/<name>_pose_labels.json，
输出片段列表、区间时长之和、逐秒准确率和混淆矩阵。
"""

from __future__ import annotations

import argparse
import json
from collections import Counter
from pathlib import Path

from pawcoach.pose.rules import PoseRules
from pawcoach.pose.superanimal import SuperAnimalPoseExtractor
from pawcoach.video.probe import load_video


LABEL_OFFSET_S = 0.5


def label_at(segs, t: float) -> str:
    for s in segs:
        if s.t_start <= t < s.t_end:
            return s.label
    return "unclear"


def evaluate(name: str, rules: PoseRules | None = None, verbose: bool = True, use_detection: bool = False) -> dict:
    video = load_video(f"data/raw/{name}.mp4")
    segs = SuperAnimalPoseExtractor(rules=rules, run_if_missing=False, use_detection=use_detection).extract(video)
    truth = json.load(open(f"tests/fixtures/{name}_pose_labels.json"))["labels"]

    total = sum(s.t_end - s.t_start for s in segs)
    confusion: Counter = Counter()
    wrong = []
    for sec, lab in sorted(truth.items(), key=lambda kv: int(kv[0])):
        # 标注图是 ffmpeg fps=1 抽的，第 k 张实际是 k+0.5 秒的画面
        pred = label_at(segs, int(sec) + LABEL_OFFSET_S)
        confusion[(lab, pred)] += 1
        if pred != lab:
            wrong.append((int(sec), lab, pred))
    n = sum(confusion.values())
    correct = sum(v for (a, b), v in confusion.items() if a == b)

    if verbose:
        print(f"== {name}  视频 {video.duration:.2f}s  片段 {len(segs)} 个，时长之和 {total:.2f}s")
        for s in segs:
            print(f"  {s.t_start:6.2f} - {s.t_end:6.2f}  {s.label:8s} conf={s.conf:.2f}")
        print(f"逐秒准确率 {correct}/{n} = {correct / n:.1%}")
        for (a, b), v in sorted(confusion.items()):
            print(f"  真值 {a:8s} → 预测 {b:8s}: {v}")
        print("错误的秒:", wrong)
    return {"total": total, "duration": video.duration, "correct": correct, "n": n, "wrong": wrong, "segs": segs}


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("name")
    ap.add_argument("--detect", action="store_true", help="加上 B3 的狗检测：狗不在画面的帧标 unclear")
    a = ap.parse_args()
    evaluate(a.name, use_detection=a.detect)
