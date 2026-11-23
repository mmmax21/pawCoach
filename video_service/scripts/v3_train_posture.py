"""v3 多角度姿态：用 scripts/v3_extract_dogpose.py 抽好的关键点训练分类器并评估。

按品种分组切分（测试集里的品种训练时没见过），避免同一品种的相似照片同时出现在两边。
增强：左右镜像；可选随机平面旋转（--rot-frac，模拟俯拍朝向任意）。
输出：pawcoach/pose/models/posture_hgb.joblib 与评估数字（打印，手动整理进 reports/V3-posture.md）。
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from pawcoach.pose.posture_model import CLASSES, MODEL_PATH, features, flip_kp, rotate_kp  # noqa: E402


def build(kps, whs, rng, rot_frac: float, flip: bool = True):
    X, idx = [], []
    for i, (kp, wh) in enumerate(zip(kps, whs)):
        variants = [kp] + ([flip_kp(kp, wh[0])] if flip else [])
        for v in variants:
            X.append(features(v)); idx.append(i)
            if rot_frac and rng.random() < rot_frac:
                c = (float(v[:, 0].mean()), float(v[:, 1].mean()))
                X.append(features(rotate_kp(v, c, rng.uniform(-180, 180)))); idx.append(i)
    return np.stack(X), np.array(idx)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--data", default=str(ROOT / "data/datasets/dogposecv/keypoints.npz"))
    ap.add_argument("--rot-frac", type=float, default=0.5)
    ap.add_argument("--min-kpts", type=int, default=12)
    ap.add_argument("--save", action="store_true")
    a = ap.parse_args()

    from sklearn.ensemble import HistGradientBoostingClassifier
    from sklearn.metrics import classification_report, confusion_matrix

    d = np.load(a.data)
    kp, wh, lab, ids = d["kp"], d["wh"], d["label"], d["id"]
    keep = (kp[:, :, 2] >= 0.3).sum(1) >= a.min_kpts
    kp, wh, lab, ids = kp[keep], wh[keep], lab[keep], ids[keep]
    breed = np.array([s.split("_")[0] for s in ids])
    rng = np.random.default_rng(0)
    breeds = np.unique(breed)
    test_breeds = set(rng.choice(breeds, size=len(breeds) // 5, replace=False))
    te = np.array([b in test_breeds for b in breed])
    print(f"samples {len(kp)} (dropped {int((~keep).sum())} with < {a.min_kpts} kpts); "
          f"train {int((~te).sum())} test {int(te.sum())}; classes",
          {c: int((lab == c).sum()) for c in CLASSES})

    Xtr, itr = build(kp[~te], wh[~te], rng, a.rot_frac)
    ytr = lab[~te][itr]
    clf = HistGradientBoostingClassifier(max_iter=400, learning_rate=0.08, max_leaf_nodes=31,
                                         l2_regularization=1.0, class_weight="balanced", random_state=0)
    clf.fit(Xtr, ytr)

    Xte = np.stack([features(k) for k in kp[te]])
    yte = lab[te]
    pred = clf.predict(Xte)
    print("== test (held-out breeds, original orientation)")
    print(classification_report(yte, pred, digits=3))
    print(confusion_matrix(yte, pred, labels=list(CLASSES)))
    Xrot = np.stack([features(rotate_kp(k, (float(k[:, 0].mean()), float(k[:, 1].mean())), rng.uniform(-180, 180)))
                     for k in kp[te]])
    pr = clf.predict(Xrot)
    print("== test rotated randomly (proxy for top-down orientation)  acc", round(float((pr == yte).mean()), 3))
    proba = clf.predict_proba(Xte).max(1)
    for th in (0.5, 0.6, 0.7, 0.8):
        m = proba >= th
        print(f"min_prob {th}: coverage {m.mean():.3f} acc {(pred[m] == yte[m]).mean():.3f}")

    # 和 v3 之前的规则比（同一批测试图）：规则判不了 → unclear；合用 = pose/rules.py 的 _hybrid
    from collections import Counter

    from pawcoach.pose.posture_model import IX, NAMES, PostureModel
    from pawcoach.pose.rules import PoseRules, _hybrid, classify_frame

    held = PostureModel.__new__(PostureModel)
    held.model, held.classes, held.min_prob, held.min_kpts = clf, list(clf.classes_), 0.6, 12
    rules = PoseRules()
    tally = {"rules": Counter(), "hybrid": Counter()}
    for k, w, y in zip(kp[te], wh[te], yte):
        rl, c = classify_frame(k[:, :2], k[:, 2], IX, float(min(w)), rules)
        hl, _ = _hybrid(rl, c, k[:, :2], k[:, 2], NAMES, held, rules)
        for name, x in (("rules", rl), ("hybrid", hl)):
            tally[name]["correct" if x == y else ("unclear" if x == "unclear" else "wrong")] += 1
    for name, c in tally.items():
        print(f"== {name}: {dict(c)} of {sum(c.values())}")

    if a.save:
        import joblib
        Xte2, ite2 = build(kp[te], wh[te], rng, a.rot_frac)  # 最终模型用全部数据重训
        clf.fit(np.concatenate([Xtr, Xte2]), np.concatenate([ytr, lab[te][ite2]]))
        MODEL_PATH.parent.mkdir(parents=True, exist_ok=True)
        joblib.dump({"model": clf, "classes": list(clf.classes_)}, MODEL_PATH, compress=3)
        print("saved", MODEL_PATH, MODEL_PATH.stat().st_size // 1024, "KB")


if __name__ == "__main__":
    main()
