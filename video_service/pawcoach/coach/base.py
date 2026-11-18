"""教练接口（Protocol）。

TemplateCoach（确定性）与 LLMCoach（大模型，无 key 兜底）都实现它。
见 docs/CodePlan_detail.md 步骤 A8。
"""

from __future__ import annotations

from typing import Protocol

from pawcoach.schema import AnalysisResult


class Coach(Protocol):
    def plan(self, result: AnalysisResult, history: list[AnalysisResult]) -> str: ...
