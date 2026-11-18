"""app/main.py 的最小测试：健康检查 + 404。"""

from fastapi.testclient import TestClient

from app.main import app


def test_health():
    client = TestClient(app)
    r = client.get("/")
    assert r.status_code == 200
    assert r.json() == {"status": "ok"}


def test_results_not_found():
    client = TestClient(app)
    r = client.get("/results/nonexistent")
    assert r.status_code == 404
