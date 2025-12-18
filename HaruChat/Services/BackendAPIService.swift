//
//  BackendAPIService.swift
//  HaruChat
//
//  后端 API 服务 - 调用 Python 后端
//

import Foundation

/// 后端 API 服务
actor BackendAPIService {
    static let shared = BackendAPIService()
    
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    var serverURL: String {
        AppSettings.shared.serverURL
    }
    
    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        self.session = URLSession(configuration: config)
        self.decoder = JSONDecoder()
        self.encoder = JSONEncoder()
    }
    
    // MARK: - 请求模型
    
    struct BackendChatRequest: Codable {
        let provider: String
        let model: String?
        let messages: [BackendMessage]
        let temperature: Double
        let max_tokens: Int
        let stream: Bool
        let enable_search: Bool
        let include_thoughts: Bool
    }
    
    struct BackendMessage: Codable {
        let role: String
        let content: String
    }
    
    struct BackendChatResponse: Codable {
        let content: String
        let thinking_content: String?
        let usage: BackendUsage?
    }
    
    struct BackendUsage: Codable {
        let prompt_tokens: Int
        let completion_tokens: Int
        let total_tokens: Int
    }
    
    struct BackendStreamChunk: Codable {
        let type: String
        let text: String?
        let usage: BackendUsage?
        let error: String?
    }
    
    // MARK: - 非流式请求
    
    func sendChatRequest(
        messages: [ChatMessage],
        settings: AppSettings,
        enableGoogleSearch: Bool = false
    ) async throws -> ChatResponse {
        
        guard let url = URL(string: "\(serverURL)/api/chat") else {
            throw APIServiceError.invalidURL
        }
        
        let backendMessages = messages.map { msg in
            BackendMessage(
                role: msg.role == .user ? "user" : "assistant",
                content: msg.content
            )
        }
        
        let requestBody = BackendChatRequest(
            provider: settings.currentProvider.rawValue.lowercased(),
            model: settings.modelName,
            messages: backendMessages,
            temperature: settings.temperature,
            max_tokens: settings.maxTokens,
            stream: false,
            enable_search: enableGoogleSearch,
            include_thoughts: settings.includeThoughts
        )
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(requestBody)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "请求失败"
            throw APIServiceError.httpError(statusCode: (response as? HTTPURLResponse)?.statusCode ?? 500, message: errorMessage)
        }
        
        let backendResponse = try decoder.decode(BackendChatResponse.self, from: data)
        
        var tokenUsage: TokenUsage? = nil
        if let usage = backendResponse.usage {
            tokenUsage = TokenUsage(
                promptTokens: usage.prompt_tokens,
                completionTokens: usage.completion_tokens,
                totalTokens: usage.total_tokens
            )
        }
        
        return ChatResponse(
            content: backendResponse.content,
            thinkingContent: backendResponse.thinking_content,
            tokenUsage: tokenUsage
        )
    }
    
    // MARK: - 流式请求
    
    func sendStreamingChatRequest(
        messages: [ChatMessage],
        settings: AppSettings,
        enableGoogleSearch: Bool = false
    ) -> AsyncThrowingStream<StreamChunkType, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    guard let url = URL(string: "\(serverURL)/api/chat/stream") else {
                        throw APIServiceError.invalidURL
                    }
                    
                    let backendMessages = messages.map { msg in
                        BackendMessage(
                            role: msg.role == .user ? "user" : "assistant",
                            content: msg.content
                        )
                    }
                    
                    let requestBody = BackendChatRequest(
                        provider: settings.currentProvider.rawValue.lowercased(),
                        model: settings.modelName,
                        messages: backendMessages,
                        temperature: settings.temperature,
                        max_tokens: settings.maxTokens,
                        stream: true,
                        enable_search: enableGoogleSearch,
                        include_thoughts: settings.includeThoughts
                    )
                    
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    request.httpBody = try self.encoder.encode(requestBody)
                    
                    let (bytes, response) = try await self.session.bytes(for: request)
                    
                    guard let httpResponse = response as? HTTPURLResponse,
                          (200...299).contains(httpResponse.statusCode) else {
                        throw APIServiceError.invalidResponse
                    }
                    
                    for try await line in bytes.lines {
                        guard line.hasPrefix("data: ") else { continue }
                        let jsonString = String(line.dropFirst(6))
                        guard let jsonData = jsonString.data(using: .utf8) else { continue }
                        
                        if let chunk = try? self.decoder.decode(BackendStreamChunk.self, from: jsonData) {
                            switch chunk.type {
                            case "thinking":
                                if let text = chunk.text, !text.isEmpty {
                                    continuation.yield(.thinking(text))
                                }
                            case "content":
                                if let text = chunk.text, !text.isEmpty {
                                    continuation.yield(.content(text))
                                }
                            case "error":
                                if let error = chunk.error {
                                    throw APIServiceError.httpError(statusCode: 500, message: error)
                                }
                            default:
                                break
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
    
    // MARK: - 健康检查
    
    func healthCheck() async -> Bool {
        guard let url = URL(string: "\(serverURL)/health") else { return false }
        
        do {
            let (_, response) = try await session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }
}

