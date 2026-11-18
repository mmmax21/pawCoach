"""Whisper 转写（M5 3.1：上传即自动转写）。

原先在 scripts/b5_asr_probe.py 里，只能手动跑；现在抽成库函数：
- AsrAudioExtractor 找不到 data/asr/<视频名>.json 时调用 `transcribe_to_cache` 自动生成；
- scripts/b5_asr_probe.py 复用 `transcribe`；
- scripts/warmup.py 用 `load_model` 预先下载、加载模型。

缓存格式与原脚本一致（video/model/language/text/segments/elapsed_s），
segments 里每段额外带可选的 `words`（词级时间戳），旧缓存没有这个字段也照常读。

模型在进程内只加载一次（按模型名缓存）。环境里没有 whisper 时抛 `AsrUnavailable`，
由调用方回退为空事件，不崩。

两种转写方式（`mode`）：
- `chunked`（默认）：先按音量切出一句句话（能量 VAD），每句单独交给 Whisper，时刻取该句的声音起点。
  训练视频里的口令是短促的单字（坐 / 好 / 好了），整段直接转写时 Whisper 常漏掉孤立短词、
  时间戳也会提前约 1 秒（合成口令实测：整段 10 个词只识别 6 个）；分句后逐句转写更稳。
- `whole`：原 b5 脚本的整段转写。
- `hybrid`（默认）：两种都跑，分句结果放 `segments`，整段结果放 `alt_segments`，
  由 AsrAudioExtractor 在事件层合并（同类同词、时刻相近的算同一次）。
  两种方式各有漏识：合成口令上分句更准（10/10 对 6/10），中文实拍上整段更准
  （「坐」2/2 对 0/2，分句把两次都听成「走」），合并后取并集。
  language=None 时先跑整段，用它检测出的语言去跑分句（分句逐句检测语言会乱，实测出现日文、韩文）。
"""

from __future__ import annotations

import json
import threading
import time
from pathlib import Path

DEFAULT_MODEL = "base"
DEFAULT_MODE = "hybrid"
MODES = ("hybrid", "chunked", "whole")
SAMPLE_RATE = 16000

# 能量 VAD 参数（秒）：20ms 帧；相邻语音间隔短于 MERGE_GAP 合成一句；短于 MIN_VOICE 的丢弃；前后各补 PAD
_FRAME = 0.02
_MERGE_GAP = 0.3
_MIN_VOICE = 0.12
_PAD = 0.15
_MAX_CHUNK = 25.0

_MODELS: dict[str, object] = {}
_LOCK = threading.Lock()


class AsrUnavailable(RuntimeError):
    """当前环境不支持转写（缺 openai-whisper 或模型加载失败）。"""


def whisper_available() -> bool:
    try:
        import whisper  # noqa: F401
    except Exception:
        return False
    return True


def load_model(model_name: str = DEFAULT_MODEL):
    """加载 Whisper 模型，进程内缓存；首次会下载到 ~/.cache/whisper。"""
    with _LOCK:
        model = _MODELS.get(model_name)
        if model is not None:
            return model
        try:
            import whisper
        except Exception as e:  # noqa: BLE001
            raise AsrUnavailable(f"缺少 openai-whisper：{e}") from e
        try:
            model = whisper.load_model(model_name)
        except Exception as e:  # noqa: BLE001
            raise AsrUnavailable(f"Whisper 模型 {model_name} 加载失败：{e}") from e
        _MODELS[model_name] = model
        return model


def model_loaded(model_name: str = DEFAULT_MODEL) -> bool:
    return model_name in _MODELS


def _load_audio(video: Path):
    """16kHz 单声道 float32（Whisper 自带的 ffmpeg 解码）。"""
    import whisper

    return whisper.load_audio(str(video))


def voice_regions(audio, sr: int = SAMPLE_RATE) -> list[tuple[float, float]]:
    """能量 VAD：返回 [(起, 止)] 秒。阈值按本段音频自适应（底噪与峰值之间 15% 处）。"""
    import numpy as np

    hop = int(sr * _FRAME)
    n = len(audio) // hop
    if n == 0:
        return []
    frames = np.asarray(audio[: n * hop], dtype=np.float32).reshape(n, hop)
    rms = np.sqrt((frames**2).mean(axis=1) + 1e-12)
    noise, peak = np.percentile(rms, 10), np.percentile(rms, 99.5)
    if peak < 1e-3 or peak < noise * 3:  # 几乎静音或没有明显起伏
        return []
    thr = noise + 0.15 * (peak - noise)
    voiced = rms > thr
    regions: list[list[float]] = []
    i = 0
    while i < n:
        if not voiced[i]:
            i += 1
            continue
        j = i
        while j < n and voiced[j]:
            j += 1
        a, b = i * _FRAME, j * _FRAME
        if regions and a - regions[-1][1] < _MERGE_GAP:
            regions[-1][1] = b
        else:
            regions.append([a, b])
        i = j
    total = n * _FRAME
    out = []
    for a, b in regions:
        if b - a < _MIN_VOICE:
            continue
        a, b = max(0.0, a - _PAD), min(total, b + _PAD)
        while b - a > _MAX_CHUNK:  # 超长连续说话按 25 秒切
            out.append((a, a + _MAX_CHUNK))
            a += _MAX_CHUNK
        out.append((a, b))
    return out


