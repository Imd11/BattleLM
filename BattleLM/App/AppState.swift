// BattleLM/App/AppState.swift
import SwiftUI
import Combine

/// 全局应用状态
class AppState: ObservableObject {
    // MARK: - Published Properties
    
    /// AI 实例列表
    @Published var aiInstances: [AIInstance] = []
    
    /// 群聊列表
    @Published var groupChats: [GroupChat] = []
    
    /// 当前选中的群聊
    @Published var selectedGroupChatId: UUID?
    
    /// 当前选中的 AI 实例（1:1 对话）
    @Published var selectedAIId: UUID?
    
    /// 是否显示终端面板
    @Published var showTerminalPanel: Bool = true
    
    /// Sheet 控制
    @Published var showAddAISheet: Bool = false
    @Published var showCreateGroupSheet: Bool = false
    @Published var showSettingsSheet: Bool = false
    
    // MARK: - Computed Properties
    
    /// 当前选中的群聊
    var selectedGroupChat: GroupChat? {
        get {
            guard let id = selectedGroupChatId else { return nil }
            return groupChats.first { $0.id == id }
        }
        set {
            if let chat = newValue {
                if let index = groupChats.firstIndex(where: { $0.id == chat.id }) {
                    groupChats[index] = chat
                }
            }
        }
    }
    
    // MARK: - Initialization
    
    init() {
        // 启动时为空，不加载示例数据
    }
    
    // MARK: - AI Instance Methods
    
    /// 添加 AI 实例
    func addAI(type: AIType, name: String? = nil, workingDirectory: String) {
        let ai = AIInstance(type: type, name: name, workingDirectory: workingDirectory)
        aiInstances.append(ai)
    }
    
    /// 获取当前选中的 AI
    var selectedAI: AIInstance? {
        guard let id = selectedAIId else { return nil }
        return aiInstances.first { $0.id == id }
    }
    
    /// 移除 AI 实例
    func removeAI(_ ai: AIInstance) {
        aiInstances.removeAll { $0.id == ai.id }
    }
    
    /// 获取 AI 实例
    func aiInstance(for id: UUID) -> AIInstance? {
        aiInstances.first { $0.id == id }
    }
    
    // MARK: - Group Chat Methods
    
    /// 创建群聊
    func createGroupChat(name: String, memberIds: [UUID]) {
        var chat = GroupChat(name: name, memberIds: memberIds)
        chat.isActive = true
        groupChats.append(chat)
        selectedGroupChatId = chat.id
    }
    
    /// 发送用户消息到群聊
    func sendUserMessage(_ content: String, to chatId: UUID) {
        guard let index = groupChats.firstIndex(where: { $0.id == chatId }) else { return }
        
        let message = Message.userMessage(content)
        groupChats[index].messages.append(message)
        
        // 启动讨论模式
        let chat = groupChats[index]
        let members = aiInstances.filter { chat.memberIds.contains($0.id) }
        
        Task {
            await startDiscussion(content, chatId: chatId, members: members)
        }
    }
    
    /// 启动讨论模式
    @MainActor
    private func startDiscussion(_ question: String, chatId: UUID, members: [AIInstance]) async {
        guard let index = groupChats.firstIndex(where: { $0.id == chatId }) else { return }
        
        // 检查 AI 会话是否已启动（模拟模式下跳过）
        let simulateMode = true // TODO: 改为 false 使用真实 AI
        
        if simulateMode {
            // 模拟 AI 响应
            await simulateAIResponses(question, chatId: chatId, members: members)
        } else {
            // 使用真实 AI
            let result = await ModeController.shared.runDiscussionMode(
                userQuestion: question,
                chat: groupChats[index],
                aiInstances: members
            ) { [weak self] message in
                Task { @MainActor in
                    self?.appendMessage(message, to: chatId)
                }
            }
            
            // 更新淘汰状态
            for eliminatedId in result.eliminatedIds {
                if let aiIndex = aiInstances.firstIndex(where: { $0.id == eliminatedId }) {
                    aiInstances[aiIndex].isEliminated = true
                }
            }
        }
    }
    
    /// 模拟 AI 响应（测试用）
    @MainActor
    private func simulateAIResponses(_ question: String, chatId: UUID, members: [AIInstance]) async {
        // 模拟每个 AI 的响应
        for ai in members {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5秒延迟
            
            let response = generateSimulatedResponse(for: ai, question: question)
            let message = Message(
                senderId: ai.id,
                senderType: .ai,
                senderName: ai.name,
                content: response,
                messageType: .analysis
            )
            appendMessage(message, to: chatId)
        }
    }
    
    /// 生成模拟响应
    private func generateSimulatedResponse(for ai: AIInstance, question: String) -> String {
        switch ai.type {
        case .claude:
            return "Based on my analysis, this appears to be related to \(question.prefix(30))... I recommend investigating the root cause systematically."
        case .gemini:
            return "I've analyzed the situation. The key factors here are related to the system architecture. We should consider multiple approaches."
        case .codex:
            return "Looking at this from a code perspective, I suggest we examine the implementation details and potential edge cases."
        }
    }
    
    /// 添加消息到群聊
    @MainActor
    private func appendMessage(_ message: Message, to chatId: UUID) {
        if let index = groupChats.firstIndex(where: { $0.id == chatId }) {
            groupChats[index].messages.append(message)
        }
    }
    
    /// 添加 AI 消息到群聊
    
    // MARK: - 1:1 AI Chat
    
    /// 选择 AI 进行 1:1 对话
    func selectAI(_ ai: AIInstance) {
        selectedAIId = ai.id
        selectedGroupChatId = nil  // 清除群聊选择
    }
    
    /// 发送消息给单个 AI
    func sendMessageToAI(_ content: String, to aiId: UUID) {
        guard let ai = aiInstance(for: aiId) else { return }
        
        // 这里将来会调用 SessionManager 发送给真实 AI
        // 目前先打印日志
        print("📤 Sending to \(ai.name): \(content)")
        
        // TODO: 实现真实的消息发送和响应
    }
}
