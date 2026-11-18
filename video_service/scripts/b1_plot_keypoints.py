"""B1：把 SuperAnimal 关键点叠加到视频帧上，生成一张多帧对比图。

用法：
    python scripts/b1_plot_keypoints.py data/raw/dog2.mp4 data/pose/<结果>.h5 reports/pose_keypoints_sample.png
"""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import pandas as pd
from matplotlib.image import imread

# 按身体部位分色，便于肉眼判断关键点是否贴对位置
GROUPS = {
    "head": (["nose", "upper_jaw", "lower_jaw", "mouth_end_right", "mouth_end_left", "right_eye",
              "left_eye", "right_earbase", "right_earend", "left_earbase", "left_earend"], "#e6194b"),
    "spine": (["neck_base", "neck_end", "throat_base", "throat_end", "back_base", "back_middle",
               "back_end", "tail_base", "tail_end"], "#3cb44b"),
    "front legs": (["front_left_thai", "front_left_knee", "front_left_paw", "front_right_thai",
                    "front_right_knee", "front_right_paw"], "#4363d8"),
    "back legs": (["back_left_thai", "back_left_knee", "back_left_paw", "back_right_thai",
                   "back_right_knee", "back_right_paw"], "#f58231"),
    "belly": (["belly_bottom", "body_middle_right", "body_middle_left"], "#911eb4"),
}
MIN_CONF = 0.3


def plot(video: Path, h5: Path, out_png: Path, n_frames: int = 8) -> None:
    df = pd.read_hdf(h5)
    n_total = len(df)
    picks = [int(i * (n_total - 1) / (n_frames - 1)) for i in range(n_frames)]

    with tempfile.TemporaryDirectory() as tmp:
        fig, axes = plt.subplots(2, 4, figsize=(20, 7.5))
        for ax, idx in zip(axes.ravel(), picks):
            frame = Path(tmp) / f"f{idx}.jpg"
            subprocess.run(
                ["ffmpeg", "-y", "-loglevel", "error", "-i", str(video),
                 "-vf", f"select=eq(n\\,{idx})", "-vframes", "1", str(frame)],
                check=True,
            )
            ax.imshow(imread(frame))
            shown = 0
            for names, color in GROUPS.values():
                for bp in names:
                    x = df[(df.columns[0][0], "animal0", bp, "x")].iloc[idx]
                    y = df[(df.columns[0][0], "animal0", bp, "y")].iloc[idx]
                    c = df[(df.columns[0][0], "animal0", bp, "likelihood")].iloc[idx]
                    if c >= MIN_CONF and x == x:
                        ax.scatter(x, y, s=28, c=color, edgecolors="white", linewidths=0.6)
                        shown += 1
            ax.set_title(f"frame {idx} ({idx / 30:.1f}s) · {shown} pts ≥{MIN_CONF}", fontsize=10)
            ax.axis("off")
        fig.suptitle("SuperAnimal-Quadruped (rtmpose_s + ssdlite) keypoints · red=head green=spine "
                     "blue=front legs orange=back legs purple=belly", fontsize=11)
        fig.tight_layout()
        out_png.parent.mkdir(parents=True, exist_ok=True)
        fig.savefig(out_png, dpi=70)
        plt.close(fig)


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("h5")
    ap.add_argument("out_png")
    a = ap.parse_args()
    plot(Path(a.video), Path(a.h5), Path(a.out_png))
    print(f"已保存：{a.out_png}")
