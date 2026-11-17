"""家庭共享的 sqlite3 存储（M4 简报第 5.4 节）。

一张通用记录表 records 存所有同步表的行（服务端不解析训练字段），
另有 users、tokens、households、members、invite_codes 几张小表。

注意：token 只存 SHA-256 摘要；token 与邀请码都不写日志。
"""

from __future__ import annotations

import hashlib
import json
import os
import secrets
import sqlite3
import threading
import uuid
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, Optional, Tuple

# 邀请码字母表：大写字母 + 数字，去掉易混的 0/O、1/I/L（简报 5.2）。
INVITE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
INVITE_LEN = 6

# 复合主键在 records.pk 里用 "|" 连接，顺序与客户端 sync_codec.dart 一致。
PK_SEP = "|"

# 允许同步的表（简报 5.3）。
SYNC_TABLES = frozenset(
    {
        "households",
        "household_members",
        "users",
        "dogs",
        "dog_concerns",
        "dog_cues",
        "weekly_plans",
        "plan_goals",
        "daily_mini_tasks",
        "training_sessions",
        "weekly_reports",
        "ai_conversations",
        "ai_messages",
        "diagnosis_results",
        "care_reminders",
        "dog_badges",
    }
)

# 已存在即拒绝覆盖的表（简报 5.3"徽章例外"）。
IMMUTABLE_TABLES = frozenset({"dog_badges"})

SCHEMA = """
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  nickname TEXT NOT NULL DEFAULT '',
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS tokens (
  token_hash TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS households (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  creator_user_id TEXT NOT NULL,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS members (
  household_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  role TEXT NOT NULL,
  joined_at TEXT NOT NULL,
  PRIMARY KEY (household_id, user_id)
);
CREATE UNIQUE INDEX IF NOT EXISTS members_one_household ON members(user_id);
CREATE TABLE IF NOT EXISTS invite_codes (
  code TEXT PRIMARY KEY,
  household_id TEXT NOT NULL,
  active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS records (
  household_id TEXT NOT NULL,
  table_name TEXT NOT NULL,
  pk TEXT NOT NULL,
  payload_json TEXT NOT NULL,
  client_updated_at TEXT NOT NULL,
  deleted INTEGER NOT NULL DEFAULT 0,
  server_seq INTEGER NOT NULL,
  PRIMARY KEY (household_id, table_name, pk)
);
CREATE INDEX IF NOT EXISTS records_seq ON records(household_id, server_seq);
CREATE TABLE IF NOT EXISTS seq (
  id INTEGER PRIMARY KEY CHECK (id = 1),
  value INTEGER NOT NULL
);
INSERT OR IGNORE INTO seq (id, value) VALUES (1, 0);
"""


def now_iso() -> str:
    return normalize_ts(datetime.now(timezone.utc).isoformat())


def normalize_ts(ts: str) -> str:
    """统一成 UTC、毫秒精度、'Z' 结尾，字符串比较即时间比较。"""
    s = ts.strip()
    if s.endswith("Z") or s.endswith("z"):
        s = s[:-1] + "+00:00"
    dt = datetime.fromisoformat(s)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    dt = dt.astimezone(timezone.utc)
    return dt.strftime("%Y-%m-%dT%H:%M:%S.") + f"{dt.microsecond // 1000:03d}Z"


def hash_token(token: str) -> str:
    return hashlib.sha256(token.encode("utf-8")).hexdigest()


def normalize_invite(code: str) -> str:
    return code.strip().upper()


class StoreError(Exception):
    def __init__(self, status: int, code: str):
        super().__init__(code)
        self.status = status
        self.code = code


