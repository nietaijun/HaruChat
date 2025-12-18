'use client'

import { useState, useRef, useEffect } from 'react'
import { ChatMessage } from '@/components/ChatMessage'
import { ChatInput } from '@/components/ChatInput'
import { Sidebar } from '@/components/Sidebar'
import { Settings } from '@/components/Settings'
import { Menu, Settings as SettingsIcon, Plus } from 'lucide-react'

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

export default function Home() {
  const [sessions, setSessions] = useState<ChatSession[]>([])
  const [currentSessionId, setCurrentSessionId] = useState<string | null>(null)
  const [isLoading, setIsLoading] = useState(false)
  const [streamingContent, setStreamingContent] = useState('')
  const [streamingThinking, setStreamingThinking] = useState('')
  const [showSidebar, setShowSidebar] = useState(true)
  const [showSettings, setShowSettings] = useState(false)
  const [provider, setProvider] = useState<'gemini' | 'openai'>('gemini')
  const [model, setModel] = useState('gemini-2.5-flash')
  
  const messagesEndRef = useRef<HTMLDivElement>(null)
  const API_URL = process.env.API_URL || 'https://www.nietaijun.cloud'

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

    // 更新会话
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
          provider,
          model,
          messages: updatedMessages.map(m => ({ role: m.role, content: m.content })),
          temperature: 0.7,
          max_tokens: 4096,
          stream: true,
          enable_search: false,
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
              if (data.type === 'content' && data.text) {
                fullContent += data.text
                setStreamingContent(fullContent)
              } else if (data.type === 'thinking' && data.text) {
                fullThinking += data.text
                setStreamingThinking(fullThinking)
              }
            } catch {}
          }
        }
      }

      // 添加助手消息
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

  return (
    <div className="flex h-screen bg-gray-50 dark:bg-gray-900">
      {/* 侧边栏 */}
      <Sidebar
        sessions={sessions}
        currentSessionId={currentSessionId}
        onSelectSession={setCurrentSessionId}
        onNewSession={createNewSession}
        onDeleteSession={deleteSession}
        isOpen={showSidebar}
        onClose={() => setShowSidebar(false)}
      />

      {/* 主内容区 */}
      <div className="flex-1 flex flex-col">
        {/* 顶部栏 */}
        <header className="h-14 border-b border-gray-200 dark:border-gray-700 flex items-center px-4 gap-4 bg-white dark:bg-gray-800">
          <button
            onClick={() => setShowSidebar(!showSidebar)}
            className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg lg:hidden"
          >
            <Menu size={20} />
          </button>
          
          <div className="flex-1 flex items-center justify-center gap-2">
            <span className="text-sm font-medium text-primary-600">{provider === 'gemini' ? 'Gemini' : 'ChatGPT'}</span>
            <span className="text-xs text-gray-500">{model}</span>
          </div>

          <button
            onClick={createNewSession}
            className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg"
          >
            <Plus size={20} />
          </button>
          <button
            onClick={() => setShowSettings(true)}
            className="p-2 hover:bg-gray-100 dark:hover:bg-gray-700 rounded-lg"
          >
            <SettingsIcon size={20} />
          </button>
        </header>

        {/* 消息区域 */}
        <main className="flex-1 overflow-y-auto">
          {currentSession?.messages.length || streamingContent ? (
            <div className="max-w-3xl mx-auto py-4">
              {currentSession?.messages.map((message) => (
                <ChatMessage key={message.id} message={message} />
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
                  isStreaming
                />
              )}
              <div ref={messagesEndRef} />
            </div>
          ) : (
            <div className="flex-1 flex flex-col items-center justify-center h-full">
              <div className="w-16 h-16 rounded-full bg-gradient-to-br from-primary-400 to-primary-600 flex items-center justify-center mb-6">
                <span className="text-3xl">🌸</span>
              </div>
              <h1 className="text-2xl font-semibold mb-2">HaruChat</h1>
              <p className="text-gray-500 dark:text-gray-400">有什么可以帮你的？</p>
            </div>
          )}
        </main>

        {/* 输入区域 */}
        <ChatInput onSend={sendMessage} isLoading={isLoading} />
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

