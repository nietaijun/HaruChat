//
//  MessageBubble.swift
//  HaruChat
//
//  Created by 玩忽所以 on 2025/12/6.
//

import SwiftUI

/// 消息气泡组件
struct MessageBubble: View {
    let message: ChatMessage
    let fontSize: Double
    let isStreaming: Bool
    let onRegenerate: (() -> Void)?
    let onCopy: (() -> Void)?
    
    @State private var isThinkingExpanded: Bool = false
    @State private var isHovering: Bool = false
    @State private var showActions: Bool = false
    
    init(
        message: ChatMessage,
        fontSize: Double = 16,
        isStreaming: Bool = false,
        onRegenerate: (() -> Void)? = nil,
        onCopy: (() -> Void)? = nil
    ) {
        self.message = message
        self.fontSize = fontSize
        self.isStreaming = isStreaming
        self.onRegenerate = onRegenerate
        self.onCopy = onCopy
    }
    
    private var isUser: Bool {
        message.role == .user
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isUser {
                Spacer(minLength: 50)
                messageContent
                AvatarView(isUser: true)
            } else {
                AvatarView(isUser: false)
                messageContent
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
    
    // MARK: - 消息内容
    
    private var messageContent: some View {
        VStack(alignment: isUser ? .trailing : .leading, spacing: 8) {
            // 思考内容（如果有）
            if !isUser && message.hasThinking {
                ThinkingBubble(
                    content: message.thinkingContent ?? "",
                    fontSize: fontSize,
                    isExpanded: $isThinkingExpanded
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity
                ))
            }
            
            // 消息气泡
            VStack(alignment: .leading, spacing: 0) {
                if isUser {
                    // 用户消息 - 简单文本
                    Text(message.content)
                        .font(.system(size: fontSize))
                        .foregroundStyle(.white)
                        .textSelection(.enabled)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                } else {
                    // 助手消息 - Markdown 渲染
                    MarkdownView(message.content, isUser: false, fontSize: fontSize)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
            }
            .background(
                Group {
                    if isUser {
                        RoundedRectangle(cornerRadius: AppTheme.bubbleCornerRadius)
                            .fill(AppTheme.userGradient)
                    } else {
                        RoundedRectangle(cornerRadius: AppTheme.bubbleCornerRadius)
                            .fill(AppTheme.assistantBubbleBackground)
                    }
                }
            )
            .bubbleShadow()
            .contextMenu {
                messageContextMenu
            }
            
            // 底部信息栏
            HStack(spacing: 12) {
                // 时间戳
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                
                // 操作按钮（悬停时显示）
                if isHovering && !isUser {
                    HStack(spacing: 8) {
                        ActionButton(icon: "doc.on.doc", label: "复制") {
                            copyMessage()
                        }
                        
                        if onRegenerate != nil {
                            ActionButton(icon: "arrow.clockwise", label: "重新生成") {
                                onRegenerate?()
                            }
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .leading)))
                }
            }
            .padding(.horizontal, 4)
        }
    }
    
    // MARK: - 上下文菜单
    
    @ViewBuilder
    private var messageContextMenu: some View {
        Button {
            copyMessage()
        } label: {
            Label("复制", systemImage: "doc.on.doc")
        }
        
        if !isUser {
            Button {
                onRegenerate?()
            } label: {
                Label("重新生成", systemImage: "arrow.clockwise")
            }
        }
        
        Divider()
        
        Button(role: .destructive) {
            // 删除消息
        } label: {
            Label("删除", systemImage: "trash")
        }
    }
    
    private func copyMessage() {
        #if os(iOS)
        UIPasteboard.general.string = message.content
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
        #endif
        HapticManager.notification(.success)
    }
}

// MARK: - 操作按钮

struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    @State private var isHovering = false
    
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(6)
                .background(
                    Circle()
                        .fill(Color.secondary.opacity(isHovering ? 0.15 : 0.08))
                )
        }
        .buttonStyle(.plain)
        .help(label)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - 思考内容气泡

struct ThinkingBubble: View {
    let content: String
    let fontSize: Double
    @Binding var isExpanded: Bool
    
