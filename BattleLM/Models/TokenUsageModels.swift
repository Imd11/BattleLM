// BattleLM/Models/TokenUsageModels.swift
// Token 用量统计数据模型

import Foundation

// MARK: - Time Range

/// 时间范围选择
enum UsageTimeRange: String, CaseIterable, Hashable {
    case today    = "Today"
    case week7d   = "7D"
    case month30d = "30D"
    case month3m  = "3M"
    case month6m  = "6M"

    /// 起始日期（基于自然日历周期）
    var startDate: Date {
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        switch self {
        case .today:    return startOfToday
        case .week7d:   return cal.date(byAdding: .day, value: -6, to: startOfToday)!
        case .month30d: return cal.date(byAdding: .day, value: -29, to: startOfToday)!
        case .month3m:  return cal.date(byAdding: .month, value: -3, to: startOfToday)!
        case .month6m:  return cal.date(byAdding: .month, value: -6, to: startOfToday)!
        }
    }

    /// 空数据时的提示文字
    var emptyMessage: String {
        switch self {
        case .today:    return "No token usage today"
        case .week7d:   return "No token usage in last 7 days"
        case .month30d: return "No token usage in last 30 days"
        case .month3m:  return "No token usage in last 3 months"
        case .month6m:  return "No token usage in last 6 months"
        }
    }

    /// 是否显示每日趋势折线图（Today 不显示）
    var showsDailyTrend: Bool {
        self != .today
    }
}

// MARK: - Token Record

/// 单条 token 使用记录（从 JSONL 日志解析）
struct TokenRecord: Identifiable {
    let id = UUID()
    let timestamp: Date
    let model: String           // e.g. "claude-sonnet-4-6", "gpt-5.3-codex"
    let source: TokenSource     // .claude / .codex
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int    // Claude: cache_read_input_tokens
    let cacheWriteTokens: Int   // Claude: cache_creation_input_tokens
    
    var totalTokens: Int { inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens }
}

/// token 来源
enum TokenSource: String, CaseIterable {
    case claude = "Claude"
    case codex  = "Codex"
    case gemini = "Gemini"
    case qwen   = "Qwen"
    
    var color: String {
        switch self {
        case .claude: return "#D97706"
        case .codex:  return "#10B981"
        case .gemini: return "#4285F4"
        case .qwen:   return "#6366F1"
        }
    }
    
    var aiType: AIType {
        switch self {
        case .claude: return .claude
        case .codex:  return .codex
        case .gemini: return .gemini
        case .qwen:   return .qwen
        }
    }
    
    var logDirectory: String {
        switch self {
        case .claude:
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".claude/projects").path
        case .codex:
            // 支持 CODEX_HOME 环境变量
            if let codexHome = ProcessInfo.processInfo.environment["CODEX_HOME"] {
                return (codexHome as NSString).appendingPathComponent("sessions")
            }
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".codex/sessions").path
        case .qwen:
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".qwen/projects").path
        case .gemini:
            return FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".gemini/tmp").path
        }
    }
}

// MARK: - Daily Trend Point

/// 单日某来源的 token 用量（来源合计，供折线图渲染）
struct DailyTrendPoint: Identifiable {
    let id = UUID()
    let date: Date          // start-of-day
    let source: TokenSource
    let tokens: Int
}

/// 单日某来源某模型的 token 用量（模型细线，供折线图渲染）
struct DailyModelTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let source: TokenSource
    let model: String
    let tokens: Int
}

// MARK: - Token Usage Summary

/// 聚合后的 token 用量汇总
struct TokenUsageSummary {
    var totalInput: Int = 0
    var totalOutput: Int = 0
    var totalCacheRead: Int = 0
    var totalCacheWrite: Int = 0
    
    var totalTokens: Int { totalInput + totalOutput + totalCacheRead + totalCacheWrite }
    
    /// 分模型统计
    var byModel: [String: ModelUsage] = [:]

    /// 分来源 + 分模型统计（用于来源详情页，避免依赖模型名猜测来源）
    var bySourceModel: [TokenSource: [String: ModelUsage]] = [:]
    
    /// 分来源统计
    var bySource: [TokenSource: SourceUsage] = [:]
    
    /// 按小时分布（key = hour 0-23）
    var hourlyTrend: [Int: Int] = [:]

    /// 按日+来源聚合（key = "yyyy-MM-dd"）
    var dailyTrendBySource: [String: [TokenSource: Int]] = [:]

    /// 按日+来源+模型聚合 [dayKey: [source: [model: tokens]]]
    var dailyTrendBySourceModel: [String: [TokenSource: [String: Int]]] = [:]

