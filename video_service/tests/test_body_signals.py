"""身体信号：用合成关键点检查每种信号的判定（不跑模型）。"""

import numpy as np

from pawcoach.body.signals import counts, frame_signals, summarize
from pawcoach.pose.posture_model import IX, NAMES


def dog(tail=(-0.3, 0.2), leg=1.2, mouth=0.1, ear=0.3, shift=(0.0, 0.0)):
    """侧面站立的狗：头朝右。tail=(沿身体轴往前, 往上) / L；leg = 爪到背的高度 / L。"""
    kp = np.zeros((len(NAMES), 3))
    L = 100.0
    base = np.array([200.0, 200.0]) + shift
    def put(n, x, y):
        kp[IX[n], :2] = base + (x, y)
        kp[IX[n], 2] = 0.9
    put("tail_base", 0, 0); put("neck_base", L, 0); put("back_middle", L / 2, 0)
    put("tail_end", tail[0] * L, -tail[1] * L)
    for p in ("front_left_paw", "front_right_paw", "back_left_paw", "back_right_paw"):
        put(p, L / 2, leg * L)
    put("nose", L * 1.5, -20); put("upper_jaw", L * 1.45, -15)
    put("lower_jaw", L * 1.45, -15 + mouth * np.hypot(L * 0.5, 20))
    for s in ("left", "right"):
        put(f"{s}_earbase", L * 1.2, -30); put(f"{s}_earend", L * 1.2, -30 - ear * np.hypot(L * 0.5, 20))
    return kp


def test_frame_signals():
    f = frame_signals(dog(tail=(0.8, -0.2)), 0, "stand")
    assert f.tail_tucked and not f.tail_high
    f = frame_signals(dog(tail=(-0.2, 0.7)), 0, "stand")
    assert f.tail_high and not f.tail_tucked
    assert frame_signals(dog(leg=0.5), 0, "stand").body_low
    assert not frame_signals(dog(leg=1.2), 0, "stand").body_low
    # 不是侧面：不判尾巴和身体高低
    f = frame_signals(dog(tail=(0.8, -0.2), leg=0.5), 0, "stand", side_view=False)
    assert f.tail_tucked is None and f.body_low is None
    assert abs(frame_signals(dog(mouth=0.5), 0).mouth_open - 0.5) < 0.02


def seq(make, n=30, fps=5.0, posture="stand"):
    return [frame_signals(make(i), i / fps, posture) for i in range(n)]


def test_panting_yawn_wag_motion_freeze():
    s = summarize(seq(lambda i: dog(mouth=0.5 if i % 2 else 0.45)))
    assert counts(s).get("panting") == 1
    s = summarize(seq(lambda i: dog(mouth=0.8 if 10 <= i < 15 else 0.1)))
    assert counts(s).get("yawn") == 1 and "panting" not in counts(s)
    s = summarize(seq(lambda i: dog(tail=(-0.3, 0.3 if i % 2 else -0.1))))
    assert counts(s).get("tail_wag", 0) >= 1
    s = summarize(seq(lambda i: dog(shift=(i * 40.0, 0))))      # 每帧 0.4 L，5 帧/秒 = 2 L/秒
    assert counts(s).get("high_motion") == 1 and s.metrics["motion_mean"] > 1.5
    s = summarize(seq(lambda i: dog(tail=(0.8, -0.2))))          # 不动 + 夹尾巴
    assert counts(s).get("freeze") == 1 and counts(s).get("tail_tucked") == 1
    s = summarize(seq(lambda i: dog()))                          # 平静站着：什么都没有
    assert counts(s) == {}


def test_ears_relative_to_own_median():
    s = summarize(seq(lambda i: dog(ear=-0.1 if 15 <= i < 25 else 0.4)))
    assert counts(s).get("ears_drop") == 1


def test_live_session_body_counts():
    from pawcoach.live.session import LiveSession

    sess = LiveSession()
    for i in range(40):  # 8 秒，5 帧/秒，第 2–4 秒打哈欠
        t = i / 5
        sess.on_frame(t, "sit", (0.1, 0.1, 0.5, 0.5))
        sess.on_body(frame_signals(dog(mouth=0.8 if 10 <= i < 15 else 0.1), t, "sit"))
    snap = sess.snapshot().to_dict()
    assert snap["body"]["counts"].get("yawn") == 1
    res = sess.result()
    assert res["body"]["kind"] == "live" and any(s["id"] == "yawn" for s in res["body"]["signals"])
