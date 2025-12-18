"""
HaruChat Backend Server
基于 FastAPI 的 AI 聊天后端服务
支持用户管理、会话管理、消息存储
"""

import os
import json
import httpx
from typing import Optional, List, AsyncGenerator
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from dotenv import load_dotenv
from sse_starlette.sse import EventSourceResponse

# 加载环境变量
load_dotenv()

# 导入数据库模块
from database import init_db
from routes import auth_router, sessions_router, users_router


# ============== 配置 ==============

class Config:
    GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
    GEMINI_BASE_URL = os.getenv("GEMINI_BASE_URL", "https://generativelanguage.googleapis.com/v1beta")
    
    OPENAI_API_KEY = os.getenv("OPENAI_API_KEY", "")
    OPENAI_BASE_URL = os.getenv("OPENAI_BASE_URL", "https://api.openai.com/v1")
    
    # 默认模型
    DEFAULT_GEMINI_MODEL = "gemini-2.5-flash"
    DEFAULT_OPENAI_MODEL = "gpt-4o"


# ============== 数据模型 ==============

class Message(BaseModel):
    role: str  # "user" | "assistant" | "system"
    content: str


class ChatRequest(BaseModel):
    provider: str = "gemini"  # "gemini" | "openai"
    model: Optional[str] = None
    messages: List[Message]
    temperature: float = 0.7
    max_tokens: int = 4096
    stream: bool = False
    enable_search: bool = False  # 仅 Gemini 支持
    include_thoughts: bool = False  # 仅 Gemini 支持


class ChatResponse(BaseModel):
    content: str
    thinking_content: Optional[str] = None
    usage: Optional[dict] = None


class ModelsResponse(BaseModel):
    provider: str
    models: List[str]


# ============== HTTP 客户端 ==============

@asynccontextmanager
async def get_http_client():
    async with httpx.AsyncClient(timeout=120.0) as client:
        yield client


# ============== 应用生命周期 ==============

@asynccontextmanager
async def lifespan(app: FastAPI):
    """应用生命周期管理"""
    # 启动时初始化数据库
    print("🚀 HaruChat Server 启动中...")
    init_db()
    print("✅ 数据库初始化完成")
    yield
    # 关闭时清理
    print("👋 HaruChat Server 关闭")


# ============== FastAPI 应用 ==============

app = FastAPI(
    title="HaruChat API",
    description="HaruChat 后端 API 服务 - 支持用户管理和对话存储",
    version="2.0.0",
    lifespan=lifespan
)

# CORS 配置
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# 注册路由
app.include_router(auth_router)
app.include_router(users_router)
app.include_router(sessions_router)


# ============== Gemini API ==============

async def call_gemini(
    client: httpx.AsyncClient,
    request: ChatRequest
) -> ChatResponse:
    """调用 Gemini API（非流式）"""
    
    model = request.model or Config.DEFAULT_GEMINI_MODEL
    url = f"{Config.GEMINI_BASE_URL}/models/{model}:generateContent?key={Config.GEMINI_API_KEY}"
    
    # 构建请求体
    contents = []
    for msg in request.messages:
        role = "user" if msg.role == "user" else "model"
        contents.append({
            "role": role,
            "parts": [{"text": msg.content}]
        })
    
    body = {
        "contents": contents,
        "generationConfig": {
            "temperature": request.temperature,
            "maxOutputTokens": request.max_tokens
        }
    }
    
    # Google Search
    if request.enable_search:
        body["tools"] = [{"google_search": {}}]
    
    # Thinking
    if request.include_thoughts:
        body["thinkingConfig"] = {"includeThoughts": True}
    
    response = await client.post(url, json=body)
    
    if response.status_code != 200:
        error_detail = response.text
        raise HTTPException(status_code=response.status_code, detail=error_detail)
    
    data = response.json()
    
    # 解析响应
    content = ""
    thinking_content = None
    
    if "candidates" in data and data["candidates"]:
        candidate = data["candidates"][0]
        if "content" in candidate and "parts" in candidate["content"]:
            for part in candidate["content"]["parts"]:
                if part.get("thought"):
                    thinking_content = (thinking_content or "") + part.get("text", "")
                else:
                    content += part.get("text", "")
    
    usage = None
    if "usageMetadata" in data:
        usage = {
            "prompt_tokens": data["usageMetadata"].get("promptTokenCount", 0),
            "completion_tokens": data["usageMetadata"].get("candidatesTokenCount", 0),
            "total_tokens": data["usageMetadata"].get("totalTokenCount", 0)
        }
    
    return ChatResponse(content=content, thinking_content=thinking_content, usage=usage)


