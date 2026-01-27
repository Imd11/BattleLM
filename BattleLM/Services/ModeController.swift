// BattleLM/Services/ModeController.swift
import Foundation
import Combine

/// 模式控制器 - 控制讨论模式和解决方案模式的流程
class ModeController: ObservableObject {
    static let shared = ModeController()
    
    private let router = MessageRouter.shared
    private let eliminator = EliminationEngine.shared
    
    @Published var isProcessing = false
    @Published var currentRound = 0
    
    private init() {}
    
    // MARK: - Discussion Mode
    
    /// 执行讨论模式
    /// - Returns: DiscussionResult 包含所有消息和淘汰的 AI
    func runDiscussionMode(
        userQuestion: String,
        chat: GroupChat,
        aiInstances: [AIInstance],
        onMessage: @escaping (Message) -> Void
    ) async -> DiscussionResult {
        
        await MainActor.run { isProcessing = true }
        defer { Task { await MainActor.run { isProcessing = false } } }
        
        var allMessages: [Message] = []
        var currentAIs = aiInstances.filter { !$0.isEliminated }
        var eliminatedIds: [UUID] = []
        
        // Round 1: 每个 AI 分析问题
        print("📝 Round 1: AI Analysis")
        await MainActor.run { currentRound = 1 }
        
        let analysisResponses = await router.broadcastUserMessage(
            userQuestion,
            to: chat,
            aiInstances: currentAIs
        )
        
        for response in analysisResponses {
            let message = Message(
                senderId: response.aiId,
                senderType: .ai,
                senderName: response.aiName,
                content: response.content,
                roundNumber: 1,
                messageType: .analysis
            )
            allMessages.append(message)
            onMessage(message)
        }
        
        // Round 2: 每个 AI 评价其他 AI
        print("🔍 Round 2: Cross Evaluation")
        await MainActor.run { currentRound = 2 }
        
        var evaluations: [UUID: [AIEvaluation]] = [:]
        
        for evaluator in currentAIs {
            for targetResponse in analysisResponses where targetResponse.aiId != evaluator.id {
                guard let targetAI = currentAIs.first(where: { $0.id == targetResponse.aiId }) else {
                    continue
                }
                
                if let evaluation = await router.requestEvaluation(
                    from: evaluator,
                    of: targetResponse.content,
                    targetAI: targetAI
                ) {
                    // 记录评价
                    if evaluations[targetResponse.aiId] == nil {
                        evaluations[targetResponse.aiId] = []
                    }
                    evaluations[targetResponse.aiId]?.append(evaluation)
                    
                    // 创建评价消息
                    let evalMessage = Message(
                        senderId: evaluator.id,
                        senderType: .ai,
                        senderName: evaluator.name,
                        content: "对 \(targetAI.name) 的评价：\(evaluation.score)/10 分\n优点：\(evaluation.pros)\n缺点：\(evaluation.cons)",
                        roundNumber: 2,
                        messageType: .evaluation
                    )
                    allMessages.append(evalMessage)
                    onMessage(evalMessage)
                }
            }
        }
        
        // Round 3: 淘汰
        print("⚔️ Round 3: Elimination")
        await MainActor.run { currentRound = 3 }
        
        let toEliminate = eliminator.calculateEliminations(
            aiInstances: currentAIs,
            evaluations: evaluations
        )
        eliminatedIds = toEliminate
        
        if !toEliminate.isEmpty {
            let eliminatedNames = toEliminate.compactMap { id in
                currentAIs.first(where: { $0.id == id })?.name
            }
            
            let systemMessage = Message.systemMessage(
                "⚔️ 淘汰: \(eliminatedNames.joined(separator: ", ")) - 评分过低"
            )
            allMessages.append(systemMessage)
            onMessage(systemMessage)
        }
        
        // 更新活跃 AI 列表
        currentAIs = currentAIs.filter { !toEliminate.contains($0.id) }
        
        // Round 4: 修正分析（如果还有 AI）
        if !currentAIs.isEmpty {
            print("✨ Round 4: Revised Analysis")
            await MainActor.run { currentRound = 4 }
            
            let revisedResponses = await router.broadcastUserMessage(
                "请根据其他 AI 的评价，给出你修正后的问题分析。",
                to: chat,
                aiInstances: currentAIs
            )
            
            for response in revisedResponses {
                let message = Message(
                    senderId: response.aiId,
                    senderType: .ai,
                    senderName: response.aiName,
                    content: "[修正后] \(response.content)",
                    roundNumber: 4,
                    messageType: .analysis
                )
                allMessages.append(message)
                onMessage(message)
            }
        }
        
        return DiscussionResult(
            messages: allMessages,
            eliminatedIds: eliminatedIds,
            remainingAIs: currentAIs
        )
    }
    
    // MARK: - Solution Mode
    
    /// 执行解决方案模式
    func runSolutionMode(
        chat: GroupChat,
        aiInstances: [AIInstance],
        onMessage: @escaping (Message) -> Void
    ) async -> SolutionResult {
        
        await MainActor.run { isProcessing = true }
        defer { Task { await MainActor.run { isProcessing = false } } }
        
        var allMessages: [Message] = []
        let currentAIs = aiInstances.filter { !$0.isEliminated }
        
        // Round 1: 每个 AI 给出解决方案
        print("💡 Round 1: Solutions")
        await MainActor.run { currentRound = 1 }
        
        let solutionResponses = await router.broadcastUserMessage(
            "请基于之前的分析，给出你的最终解决方案。",
            to: chat,
            aiInstances: currentAIs
        )
        
        for response in solutionResponses {
            let message = Message(
                senderId: response.aiId,
                senderType: .ai,
                senderName: response.aiName,
                content: response.content,
                roundNumber: 1,
                messageType: .solution
            )
            allMessages.append(message)
            onMessage(message)
        }
        
        // 选出最佳方案（目前简单选第一个）
        let bestSolutionId = solutionResponses.first?.aiId
        
        if let bestId = bestSolutionId,
           let bestAI = currentAIs.first(where: { $0.id == bestId }) {
            let systemMessage = Message.systemMessage(
                "🏆 推荐方案来自: \(bestAI.name)"
            )
            allMessages.append(systemMessage)
            onMessage(systemMessage)
        }
        
        return SolutionResult(
            messages: allMessages,
            bestSolutionId: bestSolutionId
        )
    }
}

// MARK: - Result Types

struct DiscussionResult {
    let messages: [Message]
    let eliminatedIds: [UUID]
    let remainingAIs: [AIInstance]
}

struct SolutionResult {
    let messages: [Message]
    let bestSolutionId: UUID?
}
