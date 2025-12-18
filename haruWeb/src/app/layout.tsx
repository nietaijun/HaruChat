import type { Metadata } from 'next'
import './globals.css'

export const metadata: Metadata = {
  title: 'HaruChat - AI 助手',
  description: '与 Gemini 和 ChatGPT 对话的智能助手',
  icons: {
    icon: '/favicon.ico',
  },
}

export default function RootLayout({
  children,
}: {
  children: React.ReactNode
}) {
  return (
    <html lang="zh-CN" suppressHydrationWarning>
      <head>
        <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no" />
        <meta name="theme-color" content="#10b981" />
        <meta name="apple-mobile-web-app-capable" content="yes" />
        <meta name="apple-mobile-web-app-status-bar-style" content="default" />
      </head>
      <body className="antialiased bg-[#f8fafb] dark:bg-[#0f0f0f] text-gray-900 dark:text-white">
        {children}
      </body>
    </html>
  )
}
