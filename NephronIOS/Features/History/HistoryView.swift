import SwiftUI
import SwiftData

/// 删除确认流程状态。
/// 注意：必须放在 @Observable 类里、由独立子层呈现，而不是 HistoryView 的 @State——
/// 左滑收拢期间变更持有 List 的视图的 @State 会让 List 重算并把滚动位置重置回
/// 顶部（整页跳动）。HistoryView 的 body 不读取本类属性，点删除按钮时就不会重算。
@Observable @MainActor
private final class DeleteFlow {
    var pending: RecordModel?
    var showsConfirm = false
    var errorText: String?
    var showsError = false

    func request(_ record: RecordModel) {
        pending = record
        showsConfirm = true
    }

    func cancel() {
        showsConfirm = false
        pending = nil
    }
}

/// 只承载删除确认弹框的独立呈现层，不包含列表。
private struct DeleteConfirmLayer: View {
    @Bindable var flow: DeleteFlow
    let onDelete: (RecordModel) -> Void
    let onDismiss: () -> Void

    var body: some View {
        Color.clear
            .alert("删除这条记录？", isPresented: $flow.showsConfirm) {
                Button("删除", role: .destructive) {
                    flow.showsConfirm = false
                    if let record = flow.pending {
                        flow.pending = nil
                        onDelete(record)
                    }
                }
                Button("取消", role: .cancel) {
                    flow.cancel()
                }
            }
            .alert("删除失败", isPresented: $flow.showsError) {
                Button("我知道了", role: .cancel) {
                    flow.showsError = false
                }
            } message: {
                Text(flow.errorText ?? "")
            }
            // 确认框关闭后再收起行内展开的删除按钮：与弹框呈现同帧重算会取消呈现
            .onChange(of: flow.showsConfirm) { _, shows in
                if !shows { onDismiss() }
            }
    }
}

/// 记录 Tab：双摘要 + eGFR 趋势 + 记录列表（删除带确认）+ 空状态。
struct HistoryView: View {
    @Environment(RecordStore.self) private var store
    @Environment(\.switchTab) private var switchTab
    @State private var deleteFlow = DeleteFlow()
    @State private var openRecordID: PersistentIdentifier?

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
        .background {
            DeleteConfirmLayer(
                flow: deleteFlow,
                onDelete: { record in deleteRecord(record) },
                onDismiss: {
                    withAnimation(.smooth(duration: 0.2)) {
                        openRecordID = nil
                    }
                }
            )
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

    /// 方案 A：摘要与趋势保持卡片视觉，记录区为系统分组列表（标准左滑删除）。
    private var content: some View {
        ScrollViewReader { proxy in
            List {
                Section {
                    cardListRow(summaryRow)
                } header: {
                    pageHeader
                        .textCase(nil)
                        // insetGrouped 的 Section 标题自带额外缩进和顶部留白；
                        // 对齐其他 Tab 的页头，且避开普通行的圆角裁剪。
                        .padding(.leading, -16)
                        .padding(.top, -12)
                        .padding(.bottom, 6)
                }
                .listSectionSpacing(20)

                Section {
                    cardListRow(trendCard)
                }
                .listSectionSpacing(20)

                Section {
                    // 表头：左「检验信息」右「eGFR」，与记录行数值列（宽 68、尾对齐）同列
                    listHeaderRow
                        .id("history-list-header")
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    // 存储层按日期正序（供趋势图从左到右递增）；列表展示反转：最新在前，
                    // 同日多条时创建最晚的在前
                    ForEach(store.records.reversed(), id: \.persistentModelID) { record in
                        RecordSwipeRow(
                            record: record,
                            openRecordID: $openRecordID,
                            onDeleteRequest: { deleteFlow.request(record) }
                        )
                        .id(record.persistentModelID)
                        .listRowBackground(Palette.card)
                        .accessibilityHint("左滑可删除")
                        .accessibilityAction(named: "删除") {
                            deleteFlow.request(record)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .listRowSpacing(0)
            .environment(\.defaultMinListRowHeight, 0)
            .scrollContentBackground(.hidden)
            .background(Palette.background)
            .contentMargins(.top, 12, for: .scrollContent)
            .contentMargins(.bottom, 96, for: .scrollContent)
            .onAppear {
                // 截图钩子：滚动到表头（表头顶部对齐可视区顶部），供大字体截图用。
                // 大字体下外部坐标拖拽会落在趋势图或行滑动手势上，无法可靠滚动
                if UITestHooks.historyScrollToRecords {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                        withAnimation(.smooth(duration: 0.3)) {
                            proxy.scrollTo("history-list-header", anchor: .top)
                        }
                    }
                }
            }
        }
    }

    /// 卡片式行保持原卡片视觉：透明行背景、零内边距、无分隔线。
    private func cardListRow(_ row: some View) -> some View {
        row
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
    }

    // MARK: 页头

    /// 页头：与「计算」「了解」两页同款的大标题 + 一句说明。
    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("变化要连起来看。")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Palette.primaryText)
            Text("每一次检验都会留在这里，组成你的 eGFR 趋势。")
                .font(.subheadline)
                .foregroundStyle(Palette.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }

    /// 记录列表表头：右列与记录行 eGFR 数值（宽 68、尾对齐）同列对齐。
    /// XXXL 下「eGFR」文字宽超 68pt，锁定单行并允许缩放（与记录行数值同款处理），否则被硬折行
    private var listHeaderRow: some View {
        HStack {
            Text("检验信息")
                .lineLimit(1)
            Spacer(minLength: 8)
            Text("eGFR")
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .frame(width: 68, alignment: .trailing)
        }
        .font(.footnote)
        .foregroundStyle(Palette.secondaryText)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 44)
        .background {
            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 26, topTrailing: 26))
                .fill(Palette.optPanel)
        }
        .overlay {
            UnevenRoundedRectangle(cornerRadii: .init(topLeading: 26, topTrailing: 26))
                .strokeBorder(Palette.hairline, lineWidth: 1)
        }
        .padding(.top, 1)
        .accessibilityElement(children: .combine)
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
                    // 单位锁定单行并优先取足宽度：XXXL 下宽度不足时由左侧
                    // 数值（已有 minimumScaleFactor）缩让，而不是单位折行
                    .lineLimit(1)
                    .layoutPriority(1)
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
        }
        .cardStyle()
        .accessibilityElement(children: .contain)
    }

    // MARK: 记录列表

    private func deleteRecord(_ record: RecordModel) {
        do {
            try store.deleteRecord(record)
        } catch {
            deleteFlow.errorText = (error as? StorageError)?.errorDescription ?? StorageError.deleteFailed.errorDescription
            deleteFlow.showsError = true
        }
    }
}

