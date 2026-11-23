"""一次实时练习的会话：喂入相机帧、麦克风音频、奖励点按，吐出给手机画面的快照。

会话自己不跑模型也不碰网络：帧先交给 PoseEngine 得到标签（由调用方做，见 app/live.py），
这里只负责把标签、声音起音、点按推成轮次，并在结束时产出和离线分析同格式的结果，
App 里现成的 judgeVideo / 结果页可以直接用。

时间基准：全部是"客户端会话时间"（点开始那一刻为 0 秒）。手机在每个消息里带自己的时刻，
服务端不用自己的时钟，所以网络延迟不会让奖励延迟变大。
"""

from __future__ import annotations

from dataclasses import asdict, dataclass, field

import numpy as np

from pawcoach.live.timeline import LiveTrial, build_trials
from pawcoach.live.tracker import StateTracker
from pawcoach.live.vad import OnsetDetector

# 超过这个值，就认为这一轮"奖励太晚"。与 content/video_checks.yaml 的 late_reward.threshold_sec 取同一个数；
# 服务端不读内容库，由手机在 start 消息里传进来，没传才用这个兜底。
DEFAULT_LATE_SEC = 1.0
# 狗坐下后多久还没有奖励，就开始提示"该奖励了"
NUDGE_AFTER_S = 0.8
BODY_WINDOW_S = 30.0   # 实时：最近 30 秒的身体信号（该不该停由手机按内容库规则判断）
BODY_KEEP_S = 60.0


@dataclass
class Snapshot:
    """每次状态变化后发给手机的快照。"""

    t: float                      # 会话时间（秒），最近一次收到的事件时刻
    dog_state: str | None         # sit | stand | None（还没确认）
    dog_box: list[float] | None   # 归一化 x1,y1,x2,y2
    mic_level_db: float
    mic_alive: bool               # 最近是否收到过音频（false 时提示麦克风没声音）
    trials: list[dict]            # 已出现坐下的轮次
    pending_cue_t: float | None   # 已经出声但狗还没坐下（口令已发出，在等狗）
    live_trial: dict | None       # 当前正在计时的一轮
    late_sec: float
    hint: str | None              # 提示代码，不是文字：reward_due / reward_late / cue_repeated / None。
                                  # 文字由手机端按内容库原文显示；服务端不生成任何训练建议。
    body: dict | None = None      # v3 身体信号：最近 BODY_WINDOW_S 秒里各信号出现次数 {counts, window, usable}

    def to_dict(self) -> dict:
        return asdict(self)


def _trial_dict(tr: LiveTrial, late_sec: float, now: float) -> dict:
    delay = tr.reward_delay
    waiting = tr.reward_t is None and tr.sit_end is None   # 还坐着、还没奖励：延迟正在增长
    running = round(now - tr.sit_start, 2) if waiting else None
    return {
        "cue_times": [round(v, 2) for v in tr.cue_times],
        "cue_count": len(tr.cue_times),
        "sit_start": round(tr.sit_start, 2),
        "sit_end": None if tr.sit_end is None else round(tr.sit_end, 2),
        "reward_t": None if tr.reward_t is None else round(tr.reward_t, 2),
        "reward_src": tr.reward_src,
        "reward_delay": delay,
        "latency": tr.latency,
        "waiting_reward": waiting,
        "running_delay": running,
        "late": (delay is not None and delay > late_sec) or (running is not None and running > late_sec),
        "markers_during_hold": tr.markers_during_hold,
    }


