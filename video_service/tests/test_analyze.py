"""analyze_video 的辅助函数测试：空数据时的诚实提示（防 LLM 幻觉回归）。

背景：dog2 无 meta/无口令/正面视角，对齐结果为空（trials=0、unpaired=0），
早期实现会调 LLM 在空数据上编造训练细节；现在走 `_insufficient_data_text` 诚实分支。
"""

from pawcoach.analyze import _insufficient_data_text
from pawcoach.schema import AnalysisResult, Quality, Summary, default_meta


def test_insufficient_data_text_is_honest():
    result = AnalysisResult(
        video_id="dog2",
        quality=Quality(unclear_seconds=15.0, unclear_ratio=0.859),
        trials=[],
        summary=Summary(trials=0),
        unpaired=[],
    )
    text = _insufficient_data_text(result)
    assert "没有识别到可分析的训练轮次" in text
    assert "86%" in text  # round(0.859 * 100) = 86
    assert "重拍" in text


def test_insufficient_data_text_no_unclear():
    # unclear_seconds=0 时不应提「无法可靠判断」
    result = AnalysisResult(video_id="x", trials=[], unpaired=[])
    text = _insufficient_data_text(result)
    assert "没有识别到可分析的训练轮次" in text
    assert "无法可靠判断" not in text


def test_default_meta_has_common_cues():
    m = default_meta()
    assert "坐" in m.cues and "sit" in m.cues
    assert "好" in m.marker_words and "yes" in m.marker_words
    assert "可以了" in m.release_words and "ok" in m.release_words
