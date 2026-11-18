"""C5：30 用例评估 —— 读 coach_cases.yaml，跑规则层 + 安全层，判定输出是否合理。

评估的是确定性部分（规则层 plan_progress + 安全层 triggered_flags），
不评 LLM 自由文本（无法精确断言）。输出「合理率」和「安全转介率」。
"""

from __future__ import annotations

from pathlib import Path

import yaml

from pawcoach.coach.rules import effective_target_hold, plan_progress
from pawcoach.coach.safety import triggered_flags
from pawcoach.schema import AnalysisResult, MetaInfo, Summary, Trial


def load_cases(path: str | Path) -> list[dict]:
    """读 yaml 用例文件。"""
    return yaml.safe_load(Path(path).read_text(encoding="utf-8"))


def _build_result(current: dict, target_hold: float | None) -> AnalysisResult:
    delays = current.get("reward_delays") or []
    trials = [Trial(reward_t=1.0, reward_delay=float(d)) for d in delays]
    return AnalysisResult(
        summary=Summary(
            trials=len(trials),
            reliable_trials=len(trials),
            success_rate=current.get("success_rate"),
            median_hold=current.get("median_hold"),
        ),
        trials=trials,
        target_hold=target_hold,
    )


def _build_history(history: list[dict]) -> list[AnalysisResult]:
    return [
        AnalysisResult(summary=Summary(success_rate=h.get("success_rate")))
        for h in (history or [])
    ]


def run_case(case: dict) -> tuple[bool, dict]:
    """跑一个用例，返回 (passed, detail)。"""
    meta_data = case.get("meta") or {}
    meta = MetaInfo(
        target_hold=meta_data.get("target_hold"),
        red_flags=meta_data.get("red_flags") or [],
    )
    expect = case.get("expect") or {}

    # 安全用例：期望 referral
    if "referral" in expect:
        flags = triggered_flags(meta)
        got = bool(flags)
        return got == expect["referral"], {"red_flags": flags, "referral": got}

    # 规则用例
    current = _build_result(case.get("current") or {}, meta.target_hold)
    history = _build_history(case.get("history") or [])
    plan = plan_progress(current, history, target_hold=effective_target_hold(current))

    checks: list[dict] = []
    for field, got in (("action", plan.action), ("target_hold", plan.target_hold), ("focus", plan.focus)):
        if field in expect:
            checks.append({"field": field, "got": got, "want": expect[field]})

    failed = []
    for c in checks:
        ok = abs(c["got"] - c["want"]) < 1e-6 if c["field"] == "target_hold" else c["got"] == c["want"]
        c["ok"] = ok
        if not ok:
            failed.append(c)

    return (not failed, {"checks": checks, "failed": failed})


def evaluate(cases: list[dict]) -> tuple[list, int, int, int]:
    """跑全部用例，返回 (results, n_pass, n_referral, n_referral_pass)。"""
    results = []
    n_pass = 0
    n_referral = 0
    n_referral_pass = 0
    for case in cases:
        passed, detail = run_case(case)
        results.append((case.get("id"), case.get("desc", ""), passed, detail))
        if passed:
            n_pass += 1
        if "referral" in (case.get("expect") or {}):
            n_referral += 1
            if passed:
                n_referral_pass += 1
    return results, n_pass, n_referral, n_referral_pass
