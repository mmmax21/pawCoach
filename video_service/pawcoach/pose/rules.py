"""B2：由 SuperAnimal 关键点判坐、站、卧（纯 numpy，不依赖 pandas / deeplabcut）。

输入是每帧的关键点坐标和置信度，输出 PoseSegment 列表。
流程：逐帧规则分类 → 滑动窗口多数投票 → 吸收短于 min_segment_s 的抖动片段 → 合并成区间。

规则：
- 体轴倾角 h = (tail_base_y - neck_base_y) / 体长。坐下时臀部落地、前身直立，体轴接近竖直，h 大；站、趴时体轴接近水平，h 小。
- 狗太小（体长占画面短边比例过小）、可靠关键点太少，输出 unclear。
- 可选：左右关键点的水平间距除以体长（max_width_ratio）超过阈值，当作正面或背面输出 unclear。默认开，设 None 关闭。

阈值来自 dog3.mp4（侧面，逐秒人工标注）和 dog2.mp4（正面为主）两段视频，只有这两段，
不要当作通用值。见 reports/B2.md。
"""

from __future__ import annotations

from dataclasses import dataclass

import numpy as np

from pawcoach.schema import PoseLabel, PoseSegment

# SuperAnimal-Quadruped 的左右对称关键点（用来估计狗是侧面还是正面/背面）
SYMMETRIC_PAIRS = [
    ("left_eye", "right_eye"),
    ("left_earbase", "right_earbase"),
    ("front_left_thai", "front_right_thai"),
    ("back_left_thai", "back_right_thai"),
    ("front_left_paw", "front_right_paw"),
    ("back_left_paw", "back_right_paw"),
]
PAWS = ["front_left_paw", "front_right_paw", "back_left_paw", "back_right_paw"]


@dataclass
class PoseRules:
    min_kp_conf: float = 0.3        # 关键点置信度低于此值视为没检测到
    min_kpts: int = 28              # 一帧里可靠关键点（共 39 个）少于此数 → unclear
    min_body_len_frac: float = 0.08  # 体长 / 画面短边 小于此值 → 狗太小或只露出一角 → unclear
    # 左右间距 / 体长 大于此值 → 当作正面或背面 → unclear；设成 None 关闭这条过滤。
    # 默认开：正面视角下臀部高度看不出来，关掉后 dog2 的准确率虽然从 1/13 升到 9/13，
    # 但时间线碎成 10 段，坐的片段只有 0.7s、1.4s、1.1s（标注里是约 3s 和 5s），保持时长会算错。
    # 算不出（unclear）比算错更安全。见 reports/B2.md。
    max_width_ratio: float | None = 0.4
    sit_min_h: float = 0.55         # 体轴倾角 h 不小于此值 → sit
    down_max_leg: float = 0.6       # h 小于 sit_min_h 时，(爪平均 y - back_middle y) / 体长 小于此值 → down；两段样本视频里都没有趴下，这条规则没有真实视频验证
    window_s: float = 0.5           # 多数投票窗口
    min_segment_s: float = 0.5      # 短于此时长的片段当作抖动并入邻段
    # v3：两段相同姿势之间夹着不超过此时长的"看不清"，当作姿势没变（俯拍时判定会时断时续）。
    # 0 关闭。取 1.5 秒（保守值，没有逐秒标注的视频验证过；更长的空档宁可留着看不清）。
    bridge_s: float = 1.5


@dataclass
class Keypoints:
    names: list[str]
    xy: np.ndarray    # (帧数, 关键点数, 2)，图像坐标，y 向下
    conf: np.ndarray  # (帧数, 关键点数)
    fps: float
    width: int
    height: int

    @property
    def index(self) -> dict[str, int]:
        return {n: i for i, n in enumerate(self.names)}


