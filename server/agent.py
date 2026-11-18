"""在线模式：AI 助理训犬师的模型转发（2026-11-18）。

App 跑 Agent 循环、在本机执行工具（查狗档案、训练记录、计划、内容库，提出改计划等），
这里只负责把一轮请求交给模型，返回统一格式：

    POST /v1/agent
    body: {system, messages: [Messages API 格式，含 tool_use / tool_result 块], tools: [{name, description, input_schema}]}
    resp: {stop_reason: "tool_use" | "end_turn" | ..., content: [块...], upstream: "api_key" | "cli" | "fake"}

content 里客户端只解读 text / tool_use，其余块（thinking 等）原样带回下一轮请求。

三种上游（优先级同 /v1/chat：fake > cli > api_key）：
- api_key：Claude 原生工具调用（client.beta.messages.create + tools），默认模型 claude-opus-5-5（AGENT_MODEL 可改），
  开启服务端拒答兜底（FALLBACKS=off 关闭）。
- cli：本机已登录（订阅账号）的 `claude` 命令行。命令行模式下不开放任何内置工具，所以把工具清单写进系统提示，
  要求模型只回一个 JSON（要么调用工具，要么给出回答），这里解析后转成与原生相同的 tool_use / text 块。仅测试 / 演示用。
- fake：固定剧本（查档案和记录 → 提出加入计划 → 回答），不调模型，联调与自动化测试用。
"""

from __future__ import annotations

import json
import logging
import os
import re
import uuid
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

log = logging.getLogger("puppy_ai_agent")

AGENT_MODEL = os.environ.get("AGENT_MODEL", "claude-opus-5-5")
AGENT_EFFORT = os.environ.get("AGENT_EFFORT", "medium")
AGENT_MAX_TOKENS = 16000
MAX_MESSAGES = 60

router = APIRouter()


class AgentTool(BaseModel):
    name: str = Field(min_length=1, max_length=64)
    description: str
    input_schema: Dict[str, Any]


class AgentRequest(BaseModel):
    system: str
    messages: List[Dict[str, Any]] = Field(min_length=1, max_length=MAX_MESSAGES)
    tools: List[AgentTool] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# api_key：原生工具调用
# ---------------------------------------------------------------------------


async def api_turn(req: AgentRequest) -> Dict[str, Any]:
    from main import FALLBACKS, client  # 复用 /v1/chat 的客户端与兜底开关

    kwargs: Dict[str, Any] = dict(
        model=AGENT_MODEL,
        max_tokens=AGENT_MAX_TOKENS,
        system=req.system,
        messages=req.messages,
        tools=[t.model_dump() for t in req.tools],
        output_config={"effort": AGENT_EFFORT},
    )
    if FALLBACKS != "off":
        kwargs["betas"] = ["server-side-fallback-2026-07-01"]
        kwargs["fallbacks"] = "default"
    resp = await client().beta.messages.create(**kwargs)
    return {
        "stop_reason": resp.stop_reason,
        # 全部块原样返回（含 thinking），客户端下一轮原样带回
        "content": [b.model_dump(exclude_none=True) for b in resp.content],
    }


# ---------------------------------------------------------------------------
# cli：命令行订阅登录 + JSON 协议
# ---------------------------------------------------------------------------

CLI_PROTOCOL = """

# 工具调用协议（本通道没有原生工具调用，按下面的格式回复）
你可以调用下面列出的工具。每次回复**只输出一个 JSON 对象**，不要输出任何其他文字、不要用代码块包裹：
- 需要调用工具时：{"tool_calls": [{"name": "工具名", "input": {参数}}]}（可以一次调用多个）
- 信息足够、给出最终回答时：{"answer": "给主人的回答"}
工具结果会以 <tool_result> 的形式出现在后续对话里。

可用工具（JSON Schema）：
"""


def _block_text(content: Any) -> str:
    if isinstance(content, str):
        return content
    out = []
    for b in content or []:
        if isinstance(b, dict) and b.get("type") == "text":
            out.append(b.get("text", ""))
    return "\n".join(out)


def render_transcript(messages: List[Dict[str, Any]]) -> str:
    """把 Messages API 格式的对话（含工具调用与结果）写成一段文本，交给命令行。"""
    lines: List[str] = []
    for m in messages:
        role = m.get("role")
        content = m.get("content")
        if isinstance(content, str):
            lines.append(f'<turn role="{role}">\n{content}\n</turn>')
            continue
        for b in content or []:
            if not isinstance(b, dict):
                continue
            t = b.get("type")
            if t == "text" and b.get("text"):
                lines.append(f'<turn role="{role}">\n{b["text"]}\n</turn>')
            elif t == "tool_use":
                lines.append(
                    f'<tool_call id="{b.get("id")}" name="{b.get("name")}">'
                    f"{json.dumps(b.get('input', {}), ensure_ascii=False)}</tool_call>"
                )
            elif t == "tool_result":
                err = ' is_error="true"' if b.get("is_error") else ""
                lines.append(
                    f'<tool_result tool_use_id="{b.get("tool_use_id")}"{err}>\n'
                    f"{_block_text(b.get('content'))}\n</tool_result>"
                )
    lines.append("\n请按工具调用协议回复（只输出一个 JSON 对象）。")
    return "\n".join(lines)


