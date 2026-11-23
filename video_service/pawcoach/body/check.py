"""身体信号的取样：一段视频 / 一张图 → 逐帧关键点 → signals.summarize。

练前状态检查（POST /body-check）、上传分析（analyze 里附带）和实时计时共用。
帧率默认 5 帧 / 秒：摇尾、打哈欠这类信号需要；整段分析可以传更低的 fps 省时间。
"""

from __future__ import annotations

from pathlib import Path

import numpy as np

from pawcoach.body.signals import FrameSignals, frame_signals, summarize

MAX_CHECK_S = 20.0


def read_frame(engine, rgb: np.ndarray, t: float) -> FrameSignals | None:
    """一帧 → FrameSignals（没找到狗返回 None）。姿势用和线上一样的"规则 + 分类器"合用结果。"""
    from pawcoach.pose.posture_model import default_cnn, kp_in_model_order
    from pawcoach.pose.rules import classify_frame, merge_read

    got = engine.keypoints(rgb)
    if got is None:
        return None
    kp, box = got
    names = engine.bodyparts
    ix = {n: i for i, n in enumerate(names)}
    label, conf = classify_frame(kp[:, :2], kp[:, 2], ix, float(min(rgb.shape[:2])), engine.rules)
    side_view = label != "unclear"           # 规则能判 = 侧面可判断，尾巴 / 身体高低才可信
    if label != "sit":
        cnn = default_cnn()
        if cnn is not None:
            label, _ = merge_read(label, conf, cnn.predict(rgb, box), kp[:, 2], engine.rules)
    return frame_signals(kp_in_model_order(kp[:, :2], kp[:, 2], names), t,
                         None if label == "unclear" else label, side_view)


def check_video(engine, path: str | Path, fps: float = 5.0, max_s: float | None = MAX_CHECK_S) -> dict:
    import cv2

    cap = cv2.VideoCapture(str(path))
    src_fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    n = int(cap.get(cv2.CAP_PROP_FRAME_COUNT) or 0)
    dur = n / src_fps if n else 0.0
    end = min(dur, max_s) if max_s else dur
    step = 1.0 / fps
    frames, t, k = [], 0.0, 0
    target = 0.0
    while True:
        ok, bgr = cap.read()
        if not ok:
            break
        t = k / src_fps
        k += 1
        if t > end + 1e-6:
            break
        if t + 1e-6 < target:
            continue
        target += step
        frames.append(read_frame(engine, cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB), round(t, 3)))
    cap.release()
    out = summarize(frames).to_dict()
    out["kind"] = "video"
    out["postures"] = _postures(frames)
    return out


def check_image(engine, rgb: np.ndarray) -> dict:
    """单张图：只有静态信号（尾巴、身体高低、张嘴、姿势），没有摇尾 / 喘气 / 动得多这类需要时间的信号。"""
    from pawcoach.body.signals import PANT_OPEN, YAWN_OPEN

    f = read_frame(engine, rgb, 0.0)
    out = {"kind": "image", "frames": 1, "usable": int(f is not None and f.center is not None), "signals": [],
           "metrics": {}, "postures": _postures([f])}
    if f is None:
        return out
    for sid, on in (("tail_tucked", f.tail_tucked), ("tail_high", f.tail_high), ("body_low", f.body_low),
                    ("mouth_open_wide", (f.mouth_open or 0) > YAWN_OPEN)):
        if on:
            out["signals"].append({"id": sid, "t_start": 0.0, "t_end": 0.0})
    if f.mouth_open is not None:
        out["metrics"]["mouth_open"] = f.mouth_open
        out["metrics"]["mouth_open_over_pant"] = f.mouth_open > PANT_OPEN
    return out


def _postures(frames) -> dict[str, float]:
    labs = [f.posture for f in frames if f is not None and f.posture]
    return {p: round(labs.count(p) / len(labs), 3) for p in ("sit", "stand", "down")} if labs else {}
