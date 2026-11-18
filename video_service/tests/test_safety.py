"""safety.py 的单元测试：红旗过滤、转介文本。"""

from pawcoach.coach.safety import referral_text, triggered_flags
from pawcoach.schema import MetaInfo


def test_triggered_flags_filters_and_dedupes():
    meta = MetaInfo(red_flags=["hitting", "hitting", "growling", "unknown", "fear"])
    assert triggered_flags(meta) == ["hitting", "growling", "fear"]


def test_triggered_flags_empty_and_unknown_only():
    assert triggered_flags(MetaInfo()) == []
    assert triggered_flags(MetaInfo(red_flags=["unknown", "xxx"])) == []


def test_referral_text_contains_flags_and_referral():
    text = referral_text(["hitting", "fear"])
    assert "打狗" in text
    assert "恐惧" in text
    assert "转介" in text
    assert "不生成训练建议" in text


def test_referral_text_empty_flags():
    assert referral_text([]) == ""
