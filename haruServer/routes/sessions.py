"""
HaruChat 会话管理路由
会话和消息的 CRUD 操作
"""

from typing import Optional, List
from fastapi import APIRouter, HTTPException, Depends, status, Query
from pydantic import BaseModel, Field
from datetime import datetime

from database import init_db, get_engine
from database.service import DatabaseService
from auth import get_current_user
from sqlalchemy.orm import Session

router = APIRouter(prefix="/api/sessions", tags=["会话管理"])


# ============== 数据模型 ==============

class CreateSessionRequest(BaseModel):
    title: Optional[str] = Field("新对话", max_length=200)
    provider: Optional[str] = Field("gemini")
    model: Optional[str] = Field("gemini-2.5-flash")


class UpdateSessionRequest(BaseModel):
    title: Optional[str] = Field(None, max_length=200)
    is_archived: Optional[bool] = None
    is_pinned: Optional[bool] = None


class MessageCreate(BaseModel):
    role: str = Field(..., description="角色: user/assistant/system")
    content: str = Field(..., description="消息内容")
    thinking_content: Optional[str] = None
    prompt_tokens: int = 0
    completion_tokens: int = 0
    total_tokens: int = 0
    model: Optional[str] = None
    provider: Optional[str] = None


class MessageResponse(BaseModel):
    id: int
    role: str
    content: str
    thinking_content: Optional[str]
    prompt_tokens: int
    completion_tokens: int
    total_tokens: int
    model: Optional[str]
    provider: Optional[str]
    created_at: datetime

    class Config:
        from_attributes = True


class SessionResponse(BaseModel):
    id: int
    title: str
    provider: str
    model: str
    message_count: int
    total_tokens: int
    is_archived: bool
    is_pinned: bool
    created_at: datetime
    updated_at: datetime
    
    class Config:
        from_attributes = True


class SessionDetailResponse(SessionResponse):
    messages: List[MessageResponse]


# ============== 依赖 ==============

def get_db():
    """获取数据库会话"""
    engine = get_engine()
    session = Session(engine)
    try:
        yield DatabaseService(session)
    finally:
        session.close()


# ============== 会话路由 ==============

