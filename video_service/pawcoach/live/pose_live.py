"""单帧姿态推理：一张 RGB 图 → 坐 / 站 / 看不清。

复用离线路径的全部判定：YOLOv8n 找狗（和 pose/detect.py 同一套类别与取舍），SuperAnimal rtmpose_s
只对狗框里的那块出 39 个关键点，再交给 pose/rules.py 的 classify_frame（同一组阈值）。
和离线路径的区别只有两点：逐帧调用而不是整段视频；时序平滑改由 live/tracker.py 做（因果的，只看已到的帧）。

实测（Apple M3 Max，MPS，352x640 竖屏）：YOLO 约 9 毫秒 + 关键点约 11 毫秒，一帧约 20 毫秒。
"""

from __future__ import annotations

import threading
from dataclasses import dataclass
from pathlib import Path

import numpy as np

from pawcoach.pose.detect import ANIMAL_CLASSES, DEFAULT_WEIGHTS, MIN_CONF
from pawcoach.pose.rules import PoseRules, classify_frame
from pawcoach.pose.superanimal import DEFAULT_DETECTOR, DEFAULT_MODEL, SUPERANIMAL

# 判坐只用两个点：脖根 neck_base 和尾根 tail_base（pose/rules.py）。实时路径单帧没有窗口投票兜底，
# 一个点置信度掉到 0.3 以下整帧就"看不清"，实测同一张图坐姿能认、换一张几乎一样的就认不出。
# 所以某个点不可靠时，用身上相邻、同样位于颈 / 尾部位的点顶替（取置信度最高且可靠的那个）。
# 只在原点不可靠时才顶替，原点可靠时结果和离线路径完全一致。
NECK_SUBSTITUTES = ("neck_base", "neck_end", "throat_base", "back_base")
TAIL_SUBSTITUTES = ("tail_base", "back_end")

# 狗框贴着画面边缘且很小：狗刚进入或正在离开，关键点不可信（与 pose/detect.py 的 in_frame_mask 同一条规则）
EDGE_PX = 2
MIN_EDGE_AREA_FRAC = 0.08


@dataclass
class FrameRead:
    label: str                                   # sit | stand | down | unclear
    conf: float
    box: tuple[float, float, float, float] | None  # 归一化 x1,y1,x2,y2；没找到狗为 None