class LiveSession:
    def __init__(self, late_sec: float = DEFAULT_LATE_SEC, mic_enabled: bool = True):
        self.body_frames: list = []        # v3 身体信号：FrameSignals，只留最近 BODY_KEEP_S 秒
        self.body_all: list = []           # 整段（结束时汇总进 result）
        self._body_cache: tuple[float, dict] | None = None
        self.late_sec = late_sec
        self.mic_enabled = mic_enabled
        self.tracker = StateTracker()
        self.vad = OnsetDetector()
        self.onsets: list[float] = []
        self.taps: list[float] = []
        self.now = 0.0
        self.dog_box: list[float] | None = None
        self.frames = 0
        self.dog_frames = 0
        self.clear_frames = 0
        self.audio_chunks = 0
        self._last_audio_t = -1e9

    # ----- 输入 -----
    def on_frame(self, t: float, label: str, box: tuple | None) -> None:
        self.now = max(self.now, t)
        self.frames += 1
        if box is not None:
            self.dog_frames += 1
            self.dog_box = [round(float(v), 4) for v in box]
        else:
            self.dog_box = None
        if label != "unclear":
            self.clear_frames += 1
        self.tracker.push(t, label)

    def on_body(self, fs) -> None:
        """一帧的身体信号（pawcoach/body/signals.FrameSignals）。"""
        if fs is None:
            return
        self.body_frames.append(fs)
        self.body_all.append(fs)
        cut = fs.t - BODY_KEEP_S
        while self.body_frames and self.body_frames[0].t < cut:
            self.body_frames.pop(0)

    def body_snapshot(self) -> dict | None:
        if not self.body_frames:
            return None
        if self._body_cache and self.now - self._body_cache[0] < 1.0:  # 最多每秒算一次
            return self._body_cache[1]
        from pawcoach.body.signals import counts, summarize

        recent = [f for f in self.body_frames if f.t >= self.now - BODY_WINDOW_S]
        s = summarize(recent)
        out = {"counts": counts(s), "window": BODY_WINDOW_S, "usable": s.usable}
        self._body_cache = (self.now, out)
        return out

    def on_audio(self, t0: float, pcm: np.ndarray) -> list[float]:
        n = len(pcm)
        end = t0 + n / self.vad.sr
        self.now = max(self.now, end)
        self.audio_chunks += 1
        self._last_audio_t = end
        new = self.vad.feed(pcm, t0)
        self.onsets.extend(new)
        return new

    def on_tap(self, t: float) -> None:
        self.now = max(self.now, t)
        self.taps.append(t)

    # ----- 输出 -----
    def snapshot(self) -> Snapshot:
        trials, pending = build_trials(self.tracker.sit_segments(), self.onsets, self.taps)
        tds = [_trial_dict(t, self.late_sec, self.now) for t in trials]
        live = next((d for d in reversed(tds) if d["waiting_reward"] or d["sit_end"] is None), None)
        # 提示优先级：狗已经坐了还没奖励 > 口令重复。前者正在发生、每一秒都在变糟，后者已成事实。
        # 口令说了几次在轮次卡片上始终可见（cue_count），不会因为让位给"该奖励了"而丢失。
        hint = None
        if live is not None:
            if live["waiting_reward"] and live["running_delay"] is not None:
                if live["running_delay"] >= self.late_sec:
                    hint = "reward_late"
                elif live["running_delay"] >= NUDGE_AFTER_S:
                    hint = "reward_due"
            if hint is None and live["cue_count"] >= 2:
                hint = "cue_repeated"
        return Snapshot(
            t=round(self.now, 2),
            dog_state=self.tracker.state,
            dog_box=self.dog_box,
            mic_level_db=round(self.vad.level_db, 1),
            mic_alive=(self.now - self._last_audio_t) < 2.0 if self.mic_enabled else False,
            trials=tds,
            pending_cue_t=pending[-1] if pending else None,
            live_trial=live,
            late_sec=self.late_sec,
            hint=hint,
            body=self.body_snapshot(),
        )

    def result(self) -> dict:
        """结束时的结果：字段与离线 /results 的 result 对齐，App 现成的 judgeVideo 直接能用。

        可靠性：实时路径没有离线那种整轮置信度，用"这一轮的坐下区间里看得清的帧比例"之外的简化口径——
        轮次有口令、有坐下，且整段里看得清的帧占比达标，就算可靠。口令来自声音起音（不认词），
        所以 cue_source 标为 "onset"。
        """
        trials, pending = build_trials(self.tracker.sit_segments(), self.onsets, self.taps)
        clear_ratio = (self.clear_frames / self.frames) if self.frames else 0.0
        dog_ratio = (self.dog_frames / self.frames) if self.frames else 0.0
        out_trials = []
        for t in trials:
            if t.sit_end is None:
                t_end = self.now           # 结束时还坐着：按结束时刻收尾
            else:
                t_end = t.sit_end
            hold = round(t_end - t.sit_start, 2)
            out_trials.append(
                {
                    "cue_t": t.cue_t,
                    "sit_start": round(t.sit_start, 3),
                    "sit_end": round(t_end, 3),
                    "ended_by": "stand_up" if t.sit_end is not None else "unknown",
                    "reward_t": t.reward_t,
                    "latency": t.latency,
                    "hold": hold,
                    "reward_delay": t.reward_delay,
                    "conf": round(min(1.0, clear_ratio), 3),
                    "cue_times": list(t.cue_times),   # 与离线一致：含第一次口令，App 的 repeated_cue 按个数判
                    "markers_during_hold": t.markers_during_hold,
                    "corrections": [],
                    "reliable": clear_ratio >= 0.4,
                    "cue_source": "onset",
                }
            )
        # 没有口令的坐下：与离线 unpaired 同格式，App 可以让主人补标
        unpaired = [
            {"type": "sit_without_cue", "t_start": round(s.start, 3), "t_end": round(s.end if s.end is not None else self.now, 3)}
            for s in self.tracker.sit_segments()
            if not any(abs(s.start - t.sit_start) < 1e-6 for t in trials)
        ]
        unpaired += [{"type": "cue_without_sit", "word": "", "t": v} for v in pending]
        events_pose = [
            {"t_start": round(s.start, 3), "t_end": round(s.end if s.end is not None else self.now, 3), "label": s.label, "conf": 1.0}
            for s in self.tracker.segs
        ]
        return {
            "video_id": "live",
            "quality": {
                "dog_visible_ratio": round(dog_ratio, 3),
                "audio_ok": self.audio_chunks > 0 and self.vad.voiced_frames > 0,
                "pose_conf_mean": round(clear_ratio, 3),
                "unclear_seconds": round(self.now * (1 - clear_ratio), 2),
                "unclear_ratio": round(1 - clear_ratio, 3),
                "asr": "live_onset",
            },
            "trials": out_trials,
            "summary": {"trials": len(out_trials), "reliable_trials": sum(1 for x in out_trials if x["reliable"])},
            "unpaired": unpaired,
            "coach": "",
            "events": {"pose": events_pose, "audio": [{"word": "", "t_start": v, "t_end": v, "kind": "other"} for v in self.onsets]},
            "taps": list(self.taps),
            "duration": round(self.now, 2),
            "body": self._body_result(),
        }

    def _body_result(self) -> dict | None:
        if not self.body_all:
            return None
        from pawcoach.body.signals import summarize

        out = summarize(self.body_all).to_dict()
        out["kind"] = "live"
        return out
