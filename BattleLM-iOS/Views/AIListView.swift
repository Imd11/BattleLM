import SwiftUI
import BattleLMShared
import UIKit

/// AI List View
struct AIListView: View {
    @EnvironmentObject var connection: RemoteConnection
    @State private var selectedAI: AIInfoDTO?
    @State private var showCreateGroupChat = false
    
    var body: some View {
        List {
            // Connection status
            Section {
                HStack {
                    Circle()
                        .fill(connectionStatusColor)
                        .frame(width: 8, height: 8)
                    Text(connectionStatusText)
                        .foregroundColor(.secondary)
                    Spacer()
                    if case .error = connection.state {
                        Button("Reconnect") {
                            reconnect()
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    } else {
                        Button("Disconnect") {
                            connection.disconnect()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
            }
            
            // AI list (moved above Group chats)
            Section {
                if connection.aiList.isEmpty {
                    Text("No AI instances")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(connection.aiList) { ai in
                        NavigationLink(destination: RemoteChatView(ai: ai)) {
                            AIRow(ai: ai)
                        }
                    }
                }
            } header: {
                Text("AI Instances")
            }
            
            // Group chats
            Section {
                if connection.groupChats.isEmpty {
                    Text("No group chats")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(connection.groupChats) { chat in
                        NavigationLink(destination: GroupChatView(chatId: chat.id)) {
                            GroupChatRow(chat: chat)
                        }
                    }
                }
            } header: {
                Text("Group Chats")
            }
        }
        .navigationTitle("BattleLM")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showCreateGroupChat = true
                } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Create Group Chat")
            }
        }
        .sheet(isPresented: $showCreateGroupChat) {
            CreateGroupChatView()
        }
        .sheet(item: $connection.currentPrompt) { prompt in
            TerminalPromptSheet(prompt: prompt)
        }
        .alert("Group Chat Error", isPresented: Binding(
            get: { connection.groupChatErrorMessage != nil },
            set: { _ in connection.groupChatErrorMessage = nil }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(connection.groupChatErrorMessage ?? "")
        }
    }
    
    // MARK: - Connection Status Helpers
    
    private var connectionStatusColor: Color {
        switch connection.state {
        case .connected:
            return .green
        case .connecting, .authenticating:
            return .orange
        case .disconnected:
            return .gray
        case .error:
            return .red
        }
    }
    
    private var connectionStatusText: String {
        switch connection.state {
        case .connected:
            return "Connected"
        case .connecting:
            return "Connecting..."
        case .authenticating:
            return "Authenticating..."
        case .disconnected:
            return "Disconnected"
        case .error(let msg):
            return "Error: \(msg)"
        }
    }
    
    private func reconnect() {
        // 尝试重连到最近配对的设备
        guard let device = connection.pairedDevices.first else { return }
        Task {
            try? await connection.reconnect(to: device)
        }
    }
}

struct AIRow: View {
    let ai: AIInfoDTO
    
    var body: some View {
        HStack {
            // Connection status
            Circle()
                .fill(ai.isRunning ? .green : .gray)
                .frame(width: 8, height: 8)

            providerLogo
                .frame(width: 18, height: 18)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(ai.name)
                    .font(.headline)
                
                if let dir = ai.workingDirectory {
                    Text(dir)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private var providerLogo: some View {
        if let assetName = logoAssetName,
           let image = UIImage(named: assetName) {
            return AnyView(
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            )
        }

        return AnyView(
            Image(systemName: fallbackSymbolName)
                .foregroundColor(.secondary)
        )
    }

    private var logoAssetName: String? {
        switch ai.provider.lowercased() {
        case "claude": return "ClaudeLogo"
        case "gemini": return "GeminiLogo"
        case "codex": return "OpenAILogo"
        case "qwen": return "qwen"
        case "kimi": return "KimiLogo"
        default: return nil
        }
    }

    private var fallbackSymbolName: String {
        switch ai.provider.lowercased() {
        case "claude": return "brain.head.profile"
        case "gemini": return "sparkles"
        case "codex": return "chevron.left.forwardslash.chevron.right"
        case "qwen": return "wand.and.stars"
        case "kimi": return "moon.stars"
        default: return "questionmark.circle"
        }
    }
}

struct GroupChatRow: View {
    let chat: GroupChatDTO

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .foregroundColor(.secondary)
            Text(chat.name)
                .font(.headline)
            Spacer()
            Text("\(chat.memberIds.count)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Terminal Prompt Sheet

extension TerminalPromptPayload: Identifiable {
    public var id: UUID { aiId }
}

struct TerminalPromptSheet: View {
    let prompt: TerminalPromptPayload
    @EnvironmentObject var connection: RemoteConnection
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Warning icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.orange)
                
                // Title
                Text(prompt.title)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                
                // Body
                if let body = prompt.body {
                    Text(body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // Hint (command)
                if let hint = prompt.hint {
                    Text(hint)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                }
                
                // Options
                VStack(spacing: 12) {
                    ForEach(prompt.options, id: \.number) { option in
                        Button {
                            Task {
                                try? await connection.submitChoice(option.number, for: prompt.aiId)
                                dismiss()
                            }
                        } label: {
                            Text("\(option.number). \(option.label)")
                                .frame(maxWidth: .infinity)
                                .padding()
                        }
                        .buttonStyle(.bordered)
                        .tint(option.number == 1 ? .blue : nil)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding()
            .navigationTitle("Confirm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}
