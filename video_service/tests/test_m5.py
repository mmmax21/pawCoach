"""M5（视频纠错接入 App）的 video_service 测试。

覆盖简报第 5 节第 1 条：
- 新视频无转写缓存时自动转写并产出口令事件（测试替身 + 可选的真 Whisper 合成语音用例）
- 模型进程内只加载一次；缺 whisper 时回退空事件并标明
- COACH_MODE=off 时零外部请求、coach 为空
- cue_times / markers_during_hold / corrections / reliable 的计算
- 分析后上传文件、标准化文件、缓存被删除（成功与失败两种）
"""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
import time
import types
from pathlib import Path

import pytest

from pawcoach import analyze as analyze_mod
from pawcoach.audio import transcribe as tr
from pawcoach.audio.asr import AsrAudioExtractor
from pawcoach.events.align import align
from pawcoach.schema import AudioEvent, MetaInfo, PoseSegment, RewardEvent, meta_from_dict
from pawcoach.video.probe import VideoInfo

HAS_FFMPEG = shutil.which("ffmpeg") is not None


# ---------------------------------------------------------------- 测试替身


class FakeWhisperModel:
    """假 Whisper 模型：返回固定的带词级时间戳转写，记录调用参数。"""

    def __init__(self, segments):
        self.segments = segments
        self.calls: list[dict] = []

    def transcribe(self, path, **kw):
        self.calls.append({"path": path, **kw})
        return {"language": kw.get("language") or "zh", "text": "", "segments": self.segments}


def _w(word, start, end):
    return {"word": word, "start": start, "end": end}


SEGMENTS = [
    # 「坐，坐」在同一句段：词级时间戳下应算两次口令
    {"start": 1.0, "end": 3.0, "text": "坐,坐", "words": [_w("坐", 1.0, 1.3), _w(",坐", 2.0, 2.3)]},
    # 「好」是标记词；「好了」是释放词，其中的「好」不能再算标记词
    {"start": 4.0, "end": 4.4, "text": "好", "words": [_w("好", 4.0, 4.4)]},
    {"start": 8.0, "end": 8.6, "text": "好了", "words": [_w("好", 8.0, 8.3), _w("了", 8.3, 8.6)]},
    # 「不对」是纠正词，其中的「对」不能算标记词（whisper 常出繁体）
    {"start": 12.0, "end": 12.5, "text": "不對", "words": [_w("不", 12.0, 12.2), _w("對", 12.2, 12.5)]},
]

META = MetaInfo(
    cues=["坐"], marker_words=["好", "对"], release_words=["好了"],
    correction_words=["不对"], language="zh",
)


@pytest.fixture
def fake_model(monkeypatch):
    model = FakeWhisperModel(SEGMENTS)
    monkeypatch.setattr(tr, "_MODELS", {tr.DEFAULT_MODEL: model})
    monkeypatch.setattr(tr, "DEFAULT_MODE", "whole")  # 替身返回整段转写；分句模式另有用例
    return model


def _video_file(tmp_path: Path, name: str = "abc.norm.mp4", has_audio: bool = True) -> VideoInfo:
    p = tmp_path / name
    p.write_bytes(b"\x00")
    return VideoInfo(path=str(p), duration=20.0, fps=10, width=640, height=360,
                     has_audio=has_audio, n_frames=200)


# ---------------------------------------------------------------- 3.1 自动转写


def test_missing_cache_triggers_transcription(tmp_path, fake_model):
    asr_dir = tmp_path / "asr"
    ext = AsrAudioExtractor(asr_dir=str(asr_dir))
    events = ext.extract(_video_file(tmp_path), META)

    assert ext.last_status == "transcribed"
    # 缓存写到 data/asr/<原视频名>.json（.norm 剥掉），格式与 b5_asr_probe 一致
    cache = asr_dir / "abc.json"
    data = json.loads(cache.read_text(encoding="utf-8"))
    assert {"video", "model", "language", "text", "segments", "elapsed_s"} <= set(data)
    assert data["segments"][0]["start"] == 1.0
    # 口令事件
    cues = [e.t_start for e in events if e.kind == "cue"]
    assert cues == [1.0, 2.0]
    # language 透传
    assert fake_model.calls[0]["language"] == "zh"
    assert fake_model.calls[0]["word_timestamps"] is True


