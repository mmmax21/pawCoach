"""v3 俯拍标注辅助：把一批图片拼成带编号的标注图（每张 6×5），人工看图后在 labels JSON 里写标签。

用法：python scripts/v3_label_sheets.py <图片目录> <输出目录>
输出 sheet_XX.jpg 与 index.json（编号 → 文件名）。
"""

from __future__ import annotations

import json
import sys
from pathlib import Path

import cv2
import numpy as np

TILE = 240


def main() -> None:
    src, out = Path(sys.argv[1]), Path(sys.argv[2])
    out.mkdir(parents=True, exist_ok=True)
    files = sorted(src.glob("*.jpg"))
    index, tiles = {}, []
    for k, f in enumerate(files):
        img = cv2.imread(str(f))
        if img is None:
            continue
        h, w = img.shape[:2]
        s = TILE / max(h, w)
        img = cv2.resize(img, (max(1, int(w * s)), max(1, int(h * s))))
        t = np.full((TILE, TILE, 3), 30, np.uint8)
        t[: img.shape[0], : img.shape[1]] = img
        n = len(index)
        cv2.rectangle(t, (0, 0), (52, 22), (0, 0, 0), -1)
        cv2.putText(t, str(n), (3, 17), cv2.FONT_HERSHEY_SIMPLEX, 0.6, (0, 255, 255), 2)
        index[n] = f.name
        tiles.append(t)
    per = 30
    for p in range(0, len(tiles), per):
        chunk = tiles[p:p + per]
        while len(chunk) < per:
            chunk.append(np.zeros((TILE, TILE, 3), np.uint8))
        rows = [np.hstack(chunk[r * 6:(r + 1) * 6]) for r in range(5)]
        cv2.imwrite(str(out / f"sheet_{p // per:02d}.jpg"), np.vstack(rows), [cv2.IMWRITE_JPEG_QUALITY, 78])
    (out / "index.json").write_text(json.dumps(index, ensure_ascii=False))
    print(len(index), "images,", (len(tiles) + per - 1) // per, "sheets")


if __name__ == "__main__":
    main()
