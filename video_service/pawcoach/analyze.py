"""analyze 核心逻辑：视频 → AnalysisResult（标准化 → meta → 流水线 → align → 聚合 → coach → 落库）。

cli.py 的 `analyze` 子命令和 app 后端的 `POST /analyze` 都调 `analyze_video`，
编排逻辑只此一份。落库（数据飞轮，A9 埋点）也在这里做。
"""

from __future__ import annotations

import shutil
from dataclasses import asdict
from pathlib import Path

from pawcoach import store
from pawcoach.audio.asr import AsrAudioExtractor
from pawcoach.coach.llm import LLMCoach
from pawcoach.coach.template import TemplateCoach
from pawcoach.config import coach_mode
from pawcoach.coach.safety import referral_text, triggered_flags
from pawcoach.events.align import align, gate_trials, unclear_seconds
from pawcoach.reward.merged import MergedRewardExtractor
from pawcoach.schema import (
    AnalysisResult,
    AudioEvent,
    MetaInfo,
    PoseSegment,
    Quality,
    Summary,
    default_meta,
    load_meta,
)
from pawcoach.video.normalize import normalize_video
from pawcoach.video.probe import load_video

NORMALIZED_DIR = "data/normalized"
POSE_DIR = "data/pose"
ASR_DIR = "data/asr"

# /realign：用户确认的坐姿起点与姿态段起点的匹配容差（秒），补的口令放在坐下后多少秒
_SIT_MATCH_TOL = 0.05
_USER_CUE_OFFSET = 0.15  # 要大于 align 的 _EPS（0.1），才会走「口令落在进行中的坐姿里」分支


def purge_artifacts(
    video_path: str | Path,
    normalized_dir: str | Path = NORMALIZED_DIR,
    pose_dir: str | Path = POSE_DIR,
    asr_dir: str | Path = ASR_DIR,
    delete_source: bool = False,
) -> list[Path]:
    """M5 3.4：删除一段视频的所有中间产物（标准化视频、姿态 / 检测缓存、转写缓存），返回删掉的路径。

    缓存键都以原视频名（stem）开头：标准化产物 <stem>.norm.mp4、姿态 <stem>[.norm]_superanimal*.h5、
    检测 <stem>[.norm]_dogbox.npy、转写 <stem>.json。delete_source=True 时连原视频一起删
    （API 上传的视频；CLI 分析 data/raw/ 下的素材时不删）。
    """
    video_path = Path(video_path)
    stem = video_path.stem
    removed: list[Path] = []
    candidates: list[Path] = []
    for d in (Path(normalized_dir), Path(pose_dir)):
        if d.exists():
            candidates += [p for p in d.iterdir() if p.name.startswith(stem)]
    candidates.append(Path(asr_dir) / f"{stem}.json")
    if delete_source:
        candidates.append(video_path)
    for p in candidates:
        try:
            if p.is_dir():
                shutil.rmtree(p)
            elif p.exists():
                p.unlink()
            else:
                continue
            removed.append(p)
        except OSError:
            pass
    return removed


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
    cleanup: bool = False,
    precheck: bool = False,
    on_stage=None,
) -> AnalysisResult:
    """分析一段视频，返回 AnalysisResult（含 coach 建议），并落库。

    meta 传入时用它（app 后端上传的 meta）；否则按视频文件名找 <video_id>.meta.json。
    cleanup=True（API 上传用）：无论成功失败，结束后删除原视频与全部中间产物，只留数据库里的数字。
    precheck=True（API 上传用）：先抽帧预检（pawcoach/precheck.py），明显拍坏的视频直接返回，不跑整段分析。
    on_stage(stage)：进度回调，stage 为 "precheck" / "analyzing"，供 API 轮询时告诉 App 进行到哪一步。
    """
    if not cleanup:
        return _analyze(Path(path), normalized_dir, meta, precheck, on_stage)
    try:
        return _analyze(Path(path), normalized_dir, meta, precheck, on_stage)
    finally:
        purge_artifacts(path, normalized_dir, delete_source=True)


class VideoTooLong(ValueError):
    """视频超过 meta.max_duration（M5：App 限制 120 秒）。错误信息以 video_too_long 开头，App 据此提示。"""


def assemble(
    video_id: str,
    pose: list[PoseSegment],
    audio: list[AudioEvent],
    meta: MetaInfo,
    quality: Quality,
    user_cue_sits: list[float] | None = None,
) -> AnalysisResult:
    """三条时间线 → AnalysisResult（对齐、门控、汇总），不含 coach 与落库。

    user_cue_sits：用户在 App 里确认「这几次是听口令坐下的」的坐姿起点（/realign）。
    每个起点对应的坐姿段里补一个口令事件（坐下后 _USER_CUE_OFFSET 秒），
    走 align 已有的「口令落在进行中的坐姿里」分支：latency 为 None、cue_times 为空——
    用户只确认了喊过口令，没说是什么时候喊的，反应快慢和口令次数都不能算。
    """
    orig_audio = list(audio)  # events 只存识别出的事件；用户补的口令不存，再次补标时以新的选择为准
    audio = list(audio)
    user_cues: list[float] = []
    for t in user_cue_sits or []:
        seg = next(
            (s for s in pose if s.label == meta.target_pose and abs(s.t_start - t) <= _SIT_MATCH_TOL),
            None,
        )
        if seg is None:
            continue
        ct = min(seg.t_start + _USER_CUE_OFFSET, (seg.t_start + seg.t_end) / 2)
        user_cues.append(ct)
        word = meta.cues[0] if meta.cues else "cue"
        audio.append(AudioEvent(word=word, t_start=ct, t_end=ct, kind="cue"))
    audio.sort(key=lambda e: e.t_start)

    rewards = MergedRewardExtractor().extract(meta, audio)
    trials, unpaired = align(pose, audio, rewards, meta)
    for t in trials:
        if t.cue_t is not None and any(abs(t.cue_t - c) < 1e-6 for c in user_cues):
            t.cue_source = "user"
    reliable, _unreliable = gate_trials(trials)
    for t in reliable:  # M5：每轮标明是否可靠（同一门控），App 只用可靠轮次判定
        t.reliable = True
    return AnalysisResult(
        video_id=video_id,
        quality=quality,
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
        events={"pose": [asdict(p) for p in pose], "audio": [asdict(a) for a in orig_audio]},
    )


