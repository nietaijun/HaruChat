'use client'

import { useState } from 'react'
import { X, ChevronRight, Sparkles, Zap, Brain, Leaf, Check } from 'lucide-react'
import type { Provider } from '@/app/page'
import { ProviderIcon } from './ProviderIcon'

interface SettingsProps {
  isOpen: boolean
  onClose: () => void
  provider: Provider
  setProvider: (provider: Provider) => void
  model: string
  setModel: (model: string) => void
}

const MODELS = {
  gemini: [
    { id: 'gemini-2.5-flash', name: 'Gemini 2.5 Flash', description: '快速且智能', icon: Zap, color: 'text-amber-500' },
    { id: 'gemini-2.5-pro', name: 'Gemini 2.5 Pro', description: '强大深度推理', icon: Brain, color: 'text-purple-500' },
    { id: 'gemini-2.0-flash', name: 'Gemini 2.0 Flash', description: '稳定可靠', icon: Sparkles, color: 'text-blue-500' },
    { id: 'gemini-1.5-pro', name: 'Gemini 1.5 Pro', description: '深度推理', icon: Brain, color: 'text-emerald-500' },
  ],
  openai: [
    { id: 'gpt-4o', name: 'GPT-4o', description: '最强多模态模型', icon: Sparkles, color: 'text-emerald-500' },
    { id: 'gpt-4o-mini', name: 'GPT-4o Mini', description: '轻量快速', icon: Zap, color: 'text-emerald-500' },
    { id: 'gpt-4-turbo', name: 'GPT-4 Turbo', description: '高性能模型', icon: Brain, color: 'text-emerald-500' },
    { id: 'gpt-3.5-turbo', name: 'GPT-3.5 Turbo', description: '经济实惠', icon: Leaf, color: 'text-emerald-500' },
  ],
}