def test_second_extract_reads_cache_not_model(tmp_path, fake_model):
    ext = AsrAudioExtractor(asr_dir=str(tmp_path / "asr"))
    video = _video_file(tmp_path)
    ext.extract(video, META)
    ext.extract(video, META)
    assert len(fake_model.calls) == 1
    assert ext.last_status == "cache"


def test_longer_word_wins_and_kinds(tmp_path, fake_model):
    events = AsrAudioExtractor(asr_dir=str(tmp_path / "asr")).extract(_video_file(tmp_path), META)
    by_kind = {}
    for e in events:
        by_kind.setdefault(e.kind, []).append((e.word, e.t_start))
    assert by_kind["marker"] == [("好", 4.0)]          # 「好了」「不对」里的字不重复算
    assert by_kind["release"] == [("好了", 8.0)]
    assert by_kind["correction"] == [("不对", 12.0)]


def test_old_segment_cache_still_once_per_segment(tmp_path):
    # 旧缓存无 words：保持原行为，每句段每词一次，时刻取句段起点
    (tmp_path / "old.json").write_text(json.dumps({"segments": [
        {"start": 5.0, "end": 7.0, "text": "坐 坐 坐"},
    ]}), encoding="utf-8")
    ext = AsrAudioExtractor(asr_dir=str(tmp_path))
    events = ext.extract(_video_file(tmp_path, "old.mp4"), MetaInfo(cues=["坐"]))
    assert [(e.kind, e.t_start) for e in events] == [("cue", 5.0)]


def test_model_loaded_once(monkeypatch):
    loads = []
    fake = types.ModuleType("whisper")
    fake.load_model = lambda name: loads.append(name) or object()
    monkeypatch.setitem(sys.modules, "whisper", fake)
    monkeypatch.setattr(tr, "_MODELS", {})
    a = tr.load_model("base")
    b = tr.load_model("base")
    assert a is b and loads == ["base"]


def test_missing_whisper_falls_back_empty(tmp_path, monkeypatch):
    monkeypatch.setattr(tr, "_MODELS", {})
    monkeypatch.setitem(sys.modules, "whisper", None)  # import whisper → ImportError
    ext = AsrAudioExtractor(asr_dir=str(tmp_path / "asr"))
    assert ext.extract(_video_file(tmp_path), META) == []
    assert ext.last_status.startswith("unavailable")


def test_no_audio_skips_transcription(tmp_path, fake_model):
    ext = AsrAudioExtractor(asr_dir=str(tmp_path / "asr"))
    assert ext.extract(_video_file(tmp_path, has_audio=False), META) == []
    assert ext.last_status == "no_audio"
    assert fake_model.calls == []


def test_meta_accepts_new_optional_fields():
    m = meta_from_dict({"cues": ["坐"], "correction_words": ["不对"], "language": "zh"})
    assert m.correction_words == ["不对"] and m.language == "zh"
    old = meta_from_dict({"cues": ["坐"]})
    assert old.correction_words == [] and old.language is None


# ---------------------------------------------------------------- 3.3 新字段


def _cue(t, w="坐"):
    return AudioEvent(word=w, t_start=t, t_end=t + 0.3, kind="cue")


def _marker(t):
    return AudioEvent(word="好", t_start=t, t_end=t + 0.3, kind="marker")


def _corr(t):
    return AudioEvent(word="不对", t_start=t, t_end=t + 0.3, kind="correction")


def test_repeated_cues_merge_into_one_trial():
    pose = [PoseSegment(5.0, 9.0, "sit", 0.9), PoseSegment(9.0, 12.0, "stand", 0.9),
            PoseSegment(14.0, 18.0, "sit", 0.9)]
    audio = [_cue(1.0), _cue(3.0), _cue(4.5), _cue(13.0)]
    trials, unpaired = align(pose, audio, [], MetaInfo(cues=["坐"]))
    assert len(trials) == 2
    assert trials[0].cue_t == 1.0 and trials[0].cue_times == [1.0, 3.0, 4.5]
    assert trials[0].latency == 4.0  # 原算法：从第一次口令算
    assert trials[1].cue_times == [13.0]
    assert not [u for u in unpaired if u["type"] == "sit_without_cue"]


