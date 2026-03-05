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
                    // 1:1 AI 对话 - 使用 id 确保切换时重建视图
                    AIChatView(ai: ai)
                        .id(ai.id)
                        .frame(minWidth: 400)
                    
                    // 右侧文件树面板（折叠式）
                    if appState.showTerminalPanel {
                        Divider()
                        
                        VStack(spacing: 0) {
                            // 文件树标题栏
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.secondary)
                                    .font(.caption)
                                Text("\(ai.name) Files")
                                    .font(.system(size: 12, weight: .medium))
                                Spacer()
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        appState.showTerminalPanel = false
                                    }
                                } label: {
                                    Image(systemName: "xmark")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(.windowBackgroundColor))
                            
                            Divider()
                            
                            FileTreeView(workingDirectory: ai.workingDirectory)
                        }
                        .frame(width: 260)
                        .transition(.move(edge: .trailing))
                    }
                } else if appState.selectedGroupChat != nil {
                    // 群聊
                    ChatView()
                        .frame(minWidth: 400)
                } else {
                    // 空状态
                    EmptyStateView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(minWidth: 1000, minHeight: 700)
        // 应用外观
        .preferredColorScheme(appState.appAppearance.colorScheme)
        .sheet(isPresented: $appState.showAddAISheet) {
            AddAISheet()
        }
        .sheet(isPresented: $appState.showCreateGroupSheet) {
            CreateGroupSheet()
        }
        .sheet(isPresented: $appState.showSettingsSheet) {
            SettingsSheet()
        }
        .sheet(isPresented: $appState.showPairingSheet) {
            PairingQRView()
        }
        .toolbar {
            if appState.selectedAI != nil {
                // Keep this spacer item to push the toggle into the trailing toolbar area on macOS.
                ToolbarItem(placement: .primaryAction) {
                    Spacer()
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            appState.showTerminalPanel.toggle()
                        }
                    } label: {
                        Image(systemName: "sidebar.trailing")
                    }
                    .help(appState.showTerminalPanel ? "Hide Files" : "Show Files")
                }
            }
        }

    }
}

/// 空状态视图
struct EmptyStateView: View {
    @EnvironmentObject var appState: AppState
    @State private var isAddAIHovered = false
    @State private var isCreateGroupHovered = false
    
    var body: some View {
        VStack(spacing: 20) {
            Image("BattleLogo")
                .resizable()
                .scaledToFit()
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            
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
                .scaleEffect(isAddAIHovered ? 1.03 : 1.0)
                .shadow(
                    color: isAddAIHovered ? Color.accentColor.opacity(0.25) : .clear,
                    radius: isAddAIHovered ? 8 : 0,
                    y: 2
                )
                .animation(.easeOut(duration: 0.12), value: isAddAIHovered)
                .onHover { isAddAIHovered = $0 }
                
                Button {
                    appState.showCreateGroupSheet = true
                } label: {
                    Label("Create Group", systemImage: "bubble.left.and.bubble.right")
                }
                .buttonStyle(.bordered)
                .scaleEffect(isCreateGroupHovered ? 1.03 : 1.0)
                .shadow(
                    color: isCreateGroupHovered ? Color.accentColor.opacity(0.22) : .clear,
                    radius: isCreateGroupHovered ? 8 : 0,
                    y: 2
                )
                .animation(.easeOut(duration: 0.12), value: isCreateGroupHovered)
                .onHover { isCreateGroupHovered = $0 }
            }
        }
        .offset(y: -40)
    }
}

#Preview {
    MainView()
        .environmentObject(AppState())
}
