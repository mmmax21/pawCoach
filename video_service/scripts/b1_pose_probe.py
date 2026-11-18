"""B1：SuperAnimal 关键点推理（探路脚本，不进 analyze 主流程）。

对一段视频跑 SuperAnimal-Quadruped，输出每帧 39 个关键点的 CSV/H5，
并画一张关键点叠加图到 reports/，用于肉眼确认关键点贴在狗身上。

B2 的 `SuperAnimalPoseExtractor` 会复用这里的推理与读取逻辑。

用法：
    python scripts/b1_pose_probe.py data/raw/dog2.mp4
需要在 .venv-b（Python 3.12 + deeplabcut）里运行；国外权重走代理时先 export https_proxy。
"""

from __future__ import annotations

import argparse
import time
from pathlib import Path

SUPERANIMAL = "superanimal_quadruped"
# 先用最小组合确认链路；效果不够再换 hrnet_w32 + fasterrcnn_resnet50_fpn_v2
DEFAULT_MODEL = "rtmpose_s"
DEFAULT_DETECTOR = "ssdlite"


def run_inference(video: Path, out_dir: Path, model: str, detector: str, device: str) -> Path:
    """跑 SuperAnimal 视频推理，返回结果 H5 路径。"""
    from deeplabcut.modelzoo.video_inference import video_inference_superanimal

    out_dir.mkdir(parents=True, exist_ok=True)
    video_inference_superanimal(
        videos=str(video),
        superanimal_name=SUPERANIMAL,
        model_name=model,
        detector_name=detector,
        dest_folder=str(out_dir),
        pcutoff=0.1,
        max_individuals=1,
        device=device,
        plot_bboxes=False,
        create_labeled_video=False,
    )
    h5s = sorted(out_dir.glob(f"{video.stem}*.h5"))
    if not h5s:
        raise RuntimeError(f"推理完成但没找到结果文件：{out_dir}")
    return h5s[0]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("video")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--detector", default=DEFAULT_DETECTOR)
    parser.add_argument("--device", default="auto")
    parser.add_argument("--out-dir", default="data/pose")
    args = parser.parse_args()

    video = Path(args.video)
    t0 = time.time()
    h5 = run_inference(video, Path(args.out_dir), args.model, args.detector, args.device)
    print(f"推理完成：{h5}，耗时 {time.time() - t0:.1f}s")


if __name__ == "__main__":
    main()
