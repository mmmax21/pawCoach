"""v3 多角度姿态分类器：39 个 SuperAnimal 关键点 → 坐 / 站 / 趴（任意机位）。

为什么要它：pose/rules.py 的规则只看"脖根到尾根的体轴有多竖"，只在侧面成立；
正面、斜前方、从上往下拍时体轴的竖直程度看不出来，只能输出 unclear，用户只好重拍。

做法：在公开数据集 DogPoseCV（Stanford Dogs 子集，约 1.4 万张标注了 standing / sitting / lying 的照片，
各种机位、品种都有，Apache-2.0）上，先跑和线上同一套 YOLO + SuperAnimal 拿到关键点，
再训练一个梯度提升树（scikit-learn）。训练脚本：scripts/v3_train_posture.py；评估：reports/V3-posture.md。

特征分两组，都只用关键点，不看像素：
1. 以狗框为参照的归一化坐标 + 置信度（保留"上下"方向：平视拍时重力方向是很强的线索）；
2. 与画面旋转无关的量：关键关节两两距离 / 体长、几个关节角（俯拍时狗在画面里朝向任意，
   只能靠"腿收没收起来、身体蜷没蜷"这类形状来判断）。
训练时做两种增强：左右镜像（所有样本），以及随机平面旋转（一部分样本，模拟俯拍朝向任意）。

输出带概率；概率低于 min_prob 时当作看不清（unclear），由调用方决定要不要再交给视觉大模型兜底。
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from pathlib import Path

import numpy as np

MODEL_PATH = Path(__file__).resolve().parent / "models" / "posture_hgb.joblib"
CLASSES = ("down", "sit", "stand")
MIN_KP_CONF = 0.3

NAMES = [
    "nose", "upper_jaw", "lower_jaw", "mouth_end_right", "mouth_end_left", "right_eye", "right_earbase",
    "right_earend", "right_antler_base", "right_antler_end", "left_eye", "left_earbase", "left_earend",
    "left_antler_base", "left_antler_end", "neck_base", "neck_end", "throat_base", "throat_end", "back_base",
    "back_end", "back_middle", "tail_base", "tail_end", "front_left_thai", "front_left_knee", "front_left_paw",
    "front_right_thai", "front_right_knee", "front_right_paw", "back_left_paw", "back_left_thai",
    "back_right_thai", "back_left_knee", "back_right_knee", "back_right_paw", "belly_bottom",
    "body_middle_right", "body_middle_left",
]
IX = {n: i for i, n in enumerate(NAMES)}
# 鹿角点对狗没有意义，不用
USED = [i for i, n in enumerate(NAMES) if "antler" not in n]

# 左右互换（镜像增强）
_FLIP = list(range(len(NAMES)))
for _i, _n in enumerate(NAMES):
    for a, b in (("left", "right"), ("right", "left")):
        if a in _n:
            _FLIP[_i] = IX[_n.replace(a, b)]

# 与旋转无关的特征用到的关节：头、颈、背、尾、四肢
_CORE = [
    "nose", "neck_base", "back_middle", "tail_base", "throat_base", "belly_bottom",
    "front_left_thai", "front_left_knee", "front_left_paw", "front_right_thai", "front_right_knee",
    "front_right_paw", "back_left_thai", "back_left_knee", "back_left_paw", "back_right_thai",
    "back_right_knee", "back_right_paw",
]
_CORE_IX = [IX[n] for n in _CORE]
_PAIRS = [(a, b) for k, a in enumerate(_CORE_IX) for b in _CORE_IX[k + 1:]]
_ANGLES = [  # (a, 顶点, b)
    ("front_left_thai", "front_left_knee", "front_left_paw"),
    ("front_right_thai", "front_right_knee", "front_right_paw"),
    ("back_left_thai", "back_left_knee", "back_left_paw"),
    ("back_right_thai", "back_right_knee", "back_right_paw"),
    ("neck_base", "back_middle", "tail_base"),
    ("nose", "neck_base", "back_middle"),
    ("back_middle", "tail_base", "back_left_paw"),
    ("back_middle", "tail_base", "back_right_paw"),
    ("back_middle", "neck_base", "front_left_paw"),
    ("back_middle", "neck_base", "front_right_paw"),
]
_ANGLE_IX = [(IX[a], IX[v], IX[b]) for a, v, b in _ANGLES]


def flip_kp(kp: np.ndarray, width: float) -> np.ndarray:
    """左右镜像：x → width - x，并交换左右关键点。kp: (39, 3)。"""
    out = kp[_FLIP].copy()
    out[:, 0] = width - out[:, 0]
    return out


def rotate_kp(kp: np.ndarray, center: tuple[float, float], deg: float) -> np.ndarray:
    th = math.radians(deg)
    c, s = math.cos(th), math.sin(th)
    out = kp.copy()
    x = kp[:, 0] - center[0]
    y = kp[:, 1] - center[1]
    out[:, 0] = center[0] + c * x - s * y
    out[:, 1] = center[1] + s * x + c * y
    return out


def _box_of(kp: np.ndarray) -> tuple[float, float, float, float]:
    ok = kp[:, 2] >= MIN_KP_CONF
    pts = kp[ok, :2] if ok.sum() >= 3 else kp[:, :2]
    x1, y1 = pts.min(0)
    x2, y2 = pts.max(0)
    return float(x1), float(y1), float(x2), float(y2)


def features(kp: np.ndarray) -> np.ndarray:
    """一只狗一帧的特征向量。kp: (39, 3) 像素坐标 + 置信度。

    框用可靠关键点的外接框（不用检测框）：旋转增强后检测框不再贴合，关键点框始终一致。
    """
    kp = np.asarray(kp, dtype=np.float64)
    conf = kp[:, 2]
    ok = conf >= MIN_KP_CONF
    x1, y1, x2, y2 = _box_of(kp)
    cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
    scale = max(x2 - x1, y2 - y1, 1e-6)
    xy = (kp[:, :2] - (cx, cy)) / scale
    xy[~ok] = 0.0

    f: list[float] = []
    # 1) 方向相关：归一化坐标 + 置信度 + 框长宽比
    for i in USED:
        f += [xy[i, 0], xy[i, 1], conf[i]]
    f.append((x2 - x1) / max(y2 - y1, 1e-6))
    f.append(float(ok.sum()) / len(NAMES))

    # 体长：脖根到尾根（缺一个就用背中点顶替），再不行用框的尺度
    def pt(n: str):
        i = IX[n]
        return kp[i, :2] if ok[i] else None

    nb = pt("neck_base") if pt("neck_base") is not None else pt("back_base")
    tb = pt("tail_base") if pt("tail_base") is not None else pt("back_end")
    body = float(np.hypot(*(tb - nb))) if nb is not None and tb is not None else 0.0
    norm = body if body > 0.05 * scale else scale
    f.append(body / scale)
    # 规则里的体轴倾角 h（侧面最强的线索），缺失时 0 + 标记
    if nb is not None and tb is not None and body > 0:
        f += [(tb[1] - nb[1]) / body, 1.0]
    else:
        f += [0.0, 0.0]

    # 2) 与旋转无关：关节两两距离 / 体长（缺失为 -1）、关节角（缺失为 -1）
    for a, b in _PAIRS:
        f.append(float(np.hypot(*(kp[a, :2] - kp[b, :2]))) / norm if ok[a] and ok[b] else -1.0)
    for a, v, b in _ANGLE_IX:
        if ok[a] and ok[v] and ok[b]:
            u, w = kp[a, :2] - kp[v, :2], kp[b, :2] - kp[v, :2]
            den = float(np.linalg.norm(u) * np.linalg.norm(w))
            f.append(float(np.arccos(np.clip(np.dot(u, w) / den, -1, 1))) / math.pi if den > 0 else -1.0)
        else:
            f.append(-1.0)
    return np.asarray(f, dtype=np.float32)


@dataclass
class PostureRead:
    label: str        # sit | stand | down | unclear
    prob: float       # 最高类别的概率
    probs: dict[str, float]


_DEFAULT: "PostureModel | None | bool" = False


def default_model() -> "PostureModel | None":
    """进程内共享的模型；模型文件或 scikit-learn 不在时返回 None（退回只用规则）。
    环境变量 POSTURE_MODEL=off 可关掉。"""
    global _DEFAULT
    if _DEFAULT is False:
        import os

        if os.environ.get("POSTURE_MODEL", "").lower() == "off" or not MODEL_PATH.exists():
            _DEFAULT = None
        else:
            try:
                _DEFAULT = PostureModel()
            except Exception:  # noqa: BLE001  缺 sklearn / 版本不兼容：只用规则
                _DEFAULT = None
    return _DEFAULT


def kp_in_model_order(xy: np.ndarray, conf: np.ndarray, names: list[str]) -> np.ndarray:
    """任意顺序的关键点 → 模型的 39 点顺序（缺的点置信度为 0）。"""
    out = np.zeros((len(NAMES), 3), dtype=np.float64)
    for j, n in enumerate(names):
        i = IX.get(n)
        if i is not None:
            out[i, :2] = xy[j]
            out[i, 2] = conf[j]
    return out


class PostureModel:
    def __init__(self, path: Path | str = MODEL_PATH, min_prob: float = 0.6, min_kpts: int = 12):
        import joblib

        bundle = joblib.load(path)
        self.model = bundle["model"]
        self.classes = list(bundle["classes"])
        self.min_prob = min_prob
        self.min_kpts = min_kpts

    @classmethod
    def available(cls, path: Path | str = MODEL_PATH) -> bool:
        return Path(path).exists()

    def predict(self, kp: np.ndarray) -> PostureRead:
        kp = np.asarray(kp)
        if int((kp[:, 2] >= MIN_KP_CONF).sum()) < self.min_kpts:
            return PostureRead("unclear", 0.0, {})
        p = self.model.predict_proba(features(kp)[None])[0]
        probs = {c: float(v) for c, v in zip(self.classes, p)}
        best = max(probs, key=probs.get)
        if probs[best] < self.min_prob:
            return PostureRead("unclear", probs[best], probs)
        return PostureRead(best, probs[best], probs)

    def predict_many(self, kps: np.ndarray) -> list[PostureRead]:
        return [self.predict(k) for k in kps]


CNN_PATH = Path(__file__).resolve().parent / "models" / "posture_cnn.pt"


class PostureCNN:
    """图像版多角度姿态分类（scripts/v3_train_posture_cnn.py 训练）：狗框裁图 → 坐 / 站 / 趴。"""

    def __init__(self, path: Path | str = CNN_PATH, min_prob: float = 0.6, device: str = "auto"):
        import timm
        import torch

        ck = torch.load(path, map_location="cpu", weights_only=False)
        self.classes = list(ck["classes"])
        self.size = int(ck["size"])
        if device == "auto":
            device = "mps" if torch.backends.mps.is_available() else "cpu"
        self.dev = device
        self.model = timm.create_model(ck["arch"], pretrained=False, num_classes=len(self.classes))
        self.model.load_state_dict({k: v.float() for k, v in ck["state_dict"].items()})
        self.model.eval().to(device)
        self.mean = torch.tensor(ck["mean"]).view(1, 3, 1, 1).to(device)
        self.std = torch.tensor(ck["std"]).view(1, 3, 1, 1).to(device)
        self.min_prob = min_prob

    @classmethod
    def available(cls, path: Path | str = CNN_PATH) -> bool:
        return Path(path).exists()

    def crop(self, rgb: np.ndarray, box, pad: float = 0.12) -> np.ndarray:
        from PIL import Image

        x1, y1, x2, y2 = box
        cx, cy = (x1 + x2) / 2, (y1 + y2) / 2
        s = max(x2 - x1, y2 - y1) * (1 + 2 * pad) / 2
        img = Image.fromarray(rgb).crop((int(cx - s), int(cy - s), int(cx + s), int(cy + s)))
        return np.asarray(img.resize((self.size, self.size), Image.BILINEAR))

    def predict(self, rgb: np.ndarray, box) -> PostureRead:
        import torch

        x = torch.from_numpy(self.crop(rgb, box)).permute(2, 0, 1)[None].to(self.dev).float() / 255.0
        with torch.no_grad():
            p = self.model((x - self.mean) / self.std).softmax(1)[0].cpu().numpy()
        probs = {c: float(v) for c, v in zip(self.classes, p)}
        best = max(probs, key=probs.get)
        return PostureRead(best if probs[best] >= self.min_prob else "unclear", probs[best], probs)


_CNN: "PostureCNN | None | bool" = False
CNN_MIN_PROB = 0.75  # 俯拍样片上 0.75 以上没有判错（reports/V3-posture.md）


def default_cnn() -> "PostureCNN | None":
    """进程内共享的图像分类器；模型文件或 timm 不在、或 POSTURE_MODEL=off 时为 None。"""
    global _CNN
    if _CNN is False:
        import os

        if os.environ.get("POSTURE_MODEL", "").lower() == "off" or not CNN_PATH.exists():
            _CNN = None
        else:
            try:
                _CNN = PostureCNN(min_prob=CNN_MIN_PROB)
            except Exception:  # noqa: BLE001
                _CNN = None
    return _CNN


def refine_with_images(video_path, track: np.ndarray, kp, rules):
    """离线路径：规则没判成"坐"的帧，按顺序解码视频、用狗框裁图交给图像分类器补判。

    track：detect_main_dog 的逐帧 [conf, x1, y1, x2, y2]（没有狗的帧是 NaN）。
    返回 refine(labels, confs) 函数，给 rules.keypoints_to_segments 用；没有图像分类器时返回 None。
    """
    cnn = default_cnn()
    if cnn is None:
        return None

    def refine(labels, confs):
        import cv2

        from pawcoach.pose.rules import merge_read

        need = {i for i, lab in enumerate(labels) if lab != "sit" and i < len(track) and not np.isnan(track[i, 1])}
        if not need:
            return labels, confs
        labels, confs = list(labels), np.array(confs, dtype=float)
        cap = cv2.VideoCapture(str(video_path))
        i = 0
        last = max(need)
        while i <= last:
            ok, bgr = cap.read()
            if not ok:
                break
            if i in need:
                read = cnn.predict(cv2.cvtColor(bgr, cv2.COLOR_BGR2RGB), track[i, 1:5])
                labels[i], confs[i] = merge_read(labels[i], float(confs[i]), read, kp.conf[i], rules)
            i += 1
        cap.release()
        return labels, confs

    return refine
