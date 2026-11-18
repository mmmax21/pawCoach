"""口令桩实现：阶段 A 只为跑通链路。

硬编码一个 cue + marker + release，时间点按视频时长相对放置，
便于观察下游 align 是否产出完整一轮。
阶段 B 由 AsrAudioExtractor（FunASR/Whisper）替换。
"""

from __future__ import annotations

from pawcoach.schema import AudioEvent, MetaInfo
from pawcoach.video.probe import VideoInfo


class StubAudioExtractor:
    def extract(self, video: VideoInfo, meta: MetaInfo) -> list[AudioEvent]:
        d = video.duration
        if d <= 1.5:
            return []
        return [
            AudioEvent(word="坐", t_start=0.0, t_end=0.3, kind="cue"),
            AudioEvent(word="好", t_start=d - 1.0, t_end=d - 0.8, kind="marker"),
            AudioEvent(word="可以了", t_start=d - 0.5, t_end=d - 0.3, kind="release"),
        ]
