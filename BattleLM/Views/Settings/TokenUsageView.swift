// BattleLM/Views/Settings/TokenUsageView.swift
// Token 用量仪表盘 — 按来源分 Tab 显示 Claude 和 Codex 的 token 消耗统计

import SwiftUI
import Charts

// MARK: - Usage Tab

enum UsageTab: Hashable {
    case all
    case source(TokenSource)
    
    var label: String {
        switch self {
        case .all: return "All"
        case .source(let s): return s.rawValue
        }
    }
}

// MARK: - Main View

struct TokenUsageView: View {
    let monitor: TokenUsageMonitor
    @State private var selectedTab: UsageTab = .all
    @State private var chartHoverDate: Date? = nil

    /// 模型曲线调色板（10 色，循环使用）
    private static let modelColorPalette: [Color] = [
        Color(hex: "#3B82F6"), Color(hex: "#EF4444"), Color(hex: "#10B981"),
        Color(hex: "#F59E0B"), Color(hex: "#8B5CF6"), Color(hex: "#EC4899"),
        Color(hex: "#06B6D4"), Color(hex: "#84CC16"), Color(hex: "#F97316"),
        Color(hex: "#6366F1"),
    ]
    /// 模型曲线线型（5 种，循环使用）
    private static let modelLineStyles: [StrokeStyle] = [
        StrokeStyle(lineWidth: 1.5),
        StrokeStyle(lineWidth: 1.5, dash: [8, 4]),
        StrokeStyle(lineWidth: 1.5, dash: [2, 3]),
        StrokeStyle(lineWidth: 1.5, dash: [8, 3, 2, 3]),
        StrokeStyle(lineWidth: 1.5, dash: [4, 4]),
    ]

