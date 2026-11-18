# PawCoach 后端 API（D1）

宠物训练视频分析后端，供前端同事对接。接口契约见 `app/main.py` 的 docstring，这里给启动方式和 curl 示例。

## 启动

在项目根目录（相对路径依赖 CWD）：

```bash
.venv/bin/python -m uvicorn app.main:app --host 127.0.0.1 --port 8001
```

> 注意：本机 8000 端口被 Docker（Attu/Milvus）占用，默认用 8001。

## curl 示例

```bash
# 健康检查
curl -s http://127.0.0.1:8001/

# 上传视频 + meta（meta 可选，JSON 字符串）
curl -F "file=@data/raw/sample.mp4" -F "meta=<data/raw/sample.meta.json" http://127.0.0.1:8001/analyze
# 返回 {"job_id":"...","status":"pending"}

# 轮询结果（分析在后台线程跑，几秒到几十秒不等）
curl -s http://127.0.0.1:8001/results/<job_id>
# 返回 {"status":"done","result":{...}} 或 {"status":"pending"} 或 {"status":"failed","error":"..."}
```

## 接口

| 方法 | 路径 | 说明 |
|---|---|---|
| GET | `/` | 健康检查 |
| POST | `/analyze` | multipart 上传 `file`（视频）+ `meta`（可选 JSON 字符串）→ `job_id` |
| GET | `/results/<job_id>` | 查结果：`pending` / `done`（含完整 result）/ `failed` |

`result` 是完整 `AnalysisResult`（quality / trials / summary / unpaired / coach），字段见 `pawcoach/schema.py` §1.2。

## 说明

- 分析在**后台线程**跑，不上消息队列；job 状态存内存（进程重启即失），MVP 够用。
- 上传的视频存 `data/uploads/`（`.gitignore` 已忽略 data/）。
- 姿态用真实现要跑在 `.venv-b` 环境（有 pandas/deeplabcut）；`.venv` 会回退 stub（适合先联调 API 流程）。
