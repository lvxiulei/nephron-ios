import SwiftUI
import SwiftData

/// 计算 Tab：输入检验信息 → 得到 eGFR 估算 → 保存 / 同日期对照 / 补充可选指标。
struct CalculatorView: View {
    @Environment(RecordStore.self) private var store
    @Environment(\.switchTab) private var switchTab
    @State private var viewModel: CalculatorViewModel?

    var body: some View {
        Group {
            if let viewModel {
                CalculatorContent(viewModel: viewModel, onViewRecords: {
                    switchTab(.history)
                })
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Palette.background)
        .onAppear {
            if viewModel == nil {
                let newViewModel = CalculatorViewModel(store: store)
                viewModel = newViewModel
                if UITestHooks.autoCalculate {
                    newViewModel.calculateTapped()
                }
                if UITestHooks.triggerComparison {
                    newViewModel.calculateTapped()
                    newViewModel.saveEgfrTapped()
                }
            }
        }
    }
}

private struct CalculatorContent: View {
    @Bindable var viewModel: CalculatorViewModel
    let onViewRecords: () -> Void

    private enum InputField {
        case age
        case creatinine
    }

    @FocusState private var focusedField: InputField?

    /// 结果大号数值随动态字体缩放（相对 largeTitle）。
    @ScaledMetric(relativeTo: .largeTitle) private var resultNumberSize: CGFloat = 54

    /// 方案 C：标签列定宽（两行同宽 → 输入框天然等宽）。
    @ScaledMetric(relativeTo: .subheadline) private var unitLabelWidth: CGFloat = 60

