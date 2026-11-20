"""取景自检：单帧检测结果 → 能不能开录。

实时引导用。手机每隔约 0.3 秒传一帧小图到 /frame-check，服务端用 YOLO 找狗和人，
再按「机位」（侧拍 side / 俯拍 top）的取景契约判定红 / 黄 / 绿，并给出一句改进提示。

判定本身是纯函数 `judge_frame`，输入是检测框和画面尺寸，不依赖 ultralytics，.venv 里能单测。
推理 `detect_frame` 才需要 ultralytics。

阈值来自两段真实视频的实测（侧拍：宠物狗训练模拟1，俯拍：狗狗训练-中文1），样本很少，
不要当作通用值；每个阈值都放在 `FramingSpec` 里，调整不动逻辑。
"""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Literal

import numpy as np

View = Literal["side", "top"]
Level = Literal["green", "yellow", "red"]

# COCO 类别号：person=0、cat=15、dog=16。狗和猫一起收，理由见 pawcoach/pose/detect.py（柯利犬常被认成 cat）。
PERSON_CLASS = 0
DOG_CLASSES = (15, 16)
MIN_CONF = 0.25

Box = tuple[float, float, float, float]  # x1, y1, x2, y2，像素


@dataclass(frozen=True)
class FramingSpec:
    """一种机位的取景契约。比例都相对画面宽 / 高。"""

    view: View
    # 引导框（归一化，x1, y1, x2, y2）。App 把它画在预览上，主人把狗放进框里。
    guide: tuple[float, float, float, float]
    # 狗框面积落在引导框内的比例（inside = 交集 / 狗框面积）。引导框是「放狗的区域」不是模板：
    # 坐姿的狗又窄又高、站姿又扁又长，用 IoU 会把坐下误判成没对准，所以按"狗在不在区域里"判。
    # inside 达到 min_inside_green 且狗框中心在引导框内 = 对准；低于 min_inside_yellow = 完全没对准。
    min_inside_green: float
    min_inside_yellow: float
    # 狗框宽度占画面宽度的范围：太小说明离得远，太大说明离得近
    dog_width_range: tuple[float, float]
    # 狗框宽高比（宽/高）。侧拍要同时容纳站姿（横长，约 1.5~2.5）和坐姿（竖长，约 0.6~0.9）：
    # 坐下正是这个功能要教的动作，不能让它触发"轮廓异常"。下限 0.45 取自实测坐姿中位 0.77、p10 0.48 再略放宽；
    # 上限只用来拦"整条狗被拉成一条线"这类明显失真。样本只有两段视频，别当通用值。
    dog_aspect_range: tuple[float, float]
    # 狗框贴到画面边缘多少比例以内，算「被截断」
    edge_margin: float = 0.01
    # 是否要求主人入画
    need_person: bool = True
    # 手机应当竖屏还是横屏（画面宽 > 高 为横屏）
    landscape: bool = False


# App 的取景页锁竖屏，M5 实测能出结果的侧拍视频也是竖屏（352x640），所以侧拍和俯拍都按竖屏画引导框。
# 侧拍：狗侧身横向放在画面中下部，上方留给主人；俯拍：狗在画面偏上，下方留给手。
# 尺寸比例是照实测中位数放宽的，样本只有两段视频，别当通用值。
SPECS: dict[str, FramingSpec] = {
    "side": FramingSpec(
        view="side",
        guide=(0.08, 0.40, 0.92, 0.80),
        min_inside_green=0.75,
        min_inside_yellow=0.40,
        dog_width_range=(0.20, 0.90),
        dog_aspect_range=(0.45, 3.2),
        landscape=False,
    ),
    "top": FramingSpec(
        view="top",
        guide=(0.10, 0.12, 0.90, 0.62),
        min_inside_green=0.75,
        min_inside_yellow=0.40,
        dog_width_range=(0.45, 0.95),
        dog_aspect_range=(0.45, 2.0),
        landscape=False,
    ),
}


@dataclass
class Detection:
    conf: float
    box: Box


