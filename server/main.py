"""幼犬训练 App 的模型薄代理（M3 简报第 3、9 节）。

POST /v1/chat：收客户端组好的系统提示与对话，转发给模型，SSE 流式返回（不鉴权，首版本地跑的临时方案，见 README）。
M4 起另有账号、家庭与同步接口，见 sync.py（DB_PATH 指定 sqlite 文件）。
API key 只从服务端环境变量 ANTHROPIC_API_KEY 读，客户端不持有。

环境变量：
  ANTHROPIC_API_KEY  模型 API key（FAKE_UPSTREAM=1 时可不设）
  MODEL              默认 claude-sonnet-5-5
  PORT               默认 8000（python main.py 时生效；uvicorn 命令行请用 --port）
  FALLBACKS          default（默认，开启服务端拒答兜底）| off
  FAKE_UPSTREAM      1 时不调模型，回固定文本并引用系统提示里的资料 ID（联调用）
  CLI_UPSTREAM       1 时改用本机已登录（订阅账号）的 `claude` 命令行做上游（简报第 15 节，仅测试/演示）
  CLAUDE_BIN         CLI_UPSTREAM 用的可执行文件，默认在 PATH 里找 `claude`
  CLI_TIMEOUT        CLI_UPSTREAM 单次请求超时秒数，默认 180

  AGENT_MODEL        在线模式（/v1/agent，见 agent.py）用的模型，默认 claude-opus-5-5
  AGENT_EFFORT       在线模式的 effort，默认 medium

上游优先级：FAKE_UPSTREAM > CLI_UPSTREAM > API key。
"""

from __future__ import annotations

import asyncio
import json
import logging
import os
import re
import shutil
import tempfile
from typing import AsyncIterator, Dict, List, Literal, Optional, Sequence

import anthropic
from fastapi import FastAPI
from fastapi.responses import StreamingResponse
from pydantic import BaseModel, Field

MODEL = os.environ.get("MODEL", "claude-sonnet-5-5")
FALLBACKS = os.environ.get("FALLBACKS", "default")
FAKE_UPSTREAM = os.environ.get("FAKE_UPSTREAM") == "1"
CLI_UPSTREAM = os.environ.get("CLI_UPSTREAM") == "1"
CLAUDE_BIN = os.environ.get("CLAUDE_BIN", "claude")
CLI_TIMEOUT = float(os.environ.get("CLI_TIMEOUT", "180"))
MAX_TOKENS_CAP = 4096

log = logging.getLogger("puppy_ai_proxy")
logging.basicConfig(level=logging.INFO)

app = FastAPI(title="puppy-trainer-ai-proxy", version="0.1.0")

# M4：账号、家庭、邀请码与同步（sync.py / store.py，DB_PATH 默认 server/data/app.db）。
from sync import router as sync_router  # noqa: E402

app.include_router(sync_router)


class ChatMessage(BaseModel):
    role: Literal["user", "assistant"]
    content: str = Field(min_length=1)


class ChatRequest(BaseModel):
    system: str
    messages: List[ChatMessage] = Field(min_length=1)
    max_tokens: Optional[int] = Field(default=None, ge=1)


def sse(data: str, event: Optional[str] = None) -> str:
    """一个 SSE 事件。多行文本按标准拆成多行 data:，客户端用 \\n 拼回。"""
    head = f"event: {event}\n" if event else ""
    body = "".join(f"data: {line}\n" for line in data.split("\n"))
    return head + body + "\n"


_client: Optional[anthropic.AsyncAnthropic] = None


def client() -> anthropic.AsyncAnthropic:
    global _client
    if _client is None:
        # 只读环境变量；缺失时 SDK 会在请求时报认证错误，由下面的 except 转成 error 事件。
        _client = anthropic.AsyncAnthropic()
    return _client


async def upstream_stream(req: ChatRequest) -> AsyncIterator[str]:
    """调用模型并逐段产出文本。

    temperature：简报要求 0，但 claude-sonnet-5-5 对非默认采样参数返回 400，
    因此不传（见交接单"需要 Fable 决策"）。
    """
    kwargs = dict(
        model=MODEL,
        max_tokens=min(req.max_tokens or 2048, MAX_TOKENS_CAP),
        system=req.system,
        messages=[m.model_dump() for m in req.messages],
    )
    if FALLBACKS != "off":
        kwargs["betas"] = ["server-side-fallback-2026-07-01"]
        kwargs["fallbacks"] = "default"
    async with client().beta.messages.stream(**kwargs) as stream:
        async for text in stream.text_stream:
            yield text
        final = await stream.get_final_message()
        if final.stop_reason == "refusal":
            raise RuntimeError("模型拒答（refusal）")


_MATERIAL_RE = re.compile(r'<material id="([^"]+)"')


async def fake_stream(req: ChatRequest) -> AsyncIterator[str]:
    ids = _MATERIAL_RE.findall(req.system)
    text = "（联调假回答，未调用模型）以下内容依据资料整理。\n[ref: " + ", ".join(ids) + "]"
    for i in range(0, len(text), 6):
        await asyncio.sleep(0.03)
        yield text[i : i + 6]


