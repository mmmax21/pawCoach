"""姿态提取器接口（Protocol）。

stub 与真实现（SuperAnimal/mmpose）都实现它，换实现时不改编排代码。
见 docs/CodePlan_detail.md 步骤 A4。
"""

from __future__ import annotations

from typing import Protocol

from pawcoach.schema import PoseSegment
from pawcoach.video.probe import VideoInfo


class PoseExtractor(Protocol):
    def extract(self, video: VideoInfo) -> list[PoseSegment]: ...