@dataclass
class FrameVerdict:
    level: Level
    # 一句话，直接显示给主人；绿灯时是确认语
    message: str
    # 机器可读的原因，App 与测试都按它判断，不要靠 message 文案
    reasons: list[str] = field(default_factory=list)
    dog_box: Box | None = None       # 归一化坐标 0~1
    person_box: Box | None = None
    guide: tuple[float, float, float, float] = (0, 0, 1, 1)
    inside: float = 0.0   # 狗框落在引导框内的比例，0~1

    def to_dict(self) -> dict:
        return {
            "level": self.level,
            "message": self.message,
            "reasons": self.reasons,
            "dog_box": list(self.dog_box) if self.dog_box else None,
            "person_box": list(self.person_box) if self.person_box else None,
            "guide": list(self.guide),
            "inside": round(self.inside, 3),
        }


MESSAGES = {
    "no_dog": "画面里没找到狗，请让狗进入画面",
    "dog_cut": "狗被画面边缘截断了，请退后一点让狗完整入画",
    "dog_small": "狗太小，请靠近一点",
    "dog_big": "狗太大，请退后一点",
    "bad_aspect": "看不出狗的整体轮廓，请让狗站直、正对取景框",
    "misaligned": "请把狗放进框里",
    "no_person": "没看到主人，请让手和上身入画",
    "wrong_orientation_landscape": "建议把手机横过来拍",
    "wrong_orientation_portrait": "建议把手机竖过来拍，狗和手更清楚",
    "ok": "取景合适，可以开始",
}


def iou(a: Box, b: Box) -> float:
    ix1, iy1 = max(a[0], b[0]), max(a[1], b[1])
    ix2, iy2 = min(a[2], b[2]), min(a[3], b[3])
    inter = max(0.0, ix2 - ix1) * max(0.0, iy2 - iy1)
    union = (a[2] - a[0]) * (a[3] - a[1]) + (b[2] - b[0]) * (b[3] - b[1]) - inter
    return float(inter / union) if union > 0 else 0.0


def inside_fraction(box: Box, region: Box) -> float:
    """box 的面积有多少落在 region 里（0~1）。box 面积为 0 时返回 0。"""
    ix1, iy1 = max(box[0], region[0]), max(box[1], region[1])
    ix2, iy2 = min(box[2], region[2]), min(box[3], region[3])
    inter = max(0.0, ix2 - ix1) * max(0.0, iy2 - iy1)
    area = max(0.0, box[2] - box[0]) * max(0.0, box[3] - box[1])
    return float(inter / area) if area > 0 else 0.0


def _norm(box: Box, w: int, h: int) -> Box:
    return (box[0] / w, box[1] / h, box[2] / w, box[3] / h)


def pick_main_dog(dogs: list[Detection]) -> Detection | None:
    """多只候选里选主狗：面积 × 置信度最大，与 pawcoach.pose.detect.select_main_dog 冷启动一致。"""
    dogs = [d for d in dogs if d.conf >= MIN_CONF]
    if not dogs:
        return None
    return max(dogs, key=lambda d: d.conf * max(0.0, (d.box[2] - d.box[0]) * (d.box[3] - d.box[1])))


