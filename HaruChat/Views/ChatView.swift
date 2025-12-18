//
//  ChatView.swift
//  HaruChat
//
//  Created by 玩忽所以 on 2025/12/6.
//

import SwiftUI
import SwiftData

/// 聊天视图
struct ChatView: View {
    @Bindable var viewModel: ChatViewModel
    @Bindable private var settings = AppSettings.shared
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // 消息列表
            messagesScrollView
            
            // 输入区域
            inputArea
        }
        .background(chatBackground)
        .navigationTitle(viewModel.currentSession?.title ?? "新对话")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert("错误", isPresented: $viewModel.showError) {
            Button("确定") {
                viewModel.dismissError()
            }
        } message: {
            Text(viewModel.errorMessage ?? "未知错误")
        }
    }
    
    // MARK: - 背景
    
    private var chatBackground: some View {
        #if os(iOS)
        Color(UIColor.systemGroupedBackground)
            .ignoresSafeArea()
        #else
        Color(NSColor.windowBackgroundColor)
            .ignoresSafeArea()
        #endif
    }
    
    // MARK: - 消息列表
    
    private var messagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    // 顶部间距
                    Color.clear.frame(height: 12)
                    
                    if let session = viewModel.currentSession {
                        ForEach(Array(session.sortedMessages.enumerated()), id: \.element.id) { index, message in
                            MessageBubble(
                                message: message,
                                fontSize: settings.fontSize,
                                onRegenerate: message.role == .assistant && index == session.sortedMessages.count - 1 ? {
                                    Task {
                                        await viewModel.regenerateLastMessage()
                                    }
                                } : nil
                            )
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)).combined(with: .scale(scale: 0.95)),
                                removal: .opacity
                            ))
                        }
                    }
                    
                    // 流式输出
                    if viewModel.isStreaming {
                        StreamingMessageBubble(
                            content: viewModel.streamingContent,
                            thinkingContent: viewModel.streamingThinking,
                            isThinking: viewModel.isThinking,
                            fontSize: settings.fontSize
                        )
                        .id("streaming")
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                    
                    // 加载中
                    if viewModel.isLoading && !viewModel.isStreaming {
                        LoadingIndicator()
                            .id("loading")
                            .transition(.opacity.combined(with: .scale))
                    }
                    
                    // 底部占位
                    Color.clear.frame(height: 8)
                        .id("bottom")
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.currentSession?.messages.count) { _, _ in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
            .onChange(of: viewModel.streamingContent) { _, _ in
                proxy.scrollTo("streaming", anchor: .bottom)
            }
            .onChange(of: viewModel.streamingThinking) { _, _ in
                proxy.scrollTo("streaming", anchor: .bottom)
            }
            .onChange(of: viewModel.isLoading) { _, isLoading in
                if isLoading {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
        }
    }
    
    // MARK: - 输入区域
    
    private var inputArea: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 16) {
                Spacer()
                
                // 输入框容器
                HStack(alignment: .bottom, spacing: 0) {
                    // Google 搜索按钮（仅 Gemini 供应商显示）
                    if settings.currentProvider == .gemini {
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
                        .padding(.leading, 6)
                    }
                    
                    // 输入框
                    TextField("输入消息...", text: $viewModel.inputMessage, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: settings.fontSize))
                        .lineLimit(1...6)
                        .focused($isInputFocused)
                        .onSubmit {
                            sendMessage()
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 10)
                    
                    // 发送/停止按钮（在输入框内右侧）
                    Group {
                        if viewModel.isLoading {
                            Button {
                                viewModel.stopGenerating()
                                HapticManager.impact(.medium)
                            } label: {
                                Image(systemName: "stop.fill")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(Circle().fill(Color.red))
                            }
                            .buttonStyle(BounceButtonStyle())
                        } else {
                            Button {
                                sendMessage()
                            } label: {
                                Image(systemName: "arrow.up")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .frame(width: 32, height: 32)
                                    .background(
                                        Circle()
                                            .fill(canSend ? AppTheme.sendButtonGradient : LinearGradient(colors: [Color.secondary.opacity(0.4)], startPoint: .top, endPoint: .bottom))
                                    )
                            }
                            .buttonStyle(BounceButtonStyle())
                            .disabled(!canSend)
                        }
                    }
                    .padding(.trailing, 6)
                }
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(inputFieldBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .strokeBorder(
                                    isInputFocused ? Color(hex: "10b981").opacity(0.5) : Color.secondary.opacity(0.2),
                                    lineWidth: 1
                                )
                        )
                )
                .frame(maxWidth: 700)
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(inputAreaBackground)
        }
    }
    
    private var inputFieldBackground: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemGroupedBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    private var canSend: Bool {
        !viewModel.inputMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    private var inputAreaBackground: some View {
        #if os(iOS)
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay(
                Rectangle()
                    .fill(Color(UIColor.systemBackground).opacity(0.8))
            )
        #else
        Rectangle()
            .fill(Color(NSColor.windowBackgroundColor))
        #endif
    }
    
    // MARK: - Actions
    
    private func sendMessage() {
        guard canSend else { return }
        HapticManager.impact(.medium)
        Task {
            await viewModel.sendMessage()
        }
    }
}

// MARK: - 空状态视图

struct EmptyStateView: View {
    var body: some View {
        // 空白页面，等待用户创建新对话
        Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct SuggestionChip: View {
    let text: String
    @State private var isHovering = false
    
    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule()
                    .fill(Color.secondary.opacity(isHovering ? 0.15 : 0.08))
            )
            .onHover { hovering in
                isHovering = hovering
            }
    }
}

#Preview {
    ChatView(viewModel: ChatViewModel())
}