def _seg(start: float, end: float, text: str, words: list[dict] | None = None) -> dict:
    seg = {"start": round(float(start), 2), "end": round(float(end), 2), "text": text.strip()}
    if words:
        seg["words"] = words
    return seg


def _transcribe_chunked(model, video: Path, language: str | None) -> tuple[list[dict], str | None]:
    import numpy as np

    audio = _load_audio(video)
    segments: list[dict] = []
    detected = None
    pad = np.zeros(int(0.3 * SAMPLE_RATE), dtype=np.float32)
    for a, b in voice_regions(audio):
        chunk = np.concatenate([pad, audio[int(a * SAMPLE_RATE) : int(b * SAMPLE_RATE)], pad])
        r = model.transcribe(
            chunk, language=language, verbose=None, fp16=False, word_timestamps=True,
            condition_on_previous_text=False, temperature=0.0,
        )
        detected = detected or r.get("language")
        for s in r.get("segments", []):
            text = (s.get("text") or "").strip()
            # Whisper 在噪声片段上会编句子：无语音概率高且置信低的丢掉
            if not text or (s.get("no_speech_prob", 0) > 0.6 and s.get("avg_logprob", 0) < -1.0):
                continue
            off = a - 0.3  # 减去前补的静音
            words = [
                {
                    "start": round(max(a + _PAD * 0.5, w["start"] + off), 2),
                    "end": round(max(a + _PAD * 0.5, w["end"] + off), 2),
                    "word": w["word"],
                }
                for w in (s.get("words") or [])
            ]
            # 一句里只有一个词时，时刻取声音起点（DTW 词级时间戳在短句上偏差大）
            if len(words) == 1:
                words[0]["start"] = round(a + _PAD, 2)
            segments.append(_seg(max(a, s["start"] + off), min(b, s["end"] + off), text, words))
    return segments, detected


def _transcribe_whole(model, video: Path, language: str | None) -> tuple[list[dict], str | None, str]:
    # 词级时间戳：口令「坐，坐」或等待中的多次「好」常落在同一句段里，按句段只能计一次
    result = model.transcribe(
        str(video), language=language, verbose=None, word_timestamps=True, fp16=False
    )
    segments = []
    for s in result.get("segments", []):
        words = [
            {"start": round(float(w["start"]), 2), "end": round(float(w["end"]), 2), "word": w["word"]}
            for w in (s.get("words") or [])
        ]
        segments.append(_seg(s["start"], s["end"], s.get("text") or "", words))
    return segments, result.get("language"), (result.get("text") or "").strip()


def transcribe(
    video: Path,
    model_name: str = DEFAULT_MODEL,
    language: str | None = None,
    mode: str | None = None,
) -> dict:
    """转写一段视频的音轨，返回缓存格式的 dict。language=None 时自动检测。"""
    video = Path(video)
    model = load_model(model_name)
    mode = mode or DEFAULT_MODE
    if mode not in MODES:
        raise ValueError(f"未知转写方式 {mode!r}，可选 {MODES}")
    t0 = time.time()
    out: dict = {"video": video.name, "model": model_name, "mode": mode}
    if mode == "whole":
        segments, lang, text = _transcribe_whole(model, video, language)
        out.update(language=lang, text=text, segments=segments)
    elif mode == "chunked":
        segments, lang = _transcribe_chunked(model, video, language)
        out.update(language=lang or language, text=" ".join(s["text"] for s in segments), segments=segments)
    else:  # hybrid
        alt, whole_lang, _ = _transcribe_whole(model, video, language)
        lang = language or whole_lang
        segments, _ = _transcribe_chunked(model, video, lang)
        out.update(
            language=lang, text=" ".join(s["text"] for s in segments),
            segments=segments, alt_segments=alt,
        )
    out["elapsed_s"] = round(time.time() - t0, 1)
    return out


def transcribe_to_cache(
    video: Path,
    cache: Path,
    model_name: str = DEFAULT_MODEL,
    language: str | None = None,
) -> dict:
    """转写并写入缓存文件（格式同 scripts/b5_asr_probe.py 的输出）。"""
    data = transcribe(video, model_name, language)
    cache.parent.mkdir(parents=True, exist_ok=True)
    cache.write_text(json.dumps(data, ensure_ascii=False, indent=2), encoding="utf-8")
    return data
