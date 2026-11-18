"""B2：SuperAnimalPoseExtractor。

读 SuperAnimal-Quadruped 的关键点 H5（没有就先跑推理），用 rules.py 判坐、站、卧。

推理需要 deeplabcut，它只在 Python 3.12 的 .venv-b 里；.venv（3.13）里没有。
所以 deeplabcut 和 pandas 都是用到时才 import：在 .venv 里只用已有的 H5 会因为缺 pandas 失败，
接进 analyze 时怎么处理两个环境，留给 B4。
"""

from __future__ import annotations

from pathlib import Path

import numpy as np

from pawcoach.pose.detect import detect_main_dog, in_frame_mask
from pawcoach.pose.rules import Keypoints, PoseRules, keypoints_to_segments
from pawcoach.schema import PoseSegment
from pawcoach.video.probe import VideoInfo

SUPERANIMAL = "superanimal_quadruped"
DEFAULT_MODEL = "rtmpose_s"
DEFAULT_DETECTOR = "ssdlite"
DEFAULT_POSE_DIR = "data/pose"


def run_inference(
    video: Path,
    out_dir: Path,
    model: str = DEFAULT_MODEL,
    detector: str = DEFAULT_DETECTOR,
    device: str = "auto",
) -> Path:
    """跑 SuperAnimal 视频推理，返回结果 H5 路径。需要 .venv-b 里的 deeplabcut。"""
    try:
        from deeplabcut.modelzoo.video_inference import video_inference_superanimal
    except ImportError as e:
        raise RuntimeError(
            "没有安装 deeplabcut。SuperAnimal 推理要在 Python 3.12 的 .venv-b 里跑，见 requirements-b.txt"
        ) from e

    out_dir.mkdir(parents=True, exist_ok=True)
    video_inference_superanimal(
        videos=str(video),
        superanimal_name=SUPERANIMAL,
        model_name=model,
        detector_name=detector,
        dest_folder=str(out_dir),
        pcutoff=0.1,
        max_individuals=1,
        device=device,
        plot_bboxes=False,
        create_labeled_video=False,
    )
    return find_h5(video, out_dir)


def find_h5(video: Path, pose_dir: Path) -> Path:
    # 推理在标准化产物（如 dog3.norm.mp4）上跑，deeplabcut 按它的名字输出 H5，缓存键 = 推理视频名
    h5s = sorted(pose_dir.glob(f"{video.stem}_superanimal*.h5"))
    if not h5s:
        raise FileNotFoundError(f"{pose_dir} 里没有 {video.stem} 的 SuperAnimal 结果")
    return h5s[0]


def load_keypoints(h5: Path, fps: float, width: int, height: int) -> Keypoints:
    """读 DeepLabCut 输出的 H5。列是 (scorer, individuals, bodyparts, coords)。"""
    import pandas as pd

    df = pd.read_hdf(h5)
    scorer = df.columns[0][0]
    names = list(dict.fromkeys(c[2] for c in df.columns if c[1] == "animal0"))
    xy = np.stack(
        [
            np.stack([df[(scorer, "animal0", n, "x")].to_numpy(), df[(scorer, "animal0", n, "y")].to_numpy()], -1)
            for n in names
        ],
        axis=1,
    )
    conf = np.stack([df[(scorer, "animal0", n, "likelihood")].to_numpy() for n in names], axis=1)
    # 没检测到的点可能是 NaN：坐标补 0、置信度补 0，让规则按「不可靠」处理
    bad = np.isnan(xy).any(axis=2) | np.isnan(conf)
    xy = np.where(bad[..., None], 0.0, xy)
    conf = np.where(bad, 0.0, conf)
    return Keypoints(names=names, xy=xy, conf=conf, fps=fps, width=width, height=height)


class SuperAnimalPoseExtractor:
    def __init__(
        self,
        pose_dir: str = DEFAULT_POSE_DIR,
        rules: PoseRules | None = None,
        run_if_missing: bool = True,
        model: str = DEFAULT_MODEL,
        detector: str = DEFAULT_DETECTOR,
        use_detection: bool = True,
    ):
        self.pose_dir = Path(pose_dir)
        self.rules = rules or PoseRules()
        self.run_if_missing = run_if_missing
        self.model = model
        self.detector = detector
        # B3：用 YOLO 检测框判断狗在不在画面里，不在的帧标 unclear。
        # 检测结果缓存在 data/pose/<视频名>_dogbox.npy；有缓存时 .venv 里不装 ultralytics 也能用。
        self.use_detection = use_detection

    def extract(self, video: VideoInfo) -> list[PoseSegment]:
        path = Path(video.path)
        try:
            h5 = find_h5(path, self.pose_dir)
        except FileNotFoundError:
            if not self.run_if_missing:
                raise
            h5 = run_inference(path, self.pose_dir, self.model, self.detector)
        kp = load_keypoints(h5, video.fps, *video.display_size)
        in_frame = None
        if self.use_detection:
            track = detect_main_dog(path, self.pose_dir, use_cache=True)
            in_frame = in_frame_mask(track, video.fps, *video.display_size)
        return keypoints_to_segments(kp, self.rules, in_frame)