class Store:
    def __init__(self, path: str):
        if path != ":memory:":
            os.makedirs(os.path.dirname(os.path.abspath(path)), exist_ok=True)
        self._conn = sqlite3.connect(path, check_same_thread=False, isolation_level=None)
        self._conn.row_factory = sqlite3.Row
        self._lock = threading.Lock()
        with self._lock:
            self._conn.executescript(SCHEMA)
            if path != ":memory:":
                self._conn.execute("PRAGMA journal_mode=WAL")

    # ---- 基础 --------------------------------------------------------------

    def _tx(self):
        store = self

        class _Tx:
            def __enter__(self_inner):
                store._lock.acquire()
                store._conn.execute("BEGIN IMMEDIATE")
                return store._conn

            def __exit__(self_inner, exc_type, exc, tb):
                try:
                    store._conn.execute("ROLLBACK" if exc_type else "COMMIT")
                finally:
                    store._lock.release()
                return False

        return _Tx()

    @staticmethod
    def _next_seq(c: sqlite3.Connection) -> int:
        c.execute("UPDATE seq SET value = value + 1 WHERE id = 1")
        return c.execute("SELECT value FROM seq WHERE id = 1").fetchone()[0]

    # ---- 账号 --------------------------------------------------------------

    def create_user(self, nickname: str = "") -> Tuple[str, str]:
        user_id = "u_" + uuid.uuid4().hex
        token = secrets.token_urlsafe(32)
        ts = now_iso()
        with self._tx() as c:
            c.execute(
                "INSERT INTO users (id, nickname, created_at) VALUES (?, ?, ?)",
                (user_id, nickname, ts),
            )
            c.execute(
                "INSERT INTO tokens (token_hash, user_id, created_at) VALUES (?, ?, ?)",
                (hash_token(token), user_id, ts),
            )
        return user_id, token

    def user_for_token(self, token: str) -> Optional[str]:
        with self._lock:
            row = self._conn.execute(
                "SELECT user_id FROM tokens WHERE token_hash = ?", (hash_token(token),)
            ).fetchone()
        return row[0] if row else None

    def set_nickname(self, user_id: str, nickname: str) -> None:
        with self._tx() as c:
            c.execute("UPDATE users SET nickname = ? WHERE id = ?", (nickname, user_id))

    # ---- 家庭 --------------------------------------------------------------

    def household_of(self, user_id: str) -> Optional[str]:
        with self._lock:
            row = self._conn.execute(
                "SELECT household_id FROM members WHERE user_id = ?", (user_id,)
            ).fetchone()
        return row[0] if row else None

    def is_member(self, household_id: str, user_id: str) -> bool:
        with self._lock:
            row = self._conn.execute(
                "SELECT 1 FROM members WHERE household_id = ? AND user_id = ?",
                (household_id, user_id),
            ).fetchone()
        return row is not None

    def require_member(self, household_id: str, user_id: str) -> None:
        if not self.is_member(household_id, user_id):
            raise StoreError(403, "not_member")

    @staticmethod
    def _new_invite(c: sqlite3.Connection, household_id: str) -> str:
        c.execute("UPDATE invite_codes SET active = 0 WHERE household_id = ?", (household_id,))
        while True:
            code = "".join(secrets.choice(INVITE_ALPHABET) for _ in range(INVITE_LEN))
            if c.execute("SELECT 1 FROM invite_codes WHERE code = ?", (code,)).fetchone() is None:
                break
        c.execute(
            "INSERT INTO invite_codes (code, household_id, active, created_at) VALUES (?, ?, 1, ?)",
            (code, household_id, now_iso()),
        )
        return code

    @staticmethod
    def _active_invite(c: sqlite3.Connection, household_id: str) -> Optional[str]:
        row = c.execute(
            "SELECT code FROM invite_codes WHERE household_id = ? AND active = 1", (household_id,)
        ).fetchone()
        return row[0] if row else None

    def create_household(
        self, user_id: str, household_id: str, name: str, records: Iterable[Dict[str, Any]]
    ) -> Dict[str, Any]:
        """建家并上传全部现有数据。同一用户重复调用（重试）视为幂等。"""
        records = list(records)
        with self._tx() as c:
            existing = c.execute(
                "SELECT household_id FROM members WHERE user_id = ?", (user_id,)
            ).fetchone()
            if existing is not None and existing[0] != household_id:
                raise StoreError(409, "already_in_household")
            row = c.execute("SELECT creator_user_id FROM households WHERE id = ?", (household_id,)).fetchone()
            if row is not None and existing is None:
                raise StoreError(409, "household_exists")
            if row is None:
                ts = now_iso()
                c.execute(
                    "INSERT INTO households (id, name, creator_user_id, created_at) VALUES (?, ?, ?, ?)",
                    (household_id, name, user_id, ts),
                )
                c.execute(
                    "INSERT INTO members (household_id, user_id, role, joined_at) VALUES (?, ?, 'creator', ?)",
                    (household_id, user_id, ts),
                )
                code = self._new_invite(c, household_id)
            else:
                code = self._active_invite(c, household_id) or self._new_invite(c, household_id)
            results = [self._apply(c, household_id, r) for r in records]
            max_seq = self._max_seq(c, household_id)
        return {"household_id": household_id, "invite_code": code, "results": results, "max_seq": max_seq}

    def join(self, user_id: str, invite_code: str, nickname: str) -> str:
        code = normalize_invite(invite_code)
        with self._tx() as c:
            row = c.execute(
                "SELECT household_id FROM invite_codes WHERE code = ? AND active = 1", (code,)
            ).fetchone()
            if row is None:
                raise StoreError(404, "invalid_invite")
            household_id = row[0]
            existing = c.execute(
                "SELECT household_id FROM members WHERE user_id = ?", (user_id,)
            ).fetchone()
            if existing is not None:
                if existing[0] == household_id:
                    return household_id
                raise StoreError(409, "already_in_household")
            ts = now_iso()
            c.execute(
                "INSERT INTO members (household_id, user_id, role, joined_at) VALUES (?, ?, 'member', ?)",
                (household_id, user_id, ts),
            )
            if nickname:
                c.execute("UPDATE users SET nickname = ? WHERE id = ?", (nickname, user_id))
            u = c.execute("SELECT nickname, created_at FROM users WHERE id = ?", (user_id,)).fetchone()
            # 成员与昵称由服务端写进记录表，其他成员下次拉取即可看到（客户端也会自己推一遍，按时间戳合并）。
            self._apply(
                c,
                household_id,
                {
                    "table": "household_members",
                    "pk": household_id + PK_SEP + user_id,
                    "payload": {
                        "household_id": household_id,
                        "user_id": user_id,
                        "role": "member",
                        "joined_at": ts,
                    },
                    "client_updated_at": ts,
                    "deleted": False,
                },
            )
            self._apply(
                c,
                household_id,
                {
                    "table": "users",
                    "pk": user_id,
                    "payload": {"id": user_id, "nickname": u["nickname"], "created_at": u["created_at"]},
                    "client_updated_at": ts,
                    "deleted": False,
                },
            )
        return household_id

    def regenerate_invite(self, household_id: str, user_id: str) -> str:
        with self._tx() as c:
            row = c.execute("SELECT creator_user_id FROM households WHERE id = ?", (household_id,)).fetchone()
            if row is None or not c.execute(
                "SELECT 1 FROM members WHERE household_id = ? AND user_id = ?", (household_id, user_id)
            ).fetchone():
                raise StoreError(403, "not_member")
            if row[0] != user_id:
                raise StoreError(403, "not_creator")
            return self._new_invite(c, household_id)

    def remove_member(self, household_id: str, by_user_id: str, target_user_id: str) -> None:
        """FM-4：创建者移除成员。成员关系删除后，被移除者的 push / pull 一律 403；
        同时写一条 household_members 软删除记录，其他成员下次拉取时看到成员减少。"""
        with self._tx() as c:
            row = c.execute("SELECT creator_user_id FROM households WHERE id = ?", (household_id,)).fetchone()
            if row is None or not c.execute(
                "SELECT 1 FROM members WHERE household_id = ? AND user_id = ?", (household_id, by_user_id)
            ).fetchone():
                raise StoreError(403, "not_member")
            if row[0] != by_user_id:
                raise StoreError(403, "not_creator")
            if target_user_id == by_user_id:
                raise StoreError(400, "cannot_remove_self")
            m = c.execute(
                "SELECT role, joined_at FROM members WHERE household_id = ? AND user_id = ?",
                (household_id, target_user_id),
            ).fetchone()
            if m is None:
                raise StoreError(404, "member_not_found")
            c.execute("DELETE FROM members WHERE household_id = ? AND user_id = ?", (household_id, target_user_id))
            ts = now_iso()
            self._apply(
                c,
                household_id,
                {
                    "table": "household_members",
                    "pk": household_id + PK_SEP + target_user_id,
                    "payload": {"household_id": household_id, "user_id": target_user_id, "role": m["role"], "joined_at": m["joined_at"]},
                    "client_updated_at": ts,
                    "deleted": True,
                },
            )

    def household_info(self, household_id: str) -> Dict[str, Any]:
        with self._lock:
            c = self._conn
            h = c.execute("SELECT * FROM households WHERE id = ?", (household_id,)).fetchone()
            members = c.execute(
                "SELECT m.user_id, m.role, m.joined_at, u.nickname FROM members m "
                "LEFT JOIN users u ON u.id = m.user_id WHERE m.household_id = ? ORDER BY m.joined_at",
                (household_id,),
            ).fetchall()
            code = self._active_invite(c, household_id)
        return {
            "household_id": h["id"],
            "name": h["name"],
            "creator_user_id": h["creator_user_id"],
            "invite_code": code,
            "members": [dict(m) for m in members],
        }

    # ---- 同步 --------------------------------------------------------------

    @staticmethod
    def _max_seq(c: sqlite3.Connection, household_id: str) -> int:
        row = c.execute(
            "SELECT COALESCE(MAX(server_seq), 0) FROM records WHERE household_id = ?", (household_id,)
        ).fetchone()
        return row[0]

    def _apply(self, c: sqlite3.Connection, household_id: str, r: Dict[str, Any]) -> Dict[str, Any]:
        table = r["table"]
        pk = r["pk"]
        if table not in SYNC_TABLES:
            return {"table": table, "pk": pk, "accepted": False, "reason": "unknown_table"}
        ts = normalize_ts(r["client_updated_at"])
        deleted = 1 if r.get("deleted") else 0
        payload = json.dumps(r.get("payload") or {}, ensure_ascii=False, sort_keys=True)
        cur = c.execute(
            "SELECT client_updated_at FROM records WHERE household_id = ? AND table_name = ? AND pk = ?",
            (household_id, table, pk),
        ).fetchone()
        if cur is not None:
            if table in IMMUTABLE_TABLES:
                return {"table": table, "pk": pk, "accepted": False, "reason": "immutable"}
            # 较新者胜；相同时以先到者为准（拒绝后到的）。
            if ts <= cur[0]:
                return {"table": table, "pk": pk, "accepted": False, "reason": "stale"}
        seq = self._next_seq(c)
        c.execute(
            "INSERT INTO records (household_id, table_name, pk, payload_json, client_updated_at, deleted, server_seq) "
            "VALUES (?, ?, ?, ?, ?, ?, ?) "
            "ON CONFLICT(household_id, table_name, pk) DO UPDATE SET "
            "payload_json = excluded.payload_json, client_updated_at = excluded.client_updated_at, "
            "deleted = excluded.deleted, server_seq = excluded.server_seq",
            (household_id, table, pk, payload, ts, deleted, seq),
        )
        if table == "households" and not deleted:
            name = (r.get("payload") or {}).get("name")
            if name:
                c.execute("UPDATE households SET name = ? WHERE id = ?", (name, household_id))
        return {"table": table, "pk": pk, "accepted": True, "server_seq": seq}

    def push(self, household_id: str, user_id: str, records: List[Dict[str, Any]]) -> Dict[str, Any]:
        self.require_member(household_id, user_id)
        with self._tx() as c:
            results = [self._apply(c, household_id, r) for r in records]
            max_seq = self._max_seq(c, household_id)
        return {"results": results, "max_seq": max_seq}

    def pull(self, household_id: str, user_id: str, since_seq: int, limit: int = 2000) -> Dict[str, Any]:
        self.require_member(household_id, user_id)
        with self._lock:
            rows = self._conn.execute(
                "SELECT table_name, pk, payload_json, client_updated_at, deleted, server_seq FROM records "
                "WHERE household_id = ? AND server_seq > ? ORDER BY server_seq LIMIT ?",
                (household_id, since_seq, limit + 1),
            ).fetchall()
            max_seq = self._max_seq(self._conn, household_id)
        has_more = len(rows) > limit
        rows = rows[:limit]
        records = [
            {
                "table": r["table_name"],
                "pk": r["pk"],
                "payload": json.loads(r["payload_json"]),
                "client_updated_at": r["client_updated_at"],
                "deleted": bool(r["deleted"]),
                "server_seq": r["server_seq"],
            }
            for r in rows
        ]
        next_seq = records[-1]["server_seq"] if has_more else max(max_seq, since_seq)
        return {"records": records, "max_seq": next_seq, "has_more": has_more}
