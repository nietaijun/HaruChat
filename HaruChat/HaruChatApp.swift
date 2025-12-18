//
//  HaruChatApp.swift
//  HaruChat
//
//  Created by 玩忽所以 on 2025/12/6.
//

import SwiftUI
import SwiftData

@main
struct HaruChatApp: App {
    /// SwiftData 模型容器
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            ChatSession.self,
            ChatMessage.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("无法创建 ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            SplashScreenWrapper {
                ContentView()
            }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .windowStyle(.automatic)
        .defaultSize(width: 1000, height: 700)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("新建对话") {
                    NotificationCenter.default.post(name: .newChat, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            CommandGroup(after: .appSettings) {
                Button("设置...") {
                    NotificationCenter.default.post(name: .openSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
        #endif
        
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let newChat = Notification.Name("newChat")
    static let openSettings = Notification.Name("openSettings")
}

// MARK: - 启动页包装器

struct SplashScreenWrapper<Content: View>: View {
    @ViewBuilder let content: () -> Content
    
    @State private var isLoading = true
    @State private var logoScale: CGFloat = 0.5
    @State private var logoOpacity: Double = 0
    @State private var textOpacity: Double = 0
    @State private var loadingRotation: Double = 0
    
    var body: some View {
        ZStack {
            // 主内容
            content()
                .opacity(isLoading ? 0 : 1)
            
            // 启动页
            if isLoading {
                splashScreen
                    .transition(.opacity.combined(with: .scale(scale: 1.1)))
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private var splashScreen: some View {
        ZStack {
            // 背景
            splashBackground
            
            VStack(spacing: 24) {
                // Logo 动画
                ZStack {
                    // 外圈旋转光环
                    Circle()
                        .stroke(
                            AngularGradient(
                                colors: [
                                    Color(hex: "10b981").opacity(0.8),
                                    Color(hex: "4285F4").opacity(0.6),
                                    Color(hex: "EA4335").opacity(0.4),
                                    Color(hex: "10b981").opacity(0.8)
                                ],
                                center: .center
                            ),
                            lineWidth: 3
                        )
                        .frame(width: 90, height: 90)
                        .rotationEffect(.degrees(loadingRotation))
                    
                    // 内圈背景
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "10b981"), Color(hex: "059669")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: Color(hex: "10b981").opacity(0.5), radius: 20, x: 0, y: 10)
                    
                    // App Logo
                    AppSplashLogo(size: 44)
                }
                .scaleEffect(logoScale)
                .opacity(logoOpacity)
                
                // 应用名称
                VStack(spacing: 8) {
                    Text("HaruChat")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(hex: "10b981"), Color(hex: "059669")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                    
                    Text("智能对话助手")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .opacity(textOpacity)
                
                // 加载指示器
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.8)
                    .opacity(textOpacity)
                    .padding(.top, 20)
            }
        }
    }
    
    private var splashBackground: some View {
        #if os(iOS)
        Color(UIColor.systemBackground)
            .ignoresSafeArea()
        #else
        Color(NSColor.windowBackgroundColor)
            .ignoresSafeArea()
        #endif
    }
    
    private func startAnimations() {
        // Logo 缩放和淡入
        withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) {
            logoScale = 1.0
            logoOpacity = 1.0
        }
        
        // 文字淡入
        withAnimation(.easeOut(duration: 0.4).delay(0.3)) {
            textOpacity = 1.0
        }
        
        // 旋转动画
        withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
            loadingRotation = 360
        }
        
        // 延迟后隐藏启动页
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.4)) {
                isLoading = false
            }
        }
    }
}

// MARK: - 启动页 Logo（优先使用自定义图片）

struct AppSplashLogo: View {
    let size: CGFloat
    
    @State private var hasCustomLogo: Bool = false
    
    var body: some View {
        Group {
            if hasCustomLogo {
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
            } else {
                Image(systemName: "leaf.fill")
                    .font(.system(size: size, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .onAppear {
            checkCustomLogo()
        }
    }
    
    private func checkCustomLogo() {
        #if os(iOS)
        hasCustomLogo = UIImage(named: "AppLogo") != nil
        #else
        hasCustomLogo = NSImage(named: "AppLogo") != nil
        #endif
    }
}
