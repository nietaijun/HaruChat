//
//  ChatListView.swift
//  HaruChat
//
//  Created by 玩忽所以 on 2025/12/6.
//

import SwiftUI
import SwiftData

/// 会话列表视图
struct ChatListView: View {
    @Bindable var viewModel: ChatViewModel
    @Query(sort: \ChatSession.updatedAt, order: .reverse) private var sessions: [ChatSession]
    @Environment(\.modelContext) private var modelContext
    
    @State private var showSettings: Bool = false
    @State private var sessionToRename: ChatSession?
    @State private var newTitle: String = ""
    @State private var searchText: String = ""
    
    private var filteredSessions: [ChatSession] {
        if searchText.isEmpty {
            return sessions
        }
        return sessions.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    private var groupedSessions: [(String, [ChatSession])] {
        let calendar = Calendar.current
        let now = Date()
        
        var today: [ChatSession] = []
        var yesterday: [ChatSession] = []
        var thisWeek: [ChatSession] = []
        var earlier: [ChatSession] = []
        
        for session in filteredSessions {
            if calendar.isDateInToday(session.updatedAt) {
                today.append(session)
            } else if calendar.isDateInYesterday(session.updatedAt) {
                yesterday.append(session)
            } else if let weekAgo = calendar.date(byAdding: .day, value: -7, to: now),
                      session.updatedAt > weekAgo {
                thisWeek.append(session)
            } else {
                earlier.append(session)
            }
        }
        
        var result: [(String, [ChatSession])] = []
        if !today.isEmpty { result.append(("今天", today)) }
        if !yesterday.isEmpty { result.append(("昨天", yesterday)) }
        if !thisWeek.isEmpty { result.append(("本周", thisWeek)) }
        if !earlier.isEmpty { result.append(("更早", earlier)) }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Logo 和标题
            headerView
            
            // 搜索栏
            searchBar
            
            // 新建会话按钮
            newSessionButton
            
            // 会话列表
            sessionList
            
            // 底部设置按钮
            bottomSettingsBar
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .alert("重命名对话", isPresented: Binding(
            get: { sessionToRename != nil },
            set: { if !$0 { sessionToRename = nil } }
        )) {
            TextField("对话标题", text: $newTitle)
            Button("取消", role: .cancel) {
                sessionToRename = nil
            }
            Button("确定") {
                if let session = sessionToRename {
                    viewModel.renameSession(session, newTitle: newTitle)
                }
                sessionToRename = nil
            }
        } message: {
            Text("请输入新的对话标题")
        }
        .onAppear {
            viewModel.setModelContext(modelContext)
        }
    }
    
    // MARK: - Logo 和标题
    
    private var headerView: some View {
        HStack(spacing: 10) {
            // App Logo - 使用自定义图标
            AppLogoView(size: 36)
            
            // 艺术字标题
            Text("HaruChat")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(hex: "10b981"), Color(hex: "059669")],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
    
    // MARK: - 搜索栏
    
    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
            
            TextField("搜索对话", text: $searchText)
                .textFieldStyle(.plain)
                .font(.subheadline)
            
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(searchBarBackground)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
    }
    
    // MARK: - 新建会话按钮
    
    private var newSessionButton: some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                viewModel.createNewSession()
            }
            HapticManager.impact(.medium)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 16))
                
                Text("新建对话")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [Color(hex: "10b981"), Color(hex: "059669")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
            )
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
    
    private var searchBarBackground: Color {
        #if os(iOS)
        Color(UIColor.tertiarySystemGroupedBackground)
        #else
        Color(NSColor.controlBackgroundColor)
        #endif
    }
    
    // MARK: - 会话列表
    
    private var sessionList: some View {
        List(selection: Binding(
            get: { viewModel.currentSession?.id },
            set: { id in
                if let id, let session = sessions.first(where: { $0.id == id }) {
                    viewModel.selectSession(session)
                    HapticManager.selection()
                }
            }
        )) {
            ForEach(groupedSessions, id: \.0) { group, sessionsInGroup in
                Section {
                    ForEach(sessionsInGroup) { session in
                        SessionRow(
                            session: session,
                            isSelected: viewModel.currentSession?.id == session.id
                        )
                        .tag(session.id)
                        .contextMenu {
                            sessionContextMenu(for: session)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                withAnimation {
                                    viewModel.deleteSession(session)
                                }
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                sessionToRename = session
                                newTitle = session.title
                            } label: {
                                Label("重命名", systemImage: "pencil")
                            }
                            .tint(.orange)
                        }
                    }
                } header: {
                    Text(group)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .textCase(.none)
                }
            }
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
    }
    
    // MARK: - 上下文菜单
    
    @ViewBuilder
    private func sessionContextMenu(for session: ChatSession) -> some View {
        Button {
            sessionToRename = session
            newTitle = session.title
        } label: {
            Label("重命名", systemImage: "pencil")
        }
        
        Divider()
        
        Button(role: .destructive) {
            withAnimation {
                viewModel.deleteSession(session)
            }
        } label: {
            Label("删除", systemImage: "trash")
        }
    }
    
    // MARK: - 底部设置栏
    
    private var bottomSettingsBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            Button {
                showSettings = true
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.secondary)
                    
                    Text("设置")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .background(settingsBarBackground)
    }
    
    private var settingsBarBackground: some View {
        #if os(iOS)
        Color(UIColor.systemBackground)
        #else
        Color(NSColor.windowBackgroundColor)
        #endif
    }
    
    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            viewModel.deleteSession(sessions[index])
        }
    }
}

// MARK: - 会话行视图

struct SessionRow: View {
    let session: ChatSession
    let isSelected: Bool
    
    @State private var isHovering = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 标题
            Text(session.title)
                .font(.subheadline)
                .fontWeight(.medium)
                .lineLimit(1)
                .foregroundStyle(.primary)
            
            // 底部信息
            HStack(spacing: 6) {
                // 消息预览
                if let lastMessage = session.sortedMessages.last {
                    Text(lastMessage.content)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // 时间
                Text(formattedDate)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(
                    isSelected
                    ? Color(hex: "10b981").opacity(0.15)
                    : (isHovering ? Color.secondary.opacity(0.08) : Color.clear)
                )
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
    
    private var formattedDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: session.updatedAt, relativeTo: Date())
    }
}

// MARK: - 空列表视图

struct EmptySessionListView: View {
    let onCreateNew: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            
            Text("暂无对话")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            Button {
                onCreateNew()
            } label: {
                Label("新建对话", systemImage: "plus")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - App Logo 视图

struct AppLogoView: View {
    let size: CGFloat
    
    @State private var hasCustomLogo: Bool = false
    
    var body: some View {
        Group {
            if hasCustomLogo {
                // 使用 Assets 中的自定义图片 "AppLogo"
                Image("AppLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: size * 0.22))
            } else {
                // 默认 Logo
                defaultLogo
            }
        }
        .shadow(color: Color(hex: "10b981").opacity(0.3), radius: 4, x: 0, y: 2)
        .onAppear {
            checkCustomLogo()
        }
    }
    
    private var defaultLogo: some View {
        ZStack {
            // 背景圆角矩形
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(
                    LinearGradient(
                        colors: [Color(hex: "10b981"), Color(hex: "059669")],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
            
            // 叶子图标
            Image(systemName: "leaf.fill")
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
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

#Preview {
    NavigationStack {
        ChatListView(viewModel: ChatViewModel())
    }
    .modelContainer(for: [ChatSession.self, ChatMessage.self], inMemory: true)
}
