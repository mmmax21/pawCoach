"""sop.py 的单元测试：章节切分、关键词检索打分、top_k、文件缺失容错。"""

from pawcoach.coach.sop import _parse_sections, retrieve_sop

SAMPLE = """# Sit-Stay SOP

## 入门：3 秒保持
零食要在 1 秒内给。

## 进阶：加干扰
一次只加一种干扰。
"""


def test_parse_sections():
    sections = _parse_sections(SAMPLE)
    assert [t for t, _ in sections] == ["入门：3 秒保持", "进阶：加干扰"]
    assert "1 秒内" in sections[0][1]


def test_retrieve_sop_ranks_and_filters(tmp_path):
    p = tmp_path / "sop.md"
    p.write_text(SAMPLE, encoding="utf-8")
    out = retrieve_sop(["零食"], path=p)
    assert "入门" in out
    assert "进阶" not in out  # 进阶章节没有「零食」


def test_retrieve_sop_top_k(tmp_path):
    p = tmp_path / "sop.md"
    p.write_text(SAMPLE, encoding="utf-8")
    # 「保持」命中入门（标题有「3 秒保持」）和进阶（正文无），只入门命中
    out = retrieve_sop(["保持"], top_k=1, path=p)
    assert "入门" in out
    assert "进阶" not in out


def test_retrieve_sop_empty_terms(tmp_path):
    p = tmp_path / "sop.md"
    p.write_text(SAMPLE, encoding="utf-8")
    assert retrieve_sop([], path=p) == ""


def test_retrieve_sop_missing_file(tmp_path):
    # 文件不存在 → 返回空字符串，不抛异常（容错，analyze 不崩）
    assert retrieve_sop(["零食"], path=tmp_path / "nope.md") == ""
