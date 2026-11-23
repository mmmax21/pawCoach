"""v3：出声检测补口令 / 奖励；目标姿势可配（趴下）。"""

import numpy as np

from pawcoach.analyze import assemble
from pawcoach.audio.onsets import ONSET_WORD, fill_with_onsets, onsets_from_pcm
from pawcoach.events.align import align
from pawcoach.schema import AudioEvent, MetaInfo, PoseSegment, Quality, RewardEvent


def seg(label, a, b, conf=0.8):
    return PoseSegment(label=label, t_start=a, t_end=b, conf=conf)


POSE = [seg("stand", 0, 3), seg("sit", 3, 8), seg("stand", 8, 12), seg("sit", 12, 16), seg("stand", 16, 20)]


def test_onsets_from_synthetic_pcm():
    sr = 16000
    x = np.random.default_rng(0).normal(0, 0.001, sr * 6).astype(np.float32)
    for t in (1.5, 4.0):
        i = int(t * sr)
        x[i : i + int(0.3 * sr)] += 0.2 * np.sin(np.arange(int(0.3 * sr)) * 2 * np.pi * 220 / sr)
    on = onsets_from_pcm(x, sr)
    assert len(on) == 2
    assert abs(on[0] - 1.5) < 0.08 and abs(on[1] - 4.0) < 0.08


def test_fill_roles_by_pose():
    asr = [AudioEvent(word="坐", t_start=10.5, t_end=10.8, kind="cue")]
    onsets = [1.5, 4.2, 6.0, 10.6, 13.0, 18.0]
    out = fill_with_onsets(asr, onsets, POSE)
    got = [(round(a.t_start, 1), a.kind, a.source) for a in out]
    assert (1.5, "cue", "onset") in got           # 坐下前 1.5 秒：口令
    assert (4.2, "marker", "onset") in got        # 坐着的第一声：奖励
    assert all(a.t_start != 6.0 for a in out)     # 同一段坐姿的第二声：不用
    assert sum(1 for a in out if abs(a.t_start - 10.6) < 0.2) == 1  # 和转写重合：不重复
    assert (13.0, "marker", "onset") in got
    assert all(a.t_start != 18.0 for a in out)    # 之后没有坐下：不用
    assert all(a.word == ONSET_WORD for a in out if a.source == "onset")


def test_onsets_make_trials_reliable_without_asr():
    meta = MetaInfo(cues=["坐"], marker_words=["好"])
    audio = fill_with_onsets([], [1.5, 4.2, 10.0, 12.6], POSE)
    q = Quality(audio_ok=True)
    r = assemble("v", POSE, audio, meta, q)
    assert len(r.trials) == 2
    t0 = r.trials[0]
    assert t0.cue_source == "onset" and t0.latency == 1.5 and t0.reward_t == 4.2


def test_target_down():
    pose = [seg("stand", 0, 2), seg("down", 2.5, 9), seg("stand", 9, 12)]
    meta = MetaInfo(cues=["趴"], target_pose="down")
    audio = [AudioEvent(word="趴", t_start=1.0, t_end=1.2, kind="cue")]
    trials, unpaired = align(pose, audio, [RewardEvent(t=3.0, source="marker")], meta)
    assert len(trials) == 1
    t = trials[0]
    assert t.sit_start == 2.5 and t.hold == 6.5 and t.latency == 1.5 and t.ended_by == "stand_up"
    # 目标是坐时，同一段趴下不配
    trials2, _ = align(pose, audio, [], MetaInfo(cues=["趴"]))
    assert trials2 == []


def test_down_then_sit_counts_as_breaking():
    pose = [seg("stand", 0, 2), seg("down", 2.5, 9), seg("sit", 9, 12)]
    meta = MetaInfo(target_pose="down")
    trials, _ = align(pose, [AudioEvent(word="趴", t_start=1.0, t_end=1.2, kind="cue")], [], meta)
    assert trials[0].ended_by == "stand_up"
