//
//  ChatSession.swift
//  HaruChat
//
//  Created by 玩忽所以 on 2025/12/6.
//

import Foundation
import SwiftData

/// 聊天会话模型
@Model
final class ChatSession {
    @Attribute(.unique) var id: UUID
    var title: String
    var createdAt: Date
    var updatedAt: Date
    
    /// 会话中的消息列表
    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    var messages: [ChatMessage]
    
    init(
        id: UUID = UUID(),
        title: String = "新对话",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        messages: [ChatMessage] = []
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.messages = messages
    }
    
    /// 获取排序后的消息
    var sortedMessages: [ChatMessage] {
        messages.sorted { $0.timestamp < $1.timestamp }
    }
    
    /// 根据第一条用户消息自动生成标题
    func generateTitle() {
        if let firstUserMessage = sortedMessages.first(where: { $0.role == .user }) {
            let content = firstUserMessage.content
            // 截取前30个字符作为标题
            title = String(content.prefix(30)) + (content.count > 30 ? "..." : "")
        }
    }
}

