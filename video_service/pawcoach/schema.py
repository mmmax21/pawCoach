"""PawCoach 统一数据结构（全链路合约）。

这是「视频 → JSON → 教练建议」整条链路唯一的合约：
所有模块都往这套结构里填，所有验收都检查这套结构是否字段齐全、类型正确。

约定（见 docs/CodePlan_detail.md §1.2）：
- 本模块 A 阶段就定死，后续只增字段、不破坏既有字段。
- 大模型只读这些「数字」，绝不直接看视频（K9-Bench 依据）。
"""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass, field
from pathlib import Path
from typing import Literal, Optional

from pydantic import BaseModel, Field

# 狗姿态标签：sit 坐 / stand 站 / down 卧 / unclear 看不清
PoseLabel = Literal["sit", "stand", "down", "unclear"]

# 音频事件类型：cue 口令 / marker 标记词 / release 释放词 / correction 纠正词（M5）/ other 其它
AudioKind = Literal["cue", "marker", "release", "correction", "other"]

# 奖励事件来源：tap 用户打点 / marker 标记词 / visual 视觉
RewardSource = Literal["tap", "marker", "visual"]

# 一轮结束原因：release 释放 / stand_up 自行起身 / unknown 未知
EndedBy = Literal["release", "stand_up", "unknown"]


@dataclass
class MetaInfo:
    """用户录视频/上传时填写的元信息（对应 data/raw/<id>.meta.json）。"""

    cues: list[str] = field(default_factory=list)          # 训练口令词，如 ["坐"]
    marker_words: list[str] = field(default_factory=list)  # 标记词，如 ["好", "对"]
    release_words: list[str] = field(default_factory=list) # 释放词，如 ["可以了", "走"]
    reward_taps: list[float] = field(default_factory=list) # 手动打点的奖励时刻（秒）
    target_hold: Optional[float] = None  # 本次训练的目标保持时长（秒），可选（C3 规则层用）
    red_flags: list[str] = field(default_factory=list)  # 安全红旗（C4）：用户勾选的攻击/恐惧/打踢信号
    # M5 新增（可选）：
    correction_words: list[str] = field(default_factory=list)  # 纠正词，如 ["不对", "不行"]，匹配方式同口令词
    language: Optional[str] = None  # 转写语言（如 "zh"）；None = Whisper 自动检测
    max_duration: Optional[float] = None  # 视频时长上限（秒）；超出则直接失败（错误信息含 video_too_long）
    # v3 新增（可选）：本技能的目标姿势（sit 坐 / down 趴）；轮次按"口令 → 进入目标姿势 → 保持"切分
    target_pose: str = "sit"
    # v3：用出声检测补转写没听懂的口令 / 奖励（pawcoach/audio/onsets.py）；False 时只用转写
    use_onsets: bool = True


# 常见口令默认表：不传 meta 时兜底，覆盖常见中英文口令；用户传自己的 meta 时整体覆盖这些默认。
DEFAULT_CUES = ["坐", "坐下", "坐好", "sit", "sit down"]
DEFAULT_MARKER_WORDS = ["好", "对", "真棒", "yes", "good"]
DEFAULT_RELEASE_WORDS = ["可以了", "起来", "ok", "release", "free"]


def default_meta() -> MetaInfo:
    """不传 meta 时的默认配置：常见口令表兜底，让「只传视频」也能对口令分析。

    用户传了自己的 meta（文件或 app 上传）时整体覆盖这些默认，不混用。
    """
    return MetaInfo(
        cues=DEFAULT_CUES,
        marker_words=DEFAULT_MARKER_WORDS,
        release_words=DEFAULT_RELEASE_WORDS,
    )


class MetaModel(BaseModel):
    """meta.json 的 pydantic 校验模型（步骤 A5）。字段与 MetaInfo 一一对应。

    meta.json 是用户录视频/上传时填写的输入，用它做类型校验与默认值补全；
    校验通过后再转成全链路契约里的 MetaInfo（dataclass）。
    """

    cues: list[str] = Field(default_factory=list)          # 训练口令词
    marker_words: list[str] = Field(default_factory=list)  # 标记词
    release_words: list[str] = Field(default_factory=list) # 释放词
    reward_taps: list[float] = Field(default_factory=list) # 手动打点奖励时刻（秒）
    target_hold: Optional[float] = None  # 本次训练的目标保持时长（秒），可选
    red_flags: list[str] = Field(default_factory=list)  # 安全红旗（C4）
    correction_words: list[str] = Field(default_factory=list)  # M5：纠正词
    language: Optional[str] = None  # M5：转写语言，None = 自动检测
    max_duration: Optional[float] = None  # M5：视频时长上限（秒）
    target_pose: Literal["sit", "down", "arrive"] = "sit"  # v3：目标（坐 / 趴 / 跑到主人面前）
    use_onsets: bool = True  # v3：出声检测补口令 / 奖励


@dataclass
class PoseSegment:
    """一段狗姿态时间区间。"""

    t_start: float
    t_end: float
    label: PoseLabel
    conf: float  # 0~1，越低越不可信


