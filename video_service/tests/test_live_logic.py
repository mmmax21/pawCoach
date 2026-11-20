"""实时计时的纯逻辑：声音起音检测、姿态防抖、轮次推导。不需要模型。"""

import numpy as np
import pytest

from pawcoach.live.timeline import build_trials
from pawcoach.live.tracker import Seg, StateTracker
from pawcoach.live.vad import SAMPLE_RATE, OnsetDetector

# ---------------------------------------------------------------- 声音起音 ----


def tone(t0, dur, amp=0.2, sr=SAMPLE_RATE):
    n = int(dur * sr)
    t = np.arange(n) / sr
    return t0, (amp * np.sin(2 * np.pi * 220 * t)).astype(np.float32)


def render(events, total, noise=0.002, seed=0):
    """events: [(起始秒, 时长, 振幅)]。返回整段音频。"""
    rng = np.random.default_rng(seed)
    x = noise * rng.standard_normal(int(total * SAMPLE_RATE)).astype(np.float32)
    for t0, dur, amp in events:
        _, y = tone(t0, dur, amp)
        a = int(t0 * SAMPLE_RATE)
        x[a:a + len(y)] += y
    return x


def run_vad(x, chunk_s=0.1, **kw):
    d = OnsetDetector(**kw)
    out = []
    step = int(chunk_s * SAMPLE_RATE)
    for a in range(0, len(x), step):
        out += d.feed(x[a:a + step], a / SAMPLE_RATE)
    return out, d


def test_vad_onset_error_within_50ms():
    x = render([(1.0, 0.4, 0.2), (4.3, 0.3, 0.2), (7.0, 0.5, 0.2)], 9.0)
    onsets, _ = run_vad(x)
    assert len(onsets) == 3
    for got, want in zip(onsets, [1.0, 4.3, 7.0]):
        assert abs(got - want) <= 0.05


def test_vad_merges_syllables_in_one_utterance():
    # "坐下"两个音节之间有 0.2 秒停顿：算一次
    x = render([(1.0, 0.25, 0.2), (1.45, 0.25, 0.2)], 4.0)
    onsets, _ = run_vad(x)
    assert len(onsets) == 1


def test_vad_two_cues_one_second_apart_are_two():
    x = render([(1.0, 0.3, 0.2), (2.2, 0.3, 0.2)], 4.0)
    onsets, _ = run_vad(x)
    assert len(onsets) == 2


def test_vad_warmup_learns_the_room_noise_instead_of_reporting_it():
    x = render([(2.0, 0.4, 0.3)], 5.0, noise=0.01)   # 房间底噪约 -40 dBFS
    onsets, _ = run_vad(x)
    assert len(onsets) == 1 and abs(onsets[0] - 2.0) <= 0.05


def test_vad_ignores_steady_noise_and_short_clicks():
    # 持续底噪稍大 + 一个 20 毫秒的咔嗒：都不算出声
    x = render([(2.0, 0.02, 0.5)], 5.0, noise=0.01)
    onsets, _ = run_vad(x)
    assert onsets == []


def test_vad_chunk_size_does_not_change_result():
    x = render([(1.0, 0.4, 0.2), (3.0, 0.3, 0.2)], 5.0)
    a, _ = run_vad(x, chunk_s=0.1)
    b, _ = run_vad(x, chunk_s=0.037)   # 不是帧长整数倍：测残余采样拼接
    assert len(a) == len(b) == 2
    assert all(abs(p - q) <= 0.021 for p, q in zip(a, b))


def test_vad_survives_dropped_chunk():
    x = render([(1.0, 0.4, 0.2), (6.0, 0.4, 0.2)], 8.0)
    d = OnsetDetector()
    out = []
    step = int(0.1 * SAMPLE_RATE)
    for a in range(0, len(x), step):
        if 30 <= a // step < 35:      # 丢掉 0.5 秒
            continue
        out += d.feed(x[a:a + step], a / SAMPLE_RATE)
    assert len(out) == 2 and abs(out[1] - 6.0) <= 0.05


# ---------------------------------------------------------------- 姿态防抖 ----


def feed_labels(tr, spec, fps=5.0):
    """spec: [(起始秒, 结束秒, 标签)]"""
    for a, b, lab in spec:
        t = a
        while t < b - 1e-9:
            tr.push(round(t, 3), lab)
            t += 1 / fps


