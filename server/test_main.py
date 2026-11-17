"""服务端自测：SSE 格式、FAKE_UPSTREAM 链路、上游错误转 error 事件、请求校验。

运行：cd server && .venv/bin/python -m pytest -q
"""

import os

os.environ["FAKE_UPSTREAM"] = "1"

from fastapi.testclient import TestClient  # noqa: E402

import main  # noqa: E402

client = TestClient(main.app)


def parse(body: str):
    events = []
    for block in body.split("\n\n"):
        if not block.strip():
            continue
        ev, data = "message", []
        for line in block.split("\n"):
            if line.startswith("event: "):
                ev = line[7:]
            elif line.startswith("data: "):
                data.append(line[6:])
        events.append((ev, "\n".join(data)))
    return events


def test_sse_multiline():
    assert main.sse("a\nb") == "data: a\ndata: b\n\n"
    assert main.sse("x", event="error") == "event: error\ndata: x\n\n"


def test_fake_stream_cites_material_ids():
    r = client.post(
        "/v1/chat",
        json={
            "system": '资料\n<material id="sit" type="skill">..</material>\n<material id="down" type="skill">',
            "messages": [{"role": "user", "content": "坐下怎么练"}],
        },
    )
    assert r.status_code == 200
    assert r.headers["content-type"].startswith("text/event-stream")
    events = parse(r.text)
    assert events[-1] == ("message", "[DONE]")
    text = "".join(d for e, d in events[:-1])
    assert text.endswith("[ref: sit, down]")


def test_upstream_error_becomes_error_event(monkeypatch):
    async def boom(req):
        raise RuntimeError("x")
        yield ""  # pragma: no cover

    monkeypatch.setattr(main, "FAKE_UPSTREAM", False)
    monkeypatch.setattr(main, "upstream_stream", boom)
    r = client.post("/v1/chat", json={"system": "s", "messages": [{"role": "user", "content": "q"}]})
    events = parse(r.text)
    assert events == [("error", "RuntimeError")]


def test_validation():
    r = client.post("/v1/chat", json={"system": "s", "messages": []})
    assert r.status_code == 422
    r = client.post("/v1/chat", json={"system": "s", "messages": [{"role": "system", "content": "x"}]})
    assert r.status_code == 422


def test_no_key_in_source():
    src = open(os.path.join(os.path.dirname(__file__), "main.py"), encoding="utf-8").read()
    assert "sk-ant" not in src


# ---------------------------------------------------------------------------
# CLI_UPSTREAM（简报第 15 节）：用假的可执行文件替身代替 claude 命令行
# ---------------------------------------------------------------------------

import json  # noqa: E402
import stat  # noqa: E402
import sys  # noqa: E402

import pytest  # noqa: E402

FAKE_CLI = r'''#!__PY__
import json, os, sys, time
mode = os.environ.get("FAKE_CLI_MODE", "ok")
rec = os.environ["FAKE_CLI_RECORD"]
stdin = sys.stdin.read()
json.dump({"argv": sys.argv[1:], "stdin": stdin, "env": sorted(os.environ.keys()),
           "cwd": os.getcwd(), "cwd_entries": os.listdir(os.getcwd())},
          open(rec, "w", encoding="utf-8"), ensure_ascii=False)
def out(o):
    print(json.dumps(o, ensure_ascii=False), flush=True)
model = sys.argv[sys.argv.index("--model") + 1]
init = {"type": "system", "subtype": "init", "model": model, "tools": [], "mcp_servers": [],
        "skills": [], "slash_commands": []}
if mode == "tools":
    init["tools"] = ["Bash"]
if mode == "model":
    init["model"] = "claude-other"
out(init)
if mode == "sleep":
    time.sleep(30)
if mode == "crash":
    sys.stderr.write("Traceback: secret internal error\n")
    sys.exit(3)
if mode == "notlogged":
    out({"type": "assistant", "message": {"role": "assistant", "content": [{"type": "text", "text": "Not logged in · Please run /login"}]}})
    out({"type": "result", "subtype": "success", "is_error": True, "result": "Not logged in · Please run /login"})
    sys.exit(1)
chunks = ["先降低", "难度。\n", "[ref: sit]"]
if mode != "nopartial":
    for c in chunks:
        out({"type": "stream_event", "event": {"type": "content_block_delta", "index": 0,
             "delta": {"type": "text_delta", "text": c}}})
out({"type": "assistant", "message": {"role": "assistant", "content": [{"type": "text", "text": "".join(chunks)}]}})
out({"type": "result", "subtype": "success", "is_error": False, "result": "".join(chunks)})
'''


@pytest.fixture
def cli(tmp_path, monkeypatch):
    exe = tmp_path / "claude"
    exe.write_text(FAKE_CLI.replace("__PY__", sys.executable), encoding="utf-8")
    exe.chmod(exe.stat().st_mode | stat.S_IEXEC)
    record = tmp_path / "record.json"
    monkeypatch.setattr(main, "FAKE_UPSTREAM", False)
    monkeypatch.setattr(main, "CLI_UPSTREAM", True)
    monkeypatch.setattr(main, "CLAUDE_BIN", str(exe))
    monkeypatch.setattr(main, "CLI_TIMEOUT", 5.0)
    monkeypatch.setenv("FAKE_CLI_RECORD", str(record))
    monkeypatch.setenv("FAKE_CLI_MODE", "ok")

    def run(messages, system="系统提示原文", mode="ok"):
        monkeypatch.setenv("FAKE_CLI_MODE", mode)
        r = client.post("/v1/chat", json={"system": system, "messages": messages})
        rec = json.loads(record.read_text(encoding="utf-8")) if record.exists() else None
        return r, parse(r.text), rec

    return run


