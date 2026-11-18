"""PawCoach FastAPI 后端（D1）。

接口契约（供前端同事对接，详细字段见 pawcoach/schema.py 的 §1.2）：

POST /analyze
  multipart/form-data 上传：
    file  : 视频文件（必填）
    meta  : 可选，JSON 字符串，字段同 data/raw/<id>.meta.json
            {cues, marker_words, release_words, reward_taps, target_hold, red_flags}
  返回：{"job_id": "<32位十六进制>", "status": "pending"}
  说明：分析在后台线程跑，不上消息队列；拿到 job_id 后轮询 GET /results/<job_id>。

GET /results/<job_id>
  返回：
    {"status": "pending"}                          # 还没跑完
    {"status": "done", "result": {…}}              # 完成，result 是完整 AnalysisResult（含 quality/trials/summary/unpaired/coach）
    {"status": "failed", "error": "…"}             # 失败

GET /  健康检查，返回 {"status": "ok"}

运行：在项目根目录 `uvicorn app.main:app --reload`（相对路径依赖 CWD=项目根）。
"""

from __future__ import annotations

import json
import threading
import uuid
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, UploadFile

from pawcoach.analyze import analyze_video
from pawcoach.schema import meta_from_dict, to_json

UPLOAD_DIR = Path("data/uploads")

app = FastAPI(title="PawCoach", description="宠物训练视频分析后端")

# job_id -> {"status": "pending|done|failed", "result": str|None, "error": str|None}
_JOBS: dict[str, dict] = {}


def _run(job_id: str, video_path: Path, meta) -> None:
    try:
        result = analyze_video(video_path, meta=meta)
        _JOBS[job_id] = {"status": "done", "result": to_json(result), "error": None}
    except Exception as e:  # noqa: BLE001  兜底，把错误转成 failed 状态而非崩线程
        _JOBS[job_id] = {"status": "failed", "result": None, "error": str(e)}


@app.get("/")
def health() -> dict:
    return {"status": "ok"}


@app.post("/analyze")
async def analyze(file: UploadFile = File(...), meta: str = Form(None)) -> dict:
    job_id = uuid.uuid4().hex
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    video_path = UPLOAD_DIR / f"{job_id}_{file.filename}"
    video_path.write_bytes(await file.read())

    meta_info = None
    if meta:
        try:
            meta_info = meta_from_dict(json.loads(meta))
        except Exception as e:  # noqa: BLE001  meta 非法 → 400
            raise HTTPException(status_code=400, detail=f"meta 解析失败：{e}") from e

    _JOBS[job_id] = {"status": "pending", "result": None, "error": None}
    threading.Thread(target=_run, args=(job_id, video_path, meta_info), daemon=True).start()

    return {"job_id": job_id, "status": "pending"}


@app.get("/results/{job_id}")
def results(job_id: str) -> dict:
    job = _JOBS.get(job_id)
    if job is None:
        raise HTTPException(status_code=404, detail="job not found")
    if job["status"] == "done":
        return {"status": "done", "result": json.loads(job["result"])}
    if job["status"] == "failed":
        return {"status": "failed", "error": job["error"]}
    return {"status": "pending"}
