// BattleLM/Views/Sidebar/SidebarView.swift
import SwiftUI

/// 侧边栏视图
struct SidebarView: View {
    @EnvironmentObject var appState: AppState
    @State private var addAIHovered: Bool = false
    @State private var createGroupHovered: Bool = false
    
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
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    deleteAI(ai)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                    }
                    
                    Button {
                        appState.showAddAISheet = true
                    } label: {
                        Label("Add AI", systemImage: "plus.circle")
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(addAIHovered ? Color.accentColor.opacity(0.1) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        addAIHovered = hovering
                    }
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
                        Label("Create Group", systemImage: "plus.circle")
                            .foregroundColor(.accentColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(createGroupHovered ? Color.accentColor.opacity(0.1) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                    .onHover { hovering in
                        createGroupHovered = hovering
                    }
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
                .help("Settings (⌘,)")
                
                Spacer()
            }
            .padding()
        }
        .background(Color(.windowBackgroundColor))
    }
    
    /// 删除 AI 实例
    private func deleteAI(_ ai: AIInstance) {
        Task {
            // 先停止会话
            if ai.isActive {
                try? await SessionManager.shared.stopSession(for: ai)
            }
            // 从 appState 中移除
            await MainActor.run {
                appState.removeAI(ai)
            }
        }
    }
}

/// AI 实例行
struct AIInstanceRow: View {
    let ai: AIInstance
    var isSelected: Bool = false
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            // 状态指示灯
            Circle()
                .fill(ai.isActive ? .green : .gray)
                .frame(width: 8, height: 8)
            
            // AI Logo
            AILogoView(aiType: ai.type, size: 18)
            
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
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color.primary.opacity(0.08) : Color.clear))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

/// 群聊行
struct GroupChatRow: View {
    let chat: GroupChat
    var isSelected: Bool = false
    @EnvironmentObject var appState: AppState
    @State private var isHovered: Bool = false
    
    var body: some View {
        HStack(spacing: 10) {
            // 模式图标（移到左侧，放大）
            Image(systemName: chat.mode.iconName)
                .font(.title3)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(chat.name)
                    .fontWeight(isSelected ? .semibold : .medium)
                
                // 成员头像
                HStack(spacing: -6) {
                    ForEach(chat.memberIds.prefix(3), id: \.self) { memberId in
                        if let ai = appState.aiInstance(for: memberId) {
                            ZStack {
                                Circle()
                                    .fill(Color(.windowBackgroundColor))
                                    .frame(width: 16, height: 16)
                                AILogoView(aiType: ai.type, size: 12)
                            }
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
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 6)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.15) : (isHovered ? Color.primary.opacity(0.08) : Color.clear))
        )
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

#Preview {
    SidebarView()
        .environmentObject(AppState())
        .frame(width: 250)
}
