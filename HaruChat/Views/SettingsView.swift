//
//  SettingsView.swift
//  HaruChat
//
//  Created by 玩忽所以 on 2025/12/6.
//

import SwiftUI

/// 设置页面
struct SettingsView: View {
    @Bindable private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showAPIKey: Bool = false
    @State private var testingConnection: Bool = false
    @State private var connectionTestResult: ConnectionTestResult?
    @State private var showAddModel: Bool = false
    @State private var newModelName: String = ""
    
    enum ConnectionTestResult {
        case success
        case failure(String)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: - 供应商选择
                Section {
                    Picker("AI 供应商", selection: $settings.currentProvider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: settings.currentProvider) { _, _ in
                        connectionTestResult = nil
                    }
                } header: {
                    HStack(spacing: 8) {
                        ProviderIcon(provider: settings.currentProvider, size: 18)
                        Text("供应商")
                    }
                } footer: {
                    Text(providerDescription)
                }
                
                // MARK: - API 配置
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Base URL")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("API Base URL", text: currentBaseURLBinding)
                            .textFieldStyle(.plain)
                            #if os(iOS)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                            #endif
                            .autocorrectionDisabled()
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("API Key")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            if showAPIKey {
                                TextField("输入你的 API Key", text: currentAPIKeyBinding)
                                    .textFieldStyle(.plain)
                                    #if os(iOS)
                                    .autocapitalization(.none)
                                    #endif
                                    .autocorrectionDisabled()
                            } else {
                                SecureField("输入你的 API Key", text: currentAPIKeyBinding)
                                    .textFieldStyle(.plain)
                            }
                            
