"""把"狗什么时候坐、什么时候出声、什么时候点了奖励"推成轮次。

纯函数，无状态：每次拿到全部事件重算一遍。这样事件到达的先后顺序（点按比"坐下"确认早到、
声音比姿态确认早到）不影响结果，也不需要为乱序写补丁。

声音只有时刻没有内容，角色靠"当时狗在做什么"判定：
- 狗坐下之前出的声 → 口令（同一次坐下前出现几次，就是几次口令，口令重复就是这么数的）
- 狗坐下之后第一次出声 → 奖励（"好" / 响片）；之后的出声算保持期间的标记词 / 释放词
- 狗刚起身后很短时间内出声，且这一轮还没奖励 → 迟到的奖励，不算下一轮的口令
- 点了 App 上的"奖励"按钮 → 奖励，优先于声音（不依赖麦克风）

与离线 align() 对应的字段名保持一致，结果能直接交给 App 里现成的 judgeVideo。
"""

from __future__ import annotations

from dataclasses import dataclass, field

from pawcoach.live.tracker import Seg

# 出声比 sit_start 早多少以内，仍算奖励而不是口令。
# 姿态是 5 帧每秒，sit_start 有 ±0.1 秒的取整误差；容差只用来吸收它。
# 不能放大：坐下后立刻给的奖励（响片在屁股碰地的瞬间，这是正确做法）若被当成口令，
# 做对的人会被显示成"口令说了两次、奖励晚了"。
REWARD_TOL_S = 0.1
# 起身后多久内的第一声，在这一轮没奖励的前提下，算迟到的奖励
LATE_REWARD_GRACE_S = 2.0


@dataclass
class LiveTrial:
    cue_times: list[float] = field(default_factory=list)
    sit_start: float = 0.0
    sit_end: float | None = None        # None = 还坐着
    reward_t: float | None = None
    reward_src: str | None = None       # tap | voice | voice_late
    markers_during_hold: int = 0

    @property
    def cue_t(self) -> float | None:
        return self.cue_times[0] if self.cue_times else None

    @property
    def latency(self) -> float | None:
        return None if self.cue_t is None else round(self.sit_start - self.cue_t, 2)

    @property
    def reward_delay(self) -> float | None:
        return None if self.reward_t is None else round(self.reward_t - self.sit_start, 2)


def build_trials(
    sits: list[Seg],
    onsets: list[float],
    taps: list[float],
) -> tuple[list[LiveTrial], list[float]]:
    """返回 (已出现坐下的轮次, 还没等到狗坐下的口令时刻)。没有口令的坐下不成轮次（离线叫 sit_without_cue）。"""
    onsets = sorted(onsets)
    taps = sorted(taps)
    used_v: set[int] = set()
    used_tap: set[int] = set()
    trials: list[LiveTrial] = []
    prev_end = float("-inf")

    for seg in sorted(sits, key=lambda s: s.start):
        s, e = seg.start, seg.end
        # 口令：上一次起身之后、本次坐下之前的出声
        cues = [
            (i, v) for i, v in enumerate(onsets)
            if i not in used_v and prev_end < v < s - REWARD_TOL_S
        ]
        # 上一轮的迟到奖励已经在上一轮的循环里先占走，这里不会再算成口令
        if not cues:
            # 没有口令的坐下不成轮次，但它占着的这段时间已经过去了：
            # 里面的出声（奖励、保持中的声音）不能被留给下一轮当口令。
            prev_end = e if e is not None else float("inf")
            continue
        for i, _ in cues:
            used_v.add(i)
        tr = LiveTrial(cue_times=[v for _, v in cues], sit_start=s, sit_end=e)

        hi = e if e is not None else float("inf")
        in_sit = [(i, v) for i, v in enumerate(onsets) if i not in used_v and s - REWARD_TOL_S <= v <= hi + 0.3]
        # 点按优先：落在 [坐下前 0.2 秒, 起身后 2 秒] 内的第一次
        tap_i = next(
            (i for i, tt in enumerate(taps) if i not in used_tap and s - 0.2 <= tt <= hi + LATE_REWARD_GRACE_S),
            None,
        )
        if tap_i is not None:
            tr.reward_t, tr.reward_src = taps[tap_i], "tap"
            used_tap.add(tap_i)
        elif in_sit:
            tr.reward_t, tr.reward_src = in_sit[0][1], "voice"
        tr.markers_during_hold = len(in_sit)
        for i, _ in in_sit:
            used_v.add(i)

        # 迟到的奖励：起身后马上的第一声，且本轮还没奖励
        if tr.reward_t is None and e is not None:
            late = next(
                ((i, v) for i, v in enumerate(onsets) if i not in used_v and e < v <= e + LATE_REWARD_GRACE_S),
                None,
            )
            if late is not None:
                tr.reward_t, tr.reward_src = late[1], "voice_late"
                used_v.add(late[0])

        trials.append(tr)
        prev_end = e if e is not None else float("inf")

    pending = [v for i, v in enumerate(onsets) if i not in used_v and v > prev_end]
    return trials, pending
