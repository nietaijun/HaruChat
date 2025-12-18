//
//  ContentView.swift
//  HaruChat
//
//  Created by 玩忽所以 on 2025/12/6.
//

import SwiftUI
import SwiftData

/// 主内容视图 - 根据平台自适应布局
struct ContentView: View {
    @State private var viewModel = ChatViewModel()
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        #if os(macOS)
        macOSLayout
        #else
        iOSLayout
        #endif
    }
    
    // MARK: - macOS Layout
    
    #if os(macOS)
    private var macOSLayout: some View {
        NavigationSplitView {
            ChatListView(viewModel: viewModel)
                .frame(minWidth: 280)
        } detail: {
            Group {
                if viewModel.currentSession != nil {
                    ChatView(viewModel: viewModel)
                } else {
                    WelcomeView(viewModel: viewModel)
                }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    ModelSelectorView(viewModel: viewModel)
                }
                
                ToolbarItem(placement: .automatic) {
                    TokenUsageView(viewModel: viewModel)
                }
            }
        }
        .frame(minWidth: 900, minHeight: 650)
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
    }
    #endif
    
    // MARK: - iOS Layout
    
    #if os(iOS)
    private var iOSLayout: some View {
        iOSMainView(viewModel: viewModel)
            .onAppear {
                viewModel.setModelContext(modelContext)
            }
    }
    #endif
}

// MARK: - iOS 主视图

#if os(iOS)
struct iOSMainView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var showSettings = false
    @State private var showSessionList = false
    
    var body: some View {
        NavigationStack {
            // 主聊天区域
            Group {
                if viewModel.currentSession != nil {
                    ChatView(viewModel: viewModel)
                } else {
                    iOSWelcomeView(viewModel: viewModel)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // 左上角：设置按钮
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color(hex: "10b981"))
                    }
                }
                
                // 中间：模型选择器（始终显示）
                ToolbarItem(placement: .principal) {
                    iOSModelSelector(viewModel: viewModel, showSessionList: $showSessionList)
                }
                
                // 右上角：新建会话 / 历史记录
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        // 历史记录按钮
                        Button {
                            showSessionList = true
                        } label: {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 16))
                                .foregroundStyle(.secondary)
                        }
                        
                        // 新建会话按钮
                        Button {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                viewModel.createNewSession()
                            }
                            HapticManager.impact(.medium)
                        } label: {
                            Image(systemName: "square.and.pencil")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Color(hex: "10b981"))
                        }
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showSessionList) {
                iOSSessionListSheet(viewModel: viewModel, isPresented: $showSessionList)
            }
        }
    }
}

// MARK: - iOS 欢迎视图

