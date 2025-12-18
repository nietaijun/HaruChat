//
//  APIService.swift
//  HaruChat
//
//  Created by 玩忽所以 on 2025/12/6.
//

import Foundation

/// API 服务错误类型
enum APIServiceError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int, message: String)
    case decodingError(Error)
    case networkError(Error)
    case noAPIKey
    case emptyResponse
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "无效的 API URL"
        case .invalidResponse:
            return "服务器响应无效"
        case .httpError(let statusCode, let message):
            return "HTTP 错误 (\(statusCode)): \(message)"
        case .decodingError(let error):
            return "数据解析错误: \(error.localizedDescription)"
        case .networkError(let error):
            return "网络错误: \(error.localizedDescription)"
        case .noAPIKey:
            return "请先在设置中配置 API Key"
        case .emptyResponse:
            return "服务器返回了空响应"
        }
    }
}

/// Token 使用统计
struct TokenUsage {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    init(promptTokens: Int = 0, completionTokens: Int = 0, totalTokens: Int = 0) {
        self.promptTokens = promptTokens
        self.completionTokens = completionTokens
        self.totalTokens = totalTokens
    }
}

/// 聊天响应结果
struct ChatResponse {
    let content: String
    let thinkingContent: String?
    let tokenUsage: TokenUsage?
}

/// 流式内容片段
enum StreamChunkType {
    case thinking(String)
    case content(String)
}

