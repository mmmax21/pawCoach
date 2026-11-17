#!/usr/bin/env python3
"""合成正式响片音效（替换 M2 的方波占位），纯标准库，输出 16-bit PCM WAV。

真实盒式响片是一片弹簧钢片被按下再弹回，声音由两个短促的宽频瞬态组成：
按下（较闷、略低）和回弹（更亮、略高），各带一个快速衰减的金属共振。
这里用 噪声脉冲 + 两个共振峰 + 指数包络 合成，总长约 90 毫秒。
Fable 制作，无第三方素材，无版权问题。

用法：python3 app/tool/gen_clicker.py
"""
import math
import os
import random
import struct
import wave

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio", "clicker.wav")
RATE = 44100
random.seed(7)


def transient(start_s: float, dur_s: float, f1: float, f2: float, noise_amt: float, gain: float, decay_s: float):
    n = int(RATE * dur_s)
    out = []
    for i in range(n):
        t = i / RATE
        env = math.exp(-t / decay_s)
        # 前 1.5ms 的宽频噪声脉冲模拟钢片撞击
        noise = (random.random() * 2 - 1) * noise_amt * math.exp(-t / 0.0012)
        ring = 0.6 * math.sin(2 * math.pi * f1 * t) + 0.4 * math.sin(2 * math.pi * f2 * t)
        out.append((noise + ring * env) * gain)
    return int(RATE * start_s), out


total = int(RATE * 0.09)
buf = [0.0] * total
# 按下：稍闷
for off, s in [transient(0.0, 0.05, 3100, 5200, 0.9, 0.55, 0.006)]:
    for i, v in enumerate(s):
        if off + i < total:
            buf[off + i] += v
# 回弹：更亮，间隔约 28ms
for off, s in [transient(0.028, 0.06, 4300, 7800, 1.0, 0.75, 0.008)]:
    for i, v in enumerate(s):
        if off + i < total:
            buf[off + i] += v

peak = max(abs(v) for v in buf)
samples = [int(max(-1.0, min(1.0, v / peak * 0.85)) * 32767) for v in buf]
# 末尾 3ms 淡出，避免咔哒尾音
fade = int(RATE * 0.003)
for i in range(fade):
    samples[total - fade + i] = int(samples[total - fade + i] * (1 - i / fade))

with wave.open(OUT, "wb") as w:
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(RATE)
    w.writeframes(b"".join(struct.pack("<h", s) for s in samples))
print(f"{OUT}: {os.path.getsize(OUT)} bytes, {total / RATE * 1000:.0f} ms")