def classify_frame(
    xy: np.ndarray, conf: np.ndarray, ix: dict[str, int], short_side: float, rules: PoseRules
) -> tuple[PoseLabel, float]:
    """单帧分类，返回 (标签, 置信度)。置信度是用到的关键点置信度的均值。"""
    ok = conf >= rules.min_kp_conf
    if int(ok.sum()) < rules.min_kpts:
        return "unclear", float(conf.mean())

    nb, tb = ix["neck_base"], ix["tail_base"]
    if not (ok[nb] and ok[tb]):
        return "unclear", float(conf.mean())
    body_len = float(np.hypot(*(xy[tb] - xy[nb])))
    if body_len < rules.min_body_len_frac * short_side:
        return "unclear", float(conf[[nb, tb]].mean())

    if rules.max_width_ratio is not None:
        widths = [
            abs(xy[ix[a], 0] - xy[ix[b], 0]) / body_len
            for a, b in SYMMETRIC_PAIRS
            if ok[ix[a]] and ok[ix[b]]
        ]
        if not widths or float(np.median(widths)) > rules.max_width_ratio:
            return "unclear", float(conf[[nb, tb]].mean())

    h = float(xy[tb, 1] - xy[nb, 1]) / body_len
    used = conf[[nb, tb]].mean()
    if h >= rules.sit_min_h:
        return "sit", float(used)

    paws = [ix[p] for p in PAWS if ok[ix[p]]]
    bm = ix["back_middle"]
    if paws and ok[bm]:
        leg = (float(np.mean(xy[paws, 1])) - float(xy[bm, 1])) / body_len
        if leg < rules.down_max_leg:
            return "down", float(used)
    return "stand", float(used)


# v3：多角度姿态分类器（pose/posture_model.py）怎么和规则合用
# - 规则判不了（正面、俯拍、关键点不全 → unclear）时，用分类器的结果（它自己有概率门槛）；
# - 规则判"站"或"趴"、分类器以很高的概率判成另一个时，信分类器：规则的趴下条件没有真实视频验证过，
#   分类器在 4000 多张趴着的照片上训练过；
# - 规则判"坐"的不改：侧面判坐是两段真实视频逐秒标注验证过的。
OVERRIDE_PROB = 0.85


def _hybrid(lab: PoseLabel, c: float, xy, conf, names, posture, rules: PoseRules) -> tuple[PoseLabel, float]:
    """posture：有 predict(kp39) 的关键点模型，或已经算好的 PostureRead。"""
    from pawcoach.pose.posture_model import PostureRead, kp_in_model_order

    if lab == "sit":
        return lab, c
    read = posture if isinstance(posture, PostureRead) else posture.predict(kp_in_model_order(xy, conf, names))
    return merge_read(lab, c, read, conf, rules)


def merge_read(lab: PoseLabel, c: float, read, conf, rules: PoseRules) -> tuple[PoseLabel, float]:
    """规则结果 + 分类器结果 → 最终标签（规则见上）。

    另：规则判"趴"要分类器也判"趴"才算（规则的趴下条件没有真实视频验证过，俯拍时会误判）；
    分类器拿不准时改成 unclear。没有分类器（read is None）时保持 v3 之前的行为。
    """
    if lab == "down" and read is not None and read.label != "down":
        if read.label == "unclear":
            return "unclear", c
    if lab == "sit" or read is None or read.label == "unclear":
        return lab, c
    ok = conf >= rules.min_kp_conf
    kc = float(conf[ok].mean()) if ok.any() else 0.0
    if lab == "unclear":
        return read.label, round(min(read.prob, kc), 3)
    if read.label != lab and read.label in ("stand", "down") and read.prob >= OVERRIDE_PROB:
        return read.label, round(min(read.prob, kc), 3)
    return lab, c


def classify_frames(
    kp: Keypoints, rules: PoseRules, posture=None
) -> tuple[list[PoseLabel], np.ndarray]:
    """posture：pose/posture_model.PostureModel；None 时只用规则（和 v3 之前完全一样）。"""
    ix = kp.index
    short_side = float(min(kp.width, kp.height))
    labels: list[PoseLabel] = []
    confs = np.zeros(len(kp.xy))
    for f in range(len(kp.xy)):
        lab, c = classify_frame(kp.xy[f], kp.conf[f], ix, short_side, rules)
        if posture is not None:
            lab, c = _hybrid(lab, c, kp.xy[f], kp.conf[f], kp.names, posture, rules)
        labels.append(lab)
        confs[f] = c
    return labels, confs


