"""B6：AsrAudioExtractor —— 读 Whisper 转写缓存，用 meta 口令词 + 同音表做关键词匹配，输出 AudioEvent[]。

转写缓存由 scripts/b5_asr_probe.py 生成，格式：
    {"segments": [{"start": 11.0, "end": 13.0, "text": "Sats."}, ...]}
见 reports/B5.md 与 docs/CodePlan_detail.md 步骤 B6。

匹配不能精确相等：whisper 会把 "sit" 转成 "Sats"、"坐" 转成 "做"（见 reports/B5.md），
所以这里用同音表把口令词展开成近音变体，再在归一化后的转写文本里做匹配。

时间戳是句段级（不是词级）：AudioEvent 的 t_start/t_end 取转写句段的起止，
精度只到秒级（B5 已记录），词级时间戳是 B7 之后的调准项。

M5 改动：
- 缓存缺失时自动转写（pawcoach/audio/transcribe.py），结果写入 data/asr/，格式不变；
  环境缺 whisper / 视频无音轨时回退空事件，状态记在 `last_status`，由 analyze 写进 quality.asr。
- 新缓存的句段带 `words`（词级时间戳）：按词流逐次匹配，同一句段里说两次「坐」算两次，
  时刻取命中那个词的时刻；旧缓存（无 words）仍按句段匹配，行为不变。
- 新增 kind="correction"（meta.correction_words，纠正词，如「不对」）。
- 长词优先：「好了」（释放词）里的「好」、「不对」（纠正词）里的「对」不再重复算成标记词。
- 合并转写（hybrid）：缓存里有 `alt_segments`（整段转写）时，两份各自匹配出事件再合并。
  以 `segments`（分句转写，时刻更准）为主；整段转写里的事件，若主结果在 MERGE_WINDOW 秒内
  有同类同词的事件且尚未被配过，算同一次（一对一，保留主结果时刻），否则作为漏识补进来。
"""

from __future__ import annotations

import json
import re
from pathlib import Path

from pawcoach.schema import AudioEvent, MetaInfo
from pawcoach.video.probe import VideoInfo

# 合并两份转写时，同类同词的事件相差不超过此秒数算同一次。
# 整段转写的时间戳实测比分句早约 1 秒（合成口令），取 1.5 秒；
# 一对一配对，所以「坐、坐」相隔 1.4 秒的两次口令不会被合成一次。
MERGE_WINDOW = 1.5

