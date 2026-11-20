"""声音起音检测（流式，纯 numpy）。

只回答"什么时候有人开始出声"，不识别说了什么。离线路径里最不稳的一环是 Whisper 听孤立的中文单字
（"坐"被听成"走"，英文 "sit" 被听成 "that's"），而计时只需要时刻：口令在什么时候、奖励在什么时候。
前 0.5 秒是冷启动，只学底噪，所以点"开始"后请先安静半秒。
起音的时刻误差在 ±50 毫秒量级（见 tests/test_live_vad.py 对合成语音的实测），足够判断"晚没晚 1 秒"。

做法：每 20 毫秒一帧算均方根音量（dBFS），底噪用非说话帧的指数平均跟踪；
音量超过"底噪 + margin_db"且高于绝对门限，连续 min_run_frames 帧才算开始说话；
一次说话结束后 merge_gap_s 之内的再次出声并入同一次（"坐下"两个音节、一句话里的停顿不算两次）。

角色（口令还是奖励）不在这里判断，由 timeline.py 按"狗当时是站还是坐"来定。

限制（真机前必须知道）：
- 周围有别人说话、电视、狗叫都会被当成起音。底噪跟踪只能抵消持续的噪声，抵消不了突发的声音。
- 响片的"咔"只有二三十毫秒，可能达不到 min_run_frames；要用响片请用 App 里的"奖励"按钮点按。
"""

from __future__ import annotations

import numpy as np

SAMPLE_RATE = 16000


class OnsetDetector:
    def __init__(
        self,
        sr: int = SAMPLE_RATE,
        frame_s: float = 0.02,
        margin_db: float = 10.0,
        abs_gate_db: float = -45.0,
        min_run_frames: int = 3,
        merge_gap_s: float = 0.5,
        floor_init_db: float = -60.0,
        floor_alpha: float = 0.05,
        warmup_s: float = 0.5,
    ):
        self.sr = sr
        self.frame_n = int(round(sr * frame_s))
        self.frame_s = self.frame_n / sr
        self.margin_db = margin_db
        self.abs_gate_db = abs_gate_db
        self.min_run_frames = min_run_frames
        self.merge_gap_s = merge_gap_s
        self.floor_db = floor_init_db
        self.floor_alpha = floor_alpha
        # 冷启动：前 warmup_s 秒只学底噪，不上报。底噪初值是猜的，直接用会把正常的房间噪声当成说话。
        # 学习时用更大的步长（0.3）快速收敛；之后回到 floor_alpha 慢慢跟踪。
        self.warmup_s = warmup_s
        self._warm_left = warmup_s

        self._buf = np.zeros(0, dtype=np.float32)   # 不足一帧的残余采样
        self._buf_t0: float | None = None           # _buf[0] 对应的时刻
        self._run = 0                               # 当前连续出声的帧数
        self._run_start = 0.0
        self._confirmed = False                     # 当前这段出声是否已达到 min_run_frames
        self._last_end = -1e9                       # 最近一段"已确认出声"的结束时刻
        self.level_db: float = -90.0                # 最近一帧音量，界面画电平用
        self.frames_seen = 0
        self.voiced_frames = 0

    @staticmethod
    def _to_float(pcm: np.ndarray) -> np.ndarray:
        if pcm.dtype == np.int16:
            return pcm.astype(np.float32) / 32768.0
        return pcm.astype(np.float32)

    def feed(self, pcm: np.ndarray, t0: float) -> list[float]:
        """喂入一段 16 位 PCM（或 [-1,1] 浮点），t0 是这段第一个采样的时刻（秒）。

        返回这次新确认的起音时刻（秒）。一次出声要持续 min_run_frames 帧才确认，
        所以起音要晚约 60 毫秒才能上报，但上报的时刻是真正开始出声的那一帧。
        """
        x = self._to_float(np.asarray(pcm).reshape(-1))
        if self._buf_t0 is not None:
            expected = self._buf_t0 + len(self._buf) / self.sr
            if abs(t0 - expected) <= 0.1:
                x = np.concatenate([self._buf, x])
                t0 = self._buf_t0
            # 否则是丢了一块或时钟对不上：丢掉残余采样，以新的时刻重新起算

        out: list[float] = []
        n_frames = len(x) // self.frame_n
        for k in range(n_frames):
            seg = x[k * self.frame_n:(k + 1) * self.frame_n]
            t = t0 + k * self.frame_s
            db = 20.0 * float(np.log10(np.sqrt(np.mean(seg * seg) + 1e-12) + 1e-9))
            self.level_db = db
            self.frames_seen += 1

            if self._warm_left > 0:
                self._warm_left -= self.frame_s
                self.floor_db = db if self.frames_seen == 1 else 0.7 * self.floor_db + 0.3 * db
                continue

            if db > max(self.floor_db + self.margin_db, self.abs_gate_db):
                self.voiced_frames += 1
                if self._run == 0:
                    self._run_start = t
                self._run += 1
                if self._run >= self.min_run_frames:
                    if not self._confirmed:
                        self._confirmed = True
                        # 与上一次出声隔得很近：算同一次说话，不再上报
                        if self._run_start - self._last_end >= self.merge_gap_s:
                            out.append(round(self._run_start, 3))
                    self._last_end = t + self.frame_s
            else:
                self._run = 0
                self._confirmed = False
                # 只在没出声的帧上更新底噪，且不让它被偶发的大声拉高
                self.floor_db = (1 - self.floor_alpha) * self.floor_db + self.floor_alpha * max(db, -75.0)

        self._buf = x[n_frames * self.frame_n:].copy()
        self._buf_t0 = t0 + n_frames * self.frame_s
        return out
