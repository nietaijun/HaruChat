'use client'

import { useState } from 'react'
import ReactMarkdown from 'react-markdown'
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter'
import { oneDark } from 'react-syntax-highlighter/dist/esm/styles/prism'
import { Copy, Check, ChevronDown, ChevronRight, Brain, RefreshCw, ThumbsUp, ThumbsDown, Volume2 } from 'lucide-react'
import type { Message, Provider } from '@/app/page'
import { ProviderIcon } from './ProviderIcon'

interface ChatMessageProps {
  message: Message
  provider: Provider
  isStreaming?: boolean
  isLast?: boolean
}

export function ChatMessage({ message, provider, isStreaming, isLast }: ChatMessageProps) {
  const [copiedCode, setCopiedCode] = useState<string | null>(null)
  const [showThinking, setShowThinking] = useState(false)
  const isUser = message.role === 'user'

  const copyToClipboard = (code: string) => {
    navigator.clipboard.writeText(code)
    setCopiedCode(code)
    setTimeout(() => setCopiedCode(null), 2000)
  }

  // 用户消息
  if (isUser) {
    return (
      <div className="flex justify-end mb-4 animate-slide-up">
        <div className="max-w-[85%] md:max-w-[75%]">
          <div className="user-message-gradient text-white rounded-2xl rounded-tr-md px-4 py-3 shadow-soft">
            <p className="whitespace-pre-wrap text-[15px] leading-relaxed">{message.content}</p>
          </div>
          <div className="flex justify-end mt-1">
            <span className="text-xs text-gray-400">
              {message.timestamp.toLocaleTimeString('zh-CN', { hour: '2-digit', minute: '2-digit' })}
            </span>
          </div>
        </div>
      </div>
    )
  }

  // AI 消息 - Gemini 风格（无气泡）
  return (
    <div className="mb-6 animate-slide-up">
      {/* 头像和模型名称 */}
      <div className="flex items-center gap-3 mb-3">
        <div className={`w-8 h-8 rounded-full flex items-center justify-center ${
          provider === 'gemini' ? 'gemini-gradient' : 'openai-gradient'
        }`}>
          <ProviderIcon provider={provider} size={20} />
        </div>
        <span className="font-medium text-sm text-gray-700 dark:text-gray-300">
          {provider === 'gemini' ? 'Gemini' : 'ChatGPT'}
        </span>
        {isStreaming && (
          <div className="loading-dots">
            <span></span>
            <span></span>
            <span></span>
          </div>
        )}
      </div>

      {/* 思考过程 */}
      {message.thinking && (
        <div className="mb-4 ml-11">
          <button
            onClick={() => setShowThinking(!showThinking)}
            className="flex items-center gap-2 text-sm text-purple-600 dark:text-purple-400 hover:text-purple-700 dark:hover:text-purple-300 transition-colors"
          >
            <Brain size={16} />
            <span>思考过程</span>
            {showThinking ? <ChevronDown size={14} /> : <ChevronRight size={14} />}
          </button>
          
          <div className={`overflow-hidden transition-all duration-300 ${showThinking ? 'max-h-96 opacity-100 mt-2' : 'max-h-0 opacity-0'}`}>
            <div className="thinking-bubble rounded-xl p-4 overflow-y-auto max-h-64">
              <p className="text-sm text-purple-800 dark:text-purple-200 whitespace-pre-wrap leading-relaxed">
                {message.thinking}
              </p>
            </div>
          </div>
        </div>
      )}

      {/* 消息内容 */}
      <div className={`ml-11 prose prose-gray dark:prose-invert max-w-none prose-p:leading-relaxed prose-pre:my-3 ${isStreaming ? 'typing-cursor' : ''}`}>
        <ReactMarkdown
          components={{
            code({ node, inline, className, children, ...props }: any) {
              const match = /language-(\w+)/.exec(className || '')
              const code = String(children).replace(/\n$/, '')
              
              if (!inline && match) {
                return (
                  <div className="relative group rounded-xl overflow-hidden my-3">
                    {/* 代码块头部 */}
                    <div className="flex items-center justify-between px-4 py-2 bg-[#2d2d2d] border-b border-gray-700">
                      <span className="text-xs text-gray-400 font-medium">{match[1]}</span>
                      <button
                        onClick={() => copyToClipboard(code)}
                        className="flex items-center gap-1.5 px-2 py-1 text-xs text-gray-400 hover:text-white hover:bg-gray-700 rounded transition-colors"
                      >
                        {copiedCode === code ? (
                          <>
                            <Check size={12} />
                            <span>已复制</span>
                          </>
                        ) : (
                          <>
                            <Copy size={12} />
                            <span>复制</span>
                          </>
                        )}
                      </button>
                    </div>
                    <SyntaxHighlighter
                      style={oneDark}
                      language={match[1]}
                      PreTag="div"
                      customStyle={{
                        margin: 0,
                        borderRadius: 0,
                        padding: '16px',
                        fontSize: '13px',
                      }}
                      {...props}
                    >
                      {code}
                    </SyntaxHighlighter>
                  </div>
                )
              }
              return (
                <code className="px-1.5 py-0.5 bg-primary-100 dark:bg-primary-900/30 text-primary-700 dark:text-primary-300 rounded text-sm font-mono" {...props}>
                  {children}
                </code>
              )
            },
            // 自定义链接样式
            a({ href, children }) {
              return (
                <a 
                  href={href} 
                  target="_blank" 
                  rel="noopener noreferrer"
                  className="text-primary-600 dark:text-primary-400 hover:underline"
                >
                  {children}
                </a>
              )
            },
            // 自定义段落
            p({ children }) {
              return <p className="mb-3 last:mb-0 text-[15px]">{children}</p>
            },
            // 自定义列表
            ul({ children }) {
              return <ul className="list-disc list-inside space-y-1 mb-3">{children}</ul>
            },
            ol({ children }) {
              return <ol className="list-decimal list-inside space-y-1 mb-3">{children}</ol>
            },
          }}
        >
          {message.content}
        </ReactMarkdown>
      </div>

      {/* 操作按钮 - 仅在非流式状态下显示 */}
      {!isStreaming && isLast && (
        <div className="flex items-center gap-1 mt-3 ml-11">
          <ActionButton 
            icon={<Copy size={14} />} 
            label="复制"
            onClick={() => copyToClipboard(message.content)}
            active={copiedCode === message.content}
            activeIcon={<Check size={14} />}
          />
          <ActionButton 
            icon={<RefreshCw size={14} />} 
            label="重新生成"
            onClick={() => {}}
          />
          <ActionButton 
            icon={<Volume2 size={14} />} 
            label="朗读"
            onClick={() => {}}
          />
          <div className="w-px h-4 bg-gray-200 dark:bg-gray-700 mx-1" />
          <ActionButton 
            icon={<ThumbsUp size={14} />} 
            label="有帮助"
            onClick={() => {}}
          />
          <ActionButton 
            icon={<ThumbsDown size={14} />} 
            label="没帮助"
            onClick={() => {}}
          />
        </div>
      )}
    </div>
  )
}

// 操作按钮组件
function ActionButton({ 
  icon, 
  label, 
  onClick, 
  active,
  activeIcon 
}: { 
  icon: React.ReactNode
  label: string
  onClick: () => void
  active?: boolean
  activeIcon?: React.ReactNode
}) {
  return (
    <button
      onClick={onClick}
      className={`p-2 rounded-lg transition-all hover:bg-gray-100 dark:hover:bg-gray-800 group ${
        active ? 'text-primary-500' : 'text-gray-400 hover:text-gray-600 dark:hover:text-gray-300'
      }`}
      title={label}
    >
      {active && activeIcon ? activeIcon : icon}
    </button>
  )
}
