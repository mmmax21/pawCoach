"""B2：把视频每秒抽一帧，拼成带时间标注的对照图，供人工标注姿态用。

用法：
    python scripts/b2_label_sheets.py data/raw/dog3.mp4 data/labels/dog3_sheets
输出 sheet_0.png、sheet_1.png ...，每张 8 帧（4 列 x 2 行），标题是时间（秒）。
"""

from __future__ import annotations

import argparse
import subprocess
import tempfile
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.image import imread

PER_SHEET = 8


def make_sheets(video: Path, out_dir: Path, per_sheet: int = PER_SHEET) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run(
            ["ffmpeg", "-y", "-loglevel", "error", "-i", str(video), "-vf", "fps=1",
             str(Path(tmp) / "f%04d.jpg")],
            check=True,
        )
        frames = sorted(Path(tmp).glob("f*.jpg"))
        sheets = []
        for s, start in enumerate(range(0, len(frames), per_sheet)):
            chunk = frames[start:start + per_sheet]
            fig, axes = plt.subplots(2, 4, figsize=(14, 13))
            for ax in axes.ravel():
                ax.axis("off")
            for ax, (i, f) in zip(axes.ravel(), enumerate(chunk, start=start)):
                ax.imshow(imread(f))
                ax.set_title(f"t={i}s", fontsize=14)
            fig.tight_layout()
            path = out_dir / f"sheet_{s}.png"
            fig.savefig(path, dpi=60)
            plt.close(fig)
            sheets.append(path)
    return sheets


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("out_dir")
    a = ap.parse_args()
    for p in make_sheets(Path(a.video), Path(a.out_dir)):
        print(p)
