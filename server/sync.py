"""账号、家庭、邀请码与同步接口（M4 简报第 5 节）。

  POST /v1/users                         注册匿名账号 → {user_id, token}
  PATCH /v1/users/me                     改昵称
  POST /v1/households                    建家 + 上传全部现有数据 → {household_id, invite_code, ...}
  POST /v1/households/join               用邀请码加入 → {household_id}
  GET  /v1/households/{id}               家庭信息、当前邀请码、成员
  POST /v1/households/{id}/invite_code   重新生成邀请码（仅创建者，旧码立即失效）
  DELETE /v1/households/{id}/members/{user_id}   移除成员（仅创建者，FM-4）
  POST /v1/sync/push                     上行一批记录
  GET  /v1/sync/pull?household_id=&since_seq=N   下行增量

除 POST /v1/users 外都要 Authorization: Bearer <token>。
token 与邀请码不写日志：邀请码只出现在请求 / 响应体里，不出现在 URL 中。
"""

from __future__ import annotations

import os
from typing import Any, Dict, List, Optional

from fastapi import APIRouter, Depends, Header, HTTPException, Query
from pydantic import BaseModel, Field

from store import Store, StoreError

DEFAULT_DB = os.path.join(os.path.dirname(os.path.abspath(__file__)), "data", "app.db")

_store: Optional[Store] = None


def get_store() -> Store:
    global _store
    if _store is None:
        _store = Store(os.environ.get("DB_PATH", DEFAULT_DB))
    return _store


def reset_store(path: str) -> Store:
    """测试用：换一个数据库文件。"""
    global _store
    _store = Store(path)
    return _store


router = APIRouter(prefix="/v1")


def current_user(authorization: Optional[str] = Header(default=None)) -> str:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise HTTPException(401, "unauthorized")
    user_id = get_store().user_for_token(authorization[7:].strip())
    if user_id is None:
        raise HTTPException(401, "unauthorized")
    return user_id


def _wrap(fn, *args, **kwargs):
    try:
        return fn(*args, **kwargs)
    except StoreError as e:
        raise HTTPException(e.status, e.code) from None


class NewUser(BaseModel):
    nickname: str = Field(default="", max_length=40)


class Nickname(BaseModel):
    nickname: str = Field(min_length=1, max_length=40)


class SyncRecord(BaseModel):
    table: str
    pk: str = Field(min_length=1)
    payload: Dict[str, Any] = Field(default_factory=dict)
    client_updated_at: str
    deleted: bool = False


class NewHousehold(BaseModel):
    household_id: str = Field(min_length=1)
    name: str = Field(min_length=1, max_length=60)
    records: List[SyncRecord] = Field(default_factory=list)


class JoinRequest(BaseModel):
    invite_code: str = Field(min_length=1, max_length=16)
    nickname: str = Field(default="", max_length=40)


class PushRequest(BaseModel):
    household_id: str
    records: List[SyncRecord]


@router.post("/users")
def create_user(body: NewUser) -> dict:
    user_id, token = get_store().create_user(body.nickname)
    return {"user_id": user_id, "token": token}


@router.patch("/users/me")
def set_nickname(body: Nickname, user_id: str = Depends(current_user)) -> dict:
    get_store().set_nickname(user_id, body.nickname)
    return {"ok": True}


@router.post("/households")
def create_household(body: NewHousehold, user_id: str = Depends(current_user)) -> dict:
    return _wrap(
        get_store().create_household,
        user_id,
        body.household_id,
        body.name,
        [r.model_dump() for r in body.records],
    )


@router.post("/households/join")
def join_household(body: JoinRequest, user_id: str = Depends(current_user)) -> dict:
    household_id = _wrap(get_store().join, user_id, body.invite_code, body.nickname)
    return {"household_id": household_id}


@router.get("/households/{household_id}")
def household_info(household_id: str, user_id: str = Depends(current_user)) -> dict:
    s = get_store()
    _wrap(s.require_member, household_id, user_id)
    return s.household_info(household_id)


@router.post("/households/{household_id}/invite_code")
def regenerate_invite(household_id: str, user_id: str = Depends(current_user)) -> dict:
    return {"invite_code": _wrap(get_store().regenerate_invite, household_id, user_id)}


@router.delete("/households/{household_id}/members/{member_user_id}")
def remove_member(household_id: str, member_user_id: str, user_id: str = Depends(current_user)) -> dict:
    """FM-4：仅创建者可移除成员（不能移除自己）。"""
    _wrap(get_store().remove_member, household_id, user_id, member_user_id)
    return {"ok": True}


@router.post("/sync/push")
def push(body: PushRequest, user_id: str = Depends(current_user)) -> dict:
    return _wrap(get_store().push, body.household_id, user_id, [r.model_dump() for r in body.records])


@router.get("/sync/pull")
def pull(
    household_id: str = Query(...),
    since_seq: int = Query(0, ge=0),
    user_id: str = Depends(current_user),
) -> dict:
    return _wrap(get_store().pull, household_id, user_id, since_seq)