def judge_frame(
    view: str,
    width: int,
    height: int,
    dogs: list[Detection],
    persons: list[Detection],
    spec: FramingSpec | None = None,
) -> FrameVerdict:
    """按机位的取景契约判定一帧。

    判定顺序即提示优先级：先说最基础、主人最容易改的问题（手机方向），再说狗的位置，最后说主人。
    红灯 = 不建议开录（狗没找到 / 被截断 / 方向不对）；黄灯 = 能录但可能判不准；绿灯 = 合格。
    """
    spec = spec or SPECS[view]
    guide = spec.guide
    reasons: list[str] = []
    red = False

    # 1. 手机方向。只是建议，不拦：M5 实测能出结果的侧拍视频就是竖屏（352x640），硬拦会挡掉已知可用的拍法。
    #    横屏的好处是 2 米外能同时容纳狗和主人，所以提示，但不算红灯。
    is_landscape = width > height
    if spec.landscape != is_landscape:
        reasons.append("wrong_orientation")

    # 2. 狗
    dog = pick_main_dog(dogs)
    if dog is None:
        return FrameVerdict("red", MESSAGES["no_dog"], [*reasons, "no_dog"], guide=guide)
    dn = _norm(dog.box, width, height)
    dw, dh = dn[2] - dn[0], dn[3] - dn[1]

    m = spec.edge_margin
    if dn[0] <= m or dn[1] <= m or dn[2] >= 1 - m or dn[3] >= 1 - m:
        # 贴边：狗不完整，姿态和对齐都不可信
        reasons.append("dog_cut")
        red = True

    if dw < spec.dog_width_range[0]:
        reasons.append("dog_small")
    elif dw > spec.dog_width_range[1]:
        reasons.append("dog_big")

    aspect = dw * width / max(1e-6, dh * height)
    if not spec.dog_aspect_range[0] <= aspect <= spec.dog_aspect_range[1]:
        reasons.append("bad_aspect")

    inside = inside_fraction(dn, guide)
    cx, cy = (dn[0] + dn[2]) / 2, (dn[1] + dn[3]) / 2
    center_in = guide[0] <= cx <= guide[2] and guide[1] <= cy <= guide[3]
    if inside < spec.min_inside_yellow:
        reasons.append("misaligned")
    elif inside < spec.min_inside_green or not center_in:
        reasons.append("misaligned_slight")

    # 3. 主人
    person = max(persons, key=lambda d: d.conf, default=None) if persons else None
    pn = _norm(person.box, width, height) if person is not None and person.conf >= MIN_CONF else None
    if spec.need_person and pn is None:
        reasons.append("no_person")

    # 级别：截断 / 离得太远太近 / 完全没对准 = 红；轻微没对准、没看到人、轮廓怪 = 黄
    hard = {"dog_cut", "dog_small", "dog_big", "misaligned"}
    level: Level = "red" if (red or any(r in hard for r in reasons)) else ("yellow" if reasons else "green")

    # 提示只说一件事：按优先级挑第一个
    priority = ["dog_cut", "dog_small", "dog_big", "misaligned", "bad_aspect", "no_person", "misaligned_slight", "wrong_orientation"]
    first = next((r for r in priority if r in reasons), None)
    if first is None:
        message = MESSAGES["ok"]
    elif first == "misaligned_slight":
        message = MESSAGES["misaligned"]
    elif first == "wrong_orientation":
        message = MESSAGES["wrong_orientation_landscape" if spec.landscape else "wrong_orientation_portrait"]
    else:
        message = MESSAGES[first]
    return FrameVerdict(level, message, reasons, dog_box=dn, person_box=pn, guide=guide, inside=inside)


def smooth_levels(history: list[Level], need: int = 3) -> Level:
    """把最近几次判定平滑成一个结果，避免框一闪一闪。

    规则：最近 need 次里，全是绿才算绿；出现红且最近两次都红才算红；其余黄。
    这是 App 端也要实现的逻辑，放在这里便于单测并作为规格。
    """
    if not history:
        return "red"
    recent = history[-need:]
    if len(recent) >= need and all(l == "green" for l in recent):
        return "green"
    if len(recent) >= 2 and all(l == "red" for l in recent[-2:]):
        return "red"
    return "yellow"


_MODEL = None


def _load_model():
    global _MODEL
    if _MODEL is None:
        from ultralytics import YOLO

        from pawcoach.pose.detect import DEFAULT_WEIGHTS

        _MODEL = YOLO(DEFAULT_WEIGHTS)
    return _MODEL


def detect_frame(image: np.ndarray, imgsz: int = 480) -> tuple[list[Detection], list[Detection]]:
    """跑一帧 YOLO，返回 (狗候选, 人候选)。image 是 BGR 的 HxWx3 数组。需要 ultralytics。"""
    import torch

    device = "mps" if torch.backends.mps.is_available() else ("cuda" if torch.cuda.is_available() else "cpu")
    r = _load_model().predict(
        image, classes=[PERSON_CLASS, *DOG_CLASSES], imgsz=imgsz, conf=MIN_CONF, verbose=False, device=device
    )[0]
    dogs: list[Detection] = []
    persons: list[Detection] = []
    for b in r.boxes:
        det = Detection(float(b.conf), tuple(float(v) for v in b.xyxy[0].tolist()))  # type: ignore[arg-type]
        (persons if int(b.cls) == PERSON_CLASS else dogs).append(det)
    return dogs, persons
