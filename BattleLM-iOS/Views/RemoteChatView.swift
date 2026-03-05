import SwiftUI
import BattleLMShared

/// Remote Chat View
struct RemoteChatView: View {
    let ai: AIInfoDTO
    @EnvironmentObject var connection: RemoteConnection
    
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(connection.messages(for: ai.id)) { message in
                            MessageRow(message: message)
                                .id(message.id)
                        }

                        if connection.isAwaitingResponse(for: ai.id) {
                            ThinkingRow(aiName: ai.name)
                                .id("thinking-indicator")
                                .transition(.opacity)
                        }
                    }
                    .padding()
                }
                .onChange(of: connection.messages(for: ai.id).count) { _ in
                    if let lastMessage = connection.messages(for: ai.id).last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            Divider()
            
            // Input area
            inputArea
        }
        .navigationTitle(ai.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(ai.isRunning ? .green : .gray)
                        .frame(width: 8, height: 8)
                }
            }
        }
    }
    
    private var inputArea: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(20)
                .focused($isInputFocused)
            
            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(inputText.isEmpty ? .gray : .blue)
            }
            .disabled(inputText.isEmpty)
        }
        .padding()
        .background(Color(.systemGroupedBackground))
    }
    
    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        inputText = ""
        
        Task {
            try? await connection.sendMessage(text, to: ai.id)
        }
    }
}

struct MessageRow: View {
    let message: MessageDTO
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if isUserMessage {
                Spacer(minLength: 60)
            }
            
            VStack(alignment: isUserMessage ? .trailing : .leading, spacing: 4) {
                // Sender name (for AI messages)
                if !isUserMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkle")
                            .font(.caption)
                            .foregroundColor(.purple)
                        Text(message.senderName)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                
                // Message content
                Text(message.content)
                    .padding(12)
                    .background(isUserMessage ? Color.blue : Color(.secondarySystemGroupedBackground))
                    .foregroundColor(isUserMessage ? .white : .primary)
                    .cornerRadius(16)
                
                // Timestamp
                Text(formatTime(message.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if !isUserMessage {
                Spacer(minLength: 60)
            }
        }
    }
    
    private var isUserMessage: Bool {
        message.senderType == "user"
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

private struct ThinkingRow: View {
    let aiName: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle")
                        .font(.caption)
                        .foregroundColor(.purple)
                    Text(aiName)
                        .font(.caption)
                        .fontWeight(.medium)
                }

                ThinkingDotsView()
                    .padding(12)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(16)

                Color.clear
                    .frame(height: 1)
            }

            Spacer(minLength: 60)
        }
    }
}
