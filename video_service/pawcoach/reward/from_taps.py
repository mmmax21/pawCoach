"""奖励打点提取：读 meta.reward_taps，转成 RewardEvent(source='tap')。

这是真实的奖励来源（用户录视频时手动打点），从一开始就不是 stub。
见 docs/CodePlan_detail.md 步骤 A6。
"""

from __future__ import annotations

from pawcoach.schema import AudioEvent, MetaInfo, RewardEvent


class TapRewardExtractor:
    def extract(self, meta: MetaInfo, audio: list[AudioEvent]) -> list[RewardEvent]:
        return [RewardEvent(t=t, source="tap") for t in meta.reward_taps]
