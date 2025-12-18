//
//  ChatViewModel.swift
//  HaruChat
//
//  Created by 玩忽所以 on 2025/12/6.
//

import Foundation
import SwiftUI
import SwiftData

/// 聊天视图模型
@Observable
@MainActor
final class ChatViewModel {
    // MARK: - Properties
    
    /// 当前选中的会话
    var currentSession: ChatSession?
    
    /// 用户输入的消息
    var inputMessage: String = ""
    
    /// 是否正在加载
    var isLoading: Bool = false
    
    /// 错误信息
    var errorMessage: String?
    
    /// 是否显示错误提示
    var showError: Bool = false
    
    /// 流式输出的临时内容
    var streamingContent: String = ""
    
    /// 流式输出的思考内容
    var streamingThinking: String = ""
    
    /// 是否正在流式输出
    var isStreaming: Bool = false
    
    /// 是否正在思考
    var isThinking: Bool = false
    
    /// 是否启用 Google 搜索
    var enableGoogleSearch: Bool = false
    
    /// Token 使用统计
    var lastTokenUsage: TokenUsage?
    
    /// 当前会话总 Token 数（估算）
    var sessionTotalTokens: Int = 0
    
    // MARK: - Dependencies
    
    private let apiService = APIService.shared
    let settings = AppSettings.shared
    private var modelContext: ModelContext?
    
    // MARK: - Initialization
    
    init() {}
    
    /// 设置 ModelContext
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    // MARK: - Session Management
    
    /// 创建新会话
    func createNewSession() {
        let session = ChatSession()
        modelContext?.insert(session)
        currentSession = session
        sessionTotalTokens = 0
        lastTokenUsage = nil
        saveContext()
    }
    
    /// 选择会话
    func selectSession(_ session: ChatSession) {
        currentSession = session
        // 估算已有消息的 token（粗略估算：每4个字符约1个token）
        sessionTotalTokens = session.messages.reduce(0) { total, msg in
            total + (msg.content.count / 4) + ((msg.thinkingContent?.count ?? 0) / 4)
        }
        lastTokenUsage = nil
    }
    
    /// 删除会话
    func deleteSession(_ session: ChatSession) {
        if currentSession?.id == session.id {
            currentSession = nil
            sessionTotalTokens = 0
            lastTokenUsage = nil
        }
        modelContext?.delete(session)
        saveContext()
    }
    
    /// 重命名会话
    func renameSession(_ session: ChatSession, newTitle: String) {
        session.title = newTitle
        session.updatedAt = Date()
        saveContext()
    }
    
    // MARK: - Google Search Toggle
    
    /// 切换 Google 搜索状态
    func toggleGoogleSearch() {
        enableGoogleSearch.toggle()
    }
    
    // MARK: - Message Sending
    
    /// 发送消息
    func sendMessage() async {
        let messageText = inputMessage.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !messageText.isEmpty else { return }
        
        // 如果没有当前会话，创建一个新的
        if currentSession == nil {
            createNewSession()
        }
        
        guard let session = currentSession else { return }
        
        // 清空输入框
        inputMessage = ""
        
        // 创建用户消息
        let userMessage = ChatMessage(role: .user, content: messageText)
        session.messages.append(userMessage)
        session.updatedAt = Date()
        
        // 如果是第一条消息，自动生成标题
        if session.messages.count == 1 {
            session.generateTitle()
        }
        
        saveContext()
        
        // 发送请求
        if settings.streamEnabled {
            await sendStreamingRequest(session: session, enableGoogleSearch: enableGoogleSearch)
        } else {
            await sendNormalRequest(session: session, enableGoogleSearch: enableGoogleSearch)
        }
    }
    
    /// 发送普通请求（非流式）
    private func sendNormalRequest(session: ChatSession, enableGoogleSearch: Bool) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await apiService.sendChatRequest(
                messages: session.sortedMessages,
                settings: settings,
                enableGoogleSearch: enableGoogleSearch
            )
            
            // 更新 Token 统计
            if let usage = response.tokenUsage {
                lastTokenUsage = usage
                sessionTotalTokens += usage.totalTokens
            }
            
            // 创建助手消息
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: response.content,
                thinkingContent: response.thinkingContent
            )
            session.messages.append(assistantMessage)
            session.updatedAt = Date()
            saveContext()
            
        } catch {
            handleError(error)
        }
        
        isLoading = false
    }
    
    /// 发送流式请求
    private func sendStreamingRequest(session: ChatSession, enableGoogleSearch: Bool) async {
        isLoading = true
        isStreaming = true
        isThinking = settings.includeThoughts
        streamingContent = ""
        streamingThinking = ""
        errorMessage = nil
        
        do {
            let stream = await apiService.sendStreamingChatRequest(
                messages: session.sortedMessages,
                settings: settings,
                enableGoogleSearch: enableGoogleSearch
            )
            
            for try await chunk in stream {
                switch chunk {
                case .thinking(let text):
                    streamingThinking += text
                case .content(let text):
                    // 当收到第一个内容时，标记思考结束
                    if isThinking && !text.isEmpty {
                        isThinking = false
                    }
                    streamingContent += text
                }
            }
            
            // 流结束后，创建助手消息
            if !streamingContent.isEmpty {
                let assistantMessage = ChatMessage(
                    role: .assistant,
                    content: streamingContent,
                    thinkingContent: streamingThinking.isEmpty ? nil : streamingThinking
                )
                session.messages.append(assistantMessage)
                session.updatedAt = Date()
                
                // 估算流式响应的 token（粗略估算）
                let estimatedTokens = (streamingContent.count + streamingThinking.count) / 4
                sessionTotalTokens += estimatedTokens
                
                saveContext()
            }
            
        } catch {
            handleError(error)
        }
        
        streamingContent = ""
        streamingThinking = ""
        isStreaming = false
        isThinking = false
        isLoading = false
    }
    
    /// 重新生成最后一条消息
    func regenerateLastMessage() async {
        guard let session = currentSession else { return }
        
        // 移除最后一条助手消息
        if let lastMessage = session.sortedMessages.last,
           lastMessage.role == .assistant {
            session.messages.removeAll { $0.id == lastMessage.id }
            modelContext?.delete(lastMessage)
            saveContext()
        }
        
        // 重新发送请求（不使用搜索）
        if settings.streamEnabled {
            await sendStreamingRequest(session: session, enableGoogleSearch: false)
        } else {
            await sendNormalRequest(session: session, enableGoogleSearch: false)
        }
    }
    
    /// 停止流式生成
    func stopGenerating() {
        // 如果有流式内容，保存它
        if !streamingContent.isEmpty, let session = currentSession {
            let assistantMessage = ChatMessage(
                role: .assistant,
                content: streamingContent,
                thinkingContent: streamingThinking.isEmpty ? nil : streamingThinking
            )
            session.messages.append(assistantMessage)
            session.updatedAt = Date()
            saveContext()
        }
        
        streamingContent = ""
        streamingThinking = ""
        isStreaming = false
        isThinking = false
        isLoading = false
    }
    
    // MARK: - Error Handling
    
    private func handleError(_ error: Error) {
        if let apiError = error as? APIServiceError {
            errorMessage = apiError.errorDescription
        } else {
            errorMessage = error.localizedDescription
        }
        showError = true
    }
    
    func dismissError() {
        showError = false
        errorMessage = nil
    }
    
    // MARK: - Persistence
    
    private func saveContext() {
        do {
            try modelContext?.save()
        } catch {
            print("保存失败: \(error)")
        }
    }
}
