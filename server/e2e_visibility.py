"""M4 双端可见性端到端测试（简报第 10 节第 5 条）。

起真实 server/（临时数据库、独立端口）→ 注册成员 B → 在 Android 模拟器上跑
integration_test/m4_family_e2e_test.dart（设备 A）→ 计时两个方向：
  方向 1：A 记录页点保存 → B 轮询 GET /v1/sync/pull（每 100 ms）拉到该记录
  方向 2：B POST /v1/sync/push 一条训练记录 → A 首页目标次数变化
设备与主机时钟偏差用 adb shell date 校正。两个方向都要 ≤ 10 秒，否则退出码 1。

用法：
  cd server && .venv/bin/python e2e_visibility.py [--port 8765] [--device emulator-5554]
依赖：仅标准库 + 本目录 .venv 里的 uvicorn。token / 邀请码不打印。
"""

from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
import uuid
from datetime import datetime, timezone

HERE = os.path.dirname(os.path.abspath(__file__))
APP = os.path.join(os.path.dirname(HERE), "app")
LIMIT_S = 10.0


def http(method, url, token=None, body=None):
    req = urllib.request.Request(url, method=method, data=None if body is None else json.dumps(body).encode())
    req.add_header("Content-Type", "application/json")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, timeout=5) as r:
        return json.loads(r.read())


def iso(ms: int) -> str:
    return datetime.fromtimestamp(ms / 1000, timezone.utc).strftime("%Y-%m-%dT%H:%M:%S.") + f"{ms % 1000:03d}Z"


