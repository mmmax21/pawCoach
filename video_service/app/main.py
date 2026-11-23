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

    （减少重拍）pending 时可能带 "stage": "precheck" / "analyzing"；
    result.precheck.issues 非空表示预检判定拍坏（no_dog / angle），整段分析被跳过。

POST /realign   （减少重拍）JSON {result, meta, user_cue_sits: [坐姿起点秒…]}
  用户确认「这几次是听口令坐下的」后，用上次 result.events 重新对齐，同步返回 {"status": "done", "result": {…}}。

POST /frame-check   （取景自检）multipart：file = 一帧 JPEG、view = side | top
  返回 {level: green|yellow|red, message, reasons, dog_box, person_box, guide, iou}，框为 0~1 归一化坐标。
  同一时刻只跑一帧，忙时 429（App 丢帧即可）；缺检测器时 503。不落盘。

POST /body-check   （狗的状态）multipart：file = ≤20 秒视频或一张照片
  返回身体信号 {kind, frames, usable, signals: [{id, t_start, t_end}], metrics, postures}，只测量不下结论；
  App 按内容库 body_signals.yaml 判断"适不适合练"。忙时 429；上传的文件分析完立即删除。

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

from pydantic import BaseModel

from pawcoach.analyze import analyze_video, realign
from pawcoach.config import coach_mode
from pawcoach.schema import meta_from_dict, to_json

UPLOAD_DIR = Path("data/uploads")


# job_id -> {"status": "pending|done|failed", "result": str|None, "error": str|None}
_JOBS: dict[str, dict] = {}


def _run(job_id: str, video_path: Path, meta) -> None:
    def on_stage(stage: str) -> None:
        _JOBS[job_id]["stage"] = stage

    try:
        # M5 3.4：cleanup=True → 无论成功失败都删除上传视频、标准化视频、姿态与转写缓存
        # 减少重拍：precheck=True → 先抽帧预检，明显拍坏的视频十几秒内返回（result.precheck.issues）
        result = analyze_video(video_path, meta=meta, cleanup=True, precheck=True, on_stage=on_stage)
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

# 实时计时（WebSocket /live）：边拍边显示口令、坐下、奖励和奖励延迟
from app.live import router as live_router  # noqa: E402

app.include_router(live_router)


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
    out = {"status": "pending"}
    if job.get("stage"):
        out["stage"] = job["stage"]
    return out


class RealignRequest(BaseModel):
    result: dict
    meta: dict
    user_cue_sits: list[float]


@app.post("/realign")
def realign_endpoint(req: RealignRequest) -> dict:
    """用户在 App 里确认了哪几次坐下是听口令坐下的 → 用上次结果的 events 重新对齐。

    不需要视频（视频分析完已删除），同步返回：{"status": "done", "result": {…}}。
    """
    try:
        meta_info = meta_from_dict(req.meta)
        result = realign(req.result, meta_info, req.user_cue_sits)
    except Exception as e:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=f"无法重新对齐：{e}") from e
    return {"status": "done", "result": json.loads(to_json(result))}


_BODY_LOCK = threading.Lock()
_MAX_BODY_BYTES = 60 * 1024 * 1024


@app.post("/body-check")
async def body_check(file: UploadFile = File(...)) -> dict:
    """狗的状态（练前检查）：上传一段 ≤20 秒的视频或一张照片，同步返回身体信号（只测量，不下结论）。

    返回 {kind: video|image, frames, usable, signals: [{id, t_start, t_end}], metrics, postures}。
    视频只取前 20 秒、每秒 5 帧。同一时刻只跑一个，忙时 429。分析完立即删除上传的文件。
    """
    from app.live import get_engine
    from pawcoach.body.check import check_image, check_video

    data = await file.read()
    if not data or len(data) > _MAX_BODY_BYTES:
        raise HTTPException(status_code=400, detail="文件为空或过大")
    if not _BODY_LOCK.acquire(blocking=False):
        raise HTTPException(status_code=429, detail="busy")
    tmp = None
    try:
        import cv2
        import numpy as np

        engine = get_engine()
        img = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR)
        if img is not None:
            return check_image(engine, cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
        UPLOAD_DIR.mkdir(parents=True, exist_ok=True)
        tmp = UPLOAD_DIR / f"body_{uuid.uuid4().hex}_{_safe_name(file.filename)}"
        tmp.write_bytes(data)
        return check_video(engine, tmp)
    except HTTPException:
        raise
    except Exception as e:  # noqa: BLE001
        raise HTTPException(status_code=400, detail=f"无法分析：{type(e).__name__}") from e
    finally:
        _BODY_LOCK.release()
        if tmp is not None:
            tmp.unlink(missing_ok=True)


# 取景自检的实时检测：一次只跑一帧，且同一时刻只允许一个推理在跑。
# 手机传帧比推理快时，多出来的请求直接 429，由 App 丢帧；不排队，否则预览框会越来越滞后。
_FRAME_LOCK = threading.Lock()
_MAX_FRAME_BYTES = 2 * 1024 * 1024


@app.post("/frame-check")
async def frame_check(
    file: UploadFile = File(...),
    view: str = Form("side"),
    format: str = Form("jpeg"),
    width: int | None = Form(None),
    height: int | None = Form(None),
) -> dict:
    """取景自检（实时引导用）。

    multipart：file = 一帧图像、view = side | top。
    format = jpeg（默认）：file 是 JPEG 字节。
    format = rgb：file 是 width × height × 3 的原始 RGB 字节（App 直接从相机帧缩小后发送，省去手机端编码）；
                  这时必须带 width、height，字节数要正好等于 width × height × 3。
    返回 FrameVerdict：{level: green|yellow|red, message, reasons, dog_box, person_box, guide, iou}，
    框坐标都是相对画面宽高的 0~1，App 直接叠在预览上。不落盘，不保留任何帧。
    """
    from pawcoach.framing import SPECS, detect_frame, judge_frame

    if view not in SPECS:
        raise HTTPException(status_code=400, detail=f"view 必须是 {sorted(SPECS)}")
    if format not in ("jpeg", "rgb"):
        raise HTTPException(status_code=400, detail="format 必须是 jpeg 或 rgb")
    data = await file.read()
    if not data or len(data) > _MAX_FRAME_BYTES:
        raise HTTPException(status_code=400, detail="帧为空或过大")
    if format == "rgb":
        if not width or not height or width <= 0 or height <= 0 or width * height * 3 != len(data):
            raise HTTPException(status_code=400, detail="rgb 帧需要 width、height，且字节数必须等于 width×height×3")
    if not _FRAME_LOCK.acquire(blocking=False):
        raise HTTPException(status_code=429, detail="busy")
    try:
        import cv2
        import numpy as np

        if format == "rgb":
            img = cv2.cvtColor(np.frombuffer(data, np.uint8).reshape(height, width, 3), cv2.COLOR_RGB2BGR)
        else:
            img = cv2.imdecode(np.frombuffer(data, np.uint8), cv2.IMREAD_COLOR)
        if img is None:
            raise HTTPException(status_code=400, detail="无法解码为图片")
        h, w = img.shape[:2]
        try:
            dogs, persons = detect_frame(img)
        except Exception as e:  # noqa: BLE001  缺 ultralytics 等：明确告诉 App 取景自检不可用
            raise HTTPException(status_code=503, detail=f"detector_unavailable: {e}") from e
        return judge_frame(view, w, h, dogs, persons).to_dict()
    finally:
        _FRAME_LOCK.release()
