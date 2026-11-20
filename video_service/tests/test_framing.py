"""取景自检（pawcoach/framing.py 与 POST /frame-check）。

判定逻辑是纯函数，用构造的检测框测；接口用替身检测器测，不依赖 ultralytics。
真实视频帧的检出率与延迟见 handoffs/2026-11-19-video-correction-v2.md，不在单测里跑。
"""

from __future__ import annotations

import io
import json

import numpy as np
import pytest
from fastapi.testclient import TestClient

from app.main import app
from pawcoach import framing
from pawcoach.framing import (
    SPECS,
    Detection,
    inside_fraction,
    iou,
    judge_frame,
    pick_main_dog,
    smooth_levels,
)

# 两种机位都按竖屏取景
W, H = 360, 640


def _px(box):
    return (box[0] * W, box[1] * H, box[2] * W, box[3] * H)


def _dog_in_guide(view="side", shrink=0.04):
    x1, y1, x2, y2 = SPECS[view].guide
    return [Detection(0.8, _px((x1 + shrink, y1 + shrink, x2 - shrink, y2 - shrink)))]


def _person():
    return [Detection(0.8, _px((0.02, 0.02, 0.30, 0.40)))]


class TestJudge:
    @pytest.mark.parametrize("view", ["side", "top"])
    def test_dog_inside_guide_with_person_is_green(self, view):
        v = judge_frame(view, W, H, _dog_in_guide(view), _person())
        assert v.level == "green", v.reasons
        assert v.reasons == []
        assert v.inside == pytest.approx(1.0)
        assert all(0 <= c <= 1 for c in v.dog_box)

    def test_sitting_dog_is_green_not_misaligned(self):
        # 坐姿：比站姿窄、比站姿高，只占引导框的一部分但整个在框里。
        # 不能因为"形状不像引导框"被判没对准。宽高比按实测坐姿取 ~0.6（实测中位 0.77、p10 0.48，见方案文档）
        x1, y1, x2, y2 = SPECS["side"].guide
        cx = (x1 + x2) / 2
        dog = [Detection(0.8, _px((cx - 0.21, y1 + 0.01, cx + 0.21, y2 - 0.01)))]
        v = judge_frame("side", W, H, dog, _person())
        assert v.level == "green", (v.reasons, v.inside)
        assert v.inside == pytest.approx(1.0)

    def test_standing_dog_is_green(self):
        x1, y1, x2, y2 = SPECS["side"].guide
        dog = [Detection(0.8, _px((x1 + 0.02, y1 + 0.12, x2 - 0.02, y2 - 0.02)))]
        v = judge_frame("side", W, H, dog, _person())
        assert v.level == "green", (v.reasons, v.inside)

    def test_no_dog_is_red(self):
        v = judge_frame("side", W, H, [], _person())
        assert v.level == "red" and v.reasons == ["no_dog"]
        assert v.message == framing.MESSAGES["no_dog"]

    def test_low_confidence_dog_is_ignored(self):
        v = judge_frame("side", W, H, [Detection(0.1, _dog_in_guide()[0].box)], _person())
        assert v.reasons == ["no_dog"]

    def test_dog_touching_edge_is_cut_and_red(self):
        dog = [Detection(0.8, (0.0, 0.40 * H, 0.5 * W, 0.80 * H))]
        v = judge_frame("side", W, H, dog, _person())
        assert v.level == "red" and "dog_cut" in v.reasons
        assert "截断" in v.message

    def test_dog_too_small_is_red_and_says_closer(self):
        x1, y1, x2, y2 = SPECS["side"].guide
        cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
        dog = [Detection(0.8, _px((cx - 0.06, cy - 0.05, cx + 0.06, cy + 0.05)))]
        v = judge_frame("side", W, H, dog, _person())
        assert v.level == "red" and "dog_small" in v.reasons
        assert "靠近" in v.message

    def test_dog_too_big_is_red_and_says_back_off(self):
        dog = [Detection(0.8, (0.02 * W, 0.05 * H, 0.98 * W, 0.95 * H))]
        v = judge_frame("side", W, H, dog, _person())
        assert v.level == "red" and "dog_big" in v.reasons
        assert "退后" in v.message

    def test_dog_far_from_guide_is_red_misaligned(self):
        # 尺寸合适，但整个在画面最上方，和放狗的区域几乎不重叠
        dog = [Detection(0.8, _px((0.20, 0.03, 0.80, 0.20)))]
        v = judge_frame("side", W, H, dog, _person())
        assert v.level == "red" and "misaligned" in v.reasons, (v.reasons, v.inside)
        assert v.message == framing.MESSAGES["misaligned"]

    def test_partly_outside_guide_is_yellow(self):
        # 狗框约一半在引导框外，居中偏出：inside 落在黄灯区间
        x1, y1, x2, y2 = SPECS["side"].guide
        dog = [Detection(0.8, _px((x1 + 0.05, y2 - 0.18, x2 - 0.05, y2 + 0.13)))]
        v = judge_frame("side", W, H, dog, _person())
        assert v.level == "yellow", (v.reasons, v.inside)
        assert v.reasons == ["misaligned_slight"]
        assert SPECS["side"].min_inside_yellow <= v.inside < SPECS["side"].min_inside_green

    def test_missing_person_is_yellow_not_red(self):
        v = judge_frame("side", W, H, _dog_in_guide(), [])
        assert v.level == "yellow" and v.reasons == ["no_person"]
        assert "主人" in v.message

    def test_wrong_orientation_is_only_a_hint_not_a_block(self):
        # 横屏画面：方向只提示，不拦。其余合格时是黄灯，不是红灯
        LW, LH = 640, 360
        x1, y1, x2, y2 = SPECS["side"].guide
        dog = [Detection(0.8, (x1 * LW + 20, y1 * LH + 10, x2 * LW - 20, y2 * LH - 10))]
        v = judge_frame("side", LW, LH, dog, [Detection(0.8, (5, 5, 100, 150))])
        assert "wrong_orientation" in v.reasons
        assert v.level != "red", v.reasons

    def test_wrong_orientation_never_hides_a_harder_problem(self):
        v = judge_frame("side", 640, 360, [], [])
        assert v.level == "red" and v.reasons == ["wrong_orientation", "no_dog"]
        assert v.message == framing.MESSAGES["no_dog"]

    def test_realistic_sitting_aspect_range_does_not_trigger_odd_aspect(self):
        # 像素宽高比 0.5 / 0.62 / 0.78 都是实测坐姿范围，不应该触发"轮廓异常"
        x1, y1, x2, y2 = SPECS["side"].guide
        cx = (x1 + x2) / 2
        hpx = (y2 - y1 - 0.02) * H
        for aspect in (0.5, 0.62, 0.78):
            half = aspect * hpx / W / 2
            dog = [Detection(0.8, _px((cx - half, y1 + 0.01, cx + half, y2 - 0.01)))]
            v = judge_frame("side", W, H, dog, _person())
            assert "bad_aspect" not in v.reasons, (aspect, v.reasons)

    def test_extremely_thin_box_is_flagged_odd_aspect(self):
        dog = [Detection(0.8, _px((0.48, 0.30, 0.52, 0.90)))]
        v = judge_frame("side", W, H, dog, _person())
        assert "bad_aspect" in v.reasons

    def test_message_is_single_instruction_by_priority(self):
        dog = [Detection(0.8, (0.0, 0.40 * H, 0.5 * W, 0.80 * H))]
        v = judge_frame("side", W, H, dog, [])
        assert {"dog_cut", "no_person"} <= set(v.reasons)
        assert v.message == framing.MESSAGES["dog_cut"]

    def test_picks_main_dog_among_candidates(self):
        stray = Detection(0.9, _px((0.0, 0.0, 0.05, 0.05)))  # 角落里一个很小的误检
        v = judge_frame("side", W, H, [stray, *_dog_in_guide()], _person())
        assert v.level == "green", v.reasons

    def test_to_dict_is_json_ready(self):
        d = judge_frame("side", W, H, _dog_in_guide(), _person()).to_dict()
        json.dumps(d)
        assert set(d) == {"level", "message", "reasons", "dog_box", "person_box", "guide", "inside"}

    def test_guides_are_sane(self):
        for spec in SPECS.values():
            x1, y1, x2, y2 = spec.guide
            assert 0 <= x1 < x2 <= 1 and 0 <= y1 < y2 <= 1
            assert spec.min_inside_yellow < spec.min_inside_green <= 1
            assert spec.dog_width_range[0] < spec.dog_width_range[1] <= 1


