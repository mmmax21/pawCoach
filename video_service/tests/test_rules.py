"""rules.py 进度规则层的单元测试：升档 / 回退 / 保持 / 晚奖励 / 边界。"""

from pawcoach.coach.rules import (
    bad_reward_delay_ratio,
    plan_progress,
    recent_success_rates,
)
from pawcoach.schema import AnalysisResult, Summary, Trial


def _result(success_rate, reward_delays=()):
    trials = [Trial(reward_t=1.0, reward_delay=d) for d in reward_delays]
    return AnalysisResult(
        summary=Summary(trials=len(trials), success_rate=success_rate),
        trials=trials,
    )


def test_increase_when_two_recent_high():
    cur = _result(0.85)
    past = _result(0.9)
    plan = plan_progress(cur, [past], target_hold=10.0)
    assert plan.action == "increase"
    assert plan.target_hold == 12.5  # 10 × 1.25


def test_hold_when_not_enough_history():
    # 第一次训练（无历史），即使成功率高也不升档（数据不足）
    plan = plan_progress(_result(0.9), [], target_hold=10.0)
    assert plan.action == "hold"
    assert plan.target_hold == 10.0


def test_hold_when_second_recent_low():
    # 最近 2 次里有一次 < 80% → 不升档
    cur = _result(0.9)
    past = _result(0.7)
    plan = plan_progress(cur, [past], target_hold=10.0)
    assert plan.action == "hold"


def test_decrease_when_low_success():
    plan = plan_progress(_result(0.3), [], target_hold=10.0)
    assert plan.action == "decrease"
    assert plan.target_hold == 8.0  # 10 × 0.8


def test_hold_when_mid_success():
    plan = plan_progress(_result(0.6), [_result(0.6)], target_hold=10.0)
    assert plan.action == "hold"
    assert plan.target_hold == 10.0


def test_focus_marker_timing_blocks_increase():
    # 3 轮里 1 轮晚奖励（1.5s）→ 占比 1/3 > 30%；即使达标也不升档
    cur = _result(0.9, reward_delays=[0.5, 1.5, 0.6])
    plan = plan_progress(cur, [_result(0.9)], target_hold=10.0)
    assert plan.focus == "标记时机"
    assert plan.action == "hold"
    assert plan.target_hold == 10.0


def test_focus_marker_timing_does_not_block_decrease():
    # 晚奖励占比高 + 成功率低 → 仍回退（规则 3 只拦升档，不拦回退）
    cur = _result(0.3, reward_delays=[0.5, 1.5, 0.6])
    plan = plan_progress(cur, [], target_hold=10.0)
    assert plan.focus == "标记时机"
    assert plan.action == "decrease"
    assert plan.target_hold == 8.0


def test_bad_reward_delay_ratio():
    # 恰好 30% 不触发（规则是 > 30%）
    delays_30 = [1.5] * 3 + [0.5] * 7  # 3/10 = 0.3
    assert bad_reward_delay_ratio(_result(0.9, delays_30)) == 0.3
    delays_40 = [1.5] * 4 + [0.5] * 6  # 4/10 = 0.4
    assert bad_reward_delay_ratio(_result(0.9, delays_40)) == 0.4


def test_bad_reward_delay_ratio_no_rewards():
    # 没有奖励的轮次 → 占比 0
    assert bad_reward_delay_ratio(_result(0.9, reward_delays=[])) == 0.0


def test_reward_delay_exactly_1s_not_bad():
    # reward_delay 恰好 1.0 不算晚（规则是 > 1.0）
    delays = [1.0, 1.0, 0.5]
    assert bad_reward_delay_ratio(_result(0.9, delays)) == 0.0


def test_recent_success_rates_drops_none():
    cur = _result(0.9)
    no_rate = AnalysisResult(summary=Summary(success_rate=None))
    assert recent_success_rates(cur, [no_rate], n=2) == [0.9]
