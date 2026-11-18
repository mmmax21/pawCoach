"""姿态桩实现：阶段 A 只为跑通链路。

返回整段视频一个「坐」，置信度固定 0.5。
阶段 B 由 SuperAnimalPoseExtractor 替换。
"""

from __future__ import annotations

from pawcoach.schema import PoseSegment
from pawcoach.video.probe import VideoInfo


class StubPoseExtractor:
    def extract(self, video: VideoInfo) -> list[PoseSegment]:
        return [PoseSegment(t_start=0.0, t_end=video.duration, label="sit", conf=0.5)]
