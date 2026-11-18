"""MergedRewardExtractor 的单元测试：tap > marker 优先级、marker 兜底窗口、排序。

不依赖真实数据，全部用构造的 MetaInfo + AudioEvent 验证。
"""

from pawcoach.reward.merged import MergedRewardExtractor
from pawcoach.schema import AudioEvent, MetaInfo


def _meta(taps=()):
    return MetaInfo(cues=[], marker_words=["yes"], release_words=[], reward_taps=list(taps))


def _marker(t_start: float) -> AudioEvent:
    return AudioEvent(word="yes", t_start=t_start, t_end=t_start + 1.0, kind="marker")


def test_taps_returned_directly():
    ext = MergedRewardExtractor()
    rewards = ext.extract(_meta(taps=[3.0, 8.0]), [])
    assert [(r.t, r.source) for r in rewards] == [(3.0, "tap"), (8.0, "tap")]


def test_marker_fallback_when_no_taps():
    ext = MergedRewardExtractor()
    audio = [_marker(13.0), _marker(27.0)]
    rewards = ext.extract(_meta(), audio)
    assert [(r.t, r.source) for r in rewards] == [(13.0, "marker"), (27.0, "marker")]


def test_marker_covered_by_nearby_tap_is_skipped():
    # tap 在 13.0，marker 在 13.5（距离 0.5 ≤ 窗口 2.0）→ 该 marker 已被打点覆盖，不再兜底
    ext = MergedRewardExtractor()
    audio = [_marker(13.5), _marker(27.0)]
    rewards = ext.extract(_meta(taps=[13.0]), audio)
    assert [(r.t, r.source) for r in rewards] == [(13.0, "tap"), (27.0, "marker")]


def test_marker_outside_window_falls_back():
    # tap 在 10.0，marker 在 13.0（距离 3.0 > 窗口 2.0）→ 该轮没打点，marker 兜底
    ext = MergedRewardExtractor()
    audio = [_marker(13.0)]
    rewards = ext.extract(_meta(taps=[10.0]), audio)
    assert [(r.t, r.source) for r in rewards] == [(10.0, "tap"), (13.0, "marker")]


def test_output_sorted_by_time():
    ext = MergedRewardExtractor()
    audio = [_marker(5.0)]
    rewards = ext.extract(_meta(taps=[9.0]), audio)
    assert [r.t for r in rewards] == [5.0, 9.0]
