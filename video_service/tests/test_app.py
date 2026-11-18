"""app/main.py 的最小测试：健康检查 + 404。"""

from fastapi.testclient import TestClient

from app.main import app


def test_health():
    client = TestClient(app)
    r = client.get("/")
    assert r.status_code == 200
    # M5 简报 3.5：健康检查额外返回 asr / pose / coach_mode，原断言 == {"status": "ok"} 放宽为包含
    assert r.json()["status"] == "ok"
    assert {"asr", "pose", "coach_mode"} <= set(r.json())


def test_results_not_found():
    client = TestClient(app)
    r = client.get("/results/nonexistent")
    assert r.status_code == 404
