// BattleLM/Views/MainView.swift
import SwiftUI

/// 主视图 - 三栏布局
struct MainView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationSplitView {
            // 左侧边栏
            SidebarView()
                .frame(minWidth: 200, maxWidth: 280)
        } detail: {
            // 主内容区
            HStack(spacing: 0) {
                // 内容区域：根据选择显示不同视图
                if let ai = appState.selectedAI {
                    // 1:1 AI 对话
                    AIChatView(ai: ai)
                        .frame(minWidth: 400)
                } else if appState.selectedGroupChat != nil {
                    // 群聊
                    ChatView()
                        .frame(minWidth: 400)
                } else {
                    // 空状态
                    EmptyStateView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                
                // AI 终端区域（仅在群聊或 1:1 时显示）
                if appState.showTerminalPanel && (appState.selectedAI != nil || appState.selectedGroupChat != nil) {
                    Divider()
                    if let ai = appState.selectedAI {
                        // 单个 AI 终端
                        SingleTerminalView(ai: ai)
                            .frame(width: 320)
                    } else {
                        // 多 AI 终端
                        TerminalPanelView()
                            .frame(width: 320)
                    }
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        .sheet(isPresented: $appState.showAddAISheet) {
            AddAISheet()
        }
        .sheet(isPresented: $appState.showCreateGroupSheet) {
            CreateGroupSheet()
        }
    }
}

/// 单个 AI 终端视图
struct SingleTerminalView: View {
    let ai: AIInstance
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题
            HStack {
                Image(systemName: ai.type.iconName)
                    .foregroundColor(ai.color)
                Text("\(ai.name) Terminal")
                    .fontWeight(.medium)
                Spacer()
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            // 终端内容
            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    Text("$ \(ai.type.cliCommand)")
                        .foregroundColor(.green)
                    
                    if ai.isActive {
                        Text("✦ Ready and waiting for input...")
                            .foregroundColor(.cyan)
                    } else {
                        Text("⏸ Session inactive. Click Start to begin.")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
            .background(Color.black)
        }
    }
}

/// 空状态视图
struct EmptyStateView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "bolt.shield")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("Welcome to BattleLM")
                .font(.title)
                .fontWeight(.medium)
            
            Text("Add AI instances and create group chats to get started")
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                Button {
                    appState.showAddAISheet = true
                } label: {
                    Label("Add AI", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
                
                Button {
                    appState.showCreateGroupSheet = true
                } label: {
                    Label("Create Group", systemImage: "bubble.left.and.bubble.right")
                }
                .buttonStyle(.bordered)
                .disabled(appState.aiInstances.isEmpty)
            }
        }
    }
}

#Preview {
    MainView()
        .environmentObject(AppState())
}
