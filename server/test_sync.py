"""M4 同步服务端自测（简报第 10 节第 4 条）。

运行：cd server && .venv/bin/python -m pytest -q
"""

import os
import tempfile

os.environ.setdefault("FAKE_UPSTREAM", "1")

import pytest  # noqa: E402
from fastapi.testclient import TestClient  # noqa: E402

import main  # noqa: E402
import store as store_mod  # noqa: E402
import sync  # noqa: E402

client = TestClient(main.app)


@pytest.fixture(autouse=True)
def fresh_db(tmp_path):
    sync.reset_store(str(tmp_path / "t.db"))
    yield


def register(nick=""):
    r = client.post("/v1/users", json={"nickname": nick})
    assert r.status_code == 200
    j = r.json()
    return j["user_id"], {"Authorization": f"Bearer {j['token']}"}


def rec(table, pk, ts, deleted=False, **payload):
    return {"table": table, "pk": pk, "payload": payload, "client_updated_at": ts, "deleted": deleted}


def make_household(h, hid="hh_1", records=()):
    r = client.post("/v1/households", json={"household_id": hid, "name": "豆豆的家", "records": list(records)}, headers=h)
    assert r.status_code == 200, r.text
    return r.json()


def test_register_and_auth():
    uid, h = register("妈妈")
    assert uid.startswith("u_")
    assert client.get("/v1/sync/pull", params={"household_id": "x"}).status_code == 401
    assert client.get("/v1/sync/pull", params={"household_id": "x"}, headers={"Authorization": "Bearer nope"}).status_code == 401


def test_token_stored_hashed(tmp_path):
    s = sync.get_store()
    uid, token = s.create_user("x")
    row = s._conn.execute("SELECT token_hash FROM tokens WHERE user_id = ?", (uid,)).fetchone()
    assert row[0] != token and row[0] == store_mod.hash_token(token)


def test_create_household_uploads_records_and_invite_code():
    uid, h = register("妈妈")
    j = make_household(h, records=[rec("dogs", "dog_1", "2026-11-17T01:00:00.000Z", name="豆豆")])
    code = j["invite_code"]
    assert len(code) == 6
    assert not set(code) & set("0O1IL")
    assert all(r["accepted"] for r in j["results"])
    pulled = client.get("/v1/sync/pull", params={"household_id": "hh_1", "since_seq": 0}, headers=h).json()
    assert [r["pk"] for r in pulled["records"]] == ["dog_1"]
    # 重试幂等，邀请码不变
    assert make_household(h)["invite_code"] == code


def test_join_case_insensitive_and_member_record():
    _, ha = register("妈妈")
    code = make_household(ha)["invite_code"]
    ub, hb = register()
    r = client.post("/v1/households/join", json={"invite_code": code.lower(), "nickname": "爸爸"}, headers=hb)
    assert r.status_code == 200 and r.json()["household_id"] == "hh_1"
    info = client.get("/v1/households/hh_1", headers=ha).json()
    assert {m["nickname"] for m in info["members"]} == {"妈妈", "爸爸"}
    pulled = client.get("/v1/sync/pull", params={"household_id": "hh_1"}, headers=ha).json()["records"]
    tables = {(r["table"], r["pk"]) for r in pulled}
    assert ("household_members", f"hh_1|{ub}") in tables
    assert ("users", ub) in tables
    # 已在别的家庭不能再加入 / 建家
    _, hc = register()
    code2 = make_household(hc, hid="hh_2")["invite_code"]
    assert client.post("/v1/households/join", json={"invite_code": code2}, headers=hb).status_code == 409


def test_bad_invite_404():
    _, h = register()
    assert client.post("/v1/households/join", json={"invite_code": "ZZZZZZ"}, headers=h).status_code == 404


