'use client'

import { Plus, MessageSquare, Trash2, X } from 'lucide-react'
import type { ChatSession } from '@/app/page'

interface SidebarProps {
  sessions: ChatSession[]
  currentSessionId: string | null
  onSelectSession: (id: string) => void
  onNewSession: () => void
  onDeleteSession: (id: string) => void
  isOpen: boolean
  onClose: () => void
}

export function Sidebar({
  sessions,
  currentSessionId,
  onSelectSession,
  onNewSession,
  onDeleteSession,
  isOpen,
  onClose,
}: SidebarProps) {
  return (
    <>
      {/* 遮罩 */}
      {isOpen && (
        <div
          className="fixed inset-0 bg-black/50 z-40 lg:hidden"
          onClick={onClose}
        />
      )}

      {/* 侧边栏 */}
      <aside
        className={`fixed lg:relative inset-y-0 left-0 z-50 w-72 bg-gray-900 text-white flex flex-col transform transition-transform lg:transform-none ${
          isOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        {/* 头部 */}
        <div className="p-4 flex items-center justify-between">
          <div className="flex items-center gap-2">
            <div className="w-8 h-8 rounded-lg bg-gradient-to-br from-primary-400 to-primary-600 flex items-center justify-center">
              <span className="text-lg">🌸</span>
            </div>
            <span className="font-semibold text-lg">HaruChat</span>
          </div>
          <button
            onClick={onClose}
            className="p-1 hover:bg-gray-800 rounded lg:hidden"
          >
            <X size={20} />
          </button>
        </div>

        {/* 新建按钮 */}
        <div className="px-3 pb-4">
          <button
            onClick={onNewSession}
            className="w-full flex items-center gap-2 px-4 py-3 bg-gray-800 hover:bg-gray-700 rounded-lg transition-colors"
          >
            <Plus size={18} />
            <span>新建对话</span>
          </button>
        </div>

        {/* 会话列表 */}
        <div className="flex-1 overflow-y-auto px-3 space-y-1">
          {sessions.map((session) => (
            <div
              key={session.id}
              className={`group flex items-center gap-2 px-3 py-2.5 rounded-lg cursor-pointer transition-colors ${
                currentSessionId === session.id
                  ? 'bg-gray-700'
                  : 'hover:bg-gray-800'
              }`}
              onClick={() => onSelectSession(session.id)}
            >
              <MessageSquare size={16} className="shrink-0 text-gray-400" />
              <span className="flex-1 truncate text-sm">{session.title}</span>
              <button
                onClick={(e) => {
                  e.stopPropagation()
                  onDeleteSession(session.id)
                }}
                className="opacity-0 group-hover:opacity-100 p-1 hover:bg-gray-600 rounded transition-opacity"
              >
                <Trash2 size={14} />
              </button>
            </div>
          ))}
        </div>

        {/* 底部 */}
        <div className="p-4 border-t border-gray-800">
          <p className="text-xs text-gray-500 text-center">
            © 2024 HaruChat
          </p>
        </div>
      </aside>
    </>
  )
}

