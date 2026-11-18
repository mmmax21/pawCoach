"""C3：SOP 语料 + 简单关键词检索（RAG 最小实现，不上向量库）。

语料在 prompts/sop.md（按「## 」分章节）。检索 = 关键词命中打分，返回 top_k 章节。
"""

from __future__ import annotations

from pathlib import Path

DEFAULT_SOP = "prompts/sop.md"


def _parse_sections(text: str) -> list[tuple[str, str]]:
    """把 sop.md 按「## 」切成 [(标题, 正文), ...]，跳过一级标题。"""
    sections: list[tuple[str, str]] = []
    title = ""
    body: list[str] = []
    for line in text.splitlines():
        if line.startswith("## "):
            if title:
                sections.append((title, "\n".join(body).strip()))
            title = line[3:].strip()
            body = []
        elif line.startswith("# "):
            continue
        else:
            body.append(line)
    if title:
        sections.append((title, "\n".join(body).strip()))
    return sections


def retrieve_sop(
    query_terms: list[str], top_k: int = 2, path: str | Path = DEFAULT_SOP
) -> str:
    """按关键词命中数检索 SOP 章节，返回 top_k 个命中章节（拼接）。

    一个词命中一章记 1 分；只返回至少命中 1 词的章节；无词或文件缺失返回空字符串。
    """
    if not query_terms:
        return ""
    p = Path(path)
    if not p.exists():
        return ""
    sections = _parse_sections(p.read_text(encoding="utf-8"))
    scored = []
    for title, body in sections:
        text = f"{title}\n{body}"
        score = sum(1 for term in query_terms if term in text)
        if score > 0:
            scored.append((score, title, body))
    scored.sort(key=lambda x: (-x[0], x[1]))
    return "\n\n".join(f"## {title}\n{body}" for _, title, body in scored[:top_k])
