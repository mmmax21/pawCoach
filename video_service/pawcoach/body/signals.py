"""身体信号（狗的状态）：从 39 个 SuperAnimal 关键点测出几种常见的身体信号。只测量，不下结论。

App 拿到这些信号后，按内容库 body_signals.yaml 的规则决定"适不适合练 / 该不该停 / 要不要转介"，
展示的文字也只来自内容库。这里不判断"狗开心还是焦虑"。

逐帧量（身体长度 L = 脖根到尾根的距离，只在侧面可判断的帧里算尾巴和身体高低）：
- tail_tucked  尾巴夹低：尾尖沿身体轴往头的方向伸（夹到后腿之间），投影 > TAIL_TUCK × L（只看站 / 坐）
- tail_high    尾巴高举：尾尖比尾根高 > TAIL_HIGH × L（只看站姿）
- body_low     身体压低：站姿时 (爪平均高度 - 背中点高度) / L < BODY_LOW
- mouth_open   张嘴程度：上下颌距离 / 鼻尖到脖根距离
- ears_drop    耳朵往后压：耳尖相对耳根的抬起量比这段视频自己的中位数低 EAR_DROP 以上（每只狗耳型不同，只比自己）
片段级：
- tail_wag     摇尾：尾尖相对身体轴的横向位置 2 秒内来回 ≥ 3 次且幅度 > WAG_AMP × L
- panting      喘气：2 秒窗口里张嘴程度 > PANT_OPEN 的帧 ≥ 60%
- yawn         打哈欠：张嘴程度 > YAWN_OPEN 持续 0.4–3 秒，前后都闭着
- high_motion  动得多：身体中心移动速度 > MOTION_HIGH × L / 秒，持续 ≥ 1 秒
- freeze       僵住：几乎不动（< FREEZE_MOTION × L / 秒）≥ 2 秒，且同时有尾巴夹低或身体压低

阈值来源：DogPoseCV 约 7300 张标注照片上同一套关键点的分布（站姿腿高第 10 百分位 0.78、尾巴抬起第 90 百分位 0.45、
张嘴第 90 / 97 百分位 0.39 / 0.68），见 reports/V3-body-signals.md。照片包含各种机位，阈值是粗的，宁可漏报。
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field

import numpy as np

from pawcoach.pose.posture_model import IX, MIN_KP_CONF

TAIL_TUCK = 0.6
TAIL_HIGH = 0.45
BODY_LOW = 0.7
EAR_DROP = 0.25
WAG_AMP = 0.25
PANT_OPEN = 0.39
YAWN_OPEN = 0.68
MOTION_HIGH = 1.0
FREEZE_MOTION = 0.05
PAWS = ("front_left_paw", "front_right_paw", "back_left_paw", "back_right_paw")


@dataclass
class FrameSignals:
    t: float
    posture: str | None = None
    L: float | None = None                 # 身体长度（像素）
    center: tuple[float, float] | None = None
    tail_tucked: bool | None = None
    tail_high: bool | None = None
    tail_side: float | None = None         # 尾尖相对身体轴的横向位置 / L（摇尾用）
    body_low: bool | None = None
    mouth_open: float | None = None
    ear_lift: float | None = None          # (耳根 y - 耳尖 y) / 头长，越大越竖


def _ok(kp, n):
    return kp[IX[n], 2] >= MIN_KP_CONF


def _pt(kp, n):
    return kp[IX[n], :2]


def frame_signals(kp: np.ndarray, t: float, posture: str | None = None, side_view: bool = True) -> FrameSignals:
    """kp：模型顺序的 39×3（pose/posture_model.kp_in_model_order）。side_view：这帧是否侧面可判断（尾巴 / 身体高低只在侧面算）。"""
    fs = FrameSignals(t=t, posture=posture)
    ok = kp[:, 2] >= MIN_KP_CONF
    if ok.sum() >= 3:
        fs.center = tuple(float(v) for v in kp[ok, :2].mean(0))
    if _ok(kp, "neck_base") and _ok(kp, "tail_base"):
        L = float(np.hypot(*(_pt(kp, "neck_base") - _pt(kp, "tail_base"))))
        if L > 1:
            fs.L = L
    head = None
    if _ok(kp, "nose") and _ok(kp, "neck_base"):
        head = float(np.hypot(*(_pt(kp, "nose") - _pt(kp, "neck_base"))))
    if head and head > 1 and _ok(kp, "upper_jaw") and _ok(kp, "lower_jaw"):
        fs.mouth_open = round(float(np.hypot(*(_pt(kp, "upper_jaw") - _pt(kp, "lower_jaw")))) / head, 3)
    if head and head > 1:
        lifts = [
            (kp[IX[f"{s}_earbase"], 1] - kp[IX[f"{s}_earend"], 1]) / head
            for s in ("left", "right")
            if _ok(kp, f"{s}_earbase") and _ok(kp, f"{s}_earend")
        ]
        if lifts:
            fs.ear_lift = round(float(np.mean(lifts)), 3)
    if fs.L and side_view:
        axis = (_pt(kp, "neck_base") - _pt(kp, "tail_base")) / fs.L
        if _ok(kp, "tail_end"):
            v = (_pt(kp, "tail_end") - _pt(kp, "tail_base")) / fs.L
            # 趴着时尾巴常卷到身前，不算夹尾巴；摇尾也只看站 / 坐（趴着时关键点抖动会像摇尾）
            if posture in ("stand", "sit"):
                fs.tail_tucked = bool(v @ axis > TAIL_TUCK)
                fs.tail_side = round(float(v[0] * -axis[1] + v[1] * axis[0]), 3)
            if posture == "stand":
                fs.tail_high = bool(-v[1] > TAIL_HIGH)
        paws = [IX[p] for p in PAWS if _ok(kp, p)]
        if posture == "stand" and paws and _ok(kp, "back_middle"):
            leg = (float(np.mean(kp[paws, 1])) - float(kp[IX["back_middle"], 1])) / fs.L
            fs.body_low = bool(leg < BODY_LOW)
    return fs


def _intervals(mask: list[bool], times: list[float], min_s: float, max_s: float | None = None, gap: int = 1):
    """连续为 True 的区间（允许 gap 帧空档），只保留时长在 [min_s, max_s] 的。"""
    out, i, n = [], 0, len(mask)
    while i < n:
        if not mask[i]:
            i += 1
            continue
        j, miss = i, 0
        while j + 1 < n and (mask[j + 1] or (miss < gap and any(mask[j + 2:j + 2 + gap]))):
            miss = 0 if mask[j + 1] else miss + 1
            j += 1
        dur = times[j] - times[i]
        if dur >= min_s and (max_s is None or dur <= max_s):
            out.append((round(times[i], 2), round(times[j], 2)))
        i = j + 1
    return out


@dataclass
class BodySummary:
    frames: int
    usable: int                       # 有狗、有关键点的帧
    signals: list[dict] = field(default_factory=list)   # [{id, t_start, t_end}]
    metrics: dict = field(default_factory=dict)          # motion_mean / still_ratio / lying_ratio / panting_ratio ...

    def to_dict(self) -> dict:
        return asdict(self)

    def count(self, sid: str) -> int:
        return sum(1 for s in self.signals if s["id"] == sid)


def summarize(frames: list[FrameSignals]) -> BodySummary:
    frames = [f for f in frames if f is not None]
    usable = [f for f in frames if f.center is not None]
    out = BodySummary(frames=len(frames), usable=len(usable))
    if len(usable) < 2:
        return out
    t = [f.t for f in usable]
    fps = (len(t) - 1) / max(t[-1] - t[0], 1e-6)
    sig: list[dict] = []

    def add(sid, ivs):
        sig.extend({"id": sid, "t_start": a, "t_end": b} for a, b in ivs)

    add("tail_tucked", _intervals([bool(f.tail_tucked) for f in usable], t, 0.5))
    add("tail_high", _intervals([bool(f.tail_high) for f in usable], t, 0.5))
    add("body_low", _intervals([bool(f.body_low) for f in usable], t, 0.5))

    # 耳朵：比这段视频自己的中位数
    lifts = [f.ear_lift for f in usable if f.ear_lift is not None]
    if len(lifts) >= 5:
        med = float(np.median(lifts))
        add("ears_drop", _intervals([f.ear_lift is not None and f.ear_lift < med - EAR_DROP for f in usable], t, 1.5))

    # 张嘴：喘气（持续张着）与打哈欠（短时间张很大）
    mo = [f.mouth_open if f.mouth_open is not None else 0.0 for f in usable]
    win = max(2, round(2 * fps))
    pant = [False] * len(usable)
    for i in range(len(usable)):
        seg = mo[max(0, i - win // 2): i + win // 2 + 1]
        pant[i] = sum(v > PANT_OPEN for v in seg) >= 0.6 * len(seg)
    add("panting", _intervals(pant, t, 2.0))
    add("yawn", _intervals([v > YAWN_OPEN and not p for v, p in zip(mo, pant)], t, 0.4, 3.0))

    # 摇尾：尾尖横向位置来回摆动
    side = [f.tail_side for f in usable]
    wag = [False] * len(usable)
    for i in range(len(usable)):
        seg = [v for v in side[max(0, i - win // 2): i + win // 2 + 1] if v is not None]
        if len(seg) >= 4:
            d = np.diff(seg)
            turns = int(np.sum(np.sign(d[1:]) != np.sign(d[:-1])))
            wag[i] = turns >= 3 and (max(seg) - min(seg)) > WAG_AMP
    add("tail_wag", _intervals(wag, t, 1.0))

    # 动得多 / 僵住：身体中心速度 / L
    Ls = [f.L for f in usable if f.L]
    Lref = float(np.median(Ls)) if Ls else None
    speed = [0.0]
    if Lref:
        for a, b in zip(usable[:-1], usable[1:]):
            dt = max(b.t - a.t, 1e-3)
            speed.append(float(np.hypot(b.center[0] - a.center[0], b.center[1] - a.center[1])) / Lref / dt)
        add("high_motion", _intervals([s > MOTION_HIGH for s in speed], t, 1.0))
        stressed_pose = [bool(f.tail_tucked) or bool(f.body_low) for f in usable]
        add("freeze", _intervals([s < FREEZE_MOTION and p for s, p in zip(speed, stressed_pose)], t, 2.0))
        out.metrics["motion_mean"] = round(float(np.mean(speed[1:])), 3)
        out.metrics["still_ratio"] = round(float(np.mean([s < 0.1 for s in speed[1:]])), 3)
    postures = [f.posture for f in usable if f.posture]
    if postures:
        out.metrics["lying_ratio"] = round(postures.count("down") / len(postures), 3)
    out.metrics["panting_ratio"] = round(float(np.mean(pant)), 3)
    out.metrics["duration"] = round(t[-1] - t[0], 2)
    out.signals = sorted(sig, key=lambda s: s["t_start"])
    return out


def counts(summary: BodySummary) -> dict[str, int]:
    c: dict[str, int] = {}
    for s in summary.signals:
        c[s["id"]] = c.get(s["id"], 0) + 1
    return c