def test_cue_during_hold_does_not_start_new_trial():
    pose = [PoseSegment(2.0, 10.0, "sit", 0.9), PoseSegment(20.0, 25.0, "sit", 0.9)]
    audio = [_cue(1.0), _cue(5.0)]  # 第二次口令在保持期间
    trials, unpaired = align(pose, audio, [], MetaInfo(cues=["坐"]))
    assert len(trials) == 1 and trials[0].cue_times == [1.0]
    assert {"type": "sit_without_cue", "t_start": 20.0, "t_end": 25.0} in unpaired


def test_stay_cue_inside_ongoing_sit_pairs_with_it():
    # 等待类：狗先坐好（2s），主人 3s 说「等」，12s 起身
    pose = [PoseSegment(2.0, 12.0, "sit", 0.9), PoseSegment(12.0, 15.0, "stand", 0.9)]
    trials, _ = align(pose, [_cue(3.0, "等")], [], MetaInfo(cues=["等"]))
    assert len(trials) == 1
    t = trials[0]
    assert t.sit_start == 2.0 and t.hold == 10.0
    assert t.latency is None and t.cue_times == []
    assert t.ended_by == "stand_up"


def test_markers_during_hold_counted():
    pose = [PoseSegment(2.0, 14.0, "sit", 0.9)]
    audio = [_cue(1.0), _marker(0.5), _marker(4.0), _marker(8.0), _marker(13.9), _marker(20.0)]
    trials, _ = align(pose, audio, [], MetaInfo(cues=["坐"], marker_words=["好"]))
    assert trials[0].markers_during_hold == 3


def test_corrections_assigned_to_trial_window():
    pose = [PoseSegment(2.0, 5.0, "sit", 0.9), PoseSegment(10.0, 13.0, "sit", 0.9)]
    audio = [_corr(0.2), _cue(1.0), _corr(6.0), _cue(9.0), _corr(15.0)]
    trials, unpaired = align(pose, audio, [], MetaInfo(cues=["坐"]))
    assert trials[0].corrections == [{"word": "不对", "t": 6.0}]
    assert trials[1].corrections == [{"word": "不对", "t": 15.0}]
    assert {"type": "correction_outside_trial", "word": "不对", "t": 0.2} in unpaired


# ---------------------------------------------------------------- analyze 全流程（替身流水线）


class _FakePose:
    def __init__(self, segs):
        self.segs = segs

    def extract(self, video):
        return self.segs


def _make_video(path: Path, seconds: int = 3) -> Path:
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error",
         "-f", "lavfi", "-i", f"testsrc=size=1920x1080:rate=30:duration={seconds}",
         "-f", "lavfi", "-i", f"sine=frequency=440:duration={seconds}",
         "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", str(path)],
        check=True,
    )
    return path


@pytest.fixture
def pipeline(tmp_path, monkeypatch):
    """chdir 到临时目录（data/* 都落在这里），姿态与转写用替身，落库写临时库。"""
    monkeypatch.chdir(tmp_path)
    monkeypatch.setattr(tr, "DEFAULT_MODE", "whole")
    segs = [PoseSegment(0.0, 0.5, "stand", 0.9), PoseSegment(0.5, 2.0, "sit", 0.9),
            PoseSegment(2.0, 3.0, "unclear", 0.1)]
    monkeypatch.setattr(analyze_mod, "_make_pose_extractor", lambda: (_FakePose(segs), "fake"))
    monkeypatch.setattr(tr, "_MODELS", {tr.DEFAULT_MODEL: FakeWhisperModel([
        {"start": 0.1, "end": 0.3, "text": "坐", "words": [_w("坐", 0.1, 0.3)]},
        {"start": 0.8, "end": 1.0, "text": "好", "words": [_w("好", 0.8, 1.0)]},
    ])})
    saved = []
    monkeypatch.setattr(analyze_mod.store, "save_result", lambda r: saved.append(r))
    # 姿态 / 检测缓存模拟（真实现会写到 data/pose/<stem>.norm_*）
    return types.SimpleNamespace(tmp=tmp_path, saved=saved)


