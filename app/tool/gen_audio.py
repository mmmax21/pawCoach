#!/usr/bin/env python3
"""生成跟练用的两个占位音频（纯标准库，输出 16-bit PCM WAV）。

- assets/audio/silence.wav：1 秒静音，循环播放，用于后台保活（M2 简报第 6 节）。
- assets/audio/clicker.wav：约 70 毫秒的方波短促"咔哒"，占位响片音效。
  Fable 提供 CC0 正式素材后直接覆盖同名文件即可。

用法：python3 app/tool/gen_audio.py
"""
import math
import os
import struct
import wave

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
os.makedirs(OUT, exist_ok=True)


def write(name: str, rate: int, samples: list[int]) -> None:
    path = os.path.join(OUT, name)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        w.writeframes(b"".join(struct.pack("<h", s) for s in samples))
    print(f"{path}: {os.path.getsize(path)} bytes")


# 静音：22.05kHz 单声道 1 秒。
write("silence.wav", 22050, [0] * 22050)

# 响片占位：2.4kHz 方波 + 指数衰减，70ms。
rate = 44100
n = int(rate * 0.07)
freq = 2400
clicks = []
for i in range(n):
    sq = 1 if math.sin(2 * math.pi * freq * i / rate) >= 0 else -1
    env = math.exp(-i / (rate * 0.018))
    clicks.append(int(sq * env * 0.6 * 32767))
write("clicker.wav", rate, clicks)
