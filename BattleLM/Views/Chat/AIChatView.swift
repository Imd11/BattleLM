// BattleLM/Views/Chat/AIChatView.swift
import SwiftUI

/// 1:1 AI 对话视图
struct AIChatView: View {
    @EnvironmentObject var appState: AppState
    let ai: AIInstance
    
    @State private var messages: [Message] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部栏
            HStack {
                // AI 信息
                HStack(spacing: 12) {
                    Circle()
                        .fill(ai.isActive ? .green : .gray)
                        .frame(width: 10, height: 10)
                    
                    Image(systemName: ai.type.iconName)
                        .font(.title2)
                        .foregroundColor(ai.color)
                    
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
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            // 消息列表
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty {
                            // 空状态
                            VStack(spacing: 16) {
                                Image(systemName: ai.type.iconName)
                                    .font(.system(size: 48))
                                    .foregroundColor(ai.color.opacity(0.5))
                                
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
                                AIChatBubbleView(message: message, ai: ai)
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
        guard !inputText.isEmpty else { return }
        
        let userMessage = Message.userMessage(inputText)
        messages.append(userMessage)
        
        let question = inputText
        inputText = ""
        
        // TODO: 发送给真实 AI
        appState.sendMessageToAI(question, to: ai.id)
        
        // 模拟响应
        isLoading = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let response = Message(
                senderId: ai.id,
                senderType: .ai,
                senderName: ai.name,
                content: "I received your message: \"\(question)\". This is a placeholder response. Real AI integration coming soon!",
                messageType: .analysis
            )
            messages.append(response)
            isLoading = false
        }
    }
    
    private func toggleSession() {
        // TODO: 实现真实的会话启动/停止
        if let index = appState.aiInstances.firstIndex(where: { $0.id == ai.id }) {
            appState.aiInstances[index].isActive.toggle()
        }
    }
}

/// 1:1 对话气泡视图
struct AIChatBubbleView: View {
    let message: Message
    let ai: AIInstance?
    
    var isUser: Bool {
        message.senderType == .user
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isUser {
                Spacer()
            } else if let ai = ai {
                // AI 头像
                Circle()
                    .fill(ai.color)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: ai.type.iconName)
                            .font(.caption)
                            .foregroundColor(.white)
                    )
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
            .frame(maxWidth: 500, alignment: isUser ? .trailing : .leading)
            
            if !isUser {
                Spacer()
            } else {
                // 用户头像
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 32, height: 32)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                    )
            }
        }
    }
}

#Preview {
    AIChatView(ai: AIInstance(type: .claude, name: "Claude", workingDirectory: "/Users/yang/Projects"))
        .environmentObject(AppState())
        .frame(width: 600, height: 500)
}