struct iOSWelcomeView: View {
    @Bindable var viewModel: ChatViewModel
    @Bindable private var settings = AppSettings.shared
    @FocusState private var isInputFocused: Bool
    @State private var inputText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Logo 和欢迎语
            VStack(spacing: 16) {
                // 使用当前供应商图标
                ZStack {
                    Circle()
                        .fill(providerBackgroundGradient)
                        .frame(width: 70, height: 70)
                    
                    ProviderIcon(provider: settings.currentProvider, size: 50)
                }
                
                // 欢迎语
                VStack(spacing: 6) {
                    Text("你好，有什么可以帮你的？")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    
                    Text("输入消息开始新的对话")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 30)
            
            Spacer()
            
            // 底部输入框
            iOSWelcomeInputArea(
                inputText: $inputText,
                isInputFocused: $isInputFocused,
                viewModel: viewModel,
                settings: settings
            )
        }
        .background(Color(UIColor.systemGroupedBackground).ignoresSafeArea())
    }
    
    private var providerBackgroundGradient: LinearGradient {
        switch settings.currentProvider {
        case .gemini:
            return LinearGradient(
                colors: [Color(hex: "4285F4").opacity(0.2), Color(hex: "EA4335").opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .openai:
            return LinearGradient(
                colors: [Color(hex: "10a37f").opacity(0.2), Color(hex: "1a7f5a").opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
}

// MARK: - iOS 欢迎输入区域

struct iOSWelcomeInputArea: View {
    @Binding var inputText: String
    @FocusState.Binding var isInputFocused: Bool
    @Bindable var viewModel: ChatViewModel
    @Bindable var settings: AppSettings
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(alignment: .bottom, spacing: 0) {
                // Google 搜索按钮
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        viewModel.toggleGoogleSearch()
                    }
                    HapticManager.impact(.light)
                } label: {
                    Image(systemName: viewModel.enableGoogleSearch ? "globe.americas.fill" : "globe.americas")
                        .font(.system(size: 18))
                        .foregroundStyle(viewModel.enableGoogleSearch ? Color(hex: "3b82f6") : .secondary)
                        .frame(width: 36, height: 36)
                        .background(
                            Circle()
                                .fill(viewModel.enableGoogleSearch ? Color(hex: "3b82f6").opacity(0.15) : Color.clear)
                        )
                }
                .padding(.leading, 6)
                
                // 输入框
                TextField("输入消息...", text: $inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: settings.fontSize))
                    .lineLimit(1...6)
                    .focused($isInputFocused)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 10)
                
                // 发送按钮
                Button {
                    startNewChat()
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(canSend ?
                                    LinearGradient(
                                        colors: [Color(hex: "10b981"), Color(hex: "059669")],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    ) :
                                    LinearGradient(colors: [Color.secondary.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                                )
                        )
                }
                .disabled(!canSend)
                .padding(.trailing, 6)
            }
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(UIColor.secondarySystemGroupedBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(
                                isInputFocused ? Color(hex: "10b981").opacity(0.5) : Color.secondary.opacity(0.2),
                                lineWidth: 1
                            )
                    )
            )
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
        }
    }
    
    private func startNewChat() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        HapticManager.impact(.medium)
        viewModel.createNewSession()
        viewModel.inputMessage = text
        inputText = ""
        
        Task {
            await viewModel.sendMessage()
        }
    }
}

// MARK: - iOS 模型选择器

struct iOSModelSelector: View {
    @Bindable var viewModel: ChatViewModel
    @Bindable private var settings = AppSettings.shared
    @Binding var showSessionList: Bool
    @State private var showModelPicker = false
    