    /// 有数据或已支持的来源
    private var availableSources: [TokenSource] {
        TokenSource.allCases
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Tab 栏 + 时间范围选择器
            HStack(spacing: 4) {
                usageFilterChip(label: "All", isActive: selectedTab == .all) {
                    selectedTab = .all
                }
                
                ForEach(availableSources, id: \.self) { source in
                    usageFilterChip(
                        label: source.rawValue,
                        aiType: source.aiType,
                        isActive: selectedTab == .source(source)
                    ) {
                        selectedTab = .source(source)
                    }
                }
                
                Spacer()
                
                // 时间范围选择器
                TimeRangePicker(selected: Binding(
                    get: { monitor.selectedTimeRange },
                    set: { monitor.selectedTimeRange = $0 }
                ))
            }
            .padding(.horizontal, 4)
            
            Divider()
            
            // 内容区
            ScrollView {
                let summary = monitor.summary
                
                Group {
                    switch selectedTab {
                    case .all:
                        allOverview(summary: summary)
                    case .source(let source):
                        sourceDetail(source: source, summary: summary)
                    }
                }
                .padding(.bottom, 8)
            }
        }
    }
    
    // MARK: - Filter Chip (matching Session Manager style)
    
    private func usageFilterChip(label: String, aiType: AIType? = nil, isActive: Bool, action: @escaping () -> Void) -> some View {
        UsageFilterChipButton(label: label, aiType: aiType, isActive: isActive, action: action)
    }
    
    // MARK: - All Overview Tab

    @ViewBuilder
    private func allOverview(summary: TokenUsageSummary) -> some View {
        if summary.totalTokens == 0 {
            emptyState(message: monitor.selectedTimeRange.emptyMessage)
        } else {
            // 总量
            VStack(alignment: .leading, spacing: 6) {
                Text("Total")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Text(summary.formattedTotal)
                    .font(.system(size: 32, weight: .bold, design: .monospaced))
            }
            .padding(.bottom, 4)

            // 各来源堆叠条形图
            ForEach(availableSources, id: \.self) { source in
                let sourceUsage = summary.bySource[source]
                let tokens = sourceUsage?.totalTokens ?? 0
                let requests = sourceUsage?.requestCount ?? 0

                if tokens > 0 {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            AILogoView(aiType: source.aiType, size: 14)
                            Text(source.rawValue)
                                .font(.system(size: 13, weight: .medium))
                            Spacer()
                            Text(formatTokenCount(tokens))
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            if requests > 0 {
                                Text("(\(Int(Double(tokens) / Double(summary.totalTokens) * 100))%)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // 堆叠条形图
                        stackedBar(
                            input: sourceUsage?.inputTokens ?? 0,
                            output: sourceUsage?.outputTokens ?? 0,
                            cacheRead: sourceUsage?.cacheReadTokens ?? 0,
                            cacheWrite: sourceUsage?.cacheWriteTokens ?? 0,
                            maxTotal: summary.totalTokens
                        )
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()
                .padding(.vertical, 4)

            // 图例
            tokenTypeLegend(summary: summary)

            // 每日趋势折线图（总量 + 各来源合计，不展示细分模型）
            if monitor.selectedTimeRange.showsDailyTrend {
                dailyTrendChart(
                    grandTotal: dailyGrandTotal(from: summary.dailyTrendPoints),
                    sourceTotals: summary.dailyTrendPoints,
                    hoverBinding: $chartHoverDate
                )
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Source Detail Tab

    @ViewBuilder
    private func sourceDetail(source: TokenSource, summary: TokenUsageSummary) -> some View {
        let sourceUsage = summary.bySource[source]
        let tokens = sourceUsage?.totalTokens ?? 0
        let requests = sourceUsage?.requestCount ?? 0

        // 该来源下的模型
        let models = Array((summary.bySourceModel[source] ?? [:]).values)
            .sorted(by: { $0.totalTokens > $1.totalTokens })

        if tokens == 0 {
            emptyState(message: monitor.selectedTimeRange.emptyMessage.replacingOccurrences(of: "token", with: source.rawValue))
        } else {
            // 来源总量
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Total")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text(formatTokenCount(tokens))
                        .font(.system(size: 32, weight: .bold, design: .monospaced))
                }

                Text("\(requests) requests")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 6)

                Spacer()
            }
            .padding(.bottom, 4)

            // 模型列表 + 堆叠条形图
            if !models.isEmpty {
                Text("Models")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                let maxModelTokens = models.first?.totalTokens ?? 1

                ForEach(Array(models.prefix(8)), id: \.id) { modelUsage in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(modelUsage.model)
                                .font(.system(size: 12, design: .monospaced))
                                .lineLimit(1)
                            Spacer()
                            Text(formatTokenCount(modelUsage.totalTokens))
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        }

                        stackedBar(
                            input: modelUsage.inputTokens,
                            output: modelUsage.outputTokens,
                            cacheRead: modelUsage.cacheReadTokens,
                            cacheWrite: modelUsage.cacheWriteTokens,
                            maxTotal: maxModelTokens,
                            height: 6
                        )
                    }
                    .padding(.vertical, 4)
                }
            }

            Divider()
                .padding(.vertical, 4)

            // 图例 + 明细
            tokenTypeLegend(
                input: sourceUsage?.inputTokens ?? 0,
                output: sourceUsage?.outputTokens ?? 0,
                cacheRead: sourceUsage?.cacheReadTokens ?? 0,
                cacheWrite: sourceUsage?.cacheWriteTokens ?? 0
            )

            // 每日趋势折线图（该 source 合计 + 该 source 各模型）
            if monitor.selectedTimeRange.showsDailyTrend {
                let sourceTotals = summary.dailyTrendPoints.filter { $0.source == source }
                let sourceModels = summary.dailyModelTrendPoints.filter { $0.source == source }
                dailyTrendChart(
                    sourceTotals: sourceTotals,
                    modelPoints: sourceModels,
                    hoverBinding: $chartHoverDate
                )
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - Daily Trend Line Chart

    /// grandTotal: 所有来源合并的每日总量（仅 All tab 传入）
    /// sourceTotals: 各来源每日合计线
    /// modelPoints: 各细分模型线（仅 AI tab 传入）
    @ViewBuilder
    private func dailyTrendChart(
        grandTotal: [(date: Date, tokens: Int)] = [],
        sourceTotals: [DailyTrendPoint],
        modelPoints: [DailyModelTrendPoint] = [],
        hoverBinding: Binding<Date?> = .constant(nil)
    ) -> some View {
        let hasData = !grandTotal.isEmpty || !sourceTotals.isEmpty || !modelPoints.isEmpty
        if !hasData {
            EmptyView()
        } else {
            let uniqueModelNames = modelPoints.map(\.model).uniqued()
            // 只有单个数据点的系列需要 PointMark（多点时 LineMark 自己会画线，PointMark 反而造成先出现点再出现线的视觉抖动）
            let grandTotalIsSingle = grandTotal.count == 1
            let singlePointSources = Set(
                Dictionary(grouping: sourceTotals, by: { $0.source.rawValue })
                    .filter { $0.value.count == 1 }.keys
            )
            let singlePointModels = Set(
                Dictionary(grouping: modelPoints, by: \.model)
                    .filter { $0.value.count == 1 }.keys
            )
            VStack(alignment: .leading, spacing: 6) {
                Text("Daily Trend")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)

                Chart {
                    // 总量线：最粗，主色（仅 All tab）
                    ForEach(grandTotal, id: \.date) { pt in
                        LineMark(
                            x: .value("Date", pt.date, unit: .day),
                            y: .value("Tokens", pt.tokens),
                            series: .value("Series", "Total")
                        )
                        .foregroundStyle(Color.primary.opacity(0.75))
                        .lineStyle(StrokeStyle(lineWidth: 3))
                        .interpolationMethod(.linear)

                        AreaMark(
                            x: .value("Date", pt.date, unit: .day),
                            y: .value("Tokens", pt.tokens),
                            series: .value("Series", "Total")
                        )
                        .foregroundStyle(Color.primary.opacity(0.04))
                        .interpolationMethod(.linear)

                        if grandTotalIsSingle {
                            PointMark(
                                x: .value("Date", pt.date, unit: .day),
                                y: .value("Tokens", pt.tokens)
                            )
                            .foregroundStyle(Color.primary.opacity(0.75))
                            .symbolSize(50)
                        }
                    }

                    // 来源合计线：粗实线；仅在 AI tab（grandTotal 为空）时附加阴影面积，All tab 阴影已由 Total 线承担
                    ForEach(sourceTotals) { pt in
                        let color = Color(hex: pt.source.color)

                        LineMark(
                            x: .value("Date", pt.date, unit: .day),
                            y: .value("Tokens", pt.tokens),
                            series: .value("Series", pt.source.rawValue)
                        )
                        .foregroundStyle(color)
                        .lineStyle(StrokeStyle(lineWidth: 2.5))
                        .interpolationMethod(.linear)

                        if grandTotal.isEmpty {
                            AreaMark(
                                x: .value("Date", pt.date, unit: .day),
                                y: .value("Tokens", pt.tokens),
                                series: .value("Series", pt.source.rawValue)
                            )
                            .foregroundStyle(color.opacity(0.08))
                            .interpolationMethod(.linear)
                        }

                        if singlePointSources.contains(pt.source.rawValue) {
                            PointMark(
                                x: .value("Date", pt.date, unit: .day),
                                y: .value("Tokens", pt.tokens)
                            )
                            .foregroundStyle(color)
                            .symbolSize(40)
                        }
                    }

                    // 模型细线：不同颜色 + 不同线型区分（仅 AI tab）
                    ForEach(modelPoints) { pt in
                        let idx = uniqueModelNames.firstIndex(of: pt.model) ?? 0
                        let color = Self.modelColorPalette[idx % Self.modelColorPalette.count]
                        let style = Self.modelLineStyles[idx % Self.modelLineStyles.count]

                        LineMark(
                            x: .value("Date", pt.date, unit: .day),
                            y: .value("Tokens", pt.tokens),
                            series: .value("Series", pt.model)
                        )
                        .foregroundStyle(color)
                        .lineStyle(style)
                        .interpolationMethod(.linear)

                        if singlePointModels.contains(pt.model) {
                            PointMark(
                                x: .value("Date", pt.date, unit: .day),
                                y: .value("Tokens", pt.tokens)
                            )
                            .foregroundStyle(color)
                            .symbolSize(15)
                        }
                    }

                    // Hover 竖线 + Tooltip
                    if let hoveredDate = hoverBinding.wrappedValue {
                        RuleMark(x: .value("Hover", hoveredDate, unit: .day))
                            .foregroundStyle(Color.secondary.opacity(0.25))
                            .lineStyle(StrokeStyle(lineWidth: 1))
                            .annotation(
                                position: .top,
                                spacing: 4,
                                overflowResolution: .init(x: .fit(to: .chart), y: .disabled)
                            ) {
                                chartTooltip(
                                    date: hoveredDate,
                                    grandTotal: grandTotal,
                                    sourceTotals: sourceTotals,
                                    modelPoints: modelPoints,
                                    uniqueModelNames: uniqueModelNames
                                )
                            }
                    }
                }
                .chartXAxis {
                    let allDates = grandTotal.map(\.date) + sourceTotals.map(\.date) + modelPoints.map(\.date)
                    let totalDays = Set(allDates.map { Calendar.current.startOfDay(for: $0) }).count
                    if totalDays <= 14 {
                        AxisMarks(values: .stride(by: .day)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    } else if totalDays <= 60 {
                        AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                        }
                    } else {
                        AxisMarks(values: .stride(by: .month)) { _ in
                            AxisGridLine()
                            AxisValueLabel(format: .dateTime.month(.abbreviated))
                        }
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Int.self) {
                                Text(formatTokenCount(v))
                            }
                        }
                    }
                }
                .chartLegend(.hidden)
                .frame(height: 160)
                .chartOverlay { proxy in
                    GeometryReader { geo in
                        let plotFrame = geo[proxy.plotAreaFrame]
                        Rectangle()
                            .fill(.clear)
                            .contentShape(Rectangle())
                            .onContinuousHover { phase in
                                switch phase {
                                case .active(let location):
                                    let xInPlot = location.x - plotFrame.origin.x
                                    guard xInPlot >= 0, xInPlot <= plotFrame.width else {
                                        hoverBinding.wrappedValue = nil
                                        return
                                    }
                                    if let rawDate: Date = proxy.value(atX: xInPlot, as: Date.self) {
                                        // 吸附到最近的数据日期
                                        let allDates = (grandTotal.map(\.date) + sourceTotals.map(\.date) + modelPoints.map(\.date))
                                            .map { Calendar.current.startOfDay(for: $0) }
                                        let uniqueDates = Array(Set(allDates)).sorted()
                                        hoverBinding.wrappedValue = uniqueDates.min {
                                            abs($0.timeIntervalSince(rawDate)) < abs($1.timeIntervalSince(rawDate))
                                        }
                                    }
                                case .ended:
                                    hoverBinding.wrappedValue = nil
                                }
                            }
                    }
                }

                // 图例
                HStack(spacing: 12) {
                    // Total（仅 All tab）
                    if !grandTotal.isEmpty {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color.primary.opacity(0.75))
                                .frame(width: 7, height: 7)
                            Text("Total")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    // 各来源
                    ForEach(sourceTotals.map(\.source).uniqued(), id: \.self) { source in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(Color(hex: source.color))
                                .frame(width: 7, height: 7)
                            Text(source.rawValue)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // 模型图例（仅 AI tab，各模型颜色+线型区分）
                if !uniqueModelNames.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(Array(uniqueModelNames.enumerated()), id: \.element) { idx, name in
                            HStack(spacing: 4) {
                                modelLineIndicator(
                                    color: Self.modelColorPalette[idx % Self.modelColorPalette.count],
                                    styleIndex: idx
                                )
                                Text(name)
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                        }
                    }
                }
            }
        }
    }

    /// 按日期聚合所有来源的合计（供 All tab 的 Total 线使用）
    private func dailyGrandTotal(from points: [DailyTrendPoint]) -> [(date: Date, tokens: Int)] {
        Dictionary(grouping: points, by: \.date)
            .map { (date: $0.key, tokens: $0.value.reduce(0) { $0 + $1.tokens }) }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Helpers

    /// 堆叠横向条形图：按 token 类型分段着色
    @ViewBuilder
    private func stackedBar(
        input: Int, output: Int, cacheRead: Int, cacheWrite: Int,
        maxTotal: Int, height: CGFloat = 8
    ) -> some View {
        let total = input + output + cacheRead + cacheWrite
        let overallRatio = maxTotal > 0 ? Double(total) / Double(maxTotal) : 0

        GeometryReader { geo in
            let barWidth = max(0, geo.size.width * overallRatio)

            ZStack(alignment: .leading) {
                // 背景
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.15))

                // 堆叠色块
                if total > 0 {
                    HStack(spacing: 0) {
                        // Cache Read (最大部分通常在前)
                        if cacheRead > 0 {
                            Rectangle()
                                .fill(Color.orange.opacity(0.7))
                                .frame(width: barWidth * Double(cacheRead) / Double(total))
                        }
                        // Cache Write
                        if cacheWrite > 0 {
                            Rectangle()
                                .fill(Color.purple.opacity(0.7))
                                .frame(width: barWidth * Double(cacheWrite) / Double(total))
                        }
                        // Input
                        if input > 0 {
                            Rectangle()
                                .fill(Color.blue.opacity(0.7))
                                .frame(width: barWidth * Double(input) / Double(total))
                        }
                        // Output
                        if output > 0 {
                            Rectangle()
                                .fill(Color.green.opacity(0.7))
                                .frame(width: barWidth * Double(output) / Double(total))
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                }
            }
        }
        .frame(height: height)
    }

    /// 图例 + 各类型数值（All tab 用 summary 版本）
    @ViewBuilder
    private func tokenTypeLegend(summary: TokenUsageSummary) -> some View {
        tokenTypeLegend(
            input: summary.totalInput,
            output: summary.totalOutput,
            cacheRead: summary.totalCacheRead,
            cacheWrite: summary.totalCacheWrite
        )
    }

    /// 图例 + 各类型数值
    @ViewBuilder
    private func tokenTypeLegend(input: Int, output: Int, cacheRead: Int, cacheWrite: Int) -> some View {
        let items: [(String, Int, Color)] = [
            ("Cache Read", cacheRead, .orange),
            ("Cache Write", cacheWrite, .purple),
            ("Input", input, .blue),
            ("Output", output, .green),
        ].filter { $0.1 > 0 }

        HStack(spacing: 16) {
            ForEach(items, id: \.0) { label, value, color in
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(color.opacity(0.7))
                        .frame(width: 10, height: 10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(formatTokenCount(value))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(color)
                    }
                }
            }
        }
    }

    // MARK: - Hover Tooltip

    @ViewBuilder
    private func chartTooltip(
        date: Date,
        grandTotal: [(date: Date, tokens: Int)],
        sourceTotals: [DailyTrendPoint],
        modelPoints: [DailyModelTrendPoint],
        uniqueModelNames: [String]
    ) -> some View {
        let cal = Calendar.current
        let gtPt  = grandTotal.first  { cal.isDate($0.date, inSameDayAs: date) }
        let srcPts = sourceTotals.filter { cal.isDate($0.date, inSameDayAs: date) }
        let mdlPts = modelPoints.filter  { cal.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.tokens > $1.tokens }

        VStack(alignment: .leading, spacing: 5) {
            Text(date, format: .dateTime.month(.abbreviated).day(.defaultDigits))
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            if gtPt != nil || !srcPts.isEmpty || !mdlPts.isEmpty {
                Divider()
            }

            if let pt = gtPt {
                tooltipRow(dot: Color.primary.opacity(0.75), label: "Total", tokens: pt.tokens)
            }
            ForEach(srcPts) { pt in
                tooltipRow(dot: Color(hex: pt.source.color), label: pt.source.rawValue, tokens: pt.tokens)
            }
            ForEach(mdlPts) { pt in
                let idx = uniqueModelNames.firstIndex(of: pt.model) ?? 0
                let color = Self.modelColorPalette[idx % Self.modelColorPalette.count]
                tooltipRow(dot: color, label: pt.model, tokens: pt.tokens)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.regularMaterial))
        .frame(minWidth: 160)
    }

    @ViewBuilder
    private func tooltipRow(dot: Color, label: String, tokens: Int) -> some View {
        HStack(spacing: 5) {
            Circle().fill(dot).frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 8)
            Text(formatTokenCount(tokens))
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
        }
    }

    /// 图例中对应模型线型的小图标（颜色 + 虚实形状）
    @ViewBuilder
    private func modelLineIndicator(color: Color, styleIndex: Int) -> some View {
        switch styleIndex % Self.modelLineStyles.count {
        case 0: // 实线
            Rectangle()
                .fill(color)
                .frame(width: 18, height: 1.5)
        case 1: // 长虚线
            HStack(spacing: 3) {
                Rectangle().fill(color).frame(width: 7, height: 1.5)
                Rectangle().fill(color).frame(width: 7, height: 1.5)
            }
        case 2: // 点线
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(color).frame(width: 2.5, height: 2.5)
                }
            }
        case 3: // 点划线
            HStack(spacing: 2) {
                Rectangle().fill(color).frame(width: 6, height: 1.5)
                Circle().fill(color).frame(width: 2.5, height: 2.5)
                Rectangle().fill(color).frame(width: 6, height: 1.5)
            }
        default: // 短虚线
            HStack(spacing: 2) {
                ForEach(0..<3, id: \.self) { _ in
                    Rectangle().fill(color).frame(width: 4, height: 1.5)
                }
            }
        }
    }

    @ViewBuilder
    private func emptyState(message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "chart.bar.xaxis")
                .font(.system(size: 36))
                .foregroundStyle(.quaternary)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
    

}