_JSON_RE = re.compile(r"\{.*\}", re.S)


def parse_cli_reply(text: str) -> Dict[str, Any]:
    """命令行的回复 → 统一格式。解析失败时把整段当作最终回答（不丢内容）。"""
    raw = text.strip()
    m = _JSON_RE.search(raw)
    data: Optional[dict] = None
    if m:
        try:
            data = json.loads(m.group(0))
        except ValueError:
            data = None
    if isinstance(data, dict) and isinstance(data.get("tool_calls"), list) and data["tool_calls"]:
        blocks = []
        for c in data["tool_calls"]:
            if not isinstance(c, dict) or not c.get("name"):
                continue
            blocks.append({
                "type": "tool_use",
                "id": f"cli_{uuid.uuid4().hex[:12]}",
                "name": str(c["name"]),
                "input": c.get("input") if isinstance(c.get("input"), dict) else {},
            })
        if blocks:
            return {"stop_reason": "tool_use", "content": blocks}
    if isinstance(data, dict) and isinstance(data.get("answer"), str):
        return {"stop_reason": "end_turn", "content": [{"type": "text", "text": data["answer"]}]}
    return {"stop_reason": "end_turn", "content": [{"type": "text", "text": raw}]}


async def cli_turn(req: AgentRequest) -> Dict[str, Any]:
    import main

    system = req.system + CLI_PROTOCOL + json.dumps(
        [t.model_dump() for t in req.tools], ensure_ascii=False, indent=1
    )
    chat_req = main.ChatRequest(
        system=system,
        messages=[main.ChatMessage(role="user", content=render_transcript(req.messages))],
    )
    old = main.MODEL
    main.MODEL = AGENT_MODEL  # cli_stream 用模块级 MODEL；在线模式统一用 AGENT_MODEL
    try:
        text = "".join([chunk async for chunk in main.cli_stream(chat_req)])
    finally:
        main.MODEL = old
    return parse_cli_reply(text)


# ---------------------------------------------------------------------------
# fake：固定剧本
# ---------------------------------------------------------------------------


def _round(messages: List[Dict[str, Any]]) -> int:
    """最后一条主人提问之后，已经过了几轮工具结果。"""
    n = 0
    for m in reversed(messages):
        content = m.get("content")
        if m.get("role") == "user" and isinstance(content, list) and any(
            isinstance(b, dict) and b.get("type") == "tool_result" for b in content
        ):
            n += 1
            continue
        if m.get("role") == "user":
            break
    return n


def fake_turn(req: AgentRequest) -> Dict[str, Any]:
    names = {t.name for t in req.tools}
    r = _round(req.messages)

    def call(name: str, inp: dict) -> dict:
        return {"type": "tool_use", "id": f"fake_{r}_{name}", "name": name, "input": inp}

    if r == 0 and {"get_dog_profile", "get_training_history"} <= names:
        return {"stop_reason": "tool_use", "content": [
            {"type": "text", "text": "（联调假回答）我先看看狗的档案和最近的训练。"},
            call("get_dog_profile", {}),
            call("get_training_history", {"limit": 5}),
        ]}
    if r == 1 and "propose_plan_change" in names:
        return {"stop_reason": "tool_use", "content": [
            call("propose_plan_change", {"skill_id": "lure_follow", "reason": "联调：先打基础"}),
        ]}
    return {"stop_reason": "end_turn", "content": [
        {"type": "text", "text": "（联调假回答，未调用模型）建议先练跟随零食打基础，已为你准备好加入本周计划的确认。"},
    ]}


@router.post("/v1/agent")
async def agent(req: AgentRequest) -> dict:
    from main import CliUpstreamError, upstream_mode

    mode = upstream_mode()
    try:
        if mode == "fake":
            out = fake_turn(req)
        elif mode == "cli":
            out = await cli_turn(req)
        else:
            out = await api_turn(req)
    except CliUpstreamError as e:
        log.warning("agent cli upstream error: %s %s", e.code, e.detail)
        raise HTTPException(status_code=502, detail=e.code) from None
    except Exception as e:  # noqa: BLE001 — 上游错误转 502，App 提示联系不上并可切回离线
        log.warning("agent upstream error: %s", type(e).__name__)
        raise HTTPException(status_code=502, detail=type(e).__name__) from None
    out["upstream"] = mode
    return out
