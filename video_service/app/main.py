"""PawCoach FastAPI 后端（D1）。

接口契约（供前端同事对接，详细字段见 pawcoach/schema.py 的 §1.2）：

POST /analyze
  multipart/form-data 上传：
    file  : 视频文件（必填）
    meta  : 可选，JSON 字符串，字段同 data/raw/<id>.meta.json
            {cues, marker_words, release_words, reward_taps, target_hold, red_flags,
             correction_words, language}            # 后两项 M5 新增，可选
  返回：{"job_id": "<32位十六进制>", "status": "pending"}
  说明：分析在后台线程跑，不上消息队列；拿到 job_id 后轮询 GET /results/<job_id>。

GET /results/<job_id>
  返回：
    {"status": "pending"}                          # 还没跑完
    {"status": "done", "result": {…}}              # 完成，result 是完整 AnalysisResult（含 quality/trials/summary/unpaired/coach）
    {"status": "failed", "error": "…"}             # 失败

GET /  健康检查，返回 {"status": "ok", "asr": …, "pose": …, "coach_mode": …}（M5：后三项供 App 与演示前自查）

M5：上传的视频与全部中间产物在分析完成或失败后删除（只留 data/pawcoach.db 里的数字）；
教练文字由 COACH_MODE 控制，默认 off（coach 为空串，不发任何外部请求）。

运行：在项目根目录 `uvicorn app.main:app --reload`（相对路径依赖 CWD=项目根）。
"""

from __future__ import annotations

import importlib.util
from contextlib import asynccontextmanager
import json
import re
import threading
import uuid
from pathlib import Path

from fastapi import FastAPI, File, Form, HTTPException, UploadFile

from pawcoach.analyze import analyze_video
from pawcoach.config import coach_mode
from pawcoach.schema import meta_from_dict, to_json

UPLOAD_DIR = Path("data/uploads")


# job_id -> {"status": "pending|done|failed", "result": str|None, "error": str|None}
_JOBS: dict[str, dict] = {}


def _run(job_id: str, video_path: Path, meta) -> None:
    try:
        # M5 3.4：cleanup=True → 无论成功失败都删除上传视频、标准化视频、姿态与转写缓存
        result = analyze_video(video_path, meta=meta, cleanup=True)
        _JOBS[job_id] = {"status": "done", "result": to_json(result), "error": None}
    except Exception as e:  # noqa: BLE001  兜底，把错误转成 failed 状态而非崩线程
        _JOBS[job_id] = {"status": "failed", "result": None, "error": str(e)}


def _asr_status() -> str:
    """loaded（本进程已加载）/ ready（已下载未加载）/ not_downloaded / unavailable（缺 whisper）。"""
    from pawcoach.audio import transcribe as tr

    if tr.model_loaded():
        return "loaded"
    if importlib.util.find_spec("whisper") is None:
        return "unavailable"
    cache = Path.home() / ".cache" / "whisper" / f"{tr.DEFAULT_MODEL}.pt"
    return "ready" if cache.exists() else "not_downloaded"


def _pose_status() -> str:
    """ready（SuperAnimal + YOLO 都就绪）/ not_downloaded（缺权重）/ stub（环境缺依赖，姿态整段占位）。"""
    if any(importlib.util.find_spec(m) is None for m in ("pandas", "deeplabcut", "ultralytics")):
        return "stub"
    from pawcoach.pose.detect import DEFAULT_WEIGHTS

    if not Path(DEFAULT_WEIGHTS).exists():
        return "not_downloaded"
    try:
        from deeplabcut.pose_estimation_pytorch.modelzoo.utils import get_snapshot_folder_path

        from pawcoach.pose.superanimal import DEFAULT_DETECTOR, DEFAULT_MODEL, SUPERANIMAL

        folder = get_snapshot_folder_path()
        for name in (DEFAULT_MODEL, DEFAULT_DETECTOR):
            if not (folder / f"{SUPERANIMAL}_{name}.pt").exists():
                return "not_downloaded"
    except Exception:  # noqa: BLE001
        return "not_downloaded"
    return "ready"


def _preload_asr() -> None:
    """后台预加载 Whisper，第一个请求不必等模型加载；失败（缺 whisper）静默，分析时会回退空事件。"""
    if _asr_status() != "ready":
        return

    def load():
        from pawcoach.audio import transcribe as tr

        try:
            tr.load_model()
        except Exception:  # noqa: BLE001
            pass

    threading.Thread(target=load, daemon=True).start()


@asynccontextmanager
async def _lifespan(_app):
    _preload_asr()
    yield


app = FastAPI(title="PawCoach", description="宠物训练视频分析后端", lifespan=_lifespan)


@app.get("/")
def health() -> dict:
    return {
        "status": "ok",
        "asr": _asr_status(),
        "pose": _pose_status(),
        "coach_mode": coach_mode(),
    }


def _safe_name(filename: str | None) -> str:
    """上传文件名只保留安全字符（防路径穿越），保留扩展名。"""
    name = Path(filename or "upload.mp4").name
    name = re.sub(r"[^A-Za-z0-9._-]+", "_", name).strip("._") or "upload.mp4"
    return name[-80:]


@app.post("/analyze")
async def analyze(file: UploadFile = File(...), meta: str = Form(None)) -> dict:
    job_id = uuid.uuid4().hex
    UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
    meta_info = None
    if meta:
        try:
            meta_info = meta_from_dict(json.loads(meta))
        except Exception as e:  # noqa: BLE001  meta 非法 → 400
            raise HTTPException(status_code=400, detail=f"meta 解析失败：{e}") from e

    # M5：meta 校验通过后才落盘，避免 400 时留下视频
    video_path = UPLOAD_DIR / f"{job_id}_{_safe_name(file.filename)}"
    video_path.write_bytes(await file.read())

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
