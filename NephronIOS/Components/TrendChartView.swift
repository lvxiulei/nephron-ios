import SwiftUI
import Charts

/// 趋势图数据点。
struct TrendDataPoint: Identifiable {
    let id: UUID
    let date: Date
    let egfr: Double
    let record: RecordModel

    init(record: RecordModel) {
        self.id = record.id
        self.date = record.measuredOn
        self.egfr = record.egfr
        self.record = record
    }
}

/// eGFR 趋势折线图：少于两条记录只显示单点；支持点击 / 拖动吸附最近点；
/// 选中点显示参考竖线与下方详情卡。
struct TrendChartView: View {
    let points: [TrendDataPoint]
    @State private var selectedIndex: Int?

    /// X 轴日期标签区的留白高度：绘图区底部 padding 与 overlay 内标签 y
    /// （height − areaHeight / 2，标签垂直居中于该区）共用同一常量，改动需两处联动。
    private static let xAxisLabelAreaHeight: CGFloat = 18

    private var hasTrend: Bool { points.count > 1 }

    private var xDomain: ClosedRange<Date> {
        guard let first = points.first, let last = points.last else {
            return Date()...Date().addingTimeInterval(1)
        }
        if first.date == last.date {
            return first.date.addingTimeInterval(-12 * 3600)...last.date.addingTimeInterval(12 * 3600)
        }
        let span = last.date.timeIntervalSince(first.date)
        let pad = max(span * 0.11, 6 * 3600)
        return first.date.addingTimeInterval(-pad)...last.date.addingTimeInterval(pad)
    }

    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.egfr)
        let lowest = values.min() ?? 0
        let highest = values.max() ?? 100
        let pad = Swift.max((highest - lowest) * 0.18, 6)
        return Swift.max(0, lowest - pad)...highest + pad
    }

    private var xAxisValues: [Date] {
        guard let first = points.first, let last = points.last else { return [] }
        return first.date == last.date ? [first.date] : [first.date, last.date]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            chartWithTooltip
            metricsStrip
        }
        .onAppear {
            if UITestHooks.trendSelectLast {
                selectedIndex = points.indices.last
            }
        }
    }

    /// 固定高度指标条（方案 A）：图表与 X 轴高度恒定，杜绝拖动切换点位时底部跳动。
    /// 无选中/无指标时显示占位文案，指标多于一屏时条内横向滑动——高度始终 52pt。
    private var metricsStrip: some View {
        VStack(spacing: 0) {
            Rectangle().fill(Palette.hairline).frame(height: 0.5)
            ZStack {
                if let index = selectedIndex, points.indices.contains(index) {
                    chipsRow(for: points[index])
                } else {
                    Text("按住图表，查看所选日期的补充指标")
                        .font(.system(size: 9.5))
                        .foregroundStyle(Palette.tipCaption)
                }
            }
            .frame(height: 52)
            .frame(maxWidth: .infinity)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("trend.detail")
        }
    }

    private func chipsRow(for point: TrendDataPoint) -> some View {
        let entries = point.record.filledMetricEntries
        return Group {
            if entries.isEmpty {
                Text("该次无补充指标")
                    .font(.system(size: 9.5))
                    .foregroundStyle(Palette.tipCaption)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(entries) { entry in
                            metricChip(entry)
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }
        }
    }

    /// 点位于图宽的相对位置（0–1），用于决定提示卡放左上还是右上。
    private func xRatio(of date: Date) -> Double {
        let domain = xDomain
        let span = domain.upperBound.timeIntervalSince(domain.lowerBound)
        guard span > 0 else { return 0.5 }
        return min(max(date.timeIntervalSince(domain.lowerBound) / span, 0), 1)
    }

    private var chartWithTooltip: some View {
        chart
            .overlay(alignment: .top) {
                if let index = selectedIndex, points.indices.contains(index) {
                    let anchorRight = xRatio(of: points[index].date) > 0.48
                    tooltip(for: points[index])
                        .padding(.horizontal, 6)
                        .padding(.top, 9)
                        .frame(maxWidth: .infinity, alignment: anchorRight ? .trailing : .leading)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(.smooth(duration: 0.15), value: selectedIndex)
    }

    /// 图内浮动提示卡：日期 + 大号 eGFR（紧凑，宽度贴合内容）。
    private func tooltip(for point: TrendDataPoint) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(DayDate.shortDisplayFormatter.string(from: point.date))
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Palette.tipDate)
                .padding(.bottom, 2)
                .fixedSize()
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Palette.hairline).frame(height: 0.5)
                }
            HStack(alignment: .firstTextBaseline, spacing: 2.5) {
                Text(EGFRCalculator.formattedNumber(point.egfr))
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.tipValue)
                    .lineLimit(1)
                    .fixedSize()
                Text("eGFR")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(Palette.tipUnit)
                    .fixedSize()
            }
            .padding(.top, 2.5)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .fixedSize()
        .background(Palette.tipBg, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .strokeBorder(Palette.tipBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(DayDate.displayFormatter.string(from: point.date))，eGFR \(EGFRCalculator.formattedNumber(point.egfr))")
        .accessibilityIdentifier("trend.tooltip")
    }


    /// 单个指标小卡片：上名称（可换行自适应）、下数值+单位。
    private func metricChip(_ entry: OptionalMetricEntry) -> some View {
        VStack(alignment: .center, spacing: 3) {
            Text(entry.name)
                .font(.system(size: 9))
                .foregroundStyle(Palette.tipCaption)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity)
            Text(entry.valueText)
                .font(.system(size: 10.5, weight: .semibold))
                .foregroundStyle(Palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.55)
                .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 5)
        .frame(maxWidth: .infinity)
        .background(Palette.tipBg, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Palette.tipBorder.opacity(0.6), lineWidth: 0.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(entry.name) \(entry.valueText)")
    }

    private var chart: some View {
        Chart {
            ForEach(Array(points.enumerated()), id: \.element.id) { index, point in
                if hasTrend {
                    LineMark(
                        x: .value("检验日期", point.date),
                        y: .value("eGFR", point.egfr)
                    )
                    .foregroundStyle(Palette.primary)
                    .interpolationMethod(.monotone)
                    .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                }
                PointMark(
                    x: .value("检验日期", point.date),
                    y: .value("eGFR", point.egfr)
                )
                .foregroundStyle(selectedIndex == index ? Palette.primary : Palette.primary.opacity(0.75))
                .symbolSize(selectedIndex == index ? 240 : 110)
                .accessibilityLabel("eGFR \(EGFRCalculator.formattedNumber(point.egfr))，\(DayDate.displayFormatter.string(from: point.date))")
            }

            if let index = selectedIndex, points.indices.contains(index) {
                RuleMark(x: .value("检验日期", points[index].date))
                    .foregroundStyle(Palette.secondaryText.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .accessibilityHidden(true)
            }
        }
        .chartXScale(domain: xDomain)
        .chartYScale(domain: yDomain)
        // 隐藏系统 X 轴（其标签在 iOS 27 存在丢失/自动补刻度问题），
        // 首尾日期由 chartOverlay 用 ChartProxy 精确绘制在数据点正下方
        .chartXAxis(.hidden)
        .chartPlotStyle { plot in
            plot.padding(.bottom, Self.xAxisLabelAreaHeight)
        }
        .chartYAxis {
            AxisMarks { _ in
                AxisGridLine().foregroundStyle(Palette.hairline)
                AxisValueLabel()
                    .font(.caption2)
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .frame(height: 210)
        .chartOverlay { proxy in
            GeometryReader { geometry in
                // 首尾日期：标签中心 = 数据点 x（与竖直虚线天然对齐）
                ForEach(xAxisValues, id: \.self) { date in
                    if let x = proxy.position(forX: date) {
                        Text(DayDate.shortDisplayFormatter.string(from: date))
                            .font(.caption2)
                            .foregroundStyle(Palette.secondaryText)
                            .fixedSize()
                            .position(x: x, y: geometry.size.height - Self.xAxisLabelAreaHeight / 2)
                    }
                }
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { gesture in
                                let originX = proxy.plotFrame.map { geometry[$0].origin.x } ?? 0
                                handleSelection(
                                    x: gesture.location.x - originX,
                                    proxy: proxy
                                )
                            }
                    )
            }
        }
        .accessibilityLabel("eGFR 趋势图，共 \(points.count) 条记录，拖动查看每次记录")
    }

    private func handleSelection(x: CGFloat, proxy: ChartProxy) {
        guard x >= 0, let value = proxy.value(atX: x, as: Date.self) else { return }
        guard let nearest = points.enumerated().min(by: {
            abs($0.element.date.timeIntervalSince(value)) < abs($1.element.date.timeIntervalSince(value))
        }) else { return }
        withAnimation(.snappy(duration: 0.15)) {
            selectedIndex = nearest.offset
        }
    }
}
