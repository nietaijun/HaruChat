//
//  MarkdownView.swift
//  HaruChat
//
//  Created by 玩忽所以 on 2025/12/6.
//

import SwiftUI

/// Markdown 渲染视图
struct MarkdownView: View {
    let content: String
    let isUser: Bool
    let fontSize: Double
    
    @State private var copiedCodeBlock: String?
    
    init(_ content: String, isUser: Bool = false, fontSize: Double = 16) {
        self.content = content
        self.isUser = isUser
        self.fontSize = fontSize
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(parseBlocks().enumerated()), id: \.offset) { _, block in
                renderBlock(block)
            }
        }
    }
    
    // MARK: - 解析
    
    private func parseBlocks() -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        var currentText = ""
        var inCodeBlock = false
        var codeLanguage = ""
        var codeContent = ""
        
        let lines = content.components(separatedBy: "\n")
        
        for line in lines {
            if line.hasPrefix("```") {
                if inCodeBlock {
                    // 结束代码块
                    blocks.append(.code(language: codeLanguage, content: codeContent.trimmingCharacters(in: .newlines)))
                    codeContent = ""
                    codeLanguage = ""
                    inCodeBlock = false
                } else {
                    // 开始代码块
                    if !currentText.isEmpty {
                        blocks.append(.text(currentText.trimmingCharacters(in: .newlines)))
                        currentText = ""
                    }
                    codeLanguage = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    inCodeBlock = true
                }
            } else if inCodeBlock {
                if !codeContent.isEmpty {
                    codeContent += "\n"
                }
                codeContent += line
            } else {
                if !currentText.isEmpty {
                    currentText += "\n"
                }
                currentText += line
            }
        }
        
        // 处理剩余内容
        if inCodeBlock {
            blocks.append(.code(language: codeLanguage, content: codeContent.trimmingCharacters(in: .newlines)))
        } else if !currentText.isEmpty {
            blocks.append(.text(currentText.trimmingCharacters(in: .newlines)))
        }
        
        return blocks
    }
    
    // MARK: - 渲染
    
    @ViewBuilder
    private func renderBlock(_ block: MarkdownBlock) -> some View {
        switch block {
        case .text(let content):
            renderText(content)
        case .code(let language, let content):
            CodeBlockView(language: language, code: content, fontSize: fontSize, copiedBlock: $copiedCodeBlock)
        }
    }
    
    private func renderText(_ text: String) -> some View {
        Text(parseInlineMarkdown(text))
            .font(.system(size: fontSize))
            .foregroundStyle(isUser ? .white : .primary)
            .textSelection(.enabled)
    }
    
    /// 解析内联 Markdown（加粗、斜体、行内代码）
    private func parseInlineMarkdown(_ text: String) -> AttributedString {
        var result = AttributedString(text)
        
        // 处理加粗 **text** 或 __text__
        if let boldRegex = try? Regex(#"\*\*(.+?)\*\*|__(.+?)__"#) {
            result = applyStyle(to: result, matching: boldRegex) { match in
                var attr = AttributedString(match)
                attr.font = .system(size: fontSize, weight: .bold)
                return attr
            }
        }
        
        // 处理斜体 *text* 或 _text_
        if let italicRegex = try? Regex(#"(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)|(?<!_)_(?!_)(.+?)(?<!_)_(?!_)"#) {
            result = applyStyle(to: result, matching: italicRegex) { match in
                var attr = AttributedString(match)
                attr.font = .system(size: fontSize).italic()
                return attr
            }
        }
        
        // 处理行内代码 `code`
        if let codeRegex = try? Regex(#"`([^`]+)`"#) {
            result = applyStyle(to: result, matching: codeRegex) { match in
                var attr = AttributedString(match)
                attr.font = .system(size: fontSize - 1, design: .monospaced)
                attr.backgroundColor = isUser ? .white.opacity(0.2) : Color(hex: "e5e7eb")
                return attr
            }
        }
        
        return result
    }
    
    private func applyStyle(
        to attributedString: AttributedString,
        matching regex: Regex<AnyRegexOutput>,
        transform: (String) -> AttributedString
    ) -> AttributedString {
        // 简化处理：返回原字符串，实际应用中可以使用更复杂的逻辑
        return attributedString
    }
}

// MARK: - Markdown 块类型

enum MarkdownBlock {
    case text(String)
    case code(language: String, content: String)
}

// MARK: - 代码块视图

struct CodeBlockView: View {
    let language: String
    let code: String
    let fontSize: Double
    @Binding var copiedBlock: String?
    
    @State private var isHovering = false
    
    init(language: String, code: String, fontSize: Double = 16, copiedBlock: Binding<String?>) {
        self.language = language
        self.code = code
        self.fontSize = fontSize
        self._copiedBlock = copiedBlock
    }
    
    private var isCopied: Bool {
        copiedBlock == code
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 头部
            HStack {
                // 语言标签
                if !language.isEmpty {
                    Text(language.uppercased())
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.secondary.opacity(0.15))
                        )
                }
                
                Spacer()
                
                // 复制按钮
                Button {
                    copyCode()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.caption)
                        Text(isCopied ? "已复制" : "复制")
                            .font(.caption)
                    }
                    .foregroundStyle(isCopied ? Color(hex: "10b981") : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color.secondary.opacity(isHovering ? 0.2 : 0.1))
                    )
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    isHovering = hovering
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.05))
            
            Divider()
            
            // 代码内容
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code)
                    .font(.system(size: fontSize - 2, design: .monospaced))
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
                    .padding(12)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(codeBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }
    
    private var codeBackground: Color {
        #if os(iOS)
        Color(UIColor.tertiarySystemGroupedBackground)
        #else
        Color(NSColor.textBackgroundColor)
        #endif
    }
    
    private func copyCode() {
        #if os(iOS)
        UIPasteboard.general.string = code
        #else
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        #endif
        
        HapticManager.notification(.success)
        
        withAnimation {
            copiedBlock = code
        }
        
        // 2秒后重置
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                if copiedBlock == code {
                    copiedBlock = nil
                }
            }
        }
    }
}

#Preview("Markdown") {
    ScrollView {
        MarkdownView("""
        这是一段普通文本，包含 **加粗** 和 *斜体*。
        
        下面是一段代码：
        
        ```swift
        struct HelloWorld {
            func greet() {
                print("Hello, World!")
            }
        }
        ```
        
        还有 `行内代码` 示例。
        
        ```python
        def hello():
            print("Hello from Python!")
        ```
        """, fontSize: 16)
        .padding()
    }
}
