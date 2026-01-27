// BattleLM/Views/Chat/ChatView.swift
import SwiftUI

/// 群聊视图
struct ChatView: View {
    @EnvironmentObject var appState: AppState
    @State private var inputText: String = ""
    
    var chat: GroupChat? {
        appState.selectedGroupChat
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶栏
            ChatHeaderView()
            
            Divider()
            
            // 消息列表
            MessageListView()
            
            Divider()
            
            // 输入框
            MessageInputView(inputText: $inputText) {
                sendMessage()
            }
        }
        .background(Color(.textBackgroundColor).opacity(0.3))
    }
    
    private func sendMessage() {
        guard let chat = chat, !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        appState.sendUserMessage(inputText, to: chat.id)
        inputText = ""
    }
}

/// 聊天顶栏
struct ChatHeaderView: View {
    @EnvironmentObject var appState: AppState
    
    var chat: GroupChat? {
        appState.selectedGroupChat
    }
    
    var body: some View {
        HStack {
            // 群聊名称
            Text(chat?.name ?? "Chat")
                .font(.headline)
            
            // 成员头像
            HStack(spacing: -8) {
                ForEach(chat?.memberIds ?? [], id: \.self) { memberId in
                    if let ai = appState.aiInstance(for: memberId) {
                        Circle()
                            .fill(ai.color)
                            .frame(width: 24, height: 24)
                            .overlay(
                                Text(String(ai.name.prefix(1)))
                                    .font(.caption2)
                                    .foregroundColor(.white)
                            )
                            .overlay(
                                Circle()
                                    .stroke(Color(.windowBackgroundColor), lineWidth: 2)
                            )
                    }
                }
            }
            
            Spacer()
            
            // 模式指示器
            if let mode = chat?.mode {
                HStack(spacing: 4) {
                    Image(systemName: mode.iconName)
                    Text(mode.displayName)
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.2))
                .cornerRadius(12)
            }
            
            // 切换模式按钮
            Menu {
                Button {
                    // 切换到讨论模式
                } label: {
                    Label("Discussion Mode", systemImage: "bubble.left.and.bubble.right")
                }
                
                Button {
                    // 切换到解决方案模式
                } label: {
                    Label("Solution Mode", systemImage: "lightbulb")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }
}

#Preview {
    ChatView()
        .environmentObject(AppState())
        .frame(width: 500, height: 600)
}
