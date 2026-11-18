"""在线模式 /v1/agent：三种上游统一返回格式、命令行 JSON 协议解析、错误转 502。

运行：cd server && .venv/bin/python -m pytest -q
"""

import os

os.environ["FAKE_UPSTREAM"] = "1"

from types import SimpleNamespace  # noqa: E402

from fastapi.testclient import TestClient  # noqa: E402

import agent  # noqa: E402
import main  # noqa: E402

client = TestClient(main.app)

TOOLS = [
    {"name": "get_dog_profile", "description": "狗档案", "input_schema": {"type": "object", "properties": {}}},
    {"name": "get_training_history", "description": "训练记录",
     "input_schema": {"type": "object", "properties": {"limit": {"type": "integer"}}}},
    {"name": "propose_plan_change", "description": "提出加入计划",
     "input_schema": {"type": "object", "properties": {"skill_id": {"type": "string"}}, "required": ["skill_id"]}},
]


def _user(text):
    return {"role": "user", "content": text}


def test_fake_script_runs_tools_then_proposes_then_answers():
    msgs = [_user("坐下学不会怎么办")]
    r1 = client.post("/v1/agent", json={"system": "s", "messages": msgs, "tools": TOOLS}).json()
    assert r1["upstream"] == "fake" and r1["stop_reason"] == "tool_use"
    calls = [b for b in r1["content"] if b["type"] == "tool_use"]
    assert [c["name"] for c in calls] == ["get_dog_profile", "get_training_history"]

    msgs += [
        {"role": "assistant", "content": r1["content"]},
        {"role": "user", "content": [{"type": "tool_result", "tool_use_id": c["id"], "content": "{}"} for c in calls]},
    ]
    r2 = client.post("/v1/agent", json={"system": "s", "messages": msgs, "tools": TOOLS}).json()
    assert r2["content"][0]["name"] == "propose_plan_change"

    msgs += [
        {"role": "assistant", "content": r2["content"]},
        {"role": "user", "content": [{"type": "tool_result", "tool_use_id": r2["content"][0]["id"], "content": "ok"}]},
    ]
    r3 = client.post("/v1/agent", json={"system": "s", "messages": msgs, "tools": TOOLS}).json()
    assert r3["stop_reason"] == "end_turn" and r3["content"][0]["type"] == "text"


def test_request_validation():
    assert client.post("/v1/agent", json={"system": "s", "messages": []}).status_code == 422
    too_many = [_user("x")] * (agent.MAX_MESSAGES + 1)
    assert client.post("/v1/agent", json={"system": "s", "messages": too_many}).status_code == 422


def test_parse_cli_reply_tool_calls_answer_and_fallback():
    out = agent.parse_cli_reply('{"tool_calls": [{"name": "get_dog_profile", "input": {}}]}')
    assert out["stop_reason"] == "tool_use"
    assert out["content"][0]["type"] == "tool_use" and out["content"][0]["id"].startswith("cli_")
    # 模型偶尔会在 JSON 前后加话：只取 JSON
    out = agent.parse_cli_reply('好的。\n{"answer": "先练跟随零食"}\n')
    assert out == {"stop_reason": "end_turn", "content": [{"type": "text", "text": "先练跟随零食"}]}
    # 不是 JSON：整段当回答，不丢内容
    out = agent.parse_cli_reply("直接给你建议：先降低难度")
    assert out["content"][0]["text"] == "直接给你建议：先降低难度"


def test_render_transcript_includes_calls_and_results():
    text = agent.render_transcript([
        _user("坐下学不会"),
        {"role": "assistant", "content": [
            {"type": "text", "text": "我查一下"},
            {"type": "tool_use", "id": "t1", "name": "get_dog_profile", "input": {"x": 1}},
        ]},
        {"role": "user", "content": [{"type": "tool_result", "tool_use_id": "t1", "content": "10 周", "is_error": True}]},
    ])
    assert "坐下学不会" in text and "我查一下" in text
    assert '<tool_call id="t1" name="get_dog_profile">{"x": 1}</tool_call>' in text
    assert 'tool_use_id="t1" is_error="true"' in text and "10 周" in text


def test_cli_upstream_uses_protocol_and_agent_model(monkeypatch):
    seen = {}

    async def fake_cli(req):
        seen["system"] = req.system
        seen["prompt"] = req.messages[0].content
        seen["model"] = main.MODEL
        yield '{"answer": "好的"}'

    monkeypatch.setattr(main, "FAKE_UPSTREAM", False)
    monkeypatch.setattr(main, "CLI_UPSTREAM", True)
    monkeypatch.setattr(main, "cli_stream", fake_cli)
    r = client.post("/v1/agent", json={"system": "你是助理训犬师", "messages": [_user("你好")], "tools": TOOLS})
    assert r.status_code == 200
    body = r.json()
    assert body["upstream"] == "cli" and body["content"][0]["text"] == "好的"
    assert seen["system"].startswith("你是助理训犬师") and "get_dog_profile" in seen["system"]
    assert seen["model"] == agent.AGENT_MODEL
    assert "你好" in seen["prompt"]


def test_api_upstream_passes_tools_and_returns_all_blocks(monkeypatch):
    captured = {}

    class Block(SimpleNamespace):
        def model_dump(self, exclude_none=False):
            return {k: v for k, v in vars(self).items() if not (exclude_none and v is None)}

    class Messages:
        async def create(self, **kw):
            captured.update(kw)
            return SimpleNamespace(
                stop_reason="tool_use",
                content=[
                    Block(type="thinking", thinking="", signature="sig"),
                    Block(type="tool_use", id="toolu_1", name="get_dog_profile", input={}),
                ],
            )

    fake_client = SimpleNamespace(beta=SimpleNamespace(messages=Messages()))
    monkeypatch.setattr(main, "FAKE_UPSTREAM", False)
    monkeypatch.setattr(main, "CLI_UPSTREAM", False)
    monkeypatch.setattr(main, "client", lambda: fake_client)
    r = client.post("/v1/agent", json={"system": "s", "messages": [_user("hi")], "tools": TOOLS})
    assert r.status_code == 200
    body = r.json()
    assert body["upstream"] == "api_key"
    # thinking 块也原样返回，供下一轮带回
    assert [b["type"] for b in body["content"]] == ["thinking", "tool_use"]
    assert captured["model"] == agent.AGENT_MODEL
    assert [t["name"] for t in captured["tools"]] == [t["name"] for t in TOOLS]
    assert captured["output_config"] == {"effort": agent.AGENT_EFFORT}
    assert captured["fallbacks"] == "default"


def test_upstream_error_returns_502(monkeypatch):
    class Messages:
        async def create(self, **kw):
            raise RuntimeError("boom")

    monkeypatch.setattr(main, "FAKE_UPSTREAM", False)
    monkeypatch.setattr(main, "CLI_UPSTREAM", False)
    monkeypatch.setattr(main, "client", lambda: SimpleNamespace(beta=SimpleNamespace(messages=Messages())))
    r = client.post("/v1/agent", json={"system": "s", "messages": [_user("hi")], "tools": TOOLS})
    assert r.status_code == 502


def test_healthz_reports_agent_model():
    assert client.get("/healthz").json()["agent_model"] == agent.AGENT_MODEL
