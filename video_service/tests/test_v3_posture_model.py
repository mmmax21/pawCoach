"""v3 多角度姿态分类器：特征与合用规则（不依赖训练好的模型文件）。"""

import numpy as np

from pawcoach.pose.posture_model import IX, NAMES, PostureRead, features, flip_kp, kp_in_model_order, rotate_kp
from pawcoach.pose.rules import PoseRules, _hybrid


def fake_kp(seed=0):
    rng = np.random.default_rng(seed)
    kp = np.zeros((len(NAMES), 3))
    kp[:, 0] = rng.uniform(100, 300, len(NAMES))
    kp[:, 1] = rng.uniform(100, 400, len(NAMES))
    kp[:, 2] = 0.9
    return kp


def test_feature_length_stable_and_finite():
    a, b = features(fake_kp(0)), features(fake_kp(1))
    assert a.shape == b.shape and np.isfinite(a).all()


def test_rotation_invariant_part_unchanged_under_rotation():
    kp = fake_kp(2)
    f0 = features(kp)
    f1 = features(rotate_kp(kp, (200, 250), 73))
    # 末尾的两两距离 + 关节角与旋转无关
    n_inv = 18 * 17 // 2 + 10
    assert np.allclose(f0[-n_inv:], f1[-n_inv:], atol=1e-4)


def test_flip_swaps_sides():
    kp = fake_kp(3)
    fl = flip_kp(kp, 400)
    assert np.isclose(fl[IX["left_eye"], 0], 400 - kp[IX["right_eye"], 0])
    assert np.allclose(flip_kp(fl, 400), kp)


def test_model_order_mapping():
    names = list(reversed(NAMES))
    xy = np.arange(len(NAMES) * 2, dtype=float).reshape(-1, 2)
    conf = np.full(len(NAMES), 0.8)
    out = kp_in_model_order(xy, conf, names)
    assert np.allclose(out[IX["nose"], :2], xy[names.index("nose")])


class FakeModel:
    def __init__(self, label, prob):
        self.r = PostureRead(label, prob, {label: prob})

    def predict(self, kp):
        return self.r


def test_hybrid_rules():
    xy = np.zeros((len(NAMES), 2))
    conf = np.full(len(NAMES), 0.7)
    r = PoseRules()
    assert _hybrid("sit", 0.5, xy, conf, NAMES, FakeModel("down", 0.99), r)[0] == "sit"       # 侧面判坐不改
    assert _hybrid("unclear", 0.5, xy, conf, NAMES, FakeModel("sit", 0.7), r)[0] == "sit"      # 规则判不了 → 用模型
    assert _hybrid("unclear", 0.5, xy, conf, NAMES, FakeModel("unclear", 0.4), r)[0] == "unclear"
    assert _hybrid("stand", 0.5, xy, conf, NAMES, FakeModel("down", 0.9), r)[0] == "down"      # 高概率改判站/趴
    assert _hybrid("stand", 0.5, xy, conf, NAMES, FakeModel("down", 0.7), r)[0] == "stand"
    assert _hybrid("stand", 0.5, xy, conf, NAMES, FakeModel("sit", 0.99), r)[0] == "stand"     # 站不改成坐
    assert _hybrid("down", 0.5, xy, conf, NAMES, FakeModel("unclear", 0.5), r)[0] == "unclear"  # 规则判趴要分类器确认
    assert _hybrid("down", 0.5, xy, conf, NAMES, FakeModel("down", 0.7), r)[0] == "down"


def test_bridge_unclear():
    from pawcoach.pose.rules import bridge_unclear

    L = ["sit"] * 3 + ["unclear"] * 2 + ["sit"] * 3 + ["unclear"] * 5 + ["sit"] * 2 + ["unclear"] * 2 + ["stand"]
    out = bridge_unclear(L, 3)
    assert out[3:5] == ["sit", "sit"]              # 短空档、两边都是坐 → 填上
    assert out[8:13] == ["unclear"] * 5            # 太长 → 不填
    assert out[15:17] == ["unclear"] * 2           # 两边姿势不同 → 不填
    assert bridge_unclear(L, 0) == L