def test_cli_mode_priority(monkeypatch):
    monkeypatch.setattr(main, "FAKE_UPSTREAM", True)
    monkeypatch.setattr(main, "CLI_UPSTREAM", True)
    assert main.upstream_mode() == "fake"
    monkeypatch.setattr(main, "FAKE_UPSTREAM", False)
    assert main.upstream_mode() == "cli"
    assert client.get("/healthz").json()["upstream"] == "cli"
    monkeypatch.setattr(main, "CLI_UPSTREAM", False)
    assert main.upstream_mode() == "api_key"


def test_cli_normal_stream_same_sse(cli):
    r, events, rec = cli([{"role": "user", "content": "坐下练了三天还是不坐"}], system="S" * 5000)
    assert r.headers["content-type"].startswith("text/event-stream")
    assert events[-1] == ("message", "[DONE]")
    text = "".join(d for e, d in events[:-1])
    assert text == "先降低难度。\n[ref: sit]"
    # 等价性：系统提示整体替换、模型固定、禁用工具、不读设置/自定义、空目录
    argv = rec["argv"]
    assert "-p" in argv
    assert f"--system-prompt={'S' * 5000}" in argv
    assert "--append-system-prompt" not in " ".join(argv)
    assert argv[argv.index("--model") + 1] == main.MODEL
    assert "--fallback-model" not in argv
    assert argv[argv.index("--tools") + 1] == ""
    assert argv[argv.index("--setting-sources") + 1] == ""
    for flag in ("--safe-mode", "--strict-mcp-config", "--disable-slash-commands", "--no-session-persistence"):
        assert flag in argv
    assert "--mcp-config" not in argv
    assert rec["cwd_entries"] == []
    assert not os.path.exists(rec["cwd"])  # 用完即删
    # 单轮：提示原文直传
    assert rec["stdin"] == "坐下练了三天还是不坐"


def test_cli_multiturn_history_order_and_roles(cli):
    msgs = [
        {"role": "user", "content": "问一"},
        {"role": "assistant", "content": "答一"},
        {"role": "user", "content": "问二"},
        {"role": "assistant", "content": "答二"},
        {"role": "user", "content": "问三"},
    ]
    _, events, rec = cli(msgs)
    assert events[-1] == ("message", "[DONE]")
    s = rec["stdin"]
    order = [s.index(x) for x in ['role="user">\n问一', 'role="assistant">\n答一', 'role="user">\n问二', 'role="assistant">\n答二']]
    assert order == sorted(order)
    assert s.rstrip().endswith("问三")
    assert s.count("<turn ") == 4  # 不丢不并：每条历史一个回合


def test_cli_strips_credentials_env(cli, monkeypatch):
    for k in ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL", "CLAUDECODE"):
        monkeypatch.setenv(k, "x")
    monkeypatch.setenv("KEEP_ME", "1")
    _, _, rec = cli([{"role": "user", "content": "q"}])
    for k in ("ANTHROPIC_API_KEY", "ANTHROPIC_AUTH_TOKEN", "ANTHROPIC_BASE_URL", "CLAUDECODE"):
        assert k not in rec["env"]
    assert "KEEP_ME" in rec["env"]


def test_cli_without_partial_uses_whole_message(cli):
    _, events, _ = cli([{"role": "user", "content": "q"}], mode="nopartial")
    assert "".join(d for e, d in events[:-1]) == "先降低难度。\n[ref: sit]"


@pytest.mark.parametrize(
    "mode,code",
    [
        ("notlogged", "CliNotLoggedIn"),
        ("crash", "CliExit"),
        ("tools", "CliToolsEnabled"),
        ("model", "CliModelMismatch"),
    ],
)
def test_cli_failures_become_error_event(cli, mode, code):
    r, events, _ = cli([{"role": "user", "content": "q"}], mode=mode)
    assert r.status_code == 200
    assert events == [("error", code)]
    assert "Please run" not in r.text and "secret" not in r.text  # 不透命令行原文


def test_cli_timeout(cli, monkeypatch):
    monkeypatch.setattr(main, "CLI_TIMEOUT", 1.0)
    _, events, _ = cli([{"role": "user", "content": "q"}], mode="sleep")
    assert events == [("error", "CliTimeout")]


def test_cli_not_found(monkeypatch):
    monkeypatch.setattr(main, "FAKE_UPSTREAM", False)
    monkeypatch.setattr(main, "CLI_UPSTREAM", True)
    monkeypatch.setattr(main, "CLAUDE_BIN", "/nonexistent/claude-xyz")
    r = client.post("/v1/chat", json={"system": "s", "messages": [{"role": "user", "content": "q"}]})
    assert parse(r.text) == [("error", "CliNotFound")]
    # 服务还活着
    assert client.get("/healthz").status_code == 200
