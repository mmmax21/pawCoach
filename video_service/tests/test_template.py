"""TemplateCoach（C3 升级）的单元测试：输出引用时间点 + 规则层建议。"""

from pawcoach.coach.template import TemplateCoach
from pawcoach.schema import AnalysisResult, Summary, Trial


def _result(trials, target_hold=None):
    return AnalysisResult(
        trials=trials,
        summary=Summary(
            trials=len(trials),
            reliable_trials=len(trials),
            success_rate=1.0,
            median_hold=6.5,
        ),
        target_hold=target_hold,
    )


def test_template_quotes_timepoints_and_rules():
    trials = [
        Trial(cue_t=2.0, sit_start=3.0, sit_end=9.0, reward_t=9.2, latency=1.0, hold=6.0, reward_delay=0.7, conf=0.9),
        Trial(cue_t=12.0, sit_start=13.0, sit_end=20.0, reward_t=22.0, latency=1.0, hold=7.0, reward_delay=9.0, conf=0.9),
    ]
    text = TemplateCoach().plan(_result(trials, target_hold=10.0), [])

    assert "口令在 2.0s" in text      # 引用时间点（反应最快那轮）
    assert "第 2 轮" in text          # 最需改的轮次
    assert "22.0s" in text            # 引用奖励时间点
    assert "目标保持" in text         # 规则层输出


def test_template_no_reward_delay_skips_worst_point():
    # 没有晚奖励（reward_delay 都 ≤ 1.0）→ 不输出「最需改」那行
    trials = [
        Trial(cue_t=2.0, sit_start=3.0, sit_end=9.0, reward_t=3.5, latency=1.0, hold=6.0, reward_delay=0.5, conf=0.9),
    ]
    text = TemplateCoach().plan(_result(trials), [])
    assert "⚠️" not in text
    assert "✅" in text