class TestHelpers:
    def test_iou_basic(self):
        assert iou((0, 0, 10, 10), (0, 0, 10, 10)) == pytest.approx(1.0)
        assert iou((0, 0, 10, 10), (20, 20, 30, 30)) == 0.0
        assert iou((0, 0, 10, 10), (5, 0, 15, 10)) == pytest.approx(1 / 3)

    def test_inside_fraction(self):
        r = (0.0, 0.0, 0.5, 0.5)
        assert inside_fraction((0.1, 0.1, 0.3, 0.3), r) == pytest.approx(1.0)
        assert inside_fraction((0.4, 0.0, 0.6, 0.5), r) == pytest.approx(0.5)
        assert inside_fraction((0.6, 0.6, 0.9, 0.9), r) == 0.0
        assert inside_fraction((0.3, 0.3, 0.3, 0.3), r) == 0.0  # 零面积不除零

    def test_pick_main_dog_prefers_large_confident_box(self):
        small = Detection(0.9, (0, 0, 10, 10))
        big = Detection(0.6, (0, 0, 100, 100))
        assert pick_main_dog([small, big]) is big
        assert pick_main_dog([Detection(0.1, (0, 0, 100, 100))]) is None
        assert pick_main_dog([]) is None

    def test_smooth_levels(self):
        assert smooth_levels([]) == "red"
        assert smooth_levels(["green", "green", "green"]) == "green"
        assert smooth_levels(["green", "green"]) == "yellow"        # 还没攒够
        assert smooth_levels(["green", "red", "green"]) == "yellow"  # 抖动不当红
        assert smooth_levels(["green", "red", "red"]) == "red"
        assert smooth_levels(["red", "red", "green", "green", "green"]) == "green"


