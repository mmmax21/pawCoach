"""实时计时的 WebSocket：/live

手机一路发 相机小图 + 麦克风 PCM + 奖励点按，服务端一路回 快照（狗的状态、轮次、奖励延迟）。

协议（一条连接 = 一次练习）：
  客户端 → 服务端
    文本  {"type":"start","late_sec":1.0,"mic":true}      开始。late_sec 是"奖励晚"阈值（手机从内容库读）
    二进制 帧：  b"F" + t(float32 小端，会话秒) + w(uint16) + h(uint16) + RGB 字节(w*h*3)
    二进制 音频：b"A" + t0(float32，这块第一个采样的会话秒) + 16kHz 单声道 16 位小端 PCM
    文本  {"type":"tap","t":3.2}                          奖励点按
    文本  {"type":"stop"}                                 结束，服务端回 {"type":"result",...} 后关闭
  服务端 → 客户端
    文本  {"type":"ready"}                                模型已加载，可以开始发帧
    文本  {"type":"snapshot", ...Snapshot}                状态变化时（最快每 100 毫秒一条）
    文本  {"type":"result", "result": {...}}               结束时的完整结果（与离线 /results 同格式）
    文本  {"type":"error","message":"..."}

关键设计：
- 时间全部取手机自己的会话时钟，服务端不用自己的时钟，网络抖动不会让"奖励延迟"变长。
- 推理在单独线程里串行跑；帧到得比推理快时直接丢旧帧（只处理最新一帧），预览不会越来越滞后。
- 音频不能丢：音频块只做轻量的音量计算，在事件循环里直接处理，不排队等姿态推理。
- 不落盘，不保留任何帧或音频；连接关闭即释放。
"""

from __future__ import annotations

import asyncio
import json
import struct
import time
from concurrent.futures import ThreadPoolExecutor

import numpy as np
from fastapi import APIRouter, WebSocket, WebSocketDisconnect

from pawcoach.live.session import LiveSession

router = APIRouter()

# 姿态推理单线程：模型只有一份，串行最稳
_POSE_POOL = ThreadPoolExecutor(max_workers=1, thread_name_prefix="live-pose")
_engine = None
MIN_SNAPSHOT_GAP_S = 0.1
MAX_FRAME_PIXELS = 640 * 640


def get_engine():
    """模块级 _engine（测试可替换）；没有时用进程内共享的那份（身体信号检查、整段分析也用它）。"""
    global _engine
    if _engine is None:
        from pawcoach.live.pose_live import shared_engine

        _engine = shared_engine()
    return _engine


def preload_engine() -> None:
    """服务启动时后台加载，第一个连接不必等（失败静默，连接时会回 error）。"""
    try:
        get_engine().load()
    except Exception:  # noqa: BLE001
        pass


def parse_frame(msg: bytes) -> tuple[float, np.ndarray]:
    if len(msg) < 9:
        raise ValueError("frame too short")
    t, w, h = struct.unpack("<fHH", msg[1:9])
    if w * h == 0 or w * h > MAX_FRAME_PIXELS or len(msg) - 9 != w * h * 3:
        raise ValueError(f"bad frame size {w}x{h} payload {len(msg) - 9}")
    return float(t), np.frombuffer(msg, np.uint8, offset=9).reshape(h, w, 3)


def parse_audio(msg: bytes) -> tuple[float, np.ndarray]:
    if len(msg) < 5 or (len(msg) - 5) % 2:
        raise ValueError("bad audio chunk")
    (t0,) = struct.unpack("<f", msg[1:5])
    return float(t0), np.frombuffer(msg, "<i2", offset=5)


def _dumps(obj: dict) -> str:
    return json.dumps(obj, ensure_ascii=False)


@router.websocket("/live")
async def live(ws: WebSocket) -> None:
    await ws.accept()
    loop = asyncio.get_running_loop()
    try:
        engine = get_engine()
        await loop.run_in_executor(_POSE_POOL, engine.load)
    except Exception as e:  # noqa: BLE001  缺 deeplabcut / ultralytics 等
        await ws.send_text(_dumps({"type": "error", "message": f"pose_unavailable: {e}"}))
        await ws.close()
        return
    await ws.send_text(_dumps({"type": "ready"}))

    session: LiveSession | None = None
    latest_frame: tuple[float, np.ndarray] | None = None    # 只留最新一帧
    pose_busy = False
    last_sent = 0.0
    dirty = False
    tasks: set[asyncio.Task] = set()

    async def push(force: bool = False) -> None:
        nonlocal last_sent, dirty
        now = time.monotonic()
        if session is None or not (force or (dirty and now - last_sent >= MIN_SNAPSHOT_GAP_S)):
            return
        last_sent = now
        dirty = False
        try:
            await ws.send_text(_dumps({"type": "snapshot", **session.snapshot().to_dict()}))
        except Exception:  # noqa: BLE001  连接已断
            pass

    async def run_pose() -> None:
        """取最新一帧推理；推理期间到的帧只更新 latest_frame，不排队。"""
        nonlocal latest_frame, pose_busy, dirty
        if pose_busy or latest_frame is None or session is None:
            return
        pose_busy = True
        try:
            while latest_frame is not None and session is not None:
                t, img = latest_frame
                latest_frame = None
                try:
                    r = await loop.run_in_executor(_POSE_POOL, engine.read, img)
                except Exception:  # noqa: BLE001  单帧失败当作看不清，不断连接
                    from pawcoach.live.pose_live import FrameRead

                    r = FrameRead("unclear", 0.0, None)
                session.on_frame(t, r.label, r.box)
                if r.kp is not None:  # v3 身体信号
                    from pawcoach.body.signals import frame_signals

                    session.on_body(frame_signals(r.kp, t, None if r.label == "unclear" else r.label, r.side_view))
                dirty = True
                await push()
        finally:
            pose_busy = False

    try:
        while True:
            msg = await ws.receive()
            if msg["type"] == "websocket.disconnect":
                break
            if (text := msg.get("text")) is not None:
                try:
                    obj = json.loads(text)
                except ValueError:
                    continue
                kind = obj.get("type") if isinstance(obj, dict) else None
                if kind == "start":
                    session = LiveSession(late_sec=float(obj.get("late_sec", 1.0)), mic_enabled=bool(obj.get("mic", True)))
                    latest_frame = None
                    dirty = True
                    await push(force=True)
                elif kind == "tap" and session is not None:
                    try:
                        session.on_tap(float(obj["t"]))
                    except (KeyError, TypeError, ValueError):
                        continue
                    dirty = True
                    await push(force=True)
                elif kind == "stop":
                    if session is not None:
                        for _ in range(100):             # 等最后一帧推理收尾，最多 2 秒
                            if not pose_busy:
                                break
                            await asyncio.sleep(0.02)
                        await ws.send_text(_dumps({"type": "result", "result": session.result()}))
                    await ws.close()
                    return
            elif (data := msg.get("bytes")) is not None and session is not None and data:
                try:
                    if data[:1] == b"F":
                        latest_frame = parse_frame(data)
                        task = asyncio.ensure_future(run_pose())
                        tasks.add(task)
                        task.add_done_callback(tasks.discard)
                    elif data[:1] == b"A":
                        t0, pcm = parse_audio(data)
                        new = session.on_audio(t0, pcm)
                        dirty = True
                        await push(force=bool(new))      # 出声是关键事件，不等间隔
                except ValueError:
                    continue        # 坏帧丢掉，不断连接
    except WebSocketDisconnect:
        pass
    finally:
        session = None
        latest_frame = None
        for task in list(tasks):
            task.cancel()
