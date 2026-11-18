"""LLMCoach 的单元测试：无 key 兜底、OpenAI 兼容响应解析。"""

import pytest

from pawcoach import config
from pawcoach.coach.llm import LLMCoach
from pawcoach.schema import AnalysisResult, Summary, Trial


@pytest.fixture(autouse=True)
def no_dotenv(monkeypatch, tmp_path):
    # 测试不读真实 .env（可能含本地 key），指向不存在路径
    monkeypatch.setattr(config, "_ENV_PATH", tmp_path / "nonexistent.env")


def _result():
    return AnalysisResult(
        summary=Summary(trials=1, reliable_trials=1, success_rate=1.0, median_hold=5.0),
        trials=[
            Trial(
                cue_t=2.0, sit_start=3.0, sit_end=8.0, latency=1.0, hold=5.0,
                reward_delay=0.5, conf=0.9,
            )
        ],
    )


def test_no_key_falls_back(monkeypatch):
    monkeypatch.delenv("LLM_API_KEY", raising=False)
    text = LLMCoach().plan(_result(), [])
    assert "PawCoach" in text  # TemplateCoach 兜底


def test_openai_compatible_response_parsed(monkeypatch):
    monkeypatch.setenv("LLM_API_KEY", "test-key")

    class FakeResp:
        def raise_for_status(self):
            pass

        def json(self):
            return {"choices": [{"message": {"content": "建议文本"}}]}

    monkeypatch.setattr("pawcoach.coach.llm.httpx.post", lambda *a, **k: FakeResp())
    text = LLMCoach().plan(_result(), [])
    assert text == "建议文本"


def test_empty_content_falls_back(monkeypatch):
    monkeypatch.setenv("LLM_API_KEY", "test-key")

    class FakeResp:
        def raise_for_status(self):
            pass

        def json(self):
            return {"choices": [{"message": {"content": ""}}]}

    monkeypatch.setattr("pawcoach.coach.llm.httpx.post", lambda *a, **k: FakeResp())
    text = LLMCoach().plan(_result(), [])
    assert "PawCoach" in text  # 空 content → 兜底
