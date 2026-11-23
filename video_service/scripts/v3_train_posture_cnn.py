"""v3 多角度姿态（图像版）：在 DogPoseCV 的狗框裁图上微调一个小的预训练 CNN（timm），坐 / 站 / 趴。

关键点版（v3_train_posture.py）在俯拍的毛团幼犬上会把"坐"认成"趴"（腿被身体挡住），
图像版直接看外观。增强：随机旋转（任意角度，模拟俯拍朝向）、透视、镜像、颜色抖动、裁剪抖动。
切分与关键点版一致：按品种分组，20% 品种留作测试。

用法：python scripts/v3_train_posture_cnn.py [--arch mobilenetv3_large_100] [--epochs 6] [--save]
输出：pawcoach/pose/models/posture_cnn.pt（fp16 权重 + 类别 + 输入尺寸）
"""

from __future__ import annotations

import argparse
import sys
import time
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
DS = ROOT / "data/datasets/dogposecv"
CLASSES = ["down", "sit", "stand"]
SIZE = 192
CACHE = DS / f"crops_{SIZE}.npz"


def square_crop(img: Image.Image, box, pad: float = 0.12) -> Image.Image:
    x1, y1, x2, y2 = box
    cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
    s = max(x2 - x1, y2 - y1) * (1 + 2 * pad) / 2
    return img.crop((int(cx - s), int(cy - s), int(cx + s), int(cy + s))).resize((SIZE, SIZE), Image.BILINEAR)


def build_cache() -> None:
    d = np.load(DS / "keypoints.npz")
    images = {p.name: p for p in (DS / "data/images").rglob("*.jpg")}
    X = np.zeros((len(d["id"]), SIZE, SIZE, 3), np.uint8)
    for i, (iid, box) in enumerate(zip(d["id"], d["box"])):
        X[i] = np.asarray(square_crop(Image.open(images[str(iid)]).convert("RGB"), box))
    np.savez(CACHE, x=X, label=d["label"], id=d["id"])
    print("cached", X.shape)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--arch", default="mobilenetv3_large_100")
    ap.add_argument("--epochs", type=int, default=6)
    ap.add_argument("--save", action="store_true")
    a = ap.parse_args()
    import timm
    import torch
    import torch.nn.functional as F
    from torchvision.transforms import v2 as T

    if not CACHE.exists():
        build_cache()
    d = np.load(CACHE)
    X, lab, ids = d["x"], d["label"], d["id"]
    y = np.array([CLASSES.index(str(v)) for v in lab])
    breed = np.array([str(s).split("_")[0] for s in ids])
    rng = np.random.default_rng(0)
    bs = np.unique(breed)
    test_b = set(rng.choice(bs, size=len(bs) // 5, replace=False))
    te = np.array([b in test_b for b in breed])
    if a.save:  # 最终模型：全部数据
        te_eval = te.copy()
        tr = np.ones(len(y), bool)
    else:
        te_eval, tr = te, ~te

    dev = "mps" if torch.backends.mps.is_available() else "cpu"
    model = timm.create_model(a.arch, pretrained=True, num_classes=len(CLASSES)).to(dev)
    cfg = model.pretrained_cfg
    mean, std = torch.tensor(cfg["mean"]).view(1, 3, 1, 1).to(dev), torch.tensor(cfg["std"]).view(1, 3, 1, 1).to(dev)
    aug = T.Compose([
        T.RandomHorizontalFlip(),
        T.RandomApply([T.RandomRotation(180)], p=0.6),
        T.RandomPerspective(0.35, p=0.5),
        T.RandomResizedCrop(SIZE, scale=(0.7, 1.0), ratio=(0.8, 1.25)),
        T.ColorJitter(0.3, 0.3, 0.3, 0.05),
    ])
    opt = torch.optim.AdamW(model.parameters(), lr=1e-3, weight_decay=1e-4)
    idx_tr = np.where(tr)[0]
    steps = a.epochs * (len(idx_tr) // 64)
    sched = torch.optim.lr_scheduler.OneCycleLR(opt, max_lr=1e-3, total_steps=steps)
    w = torch.tensor(len(y) / (len(CLASSES) * np.bincount(y[tr])), dtype=torch.float32, device=dev)

    def batch(ix, train):
        xb = torch.from_numpy(X[ix]).permute(0, 3, 1, 2)
        if train:
            xb = torch.stack([aug(x) for x in xb])
        xb = xb.to(dev).float() / 255.0
        return (xb - mean) / std

    t0 = time.time()
    for ep in range(a.epochs):
        model.train()
        rng.shuffle(idx_tr)
        tot = 0.0
        for k in range(len(idx_tr) // 64):
            ix = idx_tr[k * 64:(k + 1) * 64]
            loss = F.cross_entropy(model(batch(ix, True)), torch.from_numpy(y[ix]).to(dev), weight=w,
                                   label_smoothing=0.05)
            opt.zero_grad(); loss.backward(); opt.step(); sched.step()
            tot += float(loss)
        print(f"epoch {ep + 1} loss {tot / max(1, len(idx_tr) // 64):.3f} {time.time() - t0:.0f}s", flush=True)

    model.eval()
    ix_te = np.where(te_eval)[0]
    preds, probs = [], []
    with torch.no_grad():
        for k in range(0, len(ix_te), 128):
            p = model(batch(ix_te[k:k + 128], False)).softmax(1).cpu().numpy()
            probs.append(p)
    P = np.concatenate(probs)
    pred = P.argmax(1)
    yt = y[ix_te]
    tag = "(训练集含测试品种，仅供参考)" if a.save else "(held-out breeds)"
    print("test acc", round(float((pred == yt).mean()), 3), tag)
    for th in (0.5, 0.6, 0.7, 0.8):
        m = P.max(1) >= th
        print(f"min_prob {th}: coverage {m.mean():.3f} acc {(pred[m] == yt[m]).mean():.3f}")
    from sklearn.metrics import confusion_matrix
    print(confusion_matrix(yt, pred))
    if a.save:
        out = ROOT / "pawcoach/pose/models/posture_cnn.pt"
        sd = {k: v.half().cpu() for k, v in model.state_dict().items()}
        torch.save({"arch": a.arch, "classes": CLASSES, "size": SIZE, "state_dict": sd,
                    "mean": cfg["mean"], "std": cfg["std"]}, out)
        print("saved", out, out.stat().st_size // 1024, "KB")


if __name__ == "__main__":
    main()
