"""C4：安全层 —— 硬规则，优先于一切输出。

识别到狗的攻击/恐惧信号（咆哮/龇牙/扑咬/夹尾缩身躲避）或人的不当行为（打/踢/猛拉），
不生成训练计划，输出转介建议（Vieira de Castro 2020：厌恶/惩罚会加剧攻击与焦虑）。

MVP 只做「用户勾选」（meta.red_flags），不训情绪模型；大模型对逐帧/音频描述的识别留后续。
"""

from __future__ import annotations

from pawcoach.schema import MetaInfo

# 有效红旗：狗的信号 + 人的不当行为
DOG_FLAGS = {"growling", "baring_teeth", "lunging", "fear"}
HUMAN_FLAGS = {"hitting", "kicking", "jerking"}
ALL_FLAGS = DOG_FLAGS | HUMAN_FLAGS

# 红旗 → 中文（给用户看的朴实说法）
_FLAG_NAMES = {
    "growling": "狗狗咆哮",
    "baring_teeth": "狗狗龇牙",
    "lunging": "狗狗扑咬/前冲",
    "fear": "狗狗夹尾缩身躲避（恐惧）",
    "hitting": "打狗",
    "kicking": "踢狗",
    "jerking": "猛拉牵引绳",
}


def triggered_flags(meta: MetaInfo) -> list[str]:
    """从 meta.red_flags 过滤出有效红旗（去重、保序、忽略未知）。"""
    seen: set[str] = set()
    out: list[str] = []
    for f in meta.red_flags:
        if f in ALL_FLAGS and f not in seen:
            seen.add(f)
            out.append(f)
    return out


def referral_text(flags: list[str]) -> str:
    """生成转介建议文本，替代训练计划。flags 为空返回空串（调用方只在有红旗时调）。"""
    if not flags:
        return ""
    names = "、".join(_FLAG_NAMES[f] for f in flags)
    return (
        "⚠️ 本次视频检测到需要关注的信号，暂不生成训练建议。\n"
        f"检测到：{names}。\n\n"
        "出于安全，请先停止当前的训练方式，并转介专业人士：\n"
        "- 狗狗有恐惧或攻击表现时，先看兽医排除疼痛或健康问题，再找认证的正向强化训犬师评估；\n"
        "- 不要用打、踢、猛拉等方式纠正——惩罚会加剧狗的恐惧和攻击（已有研究证实）。\n\n"
        "PawCoach 只适合记录和改善正向训练，不适合处理攻击或严重恐惧的情况。"
    )