    /// 日期格式化器（复用）
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    /// 展平+排序后的每日来源合计数据点，供折线图渲染
    var dailyTrendPoints: [DailyTrendPoint] {
        let cal = Calendar.current
        return dailyTrendBySource.flatMap { (dayKey, sourcesMap) -> [DailyTrendPoint] in
            guard let date = Self.dayFormatter.date(from: dayKey) else { return [] }
            let startOfDay = cal.startOfDay(for: date)
            return sourcesMap.map { (source, tokens) in
                DailyTrendPoint(date: startOfDay, source: source, tokens: tokens)
            }
        }
        .sorted { $0.date < $1.date || ($0.date == $1.date && $0.source.rawValue < $1.source.rawValue) }
    }

    /// 展平+排序后的每日模型级数据点，供折线图渲染
    var dailyModelTrendPoints: [DailyModelTrendPoint] {
        let cal = Calendar.current
        return dailyTrendBySourceModel.flatMap { (dayKey, sourcesMap) -> [DailyModelTrendPoint] in
            guard let date = Self.dayFormatter.date(from: dayKey) else { return [] }
            let startOfDay = cal.startOfDay(for: date)
            return sourcesMap.flatMap { (source, modelsMap) in
                modelsMap.map { (model, tokens) in
                    DailyModelTrendPoint(date: startOfDay, source: source, model: model, tokens: tokens)
                }
            }
        }
        .sorted { $0.date < $1.date }
    }
    
    /// 格式化的总 token 数
    var formattedTotal: String {
        formatTokenCount(totalTokens)
    }
    
    mutating func addRecord(_ record: TokenRecord) {
        totalInput += record.inputTokens
        totalOutput += record.outputTokens
        totalCacheRead += record.cacheReadTokens
        totalCacheWrite += record.cacheWriteTokens
        
        // 按模型聚合
        var modelUsage = byModel[record.model] ?? ModelUsage(model: record.model)
        modelUsage.inputTokens += record.inputTokens
        modelUsage.outputTokens += record.outputTokens
        modelUsage.cacheReadTokens += record.cacheReadTokens
        modelUsage.cacheWriteTokens += record.cacheWriteTokens
        modelUsage.requestCount += 1
        byModel[record.model] = modelUsage

        // 按来源 + 模型聚合
        var sourceModels = bySourceModel[record.source] ?? [:]
        var sourceModelUsage = sourceModels[record.model] ?? ModelUsage(model: record.model)
        sourceModelUsage.inputTokens += record.inputTokens
        sourceModelUsage.outputTokens += record.outputTokens
        sourceModelUsage.cacheReadTokens += record.cacheReadTokens
        sourceModelUsage.cacheWriteTokens += record.cacheWriteTokens
        sourceModelUsage.requestCount += 1
        sourceModels[record.model] = sourceModelUsage
        bySourceModel[record.source] = sourceModels

        // 按来源聚合
        var sourceUsage = bySource[record.source] ?? SourceUsage(source: record.source)
        sourceUsage.inputTokens += record.inputTokens
        sourceUsage.outputTokens += record.outputTokens
        sourceUsage.cacheReadTokens += record.cacheReadTokens
        sourceUsage.cacheWriteTokens += record.cacheWriteTokens
        sourceUsage.requestCount += 1
        bySource[record.source] = sourceUsage
        
        // 按小时聚合
        let hour = Calendar.current.component(.hour, from: record.timestamp)
        hourlyTrend[hour, default: 0] += record.totalTokens  // input+output+cache

        // 按日+来源聚合
        let dayKey = Self.dayFormatter.string(from: record.timestamp)
        dailyTrendBySource[dayKey, default: [:]][record.source, default: 0] += record.totalTokens

        // 按日+来源+模型聚合
        dailyTrendBySourceModel[dayKey, default: [:]][record.source, default: [:]][record.model, default: 0] += record.totalTokens
    }
}

/// 单个模型的用量统计
struct ModelUsage: Identifiable {
    var id: String { model }
    let model: String
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheWriteTokens: Int = 0
    var requestCount: Int = 0
    var totalTokens: Int { inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens }
}

/// 单个来源的用量统计
struct SourceUsage: Identifiable {
    var id: String { source.rawValue }
    let source: TokenSource
    var inputTokens: Int = 0
    var outputTokens: Int = 0
    var cacheReadTokens: Int = 0
    var cacheWriteTokens: Int = 0
    var requestCount: Int = 0
    var totalTokens: Int { inputTokens + outputTokens + cacheReadTokens + cacheWriteTokens }
}

// MARK: - Helpers

/// 格式化 token 数量（如 1234567 → "1.2M"）
func formatTokenCount(_ count: Int) -> String {
    if count >= 1_000_000 {
        return String(format: "%.1fM", Double(count) / 1_000_000)
    } else if count >= 1_000 {
        return String(format: "%.1fK", Double(count) / 1_000)
    }
    return "\(count)"
}