def test_regenerate_invalidates_old_code():
    _, ha = register()
    old = make_household(ha)["invite_code"]
    r = client.post("/v1/households/hh_1/invite_code", headers=ha)
    new = r.json()["invite_code"]
    assert new != old
    _, hb = register()
    assert client.post("/v1/households/join", json={"invite_code": old}, headers=hb).status_code == 404
    assert client.post("/v1/households/join", json={"invite_code": new}, headers=hb).status_code == 200
    # 非创建者不能重新生成
    assert client.post("/v1/households/hh_1/invite_code", headers=hb).status_code == 403
    assert client.get("/v1/households/hh_1", headers=ha).json()["invite_code"] == new


def test_cross_household_403():
    _, ha = register()
    make_household(ha, hid="hh_a")
    _, hb = register()
    make_household(hb, hid="hh_b")
    assert client.get("/v1/sync/pull", params={"household_id": "hh_a"}, headers=hb).status_code == 403
    r = client.post("/v1/sync/push", json={"household_id": "hh_a", "records": [rec("dogs", "d", "2026-11-17T00:00:00Z")]}, headers=hb)
    assert r.status_code == 403
    assert client.get("/v1/households/hh_a", headers=hb).status_code == 403
    assert client.post("/v1/households/hh_a/invite_code", headers=hb).status_code == 403


def push(h, records, hid="hh_1"):
    r = client.post("/v1/sync/push", json={"household_id": hid, "records": records}, headers=h)
    assert r.status_code == 200, r.text
    return r.json()


def pull(h, since=0, hid="hh_1"):
    return client.get("/v1/sync/pull", params={"household_id": hid, "since_seq": since}, headers=h).json()


def test_last_writer_wins_and_first_arrival_on_tie():
    _, h = register()
    make_household(h)
    assert push(h, [rec("dog_cues", "dog_1|sit", "2026-11-17T01:00:00.000Z", cue_word="坐")])["results"][0]["accepted"]
    # 更旧的被拒
    assert not push(h, [rec("dog_cues", "dog_1|sit", "2026-11-17T00:59:59.999Z", cue_word="旧")])["results"][0]["accepted"]
    # 相同时间：先到者为准
    assert not push(h, [rec("dog_cues", "dog_1|sit", "2026-11-17T01:00:00Z", cue_word="同时")])["results"][0]["accepted"]
    # 更新的胜（不同时区写法也正确比较）
    assert push(h, [rec("dog_cues", "dog_1|sit", "2026-11-17T09:00:00.001+08:00", cue_word="新")])["results"][0]["accepted"]
    rows = pull(h)["records"]
    assert rows[-1]["payload"]["cue_word"] == "新"
    assert rows[-1]["client_updated_at"] == "2026-11-17T01:00:00.001Z"


def test_incremental_pull_by_seq():
    _, h = register()
    make_household(h)
    push(h, [rec("training_sessions", "s1", "2026-11-17T01:00:00Z")])
    first = pull(h)
    assert [r["pk"] for r in first["records"]] == ["s1"]
    seq = first["max_seq"]
    assert pull(h, seq)["records"] == []
    # 即使 client_updated_at 比已拉的早（设备时钟慢），也能按 seq 拉到
    push(h, [rec("training_sessions", "s2", "2020-01-01T00:00:00Z")])
    nxt = pull(h, seq)
    assert [r["pk"] for r in nxt["records"]] == ["s2"]
    assert nxt["max_seq"] > seq
    # 被覆盖的记录以新 seq 再次下发
    push(h, [rec("training_sessions", "s1", "2026-11-17T02:00:00Z", note_text="改")])
    again = pull(h, nxt["max_seq"])
    assert [r["pk"] for r in again["records"]] == ["s1"]


def test_badge_never_overwritten():
    ua, ha = register()
    make_household(ha)
    push(ha, [rec("dog_badges", "dog_1|first_step", "2026-11-17T01:00:00Z", earned_by_user_id=ua)])
    ub, hb = register()
    code = client.get("/v1/households/hh_1", headers=ha).json()["invite_code"]
    client.post("/v1/households/join", json={"invite_code": code}, headers=hb)
    r = push(hb, [rec("dog_badges", "dog_1|first_step", "2026-11-18T01:00:00Z", earned_by_user_id=ub)])
    assert r["results"][0]["accepted"] is False and r["results"][0]["reason"] == "immutable"
    badge = [x for x in pull(ha)["records"] if x["table"] == "dog_badges"]
    assert len(badge) == 1 and badge[0]["payload"]["earned_by_user_id"] == ua