def _fake_pose_cache(stem: str):
    Path("data/pose").mkdir(parents=True, exist_ok=True)
    for suffix in ("_superanimal_quadruped_rtmpose_s_ssdlite.h5", "_dogbox.npy"):
        Path(f"data/pose/{stem}.norm{suffix}").write_bytes(b"x")


@pytest.mark.skipif(not HAS_FFMPEG, reason="需要 ffmpeg（conda activate pawcoach）")
def test_analyze_coach_off_no_network_and_cleanup(pipeline, monkeypatch):
    monkeypatch.delenv("COACH_MODE", raising=False)
    monkeypatch.setenv("LLM_API_KEY", "sk-should-not-be-used")
    import httpx

    def boom(*a, **kw):
        raise AssertionError("COACH_MODE=off 时不应发起任何 HTTP 请求")

    monkeypatch.setattr(httpx, "post", boom)
    monkeypatch.setattr(httpx.Client, "send", boom)

    Path("data/uploads").mkdir(parents=True)
    video = _make_video(Path("data/uploads/job1_clip.mp4"))
    _fake_pose_cache("job1_clip")
    meta = MetaInfo(cues=["坐"], marker_words=["好"], language="zh", target_hold=1.0)

    result = analyze_mod.analyze_video(video, meta=meta, cleanup=True)

    assert result.coach == ""
    assert result.quality.asr == "transcribed"
    assert len(result.trials) == 1
    t = result.trials[0]
    assert t.reliable is True and t.cue_times == [0.1] and t.markers_during_hold == 1
    assert result.summary.reliable_trials == 1
    # 删干净：原视频、标准化视频、姿态缓存、转写缓存
    leftovers = [p for d in ("data/uploads", "data/normalized", "data/pose", "data/asr")
                 if Path(d).exists() for p in Path(d).iterdir()]
    assert leftovers == []
    assert pipeline.saved  # 数字照常落库


@pytest.mark.skipif(not HAS_FFMPEG, reason="需要 ffmpeg（conda activate pawcoach）")
def test_reliable_flag_follows_gate(pipeline, monkeypatch):
    segs = [PoseSegment(0.5, 1.5, "sit", 0.9), PoseSegment(1.5, 2.0, "stand", 0.9),
            PoseSegment(2.2, 2.9, "sit", 0.2)]
    monkeypatch.setattr(analyze_mod, "_make_pose_extractor", lambda: (_FakePose(segs), "fake"))
    monkeypatch.setattr(tr, "_MODELS", {tr.DEFAULT_MODEL: FakeWhisperModel([
        {"start": 0.1, "end": 0.3, "text": "坐", "words": [_w("坐", 0.1, 0.3)]},
        {"start": 2.0, "end": 2.1, "text": "坐", "words": [_w("坐", 2.0, 2.1)]},
    ])})
    video = _make_video(Path("clip.mp4"))
    result = analyze_mod.analyze_video(video, meta=MetaInfo(cues=["坐"]), cleanup=True)
    assert [t.reliable for t in result.trials] == [True, False]
    assert result.summary.reliable_trials == 1


@pytest.mark.skipif(not HAS_FFMPEG, reason="需要 ffmpeg（conda activate pawcoach）")
def test_cleanup_also_on_failure(pipeline, monkeypatch):
    def broken():
        raise RuntimeError("姿态模型坏了")

    monkeypatch.setattr(analyze_mod, "_make_pose_extractor", broken)
    Path("data/uploads").mkdir(parents=True)
    video = _make_video(Path("data/uploads/job2_clip.mp4"))
    with pytest.raises(RuntimeError):
        analyze_mod.analyze_video(video, meta=MetaInfo(cues=["坐"]), cleanup=True)
    assert not video.exists()
    assert not list(Path("data/normalized").glob("*"))


@pytest.mark.skipif(not HAS_FFMPEG, reason="需要 ffmpeg（conda activate pawcoach）")
def test_cli_mode_keeps_source(pipeline):
    video = _make_video(Path("keep.mp4"))
    analyze_mod.analyze_video(video, meta=MetaInfo(cues=["坐"]))
    assert video.exists()