@router.get("", response_model=List[SessionResponse])
async def list_sessions(
    include_archived: bool = Query(False, description="是否包含归档会话"),
    limit: int = Query(50, ge=1, le=100),
    offset: int = Query(0, ge=0),
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """获取用户的会话列表"""
    sessions = db.get_user_sessions(
        user_id=current_user["user_id"],
        include_archived=include_archived,
        limit=limit,
        offset=offset
    )
    return sessions


@router.post("", response_model=SessionResponse)
async def create_session(
    request: CreateSessionRequest,
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """创建新会话"""
    session = db.create_session(
        user_id=current_user["user_id"],
        title=request.title,
        provider=request.provider,
        model=request.model
    )
    return session


@router.get("/search", response_model=List[SessionResponse])
async def search_sessions(
    q: str = Query(..., min_length=1, description="搜索关键词"),
    limit: int = Query(20, ge=1, le=50),
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """搜索会话"""
    sessions = db.search_sessions(
        user_id=current_user["user_id"],
        query=q,
        limit=limit
    )
    return sessions


@router.get("/{session_id}", response_model=SessionDetailResponse)
async def get_session(
    session_id: int,
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """获取会话详情（包含消息）"""
    session = db.get_session_with_messages(
        session_id=session_id,
        user_id=current_user["user_id"]
    )
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在"
        )
    
    return SessionDetailResponse(
        id=session.id,
        title=session.title,
        provider=session.provider,
        model=session.model,
        message_count=session.message_count,
        total_tokens=session.total_tokens,
        is_archived=session.is_archived,
        is_pinned=session.is_pinned,
        created_at=session.created_at,
        updated_at=session.updated_at,
        messages=[MessageResponse(
            id=m.id,
            role=m.role,
            content=m.content,
            thinking_content=m.thinking_content,
            prompt_tokens=m.prompt_tokens,
            completion_tokens=m.completion_tokens,
            total_tokens=m.total_tokens,
            model=m.model,
            provider=m.provider,
            created_at=m.created_at
        ) for m in session.messages]
    )


@router.patch("/{session_id}", response_model=SessionResponse)
async def update_session(
    session_id: int,
    request: UpdateSessionRequest,
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """更新会话"""
    updates = request.model_dump(exclude_unset=True)
    
    session = db.update_session(
        session_id=session_id,
        user_id=current_user["user_id"],
        **updates
    )
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在"
        )
    
    return session


@router.delete("/{session_id}")
async def delete_session(
    session_id: int,
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """删除会话"""
    success = db.delete_session(
        session_id=session_id,
        user_id=current_user["user_id"]
    )
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在"
        )
    
    return {"message": "会话已删除"}


@router.post("/{session_id}/archive")
async def archive_session(
    session_id: int,
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """归档会话"""
    session = db.archive_session(
        session_id=session_id,
        user_id=current_user["user_id"],
        archived=True
    )
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在"
        )
    
    return {"message": "会话已归档"}


@router.post("/{session_id}/unarchive")
async def unarchive_session(
    session_id: int,
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """取消归档会话"""
    session = db.archive_session(
        session_id=session_id,
        user_id=current_user["user_id"],
        archived=False
    )
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在"
        )
    
    return {"message": "已取消归档"}


@router.post("/{session_id}/pin")
async def pin_session(
    session_id: int,
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """置顶会话"""
    session = db.pin_session(
        session_id=session_id,
        user_id=current_user["user_id"],
        pinned=True
    )
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在"
        )
    
    return {"message": "会话已置顶"}


@router.post("/{session_id}/unpin")
async def unpin_session(
    session_id: int,
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """取消置顶会话"""
    session = db.pin_session(
        session_id=session_id,
        user_id=current_user["user_id"],
        pinned=False
    )
    
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在"
        )
    
    return {"message": "已取消置顶"}


# ============== 消息路由 ==============

@router.get("/{session_id}/messages", response_model=List[MessageResponse])
async def list_messages(
    session_id: int,
    limit: int = Query(100, ge=1, le=500),
    offset: int = Query(0, ge=0),
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """获取会话的消息列表"""
    # 验证会话归属
    session = db.get_session_by_id(session_id, current_user["user_id"])
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在"
        )
    
    messages = db.get_session_messages(
        session_id=session_id,
        limit=limit,
        offset=offset
    )
    return messages


@router.post("/{session_id}/messages", response_model=MessageResponse)
async def create_message(
    session_id: int,
    request: MessageCreate,
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """创建消息"""
    # 验证会话归属
    session = db.get_session_by_id(session_id, current_user["user_id"])
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在"
        )
    
    message = db.create_message(
        session_id=session_id,
        role=request.role,
        content=request.content,
        thinking_content=request.thinking_content,
        prompt_tokens=request.prompt_tokens,
        completion_tokens=request.completion_tokens,
        total_tokens=request.total_tokens,
        model=request.model,
        provider=request.provider
    )
    return message


@router.delete("/{session_id}/messages/{message_id}")
async def delete_message(
    session_id: int,
    message_id: int,
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """删除消息"""
    # 验证会话归属
    session = db.get_session_by_id(session_id, current_user["user_id"])
    if not session:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在"
        )
    
    success = db.delete_message(message_id, session_id)
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="消息不存在"
        )
    
    return {"message": "消息已删除"}


@router.delete("/{session_id}/messages")
async def clear_messages(
    session_id: int,
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """清空会话的所有消息"""
    success = db.clear_session_messages(
        session_id=session_id,
        user_id=current_user["user_id"]
    )
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="会话不存在"
        )
    
    return {"message": "消息已清空"}

