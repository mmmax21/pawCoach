"""合成测试视频：站 / 坐两张静帧按时间线拼接 + macOS say 合成的口令音轨。

用法：python make_clip.py <scenario> <out.mp4>
"""
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).parent

# (起始秒, 姿态) — 姿态持续到下一项；最后一项持续到 END
SCENARIOS = {
    # 坐下：奖励晚 + 口令重复 → 期望命中 late_reward、repeated_cue
    "sit_bad": {
        "end": 24.0,
        "poses": [(0, "stand"), (2.0, "sit"), (6.0, "stand"), (10.5, "sit"), (14.5, "stand"), (18.0, "sit"), (21.5, "stand")],
        "words": [(0.8, "坐"), (4.2, "好"), (5.3, "好了"), (8.0, "坐"), (9.4, "坐"), (12.6, "好"), (13.8, "好了"),
                  (16.8, "坐"), (18.3, "好"), (20.8, "好了")],
    },
    # 坐下：一次口令、坐下即奖励 → 期望无问题
    "sit_good": {
        "end": 24.0,
        "poses": [(0, "stand"), (2.0, "sit"), (6.0, "stand"), (9.5, "sit"), (13.5, "stand"), (17.0, "sit"), (21.0, "stand")],
        "words": [(0.8, "坐"), (2.2, "好"), (5.3, "好了"), (8.3, "坐"), (9.7, "好"), (12.8, "好了"),
                  (15.8, "坐"), (17.2, "好"), (20.3, "好了")],
    },
    # 真实情况复现：后两次口令被听成别的词（"看"），第二轮奖励晚 2 秒 → 期望 cueNotHeard，补标后命中 late_reward
    "sit_missed": {
        "end": 24.0,
        "poses": [(0, "stand"), (2.0, "sit"), (6.0, "stand"), (9.5, "sit"), (13.5, "stand"), (17.0, "sit"), (21.0, "stand")],
        "words": [(0.8, "坐"), (2.2, "好"), (5.3, "好了"), (8.3, "看"), (11.5, "好"), (12.8, "好了"),
                  (15.8, "看"), (17.2, "好"), (20.3, "好了")],
    },
}


def say(word: str, out: Path) -> None:
    subprocess.run(["say", "-v", "Tingting", "-o", str(out), word], check=True)


def main() -> None:
    name, out = sys.argv[1], Path(sys.argv[2]).resolve()
    sc = SCENARIOS[name]
    tmp = Path(tempfile.mkdtemp())
    # 视频：concat demuxer
    lines = []
    poses = sc["poses"]
    for i, (t, pose) in enumerate(poses):
        nxt = poses[i + 1][0] if i + 1 < len(poses) else sc["end"]
        lines.append(f"file '{HERE / (pose + '.png')}'\nduration {nxt - t:.2f}")
    lines.append(f"file '{HERE / (poses[-1][1] + '.png')}'")
    (tmp / "list.txt").write_text("\n".join(lines))
    # 音频：每个词一个 aiff，adelay 到指定时刻后混音
    inputs, filters = [], []
    for i, (t, w) in enumerate(sc["words"]):
        a = tmp / f"w{i}.aiff"
        say(w, a)
        inputs += ["-i", str(a)]
        ms = int(t * 1000)
        filters.append(f"[{i + 1}:a]adelay={ms}|{ms},apad[a{i}]")
    mix = "".join(f"[a{i}]" for i in range(len(sc["words"])))
    filters.append(f"{mix}amix=inputs={len(sc['words'])}:normalize=0,atrim=0:{sc['end']}[aout]")
    cmd = [
        "ffmpeg", "-y", "-loglevel", "error",
        "-f", "concat", "-safe", "0", "-i", str(tmp / "list.txt"),
        *inputs,
        "-filter_complex", ";".join(filters),
        "-map", "0:v", "-map", "[aout]",
        "-vf", "fps=30,format=yuv420p", "-c:v", "libx264", "-c:a", "aac", "-t", str(sc["end"]), str(out),
    ]
    subprocess.run(cmd, check=True)
    print(out)


if __name__ == "__main__":
    main()