def upstream_mode() -> str:
    """当前上游：fake > cli > api_key（简报第 15 节第 1 条）。"""
    if FAKE_UPSTREAM:
        return "fake"
    if CLI_UPSTREAM:
        return "cli"
    return "api_key"


# ---------------------------------------------------------------------------
# CLI_UPSTREAM：本机已登录的 claude 命令行（简报第 15 节）
# ---------------------------------------------------------------------------

#: 启动子进程时剥离的环境变量。前三个是简报第 15 节第 4 条要求；
#: CLAUDECODE 是"已在 Claude Code 会话内"的标记，从 Claude Code 里启动本服务时会带上，去掉避免被当成嵌套会话。
STRIPPED_ENV = ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL", "CLAUDECODE")


class CliUpstreamError(Exception):
    """CLI 上游的各类失败。只把 code 透给客户端，不透命令行原文。"""

    def __init__(self, code: str, detail: str = ""):
        super().__init__(code)
        self.code = code
        self.detail = detail


def cli_env(base: Optional[Dict[str, str]] = None) -> Dict[str, str]:
    env = dict(os.environ if base is None else base)
    for k in STRIPPED_ENV:
        env.pop(k, None)
    return env


def cli_args(system: str, model: str) -> List[str]:
    """命令行参数。全部取自 `claude --help`（2.1.326）的实际输出：

    - `-p`：非交互；提示从 stdin 读。
    - `--output-format stream-json --verbose --include-partial-messages`：逐段输出文本增量。
    - `--system-prompt=<客户端系统提示>`：整体替换默认系统提示（不用 --append-system-prompt）。
    - `--model <MODEL>`：固定模型，不传 --fallback-model。
    - `--tools ""`：不提供任何内置工具。
    - `--setting-sources ""`：不读 user / project / local 设置文件。这一条同时挡住了用户级
      settings.json 里 `env` 段注入的 API key / BASE_URL（只剥进程环境变量挡不住）。
    - `--safe-mode`：关掉 CLAUDE.md、技能、插件、钩子、MCP、自定义命令与代理、输出风格等全部自定义。
    - `--strict-mcp-config`（且不给 --mcp-config）：不加载任何 MCP 服务器。
    - `--disable-slash-commands`：禁用全部技能与命令。
    - `--no-session-persistence`：不落盘会话。
    不用 `--bare`：它的认证只认 ANTHROPIC_API_KEY / apiKeyHelper，读不到订阅登录。
    """
    return [
        "-p",
        "--output-format", "stream-json",
        "--verbose",
        "--include-partial-messages",
        f"--system-prompt={system}",
        "--model", model,
        "--tools", "",
        "--setting-sources", "",
        "--safe-mode",
        "--strict-mcp-config",
        "--disable-slash-commands",
        "--no-session-persistence",
    ]


def cli_prompt(messages: Sequence[ChatMessage]) -> str:
    """把对话交给命令行。

    单轮（只有一条 user）：原文直传，与真实接口等价。
    多轮：命令行没有"注入以往 assistant 回合"的公开参数（stream-json 输入里每条 user 都会触发一轮新回答），
    只能把历史按原顺序、带原角色标记写进最后一条用户消息。这一点与真实接口**不等价**，见交接单。
    """
    if len(messages) == 1:
        return messages[0].content
    lines = ["以下是本次对话之前的记录，按原顺序列出，role 为原角色。只作为上下文，不要复述：", "<history>"]
    for m in messages[:-1]:
        lines.append(f'<turn role="{m.role}">\n{m.content}\n</turn>')
    lines.append("</history>")
    lines.append("")
    lines.append(messages[-1].content)
    return "\n".join(lines)


def _text_delta(evt: dict) -> Optional[str]:
    """stream-json 的 `stream_event` 里取 text_delta（模型 API 原始流事件）。"""
    if evt.get("type") != "stream_event":
        return None
    e = evt.get("event") or {}
    if e.get("type") != "content_block_delta":
        return None
    d = e.get("delta") or {}
    if d.get("type") == "text_delta":
        return d.get("text") or ""
    return None


def _assistant_text(evt: dict) -> str:
    msg = evt.get("message") or {}
    parts = msg.get("content") or []
    if isinstance(parts, str):
        return parts
    return "".join(p.get("text", "") for p in parts if isinstance(p, dict) and p.get("type") == "text")


def _check_init(evt: dict, model: str) -> None:
    """运行时核对等价性：模型一致、没有任何工具 / MCP 服务器 / 技能 / 斜杠命令。任一不满足即报错。"""
    got = evt.get("model")
    if got is not None and got != model:
        raise CliUpstreamError("CliModelMismatch", f"init.model={got}")
    tools = evt.get("tools")
    if tools:
        raise CliUpstreamError("CliToolsEnabled", f"tools={tools}")
    mcp = evt.get("mcp_servers")
    if mcp:
        raise CliUpstreamError("CliMcpLoaded", f"mcp_servers={mcp}")
    for key in ("skills", "slash_commands"):
        if evt.get(key):
            raise CliUpstreamError("CliCustomizationLoaded", f"{key}={evt.get(key)}")