def test_tracker_sit_start_is_backdated_to_first_sit_frame():
    tr = StateTracker()
    feed_labels(tr, [(0, 2.0, "stand"), (2.0, 5.0, "sit")])
    sits = tr.sit_segments()
    assert len(sits) == 1
    assert sits[0].start == pytest.approx(2.0, abs=0.01)   # 不是确认时刻 2.6
    assert sits[0].end is None


def test_tracker_single_bad_frame_does_not_flip():
    tr = StateTracker()
    feed_labels(tr, [(0, 3.0, "sit"), (3.0, 3.2, "stand"), (3.2, 6.0, "sit")])
    sits = tr.sit_segments()
    assert len(sits) == 1 and sits[0].end is None


def test_tracker_standup_ends_the_sit_at_first_stand_frame():
    tr = StateTracker()
    feed_labels(tr, [(0, 4.0, "sit"), (4.0, 7.0, "stand")])
    s = tr.sit_segments()[0]
    assert s.end == pytest.approx(4.0, abs=0.01)


def test_tracker_unclear_does_not_break_a_sit_but_timeout_does():
    tr = StateTracker()
    feed_labels(tr, [(0, 3.0, "sit"), (3.0, 4.0, "unclear"), (4.0, 6.0, "sit")])
    assert len(tr.sit_segments()) == 1 and tr.sit_segments()[0].end is None
    tr2 = StateTracker()
    feed_labels(tr2, [(0, 3.0, "sit"), (3.0, 7.0, "unclear")])
    assert tr2.state is None            # 看不清超过 2 秒：状态置空
    assert tr2.sit_segments()[0].end == pytest.approx(2.8, abs=0.01)


def test_tracker_down_counts_as_stand():
    tr = StateTracker()
    feed_labels(tr, [(0, 2.0, "sit"), (2.0, 5.0, "down")])
    assert tr.state == "stand"


# ---------------------------------------------------------------- 轮次推导 ----


def sit(a, b=None):
    return Seg("sit", a, b)


def test_cue_then_sit_then_reward_in_time():
    trials, pending = build_trials([sit(2.0, 6.0)], onsets=[0.8, 2.3], taps=[])
    assert pending == []
    t = trials[0]
    assert t.cue_times == [0.8] and t.reward_t == 2.3 and t.reward_src == "voice"
    assert t.reward_delay == pytest.approx(0.3)
    assert t.latency == pytest.approx(1.2)


def test_reward_two_seconds_late_is_measured():
    trials, _ = build_trials([sit(2.0, 8.0)], onsets=[0.8, 4.3], taps=[])
    assert trials[0].reward_delay == pytest.approx(2.3)


def test_repeated_cue_before_sit_is_counted():
    trials, _ = build_trials([sit(10.5, 14.5)], onsets=[8.0, 9.4, 12.6], taps=[])
    t = trials[0]
    assert t.cue_times == [8.0, 9.4]
    assert t.reward_t == 12.6


def test_tap_beats_voice_and_does_not_need_a_microphone():
    trials, _ = build_trials([sit(2.0, 6.0)], onsets=[0.8], taps=[3.1])
    assert trials[0].reward_src == "tap" and trials[0].reward_delay == pytest.approx(1.1)


def test_late_voice_after_standup_is_reward_not_next_cue():
    # 狗 6.0 起身，主人 6.4 才说"好"；下一次口令在 9.0
    trials, pending = build_trials([sit(2.0, 6.0), sit(11.0, 15.0)], onsets=[0.8, 6.4, 9.0, 11.3], taps=[])
    assert trials[0].reward_t == 6.4 and trials[0].reward_src == "voice_late"
    assert trials[1].cue_times == [9.0]


def test_holding_voice_counts_as_markers_not_a_new_cue():
    # 2.3 是奖励；保持期间又出声 5.0、8.0 两次：算 2 次保持期标记词，不另起一轮
    trials, pending = build_trials([sit(2.0, 12.0)], onsets=[0.8, 2.3, 5.0, 8.0], taps=[])
    assert len(trials) == 1 and pending == []
    assert trials[0].reward_t == 2.3
    assert trials[0].markers_during_hold == 3   # 2.3 本身也在坐着的区间里，一起计入