async def stream_gemini(
    client: httpx.AsyncClient,
    request: ChatRequest
) -> AsyncGenerator[str, None]:
    """调用 Gemini API（流式）"""
    
    model = request.model or Config.DEFAULT_GEMINI_MODEL
    url = f"{Config.GEMINI_BASE_URL}/models/{model}:streamGenerateContent?alt=sse&key={Config.GEMINI_API_KEY}"
    
    contents = []
    for msg in request.messages:
        role = "user" if msg.role == "user" else "model"
        contents.append({
            "role": role,
            "parts": [{"text": msg.content}]
        })
    
    body = {
        "contents": contents,
        "generationConfig": {
            "temperature": request.temperature,
            "maxOutputTokens": request.max_tokens
        }
    }
    
    if request.enable_search:
        body["tools"] = [{"google_search": {}}]
    
    if request.include_thoughts:
        body["thinkingConfig"] = {"includeThoughts": True}
    
    async with client.stream("POST", url, json=body) as response:
        if response.status_code != 200:
            error_text = await response.aread()
            yield f'data: {{"error": "{error_text.decode()}"}}\n\n'
            return
        
        async for line in response.aiter_lines():
            if line.startswith("data: "):
                json_str = line[6:]
                try:
                    chunk = json.loads(json_str)
                    if "candidates" in chunk and chunk["candidates"]:
                        candidate = chunk["candidates"][0]
                        if "content" in candidate and "parts" in candidate["content"]:
                            for part in candidate["content"]["parts"]:
                                text = part.get("text", "")
                                is_thought = part.get("thought", False)
                                if text:
                                    yield f'data: {{"type": "{"thinking" if is_thought else "content"}", "data": {json.dumps(text)}}}\n\n'
                    
                    # Token 使用量
                    if "usageMetadata" in chunk:
                        usage = {
                            "prompt_tokens": chunk["usageMetadata"].get("promptTokenCount", 0),
                            "completion_tokens": chunk["usageMetadata"].get("candidatesTokenCount", 0),
                            "total_tokens": chunk["usageMetadata"].get("totalTokenCount", 0)
                        }
                        yield f'data: {{"type": "usage", "usage": {json.dumps(usage)}}}\n\n'
                except json.JSONDecodeError:
                    pass
    
    yield 'data: {"type": "done"}\n\n'


# ============== OpenAI API ==============

async def call_openai(
    client: httpx.AsyncClient,
    request: ChatRequest
) -> ChatResponse:
    """调用 OpenAI API（非流式）"""
    
    model = request.model or Config.DEFAULT_OPENAI_MODEL
    url = f"{Config.OPENAI_BASE_URL}/chat/completions"
    
    messages = []
    for msg in request.messages:
        messages.append({
            "role": msg.role if msg.role != "model" else "assistant",
            "content": msg.content
        })
    
    body = {
        "model": model,
        "messages": messages,
        "temperature": request.temperature,
        "max_tokens": request.max_tokens
    }
    
    headers = {
        "Authorization": f"Bearer {Config.OPENAI_API_KEY}",
        "Content-Type": "application/json"
    }
    
    response = await client.post(url, json=body, headers=headers)
    
    if response.status_code != 200:
        error_detail = response.text
        raise HTTPException(status_code=response.status_code, detail=error_detail)
    
    data = response.json()
    
    content = ""
    if "choices" in data and data["choices"]:
        content = data["choices"][0].get("message", {}).get("content", "")
    
    usage = None
    if "usage" in data:
        usage = {
            "prompt_tokens": data["usage"].get("prompt_tokens", 0),
            "completion_tokens": data["usage"].get("completion_tokens", 0),
            "total_tokens": data["usage"].get("total_tokens", 0)
        }
    
    return ChatResponse(content=content, usage=usage)


