// BattleLM/Services/MessageRouter.swift
import Foundation
import Combine

/// 消息路由器 - 负责在 AI 之间路由消息
class MessageRouter: ObservableObject {
    static let shared = MessageRouter()
    
    private let sessionManager = SessionManager.shared
    
    private init() {}
    
    // MARK: - Broadcast Messages
    
    /// 广播用户消息给群聊中的所有 AI
    func broadcastUserMessage(
        _ message: String,
        to chat: GroupChat,
        aiInstances: [AIInstance]
    ) async -> [AIResponse] {
        
        let activeAIs = aiInstances.filter { 
            chat.activeMemberIds.contains($0.id) && !$0.isEliminated 
        }
        
        var responses: [AIResponse] = []
        
        // 并行发送给所有 AI
        await withTaskGroup(of: AIResponse?.self) { group in
            for ai in activeAIs {
                group.addTask {
                    await self.sendAndWait(message, to: ai)
                }
            }
            
            for await response in group {
                if let response = response {
                    responses.append(response)
                }
            }
        }
        
        return responses
    }
    
    /// 让一个 AI 评价另一个 AI 的输出
    func requestEvaluation(
        from evaluator: AIInstance,
        of targetResponse: String,
        targetAI: AIInstance
    ) async -> AIEvaluation? {
        
        let prompt = """
        请评价以下 AI (\(targetAI.name)) 的分析结果，并给出评分。
        
        分析内容：
        "\(targetResponse)"
        
        请用以下格式回复：
        评分：[0-10分]
        优点：[优点描述]
        缺点：[缺点描述]
        """
        
        guard let response = await sendAndWait(prompt, to: evaluator) else {
            return nil
        }
        
        return parseEvaluation(response.content, targetId: targetAI.id)
    }
    
    // MARK: - Private Methods
    
    /// 发送消息并等待响应
    private func sendAndWait(_ message: String, to ai: AIInstance) async -> AIResponse? {
        do {
            // 发送消息
            try await sessionManager.sendMessage(message, to: ai)
            
            // 等待响应
            let response = try await sessionManager.waitForResponse(
                from: ai,
                stableSeconds: 3.0,
                maxWait: 60.0
            )
            
            guard !response.isEmpty else { return nil }
            
            return AIResponse(
                aiId: ai.id,
                aiName: ai.name,
                content: response,
                timestamp: Date()
            )
            
        } catch {
            print("❌ Error sending to \(ai.name): \(error)")
            return nil
        }
    }
    
    /// 解析评价响应
    private func parseEvaluation(_ content: String, targetId: UUID) -> AIEvaluation {
        var score = 5 // 默认分数
        var pros = ""
        var cons = ""
        
        let lines = content.split(separator: "\n")
        
        for line in lines {
            let lineStr = String(line).trimmingCharacters(in: .whitespaces)
            
            if lineStr.contains("评分") || lineStr.contains("分数") || lineStr.contains("Score") {
                // 提取数字
                let numbers = lineStr.filter { $0.isNumber }
                if let parsed = Int(numbers), parsed >= 0, parsed <= 10 {
                    score = parsed
                }
            } else if lineStr.contains("优点") || lineStr.contains("Pros") {
                pros = lineStr.replacingOccurrences(of: "优点：", with: "")
                               .replacingOccurrences(of: "优点:", with: "")
                               .trimmingCharacters(in: .whitespaces)
            } else if lineStr.contains("缺点") || lineStr.contains("Cons") {
                cons = lineStr.replacingOccurrences(of: "缺点：", with: "")
                               .replacingOccurrences(of: "缺点:", with: "")
                               .trimmingCharacters(in: .whitespaces)
            }
        }
        
        return AIEvaluation(
            targetId: targetId,
            score: score,
            pros: pros,
            cons: cons
        )
    }
}

// MARK: - Supporting Types

/// AI 响应
struct AIResponse {
    let aiId: UUID
    let aiName: String
    let content: String
    let timestamp: Date
}

/// AI 评价
struct AIEvaluation {
    let targetId: UUID
    let score: Int        // 0-10
    let pros: String
    let cons: String
}
