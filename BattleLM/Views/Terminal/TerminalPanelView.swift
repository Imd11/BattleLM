// BattleLM/Views/Terminal/TerminalPanelView.swift
import SwiftUI

/// AI 终端面板视图
struct TerminalPanelView: View {
    @EnvironmentObject var appState: AppState
    @State private var isExpanded: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "terminal")
                    .foregroundColor(.secondary)
                Text("AI Workspaces")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    withAnimation {
                        isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            if isExpanded {
                // 终端列表
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(appState.aiInstances) { ai in
                            TerminalCardView(ai: ai)
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(.textBackgroundColor).opacity(0.3))
    }
}

/// 单个终端卡片视图
struct TerminalCardView: View {
    let ai: AIInstance
    @State private var terminalOutput: String = ""
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题栏
            HStack {
                Circle()
                    .fill(ai.isEliminated ? .gray : .green)
                    .frame(width: 8, height: 8)
                
                Image(systemName: ai.type.iconName)
                    .foregroundColor(ai.color)
                    .font(.caption)
                
                Text("\(ai.name) Terminal")
                    .font(.caption)
                    .fontWeight(.medium)
                
                Spacer()
                
                if ai.isEliminated {
                    Text("ELIMINATED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(8)
            .background(Color(.controlBackgroundColor))
            
            // 终端内容区域
            TerminalContentView(ai: ai)
                .frame(height: 120)
                .opacity(ai.isEliminated ? 0.5 : 1.0)
        }
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(ai.isEliminated ? Color.red.opacity(0.3) : Color.gray.opacity(0.3), lineWidth: 1)
        )
    }
}

/// 终端内容视图（暂时用 Text 模拟，后续替换为 SwiftTerm）
struct TerminalContentView: View {
    let ai: AIInstance
    
    var sampleOutput: String {
        switch ai.type {
        case .claude:
            return """
            $ claude run --fix-auth
            
            > Analyzing OAuth2 library...
            > Patching token validation method...
            > Applying changes to auth.service.js...
            > █
            """
        case .gemini:
            return """
            DB Connection Pool Analysis
            
            > Active connections: 45/50
            > Average query time: 120ms
            > Warning: High latency detected in
              token refresh queries.
            > Recommending connection pool
              optimization.
            """
        case .codex:
            return """
            Git Blame Analysis
            
            > Checking commit history...
            > Last stable version: v2.3.1
            > Regression introduced in: v2.4.0
            > Suggested rollback target found.
            """
        }
    }
    
    var body: some View {
        ScrollView {
            Text(sampleOutput)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        .background(Color.black)
    }
}

#Preview {
    TerminalPanelView()
        .environmentObject(AppState())
        .frame(width: 320, height: 500)
}