def device_offset_ms(adb, device):
    """主机时间 - 设备时间（毫秒），取 3 次 adb 往返中最短的一次。"""
    best = None
    for _ in range(3):
        t0 = time.time() * 1000
        out = subprocess.check_output([adb, "-s", device, "shell", "date", "+%s%N"], text=True).strip()
        t1 = time.time() * 1000
        dev = int(out) / 1e6
        rtt = t1 - t0
        off = (t0 + t1) / 2 - dev
        if best is None or rtt < best[0]:
            best = (rtt, off)
    return best[1], best[0]


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--device", default="emulator-5554")
    ap.add_argument("--flutter", default=os.path.expanduser("~/development/flutter/bin/flutter"))
    ap.add_argument("--adb", default=shutil.which("adb") or os.path.expanduser("~/Library/Android/sdk/platform-tools/adb"))
    a = ap.parse_args()
    base = f"http://127.0.0.1:{a.port}"

    tmp = tempfile.mkdtemp(prefix="m4e2e")
    env = dict(os.environ, DB_PATH=os.path.join(tmp, "e2e.db"), FAKE_UPSTREAM="1")
    server = subprocess.Popen(
        [os.path.join(HERE, ".venv/bin/uvicorn"), "main:app", "--host", "0.0.0.0", "--port", str(a.port),
         "--log-level", "warning"],
        cwd=HERE, env=env)
    try:
        for _ in range(50):
            try:
                http("GET", base + "/healthz")
                break
            except Exception:
                time.sleep(0.2)
        b = http("POST", base + "/v1/users", body={"nickname": "爸爸"})
        b_token, b_user = b["token"], b["user_id"]
        offset, rtt = device_offset_ms(a.adb, a.device)
        print(f"[e2e] 设备时钟偏差 host-device = {offset:.0f} ms（adb 往返 {rtt:.0f} ms）", flush=True)

        cmd = [a.flutter, "test", "integration_test/m4_family_e2e_test.dart", "-d", a.device,
               f"--dart-define=SYNC_BASE_URL=http://10.0.2.2:{a.port}", f"--dart-define=E2E_B_TOKEN={b_token}"]
        proc = subprocess.Popen(cmd, cwd=APP, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)

        state = {"hid": None, "dog": None, "session": None, "tap_ms": None, "seen1": None,
                 "push_ms": None, "seen2": None, "since": 0, "lines": []}
        stop = threading.Event()

        def poll():
            while not stop.is_set():
                if state["hid"] and state["seen1"] is None:
                    try:
                        r = http("GET", f"{base}/v1/sync/pull?household_id={state['hid']}&since_seq={state['since']}", b_token)
                        now = time.time() * 1000
                        for rec in r["records"]:
                            if rec["table"] == "training_sessions" and state["session"] in (None, rec["pk"]):
                                if state["session"] is None:
                                    state["pending"] = (rec["pk"], now)
                                else:
                                    state["seen1"] = now
                        state["since"] = r["max_seq"]
                        p = state.get("pending")
                        if p and state["session"] == p[0]:
                            state["seen1"] = p[1]
                    except Exception as e:  # noqa: BLE001
                        print(f"[e2e] pull 失败：{type(e).__name__}", flush=True)
                time.sleep(0.1)

        th = threading.Thread(target=poll, daemon=True)
        th.start()

        for line in proc.stdout:
            line = line.rstrip()
            if "E2E_" not in line and not re.search(r"(\+\d+|-\d+): |Some tests|All tests|EXCEPTION|Error", line):
                continue
            # 不回显可能含 dart-define 的命令行；E2E 行本身不含 token / 邀请码
            print(line, flush=True)
            if m := re.search(r"E2E_JOINED household=(\S+) dog=(\S+)", line):
                state["hid"], state["dog"] = m.group(1), m.group(2)
            elif m := re.search(r"E2E_CHECKIN session=(\S+) tap_ms=(\d+)", line):
                state["tap_ms"] = int(m.group(2))
                state["session"] = m.group(1)
                p = state.get("pending")
                if p and p[0] == state["session"]:
                    state["seen1"] = p[1]
            elif m := re.search(r"E2E_WAIT_B skill=(\S+)", line):
                skill = m.group(1)
                now = int(time.time() * 1000)
                sid = "ses_e2e_" + uuid.uuid4().hex[:10]
                rec = {"table": "training_sessions", "pk": sid, "client_updated_at": iso(now), "deleted": False,
                       "payload": {"id": sid, "dog_id": state["dog"], "user_id": b_user, "skill_id": skill,
                                   "script_part": 1, "started_at": iso(now - 180000), "ended_at": iso(now),
                                   "duration_sec": 180, "score": "full", "note_text": None, "note_video_url": None,
                                   "skipped_steps": "[]", "clicker_count": 0}}
                state["push_ms"] = time.time() * 1000
                http("POST", base + "/v1/sync/push", b_token, {"household_id": state["hid"], "records": [rec]})
            elif m := re.search(r"E2E_SEEN_B at_ms=(\d+)", line):
                state["seen2"] = int(m.group(1)) + offset
        rc = proc.wait()
        stop.set()

        d1 = None if state["seen1"] is None or state["tap_ms"] is None else (state["seen1"] - (state["tap_ms"] + offset)) / 1000
        d2 = None if state["seen2"] is None or state["push_ms"] is None else (state["seen2"] - state["push_ms"]) / 1000
        print("")
        print(f"[e2e] 方向 1（A 打卡 → B 拉到）：{'未测到' if d1 is None else f'{d1:.2f} s'}")
        print(f"[e2e] 方向 2（B 推送 → A 首页更新）：{'未测到' if d2 is None else f'{d2:.2f} s'}")
        ok = rc == 0 and d1 is not None and d2 is not None and d1 <= LIMIT_S and d2 <= LIMIT_S
        print(f"[e2e] 结论：{'通过' if ok else '未通过'}（上限 {LIMIT_S:.0f} 秒，flutter test 退出码 {rc}）")
        with open(os.path.join(HERE, "e2e_last_result.json"), "w") as f:
            json.dump({"direction1_s": d1, "direction2_s": d2, "flutter_rc": rc, "offset_ms": offset,
                       "at": datetime.now().isoformat(timespec="seconds"), "pass": ok}, f, ensure_ascii=False, indent=2)
        return 0 if ok else 1
    finally:
        server.terminate()
        server.wait(timeout=5)
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