def majority_vote(labels: list[PoseLabel], window: int) -> list[PoseLabel]:
    """滑动窗口多数投票。窗口取奇数；平局时保留当前帧自己的标签。"""
    if window % 2 == 0:
        window += 1
    half = window // 2
    out: list[PoseLabel] = []
    for i, own in enumerate(labels):
        chunk = labels[max(0, i - half): i + half + 1]
        counts: dict[str, int] = {}
        for lab in chunk:
            counts[lab] = counts.get(lab, 0) + 1
        best = max(counts.values())
        out.append(own if counts[own] == best else next(l for l in chunk if counts[l] == best))
    return out


def _runs(labels: list[PoseLabel]) -> list[list]:
    """连续相同标签压成 [标签, 起始帧, 结束帧（不含）]。"""
    runs: list[list] = []
    for i, lab in enumerate(labels):
        if runs and runs[-1][0] == lab:
            runs[-1][2] = i + 1
        else:
            runs.append([lab, i, i + 1])
    return runs


def absorb_short_runs(labels: list[PoseLabel], min_frames: int) -> list[PoseLabel]:
    """把短于 min_frames 的片段并入相邻的较长片段，反复做到没有短片段（或只剩一段）。"""
    labels = list(labels)
    while True:
        runs = _runs(labels)
        short = [r for r in runs if r[2] - r[1] < min_frames]
        if not short or len(runs) == 1:
            return labels
        # 先处理最短的一段，邻居里取更长的那个
        r = min(short, key=lambda r: r[2] - r[1])
        k = runs.index(r)
        neighbours = [runs[j] for j in (k - 1, k + 1) if 0 <= j < len(runs)]
        target = max(neighbours, key=lambda n: n[2] - n[1])
        for i in range(r[1], r[2]):
            labels[i] = target[0]


def bridge_unclear(labels: list[PoseLabel], max_frames: int) -> list[PoseLabel]:
    """夹在两段相同姿势之间、不超过 max_frames 帧的 unclear 填成那个姿势。"""
    if max_frames <= 0:
        return list(labels)
    labels = list(labels)
    runs = _runs(labels)
    for k in range(1, len(runs) - 1):
        lab, a, b = runs[k]
        if lab == "unclear" and b - a <= max_frames and runs[k - 1][0] == runs[k + 1][0] != "unclear":
            for i in range(a, b):
                labels[i] = runs[k - 1][0]
    return labels


def to_segments(labels: list[PoseLabel], confs: np.ndarray, fps: float) -> list[PoseSegment]:
    segs = []
    for lab, a, b in _runs(labels):
        segs.append(
            PoseSegment(
                t_start=round(a / fps, 3),
                t_end=round(b / fps, 3),
                label=lab,
                conf=round(float(np.clip(confs[a:b].mean(), 0.0, 1.0)), 3),
            )
        )
    return segs


def keypoints_to_segments(
    kp: Keypoints,
    rules: PoseRules | None = None,
    in_frame: np.ndarray | None = None,
    posture=None,
    refine=None,
) -> list[PoseSegment]:
    """in_frame：每帧「狗完整在画面里」（B3 检测得出）。为 False 的帧一律 unclear，不管关键点怎么说。
    长度和关键点帧数不一致时，缺的帧按「不在画面」处理，多的丢掉。"""
    rules = rules or PoseRules()
    labels, confs = classify_frames(kp, rules, posture)
    if refine is not None:  # v3：图像分类器逐帧补判（posture_model.refine_with_images）
        labels, confs = refine(labels, confs)
    if in_frame is not None:
        mask = np.zeros(len(labels), dtype=bool)
        k = min(len(labels), len(in_frame))
        mask[:k] = in_frame[:k]
        labels = [lab if mask[i] else "unclear" for i, lab in enumerate(labels)]
    voted = majority_vote(labels, max(1, round(rules.window_s * kp.fps)))
    smooth = absorb_short_runs(voted, max(1, round(rules.min_segment_s * kp.fps)))
    smooth = bridge_unclear(smooth, round(rules.bridge_s * kp.fps))
    return to_segments(smooth, confs, kp.fps)