# 同音/近音/繁简表：meta 里的口令词 → whisper 可能转出的变体。
# 只放实测遇到或稳妥的常见同音，缺了就往这里补，匹配逻辑不用改。
_HOMOPHONES: dict[str, list[str]] = {
    # 中文（whisper 中文常出繁体、同音错字；dog1 里「坐」→「做」，见 reports/B5.md）
    "坐": ["做", "作", "座"],
    "好": ["號", "号", "郝"],
    "对": ["對"],
    # M5：释放词 / 纠正词的繁体与同音（whisper 中文常出繁体）
    "好了": ["號了", "号了"],
    "不对": ["不對"],
    "不许": ["不許"],
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


def _find_all(text_norm: str, key_norm: str) -> list[tuple[int, int]]:
    """key 在 text 里的所有出现位置 [start, end)。匹配规则同 `_contains`。"""
    if not key_norm:
        return []
    if key_norm.isascii():
        return [(m.start(), m.end()) for m in re.finditer(rf"\b{re.escape(key_norm)}\b", text_norm)]
    out, i = [], text_norm.find(key_norm)
    while i >= 0:
        out.append((i, i + len(key_norm)))
        i = text_norm.find(key_norm, i + 1)
    return out


def _spans(text_norm: str, keyword: str) -> list[tuple[int, int]]:
    """口令词 + 同音变体的所有出现位置（去重）。"""
    variants = [keyword] + [v for v in _HOMOPHONES.get(keyword, []) if v != keyword]
    found: set[tuple[int, int]] = set()
    for v in variants:
        found.update(_find_all(text_norm, _normalize(v)))
    return sorted(found)


def _word_stream(words: list[dict]) -> tuple[str, list[float], list[float]]:
    """把词级时间戳拼成一条归一化文本，并记下每个字符所属词的起止时刻。

    中文词之间直接拼接（「好」+「了」→「好了」，才能匹配多字词），ASCII 词之间补空格保留词边界。
    """
    text = ""
    starts: list[float] = []
    ends: list[float] = []
    for w in words:
        wn = _normalize(str(w.get("word", "")))
        if not wn:
            continue
        ws = float(w.get("start", 0.0))
        we = float(w.get("end", ws))
        if text and (wn[0].isascii() or text[-1].isascii()):
            text += " "
            starts.append(ws)
            ends.append(we)
        text += wn
        starts.extend([ws] * len(wn))
        ends.extend([we] * len(wn))
    return text, starts, ends


def _drop_contained(matches: list[tuple]) -> list[tuple]:
    """长词优先：一个命中的区间被另一个更长的命中严格包含时丢弃（如「好了」里的「好」）。"""
    keep = []
    for m in matches:
        _, _, a, b = m[:4]
        contained = any(
            o is not m and o[2] <= a and b <= o[3] and (o[3] - o[2]) > (b - a) for o in matches
        )
        if not contained:
            keep.append(m)
    return keep


def _segment_events(segments: list[dict], kinds) -> list[AudioEvent]:
    """一份转写的句段 → AudioEvent[]。"""
    events: list[AudioEvent] = []
    for seg in segments:
        start = float(seg.get("start", 0.0))
        end = float(seg.get("end", start))
        words = seg.get("words") or []
        if words:
            text_norm, starts, ends = _word_stream(words)
        else:
            text_norm, starts, ends = _normalize(str(seg.get("text", ""))), [], []

        matches: list[tuple] = []
        for kind, wordlist in kinds:
            for word in wordlist:
                for a, b in _spans(text_norm, word):
                    matches.append((kind, word, a, b))
        matches = _drop_contained(matches)

        if words:
            # 词级：每次出现都是一个事件，时刻取命中词的时刻
            for kind, word, a, b in matches:
                events.append(AudioEvent(word=word, t_start=starts[a], t_end=ends[b - 1], kind=kind))
        else:
            # 句段级（旧缓存）：每句段每个词只记一次，时刻取句段起止（与原行为一致）
            seen: set[tuple[str, str]] = set()
            for kind, word, _a, _b in matches:
                if (kind, word) in seen:
                    continue
                seen.add((kind, word))
                events.append(AudioEvent(word=word, t_start=start, t_end=end, kind=kind))
    return events


def merge_events(
    primary: list[AudioEvent], extra: list[AudioEvent], window: float = MERGE_WINDOW
) -> list[AudioEvent]:
    """以 primary 为主合并两份事件：extra 里能一对一配上 primary 的丢弃，配不上的补进来。

    配对条件：同 kind、同 word、起点相差 ≤ window；每个 primary 事件最多配一个，取最近的。
    长词优先（同 `_drop_contained`）：extra 的词被 primary 里时刻重叠的更长词包含时也丢弃，
    例如一份转出「好了」（释放词）、另一份只转出「好」时，不再多算一次标记词。
    """
    used = [False] * len(primary)
    merged = list(primary)
    for e in sorted(extra, key=lambda x: x.t_start):
        best, best_d = None, None
        for i, p in enumerate(primary):
            if used[i] or p.kind != e.kind or p.word != e.word:
                continue
            d = abs(p.t_start - e.t_start)
            if d <= window and (best_d is None or d < best_d):
                best, best_d = i, d
        if best is None:
            inside_longer = any(
                p.word != e.word and e.word in p.word
                and p.t_start - 1.0 <= e.t_start <= p.t_end + 1.0  # 比 window 紧，避免误丢真实的「好」
                for p in primary
            )
            if not inside_longer:
                merged.append(e)
        else:
            used[best] = True
    return sorted(merged, key=lambda x: x.t_start)


class AsrAudioExtractor:
    """读 Whisper 转写缓存（缺失时自动转写），把命中的口令/标记词/释放词/纠正词转成 AudioEvent。"""

    def __init__(self, asr_dir: str = "data/asr", auto_transcribe: bool = True, model_name: str | None = None):
        self.asr_dir = Path(asr_dir)
        self.auto_transcribe = auto_transcribe
        self.model_name = model_name
        # 本次 extract 的转写来源：cache / transcribed / no_audio / no_video / unavailable: … / failed: … / disabled
        self.last_status = ""

    def extract(self, video: VideoInfo, meta: MetaInfo) -> list[AudioEvent]:
        cache = self._find_cache(video)
        if cache is not None:
            self.last_status = "cache"
        else:
            cache = self._transcribe(video, meta)
            if cache is None:
                return []
        data = json.loads(cache.read_text(encoding="utf-8"))

        kinds = (
            ("cue", meta.cues),
            ("marker", meta.marker_words),
            ("release", meta.release_words),
            ("correction", getattr(meta, "correction_words", []) or []),
        )
        events = _segment_events(data.get("segments", []), kinds)
        alt = data.get("alt_segments")
        if alt:
            events = merge_events(events, _segment_events(alt, kinds))
        return sorted(events, key=lambda e: e.t_start)

    def _matches(self, text_norm: str, keyword: str) -> bool:
        """口令词 + 同音变体里，任一命中即算命中（委托给模块级 _matches，逻辑只此一份）。"""
        return _matches(text_norm, keyword)

    def _cache_path(self, video: VideoInfo) -> Path:
        stem = Path(video.path).stem
        if stem.endswith(".norm"):
            stem = stem[: -len(".norm")]
        return self.asr_dir / f"{stem}.json"

    def _find_cache(self, video: VideoInfo) -> Path | None:
        """按视频名找转写缓存；标准化产物带 .norm 后缀，剥掉以对齐原始视频名。"""
        cache = self._cache_path(video)
        return cache if cache.exists() else None

    def _transcribe(self, video: VideoInfo, meta: MetaInfo) -> Path | None:
        """缓存缺失时自动转写；任何不支持 / 失败都回退 None（空事件），不抛异常。"""
        if not self.auto_transcribe:
            self.last_status = "disabled"
            return None
        if not Path(video.path).exists():
            self.last_status = "no_video"
            return None
        if not video.has_audio:
            self.last_status = "no_audio"
            return None
        from pawcoach.audio import transcribe as tr

        cache = self._cache_path(video)
        try:
            tr.transcribe_to_cache(
                Path(video.path),
                cache,
                model_name=self.model_name or tr.DEFAULT_MODEL,
                language=getattr(meta, "language", None),
            )
        except tr.AsrUnavailable as e:
            self.last_status = f"unavailable: {e}"
            return None
        except Exception as e:  # noqa: BLE001  转写失败不让整段分析崩
            self.last_status = f"failed: {e}"
            return None
        self.last_status = "transcribed"
        return cache