    @State private var showsDatePicker = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 16) {
                    header
                    inputCard
                    if let result = viewModel.displayResult {
                        resultCard(result: result)
                        optionalMetricsCard
                    }
                    bottomDisclaimer
                        .id("calculator-bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .scrollDismissesKeyboard(.immediately)
            // 悬浮 Tab 栏会盖住滚动内容底部，留出固定底边距
            .contentMargins(.bottom, 96, for: .scrollContent)
            .background(Palette.background)
            .onAppear {
                if UITestHooks.scrollToBottom {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                        withAnimation {
                            proxy.scrollTo("calculator-bottom", anchor: .bottom)
                        }
                    }
                }
            }
        }
        // 对照弹层用 fullScreenCover 呈现：键盘收起后系统可能残留透明层吞掉
        // 普通-overlay 上的点击；真实呈现层不受影响
        .fullScreenCover(
            isPresented: Binding(
                get: { viewModel.comparisonTarget != nil },
                set: { if !$0 { viewModel.comparisonDismissed() } }
            )
        ) {
            if let existing = viewModel.comparisonTarget {
                ComparisonOverlay(
                    existing: existing,
                    dateText: viewModel.comparisonDateText,
                    onUpdate: { viewModel.comparisonUpdateTapped() },
                    onKeepNew: { viewModel.comparisonKeepNewTapped() },
                    onDismiss: { viewModel.comparisonDismissed() }
                )
                .transaction { $0.disablesAnimations = true }
            } else {
                Color.clear
            }
        }
        .onChange(of: focusedField) { old, new in
            if old == .age, new != .age {
                viewModel.ageDidEndEditing()
            }
            if old == .creatinine, new != .creatinine {
                viewModel.creatinineDidEndEditing()
            }
        }
        .sheet(isPresented: $showsDatePicker) {
            datePickerSheet
        }
        .animation(.smooth(duration: 0.22), value: viewModel.displayResult != nil)
        // 多模态反馈：保存成功 / 保存失败
        .sensoryFeedback(.success, trigger: viewModel.savedRecordID)
        .sensoryFeedback(.error, trigger: viewModel.showsStorageError)
        .alert(
            "保存失败",
            isPresented: Binding(
                get: { viewModel.showsStorageError },
                set: { viewModel.showsStorageError = $0 }
            )
        ) {
            Button("我知道了", role: .cancel) {}
        } message: {
            Text(viewModel.storageErrorText ?? "")
        }
        .toolbar {
            // 数字键盘没有回车键，提供显式的“完成”收起键盘
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    focusedField = nil
                }
                .accessibilityIdentifier("calculator.keyboard.done")
            }
        }
    }

    // MARK: 头部

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("先把检验单看明白。")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Palette.primaryText)
                Text("输入检验单上的信息，得到一次清晰的 eGFR 估算。")
                    .font(.subheadline)
                    .foregroundStyle(Palette.secondaryText)
            }
            Spacer(minLength: 8)
            Label("仅本机保存", systemImage: "lock.fill")
                .font(.caption2)
                .foregroundStyle(Palette.secondaryText)
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Palette.card, in: Capsule())
                .fixedSize()
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: 主输入卡片

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("这次检验")
                    .font(.headline)
                    .foregroundStyle(Palette.primaryText)
                Text("只需三项信息")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
            }

            // 生物学性别
            VStack(alignment: .leading, spacing: 6) {
                Text("生物学性别")
                    .font(.subheadline)
                    .foregroundStyle(Palette.primaryText)
                Picker("生物学性别", selection: $viewModel.sex) {
                    Text("女").tag(BiologicalSex.female)
                    Text("男").tag(BiologicalSex.male)
                }
                .pickerStyle(.segmented)
                .frame(height: 42)
            }

            // 年龄（方案 C：标签左、输入框右，与血肌酐框等宽等高）
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text("年龄")
                        .font(.subheadline)
                        .foregroundStyle(Palette.primaryText)
                        .frame(width: unitLabelWidth, alignment: .leading)
                    TextField("如 45", text: $viewModel.ageText)
                        .keyboardType(.numberPad)
                        .font(.body)
                        .foregroundStyle(Palette.primaryText)
                        .focused($focusedField, equals: .age)
                        .padding(.horizontal, 12)
                        .frame(height: 42)
                        .frame(maxWidth: .infinity)
                        .background(Palette.fieldBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay {
                            if viewModel.ageErrorText != nil {
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Palette.danger.opacity(0.7), lineWidth: 1)
                            }
                        }
                        .onChange(of: viewModel.ageText) { _, _ in
                            viewModel.ageTextEdited()
                        }
                        .accessibilityIdentifier("calculator.age.field")
                }
                if let error = viewModel.ageErrorText {
                    FieldErrorText(message: error)
                }
            }

            // 血肌酐（方案 C：单位内嵌输入框右侧，框与年龄框等宽等高）
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 10) {
                    Text("血肌酐")
                        .font(.subheadline)
                        .foregroundStyle(Palette.primaryText)
                        .frame(width: unitLabelWidth, alignment: .leading)
                    HStack(spacing: 8) {
                        TextField("如 75", text: $viewModel.creatinineText)
                            .keyboardType(.decimalPad)
                            .font(.body)
                            .foregroundStyle(Palette.primaryText)
                            .focused($focusedField, equals: .creatinine)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .onChange(of: viewModel.creatinineText) { _, _ in
                                viewModel.creatinineTextEdited()
                            }
                            .accessibilityIdentifier("calculator.creatinine.field")
                        unitChips
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 4)
                    .frame(height: 42)
                    .frame(maxWidth: .infinity)
                    .background(Palette.fieldBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        if viewModel.creatinineErrorText != nil {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(Palette.danger.opacity(0.7), lineWidth: 1)
                        }
                    }
                }
                if let error = viewModel.creatinineErrorText {
                    FieldErrorText(message: error)
                }
            }

            // 检验日期：标签在左，日期字段同行右侧，显示 2026-09-25 样式
            HStack(spacing: 10) {
                Text("检验日期")
                    .font(.subheadline)
                    .foregroundStyle(Palette.primaryText)
                Spacer(minLength: 12)
                datePickerField
            }

            // 计算按钮
            Button {
                focusedField = nil
                viewModel.calculateTapped()
            } label: {
                Text("计算 eGFR")
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(viewModel.currentInput == nil || viewModel.displayResult != nil)
            .opacity(viewModel.currentInput == nil || viewModel.displayResult != nil ? 0.55 : 1)
            .accessibilityIdentifier("calculator.calculate.button")
        }
        .cardStyle()
        .accessibilityElement(children: .contain)
    }

    /// 透明的系统 DatePicker 承担交互，外观用自定义的 yyyy-MM-dd 文本。
    /// 内嵌在血肌酐输入框右侧的单位切换（iOS 分段样式小胶囊）。
    private var unitChips: some View {
        HStack(spacing: 2) {
            ForEach(CreatinineUnit.allCases, id: \.self) { unit in
                Button {
                    withAnimation(.smooth(duration: 0.15)) {
                        viewModel.unit = unit
                    }
                } label: {
                    Text(unit.displayName)
                        .font(.caption)
                        .fontWeight(viewModel.unit == unit ? .semibold : .regular)
                        .foregroundStyle(viewModel.unit == unit ? Palette.primaryText : Palette.secondaryText)
                        .fixedSize()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background {
                            if viewModel.unit == unit {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.white)
                                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("血肌酐单位：\(unit.displayName)")
                .accessibilityAddTraits(viewModel.unit == unit ? [.isSelected] : [])
            }
        }
        .padding(2)
        .background(Palette.hairline.opacity(0.6), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("血肌酐单位切换")
    }

    /// 日期块：点击弹出日历面板（sheet 呈现，交互可靠，不受键盘残留层影响）。
    private var datePickerField: some View {
        Button {
            focusedField = nil
            showsDatePicker = true
        } label: {
            HStack(spacing: 6) {
                Text(DayDate.displayFormatter.string(from: viewModel.measuredOn))
                    .font(.body)
                    .foregroundStyle(Palette.primaryText)
                    .lineLimit(1)
                Image(systemName: "calendar")
                    .font(.footnote)
                    .foregroundStyle(Palette.secondaryText)
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 42)
            .background(Palette.fieldBackground, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .frame(minWidth: 132)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("检验日期")
        .accessibilityIdentifier("calculator.date.field")
    }

    /// 日历选择面板。
    private var datePickerSheet: some View {
        VStack(spacing: 0) {
            DatePicker(
                "检验日期",
                selection: $viewModel.measuredOn,
                in: viewModel.allowedDateRange,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .environment(\.locale, DayDate.displayLocale)
            .padding(.horizontal, 16)
            .padding(.top, 12)

            Button {
                showsDatePicker = false
            } label: {
                Text("完成")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(Palette.primary, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
            }
            .buttonStyle(PressScaleStyle())
            .accessibilityIdentifier("calculator.date.done")
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: 结果卡片

    private func resultCard(result: EGFRResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center) {
                Text("估算 eGFR")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(result.formula)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.16), in: Capsule())
            }

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(viewModel.resultValueText)
                    .font(.system(size: resultNumberSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(Palette.resultAccent)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityLabel("估算 eGFR \(viewModel.resultValueText)")
                Text("mL/min/1.73m²")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.8))
            }

            Text(viewModel.resultRangeText)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.92))
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(.white.opacity(0.12), in: Capsule())

            Text("一次 eGFR 不能单独判断肾脏疾病；请结合尿检、既往结果与医生意见理解。")
                .font(.footnote)
                .foregroundStyle(.white.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button {
                    focusedField = nil
                    viewModel.saveEgfrTapped()
                } label: {
                    Label(
                        viewModel.isCurrentResultSaved ? "✓ 已保存" : "保存这次记录",
                        systemImage: viewModel.isCurrentResultSaved ? "checkmark.circle.fill" : "square.and.arrow.down"
                    )
                }
                .buttonStyle(PrimaryOnDarkButtonStyle())
                .disabled(viewModel.isCurrentResultSaved)
                .opacity(viewModel.isCurrentResultSaved ? 0.85 : 1)
                .accessibilityIdentifier("calculator.save.button")

                Button(action: onViewRecords) {
                    Text("查看记录")
                }
                .buttonStyle(SecondaryOnDarkButtonStyle())
                .accessibilityIdentifier("calculator.view-records.button")
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(Palette.resultCard, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    // MARK: 可选指标卡片（1:1 复刻小程序样式）

    private var optionalMetricsCard: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.smooth(duration: 0.22)) {
                    viewModel.isOptionalExpanded.toggle()
                }
            } label: {
                HStack(spacing: 7) {
                    Text("添加其他检验指标（可选）")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.optToggle)
                        .lineLimit(1)
                    Text(viewModel.isOptionalExpanded ? "−" : "+")
                        .font(.body.weight(.regular))
                        .foregroundStyle(Palette.optToggle)
                        .frame(width: 20, height: 20)
                        .overlay(Circle().strokeBorder(Palette.optCircle, lineWidth: 1))
                }
                .frame(maxWidth: .infinity)
                .frame(minHeight: 48)
            }
            .buttonStyle(.plain)
            .accessibilityHint(viewModel.isOptionalExpanded ? "收起可选指标" : "展开可选指标")
            .accessibilityIdentifier("calculator.optional.toggle")

            if viewModel.isOptionalExpanded {
                optionalMetricsPanel
                    .padding(.bottom, 12)
                    .transition(.opacity)
            }
        }
        // 裁剪到卡片边界：展开/收起时高度动画表现为卡片自身伸缩，内容在边界内揭示，
        // 不再向上方卡片滑入
        .clipped()
        .cardStyle()
        .accessibilityElement(children: .contain)
    }

    /// 展开内容面板：浅绿底圆角面板，内含血压宽块、2×2 指标格、尿蛋白区、说明与保存行。
    private var optionalMetricsPanel: some View {
        VStack(spacing: 0) {
            bloodPressureTile
            fourTileGrid
            if let error = viewModel.bloodPressureErrorText {
                FieldErrorText(message: error)
                    .padding(.top, 6)
            }
            urineBand
            noteText
            saveRow
        }
        .padding(10)
        .background(Palette.optPanel, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Palette.optPanelBorder, lineWidth: 1)
        )
    }

    /// 血压整行块：名称在左，高压/低压两个输入框中间以 "/" 分隔。
    private var bloodPressureTile: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("血压")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.optLabel)
                Text("mmHg")
                    .font(.caption2)
                    .foregroundStyle(Palette.optUnit)
            }
            Spacer(minLength: 10)
            replicaInput(
                text: $viewModel.systolicText,
                placeholder: "高压",
                a11yLabel: "血压·高压输入框",
                width: 73,
                keyboard: .numberPad
            )
            Text("/")
                .font(.footnote)
                .foregroundStyle(Palette.optDivider)
            replicaInput(
                text: $viewModel.diastolicText,
                placeholder: "低压",
                a11yLabel: "血压·低压输入框",
                width: 73,
                keyboard: .numberPad
            )
        }
        .padding(10)
        .background(Palette.optTile, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Palette.optTileBorder, lineWidth: 1))
    }

    /// 尿酸 / 红细胞 / 钾 / 磷 的 2×2 指标格。
    private var fourTileGrid: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                metricTile("尿酸", "μmol/L", $viewModel.uricAcidText)
                metricTile("红细胞", "/ul", $viewModel.redBloodCellText)
            }
            HStack(spacing: 8) {
                metricTile("钾", "mmol/L", $viewModel.potassiumText)
                metricTile("磷", "mmol/L", $viewModel.phosphorusText)
            }
        }
        .padding(.top, 8)
    }

    private func metricTile(_ label: String, _ unit: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.optLabel)
                Spacer(minLength: 6)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(Palette.optUnit)
                    .lineLimit(1)
            }
            replicaInput(text: text, placeholder: "选填", a11yLabel: "\(label)输入框")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.optTile, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous).strokeBorder(Palette.optTileBorder, lineWidth: 1))
    }

    /// 尿蛋白区：浅色底小节，两条左右布局的行。
    private var urineBand: some View {
        VStack(spacing: 0) {
            Text("尿蛋白")
                .font(.caption2.weight(.semibold))
                .kerning(1)
                .foregroundStyle(Palette.optUrineTitle)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 5)
            urineRow("尿蛋白肌酐比值", "g/g.Cr", $viewModel.upcrText, showsDivider: false)
            urineRow("尿蛋白定量", "g/L", $viewModel.urineProteinText, showsDivider: true)
        }
        .padding(.horizontal, 10)
        .padding(.top, 9)
        .background(Palette.optUrineBand, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
        .padding(.top, 9)
    }

    private func urineRow(_ label: String, _ unit: String, _ text: Binding<String>, showsDivider: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Palette.optLabel)
                Text(unit)
                    .font(.caption2)
                    .foregroundStyle(Palette.optUnit)
            }
            Spacer(minLength: 10)
            replicaInput(text: text, placeholder: "选填", a11yLabel: "\(label)输入框", width: 90)
        }
        .frame(minHeight: 54)
        .overlay(alignment: .top) {
            if showsDivider {
                Rectangle()
                    .fill(Palette.optTileBorder)
                    .frame(height: 0.5)
            }
        }
    }

    private var noteText: some View {
        Text("以上可选指标均使用上方的检验日期保存，不参与 eGFR 计算。")
            .font(.caption2)
            .foregroundStyle(Palette.optUnit)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 9)
            .padding(.bottom, 2)
    }

    /// 保存行：左侧“已填写 N 项 / 补充至…”，右侧“保存补充信息”按钮。
    private var saveRow: some View {
        HStack(alignment: .center, spacing: 9) {
            VStack(alignment: .leading, spacing: 2.5) {
                Text("已填写 \(viewModel.optionalFilledCount) 项")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.optCount)
                Text(viewModel.supplementTargetText ?? "请先保存上方 eGFR")
                    .font(.caption2)
                    .foregroundStyle(Palette.optTarget)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer(minLength: 9)
            supplementButton
        }
        .padding(.top, 10)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.optTileBorder)
                .frame(height: 0.5)
        }
        .padding(.top, 9)
    }

    private var supplementButton: some View {
        let isEnabled = viewModel.supplementTargetText != nil
            && viewModel.optionalFilledCount > 0
            && viewModel.bloodPressureErrorText == nil
        let isDone = viewModel.supplementJustSaved
        return Button {
            viewModel.supplementTapped()
        } label: {
            Text(viewModel.supplementButtonTitle)
                .font(.caption.weight(.semibold))
                .foregroundStyle(isDone ? AnyShapeStyle(Palette.optButtonDoneText) : isEnabled ? AnyShapeStyle(Color.white) : AnyShapeStyle(Palette.optButtonDisabledText))
                .frame(width: 105, height: 36)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isDone ? AnyShapeStyle(Palette.optButtonDoneBg) : isEnabled ? AnyShapeStyle(Palette.optButton) : AnyShapeStyle(Palette.optButtonDisabledBg))
                )
        }
        .buttonStyle(PressScaleStyle())
        .disabled(!isEnabled)
        .accessibilityIdentifier("calculator.supplement.button")
    }

    /// 复刻版输入框：居中文本、浅底、细描边、圆角 7。
    private func replicaInput(
        text: Binding<String>,
        placeholder: String,
        a11yLabel: String,
        width: CGFloat? = nil,
        keyboard: UIKeyboardType = .decimalPad
    ) -> some View {
        TextField(
            "",
            text: text,
            prompt: Text(placeholder)
                .font(.caption)
                .foregroundStyle(Palette.optUnit)
        )
        .keyboardType(keyboard)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(Palette.primaryText)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 8)
        .frame(minHeight: 34)
        .frame(width: width)
        .background(Palette.optTile, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(Palette.optInputBorder, lineWidth: 1))
        .accessibilityLabel(a11yLabel)
    }

    private var bottomDisclaimer: some View {
        Text("本工具使用 CKD-EPI 2021 成人血肌酐公式，仅用于计算与健康科普，不提供诊断、处方或治疗建议。")
            .font(.footnote)
            .foregroundStyle(Palette.secondaryText)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// 复刻版保存按钮：按下轻微缩放（对应小程序 :active scale 0.97）。
struct PressScaleStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.smooth(duration: 0.15), value: configuration.isPressed)
    }
}

/// 深色结果卡上的主按钮：白底主绿字。
struct PrimaryOnDarkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(Palette.resultCard)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(.white, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.smooth(duration: 0.12), value: configuration.isPressed)
    }
}

/// 深色结果卡上的次按钮：白描边。
struct SecondaryOnDarkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(.white.opacity(0.55), lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.7 : 1)
            .animation(.smooth(duration: 0.12), value: configuration.isPressed)
    }
}
