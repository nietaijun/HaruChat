'use client'

import { useState, useRef, useEffect } from 'react'
import { Send, Square, Globe, Paperclip } from 'lucide-react'

interface ChatInputProps {
  onSend: (content: string) => void
  isLoading: boolean
}

export function ChatInput({ onSend, isLoading }: ChatInputProps) {
  const [input, setInput] = useState('')
  const [enableSearch, setEnableSearch] = useState(false)
  const [isFocused, setIsFocused] = useState(false)
  const textareaRef = useRef<HTMLTextAreaElement>(null)

  // 自动调整高度
  useEffect(() => {
    if (textareaRef.current) {
      textareaRef.current.style.height = 'auto'
      textareaRef.current.style.height = `${Math.min(textareaRef.current.scrollHeight, 160)}px`
    }
  }, [input])

  const handleSubmit = () => {
    if (input.trim() && !isLoading) {
      onSend(input.trim())
      setInput('')
      // 重置高度
      if (textareaRef.current) {
        textareaRef.current.style.height = 'auto'
      }
    }
  }

  const handleKeyDown = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault()
      handleSubmit()
    }
  }

  const canSend = input.trim() && !isLoading

  return (
    <div className="border-t border-gray-200/60 dark:border-gray-800 bg-white/80 dark:bg-[#1a1a1a]/80 backdrop-blur-md px-4 py-3">
      <div className="max-w-3xl mx-auto">
        {/* 输入区域容器 */}
        <div 
          className={`flex items-end gap-2 p-2 rounded-2xl bg-gray-50 dark:bg-[#252525] border transition-all duration-200 ${
            isFocused 
              ? 'border-primary-400 dark:border-primary-500 shadow-glow' 
              : 'border-gray-200/60 dark:border-gray-700/60'
          }`}
        >
          {/* 左侧功能按钮 */}
          <div className="flex items-center gap-1 pb-1.5">
            {/* 搜索按钮 */}
            <button
              onClick={() => setEnableSearch(!enableSearch)}
              className={`p-2 rounded-xl transition-all btn-bounce ${
                enableSearch 
                  ? 'bg-blue-100 dark:bg-blue-900/40 text-blue-600 dark:text-blue-400' 
                  : 'text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700'
              }`}
              title="联网搜索"
            >
              <Globe size={18} />
            </button>
            
            {/* 附件按钮 */}
            <button
              className="p-2 rounded-xl text-gray-400 hover:text-gray-600 dark:hover:text-gray-300 hover:bg-gray-100 dark:hover:bg-gray-700 transition-all btn-bounce"
              title="添加附件"
            >
              <Paperclip size={18} />
            </button>
          </div>

          {/* 输入框 */}
          <textarea
            ref={textareaRef}
            value={input}
            onChange={(e) => setInput(e.target.value)}
            onKeyDown={handleKeyDown}
            onFocus={() => setIsFocused(true)}
            onBlur={() => setIsFocused(false)}
            placeholder="输入消息..."
            rows={1}
            className="flex-1 bg-transparent px-2 py-2.5 text-gray-900 dark:text-white placeholder-gray-400 resize-none outline-none text-[15px] leading-relaxed"
            style={{ minHeight: '44px', maxHeight: '160px' }}
            disabled={isLoading}
          />

          {/* 发送按钮 */}
          <div className="pb-1.5">
            <button
              onClick={handleSubmit}
              disabled={!canSend}
              className={`p-2.5 rounded-xl transition-all btn-bounce ${
                canSend
                  ? 'bg-gradient-to-br from-primary-500 to-primary-600 text-white shadow-glow hover:shadow-lg'
                  : 'bg-gray-200 dark:bg-gray-700 text-gray-400'
              }`}
            >
              {isLoading ? (
                <Square size={18} />
              ) : (
                <Send size={18} />
              )}
            </button>
          </div>
        </div>

        {/* 底部提示 */}
        <div className="flex items-center justify-center gap-2 mt-2">
          {enableSearch && (
            <span className="text-xs text-blue-500 dark:text-blue-400 flex items-center gap-1">
              <Globe size={12} />
              已启用联网搜索
            </span>
          )}
          <p className="text-xs text-gray-400">
            HaruChat · 按 Enter 发送，Shift+Enter 换行
          </p>
        </div>
      </div>
    </div>
  )
}