def test_coach_mode_parsing(monkeypatch, tmp_path):
    from pawcoach.config import coach_mode

    monkeypatch.chdir(tmp_path)
    monkeypatch.delenv("COACH_MODE", raising=False)
    assert coach_mode() == "off"
    for raw, want in (("template", "template"), ("LLM", "llm"), ("bogus", "off"), ("off", "off")):
        monkeypatch.setenv("COACH_MODE", raw)
        assert coach_mode() == want


@pytest.mark.skipif(not HAS_FFMPEG, reason="需要 ffmpeg（conda activate pawcoach）")
def test_coach_template_mode_still_works(pipeline, monkeypatch):
    monkeypatch.setenv("COACH_MODE", "template")
    import httpx

    monkeypatch.setattr(httpx, "post", lambda *a, **k: (_ for _ in ()).throw(AssertionError("no http")))
    video = _make_video(Path("t.mp4"))
    result = analyze_mod.analyze_video(video, meta=MetaInfo(cues=["坐"]), cleanup=True)
    assert result.coach  # 模板教练有输出，且不联网


# ---------------------------------------------------------------- API


@pytest.mark.skipif(not HAS_FFMPEG, reason="需要 ffmpeg（conda activate pawcoach）")
def test_api_upload_deletes_video_and_reports_health(pipeline, monkeypatch):
    from fastapi.testclient import TestClient

    from app import main

    monkeypatch.delenv("COACH_MODE", raising=False)
    client = TestClient(main.app)
    health = client.get("/").json()
    assert health["status"] == "ok" and health["coach_mode"] == "off"
    assert health["asr"] in {"loaded", "ready", "not_downloaded", "unavailable"}
    assert health["pose"] in {"ready", "not_downloaded", "stub"}

    src = _make_video(pipeline.tmp / "src.mp4")
    meta = {"cues": ["坐"], "marker_words": ["好"], "language": "zh", "correction_words": ["不对"]}
    with open(src, "rb") as f:
        r = client.post("/analyze", files={"file": ("../../evil name.mp4", f, "video/mp4")},
                        data={"meta": json.dumps(meta, ensure_ascii=False)})
    job = r.json()["job_id"]
    for _ in range(100):
        body = client.get(f"/results/{job}").json()
        if body["status"] != "pending":
            break
        time.sleep(0.1)
    assert body["status"] == "done", body
    assert body["result"]["coach"] == ""
    assert "reliable" in body["result"]["trials"][0]
    assert list(Path("data/uploads").iterdir()) == []


def test_api_bad_meta_leaves_no_file(pipeline):
    from fastapi.testclient import TestClient

    from app import main

    client = TestClient(main.app)
    r = client.post("/analyze", files={"file": ("a.mp4", b"x", "video/mp4")}, data={"meta": "{not json"})
    assert r.status_code == 400
    assert not Path("data/uploads").exists() or not list(Path("data/uploads").iterdir())


# ---------------------------------------------------------------- 真 Whisper（可选，模型已下载时才跑）


def _real_whisper_ready() -> bool:
    return (
        HAS_FFMPEG
        and shutil.which("say") is not None
        and tr.whisper_available()
        and (Path.home() / ".cache/whisper/base.pt").exists()
    )


@pytest.mark.skipif(not _real_whisper_ready(), reason="需要 macOS say + whisper base 已下载（先跑 scripts/warmup.py）")
def test_real_whisper_on_synthetic_speech(tmp_path, monkeypatch):
    """用 macOS say 合成「坐」口令的视频，无缓存时真 Whisper 自动转写并识别出口令。"""
    monkeypatch.setattr(tr, "_MODELS", dict(tr._MODELS))
    aiff = tmp_path / "cue.aiff"
    subprocess.run(["say", "-v", "Tingting", "-o", str(aiff), "坐。 坐下。"], check=True)
    video = tmp_path / "speech.mp4"
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi", "-i", "color=c=gray:size=320x240:rate=10",
         "-i", str(aiff), "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", str(video)],
        check=True,
    )
    from pawcoach.video.probe import load_video

    ext = AsrAudioExtractor(asr_dir=str(tmp_path / "asr"))
    events = ext.extract(load_video(video), MetaInfo(cues=["坐"], language="zh"))
    assert ext.last_status == "transcribed"
    assert any(e.kind == "cue" for e in events)
    assert (tmp_path / "asr" / "speech.json").exists()