/// API 服务 - 支持 Gemini 和 OpenAI
actor APIService {
    static let shared = APIService()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
        
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }
    
    // MARK: - 统一入口
    
    /// 发送聊天请求（根据供应商自动选择）
    func sendChatRequest(
        messages: [ChatMessage],
        settings: AppSettings,
        enableGoogleSearch: Bool = false
    ) async throws -> ChatResponse {
        switch settings.currentProvider {
        case .gemini:
            return try await sendGeminiRequest(messages: messages, settings: settings, enableGoogleSearch: enableGoogleSearch)
        case .openai:
            return try await sendOpenAIRequest(messages: messages, settings: settings)
        }
    }
    
    /// 发送流式聊天请求（根据供应商自动选择）
    func sendStreamingChatRequest(
        messages: [ChatMessage],
        settings: AppSettings,
        enableGoogleSearch: Bool = false
    ) -> AsyncThrowingStream<StreamChunkType, Error> {
        switch settings.currentProvider {
        case .gemini:
            return sendGeminiStreamingRequest(messages: messages, settings: settings, enableGoogleSearch: enableGoogleSearch)
        case .openai:
            return sendOpenAIStreamingRequest(messages: messages, settings: settings)
        }
    }
    
    // MARK: - Gemini API
    
    private func sendGeminiRequest(
        messages: [ChatMessage],
        settings: AppSettings,
        enableGoogleSearch: Bool
    ) async throws -> ChatResponse {
        guard !settings.geminiConfig.apiKey.isEmpty else {
            throw APIServiceError.noAPIKey
        }
        
        guard let url = URL(string: "\(settings.geminiURL)?key=\(settings.geminiConfig.apiKey)") else {
            throw APIServiceError.invalidURL
        }
        
        let contents = messages.map { GeminiContent(from: $0) }
        
        let requestBody = GeminiRequest(
            contents: contents,
            enableGoogleSearch: enableGoogleSearch,
            temperature: settings.temperature,
            maxOutputTokens: settings.maxTokens,
            includeThoughts: settings.includeThoughts
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = parseGeminiError(from: data) ?? "未知错误"
            throw APIServiceError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        let geminiResponse = try decoder.decode(GeminiResponse.self, from: data)
        let (thinking, content) = geminiResponse.extractContent()
        
        guard let finalContent = content else {
            throw APIServiceError.emptyResponse
        }
        
        var tokenUsage: TokenUsage? = nil
        if let usage = geminiResponse.usageMetadata {
            tokenUsage = TokenUsage(
                promptTokens: usage.promptTokenCount ?? 0,
                completionTokens: usage.candidatesTokenCount ?? 0,
                totalTokens: usage.totalTokenCount ?? 0
            )
        }
        
        return ChatResponse(content: finalContent, thinkingContent: thinking, tokenUsage: tokenUsage)
    }
    
    private func sendGeminiStreamingRequest(
        messages: [ChatMessage],
        settings: AppSettings,
        enableGoogleSearch: Bool
    ) -> AsyncThrowingStream<StreamChunkType, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard !settings.geminiConfig.apiKey.isEmpty else {
                        throw APIServiceError.noAPIKey
                    }
                    
                    guard let url = URL(string: "\(settings.geminiStreamURL)&key=\(settings.geminiConfig.apiKey)") else {
                        throw APIServiceError.invalidURL
                    }
                    
                    let contents = messages.map { GeminiContent(from: $0) }
                    
                    let requestBody = GeminiRequest(
                        contents: contents,
                        enableGoogleSearch: enableGoogleSearch,
                        temperature: settings.temperature,
                        maxOutputTokens: settings.maxTokens,
                        includeThoughts: settings.includeThoughts
                    )
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try self.encoder.encode(requestBody)
                    
                    let (bytes, response) = try await self.session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw APIServiceError.invalidResponse
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        var errorData = Data()
                        for try await byte in bytes { errorData.append(byte) }
                        let errorMessage = self.parseGeminiError(from: errorData) ?? "流式请求失败"
                        throw APIServiceError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
                    }
                    
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6))
                        guard let jsonData = jsonString.data(using: .utf8) else { continue }
                        
                        if let chunk = try? self.decoder.decode(GeminiResponse.self, from: jsonData) {
                            if let parts = chunk.candidates?.first?.content?.parts {
                                for part in parts {
                                    if let text = part.text, !text.isEmpty {
                                        if part.thought == true {
                                            continuation.yield(.thinking(text))
                                        } else {
                                            continuation.yield(.content(text))
                                        }
                                    }
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func parseGeminiError(from data: Data) -> String? {
        if let errorResponse = try? decoder.decode(GeminiErrorResponse.self, from: data) {
            return errorResponse.error.message
        }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - OpenAI API
    
    private func sendOpenAIRequest(
        messages: [ChatMessage],
        settings: AppSettings
    ) async throws -> ChatResponse {
        guard !settings.openaiConfig.apiKey.isEmpty else {
            throw APIServiceError.noAPIKey
        }
        
        guard let url = URL(string: settings.openaiURL) else {
            throw APIServiceError.invalidURL
        }
        
        let openAIMessages = messages.map { OpenAIMessage(from: $0) }
        
        let requestBody = OpenAIRequest(
            model: settings.openaiConfig.selectedModel,
            messages: openAIMessages,
            temperature: settings.temperature,
            maxTokens: settings.maxTokens,
            stream: false
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(settings.openaiConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try encoder.encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIServiceError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = parseOpenAIError(from: data) ?? "未知错误"
            throw APIServiceError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
        }
        
        let openAIResponse = try decoder.decode(OpenAIResponse.self, from: data)
        
        guard let content = openAIResponse.choices.first?.message.content else {
            throw APIServiceError.emptyResponse
        }
        
        var tokenUsage: TokenUsage? = nil
        if let usage = openAIResponse.usage {
            tokenUsage = TokenUsage(
                promptTokens: usage.promptTokens,
                completionTokens: usage.completionTokens,
                totalTokens: usage.totalTokens
            )
        }
        
        return ChatResponse(content: content, thinkingContent: nil, tokenUsage: tokenUsage)
    }
    
    private func sendOpenAIStreamingRequest(
        messages: [ChatMessage],
        settings: AppSettings
    ) -> AsyncThrowingStream<StreamChunkType, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard !settings.openaiConfig.apiKey.isEmpty else {
                        throw APIServiceError.noAPIKey
                    }
                    
                    guard let url = URL(string: settings.openaiURL) else {
                        throw APIServiceError.invalidURL
                    }
                    
                    let openAIMessages = messages.map { OpenAIMessage(from: $0) }
                    
                    let requestBody = OpenAIRequest(
                        model: settings.openaiConfig.selectedModel,
                        messages: openAIMessages,
                        temperature: settings.temperature,
                        maxTokens: settings.maxTokens,
                        stream: true
                    )
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.setValue("Bearer \(settings.openaiConfig.apiKey)", forHTTPHeaderField: "Authorization")
                    request.httpBody = try self.encoder.encode(requestBody)
                    
                    let (bytes, response) = try await self.session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse else {
                        throw APIServiceError.invalidResponse
                    }
                    
                    guard (200...299).contains(httpResponse.statusCode) else {
                        var errorData = Data()
                        for try await byte in bytes { errorData.append(byte) }
                        let errorMessage = self.parseOpenAIError(from: errorData) ?? "流式请求失败"
                        throw APIServiceError.httpError(statusCode: httpResponse.statusCode, message: errorMessage)
                    }
                    
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6))
                        
                        if jsonString == "[DONE]" { break }
                        
                        guard let jsonData = jsonString.data(using: .utf8) else { continue }
                        
                        if let chunk = try? self.decoder.decode(OpenAIStreamResponse.self, from: jsonData) {
                            if let content = chunk.choices.first?.delta.content, !content.isEmpty {
                                continuation.yield(.content(content))
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
    
    private func parseOpenAIError(from data: Data) -> String? {
        if let errorResponse = try? decoder.decode(OpenAIErrorResponse.self, from: data) {
            return errorResponse.error.message
        }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - OpenAI 请求/响应模型

struct OpenAIMessage: Codable {
    let role: String
    let content: String
    
    init(from message: ChatMessage) {
        self.role = message.role == .assistant ? "assistant" : "user"
        self.content = message.content
    }
}

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double?
    let maxTokens: Int?
    let stream: Bool
    
    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
    }
    
    init(model: String, messages: [OpenAIMessage], temperature: Double?, maxTokens: Int?, stream: Bool) {
        self.model = model
        self.messages = messages
        self.temperature = temperature
        self.maxTokens = maxTokens
        self.stream = stream
    }
}

struct OpenAIResponse: Codable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage?
}

struct OpenAIChoice: Codable {
    let index: Int
    let message: OpenAIResponseMessage
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, message
        case finishReason = "finish_reason"
    }
}

struct OpenAIResponseMessage: Codable {
    let role: String
    let content: String?
}

struct OpenAIUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
    
    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}

struct OpenAIStreamResponse: Codable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [OpenAIStreamChoice]
}

struct OpenAIStreamChoice: Codable {
    let index: Int
    let delta: OpenAIDelta
    let finishReason: String?
    
    enum CodingKeys: String, CodingKey {
        case index, delta
        case finishReason = "finish_reason"
    }
}

struct OpenAIDelta: Codable {
    let role: String?
    let content: String?
}

struct OpenAIErrorResponse: Codable {
    let error: OpenAIError
}

struct OpenAIError: Codable {
    let message: String
    let type: String?
    let code: String?
}
