"""奖励提取器接口（Protocol）。

stub 与真实现（打点 / 标记词 / 视觉）都实现它。
见 docs/CodePlan_detail.md 步骤 A4。
"""

from __future__ import annotations

from typing import Protocol

from pawcoach.schema import AudioEvent, MetaInfo, RewardEvent


class RewardExtractor(Protocol):
    def extract(self, meta: MetaInfo, audio: list[AudioEvent]) -> list[RewardEvent]: ...
