"""video 标准化的单元测试：判断逻辑与旋转解析不依赖 ffmpeg，集成测试现场合成手机风格素材。"""

import shutil
import subprocess

import pytest

from pawcoach.video.normalize import MAX_LONG_SIDE, needs_normalize, normalize_video
from pawcoach.video.probe import VideoInfo, _parse_rotation, load_video


def _info(**kw) -> VideoInfo:
    base = dict(
        path="x.mp4", duration=10.0, fps=10.0, width=1280, height=720,
        has_audio=True, n_frames=100, codec="h264", rotation=0, is_vfr=False,
    )
    base.update(kw)
    return VideoInfo(**base)


def test_standard_video_needs_nothing():
    assert needs_normalize(_info()) == []


def test_ntsc_fps_is_tolerated():
    # 9.97 / 10.0005 这类取整差异不应触发转码
    assert needs_normalize(_info(fps=9.97)) == []
    assert needs_normalize(_info(fps=10.000496)) == []


def test_hevc_rotation_vfr_all_reported():
    reasons = needs_normalize(_info(codec="hevc", rotation=90, is_vfr=True))
    assert len(reasons) == 3
    assert any("hevc" in r for r in reasons)
    assert any("旋转" in r for r in reasons)
    assert any("可变帧率" in r for r in reasons)


def test_constant_but_off_target_fps():
    reasons = needs_normalize(_info(fps=60.0))
    assert reasons == ["帧率 60.00 → 10"]


def test_large_resolution_uses_display_size():
    # 竖拍 4K：编码尺寸 3840x2160 + 旋转 90 → 显示 2160x3840，长边超限
    reasons = needs_normalize(_info(width=3840, height=2160, rotation=90))
    assert any(str(MAX_LONG_SIDE) in r for r in reasons)


def test_display_size_swaps_on_rotation():
    assert _info(width=1920, height=1080, rotation=90).display_size == (1080, 1920)
    assert _info(width=1920, height=1080, rotation=180).display_size == (1920, 1080)


def test_parse_rotation_from_display_matrix():
    # ffprobe 的 rotation 是逆时针角度，需旋转的顺时针角度取负
    assert _parse_rotation({"side_data_list": [{"rotation": -90}]}) == 90
    assert _parse_rotation({"side_data_list": [{"rotation": 90}]}) == 270
    assert _parse_rotation({"side_data_list": [{"rotation": 180}]}) == 180
    assert _parse_rotation({"side_data_list": [{"rotation": 0}]}) == 0


def test_parse_rotation_legacy_tag_and_missing():
    assert _parse_rotation({"tags": {"rotate": "90"}}) == 90
    assert _parse_rotation({"tags": {"rotate": "bad"}}) == 0
    assert _parse_rotation({}) == 0


needs_ffmpeg = pytest.mark.skipif(
    shutil.which("ffmpeg") is None, reason="需要 ffmpeg"
)


def _make_phone_clip(tmp_path, rotation: int):
    """合成 HEVC + 旋转标记 + 变帧率的手机风格素材；本机无 libx265 时跳过。"""
    base = tmp_path / "base.mp4"
    proc = subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error",
         "-f", "lavfi", "-i", "testsrc2=duration=2:size=320x180:rate=60",
         "-f", "lavfi", "-i", "sine=frequency=440:duration=2",
         "-vf", "select='lt(mod(n,5),2)'", "-fps_mode", "vfr",
         "-c:v", "libx265", "-tag:v", "hvc1", "-pix_fmt", "yuv420p",
         "-c:a", "aac", "-shortest", str(base)],
        capture_output=True, text=True,
    )
    if proc.returncode != 0:
        pytest.skip("本机 ffmpeg 不支持 libx265")
    phone = tmp_path / "phone.mov"
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error", f"-display_rotation:v", str(rotation),
         "-i", str(base), "-c", "copy", str(phone)],
        capture_output=True, text=True, check=True,
    )
    return phone


@needs_ffmpeg
def test_normalize_phone_clip_end_to_end(tmp_path):
    phone = _make_phone_clip(tmp_path, rotation=90)
    before = load_video(phone)
    assert before.codec == "hevc"
    assert before.rotation in (90, 270)
    assert before.is_vfr is True

    res = normalize_video(phone, tmp_path / "out")

    assert res.transcoded is True
    assert res.info.codec == "h264"
    assert res.info.rotation == 0
    assert res.info.is_vfr is False
    assert abs(res.info.fps - 10.0) < 0.5
    # 横屏素材 + 旋转标记 → 摆正后应是竖屏
    assert res.info.height > res.info.width
    assert res.info.has_audio is True


@needs_ffmpeg
def test_already_standard_video_is_reused(tmp_path):
    std = tmp_path / "std.mp4"
    subprocess.run(
        ["ffmpeg", "-y", "-loglevel", "error",
         "-f", "lavfi", "-i", "testsrc2=duration=1:size=320x180:rate=10",
         "-c:v", "libx264", "-pix_fmt", "yuv420p", str(std)],
        capture_output=True, text=True, check=True,
    )
    res = normalize_video(std, tmp_path / "out")
    assert res.transcoded is False
    assert res.path == str(std)
    assert not (tmp_path / "out").exists()
