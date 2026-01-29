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
    
    /// 应用外观
    @Published var appAppearance: AppAppearance = .system
    
    /// 终端主题
    @Published var terminalTheme: TerminalTheme = .default
    
    /// 终端位置
    @Published var terminalPosition: TerminalPosition = .right
    
    /// 字体大小
    @Published var fontSize: FontSizeOption = .medium
    
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
    @discardableResult
    func addAI(type: AIType, name: String? = nil, workingDirectory: String) -> AIInstance? {
        let ai = AIInstance(type: type, name: name, workingDirectory: workingDirectory)
        aiInstances.append(ai)
        
        // 自动选中新添加的 AI，关闭群聊选择
        selectedAIId = ai.id
        selectedGroupChatId = nil
        
        // 新打开 AI 时默认关闭终端面板
        showTerminalPanel = false
        
        return ai
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
    
    /// 添加消息到 AI 实例（1:1 对话）
    func appendMessage(_ message: Message, to aiId: UUID) {
        if let index = aiInstances.firstIndex(where: { $0.id == aiId }) {
            aiInstances[index].messages.append(message)
        }
    }
    
    /// 更新 AI 消息内容（用于流式输出）
    func updateMessage(_ messageId: UUID, content: String, aiId: UUID) {
        if let aiIndex = aiInstances.firstIndex(where: { $0.id == aiId }),
           let msgIndex = aiInstances[aiIndex].messages.firstIndex(where: { $0.id == messageId }) {
            // 创建新消息保留其他属性，只更新 content
            let oldMsg = aiInstances[aiIndex].messages[msgIndex]
            let newMsg = Message(
                senderId: oldMsg.senderId,
                senderType: oldMsg.senderType,
                senderName: oldMsg.senderName,
                content: content,
                roundNumber: oldMsg.roundNumber,
                messageType: oldMsg.messageType,
                userReaction: oldMsg.userReaction
            )
            // 保持原有 ID
            aiInstances[aiIndex].messages[msgIndex] = Message(
                id: oldMsg.id,
                senderId: oldMsg.senderId,
                senderType: oldMsg.senderType,
                senderName: oldMsg.senderName,
                content: content,
                timestamp: oldMsg.timestamp,
                roundNumber: oldMsg.roundNumber,
                messageType: oldMsg.messageType,
                userReaction: oldMsg.userReaction
            )
        }
    }
    
    /// 设置用户对消息的反应（点赞/踩）
    func setMessageReaction(_ reaction: UserReaction?, for messageId: UUID, in chatId: UUID) {
        guard let chatIndex = groupChats.firstIndex(where: { $0.id == chatId }),
              let msgIndex = groupChats[chatIndex].messages.firstIndex(where: { $0.id == messageId }) else {
            return
        }
        
        // 切换反应（再次点击同样的反应则取消）
        if groupChats[chatIndex].messages[msgIndex].userReaction == reaction {
            groupChats[chatIndex].messages[msgIndex].userReaction = nil
        } else {
            groupChats[chatIndex].messages[msgIndex].userReaction = reaction
        }
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
        
        let chat = groupChats[index]
        let members = aiInstances.filter { chat.memberIds.contains($0.id) }
        
        // 根据模式选择不同的处理流程
        switch chat.mode {
        case .discussion:
            // 添加 Round 1 系统消息
            let round1Msg = Message.systemMessage(DiscussionPhase.round1_analyzing.systemMessage)
            groupChats[index].messages.append(round1Msg)
            
            Task {
                await startDiscussion(content, chatId: chatId, members: members)
            }
            
        case .qna:
            // Q&A 模式：简单系统消息
            let qnaMsg = Message.systemMessage("❓ Asking all AIs...")
            groupChats[index].messages.append(qnaMsg)
            
            Task {
                await startQnA(content, chatId: chatId, members: members)
            }
        }
    }
    
    /// 启动讨论模式 - 使用 DiscussionManager 进行多轮讨论
    @MainActor
    private func startDiscussion(_ question: String, chatId: UUID, members: [AIInstance]) async {
        guard let index = groupChats.firstIndex(where: { $0.id == chatId }) else { return }
        
        // 确保所有成员 AI 的会话已启动
        for ai in members {
            if !ai.isActive {
                if let aiIndex = aiInstances.firstIndex(where: { $0.id == ai.id }) {
                    do {
                        try await SessionManager.shared.startSession(for: aiInstances[aiIndex])
                        aiInstances[aiIndex].isActive = true
                    } catch {
                        print("❌ Failed to start session for \(ai.name): \(error)")
                        let errorMsg = Message.systemMessage("⚠️ Failed to start \(ai.name)")
                        groupChats[index].messages.append(errorMsg)
                    }
                }
            }
        }
        
        // 获取活跃成员
        let activeMembers = aiInstances.filter { ai in
            members.contains(where: { $0.id == ai.id }) && ai.isActive && !ai.isEliminated
        }
        
        guard !activeMembers.isEmpty else {
            let noActiveMsg = Message.systemMessage("⚠️ No active AIs available for discussion.")
            groupChats[index].messages.append(noActiveMsg)
            return
        }
        
        // 使用 DiscussionManager 进行 3 轮讨论
        await DiscussionManager.shared.startDiscussion(
            question: question,
            activeAIs: activeMembers,
            onRoundStart: { [weak self] round in
                guard let self = self else { return }
                
                await MainActor.run {
                    guard let idx = self.groupChats.firstIndex(where: { $0.id == chatId }) else { return }
                    
                    // 在 Round 开始时立即添加系统消息
                    let systemMessage: String
                    switch round {
                    case 1:
                        return  // Round 1 消息已在 sendUserMessage 中添加
                    case 2:
                        systemMessage = DiscussionPhase.round2_evaluating.systemMessage
                    case 3:
                        systemMessage = DiscussionPhase.round3_revising.systemMessage
                    default:
                        return
                    }
                    
                    let msg = Message.systemMessage(systemMessage)
                    self.groupChats[idx].messages.append(msg)
                }
            },
            onAIResponse: { [weak self] ai, response, round in
                guard let self = self else { return }
                
                await MainActor.run {
                    guard let idx = self.groupChats.firstIndex(where: { $0.id == chatId }) else { return }
                    
                    // 确定消息类型
                    let messageType: MessageType = {
                        switch round {
                        case 1: return .analysis
                        case 2: return .evaluation
                        default: return .analysis  // Round 3+ 也是分析
                        }
                    }()
                    
                    // 添加 AI 消息到列表
                    let message = Message(
                        senderId: ai.id,
                        senderType: .ai,
                        senderName: ai.name,
                        content: response,
                        messageType: messageType
                    )
                    self.groupChats[idx].messages.append(message)
                    
                    // 更新轮次
                    self.groupChats[idx].currentRound = round
                }
            }
        )
        
        // 讨论完成，添加完成消息
        guard let idx = groupChats.firstIndex(where: { $0.id == chatId }) else { return }
        let completeMsg = Message.systemMessage(DiscussionPhase.complete.systemMessage)
        groupChats[idx].messages.append(completeMsg)
    }
    
    /// 启动 Q&A 模式 - 每个 AI 独立回答，不互相交流
    @MainActor
    private func startQnA(_ question: String, chatId: UUID, members: [AIInstance]) async {
        guard let index = groupChats.firstIndex(where: { $0.id == chatId }) else { return }
        
        // 确保所有成员 AI 的会话已启动
        for ai in members {
            if !ai.isActive {
                if let aiIndex = aiInstances.firstIndex(where: { $0.id == ai.id }) {
                    do {
                        try await SessionManager.shared.startSession(for: aiInstances[aiIndex])
                        aiInstances[aiIndex].isActive = true
                    } catch {
                        print("❌ Failed to start session for \(ai.name): \(error)")
                        let errorMsg = Message.systemMessage("⚠️ Failed to start \(ai.name)")
                        groupChats[index].messages.append(errorMsg)
                    }
                }
            }
        }
        
        // 获取活跃成员
        let activeMembers = aiInstances.filter { ai in
            members.contains(where: { $0.id == ai.id }) && ai.isActive && !ai.isEliminated
        }
        
        guard !activeMembers.isEmpty else {
            let noActiveMsg = Message.systemMessage("⚠️ No active AIs available.")
            groupChats[index].messages.append(noActiveMsg)
            return
        }
        
        // 向所有 AI 发送问题并收集响应
        for ai in activeMembers {
            do {
                // 发送问题
                try await SessionManager.shared.sendMessage(question, to: ai)
                
                // 流式获取响应
                try await SessionManager.shared.streamResponse(from: ai) { [weak self] response, isThinking, isComplete in
                    guard let self = self else { return }
                    
                    guard let idx = self.groupChats.firstIndex(where: { $0.id == chatId }) else { return }
                    
                    // 查找或创建该 AI 的消息
                    if let msgIdx = self.groupChats[idx].messages.lastIndex(where: {
                        $0.senderId == ai.id && $0.senderType == .ai
                    }) {
                        // 更新现有消息
                        self.groupChats[idx].messages[msgIdx].content = response
                        self.groupChats[idx].messages[msgIdx].isStreaming = !isComplete
                    } else {
                        // 创建新消息
                        var message = Message(
                            senderId: ai.id,
                            senderType: .ai,
                            senderName: ai.name,
                            content: response.isEmpty ? "Thinking..." : response,
                            messageType: .analysis
                        )
                        message.isStreaming = !isComplete
                        self.groupChats[idx].messages.append(message)
                    }
                }
            } catch {
                print("❌ Q&A error for \(ai.name): \(error)")
                let errorMsg = Message.systemMessage("⚠️ \(ai.name) failed to respond")
                groupChats[index].messages.append(errorMsg)
            }
        }
        
        // Q&A 完成
        guard let idx = groupChats.firstIndex(where: { $0.id == chatId }) else { return }
        let completeMsg = Message.systemMessage("✅ All AIs have responded.")
        groupChats[idx].messages.append(completeMsg)
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
        case .qwen:
            return "Based on my analysis of the problem, I recommend a systematic approach to identify the root cause and implement a robust solution."
        case .kimi:
            return "我来分析一下这个问题。从技术角度来看，我们需要深入了解需求和实现细节，找到最优解决方案。"
        }
    }
    
    /// 添加消息到群聊
    @MainActor
    private func appendGroupChatMessage(_ message: Message, to chatId: UUID) {
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
