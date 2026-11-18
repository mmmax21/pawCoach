"""AsrAudioExtractor 的单元测试：读转写缓存、同音匹配、无缓存降级。

缓存文件是 gitignore 的（data/asr/），测试用临时目录自建，不依赖真实数据。
"""

import json
from pathlib import Path

from pawcoach.audio.asr import AsrAudioExtractor, _matches, _normalize
from pawcoach.schema import MetaInfo
from pawcoach.video.probe import VideoInfo


def _video(name: str = "dog3.mp4") -> VideoInfo:
    return VideoInfo(
        path=f"data/raw/{name}", duration=60.0, fps=30, width=404, height=720,
        has_audio=True, n_frames=1800,
    )


def test_normalize_folds_case_and_punct():
    assert _normalize("  Sats! YES, good-job?  ") == "sats yes good job"
    assert _normalize("做下") == "做下"


def test_homophone_matching():
    # dog3 里 whisper 把 "sit" 转成 "Sats"，同音表要能命中
    assert _matches(_normalize("Sats."), "sit")
    # dog1 里「坐」被转成「做」
    assert _matches(_normalize("當它做下的瞬間"), "坐")
    # 词边界：sit 不能误中 sitting
    assert not _matches(_normalize("sitting on the floor"), "sit")


def test_extract_reads_cache_and_maps_kinds(tmp_path: Path):
    cache = tmp_path / "dog3.json"
    cache.write_text(json.dumps({"segments": [
        {"start": 11.0, "end": 13.0, "text": "Sats."},
        {"start": 13.0, "end": 14.0, "text": "Yes."},
        {"start": 40.0, "end": 42.0, "text": "Good job."},
    ]}, ensure_ascii=False), encoding="utf-8")

    ext = AsrAudioExtractor(asr_dir=str(tmp_path))
    meta = MetaInfo(cues=["sit"], marker_words=["yes"], release_words=["good"])
    events = ext.extract(_video("dog3.mp4"), meta)

    kinds = [(e.kind, e.word, e.t_start) for e in events]
    assert ("cue", "sit", 11.0) in kinds
    assert ("marker", "yes", 13.0) in kinds
    assert ("release", "good", 40.0) in kinds


def test_extract_no_cache_returns_empty(tmp_path: Path):
    ext = AsrAudioExtractor(asr_dir=str(tmp_path))
    meta = MetaInfo(cues=["sit"])
    assert ext.extract(_video("missing.mp4"), meta) == []


def test_extract_normalized_stem(tmp_path: Path):
    # 标准化产物 dog1.norm.mp4 应回退到 dog1 的缓存
    cache = tmp_path / "dog1.json"
    cache.write_text(json.dumps({"segments": [
        {"start": 27.0, "end": 28.5, "text": "當它做下的瞬間"},
    ]}, ensure_ascii=False), encoding="utf-8")

    ext = AsrAudioExtractor(asr_dir=str(tmp_path))
    meta = MetaInfo(cues=["坐"])
    events = ext.extract(_video("dog1.norm.mp4"), meta)
    assert len(events) == 1
    assert events[0].kind == "cue"