class TestEndpoint:
    @staticmethod
    def _jpeg(w=W, h=H) -> bytes:
        import cv2

        ok, buf = cv2.imencode(".jpg", np.full((h, w, 3), 128, np.uint8))
        assert ok
        return buf.tobytes()

    @staticmethod
    def _post(client, data: bytes, view="side", **form):
        return client.post(
            "/frame-check",
            files={"file": ("f.jpg", io.BytesIO(data), "image/jpeg")},
            data={"view": view, **form},
        )

    @staticmethod
    def _stub(monkeypatch, w=W, h=H):
        seen = {}

        def fake(img, imgsz=480):
            seen["shape"] = img.shape
            seen["mean_bgr"] = img.reshape(-1, 3).mean(axis=0).tolist()
            x1, y1, x2, y2 = SPECS["side"].guide
            return (
                [Detection(0.8, ((x1 + .04) * w, (y1 + .04) * h, (x2 - .04) * w, (y2 - .04) * h))],
                [Detection(0.8, (0.02 * w, 0.02 * h, 0.30 * w, 0.40 * h))],
            )

        monkeypatch.setattr(framing, "detect_frame", fake)
        return seen

    def test_jpeg_returns_verdict(self, monkeypatch):
        self._stub(monkeypatch)
        r = self._post(TestClient(app), self._jpeg())
        assert r.status_code == 200, r.text
        assert r.json()["level"] == "green"

    def test_rgb_raw_bytes_are_decoded_with_correct_channel_order(self, monkeypatch):
        # 纯红（RGB=255,0,0）：服务端内部用 BGR，应读成 B=0,G=0,R=255
        seen = self._stub(monkeypatch)
        w, h = 48, 64
        raw = np.zeros((h, w, 3), np.uint8)
        raw[..., 0] = 255
        r = self._post(TestClient(app), raw.tobytes(), format="rgb", width=w, height=h)
        assert r.status_code == 200, r.text
        assert seen["shape"] == (h, w, 3)
        b, g, rr = seen["mean_bgr"]
        assert (b, g, rr) == (0.0, 0.0, 255.0)

    @pytest.mark.parametrize(
        "form",
        [
            {"format": "rgb"},                                   # 缺宽高
            {"format": "rgb", "width": 10, "height": 10},        # 字节数对不上
            {"format": "rgb", "width": 0, "height": 5},
            {"format": "png"},
            {"view": "diagonal"},
        ],
    )
    def test_bad_requests_are_400(self, form):
        assert self._post(TestClient(app), b"\x00" * 100, **form).status_code == 400

    def test_empty_undecodable_oversize_are_400(self):
        c = TestClient(app)
        assert self._post(c, b"").status_code == 400
        assert self._post(c, b"not an image").status_code == 400
        assert self._post(c, b"\0" * (2 * 1024 * 1024 + 1)).status_code == 400

    def test_busy_returns_429_instead_of_queueing(self, monkeypatch):
        from app import main

        self._stub(monkeypatch)
        assert main._FRAME_LOCK.acquire(blocking=False)
        try:
            assert self._post(TestClient(app), self._jpeg()).status_code == 429
        finally:
            main._FRAME_LOCK.release()
        assert self._post(TestClient(app), self._jpeg()).status_code == 200

    def test_detector_failure_is_503_and_releases_lock(self, monkeypatch):
        from app import main

        def boom(img, imgsz=480):
            raise RuntimeError("no ultralytics")

        monkeypatch.setattr(framing, "detect_frame", boom)
        r = self._post(TestClient(app), self._jpeg())
        assert r.status_code == 503 and "detector_unavailable" in r.json()["detail"]
        assert main._FRAME_LOCK.acquire(blocking=False)
        main._FRAME_LOCK.release()
