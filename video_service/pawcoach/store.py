"""结果落库（SQLite）——数据飞轮从这里埋点。

表结构预留 reviewer_correction / reviewer_agrees / risk_flag / referral_outcome，
见 docs/CodePlan_detail.md §5。
"""

from __future__ import annotations

import sqlite3
from pathlib import Path

from pawcoach.schema import AnalysisResult, to_json

_SCHEMA = """
CREATE TABLE IF NOT EXISTS analyses (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    video_id TEXT,
    date TEXT,
    dog_id TEXT,
    coach TEXT,
    payload TEXT,
    reviewer_correction TEXT,
    reviewer_agrees INTEGER,
    risk_flag INTEGER DEFAULT 0,
    referral_outcome TEXT,
    created_at TEXT DEFAULT (datetime('now'))
);
"""


def _connect(db_path: Path) -> sqlite3.Connection:
    db_path.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(str(db_path))
    conn.execute(_SCHEMA)
    return conn


def save_result(result: AnalysisResult, db_path: str | Path = "data/pawcoach.db") -> None:
    conn = _connect(Path(db_path))
    try:
        conn.execute(
            "INSERT INTO analyses (video_id, date, dog_id, coach, payload) VALUES (?, ?, ?, ?, ?)",
            (result.video_id, result.date, result.dog_id, result.coach, to_json(result)),
        )
        conn.commit()
    finally:
        conn.close()
