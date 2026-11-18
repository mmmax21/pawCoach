"""B8：MergedRewardExtractor —— 合并三种奖励来源，优先级 tap > marker > visual。

默认读 meta.reward_taps（用户手动打点，最可信）；
没有打点覆盖的轮次，用最近的 marker 事件时刻兜底（source="marker"）；
visual（MediaPipe Hands 判「手伸向狗头」）是可选增强，本版不做——失败不影响任何东西。

见 docs/CodePlan_detail.md 步骤 B8。

注意：RewardExtractor 协议只拿到 meta + audio（没有 pose/trial），
所以「某轮没打点」在这里用「marker 附近窗口内有没有 tap」来近似——
marker 与 tap 都落在「奖励发生的瞬间」附近，距离超过窗口即认为该轮未打点。
"""

from __future__ import annotations

from pawcoach.schema import AudioEvent, MetaInfo, RewardEvent

# marker 兜底窗口（秒）：一个 marker 前后这么近的范围内有 tap，就认为该轮已由打点覆盖，
# 不再用 marker 兜底。奖励延迟目标 < 1s（见 docs/datasets-and-papers.md），取 2s 足够宽松。
_MARKER_FALLBACK_WINDOW = 2.0


class MergedRewardExtractor:
    """合并 tap / marker / visual 三种奖励来源，tap 优先。

    - tap：直接读 meta.reward_taps，每个转成 RewardEvent(source="tap")。
    - marker：对每个 marker 事件，若它附近没有 tap（窗口外），说明该轮用户没打点，
      用 marker 时刻兜底一个 RewardEvent(source="marker")。
    - visual：本版未实现（可选增强）。
    """

    def extract(self, meta: MetaInfo, audio: list[AudioEvent]) -> list[RewardEvent]:
        # 1) tap 最高优先
        tap_rewards = [RewardEvent(t=t, source="tap") for t in meta.reward_taps]
        rewards = list(tap_rewards)

        # 2) marker 兜底：没被 tap 覆盖的 marker 事件，补一个 reward
        #    「覆盖」只按 tap 判断——之前追加的 marker reward 不代表该轮被打点，
        #    否则相邻两个 marker 会互相「覆盖」，漏掉第二个兜底。
        markers = sorted((a for a in audio if a.kind == "marker"), key=lambda a: a.t_start)
        for m in markers:
            covered = any(abs(r.t - m.t_start) <= _MARKER_FALLBACK_WINDOW for r in tap_rewards)
            if not covered:
                rewards.append(RewardEvent(t=m.t_start, source="marker"))

        # 3) visual：可选增强，本版不做

        return sorted(rewards, key=lambda r: r.t)