@pytest.mark.skipif(not HAS_FFMPEG, reason="需要 ffmpeg（conda activate pawcoach）")
def test_max_duration_rejects_long_video_and_cleans(pipeline):
    Path("data/uploads").mkdir(parents=True)
    video = _make_video(Path("data/uploads/job3_long.mp4"), seconds=4)
    with pytest.raises(analyze_mod.VideoTooLong, match="video_too_long"):
        analyze_mod.analyze_video(video, meta=MetaInfo(cues=["坐"], max_duration=2), cleanup=True)
    assert not video.exists()
    # 时长内正常
    ok = _make_video(Path("ok.mp4"), seconds=2)
    analyze_mod.analyze_video(ok, meta=MetaInfo(cues=["坐"], max_duration=2), cleanup=True)


# ---------------------------------------------------------------- 分句转写（能量 VAD）


def _bursts(spec, total=6.0, sr=16000):
    """在静音里放几段 440Hz 声音：spec = [(起, 止)]。"""
    import numpy as np

    audio = np.random.default_rng(0).normal(0, 0.001, int(total * sr)).astype("float32")
    t = np.arange(int(total * sr)) / sr
    for a, b in spec:
        m = (t >= a) & (t < b)
        audio[m] += 0.3 * np.sin(2 * np.pi * 440 * t[m]).astype("float32")
    return audio


def test_voice_regions_finds_each_utterance():
    regions = tr.voice_regions(_bursts([(0.8, 1.2), (2.0, 2.3), (2.45, 2.7), (4.0, 4.5)]))
    # 2.0–2.3 与 2.45–2.7 间隔 < 0.3s 合成一句
    assert len(regions) == 3
    starts = [round(a + tr._PAD, 1) for a, _ in regions]
    assert starts == [0.8, 2.0, 4.0]
    assert tr.voice_regions(_bursts([])) == []  # 只有底噪


def test_chunked_transcription_uses_voice_onsets(monkeypatch, tmp_path):
    class ChunkModel:
        def __init__(self):
            self.n = 0

        def transcribe(self, audio, **kw):
            self.n += 1
            word = ["坐", "坐", "好"][self.n - 1]
            # 替身故意把词级时间戳给得很早（模拟 DTW 偏差），应以声音起点为准
            return {"language": "zh", "segments": [{"start": 0.0, "end": 0.5, "text": word,
                                                     "words": [{"word": word, "start": 0.0, "end": 0.4}]}]}

    model = ChunkModel()
    monkeypatch.setattr(tr, "_MODELS", {tr.DEFAULT_MODEL: model})
    monkeypatch.setattr(tr, "DEFAULT_MODE", "chunked")
    monkeypatch.setattr(tr, "_load_audio", lambda p: _bursts([(1.0, 1.3), (2.5, 2.8), (4.2, 4.5)]))
    ext = AsrAudioExtractor(asr_dir=str(tmp_path / "asr"))
    events = ext.extract(_video_file(tmp_path), MetaInfo(cues=["坐"], marker_words=["好"], language="zh"))
    assert model.n == 3
    got = [(e.kind, round(e.t_start, 1)) for e in events]
    assert got == [("cue", 1.0), ("cue", 2.5), ("marker", 4.2)]
    data = json.loads((tmp_path / "asr" / "abc.json").read_text(encoding="utf-8"))
    assert data["mode"] == "chunked"


# ---------------------------------------------------------------- 合并转写（hybrid）


def _ev(word, t, kind, dur=0.3):
    return AudioEvent(word=word, t_start=t, t_end=t + dur, kind=kind)


