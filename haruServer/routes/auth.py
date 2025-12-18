"""
HaruChat 认证路由
注册、登录、Token 刷新
"""

from typing import Optional
from fastapi import APIRouter, HTTPException, Depends, status
from pydantic import BaseModel, EmailStr, Field

from database import User, init_db, get_engine
from database.service import DatabaseService
from auth import hash_password, verify_password, create_access_token, create_refresh_token, decode_token
from sqlalchemy.orm import Session

router = APIRouter(prefix="/api/auth", tags=["认证"])


# ============== 数据模型 ==============

class RegisterRequest(BaseModel):
    username: str = Field(..., min_length=3, max_length=50, description="用户名")
    email: EmailStr = Field(..., description="邮箱")
    password: str = Field(..., min_length=6, max_length=100, description="密码")
    nickname: Optional[str] = Field(None, max_length=50, description="昵称")


class LoginRequest(BaseModel):
    username: str = Field(..., description="用户名或邮箱")
    password: str = Field(..., description="密码")


class RefreshRequest(BaseModel):
    refresh_token: str = Field(..., description="刷新 Token")


class TokenResponse(BaseModel):
    access_token: str
    refresh_token: str
    token_type: str = "bearer"
    user: dict


class UserResponse(BaseModel):
    id: int
    username: str
    email: str
    nickname: Optional[str]
    avatar: Optional[str]
    default_provider: str
    default_model: str


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

@router.post("/register", response_model=TokenResponse)
async def register(request: RegisterRequest, db: DatabaseService = Depends(get_db)):
    """用户注册"""
    
    # 检查用户名是否存在
    if db.get_user_by_username(request.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="用户名已存在"
        )
    
    # 检查邮箱是否存在
    if db.get_user_by_email(request.email):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="邮箱已被注册"
        )
    
    # 创建用户
    password_hash = hash_password(request.password)
    user = db.create_user(
        username=request.username,
        email=request.email,
        password_hash=password_hash,
        nickname=request.nickname
    )
    
    # 生成 Token
    access_token = create_access_token(user.id, user.username)
    refresh_token = create_refresh_token(user.id)
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user={
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "nickname": user.nickname,
            "avatar": user.avatar,
            "default_provider": user.default_provider,
            "default_model": user.default_model
        }
    )


@router.post("/login", response_model=TokenResponse)
async def login(request: LoginRequest, db: DatabaseService = Depends(get_db)):
    """用户登录"""
    
    # 查找用户（支持用户名或邮箱登录）
    user = db.get_user_by_username(request.username)
    if not user:
        user = db.get_user_by_email(request.username)
    
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户名或密码错误"
        )
    
    # 验证密码
    if not verify_password(request.password, user.password_hash):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户名或密码错误"
        )
    
    # 检查用户状态
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="账户已被禁用"
        )
    
    # 更新最后登录时间
    db.update_last_login(user.id)
    
    # 生成 Token
    access_token = create_access_token(user.id, user.username)
    refresh_token = create_refresh_token(user.id)
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user={
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "nickname": user.nickname,
            "avatar": user.avatar,
            "default_provider": user.default_provider,
            "default_model": user.default_model
        }
    )


@router.post("/refresh", response_model=TokenResponse)
async def refresh(request: RefreshRequest, db: DatabaseService = Depends(get_db)):
    """刷新 Token"""
    
    payload = decode_token(request.refresh_token)
    
    if not payload or payload.get("type") != "refresh":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="无效的刷新 Token"
        )
    
    user_id = int(payload["sub"])
    user = db.get_user_by_id(user_id)
    
    if not user or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="用户不存在或已被禁用"
        )
    
    # 生成新 Token
    access_token = create_access_token(user.id, user.username)
    refresh_token = create_refresh_token(user.id)
    
    return TokenResponse(
        access_token=access_token,
        refresh_token=refresh_token,
        user={
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "nickname": user.nickname,
            "avatar": user.avatar,
            "default_provider": user.default_provider,
            "default_model": user.default_model
        }
    )

