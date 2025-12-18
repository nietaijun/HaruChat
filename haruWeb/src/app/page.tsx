'use client'

import { useState, useRef, useEffect } from 'react'
import { ChatMessage } from '@/components/ChatMessage'
import { ChatInput } from '@/components/ChatInput'
import { Sidebar } from '@/components/Sidebar'
import { Settings } from '@/components/Settings'
import { ProviderIcon } from '@/components/ProviderIcon'
import { Menu, Settings as SettingsIcon, Plus, ChevronDown } from 'lucide-react'

export interface Message {
  id: string
  role: 'user' | 'assistant'
  content: string
  thinking?: string
  timestamp: Date
}

export interface ChatSession {
  id: string
  title: string
  messages: Message[]
  updatedAt: Date
}

export type Provider = 'gemini' | 'openai'

export default function Home() {
  const [sessions, setSessions] = useState<ChatSession[]>([])
  const [currentSessionId, setCurrentSessionId] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [streamingContent, setStreamingContent] = useState('')
  const [streamingThinking, setStreamingThinking] = useState('')
  const [showSidebar, setShowSidebar] = useState(true)
  const [showSettings, setShowSettings] = useState(false)
  const [showModelPicker, setShowModelPicker] = useState(false)
  const [provider, setProvider] = useState<Provider>('gemini')
  const [model, setModel] = useState('gemini-2.5-flash')
  
  const messagesEndRef = useRef<HTMLDivElement>(null)
  const API_URL = process.env.NEXT_PUBLIC_API_URL || 'https://www.nietaijun.cloud'

  const currentSession = sessions.find(s => s.id === currentSessionId)

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' })
  }

  useEffect(() => {
    scrollToBottom()
  }, [currentSession?.messages, streamingContent])

  // 创建新会话
  const createNewSession = () => {
    const newSession: ChatSession = {
      id: Date.now().toString(),
      title: '新对话',
      messages: [],
      updatedAt: new Date(),
    }
    setSessions([newSession, ...sessions])
    setCurrentSessionId(newSession.id)
  }

  // 发送消息
  const sendMessage = async (content: string) => {
    if (!content.trim() || isLoading) return

    let session = currentSession
    if (!session) {
      const newSession: ChatSession = {
        id: Date.now().toString(),
        title: content.slice(0, 20) + (content.length > 20 ? '...' : ''),
        messages: [],
        updatedAt: new Date(),
      }
      setSessions([newSession, ...sessions])
      setCurrentSessionId(newSession.id)
      session = newSession
    }

    const userMessage: Message = {
      id: Date.now().toString(),
      role: 'user',
      content,
      timestamp: new Date(),
    }

    const updatedMessages = [...(session?.messages || []), userMessage]
    setSessions(prev => prev.map(s => 
      s.id === session!.id 
        ? { ...s, messages: updatedMessages, updatedAt: new Date(), title: s.messages.length === 0 ? content.slice(0, 20) : s.title }
        : s
    ))

    setIsLoading(true)
    setStreamingContent('')
    setStreamingThinking('')

    try {
      const response = await fetch(`${API_URL}/api/chat/stream`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          provider: provider === 'gemini' ? 'Gemini' : 'OpenAI',
          model,
          messages: updatedMessages.map(m => ({ role: m.role, content: m.content })),
          temperature: 0.7,
          max_tokens: 4096,
          stream: true,
          enable_google_search: false,
          include_thoughts: provider === 'gemini',
        }),
      })

      const reader = response.body?.getReader()
      const decoder = new TextDecoder()
      let fullContent = ''
      let fullThinking = ''

      while (reader) {
        const { done, value } = await reader.read()
        if (done) break

        const chunk = decoder.decode(value)
        const lines = chunk.split('\n')

        for (const line of lines) {
          if (line.startsWith('data: ')) {
            try {
              const data = JSON.parse(line.slice(6))
              if (data.type === 'content' && data.data) {
                fullContent += data.data
                setStreamingContent(fullContent)
              } else if (data.type === 'thinking' && data.data) {
                fullThinking += data.data
                setStreamingThinking(fullThinking)
              }
            } catch {}
          }
        }
      }

      if (fullContent) {
        const assistantMessage: Message = {
          id: Date.now().toString(),
          role: 'assistant',
          content: fullContent,
          thinking: fullThinking || undefined,
          timestamp: new Date(),
        }
        setSessions(prev => prev.map(s => 
          s.id === session!.id 
            ? { ...s, messages: [...updatedMessages, assistantMessage], updatedAt: new Date() }
            : s
        ))
      }
    } catch (error) {
      console.error('Error:', error)
    } finally {
      setIsLoading(false)
      setStreamingContent('')
      setStreamingThinking('')
    }
  }

  // 删除会话
  const deleteSession = (id: string) => {
    setSessions(prev => prev.filter(s => s.id !== id))
    if (currentSessionId === id) {
      setCurrentSessionId(null)
    }
  }

  const MODELS = {
    gemini: ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-2.0-flash', 'gemini-1.5-pro'],
    openai: ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo'],
  }

  return (
    <div className="flex h-screen bg-[#f8fafb] dark:bg-[#0f0f0f]">
      {/* 侧边栏 */}
      <Sidebar
        sessions={sessions}
        currentSessionId={currentSessionId}
        onSelectSession={setCurrentSessionId}
        onNewSession={createNewSession}
        onDeleteSession={deleteSession}
        isOpen={showSidebar}
        onClose={() => setShowSidebar(false)}
        onOpenSettings={() => setShowSettings(true)}
      />

      {/* 主内容区 */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* 顶部栏 */}
        <header className="h-14 flex items-center justify-between px-4 border-b border-gray-200/60 dark:border-gray-800 bg-white/80 dark:bg-[#1a1a1a]/80 backdrop-blur-md">
          {/* 左侧：菜单按钮 */}
          <button
            onClick={() => setShowSidebar(!showSidebar)}
            className="p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-xl transition-colors lg:hidden"
          >
            <Menu size={20} className="text-gray-600 dark:text-gray-400" />
          </button>
          
          {/* 中间：模型选择器 */}
          <div className="relative">
            <button
              onClick={() => setShowModelPicker(!showModelPicker)}
              className="flex items-center gap-2 px-3 py-1.5 rounded-full bg-gray-100/80 dark:bg-gray-800/80 hover:bg-gray-200/80 dark:hover:bg-gray-700/80 transition-all btn-bounce"
            >
              <ProviderIcon provider={provider} size={18} />
              <span className="text-sm font-medium text-gray-700 dark:text-gray-300 max-w-[120px] truncate">
                {model}
              </span>
              <ChevronDown size={14} className="text-gray-400" />
            </button>

            {/* 模型选择下拉 */}
            {showModelPicker && (
              <>
                <div 
                  className="fixed inset-0 z-40" 
                  onClick={() => setShowModelPicker(false)} 
                />
                <div className="absolute top-full left-1/2 -translate-x-1/2 mt-2 w-72 bg-white dark:bg-[#1e1e1e] rounded-2xl shadow-soft border border-gray-200/60 dark:border-gray-700/60 z-50 overflow-hidden animate-slide-up">
                  {/* 供应商切换 */}
                  <div className="p-3 border-b border-gray-100 dark:border-gray-800">
                    <div className="flex gap-2">
                      {(['gemini', 'openai'] as Provider[]).map((p) => (
                        <button
                          key={p}
                          onClick={() => {
                            setProvider(p)
                            setModel(MODELS[p][0])
                          }}
                          className={`flex-1 flex items-center justify-center gap-2 py-2 px-3 rounded-xl transition-all btn-bounce ${
                            provider === p
                              ? 'bg-primary-50 dark:bg-primary-900/30 text-primary-600 dark:text-primary-400'
                              : 'hover:bg-gray-100 dark:hover:bg-gray-800 text-gray-600 dark:text-gray-400'
                          }`}
                        >
                          <ProviderIcon provider={p} size={20} />
                          <span className="font-medium text-sm">
                            {p === 'gemini' ? 'Gemini' : 'OpenAI'}
                          </span>
                        </button>
                      ))}
                    </div>
                  </div>
                  
                  {/* 模型列表 */}
                  <div className="max-h-64 overflow-y-auto p-2">
                    {MODELS[provider].map((m) => (
                      <button
                        key={m}
                        onClick={() => {
                          setModel(m)
                          setShowModelPicker(false)
                        }}
                        className={`w-full flex items-center justify-between px-3 py-2.5 rounded-xl transition-all ${
                          model === m
                            ? 'bg-primary-50 dark:bg-primary-900/30'
                            : 'hover:bg-gray-100 dark:hover:bg-gray-800'
                        }`}
                      >
                        <span className={`text-sm ${model === m ? 'text-primary-600 dark:text-primary-400 font-medium' : 'text-gray-700 dark:text-gray-300'}`}>
                          {m}
                        </span>
                        {model === m && (
                          <div className="w-2 h-2 rounded-full bg-primary-500" />
                        )}
                      </button>
                    ))}
                  </div>
                </div>
              </>
            )}
          </div>

          {/* 右侧：操作按钮 */}
          <div className="flex items-center gap-2">
            <button
              onClick={createNewSession}
              className="p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-xl transition-colors btn-bounce"
            >
              <Plus size={20} className="text-primary-500" />
            </button>
            <button
              onClick={() => setShowSettings(true)}
              className="p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-xl transition-colors btn-bounce"
            >
              <SettingsIcon size={20} className="text-gray-500 dark:text-gray-400" />
            </button>
          </div>
        </header>

        {/* 消息区域 */}
        <main className="flex-1 overflow-y-auto">
          {currentSession?.messages.length || streamingContent ? (
            <div className="max-w-3xl mx-auto py-6 px-4">
              {currentSession?.messages.map((message, index) => (
                <ChatMessage 
                  key={message.id} 
                  message={message} 
                  provider={provider}
                  isLast={index === currentSession.messages.length - 1 && !streamingContent}
                />
              ))}
              {streamingContent && (
                <ChatMessage
                  message={{
                    id: 'streaming',
                    role: 'assistant',
                    content: streamingContent,
                    thinking: streamingThinking,
                    timestamp: new Date(),
                  }}
                  provider={provider}
                  isStreaming
                />
              )}
              <div ref={messagesEndRef} className="h-4" />
            </div>
          ) : (
            <WelcomeView 
              provider={provider} 
              onSend={sendMessage}
              isLoading={isLoading}
            />
          )}
        </main>

        {/* 输入区域 - 仅在有对话时显示 */}
        {(currentSession?.messages.length || streamingContent) ? (
          <ChatInput onSend={sendMessage} isLoading={isLoading} />
        ) : null}
      </div>

      {/* 设置面板 */}
      <Settings
        isOpen={showSettings}
        onClose={() => setShowSettings(false)}
        provider={provider}
        setProvider={setProvider}
        model={model}
        setModel={setModel}
      />
    </div>
  )
}

