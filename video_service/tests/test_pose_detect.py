"""B3 狗检测后处理单测：选主狗、补短空洞、贴边小框。纯 numpy，不依赖 ultralytics。"""

from __future__ import annotations

import numpy as np

from pawcoach.pose.detect import in_frame_mask, iou, select_main_dog, visible_mask
from pawcoach.pose.rules import Keypoints, keypoints_to_segments

BOX_A = (100.0, 100.0, 300.0, 400.0)
BOX_B = (500.0, 100.0, 700.0, 400.0)


def test_iou_identical_and_disjoint():
    assert iou(np.array(BOX_A), np.array(BOX_A)) == 1.0
    assert iou(np.array(BOX_A), np.array(BOX_B)) == 0.0


def test_select_main_dog_picks_biggest_when_no_history():
    small = (0.9, (0.0, 0.0, 50.0, 50.0))
    big = (0.8, BOX_A)
    track = select_main_dog([[small, big]])
    assert tuple(track[0, 1:]) == BOX_A


def test_select_main_dog_follows_same_dog_by_iou():
    # 第二帧出现一个更大更自信的框，但位置离主狗很远：应继续跟原来的狗
    first = [(0.8, BOX_A)]
    second = [(0.95, (400.0, 0.0, 800.0, 700.0)), (0.6, (105.0, 100.0, 305.0, 400.0))]
    track = select_main_dog([first, second])
    assert tuple(track[1, 1:]) == (105.0, 100.0, 305.0, 400.0)


def test_select_main_dog_drops_low_conf_boxes():
    track = select_main_dog([[(0.1, BOX_A)]])
    assert np.isnan(track[0, 0])


def test_select_main_dog_keeps_identity_across_short_miss():
    # 中间一帧没检测到，之后同一位置的框仍然接上，不被另一只更大的狗抢走
    frames = [[(0.8, BOX_A)], [], [(0.9, (400.0, 0.0, 800.0, 700.0)), (0.7, BOX_A)]]
    track = select_main_dog(frames)
    assert tuple(track[2, 1:]) == BOX_A


def _track(present: list[bool], box=BOX_A) -> np.ndarray:
    t = np.full((len(present), 5), np.nan)
    for i, p in enumerate(present):
        if p:
            t[i] = (0.8, *box)
    return t


def test_visible_mask_fills_short_gap_only():
    # 空 3 帧（0.1s）补上，空 30 帧（1s）不补
    short = visible_mask(_track([True] * 5 + [False] * 3 + [True] * 5), fps=30.0)
    assert short.all()
    long = visible_mask(_track([True] * 5 + [False] * 30 + [True] * 5), fps=30.0)
    assert long[:5].all() and long[-5:].all() and not long[5:35].any()


def test_visible_mask_does_not_extend_before_first_or_after_last():
    m = visible_mask(_track([False] * 4 + [True] * 4 + [False] * 4), fps=30.0)
    assert m.tolist() == [False] * 4 + [True] * 4 + [False] * 4


def test_in_frame_mask_drops_small_box_touching_edge():
    # 画面 400x700；贴左边、面积只有画面的 3% → 狗只露出一角
    corner = (0.0, 300.0, 60.0, 400.0)
    m = in_frame_mask(_track([True] * 5, corner), fps=30.0, width=400, height=700)
    assert not m.any()


def test_in_frame_mask_keeps_big_box_touching_edge():
    # 贴左边但面积 > 8%：整只狗，只是靠边站
    big = (0.0, 200.0, 200.0, 500.0)
    m = in_frame_mask(_track([True] * 5, big), fps=30.0, width=400, height=700)
    assert m.all()


def test_in_frame_mask_does_not_fill_gap_with_truncated_boxes():
    # 贴边小框先剔掉再补洞：露出一角的零星几帧不能被「补洞」补成一整段在画面里
    corner = (0.0, 300.0, 60.0, 400.0)
    t = _track([True, False, False, True, False, False, True], corner)
    m = in_frame_mask(t, fps=30.0, width=400, height=700)
    assert not m.any()


def _sitting_keypoints(n_frames: int) -> Keypoints:
    """合成关键点：体轴竖直（h=1），左右间距很小，39 个点都可靠 → 规则判 sit。"""
    names = [
        "neck_base", "tail_base", "back_middle",
        "left_eye", "right_eye", "left_earbase", "right_earbase",
        "front_left_thai", "front_right_thai", "back_left_thai", "back_right_thai",
        "front_left_paw", "front_right_paw", "back_left_paw", "back_right_paw",
    ] + [f"pad{i}" for i in range(24)]  # 共 39 个点
    xy = np.zeros((n_frames, len(names), 2))
    xy[:, :, :] = (100.0, 100.0)
    xy[:, 1] = (100.0, 300.0)   # tail_base 在 neck_base 正下方 200 像素
    xy[:, 2] = (100.0, 200.0)
    return Keypoints(names=names, xy=xy, conf=np.full((n_frames, len(names)), 0.8), fps=30.0, width=1280, height=720)


def test_in_frame_forces_unclear_in_segments():
    # 关键点说「坐」，但检测说狗不在画面：以检测为准，整段 unclear
    kp = _sitting_keypoints(60)
    assert [s.label for s in keypoints_to_segments(kp)] == ["sit"]
    none_in_frame = np.zeros(60, dtype=bool)
    assert [s.label for s in keypoints_to_segments(kp, in_frame=none_in_frame)] == ["unclear"]
    half = np.array([True] * 30 + [False] * 30)
    assert [s.label for s in keypoints_to_segments(kp, in_frame=half)] == ["sit", "unclear"]
