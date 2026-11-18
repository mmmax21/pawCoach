"""集中配置：LLM 后端（模型 / key / 地址）作为单独的配置项。

优先级：进程环境变量 > .env 文件 > 默认值。
.env 已加进 .gitignore（本地的 key 不会提交），模板见 .env.example。
"""

from __future__ import annotations

import os
from pathlib import Path

_ENV_PATH = Path(".env")

_DEFAULTS = {
    # 模型名取自赞助商 /v1/models 列表（deepseek-v4-flash）；列表里没有「deepseek-flash」这个名字
    "model": "deepseek-v4-flash",
    "base_url": "https://api.openai-next.com/v1/chat/completions",
    "api_key": "",
}

# 配置项 -> 环境变量名
_ENV_KEYS = {
    "model": "LLM_MODEL",
    "base_url": "LLM_BASE_URL",
    "api_key": "LLM_API_KEY",
}


def _load_dotenv(path: Path) -> dict[str, str]:
    """手写 .env 解析：KEY=VALUE，支持 # 注释、export 前缀、引号。文件缺失返回空 dict。"""
    if not path.exists():
        return {}
    out: dict[str, str] = {}
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[len("export "):]
        if "=" not in line:
            continue
        key, _, value = line.partition("=")
        key = key.strip()
        value = value.strip().strip('"').strip("'")
        if key:
            out[key] = value
    return out


def llm_config() -> dict[str, str]:
    """LLM 后端配置 {model, api_key, base_url}。环境变量 > .env > 默认。"""
    file_env = _load_dotenv(_ENV_PATH)
    cfg: dict[str, str] = {}
    for field, env_key in _ENV_KEYS.items():
        cfg[field] = os.environ.get(env_key) or file_env.get(env_key) or _DEFAULTS[field]
    return cfg


# M5：教练文字模式。off（默认）= coach 为空串、不发任何外部请求；template = 本地模板；llm = 调大模型。
COACH_MODES = ("off", "template", "llm")


def coach_mode() -> str:
    """COACH_MODE：环境变量 > .env > 默认 off；非法取值按 off 处理（宁可不调大模型）。"""
    raw = os.environ.get("COACH_MODE") or _load_dotenv(_ENV_PATH).get("COACH_MODE") or "off"
    mode = raw.strip().lower()
    return mode if mode in COACH_MODES else "off"
