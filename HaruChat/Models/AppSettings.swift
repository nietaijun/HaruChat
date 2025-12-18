//
//  AppSettings.swift
//  HaruChat
//
//  Created by 玩忽所以 on 2025/12/6.
//

import Foundation
import SwiftUI

// MARK: - 供应商类型

enum AIProvider: String, Codable, CaseIterable {
    case gemini = "Gemini"
    case openai = "OpenAI"
    
    var displayName: String {
        switch self {
        case .gemini: return "Google Gemini"
        case .openai: return "OpenAI"
        }
    }
    
    var iconName: String {
        switch self {
        case .gemini: return "g.circle.fill"
        case .openai: return "brain.head.profile"
        }
    }
    
    var defaultBaseURL: String {
        switch self {
        case .gemini: return "https://generativelanguage.googleapis.com/v1beta"
        case .openai: return "https://api.openai.com/v1"
        }
    }
    
    var defaultModels: [String] {
        switch self {
        case .gemini: return ["gemini-3-pro-preview", "gemini-2.5-flash"]
        case .openai: return ["gpt-5.1", "gpt-5-chat-latest", "gpt-5-mini", "gpt-5-nano"]
        }
    }
}

// MARK: - 供应商配置

struct ProviderConfig: Codable {
    var baseURL: String
    var apiKey: String
    var models: [String]
    var selectedModel: String
    
    init(provider: AIProvider) {
        self.baseURL = provider.defaultBaseURL
        self.apiKey = ""
        self.models = provider.defaultModels
        self.selectedModel = provider.defaultModels.first ?? ""
    }
}

/// 应用设置管理器
@Observable
final class AppSettings {
    static let shared = AppSettings()
    
    private let defaults = UserDefaults.standard
    
    // MARK: - Keys
    private enum Keys {
        static let currentProvider = "currentProvider"
        static let geminiConfig = "geminiConfig"
        static let openaiConfig = "openaiConfig"
        static let temperature = "temperature"
        static let maxTokens = "maxTokens"
        static let streamEnabled = "streamEnabled"
        static let includeThoughts = "includeThoughts"
        static let fontSize = "fontSize"
    }
    
    // MARK: - 内存缓存
    private var _currentProvider: AIProvider = .gemini
    private var _geminiConfig: ProviderConfig
    private var _openaiConfig: ProviderConfig
    private var _temperature: Double = 0.7
    private var _maxTokens: Int = 4096
    private var _fontSize: Double = 16
    
    // MARK: - 当前供应商
    
    var currentProvider: AIProvider {
        get { _currentProvider }
        set {
            _currentProvider = newValue
            defaults.set(newValue.rawValue, forKey: Keys.currentProvider)
        }
    }
    
    // MARK: - Gemini 配置
    
    var geminiConfig: ProviderConfig {
        get { _geminiConfig }
        set {
            _geminiConfig = newValue
            saveProviderConfig(newValue, forKey: Keys.geminiConfig)
        }
    }
    
    // MARK: - OpenAI 配置
    
    var openaiConfig: ProviderConfig {
        get { _openaiConfig }
        set {
            _openaiConfig = newValue
            saveProviderConfig(newValue, forKey: Keys.openaiConfig)
        }
    }
    
    // MARK: - 当前配置快捷访问
    
    var currentConfig: ProviderConfig {
        get {
            switch currentProvider {
            case .gemini: return geminiConfig
            case .openai: return openaiConfig
            }
        }
        set {
            switch currentProvider {
            case .gemini: geminiConfig = newValue
            case .openai: openaiConfig = newValue
            }
        }
    }
    
    /// 当前 API Key
    var apiKey: String {
        get { currentConfig.apiKey }
        set {
            var config = currentConfig
            config.apiKey = newValue
            currentConfig = config
        }
    }
    
    /// 当前 Base URL
    var baseURL: String {
        get { currentConfig.baseURL }
        set {
            var config = currentConfig
            config.baseURL = newValue
            currentConfig = config
        }
    }
    
    /// 当前模型名称
    var modelName: String {
        get {
            // 确保返回的模型在列表中
            let model = currentConfig.selectedModel
            if currentConfig.models.contains(model) {
                return model
            }
            return currentConfig.models.first ?? ""
        }
        set {
            // 只有当新值在模型列表中时才设置
            if currentConfig.models.contains(newValue) {
                var config = currentConfig
                config.selectedModel = newValue
                currentConfig = config
            }
        }
    }
    
    /// 当前可用模型列表
    var availableModels: [String] {
        currentConfig.models
    }
    
    // MARK: - 通用配置
    
    var temperature: Double {
        get { _temperature }
        set {
            _temperature = newValue
            defaults.set(newValue, forKey: Keys.temperature)
        }
    }
    
