"""视频读取与抽取：用 ffprobe/ffmpeg 命令行完成，不引入 opencv。

设计说明（见 docs/CodePlan_detail.md 步骤 A3）：
- 用 `ffprobe -print_format json` 读时长/fps/尺寸/是否含音轨；
- 用 `ffmpeg` 抽帧、提音频；
- 阶段 A 不引入 opencv 读帧，降低环境风险；B 阶段需要逐帧像素时再加。
"""

from __future__ import annotations

import json
import subprocess
from dataclasses import dataclass
from pathlib import Path


@dataclass
class VideoInfo:
    """一段视频的可测量元信息。

    width/height 是编码尺寸（旋转前）；播放时的显示尺寸见 display_size。
    """

    path: str
    duration: float   # 秒
    fps: float
    width: int
    height: int
    has_audio: bool
    n_frames: int     # 估算帧数 = round(duration * fps)
    codec: str = ""           # 视频编码，如 h264 / hevc
    rotation: int = 0         # 播放时需顺时针旋转的角度：0/90/180/270（手机竖拍常见 90/270）
    is_vfr: bool = False      # 是否可变帧率（手机视频常见）

    @property
    def display_size(self) -> tuple[int, int]:
        """按旋转信息摆正后的显示宽高。"""
        if self.rotation in (90, 270):
            return self.height, self.width
        return self.width, self.height


def _run(cmd: list[str]) -> str:
    """执行命令，失败时抛异常并带出 stderr。"""
    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"命令失败：{' '.join(cmd)}\n{proc.stderr.strip()}")
    return proc.stdout


def _parse_fps(raw: str | None) -> float:
    """解析 ffprobe 的帧率字段（如 '30/1' 或 '29.97'）。"""
    if not raw or raw in ("0/0", "N/A"):
        return 0.0
    if "/" in raw:
        num, den = raw.split("/", 1)
        try:
            den_f = float(den)
            return float(num) / den_f if den_f else 0.0
        except ValueError:
            return 0.0
    try:
        return float(raw)
    except ValueError:
        return 0.0


def _parse_rotation(stream: dict) -> int:
    """读取视频流的旋转角，归一化到 0/90/180/270（顺时针，播放时需旋转的角度）。

    新版 ffprobe 把旋转放在 side_data_list 的 Display Matrix（rotation 为逆时针角度，
    符号相反）；老版本放在 tags.rotate。两处都读，取到哪个用哪个。
    """
    for sd in stream.get("side_data_list", []) or []:
        if "rotation" in sd:
            # ffprobe 的 rotation 是「逆时针旋转多少度才能摆正」，取负得到顺时针需旋转的角度
            return int(round(-float(sd["rotation"]))) % 360
    rotate = (stream.get("tags") or {}).get("rotate")
    if rotate is not None:
        try:
            return int(round(float(rotate))) % 360
        except ValueError:
            return 0
    return 0


def load_video(path: str | Path) -> VideoInfo:
    """用 ffprobe 读取视频的时长/fps/尺寸/是否含音轨，以及编码、旋转、是否变帧率。"""
    path = str(path)
    out = _run([
        "ffprobe", "-v", "error",
        "-print_format", "json",
        "-show_streams", "-show_format",
        path,
    ])
    data = json.loads(out)
    streams = data.get("streams", [])
    fmt = data.get("format", {})

    video = next((s for s in streams if s.get("codec_type") == "video"), None)
    if video is None:
        raise ValueError(f"未找到视频流：{path}")

    has_audio = any(s.get("codec_type") == "audio" for s in streams)

    # 时长：优先 format.duration，回退到视频流 duration
    duration = float(fmt.get("duration") or video.get("duration") or 0.0)

    avg_fps = _parse_fps(video.get("avg_frame_rate"))
    nominal_fps = _parse_fps(video.get("r_frame_rate"))
    fps = avg_fps or nominal_fps
    width = int(video.get("width", 0))
    height = int(video.get("height", 0))
    n_frames = int(round(duration * fps)) if fps > 0 else 0
    # 平均帧率明显低于标称帧率，说明帧间隔不均匀，按变帧率处理（阈值 2% 避开取整误差）
    is_vfr = avg_fps > 0 and nominal_fps > 0 and abs(avg_fps - nominal_fps) / nominal_fps > 0.02

    return VideoInfo(
        path=path,
        duration=duration,
        fps=fps,
        width=width,
        height=height,
        has_audio=has_audio,
        n_frames=n_frames,
        codec=str(video.get("codec_name", "")),
        rotation=_parse_rotation(video),
        is_vfr=is_vfr,
    )


def extract_frames(path: str | Path, out_dir: str | Path, fps: float = 10) -> list[Path]:
    """用 ffmpeg 按固定 fps 抽帧，返回帧文件路径列表。"""
    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    _run([
        "ffmpeg", "-y", "-i", str(path),
        "-vf", f"fps={fps}",
        str(out_dir / "frame_%06d.jpg"),
    ])
    return sorted(out_dir.glob("frame_*.jpg"))


def extract_audio(path: str | Path, out_wav: str | Path) -> Path:
    """提取 16kHz 单声道 wav。无音轨时会抛异常，调用方应先查 has_audio。"""
    out_wav = Path(out_wav)
    out_wav.parent.mkdir(parents=True, exist_ok=True)
    _run([
        "ffmpeg", "-y", "-i", str(path),
        "-ac", "1", "-ar", "16000",
        str(out_wav),
    ])
    return out_wav
