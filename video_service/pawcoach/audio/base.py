"""口令提取器接口（Protocol）。

stub 与真实现（FunASR/Whisper）都实现它。
见 docs/CodePlan_detail.md 步骤 A4。
"""

from __future__ import annotations

from typing import Protocol

from pawcoach.schema import AudioEvent, MetaInfo
from pawcoach.video.probe import VideoInfo


class AudioExtractor(Protocol):
    def extract(self, video: VideoInfo, meta: MetaInfo) -> list[AudioEvent]: ...
