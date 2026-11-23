"""v3 俯拍：在 DogPoseCV 训好的图像版上，加人工标注的俯拍 / 高角度照片继续微调。

训练数据：DogPoseCV 裁图（防止忘掉平视）+ tests/fixtures/topdown_*_labels.json 里的照片（每张过采样 --repeat 次）。
测试只用视频帧（训练里一帧都没有）：中文俯拍样片、Mixkit 俯拍 2 段、Mixkit 侧面 / 正面 19 段（看有没有退步）。

用法：python scripts/v3_finetune_topdown.py [--epochs 3] [--repeat 12] [--save]
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from scripts.v3_train_posture_cnn import CACHE, CLASSES, SIZE, square_crop  # noqa: E402

FIX = ROOT / "tests/fixtures"
SOURCES = {  # 标注文件 → 图片目录
    "topdown_openverse_labels.json": ROOT / "data/datasets/openverse/img",
    "topdown_commons_labels.json": ROOT / "data/datasets/commons/img",
}


def topdown_crops():
    from ultralytics import YOLO

    from pawcoach.pose.detect import DEFAULT_WEIGHTS

    yolo = YOLO(str(ROOT / DEFAULT_WEIGHTS))
    X, y = [], []
    for fn, d in SOURCES.items():
        if not (FIX / fn).exists():
            continue
        for name, item in json.loads((FIX / fn).read_text())["images"].items():
            p = d / name
            if not p.exists():
                continue
            img = Image.open(p).convert("RGB")
            r = yolo.predict(np.asarray(img), classes=[16], conf=0.3, verbose=False)[0]
            if not len(r.boxes):
                continue
            b = r.boxes.xyxy[int(((r.boxes.xyxy[:, 2] - r.boxes.xyxy[:, 0]) * (r.boxes.xyxy[:, 3] - r.boxes.xyxy[:, 1])).argmax())]
            X.append(np.asarray(square_crop(img, [float(v) for v in b])))
            y.append(CLASSES.index(item["label"]))
    return np.stack(X), np.array(y)


def eval_videos(model, dev, mean, std):
    """返回 {组: (对, 看不清, 错, 总)}，门槛 0.75，与线上一致。"""
    import cv2
    import torch

    from pawcoach.live.pose_live import PoseEngine

    eng = PoseEngine()
    eng.load()
    groups = {}
    spec = json.loads((FIX / "mixkit_pose_labels.json").read_text())["clips"]
    cases = []
    for vid, c in spec.items():
        path = ROOT / "data/datasets/mixkit" / Path(c["url"]).name
        for rng, lab in c["labels"].items():
            a, _, b = rng.partition("-")
            for s in range(int(a), int(b or a) + 1):
                cases.append((c["view"], path, s + 0.5, lab))
    zh = Path.home() / "Downloads/狗狗训练-中文1.mp4"
    if zh.exists():
        for k in range(4, 33):  # 每 0.5 秒，第 2–16 秒坐着
            cases.append(("top_zh", zh, k * 0.5, "sit"))
    caps = {}
    model.eval()
    for view, path, t, lab in cases:
        cap = caps.setdefault(str(path), cv2.VideoCapture(str(path)))
        cap.set(cv2.CAP_PROP_POS_MSEC, t * 1000)
        ok, bgr = cap.read()
        g = groups.setdefault(view, [0, 0, 0, 0, 0])  # 对 / 看不清 / 错 / 总 / 不设门槛时判对
        g[3] += 1
        if not ok:
            g[1] += 1
            continue
        rgb = cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB)
        got = eng.keypoints(rgb)
        if got is None:
            g[1] += 1
            continue
        crop = np.asarray(square_crop(Image.fromarray(rgb), got[1]))
        x = torch.from_numpy(crop).permute(2, 0, 1)[None].to(dev).float() / 255.0
        with torch.no_grad():
            p = model((x - mean) / std).softmax(1)[0].cpu().numpy()
        if CLASSES[int(p.argmax())] == lab:
            g[4] += 1
        if p.max() < 0.75:
            g[1] += 1
        elif CLASSES[int(p.argmax())] == lab:
            g[0] += 1
        else:
            g[2] += 1
    return groups


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--epochs", type=int, default=3)
    ap.add_argument("--repeat", type=int, default=12)
    ap.add_argument("--lr", type=float, default=2e-4)
    ap.add_argument("--save", action="store_true")
    ap.add_argument("--eval-only", action="store_true")
    ap.add_argument("--smooth", type=float, default=0.0)
    ap.add_argument("--base-per-epoch", type=int, default=3000)
    a = ap.parse_args()
    import timm
    import torch
    import torch.nn.functional as F
    from torchvision.transforms import v2 as T

    ck = torch.load(ROOT / "pawcoach/pose/models/posture_cnn.pt", map_location="cpu", weights_only=False)
    dev = "mps" if torch.backends.mps.is_available() else "cpu"
    model = timm.create_model(ck["arch"], pretrained=False, num_classes=len(CLASSES))
    model.load_state_dict({k: v.float() for k, v in ck["state_dict"].items()})
    model.to(dev)
    mean = torch.tensor(ck["mean"]).view(1, 3, 1, 1).to(dev)
    std = torch.tensor(ck["std"]).view(1, 3, 1, 1).to(dev)
    print("before:", eval_videos(model, dev, mean, std), flush=True)
    if a.eval_only:
        return

    td_x, td_y = topdown_crops()
    print("top-down photos:", len(td_y), {c: int((td_y == i).sum()) for i, c in enumerate(CLASSES)}, flush=True)
    d = np.load(CACHE)
    base_x = d["x"]
    base_y = np.array([CLASSES.index(str(v)) for v in d["label"]])
    rng = np.random.default_rng(0)
    aug = T.Compose([
        T.RandomHorizontalFlip(), T.RandomApply([T.RandomRotation(180)], p=0.7), T.RandomPerspective(0.3, p=0.5),
        T.RandomResizedCrop(SIZE, scale=(0.7, 1.0), ratio=(0.8, 1.25)), T.ColorJitter(0.3, 0.3, 0.3, 0.05),
    ])
    opt = torch.optim.AdamW(model.parameters(), lr=a.lr, weight_decay=1e-4)
    for ep in range(a.epochs):
        model.train()
        base_idx = rng.choice(len(base_y), size=a.base_per_epoch, replace=False)  # 每轮抽一部分平视数据防遗忘
        items = [(0, i) for i in base_idx] + [(1, i) for i in range(len(td_y)) for _ in range(a.repeat)]
        rng.shuffle(items)
        tot = 0.0
        for k in range(0, len(items) - 31, 32):
            chunk = items[k:k + 32]
            xs = torch.stack([aug(torch.from_numpy((base_x if s == 0 else td_x)[i]).permute(2, 0, 1)) for s, i in chunk])
            ys = torch.tensor([(base_y if s == 0 else td_y)[i] for s, i in chunk], device=dev)
            loss = F.cross_entropy(model(((xs.to(dev).float() / 255.0) - mean) / std), ys, label_smoothing=a.smooth)
            opt.zero_grad(); loss.backward(); opt.step()
            tot += float(loss)
        print(f"epoch {ep + 1} loss {tot / max(1, len(items) // 32):.3f}", flush=True)
    print("after:", eval_videos(model, dev, mean, std), flush=True)
    if a.save:
        out = ROOT / "pawcoach/pose/models/posture_cnn.pt"
        ck["state_dict"] = {k: v.half().cpu() for k, v in model.state_dict().items()}
        ck["topdown_finetune"] = {"photos": int(len(td_y)), "epochs": a.epochs, "repeat": a.repeat}
        torch.save(ck, out)
        print("saved", out)


if __name__ == "__main__":
    main()
