// BattleLM/Views/Chat/AIChatView.swift
import SwiftUI

/// 1:1 AI 对话视图
struct AIChatView: View {
    @EnvironmentObject var appState: AppState
    let ai: AIInstance
    
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    
    /// 从 AppState 获取当前 AI 的消息
    var messages: [Message] {
        appState.aiInstance(for: ai.id)?.messages ?? []
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            HStack {
                // AI 信息
                HStack(spacing: 12) {
                    Circle()
                        .fill(ai.isActive ? .green : .gray)
                        .frame(width: 10, height: 10)
                    
                    AILogoView(aiType: ai.type, size: 24)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(ai.name)
                            .font(.headline)
                        Text(ai.shortPath)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 状态
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.7)
                }
                
                // 启动/停止按钮
                Button {
                    toggleSession()
                } label: {
                    Image(systemName: ai.isActive ? "stop.circle" : "play.circle")
                        .font(.title2)
                }
                .buttonStyle(.plain)
                .help(ai.isActive ? "Stop AI" : "Start AI")
                
                // 终端切换按钮
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        appState.showTerminalPanel.toggle()
                    }
                } label: {
                    Image(systemName: appState.showTerminalPanel ? "rectangle.righthalf.inset.filled" : "rectangle.righthalf.inset.filled.arrow.right")
                        .font(.title2)
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .help(appState.showTerminalPanel ? "Hide Terminal (⌘T)" : "Show Terminal (⌘T)")
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            // 消息列表
            GeometryReader { geometry in
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            if messages.isEmpty {
                                // 空状态
                                VStack(spacing: 16) {
                                    AILogoView(aiType: ai.type, size: 48)
                                        .opacity(0.5)
                                    
                                    Text("Start a conversation with \(ai.name)")
                                        .font(.headline)
                                        .foregroundColor(.secondary)
                                    
                                    Text("Working directory: \(ai.workingDirectory)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if !ai.isActive {
                                        Button("Start \(ai.name)") {
                                            toggleSession()
                                        }
                                        .buttonStyle(.borderedProminent)
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .padding(.top, 100)
                            } else {
                                ForEach(messages) { message in
                                    AIChatBubbleView(message: message, ai: ai, containerWidth: geometry.size.width)
                                        .id(message.id)
                                }
                            }
                        }
                        .padding()
                    }
                    .onChange(of: messages.count) { _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            
            Divider()
            
            // 输入区域
            HStack(spacing: 12) {
                TextField("Ask \(ai.name) something...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .disabled(!ai.isActive)
                    .onSubmit {
                        sendMessage()
                    }
                
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                }
                .disabled(inputText.isEmpty || !ai.isActive)
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(.windowBackgroundColor))
        }
    }
    
    private func sendMessage() {
        guard !inputText.isEmpty, ai.isActive else { return }
        
        // 添加用户消息
        let userMessage = Message(
            senderId: UUID(),
            senderType: .user,
            senderName: "You",
            content: inputText,
            messageType: .question
        )
        appState.appendMessage(userMessage, to: ai.id)
        
        let question = inputText
        inputText = ""
        
        // 创建一个占位的 AI 消息（流式更新）
        let placeholderMessage = Message(
            senderId: ai.id,
            senderType: .ai,
            senderName: ai.name,
            content: "⏳ Waiting for response...",
            messageType: .analysis
        )
        let messageId = placeholderMessage.id
        appState.appendMessage(placeholderMessage, to: ai.id)
        
        isLoading = true
        
        Task {
            await MessageRouter.shared.sendWithStreaming(question, to: ai) { content, isThinking, isComplete in
                // 实时更新消息内容
                let displayContent: String
                if isThinking && content.isEmpty {
                    displayContent = "⁝ Thinking..."
                } else if content.isEmpty {
                    displayContent = "⏳ Waiting for response..."
                } else {
                    displayContent = content
                }
                
                appState.updateMessage(messageId, content: displayContent, aiId: ai.id)
                
                if isComplete {
                    isLoading = false
                }
            }
        }
    }
    
    /// 提取输出中的新增内容
    private func extractNewContent(before: String, after: String) -> String {
        let beforeLines = Set(before.split(separator: "\n").map { String($0) })
        let afterLines = after.split(separator: "\n").map { String($0) }
        
        // 找出新增的行
        var newLines: [String] = []
        for line in afterLines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // 跳过空行、边框字符、命令提示符
            if trimmed.isEmpty { continue }
            if trimmed.hasPrefix(">") || trimmed.hasPrefix("$") || trimmed.hasPrefix("%") { continue }
            if trimmed.contains("──") || trimmed.contains("│") { continue }
            
            // 检查是否是新行
            if !beforeLines.contains(line) {
                // AI 响应通常以特定字符开头
                if trimmed.hasPrefix("✦") || trimmed.hasPrefix("•") || 
                   trimmed.hasPrefix("I ") || trimmed.hasPrefix("The ") ||
                   trimmed.count > 20 {
                    newLines.append(trimmed)
                }
            }
        }
        
        return newLines.joined(separator: "\n")
    }
    
    private func toggleSession() {
        guard let index = appState.aiInstances.firstIndex(where: { $0.id == ai.id }) else { return }
        
        let currentAI = appState.aiInstances[index]
        
        Task {
            do {
                if currentAI.isActive {
                    // 停止会话
                    try await SessionManager.shared.stopSession(for: currentAI)
                    await MainActor.run {
                        appState.aiInstances[index].isActive = false
                    }
                } else {
                    // 启动会话
                    try await SessionManager.shared.startSession(for: currentAI)
                    await MainActor.run {
                        appState.aiInstances[index].isActive = true
                        let systemMessage = Message.systemMessage("🟢 \(currentAI.name) session started in \(currentAI.shortPath)")
                        appState.appendMessage(systemMessage, to: ai.id)
                    }
                }
            } catch {
                await MainActor.run {
                    let errorMessage = Message.systemMessage("❌ Failed to toggle session: \(error.localizedDescription)")
                    appState.appendMessage(errorMessage, to: ai.id)
                }
            }
        }
    }
}

/// 1:1 对话气泡视图
struct AIChatBubbleView: View {
    let message: Message
    let ai: AIInstance?
    let containerWidth: CGFloat
    
    var isUser: Bool {
        message.senderType == .user
    }
    
    var maxBubbleWidth: CGFloat {
        containerWidth * 0.7
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧空白（10%）
            Spacer()
                .frame(width: containerWidth * 0.10)
            
            // 用户消息：左边额外空白推向右边
            if isUser {
                Spacer()
            }
            
            // AI 头像
            if !isUser, let ai = ai {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 32, height: 32)
                    AILogoView(aiType: ai.type, size: 22)
                }
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(12)
                    .background(isUser ? Color.accentColor : Color(.controlBackgroundColor))
                    .foregroundColor(isUser ? .white : .primary)
                    .cornerRadius(16)
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: maxBubbleWidth, alignment: isUser ? .trailing : .leading)
            
            // AI 消息：右边额外空白
            if !isUser {
                Spacer()
            }
            
            // 用户头像
            if isUser {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                    )
            }
            
            // 右侧空白（10%）
            Spacer()
                .frame(width: containerWidth * 0.10)
        }
    }
}

#Preview {
    AIChatView(ai: AIInstance(type: .claude, name: "Claude", workingDirectory: "/Users/yang/Projects"))
        .environmentObject(AppState())
        .frame(width: 600, height: 500)
}
