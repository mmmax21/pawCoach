"""上传后快速预检（减少重拍，2026-11-18）。

整段分析要一两分钟。俯拍、正面拍、没拍到狗这类问题，结果一定是重拍，不该让用户白等。
预检从整段视频里均匀抽 PRECHECK_FRAMES 帧拼成一段短视频，只在这几帧上跑 YOLO 和 SuperAnimal，
十几秒内判断：
- no_dog：大部分抽样帧里没有完整的狗；
- angle：有狗的帧里几乎都看不出姿势（正面 / 背面 / 太小 / 关键点太少，同 pose/rules.py 的 unclear）。

只拦明显不行的视频：阈值比最终的重拍门槛（unclear_ratio > 0.5）宽得多，拿不准就放行，交给整段分析。
声音只记录（voice），不拦：没听清口令时 App 还可以让用户补标口令。
"""

from __future__ import annotations

import subprocess
import tempfile
from pathlib import Path

PRECHECK_FRAMES = 16      # 抽样帧数（视频短于 16 秒时每秒一帧，至少 6 帧）
SAMPLE_FPS = 2.0          # 抽出的帧拼成短视频时的帧率（只影响推理，不影响判断）
MIN_DOG_RATIO = 0.3       # 有完整狗的抽样帧占比低于此值 → no_dog
MIN_SIDE_RATIO = 0.2      # 有狗的帧里能判断姿势的占比低于此值 → angle（即 80% 以上看不清）


def _sample_video(src: Path, duration: float, out: Path) -> int:
    n = int(min(PRECHECK_FRAMES, max(6, round(duration))))
    rate = n / duration if duration > 0 else 1.0
    subprocess.run(
        [
            "ffmpeg", "-y", "-loglevel", "error", "-i", str(src), "-an",
            "-vf", f"fps={rate:.4f},setpts=N/{SAMPLE_FPS}/TB", "-r", str(SAMPLE_FPS),
            "-frames:v", str(n), "-c:v", "libx264", "-pix_fmt", "yuv420p", str(out),
        ],
        check=True,
    )
    return n


def _voice(video) -> bool | None:
    """有没有明显的说话声。True / False；环境缺 whisper（没法解码音频）时 None。"""
    if not video.has_audio:
        return False
    try:
        from pawcoach.audio.transcribe import _load_audio, voice_regions

        return bool(voice_regions(_load_audio(Path(video.path))))
    except Exception:  # noqa: BLE001
        return None


def decide(frames: int, dog_frames: int, side_frames: int) -> list[str]:
    """按抽样统计给出拦截原因（纯函数，便于测试）。"""
    if frames <= 0:
        return []
    if dog_frames / frames < MIN_DOG_RATIO:
        return ["no_dog"]
    if side_frames / dog_frames < MIN_SIDE_RATIO:
        return ["angle"]
    return []


def precheck(video) -> dict:
    """对标准化后的视频做预检，返回 {frames, dog_frames, side_frames, voice, issues}。"""
    import numpy as np

    from pawcoach.pose.detect import detect_main_dog, in_frame_mask
    from pawcoach.pose.rules import PoseRules, classify_frames
    from pawcoach.pose.superanimal import load_keypoints, run_inference

    with tempfile.TemporaryDirectory(prefix="precheck_") as tmp:
        work = Path(tmp)
        sample = work / "sample.mp4"
        n = _sample_video(Path(video.path), video.duration or 0.0, sample)
        w, h = video.display_size
        track = detect_main_dog(sample, work, use_cache=False)
        dog = in_frame_mask(track, SAMPLE_FPS, w, h, max_gap_s=0.0)
        kp = load_keypoints(run_inference(sample, work), SAMPLE_FPS, w, h)
        labels, _ = classify_frames(kp, PoseRules())
    m = min(len(dog), len(labels), n)
    dog = np.asarray(dog[:m], dtype=bool)
    side = dog & np.array([lab != "unclear" for lab in labels[:m]], dtype=bool)
    dog_frames, side_frames = int(dog.sum()), int(side.sum())
    return {
        "frames": m,
        "dog_frames": dog_frames,
        "side_frames": side_frames,
        "voice": _voice(video),
        "issues": decide(m, dog_frames, side_frames),
    }
