"""config.py 的单元测试：.env 解析、配置优先级。"""

from pawcoach import config


def test_load_dotenv_parses(tmp_path):
    p = tmp_path / ".env"
    p.write_text(
        "LLM_MODEL=deepseek-flash\n"
        "# 注释行\n"
        "export LLM_API_KEY=\"sk-test\"\n"
        "LLM_BASE_URL=https://api.openai-next.com/v1/chat/completions\n",
        encoding="utf-8",
    )
    out = config._load_dotenv(p)
    assert out["LLM_MODEL"] == "deepseek-flash"
    assert out["LLM_API_KEY"] == "sk-test"
    assert out["LLM_BASE_URL"] == "https://api.openai-next.com/v1/chat/completions"


def test_load_dotenv_missing(tmp_path):
    assert config._load_dotenv(tmp_path / "nope.env") == {}


def test_llm_config_defaults(monkeypatch, tmp_path):
    monkeypatch.setattr(config, "_ENV_PATH", tmp_path / "nope.env")
    for k in ("LLM_MODEL", "LLM_API_KEY", "LLM_BASE_URL"):
        monkeypatch.delenv(k, raising=False)
    cfg = config.llm_config()
    assert cfg["model"] == "deepseek-v4-flash"
    assert cfg["api_key"] == ""
    assert cfg["base_url"] == "https://api.openai-next.com/v1/chat/completions"


def test_llm_config_env_overrides_dotenv(monkeypatch, tmp_path):
    p = tmp_path / ".env"
    p.write_text("LLM_MODEL=from-dotenv\n", encoding="utf-8")
    monkeypatch.setattr(config, "_ENV_PATH", p)
    monkeypatch.setenv("LLM_MODEL", "from-env")
    monkeypatch.delenv("LLM_API_KEY", raising=False)
    monkeypatch.delenv("LLM_BASE_URL", raising=False)
    cfg = config.llm_config()
    assert cfg["model"] == "from-env"  # 环境变量优先于 .env