export function Settings({
  isOpen,
  onClose,
  provider,
  setProvider,
  model,
  setModel,
}: SettingsProps) {
  const [activeTab, setActiveTab] = useState<'model' | 'general'>('model')

  if (!isOpen) return null

  return (
    <>
      {/* 遮罩层 */}
      <div 
        className="fixed inset-0 bg-black/40 backdrop-blur-sm z-50 animate-fade-in" 
        onClick={onClose} 
      />

      {/* 设置面板 */}
      <div className="fixed right-0 top-0 bottom-0 w-full max-w-md bg-white dark:bg-[#1a1a1a] z-50 shadow-2xl animate-slide-in-right overflow-hidden flex flex-col">
        {/* 头部 */}
        <div className="flex items-center justify-between px-6 py-4 border-b border-gray-200/60 dark:border-gray-800">
          <h2 className="text-lg font-semibold text-gray-900 dark:text-white">设置</h2>
          <button
            onClick={onClose}
            className="p-2 hover:bg-gray-100 dark:hover:bg-gray-800 rounded-xl transition-colors"
          >
            <X size={20} className="text-gray-500" />
          </button>
        </div>

        {/* 选项卡 */}
        <div className="flex gap-2 px-6 py-3 border-b border-gray-200/60 dark:border-gray-800">
          <button
            onClick={() => setActiveTab('model')}
            className={`px-4 py-2 rounded-xl text-sm font-medium transition-all ${
              activeTab === 'model'
                ? 'bg-primary-50 dark:bg-primary-900/30 text-primary-600 dark:text-primary-400'
                : 'text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800'
            }`}
          >
            模型设置
          </button>
          <button
            onClick={() => setActiveTab('general')}
            className={`px-4 py-2 rounded-xl text-sm font-medium transition-all ${
              activeTab === 'general'
                ? 'bg-primary-50 dark:bg-primary-900/30 text-primary-600 dark:text-primary-400'
                : 'text-gray-600 dark:text-gray-400 hover:bg-gray-100 dark:hover:bg-gray-800'
            }`}
          >
            通用设置
          </button>
        </div>

        {/* 内容区域 */}
        <div className="flex-1 overflow-y-auto p-6 space-y-6">
          {activeTab === 'model' ? (
            <>
              {/* 供应商选择 */}
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">
                  AI 供应商
                </label>
                <div className="grid grid-cols-2 gap-3">
                  {(['gemini', 'openai'] as Provider[]).map((p) => (
                    <button
                      key={p}
                      onClick={() => {
                        setProvider(p)
                        setModel(MODELS[p][0].id)
                      }}
                      className={`relative flex flex-col items-center gap-3 p-4 rounded-2xl border-2 transition-all btn-bounce ${
                        provider === p
                          ? 'border-primary-500 bg-primary-50 dark:bg-primary-900/20'
                          : 'border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600'
                      }`}
                    >
                      {/* 选中标记 */}
                      {provider === p && (
                        <div className="absolute top-2 right-2 w-5 h-5 rounded-full bg-primary-500 flex items-center justify-center">
                          <Check size={12} className="text-white" />
                        </div>
                      )}
                      
                      <div className={`w-12 h-12 rounded-xl flex items-center justify-center ${
                        p === 'gemini' ? 'gemini-gradient' : 'openai-gradient'
                      }`}>
                        <ProviderIcon provider={p} size={28} />
                      </div>
                      <div className="text-center">
                        <span className="font-medium text-gray-900 dark:text-white">
                          {p === 'gemini' ? 'Google Gemini' : 'OpenAI'}
                        </span>
                        <p className="text-xs text-gray-500 mt-1">
                          {p === 'gemini' ? '支持搜索和思考' : 'ChatGPT 系列'}
                        </p>
                      </div>
                    </button>
                  ))}
                </div>
              </div>

              {/* 模型选择 */}
              <div>
                <label className="block text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">
                  选择模型
                </label>
                <div className="space-y-2">
                  {MODELS[provider].map((m) => {
                    const Icon = m.icon
                    return (
                      <button
                        key={m.id}
                        onClick={() => setModel(m.id)}
                        className={`w-full flex items-center gap-4 p-4 rounded-xl border transition-all ${
                          model === m.id
                            ? 'border-primary-500 bg-primary-50 dark:bg-primary-900/20'
                            : 'border-gray-200 dark:border-gray-700 hover:border-gray-300 dark:hover:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-800/50'
                        }`}
                      >
                        {/* 图标 */}
                        <div className={`w-10 h-10 rounded-xl flex items-center justify-center ${
                          model === m.id
                            ? 'bg-primary-100 dark:bg-primary-800/40'
                            : 'bg-gray-100 dark:bg-gray-800'
                        }`}>
                          <Icon size={18} className={model === m.id ? 'text-primary-600' : m.color} />
                        </div>

                        {/* 信息 */}
                        <div className="flex-1 text-left">
                          <span className={`font-medium ${
                            model === m.id
                              ? 'text-primary-700 dark:text-primary-300'
                              : 'text-gray-900 dark:text-white'
                          }`}>
                            {m.name}
                          </span>
                          <p className="text-sm text-gray-500">{m.description}</p>
                        </div>

                        {/* 选中标记 */}
                        {model === m.id && (
                          <div className="w-6 h-6 rounded-full bg-primary-500 flex items-center justify-center">
                            <Check size={14} className="text-white" />
                          </div>
                        )}
                      </button>
                    )
                  })}
                </div>
              </div>
            </>
          ) : (
            <>
              {/* 通用设置 */}
              <div className="space-y-4">
                {/* 主题设置 */}
                <SettingItem
                  title="深色模式"
                  description="切换应用主题"
                  action={
                    <button className="relative w-12 h-7 rounded-full bg-gray-200 dark:bg-primary-500 transition-colors">
                      <span className="absolute top-1 left-1 dark:left-6 w-5 h-5 rounded-full bg-white shadow transition-all" />
                    </button>
                  }
                />

                {/* 流式输出 */}
                <SettingItem
                  title="流式输出"
                  description="实时显示 AI 回复"
                  action={
                    <button className="relative w-12 h-7 rounded-full bg-primary-500 transition-colors">
                      <span className="absolute top-1 left-6 w-5 h-5 rounded-full bg-white shadow" />
                    </button>
                  }
                />

                {/* 思考过程 */}
                <SettingItem
                  title="显示思考过程"
                  description="展示 AI 的推理步骤"
                  action={
                    <button className="relative w-12 h-7 rounded-full bg-primary-500 transition-colors">
                      <span className="absolute top-1 left-6 w-5 h-5 rounded-full bg-white shadow" />
                    </button>
                  }
                />
              </div>

              {/* 关于 */}
              <div className="pt-4 border-t border-gray-200/60 dark:border-gray-800">
                <h3 className="text-sm font-medium text-gray-700 dark:text-gray-300 mb-3">关于</h3>
                <div className="space-y-2">
                  <SettingItem
                    title="版本"
                    description="HaruChat Web v1.0.0"
                    action={<ChevronRight size={18} className="text-gray-400" />}
                  />
                  <SettingItem
                    title="开源协议"
                    description="MIT License"
                    action={<ChevronRight size={18} className="text-gray-400" />}
                  />
                </div>
              </div>
            </>
          )}
        </div>

        {/* 底部 */}
        <div className="p-6 border-t border-gray-200/60 dark:border-gray-800">
          <button
            onClick={onClose}
            className="w-full py-3 bg-gradient-to-r from-primary-500 to-primary-600 hover:from-primary-600 hover:to-primary-700 text-white font-medium rounded-xl transition-all shadow-soft hover:shadow-glow btn-bounce"
          >
            完成
          </button>
        </div>
      </div>
    </>
  )
}

// 设置项组件
function SettingItem({
  title,
  description,
  action,
}: {
  title: string
  description: string
  action: React.ReactNode
}) {
  return (
    <div className="flex items-center justify-between p-4 rounded-xl bg-gray-50 dark:bg-[#1e1e1e]">
      <div>
        <p className="font-medium text-gray-900 dark:text-white">{title}</p>
        <p className="text-sm text-gray-500">{description}</p>
      </div>
      {action}
    </div>
  )
}
