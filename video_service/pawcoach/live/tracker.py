"""姿态防抖：逐帧标签 → 稳定的 坐 / 站 区间（只用已到达的帧，不看未来）。

离线路径用 0.5 秒窗口多数投票再合并短片段（pose/rules.py）。实时路径不能等未来的帧，
改成"滞回"：最近 confirm_s 秒里所有看得清的帧都是同一个标签，才确认状态切换；
确认之后把切换时刻倒推回这一连串同标签帧里最早的那一帧，所以 sit_start 是狗真正坐下的时刻，
不是确认的时刻（确认要晚 confirm_s）。

看不清（unclear）的帧不参与投票，也不打断当前状态。但状态不能靠"看不清"无限续命：
距离上一次真正看到当前状态的帧超过 unclear_timeout_s，就在那一帧收尾。这里要看的是"上一次看到当前状态"，
不是"上一次看清任何东西"：狗出画时画面边缘常有一两帧误判成站或坐，不该让这些杂帧刷新计时。
"""

from __future__ import annotations

from dataclasses import dataclass


@dataclass
class Seg:
    label: str                 # "sit" | "stand"（卧也算 stand：对"坐"来说都是没坐）
    start: float
    end: float | None = None   # None = 还在持续


class StateTracker:
    def __init__(self, confirm_s: float = 0.6, min_frames: int = 2, unclear_timeout_s: float = 2.0):
        self.confirm_s = confirm_s
        self.min_frames = min_frames
        self.unclear_timeout_s = unclear_timeout_s
        self._hist: list[tuple[float, str]] = []
        self.segs: list[Seg] = []
        self._last_state_t: float | None = None   # 最近一次看到"当前状态对应的标签"的时刻

    @property
    def state(self) -> str | None:
        return self.segs[-1].label if self.segs and self.segs[-1].end is None else None

    def push(self, t: float, label: str) -> bool:
        """喂一帧。返回这一帧是否引起了状态切换。"""
        label = "stand" if label == "down" else label
        self._hist.append((t, label))
        # 只留最近 10 秒，足够倒推切换时刻
        cut = t - 10.0
        while self._hist and self._hist[0][0] < cut:
            self._hist.pop(0)

        # 超时收尾：当前状态太久没再被看到（狗出画、被遮挡、或一直是杂帧）
        if (
            self.state is not None
            and self._last_state_t is not None
            and t - self._last_state_t > self.unclear_timeout_s
        ):
            self.segs[-1].end = self._last_state_t
            self._last_state_t = None
            ended = True
        else:
            ended = False

        if label == "unclear":
            return ended
        if self.state is not None and label == self.state:
            self._last_state_t = t

        recent = [l for tt, l in self._hist if tt >= t - self.confirm_s and l != "unclear"]
        if len(recent) < self.min_frames or any(l != label for l in recent):
            return ended
        if self.state == label:
            return ended

        # 倒推：这一串同标签帧里最早的一帧。看不清的帧可以穿过，但只能穿过一小段（不超过 unclear_timeout_s），
        # 而且不能越过上一段的结束时刻：否则两次坐下之间隔着一段"看不清"的站姿时，第二次会被倒推并进第一次。
        start = t
        gap_from: float | None = None
        for tt, l in reversed(self._hist):
            if l == label:
                start = tt
                gap_from = None
            elif l == "unclear":
                if gap_from is None:
                    gap_from = tt
                if gap_from - tt > self.unclear_timeout_s:
                    break
            else:
                break
        if self.segs and self.segs[-1].end is not None:
            start = max(start, self.segs[-1].end)
        if self.segs and self.segs[-1].end is None:
            self.segs[-1].end = start
        self.segs.append(Seg(label, start))
        self._last_state_t = t
        return True

    def sit_segments(self) -> list[Seg]:
        return [s for s in self.segs if s.label == "sit"]
