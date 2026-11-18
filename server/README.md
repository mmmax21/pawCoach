# AI 教练服务端代理（M3）

一个 FastAPI 薄代理：客户端把"系统提示 + 对话"发过来，这里转发给模型，用 SSE 流式返回。
**API key 只在这里的环境变量里，客户端代码、配置、安装包里都没有。**

> ⚠️ 临时方案：首版只在本机跑，**没有鉴权、没有限流、没有存储**。任何能访问这个端口的人都能用你的 key 调模型。
> 不要部署到公网；上线前必须加鉴权（M4 或以后）。

## 接口

```
POST /v1/chat
body: { "system": string, "messages": [{"role": "user"|"assistant", "content": string}], "max_tokens"?: int }
response: text/event-stream
  每个事件的 data 是增量文本（多行文本按 SSE 标准拆成多行 data:）
  结束事件：data: [DONE]
  出错事件：event: error / data: <错误类型>，客户端按"联系不上"处理
GET /healthz → {"ok": true, "model": ..., "fake": ...}
```

## 环境变量

| 变量 | 默认 | 说明 |
|---|---|---|
| `ANTHROPIC_API_KEY` | 无 | 模型 API key。`FAKE_UPSTREAM=1` 时可不设 |
| `MODEL` | `claude-sonnet-5-5` | |
| `PORT` | `8000` | 只在 `python main.py` 启动时生效；用 uvicorn 命令行时写 `--port` |
| `FALLBACKS` | `default` | 开启服务端拒答兜底（beta `server-side-fallback-2026-07-01`）；`off` 关闭 |
| `FAKE_UPSTREAM` | 未设 | 设为 `1` 时不调模型，回一段固定文本并引用系统提示里的资料 ID，用于没有 key 时联调 |
| `CLI_UPSTREAM` | 未设 | 设为 `1` 时用本机已登录（订阅账号）的 `claude` 命令行做上游，见下文 |
| `CLAUDE_BIN` | `claude` | `CLI_UPSTREAM` 用的可执行文件（PATH 里找不到时写绝对路径） |
| `CLI_TIMEOUT` | `180` | `CLI_UPSTREAM` 单次请求超时（秒） |

上游优先级：`FAKE_UPSTREAM` > `CLI_UPSTREAM` > API key。`GET /healthz` 的 `upstream` 字段是当前模式（`fake` / `cli` / `api_key`）。

注意：Anthropic SDK 还会读 `ANTHROPIC_BASE_URL`（以及 `ANTHROPIC_AUTH_TOKEN` 等）。如果你的 shell 里有别的工具留下的这些变量，
启动前用 `env -u ANTHROPIC_BASE_URL ...` 清掉，避免请求被转到别的地址。

关于 temperature：简报要求 0，但 `claude-sonnet-5-5` 对非默认采样参数（temperature / top_p / top_k）直接返回 400，所以代理不传。已写入交接单"需要 Fable 决策"。

## 运行

```bash
cd server
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
export ANTHROPIC_API_KEY=...        # 或者 export FAKE_UPSTREAM=1
.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
```

自测：`.venv/bin/python -m pytest -q`

## 与模拟器联调

Android 模拟器里 `10.0.2.2` 就是宿主机。客户端默认 base URL 是 `http://10.0.2.2:8000`，
也可以用 `flutter run --dart-define=AI_BASE_URL=http://<host>:<port>` 改。
App 的 `network_security_config.xml` 只对 `10.0.2.2` / `localhost` / `127.0.0.1` 放开明文 http。

## 订阅登录上游（`CLI_UPSTREAM=1`，仅测试与演示）

没有服务端 API key 时，用本机 Claude Code 命令行的订阅登录跑真实模型（M3 简报第 15 节）。**只用于回归测试和现场演示**，正式上线仍走 API key。

### 安装与登录（用户自己做一次）

```bash
npm install -g @anthropic-ai/claude-code   # 或按官方文档安装
claude auth login                          # 用订阅账号登录
```

注意：如果 `~/.claude/settings.json` 的 `env` 段里配了 `ANTHROPIC_API_KEY` / `ANTHROPIC_BASE_URL`（cc-switch 一类工具会写），
命令行平时用的是那份 key，并不代表订阅已登录。本模式会跳过所有设置文件，所以必须真的执行过 `claude auth login`。
自查（已登录时会发一条极短请求，消耗少量订阅额度；未登录时直接返回 `Not logged in`）：

```bash
cd "$(mktemp -d)" && env -u ANTHROPIC_API_KEY -u ANTHROPIC_AUTH_TOKEN -u ANTHROPIC_BASE_URL -u CLAUDECODE \
  claude -p --setting-sources "" --safe-mode --tools "" --model claude-sonnet-5-5 --system-prompt "只回复：好的" "你好"
```

### 启动

```bash
cd server
env -u ANTHROPIC_API_KEY -u ANTHROPIC_BASE_URL CLI_UPSTREAM=1 .venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
curl -s localhost:8000/healthz             # upstream 应为 "cli"
```

### 每个请求怎么调命令行

在一个新建的空临时目录里启动一次 `claude -p`，参数（以 `claude --help` 2.1.326 为准）：

| 目的 | 参数 |
|---|---|
| 系统提示整体替换 | `--system-prompt=<客户端传来的系统提示>`（不用 `--append-system-prompt`） |
| 固定模型 | `--model $MODEL`，不传 `--fallback-model` |
| 禁用全部工具 | `--tools ""` |
| 不读任何设置文件（含 settings.json 里注入的 key） | `--setting-sources ""` |
| 不加载 CLAUDE.md / 技能 / 插件 / 钩子 / MCP / 自定义命令 | `--safe-mode`、`--strict-mcp-config`（不给 `--mcp-config`）、`--disable-slash-commands` |
| 不落盘会话 | `--no-session-persistence` |
| 流式文本 | `--output-format stream-json --verbose --include-partial-messages`，取 `stream_event` 里的 `text_delta` |

