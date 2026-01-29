// BattleLM/Services/DiscussionManager.swift
import Foundation
import Combine

/// 讨论阶段
enum DiscussionPhase: String, CaseIterable {
    case idle = "idle"
    case round1_analyzing = "analyzing"      // Round 1: 初始分析
    case round2_evaluating = "evaluating"    // Round 2: 整体评价
    case round3_revising = "revising"        // Round 3: 最终修正
    case complete = "complete"
    
    var displayName: String {
        switch self {
        case .idle: return "等待中"
        case .round1_analyzing: return "AI 分析中..."
        case .round2_evaluating: return "AI 交流意见..."
        case .round3_revising: return "AI 综合修正..."
        case .complete: return "讨论完成"
        }
    }
    
    var systemMessage: String {
        switch self {
        case .idle: return ""
        case .round1_analyzing: return "💬 Sending to all AIs..."
        case .round2_evaluating: return "🔄 AI 开始交流意见..."
        case .round3_revising: return "✨ AI 综合反馈修正分析..."
        case .complete: return "✅ 讨论完成"
        }
    }
    
    var roundNumber: Int {
        switch self {
        case .idle: return 0
        case .round1_analyzing: return 1
        case .round2_evaluating: return 2
        case .round3_revising: return 3
        case .complete: return 3
        }
    }
}

/// 讨论管理器 - 管理多轮讨论流程
class DiscussionManager: ObservableObject {
    static let shared = DiscussionManager()
    
    @Published var phase: DiscussionPhase = .idle
    @Published var isProcessing: Bool = false
    
    // 各轮响应收集
    var round1Responses: [UUID: String] = [:]  // AI ID → 初始分析
    var round2Responses: [UUID: String] = [:]  // AI ID → 整体评价
    var round3Responses: [UUID: String] = [:]  // AI ID → 最终分析
    
    // AI 互评分数: [被评价者 ID: [评价者 ID: 分数]]
    var peerScores: [UUID: [UUID: Int]] = [:]
    
    // 预期响应的 AI 列表
    private var expectedAIs: Set<UUID> = []
    
    // 回调
    var onPhaseChange: ((DiscussionPhase) -> Void)?
    var onRoundComplete: ((Int, [UUID: String]) -> Void)?
    
    private let sessionManager = SessionManager.shared
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// 开始讨论
    func startDiscussion(
        question: String,
        activeAIs: [AIInstance],
        onRoundStart: @escaping (Int) async -> Void,
        onAIResponse: @escaping (AIInstance, String, Int) async -> Void
    ) async {
        await MainActor.run {
            reset()
            expectedAIs = Set(activeAIs.map { $0.id })
            phase = .round1_analyzing
            isProcessing = true
        }
        
        // Round 1: 发送用户问题给所有 AI
        await onRoundStart(1)
        await executeRound1(question: question, ais: activeAIs, onResponse: onAIResponse)
        
        // Round 2: 发送其他 AI 的分析给每个 AI
        await onRoundStart(2)
        await executeRound2(ais: activeAIs, onResponse: onAIResponse)
        
        // Round 3: 发送其他 AI 的评价给每个 AI
        await onRoundStart(3)
        await executeRound3(ais: activeAIs, onResponse: onAIResponse)
        
        await MainActor.run {
            phase = .complete
            isProcessing = false
        }
    }
    
    /// 重置状态
    func reset() {
        phase = .idle
        isProcessing = false
        round1Responses.removeAll()
        round2Responses.removeAll()
        round3Responses.removeAll()
        peerScores.removeAll()
        expectedAIs.removeAll()
    }
    
    // MARK: - Private Methods
    
    /// Round 1: 初始分析
    private func executeRound1(
        question: String,
        ais: [AIInstance],
        onResponse: @escaping (AIInstance, String, Int) async -> Void
    ) async {
        await MainActor.run {
            phase = .round1_analyzing
        }
        
        // 并行发送给所有 AI，谁先完成就立即显示
        await withTaskGroup(of: (UUID, String, AIInstance)?.self) { group in
            for ai in ais where ai.isActive && !ai.isEliminated {
                group.addTask {
                    do {
                        try await self.sessionManager.sendMessage(question, to: ai)
                        let response = try await self.sessionManager.waitForResponse(
                            from: ai,
                            stableSeconds: 3.0,
                            maxWait: 60.0
                        )
                        return (ai.id, response, ai)
                    } catch {
                        print("❌ Round 1 error for \(ai.name): \(error)")
                        return nil
                    }
                }
            }
            
            // 谁先完成就立即处理和显示
            for await result in group {
                if let (aiId, response, ai) = result {
                    // 立即存储响应
                    round1Responses[aiId] = response
                    // 立即显示到 UI
                    await onResponse(ai, response, 1)
                }
            }
        }
        
        print("📊 Round 1 collected \(round1Responses.count) responses")
        onRoundComplete?(1, round1Responses)
    }
    
