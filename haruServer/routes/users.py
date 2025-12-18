"""
HaruChat 用户管理路由
用户信息和设置
"""

from typing import Optional
from fastapi import APIRouter, HTTPException, Depends, status
from pydantic import BaseModel, EmailStr, Field

from database import init_db, get_engine
from database.service import DatabaseService
from auth import get_current_user, hash_password, verify_password
from sqlalchemy.orm import Session

router = APIRouter(prefix="/api/users", tags=["用户管理"])


# ============== 数据模型 ==============

class UserProfile(BaseModel):
    id: int
    username: str
    email: str
    nickname: Optional[str]
    avatar: Optional[str]
    default_provider: str
    default_model: str
    temperature: float
    is_admin: bool
    
    class Config:
        from_attributes = True


class UpdateProfileRequest(BaseModel):
    nickname: Optional[str] = Field(None, max_length=50)
    avatar: Optional[str] = Field(None, max_length=255)
    default_provider: Optional[str] = Field(None)
    default_model: Optional[str] = Field(None)
    temperature: Optional[float] = Field(None, ge=0, le=2)


class ChangePasswordRequest(BaseModel):
    old_password: str = Field(..., description="旧密码")
    new_password: str = Field(..., min_length=6, max_length=100, description="新密码")


class UpdateApiKeysRequest(BaseModel):
    gemini_api_key: Optional[str] = None
    openai_api_key: Optional[str] = None


class UserStats(BaseModel):
    session_count: int
    message_count: int
    total_tokens: int


# ============== 依赖 ==============

def get_db():
    """获取数据库会话"""
    engine = get_engine()
    session = Session(engine)
    try:
        yield DatabaseService(session)
    finally:
        session.close()


# ============== 路由 ==============

@router.get("/me", response_model=UserProfile)
async def get_profile(
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """获取当前用户信息"""
    user = db.get_user_by_id(current_user["user_id"])
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在"
        )
    
    return UserProfile(
        id=user.id,
        username=user.username,
        email=user.email,
        nickname=user.nickname,
        avatar=user.avatar,
        default_provider=user.default_provider,
        default_model=user.default_model,
        temperature=user.temperature,
        is_admin=user.is_admin
    )


@router.patch("/me", response_model=UserProfile)
async def update_profile(
    request: UpdateProfileRequest,
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """更新用户信息"""
    updates = request.model_dump(exclude_unset=True)
    
    user = db.update_user(
        user_id=current_user["user_id"],
        **updates
    )
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在"
        )
    
    return UserProfile(
        id=user.id,
        username=user.username,
        email=user.email,
        nickname=user.nickname,
        avatar=user.avatar,
        default_provider=user.default_provider,
        default_model=user.default_model,
        temperature=user.temperature,
        is_admin=user.is_admin
    )


@router.post("/me/password")
async def change_password(
    request: ChangePasswordRequest,
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """修改密码"""
    user = db.get_user_by_id(current_user["user_id"])
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在"
        )
    
    # 验证旧密码
    if not verify_password(request.old_password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="旧密码错误"
        )
    
    # 更新密码
    new_hash = hash_password(request.new_password)
    db.update_user(user.id, password_hash=new_hash)
    
    return {"message": "密码已更新"}


@router.put("/me/api-keys")
async def update_api_keys(
    request: UpdateApiKeysRequest,
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """更新用户 API Keys"""
    user = db.update_user_api_keys(
        user_id=current_user["user_id"],
        gemini_api_key=request.gemini_api_key,
        openai_api_key=request.openai_api_key
    )
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在"
        )
    
    return {"message": "API Keys 已更新"}


@router.get("/me/api-keys")
async def get_api_keys(
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """获取用户 API Keys（脱敏显示）"""
    user = db.get_user_by_id(current_user["user_id"])
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在"
        )
    
    def mask_key(key: Optional[str]) -> Optional[str]:
        if not key:
            return None
        if len(key) <= 8:
            return "***"
        return key[:4] + "***" + key[-4:]
    
    return {
        "gemini_api_key": mask_key(user.gemini_api_key),
        "openai_api_key": mask_key(user.openai_api_key),
        "has_gemini_key": bool(user.gemini_api_key),
        "has_openai_key": bool(user.openai_api_key)
    }


@router.get("/me/stats", response_model=UserStats)
async def get_stats(
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """获取用户统计信息"""
    stats = db.get_user_stats(current_user["user_id"])
    return UserStats(**stats)


@router.delete("/me")
async def delete_account(
    db: DatabaseService = Depends(get_db),
    current_user: dict = Depends(get_current_user)
):
    """删除账户"""
    success = db.delete_user(current_user["user_id"])
    
    if not success:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="用户不存在"
        )
    
    return {"message": "账户已删除"}