async def stream_openai(
    client: httpx.AsyncClient,
    request: ChatRequest
) -> AsyncGenerator[str, None]:
    """调用 OpenAI API（流式）"""
    
    model = request.model or Config.DEFAULT_OPENAI_MODEL
    url = f"{Config.OPENAI_BASE_URL}/chat/completions"
    
    messages = []
    for msg in request.messages:
        messages.append({
            "role": msg.role if msg.role != "model" else "assistant",
            "content": msg.content
        })
    
    body = {
        "model": model,
        "messages": messages,
        "temperature": request.temperature,
        "max_tokens": request.max_tokens,
        "stream": True
    }
    
    headers = {
        "Authorization": f"Bearer {Config.OPENAI_API_KEY}",
        "Content-Type": "application/json"
    }
    
    async with client.stream("POST", url, json=body, headers=headers) as response:
        if response.status_code != 200:
            error_text = await response.aread()
            yield f'data: {{"error": "{error_text.decode()}"}}\n\n'
            return
        
        async for line in response.aiter_lines():
            if line.startswith("data: "):
                json_str = line[6:]
                if json_str == "[DONE]":
                    break
                try:
                    chunk = json.loads(json_str)
                    if "choices" in chunk and chunk["choices"]:
                        delta = chunk["choices"][0].get("delta", {})
                        text = delta.get("content", "")
                        if text:
                            yield f'data: {{"type": "content", "data": {json.dumps(text)}}}\n\n'
                except json.JSONDecodeError:
                    pass
    
    yield 'data: {"type": "done"}\n\n'


# ============== 公共 API 路由 ==============

@app.get("/")
async def root():
    """根路径"""
    return {
        "status": "ok",
        "service": "HaruChat API",
        "version": "2.0.0",
        "features": ["chat", "users", "sessions", "messages"]
    }


@app.get("/health")
async def health():
    """健康检查"""
    return {"status": "healthy"}


@app.get("/api/models", response_model=dict)
async def get_models():
    """获取可用模型列表"""
    return {
        "gemini": {
            "models": ["gemini-2.5-flash", "gemini-2.5-pro", "gemini-2.0-flash"],
            "default": Config.DEFAULT_GEMINI_MODEL
        },
        "openai": {
            "models": ["gpt-4o", "gpt-4o-mini", "gpt-4-turbo", "gpt-3.5-turbo"],
            "default": Config.DEFAULT_OPENAI_MODEL
        }
    }


@app.post("/api/chat", response_model=ChatResponse)
async def chat(request: ChatRequest):
    """非流式聊天接口（无需登录）"""
    
    # 统一转换为小写
    provider = request.provider.lower()
    
    async with get_http_client() as client:
        if provider == "gemini":
            if not Config.GEMINI_API_KEY:
                raise HTTPException(status_code=500, detail="Gemini API Key 未配置")
            return await call_gemini(client, request)
        
        elif provider == "openai":
            if not Config.OPENAI_API_KEY:
                raise HTTPException(status_code=500, detail="OpenAI API Key 未配置")
            return await call_openai(client, request)
        
        else:
            raise HTTPException(status_code=400, detail=f"不支持的供应商: {request.provider}")


@app.post("/api/chat/stream")
async def chat_stream(request: ChatRequest):
    """流式聊天接口（无需登录）"""
    
    # 统一转换为小写
    provider = request.provider.lower()
    
    async def generate():
        async with get_http_client() as client:
            if provider == "gemini":
                if not Config.GEMINI_API_KEY:
                    yield 'data: {"error": "Gemini API Key 未配置"}\n\n'
                    return
                async for chunk in stream_gemini(client, request):
                    yield chunk
            
            elif provider == "openai":
                if not Config.OPENAI_API_KEY:
                    yield 'data: {"error": "OpenAI API Key 未配置"}\n\n'
                    return
                async for chunk in stream_openai(client, request):
                    yield chunk
            
            else:
                yield f'data: {{"error": "不支持的供应商: {request.provider}"}}\n\n'
    
    return StreamingResponse(
        generate(),
        media_type="text/event-stream",
        headers={
            "Cache-Control": "no-cache",
            "Connection": "keep-alive",
            "X-Accel-Buffering": "no",  # 禁用 Nginx 缓冲
        }
    )


# ============== 启动 ==============

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True
    )