    /// Round 2: 整体评价
    private func executeRound2(
        ais: [AIInstance],
        onResponse: @escaping (AIInstance, String, Int) async -> Void
    ) async {
        await MainActor.run {
            phase = .round2_evaluating
        }
        
        // 先构建所有 prompts（此时 round1Responses 已经完整）
        var prompts: [(AIInstance, String)] = []
        for ai in ais where ai.isActive && !ai.isEliminated {
            let prompt = buildRound2Prompt(for: ai, ais: ais)
            prompts.append((ai, prompt))
            print("📝 Round 2 prompt for \(ai.name):\n\(prompt.prefix(200))...")
        }
        
        // 使用本地变量收集响应
        var collectedResponses: [(UUID, String, AIInstance)] = []
        
        // 并行发送给所有 AI，谁先完成就立即显示
        await withTaskGroup(of: (UUID, String, AIInstance)?.self) { group in
            for (ai, prompt) in prompts {
                group.addTask {
                    do {
                        try await self.sessionManager.sendMessage(prompt, to: ai)
                        let response = try await self.sessionManager.waitForResponse(
                            from: ai,
                            stableSeconds: 3.0,
                            maxWait: 60.0
                        )
                        return (ai.id, response, ai)
                    } catch {
                        print("❌ Round 2 error for \(ai.name): \(error)")
                        return nil
                    }
                }
            }
            
            // 谁先完成就立即处理和显示
            for await result in group {
                if let (aiId, response, ai) = result {
                    collectedResponses.append((aiId, response, ai))
                    // 立即存储响应
                    round2Responses[aiId] = response
                    // 立即显示到 UI
                    await onResponse(ai, response, 2)
                    
                    // 提取评分
                    let targetAIs = ais.filter { $0.id != aiId && $0.isActive && !$0.isEliminated }
                    extractScoresFromResponse(response, evaluatorId: aiId, targetAIs: targetAIs)
                }
            }
        }
        
        print("📊 Round 2 collected \(round2Responses.count) responses")
        print("📊 Peer scores: \(peerScores.count) AIs have scores")
        onRoundComplete?(2, round2Responses)
    }
    
    /// Round 3: 最终修正
    private func executeRound3(
        ais: [AIInstance],
        onResponse: @escaping (AIInstance, String, Int) async -> Void
    ) async {
        await MainActor.run {
            phase = .round3_revising
        }
        
        // 先构建所有 prompts（此时 round2Responses 已经完整）
        var prompts: [(AIInstance, String)] = []
        for ai in ais where ai.isActive && !ai.isEliminated {
            let prompt = buildRound3Prompt(for: ai, ais: ais)
            prompts.append((ai, prompt))
            print("📝 Round 3 prompt for \(ai.name):\n\(prompt.prefix(200))...")
        }
        
        // 使用本地变量收集响应
        var collectedResponses: [(UUID, String, AIInstance)] = []
        
        // 并行发送给所有 AI，谁先完成就立即显示
        await withTaskGroup(of: (UUID, String, AIInstance)?.self) { group in
            for (ai, prompt) in prompts {
                group.addTask {
                    do {
                        try await self.sessionManager.sendMessage(prompt, to: ai)
                        let response = try await self.sessionManager.waitForResponse(
                            from: ai,
                            stableSeconds: 3.0,
                            maxWait: 60.0
                        )
                        return (ai.id, response, ai)
                    } catch {
                        print("❌ Round 3 error for \(ai.name): \(error)")
                        return nil
                    }
                }
            }
            
            // 谁先完成就立即处理和显示
            for await result in group {
                if let (aiId, response, ai) = result {
                    collectedResponses.append((aiId, response, ai))
                    // 立即存储响应
                    round3Responses[aiId] = response
                    // 立即显示到 UI
                    await onResponse(ai, response, 3)
                }
            }
        }
        
        print("📊 Round 3 collected \(round3Responses.count) responses")
        onRoundComplete?(3, round3Responses)
    }
    
