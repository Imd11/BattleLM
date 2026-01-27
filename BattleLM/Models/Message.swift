// BattleLM/Models/Message.swift
import Foundation

/// 消息模型
struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    let senderId: UUID
    let senderType: SenderType
    let senderName: String
    let content: String
    let timestamp: Date
    let roundNumber: Int
    let messageType: MessageType
    
    init(
        senderId: UUID,
        senderType: SenderType,
        senderName: String,
        content: String,
        roundNumber: Int = 0,
        messageType: MessageType = .question
    ) {
        self.id = UUID()
        self.senderId = senderId
        self.senderType = senderType
        self.senderName = senderName
        self.content = content
        self.timestamp = Date()
        self.roundNumber = roundNumber
        self.messageType = messageType
    }
    
    /// 创建用户消息
    static func userMessage(_ content: String) -> Message {
        Message(
            senderId: UUID(), // 用户 ID 可以固定
            senderType: .user,
            senderName: "You",
            content: content,
            messageType: .question
        )
    }
    
    /// 创建系统消息
    static func systemMessage(_ content: String) -> Message {
        Message(
            senderId: UUID(),
            senderType: .system,
            senderName: "System",
            content: content,
            messageType: .system
        )
    }
}