class PoseEngine:
    """线程安全：一把锁串行化推理（同一时刻只有一路在用模型）。"""

    def __init__(self, rules: PoseRules | None = None, device: str = "auto", weights: str = DEFAULT_WEIGHTS):
        self.rules = rules or PoseRules()
        self._device = device
        self._weights = weights
        self._lock = threading.Lock()
        self._loaded = False
        self._yolo = None
        self._runner = None
        self._ix: dict[str, int] = {}

    @property
    def loaded(self) -> bool:
        return self._loaded

    def load(self) -> None:
        with self._lock:
            if self._loaded:
                return
            import warnings

            warnings.filterwarnings("ignore")
            import torch
            from deeplabcut.pose_estimation_pytorch.apis.utils import get_inference_runners
            from deeplabcut.pose_estimation_pytorch.config import PoseConfig
            from deeplabcut.pose_estimation_pytorch.modelzoo.utils import get_super_animal_snapshot_path
            from ultralytics import YOLO

            dev = self._device
            if dev == "auto":
                dev = "mps" if torch.backends.mps.is_available() else ("cuda" if torch.cuda.is_available() else "cpu")
            self._dev = dev
            cfg = PoseConfig.build_for_superanimal_inference(
                super_animal=SUPERANIMAL, model_name=DEFAULT_MODEL, detector_name=DEFAULT_DETECTOR,
                max_individuals=1, device=dev,
            )
            snap = get_super_animal_snapshot_path(dataset=SUPERANIMAL, model_name=DEFAULT_MODEL)
            det = get_super_animal_snapshot_path(dataset=SUPERANIMAL, model_name=DEFAULT_DETECTOR)
            runner, _ = get_inference_runners(
                model_config=cfg, snapshot_path=snap, max_individuals=1,
                num_bodyparts=len(cfg["metadata"]["bodyparts"]), num_unique_bodyparts=0,
                batch_size=1, detector_batch_size=1, detector_path=det,
            )
            self._ix = {n: i for i, n in enumerate(cfg["metadata"]["bodyparts"])}
            self._runner = runner
            self._yolo = YOLO(self._weights if Path(self._weights).exists() else "yolov8n.pt")
            self._loaded = True
            # 预热：第一次调用要编译 / 分配显存，别让它落在用户的第一帧上
            self._infer(np.zeros((320, 180, 3), np.uint8))

    def read(self, rgb: np.ndarray) -> FrameRead:
        """rgb：HxWx3 uint8，R G B 顺序。"""
        if not self._loaded:
            self.load()
        with self._lock:
            return self._infer(rgb)

    def keypoints(self, rgb: np.ndarray) -> tuple[np.ndarray, tuple[float, float, float, float]] | None:
        """原始关键点（39×3：x、y、置信度，像素坐标）和狗框（像素 x1,y1,x2,y2）；没找到狗为 None。
        给多角度姿态分类器的训练与推理用（pose/posture_model.py）。"""
        if not self._loaded:
            self.load()
        with self._lock:
            r = self._yolo.predict(
                rgb, classes=list(ANIMAL_CLASSES), conf=MIN_CONF, verbose=False, device=self._dev
            )[0]
            if not len(r.boxes):
                return None
            i = int(r.boxes.conf.argmax())
            x1, y1, x2, y2 = (float(v) for v in r.boxes.xyxy[i].tolist())
            out = self._runner.inference(images=[(rgb, {"bboxes": np.array([[x1, y1, x2 - x1, y2 - y1]])})])
            return np.asarray(out[0]["bodyparts"])[0], (x1, y1, x2, y2)

    @property
    def bodyparts(self) -> list[str]:
        return sorted(self._ix, key=self._ix.get)

    # ----- 内部：调用方持锁 -----
    def _infer(self, rgb: np.ndarray) -> FrameRead:
        h, w = rgb.shape[:2]
        r = self._yolo.predict(
            rgb, classes=list(ANIMAL_CLASSES), conf=MIN_CONF, verbose=False, device=self._dev
        )[0]
        if not len(r.boxes):
            return FrameRead("unclear", 0.0, None)
        i = int(r.boxes.conf.argmax())
        x1, y1, x2, y2 = (float(v) for v in r.boxes.xyxy[i].tolist())
        box = (max(0.0, x1 / w), max(0.0, y1 / h), min(1.0, x2 / w), min(1.0, y2 / h))

        area = (x2 - x1) * (y2 - y1) / float(w * h)
        edge = x1 <= EDGE_PX or y1 <= EDGE_PX or x2 >= w - EDGE_PX or y2 >= h - EDGE_PX
        if edge and area < MIN_EDGE_AREA_FRAC:
            return FrameRead("unclear", float(r.boxes.conf[i]), box)

        out = self._runner.inference(images=[(rgb, {"bboxes": np.array([[x1, y1, x2 - x1, y2 - y1]])})])
        kp = np.asarray(out[0]["bodyparts"])[0]            # (39, 3)：x, y, 置信度
        xy, cf = self._substitute(kp[:, :2].copy(), kp[:, 2].copy())
        label, conf = classify_frame(xy, cf, self._ix, float(min(w, h)), self.rules)
        # v3：规则判不了（正面 / 俯拍）时用多角度分类器（和离线路径同一套合用规则）
        from pawcoach.pose.posture_model import default_cnn, default_model
        from pawcoach.pose.rules import _hybrid, merge_read

        if label != "sit":
            cnn = default_cnn()
            if cnn is not None:
                label, conf = merge_read(label, conf, cnn.predict(rgb, (x1, y1, x2, y2)), cf, self.rules)
            elif (posture := default_model()) is not None:
                label, conf = _hybrid(label, conf, xy, cf, self.bodyparts, posture, self.rules)
        return FrameRead(label, conf, box)

    def _substitute(self, xy: np.ndarray, cf: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
        floor = self.rules.min_kp_conf
        for slot, names in (("neck_base", NECK_SUBSTITUTES), ("tail_base", TAIL_SUBSTITUTES)):
            si = self._ix[slot]
            if cf[si] >= floor:
                continue
            best = max(names, key=lambda n: cf[self._ix[n]])
            bi = self._ix[best]
            if cf[bi] >= floor:
                xy[si], cf[si] = xy[bi], cf[bi]
        return xy, cf