    init(content: String, fontSize: Double = 16, isExpanded: Binding<Bool>) {
        self.content = content
        self.fontSize = fontSize
        self._isExpanded = isExpanded
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
                HapticManager.selection()
            } label: {
                HStack(spacing: 8) {
                    // 动画图标
                    ZStack {
                        Circle()
                            .fill(AppTheme.thinkingGradient)
                            .frame(width: 24, height: 24)
                        
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 12))
                            .foregroundStyle(Color(hex: "c77dff"))
                    }
                    
                    Text("思考过程")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            
            // 展开的内容
            if isExpanded {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .padding(.horizontal, 12)
                    
                    ScrollView {
                        Text(content)
                            .font(.system(size: fontSize - 1))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                    .frame(maxHeight: 200)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "e0aaff").opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color(hex: "e0aaff").opacity(0.5), Color(hex: "c77dff").opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - 流式消息气泡

struct StreamingMessageBubble: View {
    let content: String
    let thinkingContent: String
    let isThinking: Bool
    let fontSize: Double
    
    @State private var isThinkingExpanded: Bool = true
    
    init(content: String, thinkingContent: String, isThinking: Bool, fontSize: Double = 16) {
        self.content = content
        self.thinkingContent = thinkingContent
        self.isThinking = isThinking
        self.fontSize = fontSize
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(isUser: false, isAnimating: true)
            
            VStack(alignment: .leading, spacing: 8) {
                // 思考内容（流式）
                if !thinkingContent.isEmpty || isThinking {
                    StreamingThinkingBubble(
                        content: thinkingContent,
                        isThinking: isThinking,
                        fontSize: fontSize,
                        isExpanded: $isThinkingExpanded
                    )
                }
                
                // 正文内容
                if !content.isEmpty || !isThinking {
                    HStack(alignment: .bottom, spacing: 4) {
                        MarkdownView(content.isEmpty ? " " : content, isUser: false, fontSize: fontSize)
                        
                        if !isThinking {
                            TypingCursor()
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: AppTheme.bubbleCornerRadius)
                            .fill(AppTheme.assistantBubbleBackground)
                    )
                    .bubbleShadow()
                }
                
                // 状态提示
                HStack(spacing: 6) {
                    PulsingDot()
                    Text(isThinking ? "正在思考..." : "正在生成...")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 4)
            }
            
            Spacer(minLength: 50)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
}

// MARK: - 流式思考气泡

struct StreamingThinkingBubble: View {
    let content: String
    let isThinking: Bool
    let fontSize: Double
    @Binding var isExpanded: Bool
    
    init(content: String, isThinking: Bool, fontSize: Double = 16, isExpanded: Binding<Bool>) {
        self.content = content
        self.isThinking = isThinking
        self.fontSize = fontSize
        self._isExpanded = isExpanded
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.thinkingGradient)
                            .frame(width: 24, height: 24)
                        
                        if isThinking {
                            ProgressView()
                                .controlSize(.mini)
                        } else {
                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 12))
                                .foregroundStyle(Color(hex: "c77dff"))
                        }
                    }
                    
                    Text(isThinking ? "思考中..." : "思考过程")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.primary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            
            if isExpanded && !content.isEmpty {
                VStack(alignment: .leading, spacing: 0) {
                    Divider()
                        .padding(.horizontal, 12)
                    
                    ScrollView {
                        Text(content)
                            .font(.system(size: fontSize - 1))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                    }
                    .frame(maxHeight: 150)
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .move(edge: .top)),
                    removal: .opacity
                ))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "e0aaff").opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(
                            LinearGradient(
                                colors: [Color(hex: "e0aaff").opacity(0.5), Color(hex: "c77dff").opacity(0.5)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
        )
    }
}

// MARK: - 头像视图

struct AvatarView: View {
    let isUser: Bool
    var isAnimating: Bool = false
    
    @Bindable private var settings = AppSettings.shared
    @State private var animationActive = false
    
    var body: some View {
        ZStack {
            if isUser {
                // 用户头像
                userAvatar
            } else {
                // AI 头像 - 使用供应商图标
                aiAvatar
            }
        }
        .shadow(color: avatarShadowColor.opacity(0.25), radius: 6, x: 0, y: 3)
        .onAppear {
            if isAnimating {
                animationActive = true
            }
        }
    }
    
