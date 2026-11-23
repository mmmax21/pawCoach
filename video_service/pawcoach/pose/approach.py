"""v3：召回类技能的"狗跑到主人面前"（arrive）。用 YOLO 同时找人和狗，看两者的框离得多近。

召回练的是"说一次'来'，狗跑到你面前停下"，这里没有坐 / 趴可看，轮次的终点换成"狗到了主人面前"：
- 近：狗框和人框的水平间隙 ≤ NEAR_GAP × 人高，且狗框底边和人框底边（脚）的高度差 ≤ NEAR_FOOT × 人高；
- 远：水平间隙 ≥ FAR_GAP × 人高（画面里看起来离开主人至少一个身位）；
- 一次"到达"：先远过（至少 MIN_FAR_S 秒），然后近、并持续至少 MIN_NEAR_S 秒。到达片段的 label 是 "arrive"，
  交给 events/align.py 按目标姿势 "arrive" 切轮次（口令 → 到达），反应时间 = 到达时刻 - 口令时刻。

画面里看不出真实距离（没有标定），"3 米以上"只能用"至少一个身位"近似。阈值照 Mixkit 两段实拍定的
（tests/fixtures/mixkit_recall_labels.json，见 reports/V3-posture.md），样本很少，不要当作通用值。
"""

from __future__ import annotations

from pathlib import Path

import numpy as np

from pawcoach.schema import PoseSegment

PERSON = 0
DOG_CLASSES = (15, 16)
NEAR_GAP = 0.25
NEAR_FOOT = 0.35
FAR_GAP = 1.0
MIN_FAR_S = 0.5
MIN_NEAR_S = 0.5
GAP_FRAMES = 3   # 近的片段里允许的检测空档（帧）


def detect_people_and_dogs(video: Path, weights: str, device: str = "auto"):
    """逐帧：(人框列表, 狗框列表)，框为 (conf, x1, y1, x2, y2)。"""
    from ultralytics import YOLO

    if device == "auto":
        import torch

        device = "mps" if torch.backends.mps.is_available() else ("cuda" if torch.cuda.is_available() else "cpu")
    model = YOLO(weights)
    out = []
    for r in model.predict(str(video), classes=[PERSON, *DOG_CLASSES], conf=0.25, verbose=False, stream=True,
                           device=device):
        people, dogs = [], []
        for c, s, b in zip(r.boxes.cls, r.boxes.conf, r.boxes.xyxy):
            item = (float(s), *(float(v) for v in b))
            (people if int(c) == PERSON else dogs).append(item)
        out.append((people, dogs))
    return out


def _largest(boxes):
    return max(boxes, key=lambda b: (b[3] - b[1]) * (b[4] - b[2])) if boxes else None


def distance_ratio(person, dog) -> tuple[float, float]:
    """(水平间隙 / 人高, 脚的高度差 / 人高)。框为 (conf, x1, y1, x2, y2)。"""
    _, px1, py1, px2, py2 = person
    _, dx1, dy1, dx2, dy2 = dog
    ph = max(py2 - py1, 1e-6)
    gap = max(0.0, max(dx1 - px2, px1 - dx2))
    return gap / ph, abs(dy2 - py2) / ph


def proximity(frames) -> np.ndarray:
    """逐帧状态：1 近、-1 远、0 中间或看不到（人或狗缺一个）。主人取画面里最大的人，狗取最大的狗。"""
    state = np.zeros(len(frames), dtype=int)
    for i, (people, dogs) in enumerate(frames):
        p, d = _largest(people), _largest(dogs)
        if p is None or d is None:
            continue
        gap, foot = distance_ratio(p, d)
        if gap <= NEAR_GAP and foot <= NEAR_FOOT:
            state[i] = 1
        elif gap >= FAR_GAP:
            state[i] = -1
    return state


def arrive_segments(state: np.ndarray, fps: float, conf: float = 0.8) -> list[PoseSegment]:
    """先远（累计 ≥MIN_FAR_S，中间偶尔检测不到不算中断）再近（连续 ≥MIN_NEAR_S）→ 一段 arrive。

    到达片段从开始近的那一帧到不再近为止；一次到达之后要重新远过才算下一次。
    """
    min_far, min_near = max(1, round(MIN_FAR_S * fps)), max(1, round(MIN_NEAR_S * fps))
    segs: list[PoseSegment] = []
    far_count = 0
    i, n = 0, len(state)
    while i < n:
        if state[i] == -1:
            far_count += 1
            i += 1
            continue
        if state[i] == 1:
            j = i
            # 近的片段里偶尔一两帧没检测到（state 0）不算中断；再远起来才算结束
            while j < n and (state[j] == 1 or (state[j] == 0 and 1 in state[j + 1:j + 1 + GAP_FRAMES])):
                j += 1
            if far_count >= min_far and j - i >= min_near:
                segs.append(PoseSegment(label="arrive", t_start=round(i / fps, 3), t_end=round(j / fps, 3), conf=conf))
            far_count = 0  # 狗在主人身边：之后要重新离开才算下一次
            i = j
            continue
        i += 1
    return segs


def extract_arrivals(video_path: Path, fps: float, weights: str) -> tuple[list[PoseSegment], float]:
    """(到达片段, 人或狗看不到的时间占比)。"""
    frames = detect_people_and_dogs(Path(video_path), weights)
    missing = sum(1 for p, d in frames if not p or not d) / max(1, len(frames))
    return arrive_segments(proximity(frames), fps), round(missing, 3)
