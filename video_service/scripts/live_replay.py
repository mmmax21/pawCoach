"""把一段已有视频当成"现场相机和麦克风"，按真实速度喂给实时引擎，检验整条链路。

不依赖手机：用 ffmpeg 抽出音频，用 OpenCV 读帧，按视频自己的时间戳送进 LiveSession。
默认"全速回放"（不等待，只看判定是否正确）；加 --realtime 则按视频时间等待，同时统计
"事件发生 → 快照里看到"的延迟，也就是手机屏幕上数字比现实慢多少。

用法（pawcoach 环境，在 video_service/ 下）：
    PYTHONPATH=. python scripts/live_replay.py <视频> [--rate 5] [--realtime] [--late 1.0]
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import cv2
import numpy as np

from pawcoach.live.pose_live import PoseEngine
from pawcoach.live.session import LiveSession


def extract_audio(video: Path) -> np.ndarray:
    ff = Path(sys.executable).parent / "ffmpeg"
    ff = str(ff) if ff.exists() else "ffmpeg"
    with tempfile.NamedTemporaryFile(suffix=".pcm") as f:
        r = subprocess.run(
            [ff, "-y", "-loglevel", "error", "-i", str(video), "-vn", "-ac", "1", "-ar", "16000", "-f", "s16le", f.name],
            capture_output=True,
        )
        if r.returncode != 0:
            return np.zeros(0, np.int16)
        return np.fromfile(f.name, dtype="<i2")


def replay(video: Path, rate: float = 5.0, realtime: bool = False, late_sec: float = 1.0, engine: PoseEngine | None = None):
    engine = engine or PoseEngine()
    engine.load()
    cap = cv2.VideoCapture(str(video))
    fps = cap.get(cv2.CAP_PROP_FPS) or 30.0
    pcm = extract_audio(video)
    step = max(1, int(round(fps / rate)))
    chunk = 1600                                  # 100 毫秒
    s = LiveSession(late_sec=late_sec)
    start = time.perf_counter()
    lags: list[float] = []                        # 现实时间里，帧到手 → 推理完成 的耗时
    ai = 0
    i = 0
    while True:
        ok, frame = cap.read()
        if not ok:
            break
        t = i / fps
        # 这一帧之前该到的音频块
        while ai * chunk / 16000 <= t and ai * chunk < len(pcm):
            s.on_audio(ai * chunk / 16000, pcm[ai * chunk:(ai + 1) * chunk])
            ai += 1
        if i % step == 0:
            if realtime:
                wait = t - (time.perf_counter() - start)
                if wait > 0:
                    time.sleep(wait)
            a = time.perf_counter()
            r = engine.read(cv2.cvtColor(frame, cv2.COLOR_BGR2RGB))
            lags.append(time.perf_counter() - a)
            s.on_frame(t, r.label, r.box)
        i += 1
    while ai * chunk < len(pcm):
        s.on_audio(ai * chunk / 16000, pcm[ai * chunk:(ai + 1) * chunk])
        ai += 1
    return s, lags, i / fps


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("--rate", type=float, default=5.0)
    ap.add_argument("--late", type=float, default=1.0)
    ap.add_argument("--realtime", action="store_true")
    a = ap.parse_args()
    s, lags, dur = replay(Path(a.video), a.rate, a.realtime, a.late)
    res = s.result()
    print(f"{Path(a.video).name}  {dur:.1f}s  推理 {len(lags)} 帧，每帧 {np.mean(lags)*1000:.0f} ms（最大 {max(lags)*1000:.0f}）")
    print(f"声音起音 {len(s.onsets)} 次: {[round(v, 1) for v in s.onsets]}")
    print(f"坐下区间: {[(round(g.start, 1), None if g.end is None else round(g.end, 1)) for g in s.tracker.sit_segments()]}")
    for k, t in enumerate(res["trials"], 1):
        print(
            f"  第{k}轮: 口令 {t['cue_t']} 次数 {len(t['cue_times'])} → 坐下 {t['sit_start']} "
            f"(反应 {t['latency']}s) → 奖励 {t['reward_t']} (延迟 {t['reward_delay']}s) 保持 {t['hold']}s 可靠 {t['reliable']}"
        )
    if res["unpaired"]:
        print("  未配对:", res["unpaired"])


if __name__ == "__main__":
    main()
