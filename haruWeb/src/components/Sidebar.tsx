'use client'

import { useState } from 'react'
import { Plus, MessageSquare, Trash2, X, Search, Settings, Sparkles } from 'lucide-react'
import type { ChatSession } from '@/app/page'

interface SidebarProps {
  sessions: ChatSession[]
  currentSessionId: string | null
  onSelectSession: (id: string) => void
  onNewSession: () => void
  onDeleteSession: (id: string) => void
  isOpen: boolean
  onClose: () => void
  onOpenSettings: () => void
}

export function Sidebar({
  sessions,
  currentSessionId,
  onSelectSession,
  onNewSession,
  onDeleteSession,
  isOpen,
  onClose,
  onOpenSettings,
}: SidebarProps) {
  const [searchQuery, setSearchQuery] = useState('')
  const [hoveredId, setHoveredId] = useState<string | null>(null)

  const filteredSessions = sessions.filter(session =>
    session.title.toLowerCase().includes(searchQuery.toLowerCase())
  )

  // 按日期分组
  const groupedSessions = groupSessionsByDate(filteredSessions)

  return (
    <>
      {/* 遮罩层 - 移动端 */}
      {isOpen && (
        <div
          className="fixed inset-0 bg-black/40 backdrop-blur-sm z-40 lg:hidden animate-fade-in"
          onClick={onClose}
        />
      )}

      {/* 侧边栏 */}
      <aside
        className={`fixed lg:relative inset-y-0 left-0 z-50 w-72 bg-[#fafafa] dark:bg-[#141414] flex flex-col transform transition-transform duration-300 ease-out lg:transform-none border-r border-gray-200/60 dark:border-gray-800 ${
          isOpen ? 'translate-x-0' : '-translate-x-full'
        }`}
      >
        {/* 头部 Logo */}
        <div className="p-4 flex items-center justify-between">
          <div className="flex items-center gap-3">
            {/* Logo */}
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-primary-400 to-primary-600 flex items-center justify-center shadow-glow">
              <Sparkles size={20} className="text-white" />
            </div>
            <div>
              <h1 className="font-semibold text-lg text-gray-900 dark:text-white">HaruChat</h1>
              <p className="text-xs text-gray-500">AI 助手</p>
            </div>
          </div>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-200 dark:hover:bg-gray-800 rounded-xl transition-colors lg:hidden"
          >
            <X size={18} className="text-gray-500" />
          </button>
        </div>

        {/* 新建对话按钮 */}
        <div className="px-3 pb-2">
          <button
            onClick={onNewSession}
            className="w-full flex items-center justify-center gap-2 px-4 py-3 bg-gradient-to-r from-primary-500 to-primary-600 hover:from-primary-600 hover:to-primary-700 text-white rounded-xl transition-all shadow-soft hover:shadow-glow btn-bounce"
          >
            <Plus size={18} />
            <span className="font-medium">新建对话</span>
          </button>
        </div>

        {/* 搜索框 */}
        <div className="px-3 pb-3">
          <div className="relative">
            <Search size={16} className="absolute left-3 top-1/2 -translate-y-1/2 text-gray-400" />
            <input
              type="text"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              placeholder="搜索对话..."
              className="w-full pl-9 pr-4 py-2.5 bg-gray-100 dark:bg-[#1e1e1e] border border-transparent focus:border-primary-400 dark:focus:border-primary-500 rounded-xl text-sm text-gray-900 dark:text-white placeholder-gray-400 outline-none transition-all"
            />
          </div>
        </div>

        {/* 会话列表 */}
        <div className="flex-1 overflow-y-auto px-3 space-y-4">
          {Object.entries(groupedSessions).map(([group, groupSessions]) => (
            <div key={group}>
              <h3 className="text-xs font-medium text-gray-500 dark:text-gray-500 px-2 mb-2">
                {group}
              </h3>
              <div className="space-y-1">
                {groupSessions.map((session) => (
                  <div
                    key={session.id}
                    className={`group relative flex items-center gap-3 px-3 py-3 rounded-xl cursor-pointer transition-all sidebar-item ${
                      currentSessionId === session.id
                        ? 'bg-primary-50 dark:bg-primary-900/20 border border-primary-200 dark:border-primary-800'
                        : 'hover:bg-gray-100 dark:hover:bg-gray-800/60'
                    }`}
                    onClick={() => onSelectSession(session.id)}
                    onMouseEnter={() => setHoveredId(session.id)}
                    onMouseLeave={() => setHoveredId(null)}
                  >
                    {/* 图标 */}
                    <div className={`shrink-0 w-8 h-8 rounded-lg flex items-center justify-center ${
                      currentSessionId === session.id
                        ? 'bg-primary-100 dark:bg-primary-800/40'
                        : 'bg-gray-100 dark:bg-gray-800'
                    }`}>
                      <MessageSquare size={14} className={
                        currentSessionId === session.id
                          ? 'text-primary-600 dark:text-primary-400'
                          : 'text-gray-500 dark:text-gray-400'
                      } />
                    </div>

                    {/* 标题和预览 */}
                    <div className="flex-1 min-w-0">
                      <p className={`text-sm font-medium truncate ${
                        currentSessionId === session.id
                          ? 'text-primary-700 dark:text-primary-300'
                          : 'text-gray-700 dark:text-gray-300'
                      }`}>
                        {session.title}
                      </p>
                      {session.messages.length > 0 && (
                        <p className="text-xs text-gray-500 dark:text-gray-500 truncate mt-0.5">
                          {session.messages[session.messages.length - 1].content.slice(0, 30)}
                        </p>
                      )}
                    </div>

                    {/* 删除按钮 */}
                    <button
                      onClick={(e) => {
                        e.stopPropagation()
                        onDeleteSession(session.id)
                      }}
                      className={`shrink-0 p-1.5 rounded-lg transition-all ${
                        hoveredId === session.id ? 'opacity-100' : 'opacity-0'
                      } hover:bg-red-100 dark:hover:bg-red-900/30 text-gray-400 hover:text-red-500`}
                    >
                      <Trash2 size={14} />
                    </button>
                  </div>
                ))}
              </div>
            </div>
          ))}

          {/* 空状态 */}
          {filteredSessions.length === 0 && (
            <div className="flex flex-col items-center justify-center py-12 text-center">
              <div className="w-16 h-16 rounded-full bg-gray-100 dark:bg-gray-800 flex items-center justify-center mb-4">
                <MessageSquare size={24} className="text-gray-400" />
              </div>
              <p className="text-sm text-gray-500 dark:text-gray-400">
                {searchQuery ? '未找到匹配的对话' : '暂无对话记录'}
              </p>
              <p className="text-xs text-gray-400 dark:text-gray-500 mt-1">
                {searchQuery ? '尝试其他关键词' : '开始一个新的对话吧'}
              </p>
            </div>
          )}
        </div>

        {/* 底部设置 */}
        <div className="p-3 border-t border-gray-200/60 dark:border-gray-800">
          <button
            onClick={onOpenSettings}
            className="w-full flex items-center gap-3 px-3 py-2.5 rounded-xl hover:bg-gray-100 dark:hover:bg-gray-800 transition-all"
          >
            <div className="w-8 h-8 rounded-lg bg-gray-100 dark:bg-gray-800 flex items-center justify-center">
              <Settings size={16} className="text-gray-500" />
            </div>
            <span className="text-sm text-gray-700 dark:text-gray-300">设置</span>
          </button>
        </div>
      </aside>
    </>
  )
}

// 按日期分组
function groupSessionsByDate(sessions: ChatSession[]): Record<string, ChatSession[]> {
  const groups: Record<string, ChatSession[]> = {}
  const now = new Date()
  const today = new Date(now.getFullYear(), now.getMonth(), now.getDate())
  const yesterday = new Date(today.getTime() - 24 * 60 * 60 * 1000)
  const lastWeek = new Date(today.getTime() - 7 * 24 * 60 * 60 * 1000)

  sessions.forEach(session => {
    const sessionDate = new Date(session.updatedAt)
    let group: string

    if (sessionDate >= today) {
      group = '今天'
    } else if (sessionDate >= yesterday) {
      group = '昨天'
    } else if (sessionDate >= lastWeek) {
      group = '最近 7 天'
    } else {
      group = '更早'
    }

    if (!groups[group]) {
      groups[group] = []
    }
    groups[group].push(session)
  })

  return groups
}