def test_soft_delete_propagates():
    _, h = register()
    make_household(h)
    push(h, [rec("care_reminders", "cr_1", "2026-11-17T01:00:00Z", title="手动")])
    seq = pull(h)["max_seq"]
    push(h, [rec("care_reminders", "cr_1", "2026-11-17T02:00:00Z", deleted=True, title="手动")])
    rows = pull(h, seq)["records"]
    assert rows[0]["deleted"] is True
    # 删除后旧的写入不能复活
    assert not push(h, [rec("care_reminders", "cr_1", "2026-11-17T01:30:00Z", title="手动")])["results"][0]["accepted"]


def test_unknown_table_rejected():
    _, h = register()
    make_household(h)
    r = push(h, [rec("streaks", "dog_1", "2026-11-17T01:00:00Z")])
    assert r["results"][0]["accepted"] is False


def test_household_rename_via_sync():
    _, h = register()
    make_household(h)
    push(h, [rec("households", "hh_1", "2026-11-17T05:00:00Z", id="hh_1", name="新名字")])
    assert client.get("/v1/households/hh_1", headers=h).json()["name"] == "新名字"


def test_no_secret_in_logs(caplog):
    import logging

    caplog.set_level(logging.DEBUG)
    r = client.post("/v1/users", json={})
    token = r.json()["token"]
    h = {"Authorization": f"Bearer {token}"}
    code = make_household(h)["invite_code"]
    _, hb = register()
    client.post("/v1/households/join", json={"invite_code": code}, headers=hb)
    text = caplog.text
    assert token not in text and code not in text


# ---- M4 批次 B：FM-4 创建者移除成员 ----


def _family():
    ua, ha = register("妈妈")
    code = make_household(ha)["invite_code"]
    ub, hb = register("爸爸")
    client.post("/v1/households/join", json={"invite_code": code}, headers=hb)
    return ua, ha, ub, hb


def test_creator_removes_member_then_member_gets_403():
    ua, ha, ub, hb = _family()
    assert pull(hb)["records"] is not None
    seq = pull(ha)["max_seq"]
    r = client.delete(f"/v1/households/hh_1/members/{ub}", headers=ha)
    assert r.status_code == 200
    assert client.get("/v1/sync/pull", params={"household_id": "hh_1"}, headers=hb).status_code == 403
    rp = client.post("/v1/sync/push", json={"household_id": "hh_1", "records": [rec("dogs", "d", "2026-11-18T00:00:00Z")]}, headers=hb)
    assert rp.status_code == 403
    # 其他成员拉到成员软删除
    rows = pull(ha, seq)["records"]
    assert any(x["table"] == "household_members" and x["pk"] == f"hh_1|{ub}" and x["deleted"] for x in rows)
    info = client.get("/v1/households/hh_1", headers=ha).json()
    assert [m["user_id"] for m in info["members"]] == [ua]


def test_only_creator_can_remove_and_not_self():
    ua, ha, ub, hb = _family()
    assert client.delete(f"/v1/households/hh_1/members/{ua}", headers=hb).status_code == 403
    assert client.delete(f"/v1/households/hh_1/members/{ua}", headers=ha).status_code == 400
    assert client.delete("/v1/households/hh_1/members/u_nobody", headers=ha).status_code == 404
    _, hc = register()
    make_household(hc, hid="hh_2")
    assert client.delete(f"/v1/households/hh_1/members/{ub}", headers=hc).status_code == 403


def test_removed_member_can_rejoin_with_current_code():
    ua, ha, ub, hb = _family()
    client.delete(f"/v1/households/hh_1/members/{ub}", headers=ha)
    code = client.get("/v1/households/hh_1", headers=ha).json()["invite_code"]
    assert client.post("/v1/households/join", json={"invite_code": code}, headers=hb).status_code == 200
    assert client.get("/v1/sync/pull", params={"household_id": "hh_1"}, headers=hb).status_code == 200
