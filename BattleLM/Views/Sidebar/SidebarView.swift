// BattleLM/Views/Sidebar/SidebarView.swift
import SwiftUI

/// 侧边栏视图
struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Logo
            HStack {
                Image(systemName: "bolt.shield")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("BattleLM")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
            }
            .padding()
            
            Divider()
            
            // 内容列表
            List {
                // AI 实例区域
                Section("AI Instances") {
                    ForEach(appState.aiInstances) { ai in
                        AIInstanceRow(ai: ai, isSelected: appState.selectedAIId == ai.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                appState.selectAI(ai)
                            }
                    }
                    
                    Button {
                        appState.showAddAISheet = true
                    } label: {
                        Label("Add AI", systemImage: "plus.circle")
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
                
                // 群聊区域
                Section("Group Chats") {
                    ForEach(appState.groupChats) { chat in
                        GroupChatRow(chat: chat, isSelected: appState.selectedGroupChatId == chat.id)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                appState.selectedGroupChatId = chat.id
                                appState.selectedAIId = nil  // 清除 AI 选择
                            }
                    }
                    
                    Button {
                        appState.showCreateGroupSheet = true
                    } label: {
                        Label("Create Chat", systemImage: "plus.circle")
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .listStyle(.sidebar)
            
            Divider()
            
            // 底部设置
            HStack {
                Button {
                    appState.showSettingsSheet = true
                } label: {
                    Image(systemName: "gear")
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button {
                    appState.showTerminalPanel.toggle()
                } label: {
                    Image(systemName: appState.showTerminalPanel ? "sidebar.right" : "sidebar.right")
                        .foregroundColor(appState.showTerminalPanel ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("Toggle Terminal Panel")
            }
            .padding()
        }
        .background(Color(.windowBackgroundColor))
    }
}

/// AI 实例行
struct AIInstanceRow: View {
    let ai: AIInstance
    var isSelected: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            // 状态指示灯
            Circle()
                .fill(ai.isActive ? .green : .gray)
                .frame(width: 8, height: 8)
            
            // 图标
            Image(systemName: ai.type.iconName)
                .foregroundColor(ai.color)
            
            // 名称和路径
            VStack(alignment: .leading, spacing: 2) {
                Text(ai.name)
                    .fontWeight(isSelected ? .semibold : .regular)
                
                Text(ai.shortPath)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 淘汰标记
            if ai.isEliminated {
                Text("OUT")
                    .font(.caption2)
                    .foregroundColor(.red)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.red.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .cornerRadius(6)
    }
}

/// 群聊行
struct GroupChatRow: View {
    let chat: GroupChat
    var isSelected: Bool = false
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(spacing: 10) {
            // 图标
            Image(systemName: "bubble.left.and.bubble.right")
                .foregroundColor(.accentColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(chat.name)
                    .fontWeight(isSelected ? .semibold : .medium)
                
                // 成员头像
                HStack(spacing: -6) {
                    ForEach(chat.memberIds.prefix(3), id: \.self) { memberId in
                        if let ai = appState.aiInstance(for: memberId) {
                            Circle()
                                .fill(ai.color)
                                .frame(width: 16, height: 16)
                                .overlay(
                                    Circle()
                                        .stroke(Color(.windowBackgroundColor), lineWidth: 1)
                                )
                        }
                    }
                    
                    if chat.memberIds.count > 3 {
                        Text("+\(chat.memberIds.count - 3)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            // 模式指示
            Image(systemName: chat.mode.iconName)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    SidebarView()
        .environmentObject(AppState())
        .frame(width: 250)
}