async def cli_stream(req: ChatRequest) -> AsyncIterator[str]:
    exe = shutil.which(CLAUDE_BIN)
    if exe is None:
        raise CliUpstreamError("CliNotFound")
    workdir = tempfile.mkdtemp(prefix="puppy-cli-")  # 空临时目录：没有 CLAUDE.md / .claude/ / .mcp.json
    proc: Optional[asyncio.subprocess.Process] = None
    try:
        proc = await asyncio.create_subprocess_exec(
            exe,
            *cli_args(req.system, MODEL),
            cwd=workdir,
            env=cli_env(),
            stdin=asyncio.subprocess.PIPE,
            stdout=asyncio.subprocess.PIPE,
            stderr=asyncio.subprocess.PIPE,
        )
        assert proc.stdin and proc.stdout and proc.stderr
        proc.stdin.write(cli_prompt(req.messages).encode("utf-8"))
        await proc.stdin.drain()
        proc.stdin.close()

        loop = asyncio.get_running_loop()
        deadline = loop.time() + CLI_TIMEOUT
        streamed = False
        fallback_text = ""
        result: Optional[dict] = None
        while True:
            remaining = deadline - loop.time()
            if remaining <= 0:
                raise CliUpstreamError("CliTimeout")
            try:
                line = await asyncio.wait_for(proc.stdout.readline(), timeout=remaining)
            except asyncio.TimeoutError:
                raise CliUpstreamError("CliTimeout") from None
            if not line:
                break
            try:
                evt = json.loads(line)
            except ValueError:
                continue  # 非 JSON 行（不应出现）忽略
            t = evt.get("type")
            if t == "system" and evt.get("subtype") == "init":
                _check_init(evt, MODEL)
            elif t == "stream_event":
                text = _text_delta(evt)
                if text:
                    streamed = True
                    yield text
            elif t == "assistant":
                # 未开 partial 时的整段文本；"未登录"等合成消息也走这里，所以只在确认成功后才用。
                fallback_text += _assistant_text(evt)
            elif t == "result":
                result = evt
        rc = await asyncio.wait_for(proc.wait(), timeout=max(1.0, deadline - loop.time()))
        if result is None:
            raise CliUpstreamError("CliExit" if rc else "CliNoResult", f"rc={rc}")
        if result.get("is_error") or result.get("subtype") != "success":
            res = str(result.get("result", ""))
            code = "CliNotLoggedIn" if ("login" in res.lower() or "logged in" in res.lower()) else "CliError"
            raise CliUpstreamError(code, res[:200])
        if rc != 0:
            raise CliUpstreamError("CliExit", f"rc={rc}")
        if not streamed and fallback_text:
            yield fallback_text
    except asyncio.TimeoutError:
        raise CliUpstreamError("CliTimeout") from None
    except OSError as e:
        raise CliUpstreamError("CliSpawnFailed", type(e).__name__) from None
    finally:
        if proc is not None and proc.returncode is None:
            try:
                proc.kill()
            except ProcessLookupError:
                pass
            await proc.wait()
        shutil.rmtree(workdir, ignore_errors=True)


@app.get("/healthz")
async def healthz() -> dict:
    from agent import AGENT_MODEL

    return {"ok": True, "model": MODEL, "agent_model": AGENT_MODEL, "fake": FAKE_UPSTREAM, "upstream": upstream_mode()}


@app.post("/v1/chat")
async def chat(req: ChatRequest) -> StreamingResponse:
    async def gen() -> AsyncIterator[str]:
        mode = upstream_mode()
        source = {"fake": fake_stream, "cli": cli_stream}.get(mode, upstream_stream)(req)
        try:
            async for chunk in source:
                if chunk:
                    yield sse(chunk)
            yield sse("[DONE]")
        except CliUpstreamError as e:
            # 只透错误码；命令行原文只进服务端日志（截断）。
            log.warning("cli upstream error: %s %s", e.code, e.detail)
            yield sse(e.code, event="error")
        except Exception as e:  # noqa: BLE001 — 任何上游错误都转成 error 事件，客户端按网络失败处理
            log.warning("upstream error: %s", type(e).__name__)
            yield sse(type(e).__name__, event="error")

    return StreamingResponse(
        gen(),
        media_type="text/event-stream",
        headers={"Cache-Control": "no-cache", "X-Accel-Buffering": "no"},
    )


# 在线模式（2026-11-18）：AI 助理训犬师的工具调用转发，见 agent.py。
from agent import AGENT_MODEL, router as agent_router  # noqa: E402

app.include_router(agent_router)


if __name__ == "__main__":
    import uvicorn

    uvicorn.run(app, host="0.0.0.0", port=int(os.environ.get("PORT", "8000")))