@dataclass
class AudioEvent:
    """一个命中的口令/标记词/释放词事件。"""

    word: str  # 命中的词（坐/好/可以了/sit/…）
    t_start: float
    t_end: float
    kind: AudioKind
    source: str = "asr"  # v3：asr 转写识别 / onset 出声检测补的（没听懂内容，只有时刻）


@dataclass
class RewardEvent:
    """一个奖励事件时刻。"""

    t: float
    source: RewardSource


@dataclass
class Trial:
    """一轮训练：一次 cue → 进入坐姿 → 保持 → 结束/奖励。"""

    cue_t: Optional[float] = None          # 口令时刻
    sit_start: Optional[float] = None      # 进入坐姿时刻
    sit_end: Optional[float] = None        # 离开坐姿时刻
    ended_by: Optional[EndedBy] = None
    reward_t: Optional[float] = None       # 奖励时刻
    latency: Optional[float] = None        # 反应延迟 = sit_start - cue_t
    hold: Optional[float] = None           # 保持时长 = sit_end - sit_start
    reward_delay: Optional[float] = None   # 奖励延迟
    conf: float = 0.0                      # 本轮整体置信度
    # M5 新增（只增不改）：
    cue_times: list[float] = field(default_factory=list)  # 本轮内、狗坐下之前识别到的所有口令时刻
    markers_during_hold: int = 0           # 坐下到起身之间识别到的标记词次数
    corrections: list[dict] = field(default_factory=list)  # 本轮内识别到的纠正词 [{word, t}]
    reliable: bool = False                 # 是否通过置信度门控（gate_trials），App 只用可靠轮次判定
    cue_source: str = "asr"                # 口令来源：asr 转写识别 / user 用户在 App 里确认（/realign）


@dataclass
class Quality:
    """整段视频的可测量质量，用于置信度门控。"""

    dog_visible_ratio: float = 0.0
    audio_ok: bool = False
    pose_conf_mean: float = 0.0
    unclear_seconds: float = 0.0   # 无法可靠判断的片段总时长（狗出画/低置信/正面视角）
    unclear_ratio: float = 0.0     # unclear_seconds / 视频时长
    asr: str = ""                  # M5：转写来源 cache / transcribed / no_audio / unavailable: … / failed: …


@dataclass
class Summary:
    """聚合指标。

    trials 是识别到的总轮数；reliable_trials / unreliable_trials 是置信度门控（C1）后的分组。
    success_rate / median_hold 只基于可靠轮次，低置信轮次不计入。
    """

    trials: int = 0
    reliable_trials: int = 0      # conf >= CONF_GATE 的轮数
    unreliable_trials: int = 0    # conf < CONF_GATE 的轮数
    success_rate: Optional[float] = None
    median_hold: Optional[float] = None


@dataclass
class AnalysisResult:
    """一次 analyze 的最终结果，写入 results/<video_id>.json。"""

    video_id: str = ""
    dog_id: str = ""
    date: str = ""
    quality: Quality = field(default_factory=Quality)
    trials: list[Trial] = field(default_factory=list)
    summary: Summary = field(default_factory=Summary)
    unpaired: list[dict] = field(default_factory=list)  # 无法配对的事件，作反馈素材
    coach: str = ""                                     # 教练建议文本
    target_hold: Optional[float] = None                 # 本次训练目标保持时长（来自 meta，C3 规则层用）
    # 减少重拍（2026-11-18）：
    # events = {"pose": [PoseSegment…], "audio": [AudioEvent…]}，只有数字和命中的词。
    # 视频分析完就删了，用户在 App 里补标口令时由 /realign 用它重新对齐，不必重传视频。
    events: dict = field(default_factory=dict)
    # 预检结果（只在 API 开启预检时有）：{frames, dog_frames, side_frames, voice, issues: [...]}。
    # issues 非空时整段分析被跳过，trials 为空，App 按 issues 给出具体的重拍原因。
    precheck: Optional[dict] = None
    # v3 身体信号（狗的状态）：pawcoach/body/check.check_video 的结果 {signals, metrics, postures, ...}；只测量
    body: Optional[dict] = None


def to_json(result: AnalysisResult) -> str:
    """把结果序列化为带缩进、非 ASCII 的 JSON 字符串。"""
    return json.dumps(asdict(result), ensure_ascii=False, indent=2)


def load_meta(path: str | Path) -> MetaInfo:
    """读取并校验 data/raw/<id>.meta.json，返回 MetaInfo。

    用 pydantic（MetaModel）校验字段与类型，缺失字段按默认值补全；
    非法类型（如 reward_taps 里混入字符串）会抛出 pydantic 的 ValidationError。
    """
    raw = json.loads(Path(path).read_text(encoding="utf-8"))
    return meta_from_dict(raw)


def meta_from_dict(raw: dict) -> MetaInfo:
    """从 dict 构造 MetaInfo（app 后端上传的 meta JSON 解析用）。"""
    m = MetaModel.model_validate(raw)
    return MetaInfo(
        cues=m.cues,
        marker_words=m.marker_words,
        release_words=m.release_words,
        reward_taps=m.reward_taps,
        target_hold=m.target_hold,
        red_flags=m.red_flags,
        correction_words=m.correction_words,
        language=m.language,
        max_duration=m.max_duration,
        target_pose=m.target_pose,
        use_onsets=m.use_onsets,
    )
