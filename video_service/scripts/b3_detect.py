"""B3：对一段视频跑狗检测，打印主狗框，标出狗不在画面（或只露一角）的区间，可选画框叠加图。

用法（.venv-b 里，需要 ultralytics 和 data/models/yolov8n.pt）：
    python scripts/b3_detect.py data/raw/dog3.mp4
    python scripts/b3_detect.py data/raw/dog3.mp4 --plot reports/dog_boxes_dog3.png
结果缓存在 data/pose/<视频名>_dogbox.npy；--force 重新检测。
权重下载（国外站点要走代理）：
    curl -x http://127.0.0.1:7892 -L -o data/models/yolov8n.pt \
        https://github.com/ultralytics/assets/releases/download/v8.3.0/yolov8n.pt
"""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path

import numpy as np

from pawcoach.pose.detect import detect_main_dog, in_frame_mask
from pawcoach.video.probe import load_video


def runs(mask: np.ndarray, fps: float) -> list[tuple[float, float, bool]]:
    out = []
    start = 0
    for i in range(1, len(mask) + 1):
        if i == len(mask) or mask[i] != mask[start]:
            out.append((round(start / fps, 2), round(i / fps, 2), bool(mask[start])))
            start = i
    return out


def plot(video: Path, track: np.ndarray, mask: np.ndarray, out_png: Path, fps: float, n: int = 8) -> None:
    import matplotlib

    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from matplotlib.image import imread
    from matplotlib.patches import Rectangle

    picks = [int(i * (len(track) - 1) / (n - 1)) for i in range(n)]
    with tempfile.TemporaryDirectory() as tmp:
        fig, axes = plt.subplots(2, 4, figsize=(16, 14))
        for ax, f in zip(axes.ravel(), picks):
            img = Path(tmp) / f"f{f}.jpg"
            subprocess.run(
                ["ffmpeg", "-y", "-loglevel", "error", "-i", str(video), "-vf", f"select=eq(n\\,{f})",
                 "-vframes", "1", str(img)],
                check=True,
            )
            ax.imshow(imread(img))
            c, x1, y1, x2, y2 = track[f]
            if not np.isnan(c):
                color = "#2ca02c" if mask[f] else "#d62728"
                ax.add_patch(Rectangle((x1, y1), x2 - x1, y2 - y1, fill=False, edgecolor=color, linewidth=3))
            state = "in frame" if mask[f] else "out / corner only"
            ax.set_title(f"{f / fps:.1f}s  {state}" + ("" if np.isnan(c) else f"  conf={c:.2f}"), fontsize=11)
            ax.axis("off")
        fig.suptitle("YOLOv8n main-dog box (cat+dog classes) · green = in frame, red = corner only, no box = not detected", fontsize=12)
        fig.tight_layout()
        out_png.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(out_png, dpi=55)
        plt.close(fig)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("--plot")
    ap.add_argument("--force", action="store_true")
    ap.add_argument("--every", type=float, default=1.0, help="每隔多少秒打印一次框")
    a = ap.parse_args()

    video = load_video(a.video)
    pose_dir = Path("data/pose")
    track = detect_main_dog(Path(video.path), pose_dir, use_cache=not a.force)
    mask = in_frame_mask(track, video.fps, *video.display_size)

    print(f"{video.path}  {len(track)} 帧  {video.fps:.0f}fps  画面 {video.display_size[0]}x{video.display_size[1]}")
    print("时间(s)  置信度  主狗框 (x1, y1, x2, y2)       在画面")
    step = max(1, round(a.every * video.fps))
    for f in range(0, len(track), step):
        c, x1, y1, x2, y2 = track[f]
        box = "无框" if np.isnan(c) else f"{c:.2f}    ({x1:4.0f}, {y1:4.0f}, {x2:4.0f}, {y2:4.0f})"
        print(f"{f / video.fps:6.1f}   {box:36s} {'是' if mask[f] else '否'}")
    print("区间（狗在画面 / 不在或只露一角）：")
    for s, e, inside in runs(mask, video.fps):
        print(f"  {s:6.2f} - {e:6.2f}  {'在画面' if inside else '不在/只露一角'}")
    if a.plot:
        plot(Path(video.path), track, mask, Path(a.plot), video.fps)
        print(f"已保存：{a.plot}")


if __name__ == "__main__":
    main()