// MARK: - Usage Filter Chip (matching Session Manager's FilterChip)

private struct UsageFilterChipButton: View {
    let label: String
    var aiType: AIType? = nil
    let isActive: Bool
    let action: () -> Void
    @State private var isHovered = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if let aiType {
                    AILogoView(aiType: aiType, size: 14)
                }
                Text(label)
                    .font(.system(size: 12, weight: isActive ? .semibold : .regular))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(isActive ? Color.accentColor.opacity(0.2) : (isHovered ? Color.primary.opacity(0.06) : Color.primary.opacity(0.03)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isActive ? Color.accentColor.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Time Range Picker

/// 紧凑的时间范围选择器（分段控件风格）
private struct TimeRangePicker: View {
    @Binding var selected: UsageTimeRange
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(UsageTimeRange.allCases, id: \.self) { range in
                TimeRangeButton(
                    label: range.rawValue,
                    isSelected: selected == range
                ) {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selected = range
                    }
                }
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.05))
        )
    }
}

/// 单个时间范围按钮
private struct TimeRangeButton: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Group {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.accentColor.opacity(0.7))
                        } else if isHovered {
                            RoundedRectangle(cornerRadius: 5)
                                .fill(Color.primary.opacity(0.06))
                        }
                    }
                )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Array Uniqued Helper

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - Flow Layout (wrap model legend items)

private struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = bounds.minX
        var y: CGFloat = bounds.minY
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX {
                x = bounds.minX
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
