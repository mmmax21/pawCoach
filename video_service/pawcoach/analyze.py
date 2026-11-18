"""analyze 核心逻辑：视频 → AnalysisResult（标准化 → meta → 流水线 → align → 聚合 → coach → 落库）。

cli.py 的 `analyze` 子命令和 app 后端的 `POST /analyze` 都调 `analyze_video`，
编排逻辑只此一份。落库（数据飞轮，A9 埋点）也在这里做。
"""

from __future__ import annotations

from pathlib import Path

from pawcoach import store
from pawcoach.audio.asr import AsrAudioExtractor
from pawcoach.coach.llm import LLMCoach
from pawcoach.coach.safety import referral_text, triggered_flags
from pawcoach.events.align import align, gate_trials, unclear_seconds
from pawcoach.reward.merged import MergedRewardExtractor
from pawcoach.schema import AnalysisResult, MetaInfo, Quality, Summary, default_meta, load_meta
from pawcoach.video.normalize import normalize_video
from pawcoach.video.probe import load_video

NORMALIZED_DIR = "data/normalized"


def _make_pose_extractor():
    """姿态提取器：优先 SuperAnimal 真实现，环境不支持则回退 stub。

    两个 Python 环境（见 requirements-b.txt）：`.venv-b`（3.12）有 pandas/ultralytics/deeplabcut，
    `.venv`（3.13）只有 numpy/pydantic/httpx。真实现读 H5 需要 pandas，所以在 `.venv` 里回退 stub。
    D2 降帧到 10fps 后推理约 80s，缓存缺失时自动推理（run_if_missing=True）可接受。
    """
    try:
        import pandas  # noqa: F401  读 SuperAnimal H5 需要
    except ImportError:
        from pawcoach.pose.stub import StubPoseExtractor

        return StubPoseExtractor(), "stub（当前环境缺 pandas，姿态整段占位）"

    from pawcoach.pose.superanimal import SuperAnimalPoseExtractor

    return SuperAnimalPoseExtractor(run_if_missing=True, use_detection=True), "superanimal"


def _median(values: list[float]) -> float | None:
    """中位数；空列表返回 None。"""
    if not values:
        return None
    ordered = sorted(values)
    n = len(ordered)
    mid = n // 2
    if n % 2:
        return ordered[mid]
    return round((ordered[mid - 1] + ordered[mid]) / 2, 2)


def _success_rate(trials: list) -> float | None:
    """可靠轮次里拿到奖励的比例；空列表返回 None（表示无数据）。"""
    if not trials:
        return None
    return round(len([t for t in trials if t.reward_t is not None]) / len(trials), 3)


def _dog_visible_ratio(video) -> float:
    """狗完整在画面里的帧占比（B3 检测框 + 补洞）。只读 dogbox.npy 缓存，缺失回退 1.0 占位。

    不触发推理：缓存不存在（新视频或 .venv 无 ultralytics）时直接回退，analyze 不该隐式跑 YOLO。
    """
    try:
        import numpy as np
        from pawcoach.pose.detect import in_frame_mask, track_path

        path = track_path(Path(video.path), Path("data/pose"))
        if not path.exists():
            return 1.0
        mask = in_frame_mask(np.load(path), video.fps, *video.display_size)
        return round(float(mask.mean()), 3) if mask.size else 1.0
    except Exception:
        return 1.0


def _insufficient_data_text(result: AnalysisResult) -> str:
    """完全没有对齐结果（0 轮 + 0 未配对事件）时的诚实提示；不调 LLM，避免在空数据上编造细节。"""
    q = result.quality
    lines = ["【PawCoach 教练建议】", "这段视频没有识别到可分析的训练轮次。"]
    if q.unclear_seconds > 0:
        pct = round(q.unclear_ratio * 100)
        lines.append(
            f"其中 {q.unclear_seconds:.1f} 秒（约 {pct}%）无法可靠判断——"
            "通常是狗出画、机位拍的是正面而不是侧面、或画面太远看不清。"
        )
    lines.append("建议换个能拍到狗侧面全身、且狗完整在画面里的机位，重拍一段再分析。")
    return "\n".join(lines)


def analyze_video(
    path: str | Path,
    normalized_dir: str = NORMALIZED_DIR,
    meta: MetaInfo | None = None,
) -> AnalysisResult:
    """分析一段视频，返回 AnalysisResult（含 coach 建议），并落库。

    meta 传入时用它（app 后端上传的 meta）；否则按视频文件名找 <video_id>.meta.json。
    """
    path = Path(path)
    video_id = path.stem

    # 1) 标准化
    norm = normalize_video(path, normalized_dir)
    video = load_video(norm.path)

    # 2) meta（可选；不存在则用常见口令默认表，用户传自己的 meta 时整体覆盖）
    if meta is None:
        meta_path = path.with_name(f"{video_id}.meta.json")
        meta = load_meta(meta_path) if meta_path.exists() else default_meta()

    # 3) 三条流水线
    pose_extractor, _ = _make_pose_extractor()
    pose = pose_extractor.extract(video)
    audio = AsrAudioExtractor().extract(video, meta)
    rewards = MergedRewardExtractor().extract(meta, audio)

    # 4) 对齐
    trials, unpaired = align(pose, audio, rewards, meta)

    # 5) 聚合（C1 门控）
    confs = [s.conf for s in pose]
    reliable, _unreliable = gate_trials(trials)
    unclear_s = unclear_seconds(pose)
    duration = video.duration or 0.0
    result = AnalysisResult(
        video_id=video_id,
        quality=Quality(
            dog_visible_ratio=_dog_visible_ratio(video),
            audio_ok=video.has_audio,
            pose_conf_mean=(sum(confs) / len(confs)) if confs else 0.0,
            unclear_seconds=unclear_s,
            unclear_ratio=round(unclear_s / duration, 3) if duration > 0 else 0.0,
        ),
        trials=trials,
        summary=Summary(
            trials=len(trials),
            reliable_trials=len(reliable),
            unreliable_trials=len(trials) - len(reliable),
            success_rate=_success_rate(reliable),
            median_hold=_median([t.hold for t in reliable if t.hold is not None]),
        ),
        unpaired=unpaired,
        target_hold=meta.target_hold,
    )

    # 6) coach（C4 安全层优先；完全空数据时给诚实提示，不调 LLM 避免幻觉）
    flags = triggered_flags(meta)
    if flags:
        result.coach = referral_text(flags)
    elif not result.trials and not result.unpaired:
        result.coach = _insufficient_data_text(result)
    else:
        result.coach = LLMCoach().plan(result, [])

    # 7) 落库
    store.save_result(result)

    return result
