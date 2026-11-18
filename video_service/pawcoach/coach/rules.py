"""C2：进度规则层 —— 确定性、可测试、纯 Python。

输入：本次指标（AnalysisResult）+ 历史趋势（list[AnalysisResult]）+ 当前目标保持时长。
输出：ProgressPlan —— 下一次训练的建议（目标时长、动作、本次重点、频率/时长）。

规则（docs/CodePlan_detail.md 步骤 C2）：
1. 最近 2 次成功率 ≥ 80% → 目标时长 +25%（原文「20～30%」取中值 25%）；
2. 本次成功率 < 50% → 回退一档（目标时长 -20%，即 ÷1.25 的对称步长）；
3. reward_delay > 1.0s 占比 > 30% → 本次重点改「标记时机」，且时长不加（即使达标也不升档）；
4. 频率/时长：每次 3～5 分钟、5～10 轮，每周 1～2 次（Demant 2011：每周 1～2 次优于每日）。

「回退上一档」实现成「回退一个 +25% 步长」：若档位按 +25% 等比递增，
上一档 = 当前 ÷ 1.25 = 当前 × 0.8。不引入原文没有的离散档位表，见 reports/C2.md。
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Literal

from pawcoach.schema import AnalysisResult

# 规则阈值（照 CodePlan_detail.md C2，未做通用验证）
SUCCESS_UP = 0.8               # 最近 2 次成功率都 ≥ 此值 → 升档
SUCCESS_DOWN = 0.5             # 本次成功率 < 此值 → 回退
UP_RATIO = 1.25                # 升档放大倍数（20～30% 取中值 25%）
DOWN_RATIO = 1.0 / UP_RATIO    # 回退缩小倍数（-20%，对称步长）
REWARD_DELAY_BAD = 1.0         # reward_delay 超过此值（秒）算「奖励给晚了」
REWARD_DELAY_BAD_RATIO = 0.3   # 晚奖励占比超过此值 → 本次重点改标记时机

# 训练频率/时长（Demant 2011：每周 1～2 次优于每日）
SESSION_RECOMMENDATION = "每次 3～5 分钟、5～10 轮，每周 1～2 次（不要每天练）。"

Action = Literal["increase", "decrease", "hold"]


@dataclass
class ProgressPlan:
    """规则层输出的下一次训练计划。"""

    target_hold: float          # 下一次目标保持时长（秒）
    action: Action              # 升档 / 回退 / 保持
    focus: str                  # 本次训练重点；"" 表示无特别重点
    session: str = SESSION_RECOMMENDATION


def bad_reward_delay_ratio(current: AnalysisResult) -> float:
    """本次 reward_delay > REWARD_DELAY_BAD 的轮次占「有奖励轮次」的比例。

    没有奖励的轮次（reward_delay 为 None）不参与，分母是有 reward_delay 的轮次数。
    """
    delays = [t.reward_delay for t in current.trials if t.reward_delay is not None]
    if not delays:
        return 0.0
    return sum(1 for d in delays if d > REWARD_DELAY_BAD) / len(delays)


def recent_success_rates(
    current: AnalysisResult, history: list[AnalysisResult], n: int = 2
) -> list[float]:
    """最近 n 次（含本次）的成功率，按时间升序，剔除 None。不足 n 次就返回能拿到的。"""
    past = [r.summary.success_rate for r in history[-(n - 1):]]
    rates = past + [current.summary.success_rate]
    return [r for r in rates if r is not None]


def plan_progress(
    current: AnalysisResult,
    history: list[AnalysisResult],
    target_hold: float,
) -> ProgressPlan:
    """按规则层输出下一次训练计划。"""
    rate = current.summary.success_rate

    # 规则 3：晚奖励占比高 → 本次重点改标记时机
    focus = "标记时机" if bad_reward_delay_ratio(current) > REWARD_DELAY_BAD_RATIO else ""

    # 决定动作：回退优先（成功率低是硬信号），其次升档，否则保持
    action: Action = "hold"
    if rate is not None and rate < SUCCESS_DOWN:
        action = "decrease"
    else:
        rates = recent_success_rates(current, history, n=2)
        if len(rates) >= 2 and all(r >= SUCCESS_UP for r in rates):
            action = "increase"

    # 规则 3：晚奖励占比高 → 即使满足升档条件也不加时长（只拦升档，不拦回退）
    if focus == "标记时机" and action == "increase":
        action = "hold"

    # 应用动作到目标时长
    if action == "increase":
        new_hold = round(target_hold * UP_RATIO, 1)
    elif action == "decrease":
        new_hold = round(target_hold * DOWN_RATIO, 1)
    else:
        new_hold = target_hold

    return ProgressPlan(target_hold=new_hold, action=action, focus=focus)


def effective_target_hold(result: AnalysisResult) -> float:
    """当前目标保持时长：优先 meta 的 target_hold，回退本次 median_hold，再回退默认 10s。

    规则层（plan_progress）需要「当前目标」作起点；meta 没填（target_hold=None）时，
    用本次实际中位保持时长对齐，两者都没有时用 10s（Sit-Stay 常见起点）。
    """
    if result.target_hold is not None:
        return result.target_hold
    if result.summary.median_hold is not None:
        return result.summary.median_hold
    return 10.0


def sop_query_terms(plan: ProgressPlan) -> list[str]:
    """从规则层计划构造 SOP 检索词（供 coach 检索 prompts/sop.md）。"""
    terms = ["保持"]
    if plan.focus == "标记时机":
        terms += ["奖励", "标记", "零食", "晚"]
    if plan.action == "increase":
        terms += ["延长", "干扰", "进阶"]
    elif plan.action == "decrease":
        terms += ["入门", "3 秒", "基础"]
    return terms
