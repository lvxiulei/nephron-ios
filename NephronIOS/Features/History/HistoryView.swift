import SwiftUI

/// 记录 Tab：双摘要 + eGFR 趋势 + 记录列表（删除带确认）+ 空状态。
struct HistoryView: View {
    @Environment(RecordStore.self) private var store
    @Environment(\.switchTab) private var switchTab
    @State private var recordPendingDelete: RecordModel?
    @State private var deleteErrorText: String?
    @State private var showsDeleteError = false

    var body: some View {
        Group {
            if store.records.isEmpty {
                emptyState
            } else {
                content
            }
        }
        .background(Palette.background)
        .onAppear {
            store.reload()
        }
        // 删除记录等数量变化时的轻微触感
        .sensoryFeedback(.impact(weight: .light), trigger: store.recordCount)
        .confirmationDialog(
            "删除这条记录？",
            isPresented: Binding(
                get: { recordPendingDelete != nil },
                set: { if !$0 { recordPendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除本机记录", role: .destructive) {
                deletePending()
            }
            Button("取消", role: .cancel) {
                recordPendingDelete = nil
            }
        } message: {
            Text("删除后本机记录不可恢复，且不影响其他设备数据。")
        }
        .alert("删除失败", isPresented: $showsDeleteError) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(deleteErrorText ?? "")
        }
    }

    private var emptyState: some View {
        EmptyStateView(
            systemImage: "chart.xyaxis.line",
            title: "这里还没有记录",
            message: "完成一次计算后，点“保存这次记录”，趋势会从第一条开始。",
            actionTitle: "去计算 eGFR"
        ) {
            switchTab(.calculator)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var content: some View {
        ScrollView {
            VStack(spacing: 16) {
                summaryRow
                trendCard
                recordListCard
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .contentMargins(.bottom, 96, for: .scrollContent)
        .background(Palette.background)
    }

    // MARK: 双摘要

    private var summaryRow: some View {
        HStack(spacing: 12) {
            summaryCard(title: "已记录次数", value: "\(store.recordCount)", unit: "次", identifier: "history.summary.count.value")
            summaryCard(title: "最近 eGFR", value: store.latestEGFRText ?? "—", unit: "eGFR", identifier: "history.summary.latest.value")
        }
    }

    private func summaryCard(title: String, value: String, unit: String, identifier: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(Palette.secondaryText)
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(value)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Palette.primaryText)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .accessibilityIdentifier(identifier)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardStyle()
    }

    // MARK: 趋势卡片

    private var trendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("eGFR 趋势")
                    .font(.headline)
                    .foregroundStyle(Palette.primaryText)
                Text("按检验日期排列")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
            }
            TrendChartView(points: store.records.map(TrendDataPoint.init(record:)))
            Text("只用于看变化，不替代医生判断")
                .font(.caption)
                .foregroundStyle(Palette.secondaryText)
        }
        .cardStyle()
        .accessibilityElement(children: .contain)
    }

    // MARK: 记录列表

    private var recordListCard: some View {
        VStack(spacing: 0) {
            ForEach(Array(store.records.enumerated()), id: \.element.persistentModelID) { index, record in
                if index > 0 {
                    Divider()
                        .overlay(Palette.hairline)
                        .padding(.leading, 0)
                }
                recordRow(record)
            }
        }
        .cardStyle()
    }

    /// 固定三列：检验信息 / eGFR / 操作。
    private func recordRow(_ record: RecordModel) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(DayDate.displayFormatter.string(from: record.measuredOn))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Palette.primaryText)
                Text("肌酐 \(EGFRCalculator.formattedNumber(record.creatinine)) \(record.creatinineUnit.displayName)")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            VStack(alignment: .trailing, spacing: 2) {
                Text(EGFRCalculator.formattedNumber(record.egfr))
                    .font(.headline)
                    .foregroundStyle(Palette.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text("eGFR")
                    .font(.caption2)
                    .foregroundStyle(Palette.secondaryText)
            }
            .frame(width: 68, alignment: .trailing)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("eGFR \(EGFRCalculator.formattedNumber(record.egfr))")

            Button {
                recordPendingDelete = record
            } label: {
                Image(systemName: "trash")
                    .font(.subheadline)
                    .foregroundStyle(Palette.danger)
                    .frame(width: 40, height: 36)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("删除 \(DayDate.displayFormatter.string(from: record.measuredOn)) 的记录")
        }
        .padding(.vertical, 10)
    }

    private func deletePending() {
        guard let record = recordPendingDelete else { return }
        recordPendingDelete = nil
        do {
            try store.deleteRecord(record)
        } catch {
            deleteErrorText = (error as? StorageError)?.errorDescription ?? StorageError.deleteFailed.errorDescription
            showsDeleteError = true
        }
    }
}
