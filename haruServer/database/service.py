"""
HaruChat 数据库服务层
提供用户、会话、消息的 CRUD 操作
"""

from datetime import datetime
from typing import Optional, List
from sqlalchemy import select, update, delete, func, desc
from sqlalchemy.orm import Session, joinedload
from sqlalchemy.ext.asyncio import AsyncSession

from .models import User, ChatSession, ChatMessage


class DatabaseService:
    """数据库服务类"""
    
    def __init__(self, session: Session):
        self.session = session
    
    # ============== 用户操作 ==============
    
    def create_user(
        self,
        username: str,
        email: str,
        password_hash: str,
        nickname: Optional[str] = None
    ) -> User:
        """创建用户"""
        user = User(
            username=username,
            email=email,
            password_hash=password_hash,
            nickname=nickname or username
        )
        self.session.add(user)
        self.session.commit()
        self.session.refresh(user)
        return user
    
    def get_user_by_id(self, user_id: int) -> Optional[User]:
        """根据 ID 获取用户"""
        return self.session.query(User).filter(User.id == user_id).first()
    
    def get_user_by_username(self, username: str) -> Optional[User]:
        """根据用户名获取用户"""
        return self.session.query(User).filter(User.username == username).first()
    
    def get_user_by_email(self, email: str) -> Optional[User]:
        """根据邮箱获取用户"""
        return self.session.query(User).filter(User.email == email).first()
    
    def update_user(self, user_id: int, **kwargs) -> Optional[User]:
        """更新用户信息"""
        user = self.get_user_by_id(user_id)
        if user:
            for key, value in kwargs.items():
                if hasattr(user, key):
                    setattr(user, key, value)
            user.updated_at = datetime.utcnow()
            self.session.commit()
            self.session.refresh(user)
        return user
    
    def update_last_login(self, user_id: int) -> None:
        """更新最后登录时间"""
        self.session.query(User).filter(User.id == user_id).update({
            "last_login_at": datetime.utcnow()
        })
        self.session.commit()
    
    def delete_user(self, user_id: int) -> bool:
        """删除用户"""
        result = self.session.query(User).filter(User.id == user_id).delete()
        self.session.commit()
        return result > 0
    
    def update_user_api_keys(
        self,
        user_id: int,
        gemini_api_key: Optional[str] = None,
        openai_api_key: Optional[str] = None
    ) -> Optional[User]:
        """更新用户 API Keys"""
        updates = {}
        if gemini_api_key is not None:
            updates["gemini_api_key"] = gemini_api_key
        if openai_api_key is not None:
            updates["openai_api_key"] = openai_api_key
        
        if updates:
            return self.update_user(user_id, **updates)
        return self.get_user_by_id(user_id)
    
    # ============== 会话操作 ==============
    
    def create_session(
        self,
        user_id: int,
        title: str = "新对话",
        provider: str = "gemini",
        model: str = "gemini-2.5-flash"
    ) -> ChatSession:
        """创建会话"""
        session = ChatSession(
            user_id=user_id,
            title=title,
            provider=provider,
            model=model
        )
        self.session.add(session)
        self.session.commit()
        self.session.refresh(session)
        return session
    
    def get_session_by_id(self, session_id: int, user_id: int) -> Optional[ChatSession]:
        """根据 ID 获取会话（验证用户归属）"""
        return self.session.query(ChatSession).filter(
            ChatSession.id == session_id,
            ChatSession.user_id == user_id
        ).first()
    
    def get_user_sessions(
        self,
        user_id: int,
        include_archived: bool = False,
        limit: int = 50,
        offset: int = 0
    ) -> List[ChatSession]:
        """获取用户的所有会话"""
        query = self.session.query(ChatSession).filter(
            ChatSession.user_id == user_id
        )
        
        if not include_archived:
            query = query.filter(ChatSession.is_archived == False)
        
        return query.order_by(
            desc(ChatSession.is_pinned),
            desc(ChatSession.updated_at)
        ).offset(offset).limit(limit).all()
    
    def get_session_with_messages(
        self,
        session_id: int,
        user_id: int
    ) -> Optional[ChatSession]:
        """获取会话及其消息"""
        return self.session.query(ChatSession).options(
            joinedload(ChatSession.messages)
        ).filter(
            ChatSession.id == session_id,
            ChatSession.user_id == user_id
        ).first()
    
    def update_session(self, session_id: int, user_id: int, **kwargs) -> Optional[ChatSession]:
        """更新会话"""
        chat_session = self.get_session_by_id(session_id, user_id)
        if chat_session:
            for key, value in kwargs.items():
                if hasattr(chat_session, key):
                    setattr(chat_session, key, value)
            chat_session.updated_at = datetime.utcnow()
            self.session.commit()
            self.session.refresh(chat_session)
        return chat_session
    
    def delete_session(self, session_id: int, user_id: int) -> bool:
        """删除会话"""
        result = self.session.query(ChatSession).filter(
            ChatSession.id == session_id,
            ChatSession.user_id == user_id
        ).delete()
        self.session.commit()
        return result > 0
    
    def archive_session(self, session_id: int, user_id: int, archived: bool = True) -> Optional[ChatSession]:
        """归档/取消归档会话"""
        return self.update_session(session_id, user_id, is_archived=archived)
    
    def pin_session(self, session_id: int, user_id: int, pinned: bool = True) -> Optional[ChatSession]:
        """置顶/取消置顶会话"""
        return self.update_session(session_id, user_id, is_pinned=pinned)
    
    def search_sessions(
        self,
        user_id: int,
        query: str,
        limit: int = 20
    ) -> List[ChatSession]:
        """搜索会话"""
        return self.session.query(ChatSession).filter(
            ChatSession.user_id == user_id,
            ChatSession.title.ilike(f"%{query}%")
        ).order_by(desc(ChatSession.updated_at)).limit(limit).all()
    
    # ============== 消息操作 ==============
    
    def create_message(
        self,
        session_id: int,
        role: str,
        content: str,
        thinking_content: Optional[str] = None,
        prompt_tokens: int = 0,
        completion_tokens: int = 0,
        total_tokens: int = 0,
        model: Optional[str] = None,
        provider: Optional[str] = None
    ) -> ChatMessage:
        """创建消息"""
        message = ChatMessage(
            session_id=session_id,
            role=role,
            content=content,
            thinking_content=thinking_content,
            prompt_tokens=prompt_tokens,
            completion_tokens=completion_tokens,
            total_tokens=total_tokens,
            model=model,
            provider=provider
        )
        self.session.add(message)
        
        # 更新会话统计
        self.session.query(ChatSession).filter(
            ChatSession.id == session_id
        ).update({
            "message_count": ChatSession.message_count + 1,
            "total_tokens": ChatSession.total_tokens + total_tokens,
            "updated_at": datetime.utcnow()
        })
        
        self.session.commit()
        self.session.refresh(message)
        return message
    
    def get_session_messages(
        self,
        session_id: int,
        limit: int = 100,
        offset: int = 0
    ) -> List[ChatMessage]:
        """获取会话的消息列表"""
        return self.session.query(ChatMessage).filter(
            ChatMessage.session_id == session_id
        ).order_by(ChatMessage.created_at).offset(offset).limit(limit).all()
    
    def get_recent_messages(
        self,
        session_id: int,
        limit: int = 20
    ) -> List[ChatMessage]:
        """获取最近的消息（用于上下文）"""
        return self.session.query(ChatMessage).filter(
            ChatMessage.session_id == session_id
        ).order_by(desc(ChatMessage.created_at)).limit(limit).all()[::-1]
    
    def delete_message(self, message_id: int, session_id: int) -> bool:
        """删除消息"""
        message = self.session.query(ChatMessage).filter(
            ChatMessage.id == message_id,
            ChatMessage.session_id == session_id
        ).first()
        
        if message:
            # 更新会话统计
            self.session.query(ChatSession).filter(
                ChatSession.id == session_id
            ).update({
                "message_count": ChatSession.message_count - 1,
                "total_tokens": ChatSession.total_tokens - message.total_tokens
            })
            
            self.session.delete(message)
            self.session.commit()
            return True
        return False
    
    def clear_session_messages(self, session_id: int, user_id: int) -> bool:
        """清空会话的所有消息"""
        chat_session = self.get_session_by_id(session_id, user_id)
        if chat_session:
            self.session.query(ChatMessage).filter(
                ChatMessage.session_id == session_id
            ).delete()
            
            chat_session.message_count = 0
            chat_session.total_tokens = 0
            chat_session.updated_at = datetime.utcnow()
            
            self.session.commit()
            return True
        return False
    
    # ============== 统计操作 ==============
    
    def get_user_stats(self, user_id: int) -> dict:
        """获取用户统计信息"""
        session_count = self.session.query(func.count(ChatSession.id)).filter(
            ChatSession.user_id == user_id
        ).scalar()
        
        message_count = self.session.query(func.count(ChatMessage.id)).join(
            ChatSession
        ).filter(
            ChatSession.user_id == user_id
        ).scalar()
        
        total_tokens = self.session.query(func.sum(ChatSession.total_tokens)).filter(
            ChatSession.user_id == user_id
        ).scalar() or 0
        
        return {
            "session_count": session_count,
            "message_count": message_count,
            "total_tokens": total_tokens
        }