子进程环境去掉 `ANTHROPIC_API_KEY`、`ANTHROPIC_AUTH_TOKEN`、`ANTHROPIC_BASE_URL`、`CLAUDECODE`。
命令行 `init` 事件里如果模型不一致、工具 / MCP / 技能 / 斜杠命令非空，请求直接报错。
命令行不存在、未登录、超时、非零退出、上述核对失败，统一回 `event: error`，`data` 只有错误码（`CliNotFound`、`CliNotLoggedIn`、`CliTimeout`、`CliExit`、`CliModelMismatch`、`CliToolsEnabled` 等），命令行原文只写服务端日志。

### 限制

- **多轮历史不完全等价**：命令行没有公开参数能注入以往的 assistant 回合，多轮时把历史按原顺序、带原角色标记写进最后一条用户消息（单轮完全等价）。
- 不用 `--bare`（它的认证只认 API key，读不到订阅登录），所以内置插件仍会加载（`init.plugins` 可见），它们是否往请求里加内容未逐一核实。
- 自动记忆：`--safe-mode` + `--setting-sources ""` + 自定义系统提示下是否完全不注入，需登录后实测（见交接单冒烟命令）。
- 每个请求起一个进程，首字延迟不具代表性，PRD 第 5 节"≤3 秒"在此模式下不测。
- temperature 同样不传；`max_tokens` 无法透传给命令行，忽略。
- 消耗的是登录账号的订阅额度。

## 在线模式：AI 助理训犬师（agent.py，2026-11-18）

App 的 AI 教练有"离线 / 在线"两种模式。在线模式由 App 跑 Agent 循环、在本机执行工具，这里只把每一轮交给模型：

```
POST /v1/agent
body: {system, messages: [Messages API 格式，含 tool_use / tool_result 块], tools: [{name, description, input_schema}]}
resp: {stop_reason, content: [块...], upstream: "api_key" | "cli" | "fake"}   上游失败 → HTTP 502
```

| 上游 | 怎么开 | 说明 |
|---|---|---|
| API key | 设 `ANTHROPIC_API_KEY` | Claude 原生工具调用，模型 `AGENT_MODEL`（默认 `claude-opus-5-5`），effort `AGENT_EFFORT`（默认 `medium`），开启服务端拒答兜底 |
| 命令行订阅登录 | `CLI_UPSTREAM=1` | 命令行不开放工具，改为把工具清单写进系统提示、要求模型只回 JSON，服务端解析成与原生相同的块。仅测试 / 演示 |
| 假上游 | `FAKE_UPSTREAM=1` | 固定剧本（查档案和记录 → 提议加入计划 → 回答），不调模型 |

演示（没有 API key 时用命令行订阅登录）：

```bash
CLI_UPSTREAM=1 .venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
```

使用第三方中转（提供 Anthropic 格式接口、支持工具调用）时，用环境变量指定地址和 key，并关掉拒答兜底（中转通常不支持该 beta）：

```bash
export ANTHROPIC_BASE_URL="https://中转站地址"
export ANTHROPIC_API_KEY="中转站的 key"
export FALLBACKS=off
.venv/bin/uvicorn main:app --host 0.0.0.0 --port 8000
```

注意：数据会经过中转站，只建议演示时使用；key 不要写进代码或提交到仓库。

`GET /healthz` 会返回 `agent_model` 与当前 `upstream`。

## M4：账号、家庭与同步（sync.py / store.py）

FastAPI + 标准库 `sqlite3`，**没有新增依赖**。数据库文件由环境变量 `DB_PATH` 指定，默认 `server/data/app.db`
（`data/` 已加入 `.gitignore`，不入库）。

```
POST  /v1/users                          注册匿名账号 → {user_id, token}（token 只存 SHA-256 摘要）
PATCH /v1/users/me                       改昵称
POST  /v1/households                     建家 + 上传全部现有数据 → {household_id, invite_code, max_seq}
POST  /v1/households/join                {invite_code, nickname} → {household_id}（邀请码不区分大小写）
GET   /v1/households/{id}                家庭名称、当前邀请码、成员（含昵称）
POST  /v1/households/{id}/invite_code    重新生成邀请码（仅创建者，旧码立即失效）
POST  /v1/sync/push                      {household_id, records:[{table, pk, payload, client_updated_at, deleted}]}
GET   /v1/sync/pull?household_id=&since_seq=N   该家庭 server_seq > N 的记录 + max_seq + has_more
```

- 除注册外都要 `Authorization: Bearer <token>`；不是该家庭成员返回 403。
- 冲突：`client_updated_at` 较新者胜，相同时先到者为准；`dog_badges` 已存在即拒绝覆盖。
- 邀请码只出现在请求 / 响应体里，不出现在 URL；token 与邀请码不写日志。

自测：`.venv/bin/python -m pytest -q`（`test_main.py` 代理 + `test_sync.py` 同步 + `test_agent.py` 在线模式，共 41 项）。

双端可见性端到端（需要 Android 模拟器 emulator-5554）：

```bash
.venv/bin/python e2e_visibility.py --port 8765     # 两个方向计时，结果写 e2e_last_result.json
.venv/bin/python m4_device_tour.py --port 8766     # M4 设备实测截图 → app/build/m4_screenshots/
```
