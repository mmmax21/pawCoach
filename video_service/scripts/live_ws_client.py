"""把一段视频当"手机"：按真实速度经 WebSocket 推给运行中的 /live，量"事件发生 → 手机屏幕上看到"的延迟。

这是边拍边显示的端到端验收，也是演示当天的兜底：手机相机出问题时，可以用预录视频当相机，
大屏照样跑实时计时。

用法（先启动服务：uvicorn app.main:app --port 8001）：
    PYTHONPATH=. python scripts/live_ws_client.py <视频> [--url ws://127.0.0.1:8001/live] [--rate 5]

输出：
- 每个"坐下"首次出现在快照里的时刻 vs 视频里狗真正坐下的时刻（含防抖确认的 0.6 秒）
- 每个"奖励延迟"首次出现在快照里的时刻 vs 奖励声音真正出现的时刻
- 快照间隔（屏幕数字多久刷新一次）
"""

from __future__ import annotations

import argparse
import asyncio
import json
import struct
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import cv2
import numpy as np
import websockets


def audio_of(video: Path) -> np.ndarray:
    ff = Path(sys.executable).parent / "ffmpeg"
    ff = str(ff) if ff.exists() else "ffmpeg"
    with tempfile.NamedTemporaryFile(suffix=".pcm") as f:
        subprocess.run([ff, "-y", "-loglevel", "error", "-i", str(video), "-vn", "-ac", "1", "-ar", "16000", "-f", "s16le", f.name], check=False)
        return np.fromfile(f.name, dtype="<i2")


async def run(video: Path, url: str, rate: float, long_side: int = 320, late: float = 1.0) -> dict:
    cap = cv2.VideoCapture(str(video))
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    n_frames = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))
    pcm = audio_of(video)
    step = max(1, int(round(fps / rate)))

    seen: list[tuple[float, dict]] = []      # (本地接收时刻 - 开始时刻, 快照)
    result: dict | None = None

    async with websockets.connect(url, max_size=8 * 1024 * 1024) as ws:
        first = json.loads(await ws.recv())
        assert first["type"] == "ready", first
        t_start = time.perf_counter()

        async def reader():
            nonlocal result
            async for raw in ws:
                m = json.loads(raw)
                if m["type"] == "snapshot":
                    seen.append((time.perf_counter() - t_start, m))
                elif m["type"] == "result":
                    result = m["result"]
                    return

        rd = asyncio.create_task(reader())
        await ws.send(json.dumps({"type": "start", "late_sec": late, "mic": True}))
        t_start = time.perf_counter()

        chunk = 1600
        ai = 0
        i = 0
        while True:
            ok, frame = cap.read()
            if not ok:
                break
            t = i / fps
            wait = t - (time.perf_counter() - t_start)
            if wait > 0:
                await asyncio.sleep(wait)
            while ai * chunk / 16000 <= t and ai * chunk < len(pcm):
                blk = pcm[ai * chunk:(ai + 1) * chunk]
                await ws.send(b"A" + struct.pack("<f", ai * chunk / 16000) + blk.astype("<i2").tobytes())
                ai += 1
            if i % step == 0:
                h, w = frame.shape[:2]
                s = long_side / max(h, w)
                small = cv2.resize(frame, (max(1, int(w * s)), max(1, int(h * s))))
                rgb = cv2.cvtColor(small, cv2.COLOR_BGR2RGB)
                await ws.send(b"F" + struct.pack("<fHH", t, rgb.shape[1], rgb.shape[0]) + rgb.tobytes())
            i += 1
        await ws.send(json.dumps({"type": "stop"}))
        await rd
    return {"seen": seen, "result": result, "duration": n_frames / fps}


def report(out: dict) -> None:
    seen, res = out["seen"], out["result"]
    print(f"快照 {len(seen)} 条，视频 {out['duration']:.1f}s")
    if len(seen) > 1:
        gaps = np.diff([a for a, _ in seen])
        print(f"快照间隔: 中位 {np.median(gaps)*1000:.0f} ms，p95 {np.percentile(gaps, 95)*1000:.0f} ms，最大 {gaps.max()*1000:.0f} ms")
    # 每个坐下第一次出现的时刻
    first_sit: dict[float, float] = {}
    first_reward: dict[float, float] = {}
    for at, snap in seen:
        for tr in snap["trials"]:
            first_sit.setdefault(tr["sit_start"], at)
            if tr["reward_t"] is not None:
                first_reward.setdefault(tr["sit_start"], at)
    print("\n坐下被看到:  (狗真正坐下的视频时刻 → 手机屏幕上出现的时刻)")
    for st, at in sorted(first_sit.items()):
        print(f"  坐下 {st:5.1f}s → 屏幕 {at:5.1f}s  晚 {at - st:4.2f}s")
    print("奖励被看到:  (奖励声音的视频时刻 → 手机屏幕上出现的时刻)")
    for st in sorted(first_reward):
        rt = next(tr["reward_t"] for _, s in seen for tr in s["trials"] if tr["sit_start"] == st and tr["reward_t"] is not None)
        print(f"  奖励 {rt:5.1f}s → 屏幕 {first_reward[st]:5.1f}s  晚 {first_reward[st] - rt:4.2f}s")
    # "奖励晚了"提示什么时候亮的（奖励还没出现就已经亮）
    for at, snap in seen:
        lt = snap.get("live_trial")
        if snap.get("hint") == "reward_late" and lt:
            print(f"\nreward_late 提示首次亮起: 屏幕 {at:.1f}s（这一轮 {lt['sit_start']:.1f}s 坐下，此时还没有奖励，已等 {lt['running_delay']}s）")
            break
    print("\n最终结果:")
    for k, t in enumerate(res["trials"], 1):
        print(f"  第{k}轮 口令{len(t['cue_times'])}次 坐下{t['sit_start']} 奖励{t['reward_t']} 延迟{t['reward_delay']}s")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("--url", default="ws://127.0.0.1:8001/live")
    ap.add_argument("--rate", type=float, default=5.0)
    a = ap.parse_args()
    report(asyncio.run(run(Path(a.video), a.url, a.rate)))
