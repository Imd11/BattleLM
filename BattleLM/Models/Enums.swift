// BattleLM/Models/Enums.swift
import Foundation

/// AI 类型
enum AIType: String, Codable, CaseIterable, Identifiable {
    case claude = "claude"
    case gemini = "gemini"
    case codex = "codex"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .claude: return "Claude"
        case .gemini: return "Gemini"
        case .codex: return "Codex"
        }
    }
    
    var cliCommand: String {
        switch self {
        case .claude: return "claude"
        case .gemini: return "gemini"
        case .codex: return "codex"
        }
    }
    
    var iconName: String {
        switch self {
        case .claude: return "brain.head.profile"
        case .gemini: return "sparkles"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        }
    }
    
    var color: String {
        switch self {
        case .claude: return "#A855F7" // Purple
        case .gemini: return "#3B82F6" // Blue
        case .codex: return "#22C55E" // Green
        }
    }
}

/// 发送者类型
enum SenderType: String, Codable {
    case user
    case ai
    case system
}

/// 消息类型
enum MessageType: String, Codable {
    case question      // 用户问题
    case analysis      // AI 问题分析
    case evaluation    // AI 评价
    case solution      // AI 解决方案
    case system        // 系统消息
}

/// 聊天模式
enum ChatMode: String, Codable {
    case discussion    // 讨论模式
    case solution      // 解决方案模式
    
    var displayName: String {
        switch self {
        case .discussion: return "Discussion Mode"
        case .solution: return "Solution Mode"
        }
    }
    
    var iconName: String {
        switch self {
        case .discussion: return "bubble.left.and.bubble.right"
        case .solution: return "lightbulb"
        }
    }
}
