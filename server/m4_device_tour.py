"""M4 设备实测截图：起真实 server/（临时库）→ 注册成员 B（API 身份）→ 跑
integration_test/m4_device_tour_test.dart → 每个 M4SHOT 行用 adb 截图到 app/build/m4_screenshots/。

用法：cd server && .venv/bin/python m4_device_tour.py [--port 8766] [--device emulator-5554]
      批次 B：.venv/bin/python m4_device_tour.py --test integration_test/m4b_device_tour_test.dart --out m4b_screenshots
"""

from __future__ import annotations

import argparse
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

from e2e_visibility import APP, HERE, http


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8766)
    ap.add_argument("--test", default="integration_test/m4_device_tour_test.dart")
    ap.add_argument("--out", default="m4_screenshots")
    ap.add_argument("--device", default="emulator-5554")
    ap.add_argument("--flutter", default=os.path.expanduser("~/development/flutter/bin/flutter"))
    ap.add_argument("--adb", default=shutil.which("adb") or os.path.expanduser("~/Library/Android/sdk/platform-tools/adb"))
    a = ap.parse_args()
    base = f"http://127.0.0.1:{a.port}"
    out_dir = os.path.join(APP, "build", a.out)
    os.makedirs(out_dir, exist_ok=True)
    tmp = tempfile.mkdtemp(prefix="m4tour")
    env = dict(os.environ, DB_PATH=os.path.join(tmp, "tour.db"), FAKE_UPSTREAM="1")
    server = subprocess.Popen([os.path.join(HERE, ".venv/bin/uvicorn"), "main:app", "--host", "0.0.0.0",
                               "--port", str(a.port), "--log-level", "warning"], cwd=HERE, env=env)
    try:
        for _ in range(50):
            try:
                http("GET", base + "/healthz")
                break
            except Exception:
                time.sleep(0.2)
        b = http("POST", base + "/v1/users", body={"nickname": "爸爸"})
        cmd = [a.flutter, "test", a.test, "-d", a.device,
               f"--dart-define=SYNC_BASE_URL=http://10.0.2.2:{a.port}",
               f"--dart-define=E2E_B_TOKEN={b['token']}", f"--dart-define=E2E_B_USER={b['user_id']}"]
        proc = subprocess.Popen(cmd, cwd=APP, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        in_exc = False
        for line in proc.stdout:
            line = line.rstrip()
            if "EXCEPTION CAUGHT" in line:
                in_exc = True
            if in_exc and "dart-define" not in line:
                print(line, flush=True)
                if line.startswith("════════") and "EXCEPTION" not in line:
                    in_exc = False
                continue
            if "+0: M4" in line:
                # App 已装好：授予通知权限，AI-5 截通知栏时需要
                subprocess.run([a.adb, "-s", a.device, "shell", "pm", "grant", "com.puppytrainer.puppy_trainer",
                                "android.permission.POST_NOTIFICATIONS"], check=False)
            if m := re.search(r"M4CMD (expand|collapse)", line):
                sub = "expand-notifications" if m.group(1) == "expand" else "collapse"
                subprocess.run([a.adb, "-s", a.device, "shell", "cmd", "statusbar", sub], check=False)
                continue
            if m := re.search(r"M4SHOT (\S+)", line):
                path = os.path.join(out_dir, m.group(1) + ".png")
                with open(path, "wb") as f:
                    subprocess.run([a.adb, "-s", a.device, "exec-out", "screencap", "-p"], stdout=f, check=False)
                print(f"[tour] 截图 {path}", flush=True)
            elif re.search(r"M4TOUR|(\+\d+|-\d+): |Some tests|All tests|Expected|Actual|超时|失败|Exception|Error", line):
                print(line, flush=True)
        rc = proc.wait()
        print(f"[tour] flutter test 退出码 {rc}")
        return rc
    finally:
        server.terminate()
        server.wait(timeout=5)
        shutil.rmtree(tmp, ignore_errors=True)


if __name__ == "__main__":
    sys.exit(main())