def test_cue_after_last_standup_is_pending():
    trials, pending = build_trials([sit(2.0, 6.0)], onsets=[0.8, 2.3, 9.0], taps=[])
    assert pending == [9.0]


def test_sit_without_cue_is_not_a_trial():
    trials, _ = build_trials([sit(2.0, 6.0)], onsets=[], taps=[])
    assert trials == []


def test_events_arriving_out_of_order_give_same_result():
    a = build_trials([sit(2.0, 6.0)], onsets=[0.8, 4.3], taps=[])
    b = build_trials([sit(2.0, 6.0)], onsets=[4.3, 0.8], taps=[])
    assert a[0][0].reward_delay == b[0][0].reward_delay == pytest.approx(2.3)


def test_tracker_two_sits_separated_by_unclear_do_not_merge():
    """站姿被判成"看不清"时（狗侧身或被遮挡），第二次坐下不能被倒推并进第一次。"""
    tr = StateTracker()
    feed_labels(tr, [(0, 4.0, "sit"), (4.0, 9.0, "unclear"), (9.0, 13.0, "sit")])
    sits = tr.sit_segments()
    assert len(sits) == 2
    assert sits[0].end == pytest.approx(3.8, abs=0.01)
    assert sits[1].start == pytest.approx(9.0, abs=0.01)


def test_tracker_sit_flickering_with_unclear_still_confirms():
    tr = StateTracker()
    labs = ["sit", "unclear", "sit", "unclear", "unclear", "sit", "sit", "unclear", "sit"]
    for k, l in enumerate(labs):
        tr.push(k * 0.2, l)
    assert tr.state == "sit" and tr.sit_segments()[0].start == pytest.approx(0.0)


def test_instant_reward_right_after_sit_is_reward_not_a_second_cue():
    """响片在屁股碰地后 0.2 秒内按下是正确做法。它不能被数成"口令重复"，更不能被算成奖励晚。"""
    trials, _ = build_trials([sit(2.0, 6.0)], onsets=[0.8, 2.2, 5.3], taps=[])
    t = trials[0]
    assert t.cue_times == [0.8]
    assert t.reward_t == 2.2 and t.reward_delay == pytest.approx(0.2)
    assert t.markers_during_hold == 2          # 奖励 2.2 与释放 5.3


def test_sound_just_before_sit_start_within_tolerance_is_reward():
    trials, _ = build_trials([sit(2.0, 6.0)], onsets=[0.8, 1.95], taps=[])
    assert trials[0].cue_times == [0.8] and trials[0].reward_t == 1.95


def test_sound_clearly_before_sit_start_is_still_a_cue():
    trials, _ = build_trials([sit(2.0, 6.0)], onsets=[0.8, 1.7, 2.5], taps=[])
    assert trials[0].cue_times == [0.8, 1.7] and trials[0].reward_t == 2.5


def test_tracker_stray_frames_do_not_keep_a_sit_alive_after_the_dog_leaves():
    """狗出画后，画面边缘零星的"站"和"坐"杂帧不能刷新超时计时（dog3 实拍复现）。"""
    tr = StateTracker()
    feed_labels(tr, [(0, 2.0, "sit"), (2.0, 2.6, "unclear")])
    tr.push(2.6, "stand")                         # 杂帧：单帧站，不足以切换
    feed_labels(tr, [(2.8, 4.8, "unclear")])
    tr.push(4.8, "sit")                           # 杂帧：单帧坐
    feed_labels(tr, [(5.0, 6.0, "stand")])
    s = tr.sit_segments()[0]
    assert s.end is not None and s.end == pytest.approx(1.8, abs=0.01)   # 最后一次真看到坐的那一帧
    assert len(tr.sit_segments()) == 1


def test_skipped_sit_without_cue_does_not_leak_its_sounds_into_next_trial_as_cues():
    """第一次坐下没有口令（被跳过）。它里面的声音不能被后面一轮当成口令。"""
    trials, pending = build_trials([sit(2.0, 8.0), sit(14.0, 18.0)], onsets=[2.4, 6.5, 12.0, 14.3], taps=[])
    assert len(trials) == 1
    assert trials[0].cue_times == [12.0]           # 不是 [2.4, 6.5, 12.0]
    assert trials[0].reward_t == 14.3


# ---------------------------------------------------------------- 会话快照 ----


