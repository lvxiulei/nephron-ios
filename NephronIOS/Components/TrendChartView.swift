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

    private var hasTrend: Bool { points.count > 1 }

    private var xDomain: ClosedRange<Date> {
        guard let first = points.first, let last = points.last else {
            return Date()...Date().addingTimeInterval(1)
        }
        if first.date == last.date {
            return first.date.addingTimeInterval(-12 * 3600)...last.date.addingTimeInterval(12 * 3600)
        }
        let span = last.date.timeIntervalSince(first.date)
        let pad = max(span * 0.04, 6 * 3600)
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
        VStack(alignment: .leading, spacing: 12) {
            chart
            if let index = selectedIndex, points.indices.contains(index) {
                selectionCard(for: points[index])
                    .id(points[index].id)
            } else if let last = points.last {
                selectionCard(for: last)
                    .id(last.id)
            }
        }
        .onAppear {
            // 默认选中最新一条
            selectedIndex = points.indices.last
        }
        .onChange(of: points.map(\.id)) {
            selectedIndex = points.indices.last
        }
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
        .chartXAxis {
            AxisMarks(values: xAxisValues) { _ in
                AxisValueLabel(
                    format: .dateTime
                        .month(.twoDigits)
                        .day(.twoDigits)
                        .locale(DayDate.displayLocale)
                )
                AxisGridLine().foregroundStyle(.clear)
                AxisTick().foregroundStyle(.clear)
            }
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

    /// 选中点详情卡：完整日期 + eGFR 数值同层级 + 已填写可选指标竖向列表。
    private func selectionCard(for point: TrendDataPoint) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(DayDate.displayFormatter.string(from: point.date))
                .font(.footnote.weight(.medium))
                .foregroundStyle(Palette.secondaryText)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(EGFRCalculator.formattedNumber(point.egfr))
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Palette.primary)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("eGFR")
                    .font(.subheadline)
                    .foregroundStyle(Palette.primaryText)
            }

            let entries = point.record.filledMetricEntries
            if !entries.isEmpty {
                VStack(spacing: 6) {
                    ForEach(entries) { entry in
                        HStack(alignment: .firstTextBaseline) {
                            Text(entry.name)
                                .font(.footnote)
                                .foregroundStyle(Palette.secondaryText)
                            Spacer(minLength: 12)
                            Text(entry.valueText)
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Palette.primaryText)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.mintCard, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            "\(DayDate.displayFormatter.string(from: point.date))，eGFR \(EGFRCalculator.formattedNumber(point.egfr))"
        )
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