    // MARK: - 用户头像
    private var userAvatar: some View {
        ZStack {
            Circle()
                .fill(AppTheme.userAvatarBackground)
                .frame(width: AppTheme.avatarSize, height: AppTheme.avatarSize)
            
            Circle()
                .fill(Color.white)
                .frame(width: AppTheme.avatarSize - 4, height: AppTheme.avatarSize - 4)
            
            Image(systemName: "person.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "ff9f1c"), Color(hex: "f77f00")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
    }
    
    // MARK: - AI 头像（使用供应商图标）
    private var aiAvatar: some View {
        ZStack {
            // 外圈 - 根据供应商改变颜色
            Circle()
                .fill(aiAvatarGradient)
                .frame(width: AppTheme.avatarSize, height: AppTheme.avatarSize)
            
            // 内圈白色背景
            Circle()
                .fill(Color.white)
                .frame(width: AppTheme.avatarSize - 4, height: AppTheme.avatarSize - 4)
            
            // 供应商图标
            ProviderIcon(provider: settings.currentProvider, size: AppTheme.avatarSize - 8)
                .scaleEffect(animationActive && isAnimating ? 1.05 : 1.0)
                .animation(
                    isAnimating ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true) : .default,
                    value: animationActive
                )
        }
    }
    
    // MARK: - 颜色配置
    private var aiAvatarGradient: LinearGradient {
        switch settings.currentProvider {
        case .gemini:
            return LinearGradient(
                colors: [Color(hex: "4285F4"), Color(hex: "EA4335")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .openai:
            return LinearGradient(
                colors: [Color(hex: "10a37f"), Color(hex: "1a7f5a")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }
    
    private var avatarShadowColor: Color {
        if isUser {
            return Color(hex: "ff9f1c")
        }
        switch settings.currentProvider {
        case .gemini:
            return Color(hex: "4285F4")
        case .openai:
            return Color(hex: "10a37f")
        }
    }
}

// MARK: - 打字光标动画

struct TypingCursor: View {
    @State private var isVisible = true
    
    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(Color(hex: "10b981"))
            .frame(width: 3, height: 18)
            .opacity(isVisible ? 1 : 0.2)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: isVisible)
            .onAppear {
                isVisible = false
            }
    }
}

// MARK: - 脉冲点动画

struct PulsingDot: View {
    @State private var isPulsing = false
    
    var body: some View {
        Circle()
            .fill(Color(hex: "10b981"))
            .frame(width: 6, height: 6)
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.6 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: isPulsing)
            .onAppear {
                isPulsing = true
            }
    }
}

// MARK: - 加载指示器

struct LoadingIndicator: View {
    @State private var isAnimating = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(isUser: false, isAnimating: true)
            
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Color(hex: "10b981"))
                        .frame(width: 10, height: 10)
                        .scaleEffect(isAnimating ? 1.0 : 0.6)
                        .opacity(isAnimating ? 1.0 : 0.4)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                            value: isAnimating
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: AppTheme.bubbleCornerRadius)
                    .fill(AppTheme.assistantBubbleBackground)
            )
            .bubbleShadow()
            
            Spacer(minLength: 50)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Previews

#Preview("User Message") {
    MessageBubble(
        message: ChatMessage(role: .user, content: "你好，请帮我写一段 Swift 代码"),
        fontSize: 16
    )
    .padding()
}

#Preview("Assistant Message") {
    MessageBubble(
        message: ChatMessage(role: .assistant, content: """
        你好！这是一段示例代码：
        
        ```swift
        struct ContentView: View {
            var body: some View {
                Text("Hello, World!")
            }
        }
        ```
        
        这段代码创建了一个简单的 **SwiftUI** 视图。
        """),
        fontSize: 16
    )
    .padding()
}

#Preview("With Thinking") {
    MessageBubble(
        message: ChatMessage(
            role: .assistant,
            content: "根据我的分析，答案是 42。",
            thinkingContent: "让我分析一下这个问题...\n\n1. 首先理解问题\n2. 考虑各种可能性\n3. 得出结论"
        ),
        fontSize: 16
    )
    .padding()
}

#Preview("Streaming") {
    StreamingMessageBubble(
        content: "我正在生成回复...",
        thinkingContent: "分析问题中...",
        isThinking: false,
        fontSize: 16
    )
    .padding()
}

#Preview("Loading") {
    LoadingIndicator()
        .padding()
}
