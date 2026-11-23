"""v3：上传分析用"出声检测"补口令和奖励（和实时计时同一个 OnsetDetector）。

问题：Whisper 听孤立的中文单字很不稳（"坐"听成"走"），听不到口令时整轮配不上，App 只能提示重拍。
计时只需要时刻，不需要听懂说了什么。所以：
- 先用转写识别出的词（口令 / 标记词 / 释放词 / 纠正词）；
- 再把整段音频过一遍起音检测，离转写事件很近（MATCH_S 内）的起音视为同一次说话，跳过；
- 剩下"没听懂"的起音按狗当时的姿势定角色（和 live/timeline.py 同一个思路）：
  狗还没进入目标姿势、且 CUE_BEFORE_S 秒内就进入了 → 口令；
  狗处在目标姿势里、且这一段还没有任何奖励 / 标记词 → 这一段的第一声当作奖励（标记词）。
  其余的起音不用（宁可漏，不乱配）。

限制：周围有人说话、电视、狗叫都会被当成起音；底噪只能抵消持续的噪声。
"""

from __future__ import annotations

from pathlib import Path

import numpy as np

from pawcoach.live.vad import SAMPLE_RATE, OnsetDetector
from pawcoach.schema import AudioEvent, PoseSegment

ONSET_WORD = "（出声）"   # 没听懂内容的一次说话；App 只用时刻，不展示这个词
MATCH_S = 0.6             # 起音离转写出的词这么近 → 同一次说话
CUE_BEFORE_S = 4.0        # 狗在起音后这么多秒内进入目标姿势 → 这一声是口令
CUE_BEFORE_S_ARRIVE = 6.0  # 召回：狗要跑一段（成功标准"5 秒内跑到面前"），口令窗口放宽
_EPS = 0.1


def detect_onsets(video_path: str | Path) -> list[float]:
    """整段音频的起音时刻（秒）。没有音轨或解码失败返回空。"""
    try:
        from pawcoach.audio.transcribe import _load_audio

        audio = _load_audio(Path(video_path))
    except Exception:  # noqa: BLE001
        return []
    return onsets_from_pcm(np.asarray(audio, dtype=np.float32))


def onsets_from_pcm(pcm: np.ndarray, sr: int = SAMPLE_RATE) -> list[float]:
    if pcm.size == 0:
        return []
    det = OnsetDetector(sr=sr)
    return det.feed(pcm, 0.0)


def fill_with_onsets(
    audio: list[AudioEvent], onsets: list[float], pose: list[PoseSegment], target: str = "sit"
) -> list[AudioEvent]:
    """返回补上起音事件后的事件表（原事件不变，新增事件 source="onset"）。"""
    known = sorted(a.t_start for a in audio)
    segs = sorted((s for s in pose if s.label == target), key=lambda s: s.t_start)
    out = list(audio)

    def near_known(t: float) -> bool:
        return any(abs(t - k) <= MATCH_S for k in known)

    rewarded = {
        i
        for i, s in enumerate(segs)
        for a in audio
        if a.kind == "marker" and s.t_start - _EPS <= a.t_start <= s.t_end + _EPS
    }
    for t in sorted(onsets):
        if near_known(t):
            continue
        inside = next((i for i, s in enumerate(segs) if s.t_start + _EPS < t <= s.t_end + _EPS), None)
        if inside is not None:
            if inside not in rewarded:
                rewarded.add(inside)
                out.append(AudioEvent(word=ONSET_WORD, t_start=t, t_end=t, kind="marker", source="onset"))
            continue
        nxt = next((s for s in segs if s.t_start >= t - _EPS), None)
        window = CUE_BEFORE_S_ARRIVE if target == "arrive" else CUE_BEFORE_S
        if nxt is not None and nxt.t_start - t <= window:
            out.append(AudioEvent(word=ONSET_WORD, t_start=t, t_end=t, kind="cue", source="onset"))
    return sorted(out, key=lambda a: a.t_start)
