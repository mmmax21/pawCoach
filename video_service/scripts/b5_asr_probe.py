"""B5：Whisper 转写探路脚本（进 analyze 之前先验证 ASR 能出带时间戳的转写）。

对一段视频的音轨跑 openai-whisper（base 模型），打印带时间戳的分段转写，
并保存 JSON 到 data/asr/<视频名>.json，供 B6 的 AsrAudioExtractor 复用。

用法（.venv-b 里，需要 openai-whisper 和 base 模型）：
    python scripts/b5_asr_probe.py data/raw/dog3.mp4
首次运行会自动下载 base 模型（139MB），国外站点要先 export https_proxy=...
"""

from __future__ import annotations

import argparse
import json
import time
from pathlib import Path

DEFAULT_MODEL = "base"


def transcribe(video: Path, model_name: str = DEFAULT_MODEL, language: str | None = None) -> dict:
    import whisper

    model = whisper.load_model(model_name)
    t0 = time.time()
    result = model.transcribe(str(video), language=language, verbose=False)
    return {
        "video": video.name,
        "model": model_name,
        "language": result.get("language"),
        "text": (result.get("text") or "").strip(),
        "segments": [
            {"start": round(s["start"], 2), "end": round(s["end"], 2), "text": s["text"].strip()}
            for s in result.get("segments", [])
        ],
        "elapsed_s": round(time.time() - t0, 1),
    }


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    ap.add_argument("--model", default=DEFAULT_MODEL)
    ap.add_argument("--language", default=None, help="强制语言，如 zh / en；默认自动检测")
    ap.add_argument("--out-dir", default="data/asr")
    args = ap.parse_args()

    video = Path(args.video)
    result = transcribe(video, args.model, args.language)
    print(f"语言={result['language']}  模型={result['model']}  耗时 {result['elapsed_s']}s")
    print(f"全文: {result['text'] or '(空)'}")
    for s in result["segments"]:
        print(f"  [{s['start']:6.2f} - {s['end']:6.2f}] {s['text']}")
    out_dir = Path(args.out_dir)
    out_dir.mkdir(parents=True, exist_ok=True)
    out = out_dir / f"{video.stem}.json"
    out.write_text(json.dumps(result, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"已保存：{out}")


if __name__ == "__main__":
    main()