// 欢迎视图组件
function WelcomeView({ 
  provider, 
  onSend, 
  isLoading 
}: { 
  provider: Provider
  onSend: (content: string) => void
  isLoading: boolean 
}) {
  const [input, setInput] = useState('')
  
  const handleSubmit = () => {
    if (input.trim() && !isLoading) {
      onSend(input.trim())
      setInput('')
    }
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSubmit()
    }
  }

  return (
    <div className="flex-1 flex flex-col items-center justify-center h-full px-4">
      {/* Logo 和欢迎语 */}
      <div className="flex flex-col items-center mb-8 animate-fade-in">
        {/* Provider 图标 */}
        <div className={`w-20 h-20 rounded-full flex items-center justify-center mb-6 ${
          provider === 'gemini' ? 'gemini-gradient' : 'openai-gradient'
        }`}>
          <ProviderIcon provider={provider} size={48} />
        </div>
        
        {/* 欢迎文字 */}
        <h1 className="text-2xl font-semibold text-gray-900 dark:text-white mb-2">
          你好，有什么可以帮你的？
        </h1>
        <p className="text-gray-500 dark:text-gray-400">
          输入消息开始新的对话
        </p>
      </div>

      {/* 输入框 */}
      <div className="w-full max-w-2xl animate-slide-up">
        <div className={`flex items-end gap-2 p-2 rounded-2xl bg-white dark:bg-[#1e1e1e] border border-gray-200/60 dark:border-gray-700/60 shadow-soft transition-all input-glow`}>
          <textarea
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            placeholder="输入消息开始对话..."
            rows={1}
            className="flex-1 bg-transparent px-3 py-2.5 text-gray-900 dark:text-white placeholder-gray-400 resize-none outline-none text-[15px] max-h-32"
            style={{ minHeight: '44px' }}
          />
          <button
            onClick={handleSubmit}
            disabled={!input.trim() || isLoading}
            className={`shrink-0 w-10 h-10 rounded-xl flex items-center justify-center transition-all btn-bounce ${
              input.trim() && !isLoading
                ? 'bg-gradient-to-br from-primary-500 to-primary-600 text-white shadow-glow'
                : 'bg-gray-100 dark:bg-gray-800 text-gray-400'
            }`}
          >
            <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
              <path d="M12 19V5M5 12l7-7 7 7" />
            </svg>
          </button>
        </div>
        
        {/* 底部提示 */}
        <p className="text-center text-xs text-gray-400 mt-4">
          HaruChat · Powered by {provider === 'gemini' ? 'Google Gemini' : 'OpenAI'}
        </p>
      </div>
    </div>
  )
}
