//
//  Theme.swift
//  HaruChat
//
//  Created by 玩忽所以 on 2025/12/6.
//

import SwiftUI

// MARK: - 主题颜色系统

/// 应用主题 - HaruChat 绿色清新风格
enum AppTheme {
    // MARK: - 主色调（绿色系）
    
    /// 主绿色
    static let primaryGreen = Color(hex: "10b981")
    
    /// 深绿色
    static let darkGreen = Color(hex: "059669")
    
    /// 浅绿色
    static let lightGreen = Color(hex: "34d399")
    
    // MARK: - 渐变色
    
    /// 用户消息渐变 - 蓝绿色
    static let userGradient = LinearGradient(
        colors: [Color(hex: "0ea5e9"), Color(hex: "0284c7")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// AI 消息渐变 - 清新绿色
    static let aiGradient = LinearGradient(
        colors: [Color(hex: "10b981"), Color(hex: "059669")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// 思考气泡渐变 - 柔和紫色
    static let thinkingGradient = LinearGradient(
        colors: [Color(hex: "e0aaff").opacity(0.3), Color(hex: "c77dff").opacity(0.3)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// 发送按钮渐变 - 绿色主题
    static let sendButtonGradient = LinearGradient(
        colors: [Color(hex: "10b981"), Color(hex: "059669")],
        startPoint: .top,
        endPoint: .bottom
    )
    
    /// Logo 渐变
    static let logoGradient = LinearGradient(
        colors: [Color(hex: "10b981"), Color(hex: "059669")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - 头像背景
    
    /// 用户头像背景 - 温暖橙色
    static let userAvatarBackground = LinearGradient(
        colors: [Color(hex: "ff9f1c"), Color(hex: "ffbf69")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    /// AI 头像背景 - 清新绿色
    static let aiAvatarBackground = LinearGradient(
        colors: [Color(hex: "10b981"), Color(hex: "059669")],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // MARK: - 背景色
    
    /// 代码块背景色
    static var codeBlockBackground: Color {
        #if os(iOS)
        Color(UIColor.secondarySystemBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    /// 助手消息背景 - 更亮的白色
    static var assistantBubbleBackground: Color {
        #if os(iOS)
        Color.white
        #else
        Color.white
        #endif
    }
    
    /// 输入框背景
    static var inputBackground: Color {
        #if os(iOS)
        Color(UIColor.tertiarySystemGroupedBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    // MARK: - 阴影
    
    /// 消息气泡阴影 - 更柔和
    static let bubbleShadow = Color.black.opacity(0.06)
    
    /// 卡片阴影
    static let cardShadow = Color.black.opacity(0.08)
    
    // MARK: - 动画时长
    
    static let quickAnimation: Double = 0.15
    static let normalAnimation: Double = 0.25
    static let slowAnimation: Double = 0.4
    
    // MARK: - 圆角
    
    static let bubbleCornerRadius: CGFloat = 20
    static let cardCornerRadius: CGFloat = 16
    static let buttonCornerRadius: CGFloat = 12
    static let avatarSize: CGFloat = 38
}

// MARK: - 颜色扩展

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - 视图修饰器

/// 气泡阴影修饰器
struct BubbleShadowModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .shadow(color: AppTheme.bubbleShadow, radius: 6, x: 0, y: 2)
    }
}

/// 卡片样式修饰器
struct CardStyleModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: AppTheme.cardCornerRadius)
                    .fill(.regularMaterial)
            )
            .shadow(color: AppTheme.cardShadow, radius: 10, x: 0, y: 4)
    }
}

/// 按钮缩放效果
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(.easeInOut(duration: AppTheme.quickAnimation), value: configuration.isPressed)
    }
}

/// 弹跳按钮效果
struct BounceButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.88 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}

extension View {
    func bubbleShadow() -> some View {
        modifier(BubbleShadowModifier())
    }
    
    func cardStyle() -> some View {
        modifier(CardStyleModifier())
    }
}

// MARK: - 动画扩展

extension Animation {
    static let bubbleAppear = Animation.spring(response: 0.4, dampingFraction: 0.7)
    static let quickSpring = Animation.spring(response: 0.3, dampingFraction: 0.7)
    static let smoothEase = Animation.easeInOut(duration: 0.25)
}

// MARK: - 触觉反馈

#if os(iOS)
enum HapticManager {
    enum NotificationType {
        case success
        case warning
        case error
        
        var uiType: UINotificationFeedbackGenerator.FeedbackType {
            switch self {
            case .success: return .success
            case .warning: return .warning
            case .error: return .error
            }
        }
    }
    
    enum ImpactStyle {
        case light
        case medium
        case heavy
        
        var uiStyle: UIImpactFeedbackGenerator.FeedbackStyle {
            switch self {
            case .light: return .light
            case .medium: return .medium
            case .heavy: return .heavy
            }
        }
    }
    
    static func impact(_ style: ImpactStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style.uiStyle)
        generator.impactOccurred()
    }
    
    static func notification(_ type: NotificationType) {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(type.uiType)
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.selectionChanged()
    }
}
#else
enum HapticManager {
    enum NotificationType {
        case success
        case warning
        case error
    }
    
    enum ImpactStyle {
        case light
        case medium
        case heavy
    }
    
    static func impact(_ style: ImpactStyle = .medium) {}
    static func notification(_ type: NotificationType) {}
    static func selection() {}
}
#endif
