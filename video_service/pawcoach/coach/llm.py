"""LLM 教练：调 OpenAI 兼容大模型 API 生成建议；无 key / 超时则兜底到 TemplateCoach。

模型 / key / 地址是单独的配置项，集中在 pawcoach/config.py（读 .env 或环境变量），
不散落在代码里。C3：prompt 注入本次指标 + 历史趋势 + 规则层输出 + SOP。
原则：大模型只读结构化数字，不看视频（K9-Bench 依据）。
"""

from __future__ import annotations

import json
from dataclasses import asdict

import httpx

from pawcoach.config import llm_config
from pawcoach.coach.rules import effective_target_hold, plan_progress, sop_query_terms
from pawcoach.coach.sop import retrieve_sop
from pawcoach.coach.template import TemplateCoach
from pawcoach.schema import AnalysisResult, to_json

class LLMCoach:
    def __init__(self, model: str | None = None, base_url: str | None = None):
        self.model = model          # None 表示用配置（.env / 环境变量）
        self.base_url = base_url    # 同上
        self._fallback = TemplateCoach()

    def plan(self, result: AnalysisResult, history: list[AnalysisResult]) -> str:
        cfg = llm_config()
        api_key = cfg["api_key"]
        model = self.model or cfg["model"]
        base_url = self.base_url or cfg["base_url"]
        if not api_key:
            return self._fallback.plan(result, history)

        plan = plan_progress(result, history, target_hold=effective_target_hold(result))
        sop = retrieve_sop(sop_query_terms(plan), top_k=2)

        try:
            resp = httpx.post(
                base_url,
                headers={
                    "Authorization": f"Bearer {api_key}",
                    "content-type": "application/json",
                },
                json={
                    "model": model,
                    "max_tokens": 600,
                    "messages": [
                        {"role": "user", "content": self._build_prompt(result, history, plan, sop)}
                    ],
                },
                timeout=30.0,
            )
            resp.raise_for_status()
            data = resp.json()
            text = (data.get("choices", [{}])[0].get("message", {}) or {}).get("content", "")
            return (text or "").strip() or self._fallback.plan(result, history)
        except Exception:
            return self._fallback.plan(result, history)

    @staticmethod
    def _build_prompt(
        result: AnalysisResult, history: list[AnalysisResult], plan, sop: str
    ) -> str:
        history_json = (
            json.dumps([asdict(r) for r in history[-3:]], ensure_ascii=False)
            if history
            else "（无历史）"
        )
        return (
            "你是一位正向强化训犬教练。基于以下结构化指标（不要看视频），"
            "重要：如果本次没有任何训练轮次，或指标显示大部分时间无法可靠判断（unclear 占比高），"
            "要如实说明数据不足、建议换个机位重拍，严禁编造训练过程、口令、奖励时机或任何时间点。"
            "用中文给出三点，每一点都要引用具体视频时间点（秒）：\n"
            "1. 做得好的一点；\n2. 最需改的一点；\n3. 下次怎么练。\n"
            "风格要求：说大白话，面向没学过训犬术语的普通养狗人，不要出现任何英文或代码字段名——\n"
            "latency 说「反应快慢」、reward_delay 说「奖励给得早还是晚」、"
            "success_rate 说「成功率」、trial 说「这一轮」，也不要照抄 sit_start/sit_end/reward_t 这类字段名。\n"
            f"规则层建议：下次目标保持 {plan.target_hold:.1f} 秒，"
            f"本次重点「{plan.focus or '无'}」。{plan.session}\n"
            f"参考要点：\n{sop or '（无）'}\n"
            f"历史趋势（最近 3 次）：\n{history_json}\n"
            f"本次指标：\n{to_json(result)}"
        )
