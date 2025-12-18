'use client'

import { X } from 'lucide-react'

interface SettingsProps {
  isOpen: boolean
  onClose: () => void
  provider: 'gemini' | 'openai'
  setProvider: (provider: 'gemini' | 'openai') => void
  model: string
  setModel: (model: string) => void
}

const MODELS = {
  gemini: ['gemini-2.5-flash', 'gemini-2.5-pro', 'gemini-2.0-flash'],
  openai: ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-3.5-turbo'],
}

export function Settings({
  isOpen,
  onClose,
  provider,
  setProvider,
  model,
  setModel,
}: SettingsProps) {
  if (!isOpen) return null

  return (
    <>
      {/* 遮罩 */}
      <div className="fixed inset-0 bg-black/50 z-50" onClick={onClose} />

      {/* 面板 */}
      <div className="fixed right-0 top-0 bottom-0 w-80 bg-white dark:bg-gray-800 z-50 shadow-xl">
        <div className="p-4 border-b border-gray-200 dark:border-gray-700 flex items-center justify-between">
          <h2 className="font-semibold text-lg">设置</h2>
          <button
            onClick={onClose}
            className="p-1 hover:bg-gray-100 dark:hover:bg-gray-700 rounded"
          >
            <X size={20} />
          </button>
        </div>

        <div className="p-4 space-y-6">
          {/* 供应商选择 */}
          <div>
            <label className="block text-sm font-medium mb-2">AI 供应商</label>
            <div className="flex gap-2">
              <button
                onClick={() => {
                  setProvider('gemini')
                  setModel(MODELS.gemini[0])
                }}
                className={`flex-1 py-2 px-4 rounded-lg border-2 transition-colors ${
                  provider === 'gemini'
                    ? 'border-primary-500 bg-primary-50 dark:bg-primary-900/20'
                    : 'border-gray-200 dark:border-gray-600'
                }`}
              >
                <span className="font-medium">Gemini</span>
              </button>
              <button
                onClick={() => {
                  setProvider('openai')
                  setModel(MODELS.openai[0])
                }}
                className={`flex-1 py-2 px-4 rounded-lg border-2 transition-colors ${
                  provider === 'openai'
                    ? 'border-primary-500 bg-primary-50 dark:bg-primary-900/20'
                    : 'border-gray-200 dark:border-gray-600'
                }`}
              >
                <span className="font-medium">OpenAI</span>
              </button>
            </div>
          </div>

          {/* 模型选择 */}
          <div>
            <label className="block text-sm font-medium mb-2">模型</label>
            <div className="space-y-2">
              {MODELS[provider].map((m) => (
                <button
                  key={m}
                  onClick={() => setModel(m)}
                  className={`w-full text-left py-2 px-4 rounded-lg border transition-colors ${
                    model === m
                      ? 'border-primary-500 bg-primary-50 dark:bg-primary-900/20'
                      : 'border-gray-200 dark:border-gray-600 hover:bg-gray-50 dark:hover:bg-gray-700'
                  }`}
                >
                  <span className="font-medium">{m}</span>
                </button>
              ))}
            </div>
          </div>
        </div>
      </div>
    </>
  )
}

