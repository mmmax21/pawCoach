"""演示前预热（M5 3.5）：预先下载并加载全部模型，现场不再下载。

检查项（每项打印状态与耗时）：
1. ffmpeg 在 PATH 里（标准化与 Whisper 读音轨都要用）
2. YOLO 狗检测权重 data/models/yolov8n.pt 存在，并能加载
3. Whisper base：下载（~/.cache/whisper/base.pt）并加载
4. SuperAnimal 四足姿态权重（rtmpose_s + ssdlite 检测器）：从 HuggingFace 下载并加载
5. 端到端冒烟：用 ffmpeg 生成 2 秒测试视频，跑一遍姿态推理 + 狗检测 + 转写（临时目录，跑完即删）

用法（在 video_service/ 下，先 conda activate pawcoach）：
    python scripts/warmup.py            # 全部
    python scripts/warmup.py --skip-smoke
退出码：全部 OK 为 0，任一项失败为 1。
"""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

RESULTS: list[tuple[str, bool, float, str]] = []


def step(name: str):
    def deco(fn):
        def run(*a, **kw):
            t0 = time.time()
            try:
                detail = fn(*a, **kw) or ""
                ok = True
            except Exception as e:  # noqa: BLE001
                detail, ok = f"{type(e).__name__}: {e}", False
            dt = time.time() - t0
            RESULTS.append((name, ok, dt, detail))
            print(f"[{'OK ' if ok else 'ERR'}] {name:<28} {dt:6.1f}s  {detail}", flush=True)
            return ok

        return run

    return deco


@step("ffmpeg")
def check_ffmpeg() -> str:
    path = shutil.which("ffmpeg")
    if not path:
        raise RuntimeError("PATH 里没有 ffmpeg，请先 conda activate pawcoach")
    return path


@step("YOLO 权重 yolov8n.pt")
def check_yolo() -> str:
    from pawcoach.pose.detect import DEFAULT_WEIGHTS

    weights = ROOT / DEFAULT_WEIGHTS
    if not weights.exists():
        raise FileNotFoundError(f"缺少 {weights}，下载方式见 README")
    from ultralytics import YOLO

    YOLO(str(weights))
    return str(weights.relative_to(ROOT))


@step("Whisper base")
def check_whisper() -> str:
    from pawcoach.audio.transcribe import DEFAULT_MODEL, load_model

    load_model(DEFAULT_MODEL)
    cache = Path.home() / ".cache" / "whisper" / f"{DEFAULT_MODEL}.pt"
    return f"{cache}（{cache.stat().st_size / 1e6:.0f} MB）" if cache.exists() else "已加载"


@step("SuperAnimal 权重")
def check_superanimal() -> str:
    import torch
    from deeplabcut.pose_estimation_pytorch.modelzoo.utils import get_super_animal_snapshot_path

    from pawcoach.pose.superanimal import DEFAULT_DETECTOR, DEFAULT_MODEL, SUPERANIMAL

    out = []
    for name in (DEFAULT_MODEL, DEFAULT_DETECTOR):
        p = get_super_animal_snapshot_path(SUPERANIMAL, name, download=True)
        torch.load(p, map_location="cpu", weights_only=False)
        out.append(f"{p.name}（{p.stat().st_size / 1e6:.0f} MB）")
    return "，".join(out)


@step("冒烟：2 秒视频全流程")
def smoke() -> str:
    from pawcoach.audio.transcribe import transcribe
    from pawcoach.pose.detect import detect_main_dog
    from pawcoach.pose.superanimal import SuperAnimalPoseExtractor
    from pawcoach.video.probe import load_video

    tmp = Path(tempfile.mkdtemp(prefix="pawcoach-warmup-"))
    try:
        video = tmp / "warmup.mp4"
        subprocess.run(
            [
                "ffmpeg", "-y", "-loglevel", "error",
                "-f", "lavfi", "-i", "testsrc=size=640x360:rate=10:duration=2",
                "-f", "lavfi", "-i", "sine=frequency=440:duration=2",
                "-c:v", "libx264", "-pix_fmt", "yuv420p", "-c:a", "aac", "-shortest", str(video),
            ],
            check=True,
        )
        info = load_video(video)
        pose_dir = tmp / "pose"
        SuperAnimalPoseExtractor(pose_dir=str(pose_dir), run_if_missing=True, use_detection=False).extract(info)
        detect_main_dog(video, pose_dir, weights=str(ROOT / "data/models/yolov8n.pt"), use_cache=False)
        transcribe(video, language="zh")
        return "姿态推理、狗检测、转写均可运行"
    finally:
        shutil.rmtree(tmp, ignore_errors=True)


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--skip-smoke", action="store_true")
    args = ap.parse_args()
    t0 = time.time()
    check_ffmpeg()
    check_yolo()
    check_whisper()
    check_superanimal()
    if not args.skip_smoke:
        smoke()
    failed = [r for r in RESULTS if not r[1]]
    print(f"\n预热完成，用时 {time.time() - t0:.1f}s：{len(RESULTS) - len(failed)}/{len(RESULTS)} 项 OK")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