/// 单条记录行：检验信息 / eGFR，自绘左滑露出删除按钮。
/// 不用系统 swipeActions：iOS 26/27 上点击其按钮会让 List 重载并把滚动位置
/// 重置回顶部（整页跳动）；自绘滑动露出的普通按钮无此问题（已用帧采样探针验证）。
private struct RecordSwipeRow: View {
    let record: RecordModel
    @Binding var openRecordID: PersistentIdentifier?
    let onDeleteRequest: () -> Void

    @State private var offsetX: CGFloat = 0
    private let revealWidth: CGFloat = 64

    private var isOpen: Bool { openRecordID == record.persistentModelID }

    var body: some View {
        ZStack(alignment: .trailing) {
            // 仅在露出期间渲染删除按钮：收起的行不能存在被遮挡的按钮元素，
            // 否则可达性树里会出现多个“删除”，点击与 VoiceOver 都无法定位
            if offsetX < -0.5 {
                Button {
                    onDeleteRequest()
                } label: {
                    Image(systemName: "trash")
                        .font(.body.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(width: revealWidth - 8)
                        .frame(maxHeight: .infinity)
                        .background(Color.red, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("删除")
            }

            rowContent
                .background(Palette.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .offset(x: offsetX)
                .simultaneousGesture(revealGesture)
                .onTapGesture {
                    // 点击任意行收起当前展开的删除按钮
                    if openRecordID != nil {
                        withAnimation(.smooth(duration: 0.2)) {
                            openRecordID = nil
                        }
                    }
                }
                .onChange(of: openRecordID) { _, newID in
                    if newID != record.persistentModelID, offsetX != 0 {
                        withAnimation(.smooth(duration: 0.2)) {
                            offsetX = 0
                        }
                    }
                }
        }
        // 与系统左滑一致：内容滑出在卡片边缘裁切，而不是屏幕边缘
        .clipped()
    }

    private var rowContent: some View {
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

            Text(EGFRCalculator.formattedNumber(record.egfr))
                .font(.headline)
                .foregroundStyle(Palette.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(width: 68, alignment: .trailing)
                .accessibilityLabel("eGFR \(EGFRCalculator.formattedNumber(record.egfr))")
        }
        .padding(.vertical, 4)
    }

    /// 横向拖拽露出/收起删除按钮；纵向交给 List 滚动。
    private var revealGesture: some Gesture {
        DragGesture(minimumDistance: 12)
            .onChanged { value in
                guard abs(value.translation.width) > max(12, abs(value.translation.height) * 1.5) else { return }
                let base: CGFloat = isOpen ? -revealWidth : 0
                offsetX = min(0, max(-revealWidth, base + value.translation.width))
            }
            .onEnded { value in
                guard abs(value.translation.width) > max(24, abs(value.translation.height) * 1.5) else {
                    withAnimation(.smooth(duration: 0.22)) {
                        offsetX = isOpen ? -revealWidth : 0
                    }
                    return
                }
                let shouldOpen = value.predictedEndTranslation.width < -revealWidth * 0.6
                    || value.translation.width < -24
                withAnimation(.smooth(duration: 0.22)) {
                    if shouldOpen {
                        openRecordID = record.persistentModelID
                        offsetX = -revealWidth
                    } else {
                        openRecordID = nil
                        offsetX = 0
                    }
                }
            }
    }
}