    var body: some View {
        Button {
            showModelPicker = true
        } label: {
            HStack(spacing: 4) {
                // 根据当前供应商显示对应图标
                ProviderIcon(provider: settings.currentProvider, size: 14)
                
                Text(settings.modelName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showModelPicker) {
            iOSModelPickerSheet(settings: settings, isPresented: $showModelPicker)
        }
    }
}

// MARK: - iOS 模型选择弹窗

struct iOSModelPickerSheet: View {
    @Bindable var settings: AppSettings
    @Binding var isPresented: Bool
    @State private var newModelName: String = ""
    
    var body: some View {
        NavigationStack {
            List {
                // 供应商选择
                Section("供应商") {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Button {
                            if settings.currentProvider != provider {
                                settings.currentProvider = provider
                                HapticManager.selection()
                            }
                        } label: {
                            HStack(spacing: 12) {
                                ProviderIcon(provider: provider, size: 28)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(provider.displayName)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    
                                    Text(providerDescription(provider))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if settings.currentProvider == provider {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color(hex: "10b981"))
                                }
                            }
                        }
                    }
                }
                
                // 模型选择
                Section("选择模型") {
                    ForEach(settings.availableModels, id: \.self) { model in
                        Button {
                            settings.modelName = model
                            HapticManager.selection()
                            isPresented = false
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(model)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    
                                    Text(modelDescription(model))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                
                                Spacer()
                                
                                if settings.modelName == model {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Color(hex: "10b981"))
                                }
                            }
                        }
                    }
                }
                
                Section("添加自定义模型") {
                    HStack {
                        TextField("模型名称", text: $newModelName)
                        
                        Button {
                            let trimmed = newModelName.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !trimmed.isEmpty {
                                settings.addModel(trimmed)
                                settings.modelName = trimmed
                                newModelName = ""
                                isPresented = false
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(newModelName.isEmpty ? .secondary : Color(hex: "10b981"))
                        }
                        .disabled(newModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
            .navigationTitle("模型")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func modelDescription(_ model: String) -> String {
        // Gemini 模型
        if model.contains("3-pro") { return "最新旗舰模型" }
        if model.contains("2.5-pro") { return "强大深度推理" }
        if model.contains("2.5-flash") { return "快速且智能" }
        if model.contains("2.0") { return "稳定可靠" }
        if model.contains("1.5") { return "经典模型" }
        // OpenAI 模型
        if model.contains("gpt-4o") && !model.contains("mini") { return "最强多模态模型" }
        if model.contains("gpt-4o-mini") { return "轻量快速" }
        if model.contains("gpt-4-turbo") { return "高性能模型" }
        if model.contains("gpt-3.5") { return "经济实惠" }
        return "自定义模型"
    }
    
    private func providerDescription(_ provider: AIProvider) -> String {
        switch provider {
        case .gemini:
            return "Google AI，支持搜索和思考"
        case .openai:
            return "OpenAI ChatGPT"
        }
    }
}

// MARK: - iOS 会话列表弹窗

struct iOSSessionListSheet: View {
    @Bindable var viewModel: ChatViewModel
    @Binding var isPresented: Bool
    @Query(sort: \ChatSession.updatedAt, order: .reverse) private var sessions: [ChatSession]
    @State private var searchText: String = ""
    
    private var filteredSessions: [ChatSession] {
        if searchText.isEmpty { return sessions }
        return sessions.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        NavigationStack {
            List {
                if filteredSessions.isEmpty {
                    ContentUnavailableView("暂无对话", systemImage: "tray", description: Text("开始一个新的对话吧"))
                } else {
                    ForEach(filteredSessions) { session in
                        Button {
                            viewModel.selectSession(session)
                            HapticManager.selection()
                            isPresented = false
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(session.title)
                                        .font(.body)
                                        .fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    if viewModel.currentSession?.id == session.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(Color(hex: "10b981"))
                                            .font(.caption)
                                    }
                                }
                                
                                if let lastMessage = session.sortedMessages.last {
                                    Text(lastMessage.content)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                
                                Text(session.updatedAt, style: .relative)
                                    .font(.caption2)
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                viewModel.deleteSession(session)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "搜索对话")
            .navigationTitle("历史对话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        viewModel.currentSession = nil
                        isPresented = false
                    } label: {
                        Text("新对话")
                            .foregroundStyle(Color(hex: "10b981"))
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        isPresented = false
                    }
                }
            }
        }
    }
}
#endif

// MARK: - 欢迎视图（macOS）

struct WelcomeView: View {
    @Bindable var viewModel: ChatViewModel
    @Bindable private var settings = AppSettings.shared
    @FocusState private var isInputFocused: Bool
    @State private var inputText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Logo 和欢迎语
            VStack(spacing: 20) {
                // Logo - 使用当前供应商图标
                ZStack {
                    Circle()
                        .fill(providerBackgroundGradient)
                        .frame(width: 80, height: 80)
                    
                    ProviderIcon(provider: settings.currentProvider, size: 56)
                }
                
                // 欢迎语
                VStack(spacing: 8) {
                    Text("你好，有什么可以帮你的？")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .foregroundStyle(.primary)
                    
                    Text("输入消息开始新的对话")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.bottom, 40)
            
            // 居中的输入框
            welcomeInputArea
                .frame(maxWidth: 600)
                .padding(.horizontal, 24)
            
            Spacer()
        }
        .background(welcomeBackground)
    }
    
    private var welcomeInputArea: some View {
        HStack(alignment: .bottom, spacing: 0) {
            // Google 搜索按钮
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    viewModel.toggleGoogleSearch()
                }
                HapticManager.impact(.light)
            } label: {
                Image(systemName: viewModel.enableGoogleSearch ? "globe.americas.fill" : "globe.americas")
                    .font(.system(size: 18))
                    .foregroundStyle(viewModel.enableGoogleSearch ? Color(hex: "3b82f6") : .secondary)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(viewModel.enableGoogleSearch ? Color(hex: "3b82f6").opacity(0.15) : Color.clear)
                    )
            }
            .buttonStyle(.plain)
            .help("Google 搜索")
            .padding(.leading, 8)
            
            // 输入框
            TextField("输入消息开始新对话...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: AppSettings.shared.fontSize))
                .lineLimit(1...6)
                .focused($isInputFocused)
                .onSubmit {
                    startNewChat()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
            
            // 发送按钮
            Button {
                startNewChat()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(
                        Circle()
                            .fill(canSend ? 
                                LinearGradient(
                                    colors: [Color(hex: "10b981"), Color(hex: "059669")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) : 
                                LinearGradient(colors: [Color.secondary.opacity(0.4)], startPoint: .top, endPoint: .bottom)
                            )
                    )
            }
            .buttonStyle(BounceButtonStyle())
            .disabled(!canSend)
            .padding(.trailing, 8)
        }
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 26)
                .fill(inputFieldBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 26)
                        .strokeBorder(
                            isInputFocused ? Color(hex: "10b981").opacity(0.5) : Color.secondary.opacity(0.2),
                            lineWidth: 1.5
                        )
                )
                .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
        )
    }
    
    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var inputFieldBackground: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemGroupedBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    private var welcomeBackground: some View {
        #if os(iOS)
        Color(UIColor.systemGroupedBackground)
            .ignoresSafeArea()
        #else
        Color(NSColor.windowBackgroundColor)
            .ignoresSafeArea()
        #endif
    }
    
    private var providerBackgroundGradient: LinearGradient {
        switch settings.currentProvider {
        case .gemini:
            return LinearGradient(
                colors: [Color(hex: "4285F4").opacity(0.2), Color(hex: "EA4335").opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .openai:
            return LinearGradient(
                colors: [Color(hex: "10a37f").opacity(0.2), Color(hex: "1a7f5a").opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private func startNewChat() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        HapticManager.impact(.medium)
        
        // 创建新会话并发送消息
        viewModel.createNewSession()
        viewModel.inputMessage = text
        inputText = ""
        
        Task {
            await viewModel.sendMessage()
        }
    }
}

// MARK: - 模型选择器 (macOS)

struct ModelSelectorView: View {
    @Bindable var viewModel: ChatViewModel
    @Bindable private var settings = AppSettings.shared
    @State private var showModelPicker = false
    
    var body: some View {
        Button {
            showModelPicker.toggle()
        } label: {
            HStack(spacing: 6) {
                // 供应商图标
                ProviderIcon(provider: settings.currentProvider, size: 16)
                
                // 模型名称
                Text(settings.modelName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                // 下拉箭头
                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showModelPicker) {
            modelPickerContent
        }
    }
    
    private var modelPickerContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 供应商切换
            HStack {
                Text("供应商")
                    .font(.headline)
                
                Spacer()
                
                Picker("", selection: $settings.currentProvider) {
                    ForEach(AIProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            Divider()
            
            // 模型列表
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(settings.availableModels, id: \.self) { model in
                        ModelOptionRow(
                            modelName: model,
                            isSelected: settings.modelName == model
                        ) {
                            settings.modelName = model
                            showModelPicker = false
                            HapticManager.selection()
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 8)
                    
                    // 自定义模型输入
                    CustomModelInputView(settings: settings, showPicker: $showModelPicker)
                }
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 350)
        }
        .frame(width: 320)
    }
}

// MARK: - 自定义模型输入

struct CustomModelInputView: View {
    @Bindable var settings: AppSettings
    @Binding var showPicker: Bool
    @State private var customModelName: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("添加自定义模型")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 12)
            
            HStack(spacing: 8) {
                TextField("模型名称", text: $customModelName)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.1))
                    )
                
                Button {
                    let trimmed = customModelName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        settings.addModel(trimmed)
                        settings.modelName = trimmed
                        customModelName = ""
                        showPicker = false
                        HapticManager.selection()
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(customModelName.isEmpty ? .secondary : Color(hex: "10b981"))
                }
                .buttonStyle(.plain)
                .disabled(customModelName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
        }
    }
}

// MARK: - 模型选项行

struct ModelOptionRow: View {
    let modelName: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    @State private var isHovering = false
    @Bindable private var settings = AppSettings.shared
    
    private var modelInfo: (icon: String, color: Color, description: String) {
        // Gemini 模型
        if modelName.contains("3-pro") || modelName.contains("3.0-pro") {
            return ("sparkles", Color(hex: "ec4899"), "最新旗舰模型")
        } else if modelName.contains("2.5-pro") {
            return ("sparkles", Color(hex: "a855f7"), "强大深度推理")
        } else if modelName.contains("2.5-flash") {
            return ("bolt.fill", Color(hex: "f59e0b"), "快速且智能")
        } else if modelName.contains("2.0") {
            return ("star.fill", Color(hex: "3b82f6"), "稳定可靠")
        } else if modelName.contains("1.5-pro") {
            return ("brain", Color(hex: "10b981"), "深度推理")
        } else if modelName.contains("1.5-flash") {
            return ("bolt", Color(hex: "6366f1"), "轻量快速")
        }
        // OpenAI 模型
        else if modelName.contains("gpt-4o") && !modelName.contains("mini") {
            return ("sparkles", Color(hex: "10a37f"), "最强多模态模型")
        } else if modelName.contains("gpt-4o-mini") {
            return ("bolt.fill", Color(hex: "19c37d"), "轻量快速")
        } else if modelName.contains("gpt-4-turbo") {
            return ("bolt", Color(hex: "00a67e"), "高性能模型")
        } else if modelName.contains("gpt-3.5") {
            return ("leaf.fill", Color(hex: "10a37f"), "经济实惠")
        } else if modelName.contains("o1") || modelName.contains("o3") {
            return ("brain.head.profile", Color(hex: "10a37f"), "推理模型")
        }
        // 自定义模型 - 根据供应商显示不同图标
        else {
            switch settings.currentProvider {
            case .gemini:
                return ("wand.and.stars", Color(hex: "4285F4"), "自定义模型")
            case .openai:
                return ("wand.and.stars", Color(hex: "10a37f"), "自定义模型")
            }
        }
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // 图标
                ZStack {
                    Circle()
                        .fill(modelInfo.color.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: modelInfo.icon)
                        .font(.system(size: 14))
                        .foregroundStyle(modelInfo.color)
                }
                
                // 信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(modelName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Text(modelInfo.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // 选中标记
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color(hex: "10b981"))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        isSelected
                        ? Color(hex: "10b981").opacity(0.1)
                        : (isHovering ? Color.secondary.opacity(0.08) : Color.clear)
                    )
            )
            .padding(.horizontal, 8)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Token 使用量显示

struct TokenUsageView: View {
    @Bindable var viewModel: ChatViewModel
    @State private var showDetails = false
    
    var body: some View {
        Button {
            showDetails.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(tokenColor)
                
                Text(formatTokenCount(viewModel.sessionTotalTokens))
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
        .help("Token 使用量")
        .popover(isPresented: $showDetails) {
            tokenDetailsView
        }
    }
    
    private var tokenColor: Color {
        if viewModel.sessionTotalTokens > 50000 {
            return Color(hex: "ef476f")
        } else if viewModel.sessionTotalTokens > 20000 {
            return Color(hex: "ffd166")
        } else {
            return Color(hex: "10b981")
        }
    }
    
    private var tokenDetailsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "chart.bar.fill")
                    .foregroundStyle(Color(hex: "10b981"))
                Text("Token 使用统计")
                    .font(.headline)
            }
            .padding(.bottom, 4)
            
            Divider()
            
            // 当前会话统计
            VStack(alignment: .leading, spacing: 8) {
                Text("当前会话")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                HStack {
                    Text("总计")
                    Spacer()
                    Text("\(viewModel.sessionTotalTokens)")
                        .fontWeight(.semibold)
                        .foregroundStyle(tokenColor)
                }
                .font(.subheadline)
            }
            
            // 最近请求统计
            if let usage = viewModel.lastTokenUsage {
                Divider()
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("最近请求")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    VStack(spacing: 6) {
                        TokenStatRow(label: "输入", value: usage.promptTokens, color: .blue)
                        TokenStatRow(label: "输出", value: usage.completionTokens, color: .green)
                        TokenStatRow(label: "合计", value: usage.totalTokens, color: .primary)
                    }
                }
            }
            
            Divider()
            
            // 提示
            Text("Token 数量影响 API 费用和上下文长度")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(16)
        .frame(width: 220)
    }
    
    private func formatTokenCount(_ count: Int) -> String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000)
        }
        return "\(count)"
    }
}

// MARK: - Token 统计行

struct TokenStatRow: View {
    let label: String
    let value: Int
    let color: Color
    
    var body: some View {
        HStack {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            
            Text(label)
                .font(.caption)
            
            Spacer()
            
            Text("\(value)")
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Google Gemini 图标

// GoogleGeminiIcon 已移至 SettingsView.swift 中作为 GeminiIconDefault

#Preview {
    ContentView()
        .modelContainer(for: [ChatSession.self, ChatMessage.self], inMemory: true)
}
