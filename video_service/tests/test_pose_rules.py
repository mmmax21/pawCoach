"""B2 姿态规则单测：用合成关键点，不依赖 deeplabcut / pandas / 真实视频。"""

from __future__ import annotations

import numpy as np

from pawcoach.pose.rules import (
    Keypoints,
    PoseRules,
    absorb_short_runs,
    classify_frame,
    keypoints_to_segments,
    majority_vote,
)

NAMES = [
    "nose", "neck_base", "tail_base", "back_middle",
    "left_eye", "right_eye", "left_earbase", "right_earbase",
    "front_left_thai", "front_right_thai", "back_left_thai", "back_right_thai",
    "front_left_paw", "front_right_paw", "back_left_paw", "back_right_paw",
] + [f"pad{i}" for i in range(23)]  # 凑够 39 个点
IX = {n: i for i, n in enumerate(NAMES)}
SHORT_SIDE = 720.0


def make_frame(neck=(100.0, 100.0), tail=(100.0, 300.0), side_width=0.05, paw_y=None, conf=0.8):
    """合成一帧：体长 = neck 到 tail 的距离。左右关键点的水平间距 = 体长 * side_width。"""
    xy = np.zeros((len(NAMES), 2))
    xy[:] = neck
    xy[IX["neck_base"]] = neck
    xy[IX["tail_base"]] = tail
    body = float(np.hypot(tail[0] - neck[0], tail[1] - neck[1]))
    xy[IX["back_middle"]] = ((neck[0] + tail[0]) / 2, (neck[1] + tail[1]) / 2)
    gap = body * side_width
    for a, b in [("left_eye", "right_eye"), ("left_earbase", "right_earbase"),
                 ("front_left_thai", "front_right_thai"), ("back_left_thai", "back_right_thai"),
                 ("front_left_paw", "front_right_paw"), ("back_left_paw", "back_right_paw")]:
        xy[IX[a]] = (neck[0] - gap / 2, neck[1])
        xy[IX[b]] = (neck[0] + gap / 2, neck[1])
    if paw_y is not None:
        for p in ("front_left_paw", "front_right_paw", "back_left_paw", "back_right_paw"):
            xy[IX[p], 1] = paw_y
    return xy, np.full(len(NAMES), conf)


def classify(xy, conf, rules=None):
    return classify_frame(xy, conf, IX, SHORT_SIDE, rules or PoseRules())[0]


def test_sit_when_body_axis_vertical():
    # 臀部比颈部低一个体长（h≈1）：坐
    assert classify(*make_frame(neck=(100, 100), tail=(100, 300))) == "sit"


def test_stand_when_body_axis_horizontal_and_legs_long():
    # 体轴水平（h≈0），爪子在背部下方 0.8 个体长：站
    xy, conf = make_frame(neck=(100, 200), tail=(300, 200), paw_y=200 + 0.8 * 200)
    assert classify(xy, conf) == "stand"


def test_down_when_body_axis_horizontal_and_paws_close_to_back():
    # 体轴水平，爪子几乎和背部同高：趴（这条规则没有真实视频验证，这里只测逻辑）
    xy, conf = make_frame(neck=(100, 200), tail=(300, 200), paw_y=200 + 0.2 * 200)
    assert classify(xy, conf) == "down"


def test_frontal_view_is_unclear_by_default():
    # 左右间距超过体长的 0.4：正面或背面，看不出臀部高度，默认降级
    xy, conf = make_frame(neck=(100, 100), tail=(100, 300), side_width=0.8)
    assert classify(xy, conf) == "unclear"


def test_frontal_filter_can_be_turned_off():
    xy, conf = make_frame(neck=(100, 100), tail=(100, 300), side_width=0.8)
    assert classify(xy, conf, PoseRules(max_width_ratio=None)) == "sit"


def test_unclear_when_few_reliable_keypoints():
    xy, conf = make_frame()
    conf[:20] = 0.1
    assert classify(xy, conf) == "unclear"


def test_unclear_when_dog_too_small():
    # 体长只有画面短边的 3%
    xy, conf = make_frame(neck=(100, 100), tail=(100, 100 + 0.03 * SHORT_SIDE))
    assert classify(xy, conf) == "unclear"


def test_majority_vote_removes_single_frame_flicker():
    labels = ["sit"] * 10 + ["stand"] + ["sit"] * 10
    assert set(majority_vote(labels, 5)) == {"sit"}


def test_absorb_short_runs_merges_into_longer_neighbour():
    labels = ["sit"] * 20 + ["stand"] * 3 + ["sit"] * 10
    assert set(absorb_short_runs(labels, 5)) == {"sit"}


def test_absorb_keeps_long_runs():
    labels = ["sit"] * 20 + ["stand"] * 20
    assert absorb_short_runs(labels, 5) == labels


def test_absorb_single_run_does_not_loop():
    assert absorb_short_runs(["sit"] * 3, 15) == ["sit"] * 3


def test_segments_cover_whole_video_with_no_gap():
    fps = 30.0
    frames = [make_frame(tail=(100, 300))] * 60 + [make_frame(neck=(100, 200), tail=(300, 200), paw_y=360)] * 60
    kp = Keypoints(
        names=NAMES,
        xy=np.stack([f[0] for f in frames]),
        conf=np.stack([f[1] for f in frames]),
        fps=fps, width=1280, height=720,
    )
    segs = keypoints_to_segments(kp)
    assert [s.label for s in segs] == ["sit", "stand"]
    assert segs[0].t_start == 0.0
    assert abs(segs[-1].t_end - 120 / fps) < 1e-6
    for a, b in zip(segs, segs[1:]):
        assert abs(a.t_end - b.t_start) < 1e-6
    assert all(0.0 <= s.conf <= 1.0 for s in segs)
