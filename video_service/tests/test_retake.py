"""减少重拍（2026-11-18）：预检、events、/realign。"""

from __future__ import annotations

import json
from dataclasses import asdict
from pathlib import Path

import pytest

from pawcoach import analyze as analyze_mod
from pawcoach import precheck as pc_mod
from pawcoach.schema import AudioEvent, MetaInfo, PoseSegment, Quality, to_json
from tests.test_m5 import HAS_FFMPEG, _FakePose, _make_video, pipeline  # noqa: F401  pipeline 是 fixture

META = MetaInfo(cues=["坐"], marker_words=["好"], release_words=["好了"], language="zh", target_hold=2.0)

# 三次坐下；只有第一次识别到口令（第二、三次口令被 Whisper 听错）
POSE = [
    PoseSegment(0.0, 2.0, "stand", 0.9),
    PoseSegment(2.0, 6.0, "sit", 0.9),
    PoseSegment(6.0, 9.0, "stand", 0.9),
    PoseSegment(9.0, 13.0, "sit", 0.9),
    PoseSegment(13.0, 16.0, "stand", 0.9),
    PoseSegment(16.0, 20.0, "sit", 0.9),
    PoseSegment(20.0, 22.0, "stand", 0.9),
]
AUDIO = [
    AudioEvent("坐", 1.0, 1.2, "cue"),
    AudioEvent("好", 2.5, 2.7, "marker"),
    AudioEvent("好", 11.5, 11.7, "marker"),
    AudioEvent("好了", 12.5, 12.8, "release"),
    AudioEvent("好", 16.3, 16.5, "marker"),
]


def _base() -> dict:
    r = analyze_mod.assemble("v1", POSE, AUDIO, META, Quality(audio_ok=True, asr="transcribed"))
    return json.loads(to_json(r))


# ---------------------------------------------------------------- events


def test_result_carries_events_for_realign():
    r = _base()
    assert len(r["trials"]) == 1
    assert [u["t_start"] for u in r["unpaired"] if u["type"] == "sit_without_cue"] == [9.0, 16.0]
    assert r["events"]["pose"][1] == asdict(POSE[1])
    assert len(r["events"]["audio"]) == len(AUDIO)
    assert r["trials"][0]["cue_source"] == "asr"


# ---------------------------------------------------------------- realign


def test_realign_adds_user_confirmed_trials():
    out = analyze_mod.realign(_base(), META, [9.0, 16.0])
    assert [t.sit_start for t in out.trials] == [2.0, 9.0, 16.0]
    assert [t.cue_source for t in out.trials] == ["asr", "user", "user"]
    user = out.trials[1]
    # 只确认了「喊过口令」，没说什么时候：反应快慢、口令次数都不算
    assert user.latency is None and user.cue_times == []
    # 其余测量照常：奖励、结束方式、标记词
    assert user.reward_t == 11.5 and user.ended_by == "release" and user.markers_during_hold == 1
    assert out.summary.reliable_trials == 3
    assert not [u for u in out.unpaired if u["type"] == "sit_without_cue"]
    # events 不含用户补的口令：再次补标时以新的选择为准
    assert len(out.events["audio"]) == len(AUDIO)


def test_realign_replaces_previous_selection():
    first = json.loads(to_json(analyze_mod.realign(_base(), META, [9.0, 16.0])))
    again = analyze_mod.realign(first, META, [16.0])
    assert [t.sit_start for t in again.trials] == [2.0, 16.0]


def test_realign_ignores_unknown_times_and_keeps_quality():
    base = _base()
    base["quality"]["unclear_ratio"] = 0.2
    out = analyze_mod.realign(base, META, [5.0, 99.0])
    assert len(out.trials) == 1
    assert out.quality.unclear_ratio == 0.2 and out.quality.asr == "transcribed"


def test_realign_without_events_rejected():
    base = _base()
    base["events"] = {}
    with pytest.raises(ValueError):
        analyze_mod.realign(base, META, [9.0])


def test_api_realign():
    from fastapi.testclient import TestClient

    from app import main

    client = TestClient(main.app)
    meta = {"cues": ["坐"], "marker_words": ["好"], "release_words": ["好了"], "language": "zh", "target_hold": 2.0}
    r = client.post("/realign", json={"result": _base(), "meta": meta, "user_cue_sits": [9.0]})
    assert r.status_code == 200
    body = r.json()
    assert body["status"] == "done"
    assert [t["cue_source"] for t in body["result"]["trials"]] == ["asr", "user"]
    bad = client.post("/realign", json={"result": {"events": {}}, "meta": meta, "user_cue_sits": [9.0]})
    assert bad.status_code == 400


# ---------------------------------------------------------------- 预检


@pytest.mark.parametrize(
    "frames,dog,side,issues",
    [
        (16, 16, 8, []),
        (16, 4, 4, ["no_dog"]),      # 只有 25% 的帧有狗
        (16, 5, 5, []),              # 31%：放行
        (16, 15, 0, ["angle"]),      # 俯拍：有狗但全程看不出姿势
        (16, 15, 3, []),             # 20%：放行（只拦明显不行的）
        (0, 0, 0, []),
    ],
)
def test_precheck_decide(frames, dog, side, issues):
    assert pc_mod.decide(frames, dog, side) == issues


@pytest.mark.skipif(not HAS_FFMPEG, reason="需要 ffmpeg（conda activate pawcoach）")
def test_precheck_failure_skips_full_analysis_and_cleans(pipeline, monkeypatch):  # noqa: F811
    class MustNotRun(_FakePose):
        def extract(self, video):
            raise AssertionError("预检不通过时不应跑整段姿态")

    monkeypatch.setattr(analyze_mod, "_make_pose_extractor", lambda: (MustNotRun([]), "superanimal"))
    fake = {"frames": 16, "dog_frames": 16, "side_frames": 0, "voice": True, "issues": ["angle"]}
    monkeypatch.setattr(pc_mod, "precheck", lambda video: fake)
    stages = []
    Path("data/uploads").mkdir(parents=True)
    video = _make_video(Path("data/uploads/job3_clip.mp4"))
    result = analyze_mod.analyze_video(video, meta=META, cleanup=True, precheck=True, on_stage=stages.append)
    assert result.precheck == fake and result.trials == []
    assert result.quality.unclear_ratio == 1.0 and result.quality.asr == "skipped"
    assert stages == ["precheck"]
    leftovers = [p for d in ("data/uploads", "data/normalized") if Path(d).exists() for p in Path(d).iterdir()]
    assert leftovers == []


@pytest.mark.skipif(not HAS_FFMPEG, reason="需要 ffmpeg（conda activate pawcoach）")
def test_precheck_pass_runs_full_analysis(pipeline, monkeypatch):  # noqa: F811
    segs = [PoseSegment(0.0, 0.5, "stand", 0.9), PoseSegment(0.5, 2.0, "sit", 0.9)]
    monkeypatch.setattr(analyze_mod, "_make_pose_extractor", lambda: (_FakePose(segs), "superanimal"))
    ok = {"frames": 16, "dog_frames": 16, "side_frames": 10, "voice": True, "issues": []}
    monkeypatch.setattr(pc_mod, "precheck", lambda video: ok)
    stages = []
    video = _make_video(Path("clip.mp4"))
    result = analyze_mod.analyze_video(video, meta=META, cleanup=True, precheck=True, on_stage=stages.append)
    assert stages == ["precheck", "analyzing"]
    assert result.precheck == ok and len(result.trials) == 1
    assert result.events["pose"]