    var maxTokens: Int {
        get { _maxTokens }
        set {
            _maxTokens = newValue
            defaults.set(newValue, forKey: Keys.maxTokens)
        }
    }
    
    var streamEnabled: Bool {
        get {
            if defaults.object(forKey: Keys.streamEnabled) == nil { return true }
            return defaults.bool(forKey: Keys.streamEnabled)
        }
        set { defaults.set(newValue, forKey: Keys.streamEnabled) }
    }
    
    var includeThoughts: Bool {
        get { defaults.bool(forKey: Keys.includeThoughts) }
        set { defaults.set(newValue, forKey: Keys.includeThoughts) }
    }
    
    var fontSize: Double {
        get { _fontSize }
        set {
            _fontSize = newValue
            defaults.set(newValue, forKey: Keys.fontSize)
        }
    }
    
    // MARK: - 计算属性
    
    var isConfigured: Bool {
        !apiKey.isEmpty && !baseURL.isEmpty && !modelName.isEmpty
    }
    
    /// Gemini API URL
    var geminiURL: String {
        let url = geminiConfig.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(url)/models/\(geminiConfig.selectedModel):generateContent"
    }
    
    /// Gemini 流式 API URL
    var geminiStreamURL: String {
        let url = geminiConfig.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(url)/models/\(geminiConfig.selectedModel):streamGenerateContent?alt=sse"
    }
    
    /// OpenAI API URL
    var openaiURL: String {
        let url = openaiConfig.baseURL.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return "\(url)/chat/completions"
    }
    
    // MARK: - 模型管理
    
    func addModel(_ model: String) {
        var config = currentConfig
        if !config.models.contains(model) {
            config.models.append(model)
            currentConfig = config
        }
    }
    
    func removeModel(_ model: String) {
        var config = currentConfig
        config.models.removeAll { $0 == model }
        if config.models.isEmpty {
            config.models = currentProvider.defaultModels
        }
        if config.selectedModel == model {
            config.selectedModel = config.models.first ?? ""
        }
        currentConfig = config
    }
    
    func resetModels() {
        var config = currentConfig
        config.models = currentProvider.defaultModels
        if !config.models.contains(config.selectedModel) {
            config.selectedModel = config.models.first ?? ""
        }
        currentConfig = config
    }
    
    // MARK: - 私有方法
    
    private func saveProviderConfig(_ config: ProviderConfig, forKey key: String) {
        if let data = try? JSONEncoder().encode(config) {
            defaults.set(data, forKey: key)
        }
    }
    
    private static func loadProviderConfig(forKey key: String, default defaultConfig: ProviderConfig) -> ProviderConfig {
        guard let data = UserDefaults.standard.data(forKey: key),
              let config = try? JSONDecoder().decode(ProviderConfig.self, from: data) else {
            return defaultConfig
        }
        return config
    }
    
    private init() {
        // 加载当前供应商
        if let providerRaw = defaults.string(forKey: Keys.currentProvider),
           let provider = AIProvider(rawValue: providerRaw) {
            _currentProvider = provider
        }
        
        // 加载供应商配置
        _geminiConfig = Self.loadProviderConfig(forKey: Keys.geminiConfig, default: ProviderConfig(provider: .gemini))
        _openaiConfig = Self.loadProviderConfig(forKey: Keys.openaiConfig, default: ProviderConfig(provider: .openai))
        
        // 验证并修复 selectedModel（确保它在 models 列表中）
        validateAndFixSelectedModel()
        
        // 加载通用配置
        if defaults.object(forKey: Keys.temperature) != nil {
            _temperature = defaults.double(forKey: Keys.temperature)
        }
        
        let maxTokensValue = defaults.integer(forKey: Keys.maxTokens)
        _maxTokens = maxTokensValue == 0 ? 4096 : maxTokensValue
        
        let fontSizeValue = defaults.double(forKey: Keys.fontSize)
        _fontSize = fontSizeValue == 0 ? 16 : fontSizeValue
    }
    
    /// 验证并修复 selectedModel，确保它在 models 列表中
    private func validateAndFixSelectedModel() {
        // 验证 Gemini 配置
        if !_geminiConfig.models.contains(_geminiConfig.selectedModel) {
            _geminiConfig.selectedModel = _geminiConfig.models.first ?? AIProvider.gemini.defaultModels.first ?? ""
            saveProviderConfig(_geminiConfig, forKey: Keys.geminiConfig)
        }
        
        // 验证 OpenAI 配置
        if !_openaiConfig.models.contains(_openaiConfig.selectedModel) {
            _openaiConfig.selectedModel = _openaiConfig.models.first ?? AIProvider.openai.defaultModels.first ?? ""
            saveProviderConfig(_openaiConfig, forKey: Keys.openaiConfig)
        }
    }
}
