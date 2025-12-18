//
//  ChatMessage.swift
//  HaruChat
//
//  Created by 玩忽所以 on 2025/12/6.
//

import Foundation
import SwiftData

/// 消息角色枚举
enum MessageRole: String, Codable {
    case user = "user"
    case assistant = "assistant"
    case system = "system"
    
    /// 转换为 Gemini API 角色
    var geminiRole: String {
        switch self {
        case .user, .system:
            return "user"
        case .assistant:
            return "model"
        }
    }
}

/// 聊天消息模型
@Model
final class ChatMessage {
    @Attribute(.unique) var id: UUID
    var role: MessageRole
    var content: String
    var timestamp: Date
    /// 思考内容（如果有）
    var thinkingContent: String?
    
    /// 关联的会话
    var session: ChatSession?
    
    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        thinkingContent: String? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.thinkingContent = thinkingContent
    }
    
    /// 是否包含思考内容
    var hasThinking: Bool {
        thinkingContent != nil && !thinkingContent!.isEmpty
    }
}

// MARK: - Gemini 原生 API 请求模型

/// Gemini 内容格式
struct GeminiContent: Codable {
    let role: String?
    let parts: [GeminiPart]
    
    init(role: String? = nil, parts: [GeminiPart]) {
        self.role = role
        self.parts = parts
    }
    
    init(from message: ChatMessage) {
        self.role = message.role.geminiRole
        self.parts = [GeminiPart(text: message.content)]
    }
}

/// Gemini Part
struct GeminiPart: Codable {
    let text: String?
    let thought: Bool?
    
    init(text: String) {
        self.text = text
        self.thought = nil
    }
    
    enum CodingKeys: String, CodingKey {
        case text, thought
    }
}

/// Google Search 工具
struct GoogleSearchTool: Codable {
    let googleSearch: EmptyObject
    
    enum CodingKeys: String, CodingKey {
        case googleSearch = "google_search"
    }
    
    init() {
        self.googleSearch = EmptyObject()
    }
}

struct EmptyObject: Codable {}

/// 思考配置
struct ThinkingConfig: Codable {
    let includeThoughts: Bool
}

/// 生成配置
struct GenerationConfig: Codable {
    let temperature: Double?
    let maxOutputTokens: Int?
    let thinkingConfig: ThinkingConfig?
    
    init(
        temperature: Double? = nil,
        maxOutputTokens: Int? = nil,
        includeThoughts: Bool = false
    ) {
        self.temperature = temperature
        self.maxOutputTokens = maxOutputTokens
        self.thinkingConfig = includeThoughts ? ThinkingConfig(includeThoughts: true) : nil
    }
}

/// Gemini 请求体
struct GeminiRequest: Codable {
    let contents: [GeminiContent]
    let tools: [GoogleSearchTool]?
    let generationConfig: GenerationConfig?
    
    init(
        contents: [GeminiContent],
        enableGoogleSearch: Bool = false,
        temperature: Double? = nil,
        maxOutputTokens: Int? = nil,
        includeThoughts: Bool = false
    ) {
        self.contents = contents
        self.tools = enableGoogleSearch ? [GoogleSearchTool()] : nil
        self.generationConfig = GenerationConfig(
            temperature: temperature,
            maxOutputTokens: maxOutputTokens,
            includeThoughts: includeThoughts
        )
    }
}

// MARK: - Gemini 原生 API 响应模型

/// Gemini 响应体
struct GeminiResponse: Codable {
    let candidates: [GeminiCandidate]?
    let usageMetadata: UsageMetadata?
    
    struct GeminiCandidate: Codable {
        let content: GeminiContent?
        let finishReason: String?
        let groundingMetadata: GroundingMetadata?
    }
    
    struct UsageMetadata: Codable {
        let promptTokenCount: Int?
        let candidatesTokenCount: Int?
        let totalTokenCount: Int?
    }
    
    struct GroundingMetadata: Codable {
        let searchEntryPoint: SearchEntryPoint?
        let groundingChunks: [GroundingChunk]?
        let webSearchQueries: [String]?
    }
    
    struct SearchEntryPoint: Codable {
        let renderedContent: String?
    }
    
    struct GroundingChunk: Codable {
        let web: WebSource?
    }
    
    struct WebSource: Codable {
        let uri: String?
        let title: String?
    }
    
    /// 提取思考内容和正文内容
    func extractContent() -> (thinking: String?, content: String?) {
        guard let parts = candidates?.first?.content?.parts else {
            return (nil, nil)
        }
        
        var thinkingParts: [String] = []
        var contentParts: [String] = []
        
        for part in parts {
            if let text = part.text, !text.isEmpty {
                if part.thought == true {
                    thinkingParts.append(text)
                } else {
                    contentParts.append(text)
                }
            }
        }
        
        let thinking = thinkingParts.isEmpty ? nil : thinkingParts.joined()
        let content = contentParts.isEmpty ? nil : contentParts.joined()
        
        return (thinking, content)
    }
}

/// Gemini 错误响应
struct GeminiErrorResponse: Codable {
    let error: GeminiError
    
    struct GeminiError: Codable {
        let code: Int?
        let message: String
        let status: String?
    }
}
