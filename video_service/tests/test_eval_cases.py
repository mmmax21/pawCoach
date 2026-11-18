"""eval_cases 的单元测试：run_case 规则/安全分支 + evaluate 汇总。"""

from pawcoach.eval_cases import evaluate, run_case


def test_run_case_rule_increase():
    case = {
        "meta": {"target_hold": 10.0},
        "history": [{"success_rate": 0.9}],
        "current": {"success_rate": 0.85},
        "expect": {"action": "increase", "target_hold": 12.5, "focus": ""},
    }
    passed, _ = run_case(case)
    assert passed


def test_run_case_rule_mismatch_fails():
    # 数据不足（无历史）应该 hold，不是 increase
    case = {
        "meta": {"target_hold": 10.0},
        "current": {"success_rate": 0.9},
        "expect": {"action": "increase", "target_hold": 12.5},
    }
    passed, detail = run_case(case)
    assert not passed
    assert detail["failed"]


def test_run_case_safety_referral():
    case = {"meta": {"red_flags": ["hitting"]}, "expect": {"referral": True}}
    passed, _ = run_case(case)
    assert passed


def test_evaluate_counts():
    cases = [
        {
            "id": 1, "desc": "规则", "meta": {"target_hold": 10.0},
            "history": [{"success_rate": 0.9}], "current": {"success_rate": 0.85},
            "expect": {"action": "increase", "target_hold": 12.5},
        },
        {"id": 2, "desc": "安全", "meta": {"red_flags": ["fear"]}, "expect": {"referral": True}},
    ]
    results, n_pass, n_referral, n_referral_pass = evaluate(cases)
    assert n_pass == 2
    assert n_referral == 1
    assert n_referral_pass == 1
    assert len(results) == 2
