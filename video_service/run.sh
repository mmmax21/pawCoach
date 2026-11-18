#!/usr/bin/env bash
# M5：启动视频分析服务（0.0.0.0:8001，局域网内的手机 / 模拟器可访问）。
# 用法：./run.sh            （演示前先跑一次 python scripts/warmup.py 预热）
# 环境变量：COACH_MODE=off（默认，不调任何大模型）/ template / llm；PORT 可覆盖端口（默认 8001）。
set -euo pipefail

cd "$(dirname "$0")"
PORT="${PORT:-8001}"
ENV_NAME="pawcoach"

# 激活 conda 环境（ffmpeg、whisper、deeplabcut 都在里面）
if [ "${CONDA_DEFAULT_ENV:-}" != "$ENV_NAME" ]; then
  CONDA_BASE="$(conda info --base 2>/dev/null || echo "$HOME/miniforge3")"
  # shellcheck disable=SC1091
  source "$CONDA_BASE/etc/profile.d/conda.sh"
  conda activate "$ENV_NAME"
fi

command -v ffmpeg >/dev/null || { echo "找不到 ffmpeg：conda 环境 $ENV_NAME 未正确激活" >&2; exit 1; }

if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >/dev/null 2>&1; then
  echo "端口 $PORT 已被占用：" >&2
  lsof -nP -iTCP:"$PORT" -sTCP:LISTEN >&2
  echo "（若是旧的 docker 容器 pawcoach-pawcoach-1，可用 docker stop pawcoach-pawcoach-1 停掉）" >&2
  exit 1
fi

export COACH_MODE="${COACH_MODE:-off}"
# 关闭 ultralytics 的联网检查与匿名统计（演示现场只用本机权重）
export YOLO_OFFLINE=1
echo "PawCoach video_service  http://0.0.0.0:$PORT  COACH_MODE=$COACH_MODE"
exec python -m uvicorn app.main:app --host 0.0.0.0 --port "$PORT"
