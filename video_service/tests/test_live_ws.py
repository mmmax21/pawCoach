"""/live WebSocket：协议、丢帧、错误输入。姿态引擎换成替身，不需要模型。"""

import json
import struct

import numpy as np
import pytest
from fastapi.testclient import TestClient

import app.live as live_mod
from app.main import app
from pawcoach.live.pose_live import FrameRead


class FakeEngine:
    """按会话时间返回标签：t < sit_at 站，之后坐。"""

    def __init__(self, sit_at=2.0, stand_at=None):
        self.sit_at, self.stand_at = sit_at, stand_at
        self.t = 0.0
        self.loaded = True
        self.calls = 0

    def load(self):
        pass

    def read(self, img):
        self.calls += 1
        t = float(img[0, 0, 0]) / 10.0           # 测试把时间编码进第一个像素：t = 像素值/10
        lab = "sit" if t >= self.sit_at and (self.stand_at is None or t < self.stand_at) else "stand"
        return FrameRead(lab, 0.9, (0.1, 0.4, 0.9, 0.8))


@pytest.fixture
def client(monkeypatch):
    eng = FakeEngine()
    monkeypatch.setattr(live_mod, "_engine", eng)
    return TestClient(app), eng


def frame_msg(t):
    img = np.zeros((16, 9, 3), np.uint8)
    img[0, 0, 0] = int(round(t * 10))
    return b"F" + struct.pack("<fHH", t, 9, 16) + img.tobytes()


def audio_msg(t0, pcm):
    return b"A" + struct.pack("<f", t0) + pcm.astype("<i2").tobytes()


def speech(t_on, dur=0.4, total=None):
    """返回 [(t0, pcm)]：100 毫秒一块，t_on 起 dur 秒有声，前 0.6 秒静音用于冷启动。"""
    sr = 16000
    out = []
    for k in range(int((total or t_on + dur + 0.5) * 10)):
        t0 = k / 10
        n = sr // 10
        tt = np.arange(n) / sr + t0
        loud = t_on <= t0 + 0.05 and t0 < t_on + dur
        x = (0.2 * np.sin(2 * np.pi * 220 * tt) if loud else 0.001 * np.random.default_rng(k).standard_normal(n)) * 32767
        out.append((t0, x.astype(np.int16)))
    return out


def drain(ws, until="snapshot", limit=200):
    last = None
    for _ in range(limit):
        m = json.loads(ws.receive_text())
        if m["type"] == until:
            last = m
            break
    return last


def test_handshake_ready_then_start_snapshot(client):
    c, _ = client
    with c.websocket_connect("/live") as ws:
        assert json.loads(ws.receive_text())["type"] == "ready"
        ws.send_text(json.dumps({"type": "start", "late_sec": 1.0}))
        snap = drain(ws)
        assert snap["trials"] == [] and snap["late_sec"] == 1.0


def test_end_to_end_late_reward_is_measured(client):
    """口令 0.8 秒 → 狗 2.0 秒坐下 → 3.4 秒才有声音（奖励）。奖励延迟应约 1.4 秒。"""
    c, _ = client
    with c.websocket_connect("/live") as ws:
        ws.receive_text()
        ws.send_text(json.dumps({"type": "start", "late_sec": 1.0}))
        drain(ws)
        events = []
        for t0, p in speech(0.8, total=4.2):          # 0.8 秒口令；其后静音
            events.append((t0, 0, "a", p))
        for t0, p in speech(3.4, total=4.2):          # 3.4 秒奖励
            if t0 >= 3.0:
                events.append((t0 + 0.0001, 0, "a2", p))
        # a2 与 a 在 3.0 秒之后重叠：只保留 a2 的有声块，丢掉 a 里 3.0 之后的静音块
        events = [e for e in events if not (e[2] == "a" and e[0] >= 3.0)]
        for k in range(0, 42):
            events.append((k / 10, 1, "f", None))
        events.sort(key=lambda e: (e[0], e[1]))
        for t, _, kind, p in events:
            if kind == "f":
                ws.send_bytes(frame_msg(t))
            else:
                ws.send_bytes(audio_msg(round(t, 1), p))
        ws.send_text(json.dumps({"type": "stop"}))
        res = drain(ws, until="result")["result"]
        tr = res["trials"][0]
        assert abs(tr["cue_t"] - 0.8) <= 0.12
        assert 1.2 <= tr["reward_delay"] <= 1.7
        assert res["quality"]["asr"] == "live_onset" and tr["cue_source"] == "onset"


def test_tap_reward_without_any_audio(client):
    c, _ = client
    with c.websocket_connect("/live") as ws:
        ws.receive_text()
        ws.send_text(json.dumps({"type": "start", "late_sec": 1.0, "mic": False}))
        drain(ws)
        for t, p in speech(0.8, total=1.2):
            ws.send_bytes(audio_msg(t, p))
        for k in range(0, 40):
            ws.send_bytes(frame_msg(k / 10))
        ws.send_text(json.dumps({"type": "tap", "t": 3.1}))
        ws.send_text(json.dumps({"type": "stop"}))
        res = drain(ws, until="result")["result"]
        tr = res["trials"][0]
        assert tr["reward_t"] == pytest.approx(3.1) and tr["reward_delay"] == pytest.approx(1.1, abs=0.15)


def test_bad_frames_and_garbage_do_not_kill_the_connection(client):
    c, _ = client
    with c.websocket_connect("/live") as ws:
        ws.receive_text()
        ws.send_text(json.dumps({"type": "start"}))
        drain(ws)
        ws.send_bytes(b"F")                                          # 太短
        ws.send_bytes(b"F" + struct.pack("<fHH", 1.0, 10, 10) + b"x")  # 长度对不上
        ws.send_bytes(b"A\x00\x00\x00")                                # 音频奇数字节
        ws.send_text("not json")
        ws.send_bytes(frame_msg(0.5))                                  # 之后正常帧还能处理
        ws.send_text(json.dumps({"type": "stop"}))
        assert drain(ws, until="result")["result"]["duration"] >= 0


def test_frames_arrive_faster_than_inference_only_latest_is_processed(client, monkeypatch):
    import threading
    import time

    c, eng = client
    gate = threading.Event()
    orig = eng.read

    def slow(img):
        gate.wait(1.0)
        return orig(img)

    eng.read = slow
    with c.websocket_connect("/live") as ws:
        ws.receive_text()
        ws.send_text(json.dumps({"type": "start"}))
        drain(ws)
        for k in range(30):
            ws.send_bytes(frame_msg(k / 10))
        gate.set()
        time.sleep(0.5)
        ws.send_text(json.dumps({"type": "stop"}))
        drain(ws, until="result")
    assert eng.calls < 30     # 中间的旧帧被丢掉，没有 30 次推理排队


def test_pose_unavailable_gives_error_message(monkeypatch):
    class Boom:
        def load(self):
            raise RuntimeError("no deeplabcut")

    monkeypatch.setattr(live_mod, "_engine", Boom())
    with TestClient(app).websocket_connect("/live") as ws:
        m = json.loads(ws.receive_text())
        assert m["type"] == "error" and "pose_unavailable" in m["message"]


def test_parse_helpers_reject_oversize_and_mismatch():
    with pytest.raises(ValueError):
        live_mod.parse_frame(b"F" + struct.pack("<fHH", 0, 1000, 1000) + b"")
    with pytest.raises(ValueError):
        live_mod.parse_audio(b"A" + struct.pack("<f", 0) + b"\x00")
