"""B6：AsrAudioExtractor —— 读 Whisper 转写缓存，用 meta 口令词 + 同音表做关键词匹配，输出 AudioEvent[]。

转写缓存由 scripts/b5_asr_probe.py 生成，格式：
    {"segments": [{"start": 11.0, "end": 13.0, "text": "Sats."}, ...]}
见 reports/B5.md 与 docs/CodePlan_detail.md 步骤 B6。

匹配不能精确相等：whisper 会把 "sit" 转成 "Sats"、"坐" 转成 "做"（见 reports/B5.md），
所以这里用同音表把口令词展开成近音变体，再在归一化后的转写文本里做匹配。

时间戳是句段级（不是词级）：AudioEvent 的 t_start/t_end 取转写句段的起止，
精度只到秒级（B5 已记录），词级时间戳是 B7 之后的调准项。
"""

from __future__ import annotations

import json
import re
from pathlib import Path

from pawcoach.schema import AudioEvent, MetaInfo
from pawcoach.video.probe import VideoInfo

# 同音/近音/繁简表：meta 里的口令词 → whisper 可能转出的变体。
# 只放实测遇到或稳妥的常见同音，缺了就往这里补，匹配逻辑不用改。
_HOMOPHONES: dict[str, list[str]] = {
    # 中文（whisper 中文常出繁体、同音错字；dog1 里「坐」→「做」，见 reports/B5.md）
    "坐": ["做", "作", "座"],
    "好": ["號", "号", "郝"],
    "对": ["對"],
    # 注意：没做「可以了 → 可以」的同音映射——「可以」太常见，会把「可以利用」这类解说词误判成释放词。
    # 英文（dog3 里 "sit" → "Sats"，见 reports/B5.md）
    "sit": ["sats", "set", "sat"],
}


def _normalize(text: str) -> str:
    """小写 + 非「字母/数字/中文/下划线」字符压成空格，保留词边界。"""
    return re.sub(r"[^\w一-鿿]+", " ", text.lower()).strip()


def _contains(text_norm: str, key_norm: str) -> bool:
    """key 是否出现在 text 里：ASCII 词用词边界（避免 "sit" 误中 "sitting"），中文用子串。"""
    if not key_norm:
        return False
    if key_norm.isascii():
        return re.search(rf"\b{re.escape(key_norm)}\b", text_norm) is not None
    return key_norm in text_norm


def _matches(text_norm: str, keyword: str) -> bool:
    """口令词 + 同音变体里，任一命中即算命中（返回命中的是哪一个不重要，词用规范写法）。"""
    variants = [keyword] + [v for v in _HOMOPHONES.get(keyword, []) if v != keyword]
    return any(_contains(text_norm, _normalize(v)) for v in variants)


class AsrAudioExtractor:
    """读 Whisper 转写缓存，把命中的口令/标记词/释放词转成 AudioEvent。"""

    def __init__(self, asr_dir: str = "data/asr"):
        self.asr_dir = Path(asr_dir)

    def extract(self, video: VideoInfo, meta: MetaInfo) -> list[AudioEvent]:
        cache = self._find_cache(video)
        if cache is None:
            return []
        segments = json.loads(cache.read_text(encoding="utf-8")).get("segments", [])

        events: list[AudioEvent] = []
        for seg in segments:
            text_norm = _normalize(str(seg.get("text", "")))
            start = float(seg.get("start", 0.0))
            end = float(seg.get("end", start))
            for kind, words in (
                ("cue", meta.cues),
                ("marker", meta.marker_words),
                ("release", meta.release_words),
            ):
                for word in words:
                    if self._matches(text_norm, word):
                        events.append(AudioEvent(word=word, t_start=start, t_end=end, kind=kind))
        return sorted(events, key=lambda e: e.t_start)

    def _matches(self, text_norm: str, keyword: str) -> bool:
        """口令词 + 同音变体里，任一命中即算命中（委托给模块级 _matches，逻辑只此一份）。"""
        return _matches(text_norm, keyword)

    def _find_cache(self, video: VideoInfo) -> Path | None:
        """按视频名找转写缓存；标准化产物带 .norm 后缀，剥掉以对齐原始视频名。"""
        stem = Path(video.path).stem
        if stem.endswith(".norm"):
            stem = stem[: -len(".norm")]
        cache = self.asr_dir / f"{stem}.json"
        return cache if cache.exists() else None