                            Button {
                                showAPIKey.toggle()
                            } label: {
                                Image(systemName: showAPIKey ? "eye.slash" : "eye")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // 测试连接按钮
                    Button {
                        Task { await testConnection() }
                    } label: {
                        HStack {
                            if testingConnection {
                                ProgressView().controlSize(.small)
                                Text("测试中...")
                            } else {
                                Image(systemName: "network")
                                Text("测试连接")
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(testingConnection || !settings.isConfigured)
                    
                    if let result = connectionTestResult {
                        HStack {
                            switch result {
                            case .success:
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                Text("连接成功！").foregroundStyle(.green)
                            case .failure(let message):
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                Text(message).foregroundStyle(.red).font(.caption)
                            }
                        }
                    }
                } header: {
                    Label("\(settings.currentProvider.displayName) 配置", systemImage: "key.fill")
                } footer: {
                    Text("默认 URL: \(settings.currentProvider.defaultBaseURL)")
                }
                
                // MARK: - 模型管理
                Section {
                    Picker("当前模型", selection: currentModelBinding) {
                        ForEach(settings.availableModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                    
                    ForEach(settings.availableModels, id: \.self) { model in
                        HStack {
                            Image(systemName: settings.modelName == model ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(settings.modelName == model ? Color(hex: "10b981") : .secondary)
                                .font(.system(size: 14))
                            
                            Text(model).font(.body)
                            
                            Spacer()
                            
                            if settings.availableModels.count > 1 {
                                Button {
                                    withAnimation { settings.removeModel(model) }
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                    
                    Button {
                        showAddModel = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill").foregroundStyle(Color(hex: "10b981"))
                            Text("添加模型")
                        }
                    }
                    
                    Button {
                        withAnimation { settings.resetModels() }
                    } label: {
                        HStack {
                            Image(systemName: "arrow.counterclockwise").foregroundStyle(.orange)
                            Text("重置为默认列表")
                        }
                    }
                } header: {
                    Label("模型管理", systemImage: "cpu")
                }
                
                // MARK: - 模型参数
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Temperature")
                            Spacer()
                            Text(String(format: "%.1f", settings.temperature))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: 40, alignment: .trailing)
                        }
                        Slider(value: $settings.temperature, in: 0...2, step: 0.1)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Max Tokens")
                            Spacer()
                            Text("\(settings.maxTokens)")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: 60, alignment: .trailing)
                        }
                        Slider(
                            value: Binding(
                                get: { Double(settings.maxTokens) },
                                set: { settings.maxTokens = Int($0) }
                            ),
                            in: 256...8192,
                            step: 256
                        )
                    }
                    
                    Toggle(isOn: $settings.streamEnabled) {
                        VStack(alignment: .leading) {
                            Text("流式输出")
                            Text("实时显示生成的内容").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    
                    if settings.currentProvider == .gemini {
                        Toggle(isOn: $settings.includeThoughts) {
                            VStack(alignment: .leading) {
                                Text("显示思考过程")
                                Text("查看 AI 的推理过程（仅 Gemini）").font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Label("模型参数", systemImage: "slider.horizontal.3")
                }
                
                // MARK: - 界面设置
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("字体大小")
                            Spacer()
                            Text("\(Int(settings.fontSize))pt")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                                .frame(width: 50, alignment: .trailing)
                        }
                        Slider(value: $settings.fontSize, in: 12...24, step: 1)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("预览效果").font(.caption).foregroundStyle(.secondary)
                        Text("你好，这是字体大小预览。Hello!")
                            .font(.system(size: settings.fontSize))
                            .padding(.vertical, 8)
                            .padding(.horizontal, 12)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.1)))
                    }
                } header: {
                    Label("界面设置", systemImage: "textformat.size")
                }
                
                // MARK: - 关于
                Section {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("1.0.0").foregroundStyle(.secondary)
                    }
                    
                    Link(destination: URL(string: "https://ai.google.dev/gemini-api/docs")!) {
                        HStack {
                            Text("Gemini API 文档")
                            Spacer()
                            Image(systemName: "arrow.up.right.square").foregroundStyle(.secondary)
                        }
                    }
                    
                    Link(destination: URL(string: "https://platform.openai.com/docs")!) {
                        HStack {
                            Text("OpenAI API 文档")
                            Spacer()
                            Image(systemName: "arrow.up.right.square").foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Label("关于", systemImage: "info.circle")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("设置")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            #else
            .frame(minWidth: 500, minHeight: 700)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
            }
            #endif
            .alert("添加模型", isPresented: $showAddModel) {
                TextField("模型名称", text: $newModelName)
                    #if os(iOS)
                    .autocapitalization(.none)
                    #endif
                Button("取消", role: .cancel) { newModelName = "" }
                Button("添加") {
                    let trimmed = newModelName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty { settings.addModel(trimmed) }
                    newModelName = ""
                }
            } message: {
                Text("输入模型名称")
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var providerDescription: String {
        switch settings.currentProvider {
        case .gemini:
            return "Google Gemini 支持思考过程和 Google 搜索功能"
        case .openai:
            return "OpenAI GPT 系列模型，兼容其他 OpenAI API 格式的服务"
        }
    }
    
    private var currentBaseURLBinding: Binding<String> {
        Binding(
            get: {
                switch settings.currentProvider {
                case .gemini: return settings.geminiConfig.baseURL
                case .openai: return settings.openaiConfig.baseURL
                }
            },
            set: { newValue in
                switch settings.currentProvider {
                case .gemini:
                    var config = settings.geminiConfig
                    config.baseURL = newValue
                    settings.geminiConfig = config
                case .openai:
                    var config = settings.openaiConfig
                    config.baseURL = newValue
                    settings.openaiConfig = config
                }
            }
        )
    }
    
    private var currentAPIKeyBinding: Binding<String> {
        Binding(
            get: {
                switch settings.currentProvider {
                case .gemini: return settings.geminiConfig.apiKey
                case .openai: return settings.openaiConfig.apiKey
                }
            },
            set: { newValue in
                switch settings.currentProvider {
                case .gemini:
                    var config = settings.geminiConfig
                    config.apiKey = newValue
                    settings.geminiConfig = config
                case .openai:
                    var config = settings.openaiConfig
                    config.apiKey = newValue
                    settings.openaiConfig = config
                }
            }
        )
    }
    
    private var currentModelBinding: Binding<String> {
        Binding(
            get: { settings.modelName },
            set: { settings.modelName = $0 }
        )
    }
    
    // MARK: - 测试连接
    
    private func testConnection() async {
        testingConnection = true
        connectionTestResult = nil
        
        do {
            let testMessage = ChatMessage(role: .user, content: "Hello")
            let response = try await APIService.shared.sendChatRequest(
                messages: [testMessage],
                settings: settings
            )
            
            if !response.content.isEmpty {
                connectionTestResult = .success
            } else {
                connectionTestResult = .failure("收到空响应")
            }
        } catch {
            if let apiError = error as? APIServiceError {
                connectionTestResult = .failure(apiError.errorDescription ?? "未知错误")
            } else {
                connectionTestResult = .failure(error.localizedDescription)
            }
        }
        
        testingConnection = false
    }
}

// MARK: - 供应商图标

// MARK: - 供应商图标
struct ProviderIcon: View {
    let provider: AIProvider
    let size: CGFloat
    /// 是否使用自定义图片（Assets 中的 GeminiLogo / OpenAILogo）
    var useCustomImage: Bool = true
    
    var body: some View {
        Group {
            switch provider {
            case .gemini:
                if useCustomImage {
                    CustomImageIcon(imageName: "GeminiLogo", size: size, fallback: {
                        GeminiIconDefault(size: size)
                    })
                } else {
                    GeminiIconDefault(size: size)
                }
            case .openai:
                if useCustomImage {
                    CustomImageIcon(imageName: "OpenAILogo", size: size, fallback: {
                        OpenAIIconDefault(size: size)
                    })
                } else {
                    OpenAIIconDefault(size: size)
                }
            }
        }
    }
}

// MARK: - 自定义图片图标（带 fallback）
struct CustomImageIcon<Fallback: View>: View {
    let imageName: String
    let size: CGFloat
    @ViewBuilder let fallback: () -> Fallback
    
    @State private var imageExists: Bool = false
    
    var body: some View {
        Group {
            if imageExists {
                Image(imageName)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                fallback()
            }
        }
        .onAppear {
            checkImageExists()
        }
    }
    
    private func checkImageExists() {
        #if os(iOS)
        imageExists = UIImage(named: imageName) != nil
        #else
        imageExists = NSImage(named: imageName) != nil
        #endif
    }
}

// MARK: - Gemini 默认图标
struct GeminiIconDefault: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                Rectangle().fill(Color(hex: "4285F4"))
                Rectangle().fill(Color(hex: "EA4335"))
            }
            .mask(
                Text("G")
                    .font(.system(size: size * 0.7, weight: .bold, design: .rounded))
            )
        }
        .frame(width: size, height: size)
    }
}

// MARK: - OpenAI 默认图标
struct OpenAIIconDefault: View {
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.black)
                .frame(width: size, height: size)
            
            Image(systemName: "hexagon")
                .font(.system(size: size * 0.55, weight: .medium))
                .foregroundStyle(.white)
        }
    }
}

#Preview {
    SettingsView()
}
