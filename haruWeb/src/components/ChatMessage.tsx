'use client'

import { useState } from 'react'
import ReactMarkdown from 'react-markdown'
import { Prism as SyntaxHighlighter } from 'react-syntax-highlighter'
import { oneDark } from 'react-syntax-highlighter/dist/esm/styles/prism'
import { Copy, Check, ChevronDown, ChevronRight, Brain } from 'lucide-react'
import type { Message } from '@/app/page'

interface ChatMessageProps {
  message: Message
  isStreaming?: boolean
}

export function ChatMessage({ message, isStreaming }: ChatMessageProps) {
  const [copiedCode, setCopiedCode] = useState<string | null>(null)
  const [showThinking, setShowThinking] = useState(false)
  const isUser = message.role === 'user'

  const copyToClipboard = (code: string) => {
    navigator.clipboard.writeText(code)
    setCopiedCode(code)
    setTimeout(() => setCopiedCode(null), 2000)
  }

  if (isUser) {
    return (
      <div className="flex justify-end px-4 py-2">
        <div className="max-w-[80%] bg-primary-500 text-white rounded-2xl rounded-tr-sm px-4 py-3">
          <p className="whitespace-pre-wrap">{message.content}</p>
        </div>
      </div>
    )
  }

  return (
    <div className="px-4 py-4 bg-gray-50 dark:bg-gray-800/50">
      <div className="max-w-3xl mx-auto">
        {/* 头像和名称 */}
        <div className="flex items-center gap-3 mb-3">
          <div className="w-8 h-8 rounded-full bg-gradient-to-br from-blue-400 to-red-400 flex items-center justify-center">
            <span className="text-white text-sm font-bold">G</span>
          </div>
          <span className="font-medium text-sm">Gemini</span>
          {isStreaming && (
            <span className="text-xs text-gray-500 animate-pulse">生成中...</span>
          )}
        </div>

        {/* 思考过程 */}
        {message.thinking && (
          <div className="mb-3">
            <button
              onClick={() => setShowThinking(!showThinking)}
              className="flex items-center gap-2 text-sm text-purple-600 dark:text-purple-400 hover:underline"
            >
              <Brain size={16} />
              <span>思考过程</span>
              {showThinking ? <ChevronDown size={14} /> : <ChevronRight size={14} />}
            </button>
            {showThinking && (
              <div className="mt-2 p-3 bg-purple-50 dark:bg-purple-900/20 rounded-lg border border-purple-200 dark:border-purple-800">
                <p className="text-sm text-purple-800 dark:text-purple-200 whitespace-pre-wrap">
                  {message.thinking}
                </p>
              </div>
            )}
          </div>
        )}

        {/* 消息内容 */}
        <div className={`prose dark:prose-invert max-w-none ${isStreaming ? 'typing-cursor' : ''}`}>
          <ReactMarkdown
            components={{
              code({ node, inline, className, children, ...props }: any) {
                const match = /language-(\w+)/.exec(className || '')
                const code = String(children).replace(/\n$/, '')
                
                if (!inline && match) {
                  return (
                    <div className="relative group">
                      <div className="absolute right-2 top-2 opacity-0 group-hover:opacity-100 transition-opacity">
                        <button
                          onClick={() => copyToClipboard(code)}
                          className="p-1.5 bg-gray-700 hover:bg-gray-600 rounded text-white"
                        >
                          {copiedCode === code ? <Check size={14} /> : <Copy size={14} />}
                        </button>
                      </div>
                      <SyntaxHighlighter
                        style={oneDark}
                        language={match[1]}
                        PreTag="div"
                        {...props}
                      >
                        {code}
                      </SyntaxHighlighter>
                    </div>
                  )
                }
                return (
                  <code className={className} {...props}>
                    {children}
                  </code>
                )
              },
            }}
          >
            {message.content}
          </ReactMarkdown>
        </div>

        {/* 操作按钮 */}
        {!isStreaming && (
          <div className="flex items-center gap-2 mt-3 opacity-0 hover:opacity-100 transition-opacity">
            <button
              onClick={() => copyToClipboard(message.content)}
              className="p-1.5 hover:bg-gray-200 dark:hover:bg-gray-700 rounded text-gray-500"
            >
              {copiedCode === message.content ? <Check size={16} /> : <Copy size={16} />}
            </button>
          </div>
        )}
      </div>
    </div>
  )
}

