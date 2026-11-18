"""模板教练：确定性的建议文本，保证跑通、无外部依赖。

C3 升级：消费规则层（ProgressPlan），输出引用视频时间点的三点建议。
LLMCoach 无 key / 超时时兜底到这里。
"""

from __future__ import annotations

from pawcoach.coach.rules import effective_target_hold, plan_progress
from pawcoach.schema import AnalysisResult


class TemplateCoach:
    def plan(self, result: AnalysisResult, history: list[AnalysisResult]) -> str:
        s = result.summary
        trials = result.trials
        lines = ["【PawCoach 教练建议（模板版）】"]
        lines.append(f"本次识别到 {s.trials} 轮训练。")

        # 做得好的一点：反应最快的轮次（引用时间点）
        with_latency = [t for t in trials if t.latency is not None]
        if with_latency:
            best = min(
                with_latency,
                key=lambda t: t.latency if t.latency is not None else float("inf"),
            )
            idx = trials.index(best) + 1
            lines.append(
                f"✅ 做得好的：第 {idx} 轮（口令在 {best.cue_t:.1f}s）"
                f"{best.latency:.2f} 秒就坐下，反应快。"
            )

        # 最需改的一点：奖励给晚的轮次（引用时间点）
        with_delay = [t for t in trials if t.reward_delay is not None]
        if with_delay:
            worst = max(
                with_delay,
                key=lambda t: t.reward_delay if t.reward_delay is not None else float("-inf"),
            )
            if worst.reward_delay is not None and worst.reward_delay > 1.0:
                idx = trials.index(worst) + 1
                lines.append(
                    f"⚠️ 最需改：第 {idx} 轮奖励给晚了 {worst.reward_delay:.1f} 秒"
                    f"（{worst.reward_t:.1f}s 才递零食），狗会把「起身」和奖励联系起来，"
                    "下次坐下后 1 秒内标记。"
                )

        # 下次怎么练：规则层（升档/回退/保持 + 重点 + 频率）
        plan = plan_progress(result, history, target_hold=effective_target_hold(result))
        lines.append(f"📋 下次目标保持 {plan.target_hold:.1f} 秒。{plan.session}")
        if plan.focus:
            lines.append(f"   本次重点：{plan.focus}")

        # unclear 说明（C1）
        if result.quality.unclear_seconds > 0:
            lines.append(
                f"（本段有 {result.quality.unclear_seconds:.1f} 秒无法可靠判断，未计入上述指标。）"
            )

        return "\n".join(lines)
