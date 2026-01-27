// BattleLM/Views/Chat/MessageInputView.swift
import SwiftUI

/// 消息输入框视图
struct MessageInputView: View {
    @Binding var inputText: String
    var onSend: () -> Void
    
    @FocusState private var isFocused: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            // 附件按钮
            Button {
                // TODO: 添加附件
            } label: {
                Image(systemName: "paperclip")
                    .font(.title3)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            
            // 输入框
            TextField("Type your question...", text: $inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isFocused)
                .onSubmit {
                    if !inputText.isEmpty {
                        onSend()
                    }
                }
            
            // 发送按钮
            Button {
                onSend()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(inputText.isEmpty ? .gray : .accentColor)
            }
            .buttonStyle(.plain)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .keyboardShortcut(.return, modifiers: .command)
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }
}

#Preview {
    MessageInputView(inputText: .constant("")) {
        print("Send")
    }
    .frame(width: 500)
}
