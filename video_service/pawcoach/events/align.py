"""事件对齐：把姿态 / 口令 / 奖励三条时间线合成「轮次」。

纯规则，不引入模型（docs/CodePlan_detail.md 步骤 A7）。
- 每个 cue（口令）后找最近的 sit 段，组成一轮；
- 计算 latency（反应延迟）/ hold（保持时长）/ reward_delay（奖励延迟）；
- 无法配对的 cue / sit / reward 塞进 unpaired，作为反馈素材。

正确切分（多轮、跨轮奖励归因、过渡态）是阶段 C 的迭代项，本模块只保证跑通。

M5 改动（只增字段，原有字段算法不变）：
- 同一次坐下之前的重复口令并入同一轮（记入 cue_times），不再各自去配后面的坐姿段；
  上一轮坐姿保持期间的口令不再另起一轮。
- 口令落在一段尚未配对、正在进行的坐姿里（等待类技能：狗先坐好，主人再说「等」）时与这段配对，
  这种轮次 latency 为 None（狗本来就坐着，没有反应快慢可言）。
- 新增 cue_times / markers_during_hold / corrections 三个测量字段。
"""

from __future__ import annotations

from pawcoach.schema import (
    AudioEvent,
    MetaInfo,
    PoseSegment,
    RewardEvent,
    Trial,
)

# 配对允许的时间容差（秒）
_EPS = 0.1

# 置信度门控阈值：trial 整体置信度低于此值 → 不进 summary 指标。
# 照 dog3 实测（trial conf ≈ 0.48～0.55、pose_conf_mean 0.46）取 0.4，未做通用验证，见 reports/C1.md。
CONF_GATE = 0.4


def align(
    pose: list[PoseSegment],
    audio: list[AudioEvent],
    rewards: list[RewardEvent],
    meta: MetaInfo,
) -> tuple[list[Trial], list[dict]]:
    cues = sorted((a for a in audio if a.kind == "cue"), key=lambda a: a.t_start)
    markers = sorted((a for a in audio if a.kind == "marker"), key=lambda a: a.t_start)
    releases = sorted((a for a in audio if a.kind == "release"), key=lambda a: a.t_start)
    sits = sorted((s for s in pose if s.label == "sit"), key=lambda s: s.t_start)
    rewards_sorted = sorted(rewards, key=lambda r: r.t)
    corrections = sorted((a for a in audio if a.kind == "correction"), key=lambda a: a.t_start)

    trials: list[Trial] = []
    trial_segs: list[PoseSegment] = []
    unpaired: list[dict] = []
    used_sit: set[int] = set()

    for cue in cues:
        # M5：上一轮的坐姿还没结束 → 这个口令属于上一轮（坐下前的重复口令，或保持中的口令）
        if trials and cue.t_start <= trial_segs[-1].t_end + _EPS:
            last, last_seg = trials[-1], trial_segs[-1]
            if cue.t_start < last_seg.t_start - _EPS:
                last.cue_times.append(cue.t_start)
            continue

        # M5：口令落在一段未配对、正在进行的坐姿里（狗已坐好再说「等」）→ 配这一段
        sit_idx = next(
            (
                i
                for i, seg in enumerate(sits)
                if i not in used_sit and seg.t_start - _EPS < cue.t_start <= seg.t_end
                and cue.t_start > seg.t_start + _EPS
            ),
            None,
        )
        cue_during_sit = sit_idx is not None
        if sit_idx is None:
            # 找 cue 之后最近的 sit 段
            sit_idx = next(
                (i for i, seg in enumerate(sits) if i not in used_sit and seg.t_start >= cue.t_start - _EPS),
                None,
            )
        if sit_idx is None:
            unpaired.append({"type": "cue_without_sit", "word": cue.word, "t": cue.t_start})
            continue

        seg = sits[sit_idx]
        used_sit.add(sit_idx)

        trial = Trial(
            cue_t=cue.t_start,
            sit_start=seg.t_start,
            sit_end=seg.t_end,
            conf=seg.conf,
            cue_times=[] if cue_during_sit else [cue.t_start],
        )

        # 结束原因：本段内有释放词 → release；否则其后紧邻 stand → stand_up；否则 unknown
        release = next(
            (r for r in releases if seg.t_start - _EPS <= r.t_start <= seg.t_end + _EPS),
            None,
        )
        if release is not None:
            trial.ended_by = "release"
        else:
            stand_after = next(
                (s for s in pose if s.label == "stand" and s.t_start >= seg.t_end - _EPS),
                None,
            )
            trial.ended_by = "stand_up" if stand_after is not None else "unknown"

        # 奖励：狗达成坐之后最近的奖励时刻
        reward = next((r for r in rewards_sorted if r.t >= seg.t_start - _EPS), None)
        # 标记词：本轮窗口内（坐达成到保持结束）
        marker = next(
            (m for m in markers if seg.t_start - _EPS <= m.t_start <= seg.t_end + _EPS),
            None,
        )

        if reward is not None:
            trial.reward_t = reward.t
        if trial.cue_t is not None and trial.sit_start is not None and not cue_during_sit:
            trial.latency = round(trial.sit_start - trial.cue_t, 2)
        if trial.sit_start is not None and trial.sit_end is not None:
            trial.hold = round(trial.sit_end - trial.sit_start, 2)
        if trial.reward_t is not None:
            anchor = marker.t_start if marker is not None else trial.sit_start
            if anchor is not None:
                trial.reward_delay = round(trial.reward_t - anchor, 2)

        # M5：坐下到起身之间的标记词次数
        trial.markers_during_hold = sum(
            1 for m in markers if seg.t_start - _EPS <= m.t_start <= seg.t_end + _EPS
        )

        trials.append(trial)
        trial_segs.append(seg)

    # M5：纠正词按轮次窗口归属：[本轮开始, 下一轮开始)，第一轮之前的记入 unpaired
    starts = [min([t.cue_t, t.sit_start] + t.cue_times) for t in trials]
    order = sorted(range(len(trials)), key=lambda i: starts[i])
    for c in corrections:
        owner = None
        for k, i in enumerate(order):
            nxt = starts[order[k + 1]] if k + 1 < len(order) else float("inf")
            if starts[i] - _EPS <= c.t_start < nxt:
                owner = trials[i]
                break
        if owner is None:
            unpaired.append({"type": "correction_outside_trial", "word": c.word, "t": c.t_start})
        else:
            owner.corrections.append({"word": c.word, "t": c.t_start})

    # 未配对的 sit 段
    for i, seg in enumerate(sits):
        if i not in used_sit:
            unpaired.append({"type": "sit_without_cue", "t_start": seg.t_start, "t_end": seg.t_end})

    return trials, unpaired


def unclear_seconds(pose: list[PoseSegment]) -> float:
    """pose 里 label=="unclear" 的片段总时长（狗出画 / 低置信 / 正面视角，见 B2/B3）。

    这些片段不参与 trial 配对，也不进 summary 指标，只作为「本段有多少秒无法可靠判断」报告给 coach。
    """
    return round(sum(s.t_end - s.t_start for s in pose if s.label == "unclear"), 3)


def gate_trials(
    trials: list[Trial], conf_gate: float = CONF_GATE
) -> tuple[list[Trial], list[Trial]]:
    """置信度门控：把 trial 分成可靠（conf >= 阈值）与不可靠（conf < 阈值）两组。

    可靠组进 summary 指标（success_rate / median_hold），不可靠组只在计数里体现、不进指标。
    """
    reliable = [t for t in trials if t.conf >= conf_gate]
    unreliable = [t for t in trials if t.conf < conf_gate]
    return reliable, unreliable