def _session_at(now, sit_at=2.0, onsets=(0.8,), late=1.0, fps=5.0):
    """模拟到 now 秒：狗在 sit_at 坐下，帧一直喂到 now（和真实使用一样，快照里的"现在"就是最新一帧）。"""
    from pawcoach.live.session import LiveSession

    s = LiveSession(late_sec=late)
    t = 0.0
    while t <= now + 1e-9:
        s.on_frame(round(t, 3), "sit" if t >= sit_at else "stand", (0.1, 0.4, 0.9, 0.8))
        t += 1 / fps
    s.onsets.extend(onsets)
    return s


def test_snapshot_hint_is_a_code_never_prose():
    # 坐下 2.0；确认要 0.6 秒，所以 2.4 秒时还没开始计时
    assert _session_at(2.4).snapshot().live_trial is None
    s = _session_at(3.0)                                   # 已确认，坐了 1.0 秒但还没奖励
    snap = s.snapshot()
    assert snap.live_trial["waiting_reward"] and snap.hint in ("reward_due", "reward_late")
    snap = _session_at(3.6).snapshot()                     # 等了约 1.6 秒：超过阈值
    assert snap.hint == "reward_late"
    # 起点精度是一帧（5 帧每秒 = 0.2 秒）：浮点累加的时间戳可能把 2.0 记成 2.2
    assert snap.live_trial["running_delay"] == pytest.approx(1.6, abs=0.25)
    assert snap.live_trial["late"] is True
    assert snap.hint.isascii()                             # 是代码，不含中文文字


def test_snapshot_reward_due_comes_before_reward_late():
    hints = []
    for now in (2.8, 3.0, 3.2, 3.6):
        hints.append(_session_at(now).snapshot().hint)
    assert hints[0] in (None, "reward_due") and hints[-1] == "reward_late"
    # 一旦变成 late 就不会退回 due
    assert hints.index("reward_late") >= hints.index("reward_due") if "reward_due" in hints else True


def test_late_reward_hint_outranks_repeated_cue_but_count_stays_visible():
    s = _session_at(5.0, sit_at=3.0, onsets=(0.6, 1.9))    # 坐下 2 秒了还没奖励，口令也重复了
    snap = s.snapshot()
    assert snap.hint == "reward_late"
    assert snap.live_trial["cue_count"] == 2               # 口令次数不因提示让位而丢失


def test_snapshot_repeated_cue_hint_and_reward_clears_it():
    s = _session_at(3.6, sit_at=3.0, onsets=(0.6, 1.9))    # 刚确认坐下（约 0.4 秒），还没到该提醒奖励的时候
    assert s.snapshot().hint == "cue_repeated"
    assert s.snapshot().live_trial["cue_count"] == 2
    s = _session_at(4.0, sit_at=3.0, onsets=(0.6, 1.9, 3.1))   # 坐下后立刻奖励
    snap = s.snapshot()
    assert snap.live_trial["reward_delay"] == pytest.approx(0.1, abs=0.15)
    assert snap.live_trial["late"] is False and snap.live_trial["waiting_reward"] is False


def test_result_shape_matches_offline_fields_the_app_reads():
    s = _session_at(6.0, onsets=(0.8, 4.4))
    r = s.result()
    t = r["trials"][0]
    for key in ("cue_t", "sit_start", "sit_end", "reward_t", "latency", "hold", "cue_times",
                "markers_during_hold", "corrections", "reliable", "ended_by"):
        assert key in t
    assert t["reward_t"] == 4.4 and t["cue_source"] == "onset"
    assert {"dog_visible_ratio", "audio_ok", "unclear_ratio", "asr"} <= set(r["quality"])


def test_result_cue_times_include_the_first_cue_like_offline():
    """离线 align() 的 cue_times 含第一次口令，App 的 repeated_cue 用 cue_times 的个数判。"""
    one = _session_at(6.0, onsets=(0.8, 2.2)).result()["trials"][0]
    assert one["cue_times"] == [0.8] and one["cue_t"] == 0.8
    two = _session_at(7.0, sit_at=3.0, onsets=(0.6, 1.9, 3.2)).result()["trials"][0]
    assert two["cue_times"] == [0.6, 1.9] and len(two["cue_times"]) >= 2   # 阈值 threshold_count=2
