// BattleLM/Views/Chat/MessageListView.swift
import SwiftUI

/// 消息列表视图
struct MessageListView: View {
    @EnvironmentObject var appState: AppState
    
    var messages: [Message] {
        appState.selectedGroupChat?.messages ?? []
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(messages) { message in
                        MessageBubbleView(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _ in
                // 自动滚动到最新消息
                if let lastMessage = messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

/// 消息气泡视图
struct MessageBubbleView: View {
    let message: Message
    @EnvironmentObject var appState: AppState
    
    var isUser: Bool {
        message.senderType == .user
    }
    
    var isSystem: Bool {
        message.senderType == .system
    }
    
    var aiInstance: AIInstance? {
        appState.aiInstance(for: message.senderId)
    }
    
    var body: some View {
        if isSystem {
            // 系统消息
            systemMessageView
        } else {
            // 用户或 AI 消息
            regularMessageView
        }
    }
    
    // 系统消息样式
    private var systemMessageView: some View {
        HStack {
            Spacer()
            Text(message.content)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            Spacer()
        }
    }
    
    // 普通消息样式
    private var regularMessageView: some View {
        HStack(alignment: .top, spacing: 12) {
            // 左侧头像（AI 消息）
            if !isUser {
                avatarView
            }
            
            // 消息内容
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                // 发送者名称和类型标签
                if !isUser {
                    HStack(spacing: 6) {
                        Text(message.senderName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(aiInstance?.color ?? .secondary)
                        
                        messageTypeTag
                    }
                }
                
                // 消息内容
                Text(message.content)
                    .padding(12)
                    .background(bubbleBackground)
                    .foregroundColor(bubbleTextColor)
                    .cornerRadius(16)
                    .frame(maxWidth: 450, alignment: isUser ? .trailing : .leading)
                
                // 时间戳
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // 右侧空间（用户消息靠右）
            if isUser {
                Spacer(minLength: 60)
            } else {
                Spacer(minLength: 40)
            }
        }
        .frame(maxWidth: .infinity, alignment: isUser ? .trailing : .leading)
    }
    
    // 头像视图
    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(aiInstance?.color ?? .gray)
                .frame(width: 36, height: 36)
            
            if let iconName = aiInstance?.type.iconName {
                Image(systemName: iconName)
                    .font(.system(size: 16))
                    .foregroundColor(.white)
            }
        }
    }
    
    // 消息类型标签
    @ViewBuilder
    private var messageTypeTag: some View {
        if message.messageType != .question {
            Text(messageTypeText)
                .font(.caption2)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(messageTypeColor.opacity(0.2))
                .foregroundColor(messageTypeColor)
                .cornerRadius(4)
        }
    }
    
    private var messageTypeText: String {
        switch message.messageType {
        case .analysis: return "Analysis"
        case .evaluation: return "Evaluation"
        case .solution: return "Solution"
        default: return ""
        }
    }
    
    private var messageTypeColor: Color {
        switch message.messageType {
        case .analysis: return .blue
        case .evaluation: return .orange
        case .solution: return .green
        default: return .gray
        }
    }
    
    private var bubbleBackground: Color {
        isUser ? Color.accentColor : Color(.controlBackgroundColor)
    }
    
    private var bubbleTextColor: Color {
        isUser ? .white : .primary
    }
}

#Preview {
    MessageListView()
        .environmentObject(AppState())
        .frame(width: 500, height: 400)
}
