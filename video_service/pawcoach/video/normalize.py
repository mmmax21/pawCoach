"""视频标准化：把手机视频统一成下游模型好处理的格式。

手机视频的三个常见问题（见 docs/CodePlan_detail.md 步骤 A10）：
- 编码：iPhone 默认 HEVC（.mov），部分环境的解码和抽帧不稳；
- 方向：竖拍视频靠旋转元数据（displaymatrix）标记，不摆正则宽高与画面方向都会错；
- 帧率：可变帧率（VFR），按帧序号换算时间会漂移。

标准化目标：H.264 + yuv420p + 固定帧率 + 方向摆正（旋转元数据清零）+ AAC 音轨。
已经符合目标的视频不转码，原样复用，避免无谓的画质损失和耗时。
"""

from __future__ import annotations

import subprocess
from dataclasses import dataclass
from pathlib import Path

from pawcoach.video.probe import VideoInfo, load_video

TARGET_FPS = 10  # D2 性能优化：Sit-Stay 姿态是秒级变化，10fps 足够；帧数降到 1/3，推理快 3 倍
TARGET_CODEC = "h264"
# 长边上限：手机常拍 4K，姿态与 ASR 用不到那么高的分辨率，缩小可显著降低后续耗时
MAX_LONG_SIDE = 1280


@dataclass
class NormalizeResult:
    """标准化结果。"""

    path: str            # 标准化后（或原样复用）的视频路径
    transcoded: bool     # 是否真的转码了
    reasons: list[str]   # 需要转码的原因；为空表示原样复用
    info: VideoInfo      # 标准化后视频的信息


def needs_normalize(info: VideoInfo) -> list[str]:
    """返回需要转码的原因列表；为空表示视频已符合标准。"""
    reasons: list[str] = []
    if info.codec != TARGET_CODEC:
        reasons.append(f"编码 {info.codec or '未知'} → {TARGET_CODEC}")
    if info.rotation != 0:
        reasons.append(f"旋转 {info.rotation}° 摆正")
    if info.is_vfr:
        reasons.append("可变帧率 → 固定帧率")
    elif info.fps and abs(info.fps - TARGET_FPS) > 0.5:
        reasons.append(f"帧率 {info.fps:.2f} → {TARGET_FPS}")
    w, h = info.display_size
    if max(w, h) > MAX_LONG_SIDE:
        reasons.append(f"分辨率 {w}x{h} 长边超过 {MAX_LONG_SIDE}")
    return reasons


def _scale_filter(info: VideoInfo) -> str:
    """长边超限时按比例缩小，否则保持原尺寸；宽高统一取偶数（H.264 要求）。"""
    w, h = info.display_size
    if max(w, h) > MAX_LONG_SIDE:
        # 长边缩到 MAX_LONG_SIDE，另一边按比例并取偶数
        if w >= h:
            return f"scale={MAX_LONG_SIDE}:-2"
        return f"scale=-2:{MAX_LONG_SIDE}"
    return "scale=trunc(iw/2)*2:trunc(ih/2)*2"


def normalize_video(path: str | Path, out_dir: str | Path, force: bool = False) -> NormalizeResult:
    """把视频标准化到 out_dir/<原文件名>.norm.mp4；已符合标准则原样返回。

    ffmpeg 默认会按旋转元数据自动摆正画面并清掉旋转标记，所以只需按目标参数重编码；
    这里依赖该默认行为，转码后用 load_video 复查 rotation==0 作为校验。
    """
    path = Path(path)
    info = load_video(path)
    reasons = needs_normalize(info)
    if not reasons and not force:
        return NormalizeResult(path=str(path), transcoded=False, reasons=[], info=info)

    out_dir = Path(out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / f"{path.stem}.norm.mp4"

    cmd = [
        "ffmpeg", "-y", "-loglevel", "error", "-i", str(path),
        "-vf", f"fps={TARGET_FPS},{_scale_filter(info)}",
        "-c:v", "libx264", "-pix_fmt", "yuv420p", "-preset", "veryfast", "-crf", "23",
        "-movflags", "+faststart",
    ]
    if info.has_audio:
        cmd += ["-c:a", "aac", "-b:a", "128k", "-ac", "1", "-ar", "16000"]
    else:
        cmd += ["-an"]
    cmd.append(str(out))

    proc = subprocess.run(cmd, capture_output=True, text=True)
    if proc.returncode != 0:
        raise RuntimeError(f"标准化失败：{path}\n{proc.stderr.strip()}")

    result_info = load_video(out)
    if result_info.rotation != 0:
        raise RuntimeError(f"标准化后仍带旋转标记（{result_info.rotation}°）：{out}")
    return NormalizeResult(path=str(out), transcoded=True, reasons=reasons, info=result_info)
