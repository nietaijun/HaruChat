"""
HaruChat 数据库模型
使用 SQLAlchemy ORM + SQLite3
"""

from datetime import datetime
from typing import Optional, List
from sqlalchemy import Column, Integer, String, Text, DateTime, Boolean, ForeignKey, Float, create_engine
from sqlalchemy.orm import relationship, declarative_base, Session
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker

Base = declarative_base()


class User(Base):
    """用户模型"""
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    username = Column(String(50), unique=True, nullable=False, index=True)
    email = Column(String(100), unique=True, nullable=False, index=True)
    password_hash = Column(String(255), nullable=False)
    nickname = Column(String(50), nullable=True)
    avatar = Column(String(255), nullable=True)
    
    # 用户设置
    default_provider = Column(String(20), default="gemini")
    default_model = Column(String(50), default="gemini-2.5-flash")
    temperature = Column(Float, default=0.7)
    
    # API Keys (加密存储)
    gemini_api_key = Column(String(255), nullable=True)
    openai_api_key = Column(String(255), nullable=True)
    
    # 状态
    is_active = Column(Boolean, default=True)
    is_admin = Column(Boolean, default=False)
    
    # 时间戳
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    last_login_at = Column(DateTime, nullable=True)
    
    # 关系
    sessions = relationship("ChatSession", back_populates="user", cascade="all, delete-orphan")
    
    def __repr__(self):
        return f"<User(id={self.id}, username='{self.username}')>"


class ChatSession(Base):
    """对话会话模型"""
    __tablename__ = "chat_sessions"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # 会话信息
    title = Column(String(200), default="新对话")
    provider = Column(String(20), default="gemini")
    model = Column(String(50), default="gemini-2.5-flash")
    
    # 统计
    message_count = Column(Integer, default=0)
    total_tokens = Column(Integer, default=0)
    
    # 状态
    is_archived = Column(Boolean, default=False)
    is_pinned = Column(Boolean, default=False)
    
    # 时间戳
    created_at = Column(DateTime, default=datetime.utcnow)
    updated_at = Column(DateTime, default=datetime.utcnow, onupdate=datetime.utcnow)
    
    # 关系
    user = relationship("User", back_populates="sessions")
    messages = relationship("ChatMessage", back_populates="session", cascade="all, delete-orphan", order_by="ChatMessage.created_at")
    
    def __repr__(self):
        return f"<ChatSession(id={self.id}, title='{self.title}')>"


class ChatMessage(Base):
    """聊天消息模型"""
    __tablename__ = "chat_messages"
    
    id = Column(Integer, primary_key=True, autoincrement=True)
    session_id = Column(Integer, ForeignKey("chat_sessions.id", ondelete="CASCADE"), nullable=False, index=True)
    
    # 消息内容
    role = Column(String(20), nullable=False)  # "user" | "assistant" | "system"
    content = Column(Text, nullable=False)
    thinking_content = Column(Text, nullable=True)  # AI 思考过程
    
    # Token 使用
    prompt_tokens = Column(Integer, default=0)
    completion_tokens = Column(Integer, default=0)
    total_tokens = Column(Integer, default=0)
    
    # 元数据
    model = Column(String(50), nullable=True)
    provider = Column(String(20), nullable=True)
    
    # 时间戳
    created_at = Column(DateTime, default=datetime.utcnow)
    
    # 关系
    session = relationship("ChatSession", back_populates="messages")
    
    def __repr__(self):
        return f"<ChatMessage(id={self.id}, role='{self.role}')>"


# 数据库配置
DATABASE_URL = "sqlite:///./data/haruchat.db"
ASYNC_DATABASE_URL = "sqlite+aiosqlite:///./data/haruchat.db"


def get_engine():
    """获取同步引擎"""
    return create_engine(DATABASE_URL, echo=False)


def get_async_engine():
    """获取异步引擎"""
    return create_async_engine(ASYNC_DATABASE_URL, echo=False)


def init_db():
    """初始化数据库（创建表）"""
    import os
    os.makedirs("./data", exist_ok=True)
    engine = get_engine()
    Base.metadata.create_all(engine)
    return engine


# Session 工厂
SessionLocal = sessionmaker(autocommit=False, autoflush=False)
AsyncSessionLocal = sessionmaker(class_=AsyncSession, autocommit=False, autoflush=False)