def realign(result: dict, meta: MetaInfo, user_cue_sits: list[float]) -> AnalysisResult:
    """用户补标口令后重新对齐（不需要视频：只用上次结果里的 events 与 quality）。不落库、不生成 coach。"""
    ev = result.get("events") or {}
    if not ev.get("pose"):
        raise ValueError("结果里没有 events，无法重新对齐（旧版本服务的结果）")
    pose = [PoseSegment(**p) for p in ev["pose"]]
    audio = [AudioEvent(**a) for a in ev.get("audio", [])]
    q = result.get("quality") or {}
    quality = Quality(**{k: q[k] for k in Quality.__dataclass_fields__ if k in q})
    out = assemble(result.get("video_id", ""), pose, audio, meta, quality, user_cue_sits)
    out.precheck = result.get("precheck")
    return out


def _stage(on_stage, stage: str) -> None:
    if on_stage is not None:
        try:
            on_stage(stage)
        except Exception:  # noqa: BLE001  进度回调失败不影响分析
            pass


def _analyze(
    path: Path, normalized_dir: str, meta: MetaInfo | None, precheck: bool = False, on_stage=None
) -> AnalysisResult:
    video_id = path.stem

    # 0) M5：时长上限（在标准化与推理之前检查，超长视频不浪费算力）
    if meta is not None and meta.max_duration:
        src = load_video(path)
        if (src.duration or 0.0) > meta.max_duration + 0.5:
            raise VideoTooLong(f"video_too_long: {src.duration:.1f}s > {meta.max_duration:.0f}s")

    # 1) 标准化
    norm = normalize_video(path, normalized_dir)
    video = load_video(norm.path)

    # 2) meta（可选；不存在则用常见口令默认表，用户传自己的 meta 时整体覆盖）
    if meta is None:
        meta_path = path.with_name(f"{video_id}.meta.json")
        meta = load_meta(meta_path) if meta_path.exists() else default_meta()

    # 2.5) 预检：明显拍坏（没拍到狗 / 几乎全程看不出姿势）就不跑整段分析，十几秒内返回
    pose_extractor, pose_kind = _make_pose_extractor()
    if precheck and pose_kind == "superanimal":
        _stage(on_stage, "precheck")
        from pawcoach.precheck import precheck as run_precheck

        pc = run_precheck(video)
        if pc["issues"]:
            frames = max(pc["frames"], 1)
            result = AnalysisResult(
                video_id=video_id,
                quality=Quality(
                    dog_visible_ratio=round(pc["dog_frames"] / frames, 3),
                    audio_ok=video.has_audio,
                    unclear_ratio=round(1 - pc["side_frames"] / frames, 3),
                    unclear_seconds=round((video.duration or 0.0) * (1 - pc["side_frames"] / frames), 3),
                    asr="skipped",
                ),
                target_hold=meta.target_hold,
                precheck=pc,
            )
            store.save_result(result)
            return result
    else:
        pc = None
    _stage(on_stage, "analyzing")

    # 3) 三条流水线
    pose = pose_extractor.extract(video)
    asr = AsrAudioExtractor()
    audio = asr.extract(video, meta)
    # v3：转写没听懂的口令 / 奖励用出声检测补（只有时刻）
    if meta.use_onsets and video.has_audio:
        from pawcoach.audio.onsets import detect_onsets, fill_with_onsets

        audio = fill_with_onsets(audio, detect_onsets(video.path), pose, meta.target_pose)

    # 4)–5) 对齐与聚合（/realign 复用同一份逻辑）
    confs = [seg.conf for seg in pose]
    duration = video.duration or 0.0
    unclear_s = unclear_seconds(pose)
    quality = Quality(
        dog_visible_ratio=_dog_visible_ratio(video),
        audio_ok=video.has_audio,
        pose_conf_mean=(sum(confs) / len(confs)) if confs else 0.0,
        unclear_seconds=unclear_s,
        unclear_ratio=round(unclear_s / duration, 3) if duration > 0 else 0.0,
        asr=asr.last_status,
    )
    result = assemble(video_id, pose, audio, meta, quality)
    result.precheck = pc

    # 6) coach（M5：COACH_MODE 默认 off → 空串、不发任何外部请求；
    #    template / llm 时沿用原逻辑：C4 安全层优先，完全空数据时给诚实提示，不调 LLM 避免幻觉）
    mode = coach_mode()
    flags = triggered_flags(meta)
    if mode == "off":
        result.coach = ""
    elif flags:
        result.coach = referral_text(flags)
    elif not result.trials and not result.unpaired:
        result.coach = _insufficient_data_text(result)
    elif mode == "template":
        result.coach = TemplateCoach().plan(result, [])
    else:
        result.coach = LLMCoach().plan(result, [])

    # 7) 落库
    store.save_result(result)

    return result
