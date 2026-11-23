"""v3：本地模型判不了的帧，交给 Claude 看图兜底（俯拍为主）。默认关闭，需要明确打开。

为什么默认关：打开后会把狗框裁图（不是整段视频、不含声音）发到 Anthropic 的接口，属于把用户数据发到外部服务。
只有部署的人设置了 VISION_FALLBACK=on 并配好凭据（ANTHROPIC_API_KEY，或 ANTHROPIC_BASE_URL 指向的中转）才会调用。

做法：把最多 MAX_FRAMES 张裁图拼成一张带编号的图，一次请求，要求按编号返回 sit / stand / down / unclear（结构化输出）。
模型：VISION_MODEL，缺省 claude-opus-5-5；遇到安全拒答时服务端自动换模型重试（server-side fallback）。
失败（没有凭据、网络错误、拒答、返回格式不对）一律当作"判不了"，不影响其余分析。
"""

from __future__ import annotations

import base64
import io
import json
import os
from dataclasses import dataclass

import numpy as np

MAX_FRAMES = 16
TILE = 224
LABELS = ("sit", "stand", "down", "unclear")

PROMPT = (
    "下面这张图由 {n} 个编号小格组成，每格是同一段狗狗训练视频里某一帧的狗（可能是从正上方、斜上方或侧面拍的）。"
    "请逐格判断狗当时的姿势：sit（坐：臀部着地、前腿撑直）、down（趴：胸腹和肘部贴地）、"
    "stand（站或走动：四条腿撑起身体）、unclear（看不清、狗不完整、或拿不准）。"
    "拿不准就选 unclear，不要猜。按编号返回。"
)

SCHEMA = {
    "type": "object",
    "properties": {
        "frames": {
            "type": "array",
            "items": {
                "type": "object",
                "properties": {
                    "index": {"type": "integer"},
                    "posture": {"type": "string", "enum": list(LABELS)},
                },
                "required": ["index", "posture"],
                "additionalProperties": False,
            },
        }
    },
    "required": ["frames"],
    "additionalProperties": False,
}


def enabled() -> bool:
    return os.environ.get("VISION_FALLBACK", "").lower() in ("1", "on", "true")


def make_grid(crops: list[np.ndarray]) -> bytes:
    """裁图拼成带编号（从 1 起）的 JPEG。"""
    from PIL import Image, ImageDraw

    n = len(crops)
    cols = min(4, n)
    rows = (n + cols - 1) // cols
    grid = Image.new("RGB", (cols * TILE, rows * TILE), "white")
    draw = ImageDraw.Draw(grid)
    for k, c in enumerate(crops):
        x, y = (k % cols) * TILE, (k // cols) * TILE
        grid.paste(Image.fromarray(c).resize((TILE - 4, TILE - 4)), (x + 2, y + 2))
        draw.rectangle([x + 2, y + 2, x + 34, y + 26], fill="black")
        draw.text((x + 8, y + 7), str(k + 1), fill="white")
    buf = io.BytesIO()
    grid.save(buf, format="JPEG", quality=85)
    return buf.getvalue()


@dataclass
class VisionResult:
    labels: list[str]          # 与输入裁图一一对应；失败时全是 unclear
    ok: bool
    note: str = ""


def parse_labels(text: str, n: int) -> list[str]:
    data = json.loads(text)
    out = ["unclear"] * n
    for item in data.get("frames", []):
        i = int(item.get("index", 0)) - 1
        lab = item.get("posture")
        if 0 <= i < n and lab in LABELS:
            out[i] = lab
    return out


def classify_crops(crops: list[np.ndarray], client=None) -> VisionResult:
    """crops：狗框裁图（RGB uint8），最多 MAX_FRAMES 张（多的截掉，调用方负责抽样）。"""
    crops = crops[:MAX_FRAMES]
    if not crops:
        return VisionResult([], True)
    try:
        import anthropic

        client = client or anthropic.Anthropic()
        response = client.beta.messages.create(
            model=os.environ.get("VISION_MODEL", "claude-opus-5-5"),
            max_tokens=2000,
            betas=["server-side-fallback-2026-07-01"],
            fallbacks="default",
            output_config={"effort": "low", "format": {"type": "json_schema", "schema": SCHEMA}},
            messages=[{
                "role": "user",
                "content": [
                    {"type": "image", "source": {
                        "type": "base64", "media_type": "image/jpeg",
                        "data": base64.standard_b64encode(make_grid(crops)).decode("ascii"),
                    }},
                    {"type": "text", "text": PROMPT.format(n=len(crops))},
                ],
            }],
        )
        if response.stop_reason == "refusal":
            return VisionResult(["unclear"] * len(crops), False, "refusal")
        text = next((b.text for b in response.content if b.type == "text"), "")
        return VisionResult(parse_labels(text, len(crops)), True)
    except Exception as e:  # noqa: BLE001  兜底失败不影响主流程
        return VisionResult(["unclear"] * len(crops), False, type(e).__name__)