    // MARK: - Prompt Builders
    
    /// 构建 Round 2 prompt - 评价其他 AI 并打分
    private func buildRound2Prompt(for targetAI: AIInstance, ais: [AIInstance]) -> String {
        var sections: [String] = []
        var aiNames: [String] = []
        
        for ai in ais where ai.id != targetAI.id {
            if let response = round1Responses[ai.id], !response.isEmpty {
                sections.append("【\(ai.name)】\n\(response)")
                aiNames.append(ai.name)
            }
        }
        
        let otherAnalyses = sections.joined(separator: "\n\n────────────\n\n")
        let scoreFormat = aiNames.map { """
【\($0)】
评价：[你对 \($0) 回答的看法]
评分：X分
""" }.joined(separator: "\n\n")
        
        return """
以下是其他 AI 对问题的分析：

────────────

\(otherAnalyses)

────────────

请对每个 AI 的分析进行评价，最后给出评分（1-10分）。

格式：
\(scoreFormat)

（先评价，再打分。X 为 1-10 的数字）
"""
    }
    
    /// 构建 Round 3 prompt - 其他 AI 的评价
    private func buildRound3Prompt(for targetAI: AIInstance, ais: [AIInstance]) -> String {
        var sections: [String] = []
        
        for ai in ais where ai.id != targetAI.id {
            if let response = round2Responses[ai.id], !response.isEmpty {
                sections.append("【\(ai.name)】的评价: \(response)")
            }
        }
        
        let otherEvaluations = sections.joined(separator: "\n\n")
        
        return """
以下是其他 AI 对本次讨论的整体评价：

────────────

\(otherEvaluations)

────────────

请综合以上反馈，给出你的最终问题分析报告。
"""
    }
    
    // MARK: - Score Extraction
    
    /// 从 Round 2 响应中提取评分
    /// - Parameters:
    ///   - content: AI 的评价内容
    ///   - evaluatorId: 评价者 AI 的 ID
    ///   - targetAIs: 被评价的 AI 列表
    func extractScoresFromResponse(_ content: String, evaluatorId: UUID, targetAIs: [AIInstance]) {
        for ai in targetAIs {
            if let score = extractScore(for: ai.name, from: content) {
                // 存储分数
                if peerScores[ai.id] == nil {
                    peerScores[ai.id] = [:]
                }
                peerScores[ai.id]?[evaluatorId] = score
                print("📊 \(ai.name) 收到评分: \(score)分")
            }
        }
    }
    
    /// 从文本中提取某个 AI 的评分
    private func extractScore(for aiName: String, from content: String) -> Int? {
        // 多种模式匹配
        let patterns = [
            // 模式1: 【Claude】后面跟着 评分：8分 或 评分: 8分
            "【\(aiName)】[\\s\\S]*?评分[：:：]\\s*(\\d+)\\s*分",
            // 模式2: "Claude: 8分" 或 "Claude：8分"
            "\(aiName)[：:：]\\s*(\\d+)\\s*分",
            // 模式3: "评分：8分" 在 Claude 相关段落中
            "【\(aiName)】[\\s\\S]*?(\\d+)\\s*分",
            // 模式4: "Claude 8分"
            "\(aiName)\\s+(\\d+)\\s*分"
        ]
        
        for pattern in patterns {
            if let score = matchScore(pattern: pattern, in: content) {
                return min(max(score, 1), 10)  // 限制在 1-10 范围
            }
        }
        
        // 兜底：默认 5 分
        print("⚠️ 无法提取 \(aiName) 的评分，使用默认值 5 分")
        return 5
    }
    
    /// 正则匹配提取分数
    private func matchScore(pattern: String, in content: String) -> Int? {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
            let range = NSRange(content.startIndex..., in: content)
            
            if let match = regex.firstMatch(in: content, options: [], range: range) {
                if match.numberOfRanges >= 2 {
                    let scoreRange = Range(match.range(at: 1), in: content)!
                    if let score = Int(content[scoreRange]) {
                        return score
                    }
                }
            }
        } catch {
            print("❌ Regex error: \(error)")
        }
        return nil
    }
    
    /// 获取某个 AI 的互评平均分
    func getAveragePeerScore(for aiId: UUID) -> Double {
        guard let scores = peerScores[aiId], !scores.isEmpty else {
            return 0.0  // 无评分时返回 0
        }
        
        let total = scores.values.reduce(0, +)
        return Double(total) / Double(scores.count)
    }
}
