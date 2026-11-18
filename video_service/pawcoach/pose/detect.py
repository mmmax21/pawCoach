"""B3：狗检测与主狗跟踪。

用 YOLO（COCO 预训练）找画面里的狗，只保留一只主狗，并回答「这一帧狗在不在画面里」。

两点实测结论（见 reports/B3.md）：
1. COCO 的 dog 类不够用。dog3.mp4 里坐着的柯利犬大部分帧被认成 cat（置信度 0.8 以上），
   只认 dog 会漏掉 41% 的帧。所以候选类别取 dog 和 cat。其他动物类别（cow、horse 等）在 dog2 里有
   少量误检，不收。
2. 检测结果是逐帧独立的，会闪。要靠 IoU 跟踪选主狗，再补短空洞，才能当「在不在画面」用。

推理需要 ultralytics（只装在 .venv-b）。选主狗、补空洞、框内关键点占比都是纯 numpy，.venv 里能单测。
"""

from __future__ import annotations

from pathlib import Path

import numpy as np

# COCO 类别号：cat=15, dog=16。其他动物类别不收。
ANIMAL_CLASSES = {15: "cat", 16: "dog"}
DEFAULT_WEIGHTS = "data/models/yolov8n.pt"
MIN_CONF = 0.25        # 低于此置信度的框不要
MIN_IOU_FOLLOW = 0.3   # 与上一帧主狗框 IoU 不低于此值，视为同一只
MAX_GAP_S = 0.5        # 狗短暂没检测到（小于此时长）当作仍在画面里
EDGE_PX = 2            # 框边离画面边缘不超过此像素，算「贴边」
# 贴边且框面积小于画面的此比例，当作狗只露出一角。0.08 是照 dog3.mp4 的几个样本定的
# （露一角 3.5%~6.3%，贴边但算整只的站姿 9%~16%），两组只差一点，只有一只狗一个视频，见 reports/B3.md。
MIN_EDGE_AREA_FRAC = 0.08

# 一帧一行：[conf, x1, y1, x2, y2]；这一帧没有狗时整行 NaN
Track = np.ndarray


def iou(a: np.ndarray, b: np.ndarray) -> float:
    ix1, iy1 = max(a[0], b[0]), max(a[1], b[1])
    ix2, iy2 = min(a[2], b[2]), min(a[3], b[3])
    inter = max(0.0, ix2 - ix1) * max(0.0, iy2 - iy1)
    union = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
    return float(inter / union) if union > 0 else 0.0


def select_main_dog(frames: list[list[tuple[float, tuple[float, float, float, float]]]]) -> Track:
    """逐帧候选框 → 主狗轨迹。

    每帧候选是 [(conf, (x1, y1, x2, y2)), ...]。
    上一帧有主狗时，选 IoU 最大且不低于 MIN_IOU_FOLLOW 的框；否则（第一帧、或跟丢）选 面积 x 置信度 最大的框。
    """
    track = np.full((len(frames), 5), np.nan)
    prev: np.ndarray | None = None
    for i, cands in enumerate(frames):
        cands = [c for c in cands if c[0] >= MIN_CONF]
        if not cands:
            continue  # 保留 prev：短暂漏检后还能接上同一只狗
        chosen = None
        if prev is not None:
            scored = [(iou(prev, np.array(b)), c) for c in cands for b in [c[1]]]
            best_iou, best = max(scored, key=lambda s: s[0])
            if best_iou >= MIN_IOU_FOLLOW:
                chosen = best
        if chosen is None:
            chosen = max(cands, key=lambda c: c[0] * max(0.0, (c[1][2] - c[1][0]) * (c[1][3] - c[1][1])))
        track[i] = (chosen[0], *chosen[1])
        prev = np.array(chosen[1])
    return track


def visible_mask(track: Track, fps: float, max_gap_s: float = MAX_GAP_S) -> np.ndarray:
    """每帧狗是否在画面里：有框的帧，加上前后都有框、中间空洞短于 max_gap_s 的帧。"""
    present = ~np.isnan(track[:, 0])
    mask = present.copy()
    max_gap = max(1, round(max_gap_s * fps))
    idx = np.flatnonzero(present)
    for a, b in zip(idx, idx[1:]):
        if 1 < b - a <= max_gap + 1:
            mask[a:b] = True
    return mask


def in_frame_mask(
    track: Track,
    fps: float,
    width: int,
    height: int,
    min_edge_area_frac: float = MIN_EDGE_AREA_FRAC,
    max_gap_s: float = MAX_GAP_S,
) -> np.ndarray:
    """每帧「狗完整在画面里」。

    先把「贴着画面边缘的小框」剔掉（狗只露出一角，刚进入或正在离开画面，关键点和姿态都不可信），
    再对剩下的框补短空洞。顺序不能反：先补洞再剔，补出来的帧没有框，剔不掉。
    """
    with np.errstate(invalid="ignore"):
        x1, y1, x2, y2 = track[:, 1], track[:, 2], track[:, 3], track[:, 4]
        area = (x2 - x1) * (y2 - y1) / float(width * height)
        edge = (x1 <= EDGE_PX) | (y1 <= EDGE_PX) | (x2 >= width - EDGE_PX) | (y2 >= height - EDGE_PX)
        truncated = edge & (area < min_edge_area_frac)
    full = track.copy()
    full[truncated] = np.nan
    return visible_mask(full, fps, max_gap_s)


def detect_frames(video: Path, weights: str = DEFAULT_WEIGHTS, device: str = "auto"):
    """逐帧跑 YOLO，返回每帧的候选框 [(conf, (x1, y1, x2, y2)), ...]。需要 .venv-b 里的 ultralytics。"""
    try:
        from ultralytics import YOLO
    except ImportError as e:
        raise RuntimeError("没有安装 ultralytics。检测要在 .venv-b 里跑，见 requirements-b.txt") from e

    if device == "auto":
        import torch

        device = "mps" if torch.backends.mps.is_available() else ("cuda" if torch.cuda.is_available() else "cpu")
    model = YOLO(weights)
    frames = []
    for r in model.predict(str(video), classes=list(ANIMAL_CLASSES), conf=0.1, verbose=False, stream=True, device=device):
        frames.append([(float(s), tuple(float(v) for v in b)) for s, b in zip(r.boxes.conf, r.boxes.xyxy)])
    return frames


def track_path(video: Path, pose_dir: Path) -> Path:
    # 检测在标准化产物上跑，缓存键 = 检测视频名（如 dog3.norm）
    return pose_dir / f"{video.stem}_dogbox.npy"


def detect_main_dog(video: Path, pose_dir: Path, weights: str = DEFAULT_WEIGHTS, device: str = "auto", use_cache: bool = True) -> Track:
    """主狗轨迹，带缓存（data/pose/<视频名>_dogbox.npy）。"""
    path = track_path(video, pose_dir)
    if use_cache and path.exists():
        return np.load(path)
    track = select_main_dog(detect_frames(video, weights, device))
    pose_dir.mkdir(parents=True, exist_ok=True)
    np.save(path, track)
    return track
