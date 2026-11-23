"""v3 视觉大模型兜底：默认关闭；拼图、解析、失败兜底（不发真实请求）。"""

import json
from types import SimpleNamespace

import numpy as np

from pawcoach.pose import vision_fallback as vf


def crops(n):
    return [np.full((60, 40, 3), 40 * k % 255, np.uint8) for k in range(n)]


def test_disabled_by_default(monkeypatch):
    monkeypatch.delenv("VISION_FALLBACK", raising=False)
    assert not vf.enabled()
    monkeypatch.setenv("VISION_FALLBACK", "on")
    assert vf.enabled()


def test_grid_is_jpeg():
    b = vf.make_grid(crops(5))
    assert b[:2] == b"\xff\xd8"


def test_parse_labels_ignores_bad_items():
    text = json.dumps({"frames": [{"index": 1, "posture": "sit"}, {"index": 9, "posture": "down"},
                                  {"index": 2, "posture": "jumping"}]})
    assert vf.parse_labels(text, 3) == ["sit", "unclear", "unclear"]


class FakeClient:
    def __init__(self, text=None, stop="end_turn", boom=False):
        self.calls = []
        msgs = SimpleNamespace(create=self._create)
        self.beta = SimpleNamespace(messages=msgs)
        self.text, self.stop, self.boom = text, stop, boom

    def _create(self, **kw):
        self.calls.append(kw)
        if self.boom:
            raise RuntimeError("network")
        return SimpleNamespace(stop_reason=self.stop, content=[SimpleNamespace(type="text", text=self.text)])


def test_classify_request_shape_and_result():
    fc = FakeClient(json.dumps({"frames": [{"index": 1, "posture": "down"}, {"index": 2, "posture": "sit"}]}))
    r = vf.classify_crops(crops(2), client=fc)
    assert r.ok and r.labels == ["down", "sit"]
    kw = fc.calls[0]
    assert kw["fallbacks"] == "default" and "server-side-fallback-2026-07-01" in kw["betas"]
    assert kw["output_config"]["format"]["type"] == "json_schema"
    assert kw["messages"][0]["content"][0]["type"] == "image"


def test_failures_become_unclear():
    assert vf.classify_crops(crops(2), client=FakeClient(boom=True)).labels == ["unclear", "unclear"]
    r = vf.classify_crops(crops(2), client=FakeClient("", stop="refusal"))
    assert not r.ok and r.labels == ["unclear", "unclear"]
    assert len(vf.classify_crops(crops(30), client=FakeClient(json.dumps({"frames": []}))).labels) == vf.MAX_FRAMES