def test_hybrid_is_default_and_stores_both(monkeypatch, tmp_path):
    class Model:
        def __init__(self):
            self.calls = []

        def transcribe(self, x, **kw):
            whole = isinstance(x, str)
            self.calls.append(("whole" if whole else "chunk", kw.get("language")))
            if whole:  # 整段：认出「坐」，语言 zh
                return {"language": "zh", "text": "坐", "segments": [
                    {"start": 1.0, "end": 1.4, "text": "坐", "words": [_w("坐", 1.0, 1.4)]}]}
            return {"language": "ja", "segments": [  # 分句：把「坐」听成「走」
                {"start": 0.0, "end": 0.5, "text": "走", "words": [_w("走", 0.0, 0.4)]}]}

    model = Model()
    assert tr.DEFAULT_MODE == "hybrid"
    monkeypatch.setattr(tr, "_MODELS", {tr.DEFAULT_MODEL: model})
    monkeypatch.setattr(tr, "_load_audio", lambda p: _bursts([(1.0, 1.3)]))
    ext = AsrAudioExtractor(asr_dir=str(tmp_path / "asr"))
    meta = MetaInfo(cues=["坐"], marker_words=["好"], language=None)
    events = ext.extract(_video_file(tmp_path), meta)
    # 先整段，再用整段检测出的语言跑分句（而不是让每句各自检测）
    assert model.calls == [("whole", None), ("chunk", "zh")]
    data = json.loads((tmp_path / "asr" / "abc.json").read_text(encoding="utf-8"))
    assert data["mode"] == "hybrid" and data["language"] == "zh"
    assert data["segments"][0]["text"] == "走" and data["alt_segments"][0]["text"] == "坐"
    # 分句漏掉的口令由整段补上
    assert [(e.kind, e.word, e.t_start) for e in events] == [("cue", "坐", 1.0)]


def test_unknown_mode_rejected(monkeypatch):
    monkeypatch.setattr(tr, "_MODELS", {tr.DEFAULT_MODEL: object()})
    with pytest.raises(ValueError):
        tr.transcribe(Path("x.mp4"), mode="fast")


def test_merge_events_dedups_one_to_one():
    from pawcoach.audio.asr import merge_events

    primary = [_ev("坐", 8.0, "cue"), _ev("坐", 9.4, "cue"), _ev("好", 12.6, "marker")]
    # 整段时间戳早约 1 秒：两次「坐」各配一个，不能合成一次；12.6 的「好」配上；20.0 的「好」是漏识，补进来
    extra = [_ev("坐", 7.1, "cue"), _ev("坐", 8.5, "cue"), _ev("好", 11.7, "marker"), _ev("好", 20.0, "marker")]
    got = [(e.word, e.t_start) for e in merge_events(primary, extra)]
    assert got == [("坐", 8.0), ("坐", 9.4), ("好", 12.6), ("好", 20.0)]


def test_merge_events_keeps_extra_repeat_and_respects_kind():
    from pawcoach.audio.asr import merge_events

    # 主结果只认出一次「坐」，整段认出两次：多出的一次补进来（口令重复要靠它）
    got = merge_events([_ev("坐", 2.0, "cue")], [_ev("坐", 1.2, "cue"), _ev("坐", 2.6, "cue")])
    assert [e.t_start for e in got] == [2.0, 2.6]
    # 主结果的「好了」（释放词）附近，整段只转出「好」：长词优先，不多算标记词
    got = merge_events([_ev("好了", 15.5, "release")], [_ev("好", 15.6, "marker")])
    assert [(e.kind, e.word) for e in got] == [("release", "好了")]
    # 离得远的「好」照常补进来
    got = merge_events([_ev("好了", 15.5, "release")], [_ev("好", 12.0, "marker")])
    assert [(e.kind, e.word) for e in got] == [("marker", "好"), ("release", "好了")]


def test_old_cache_without_alt_segments_unchanged(tmp_path):
    asr_dir = tmp_path / "asr"
    asr_dir.mkdir()
    (asr_dir / "abc.json").write_text(json.dumps({"segments": SEGMENTS}, ensure_ascii=False), encoding="utf-8")
    ext = AsrAudioExtractor(asr_dir=str(asr_dir), auto_transcribe=False)
    events = ext.extract(_video_file(tmp_path), META)
    assert [(e.kind, e.t_start) for e in events] == [
        ("cue", 1.0), ("cue", 2.0), ("marker", 4.0), ("release", 8.0), ("correction", 12.0)]
