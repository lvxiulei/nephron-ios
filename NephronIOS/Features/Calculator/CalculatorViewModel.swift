import SwiftUI
import Observation
import OSLog

private let logger = Logger(subsystem: "com.lvxiulei.nephronios", category: "calculator")

/// 计算 Tab 的状态与操作：输入解析、结果计算、保存、同日期对照、补充可选指标。
/// 模块默认 MainActor 隔离。
@Observable
final class CalculatorViewModel {
    // 必填输入
    var sex: BiologicalSex = .female
    var ageText = ""
    var creatinineText = ""
    var unit: CreatinineUnit = .micromolPerL
    var measuredOn = DayDate.today

    // 可选指标输入
    var systolicText = ""
    var diastolicText = ""
    var uricAcidText = ""
    var redBloodCellText = ""
    var potassiumText = ""
    var phosphorusText = ""
    var upcrText = ""
    var urineProteinText = ""
    var isOptionalExpanded = false
    var supplementJustSaved = false

    // 保存状态
    private(set) var savedRecordID: UUID?
    private(set) var savedSnapshot: EGFRInput?
    private(set) var savedMeasuredOn: Date?

    // 同日期对照弹层
    private(set) var comparisonTarget: RecordModel?
    private(set) var comparisonDateText = ""

    // 错误提示
    var storageErrorText: String?
    var showsStorageError = false

    private let store: RecordStore

    init(store: RecordStore) {
        self.store = store
        if UITestHooks.prefillCalculator {
            ageText = "45"
            creatinineText = "75"
        }
        if UITestHooks.expandOptional {
            isOptionalExpanded = true
        }
    }

    // MARK: 解析与校验

    private var trimmedAgeText: String { ageText.trimmingCharacters(in: .whitespaces) }
    private var trimmedCreatinineText: String { creatinineText.trimmingCharacters(in: .whitespaces) }

    var parsedAge: Int? {
        guard !trimmedAgeText.isEmpty else { return nil }
        return Int(trimmedAgeText)
    }

    var parsedCreatinine: Double? {
        guard !trimmedCreatinineText.isEmpty else { return nil }
        return Double(trimmedCreatinineText.replacingOccurrences(of: ",", with: "."))
    }

    /// 年龄字段错误文案；空值不提示，非法值给明确中文文案。
    // MARK: 校验时机（方案 A：输入中不打扰，失焦后再校验，再编辑即清除）
    private(set) var ageWasValidated = false
    private(set) var creatinineWasValidated = false

    func ageDidEndEditing() { ageWasValidated = true }
    func creatinineDidEndEditing() { creatinineWasValidated = true }
    func ageTextEdited() { ageWasValidated = false }
    func creatinineTextEdited() { creatinineWasValidated = false }

    var ageErrorText: String? {
        guard ageWasValidated, !trimmedAgeText.isEmpty else { return nil }
        guard let age = parsedAge else {
            return "请填写 18–120 岁的整数年龄"
        }
        if !(18...120).contains(age) {
            return EGFRInputError.ageOutOfRange.errorDescription
        }
        return nil
    }

    var creatinineErrorText: String? {
        guard creatinineWasValidated, !trimmedCreatinineText.isEmpty else { return nil }
        guard let value = parsedCreatinine, value > 0 else {
            return EGFRInputError.creatinineNotPositive.errorDescription
        }
        let micromol = unit == .micromolPerL ? value : value * EGFRCalculator.micromolPerMgDl
        if !(10...2000).contains(micromol) {
            return EGFRInputError.creatinineOutOfRange.errorDescription
        }
        return nil
    }

    var currentInput: EGFRInput? {
        guard let age = parsedAge,
              let creatinine = parsedCreatinine,
              ageErrorText == nil,
              creatinineErrorText == nil
        else { return nil }
        return EGFRInput(age: age, sex: sex, creatinine: creatinine, unit: unit)
    }

    // 手动计算：点击「计算 eGFR」后才有结果；输入变化后展示的结果失效（需重新计算）
    private(set) var calculatedResult: EGFRResult?
    private(set) var calculatedInput: EGFRInput?
    private(set) var calculatedMeasuredOn: Date?

    /// 当前可展示的计算结果：仅在必填输入与计算时一致时非空。
    var displayResult: EGFRResult? {
        guard let calculatedResult,
              let calculatedInput,
              currentInput == calculatedInput,
              DayDate.startOfDay(calculatedMeasuredOn ?? .distantFuture) == DayDate.startOfDay(measuredOn)
        else { return nil }
        return calculatedResult
    }

    /// 点击「计算 eGFR」。
    func calculateTapped() {
        guard let input = currentInput else { return }
        calculatedResult = try? EGFRCalculator.calculate(input)
        if calculatedResult != nil {
            calculatedInput = input
            calculatedMeasuredOn = measuredOn
        } else {
            calculatedInput = nil
            calculatedMeasuredOn = nil
        }
    }

    var resultValueText: String {
        guard let result = displayResult else { return "" }
        return EGFRCalculator.formattedNumber(result.roundedValue)
    }

    var resultRangeText: String {
        guard let result = displayResult else { return "" }
        return EGFRCalculator.rangeLabel(for: result.roundedValue)
    }

    /// 当前表单内容与已保存内容一致时，结果卡显示“✓ 已保存”。
    var isCurrentResultSaved: Bool {
        guard let snapshot = savedSnapshot,
              let input = currentInput,
              snapshot == input,
              DayDate.startOfDay(savedMeasuredOn ?? .distantPast) == DayDate.startOfDay(measuredOn)
        else { return false }
        return true
    }

    // MARK: 可选指标

    private var parsedOptionals: (systolic: Int?, diastolic: Int?, uricAcid: Double?, rbc: Double?, potassium: Double?, phosphorus: Double?, upcr: Double?, urineProtein: Double?) {
        func number(_ text: String) -> Double? {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            return Double(trimmed.replacingOccurrences(of: ",", with: "."))
        }
        func integer(_ text: String) -> Int? {
            let trimmed = text.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { return nil }
            return Int(trimmed)
        }
        return (
            integer(systolicText),
            integer(diastolicText),
            number(uricAcidText),
            number(redBloodCellText),
            number(potassiumText),
            number(phosphorusText),
            number(upcrText),
            number(urineProteinText)
        )
    }

    /// 血压字段错误：只填一个 / 高压不大于低压。
    var bloodPressureErrorText: String? {
        let p = parsedOptionals
        let hasSystolic = p.systolic != nil || !systolicText.trimmingCharacters(in: .whitespaces).isEmpty
        let hasDiastolic = p.diastolic != nil || !diastolicText.trimmingCharacters(in: .whitespaces).isEmpty
        if hasSystolic != hasDiastolic {
            return "血压高压 / 低压需同时填写"
        }
        if let systolic = p.systolic, let diastolic = p.diastolic, systolic <= diastolic {
            return "高压需大于低压"
        }
        if (hasSystolic && p.systolic == nil) || (hasDiastolic && p.diastolic == nil) {
            return "血压请填写整数数值"
        }
        return nil
    }

    var optionalMetricsInput: OptionalMetricsInput? {
        guard bloodPressureErrorText == nil else { return nil }
        let p = parsedOptionals
        return OptionalMetricsInput(
            systolicBP: p.systolic,
            diastolicBP: p.diastolic,
            uricAcid: p.uricAcid,
            redBloodCell: p.rbc,
            potassium: p.potassium,
            phosphorus: p.phosphorus,
            urineProteinCreatinineRatio: p.upcr,
            urineProteinQuantitative: p.urineProtein
        )
    }

    var optionalFilledCount: Int {
        // 仅统计能被解析的填写项，与保存逻辑一致。
        guard let metrics = optionalMetricsInput else {
            let p = parsedOptionals
            var count = 0
            if p.uricAcid != nil { count += 1 }
            if p.rbc != nil { count += 1 }
            if p.potassium != nil { count += 1 }
            if p.phosphorus != nil { count += 1 }
            if p.upcr != nil { count += 1 }
            if p.urineProtein != nil { count += 1 }
            return count
        }
        return metrics.filledCount
    }

    /// 补充状态文案：本次会话已保存 → “补充至 YYYY-MM-DD”；否则提示先保存。
    var supplementTargetText: String? {
        guard let id = savedRecordID,
              let record = store.record(withID: id)
        else { return nil }
        return "补充至 \(DayDate.displayFormatter.string(from: record.measuredOn))"
    }

    // MARK: 保存动作

    /// 点击“保存这次记录”：先查同日期记录，命中则弹对照层，不静默写入。
    func saveEgfrTapped() {
        guard let input = currentInput, let result = displayResult else { return }
        if let existing = store.latestRecord(onDay: measuredOn) {
            comparisonTarget = existing
            comparisonDateText = DayDate.displayFormatter.string(from: existing.measuredOn)
            return
        }
        persistNewRecord(input: input, result: result)
    }

    private func persistNewRecord(input: EGFRInput, result: EGFRResult) {
        do {
            let record = try store.createRecord(
                input: input,
                result: result,
                measuredOn: measuredOn,
                optionals: optionalMetricsInput ?? OptionalMetricsInput()
            )
            savedRecordID = record.id
            savedSnapshot = input
            savedMeasuredOn = measuredOn
            supplementJustSaved = false
        } catch {
            presentStorageError(error)
        }
    }

    /// 对照层 - 用本次结果更新。
    func comparisonUpdateTapped() {
        guard let existing = comparisonTarget,
              let input = currentInput,
              let result = displayResult
        else { return }
        do {
            try store.updateRecord(
                existing,
                input: input,
                result: result,
                measuredOn: measuredOn,
                optionals: optionalMetricsInput ?? OptionalMetricsInput()
            )
            savedRecordID = existing.id
            savedSnapshot = input
            savedMeasuredOn = measuredOn
            comparisonTarget = nil
        } catch {
            comparisonTarget = nil
            presentStorageError(error)
        }
    }

    /// 对照层 - 保留为新记录。
    func comparisonKeepNewTapped() {
        guard let input = currentInput, let result = displayResult else { return }
        comparisonTarget = nil
        persistNewRecord(input: input, result: result)
    }

    /// 点击遮罩关闭弹层，不写入任何数据。
    func comparisonDismissed() {
        comparisonTarget = nil
    }

    /// 保存补充信息：只更新当前已保存记录的可选指标。
    func supplementTapped() {
        guard let metrics = optionalMetricsInput,
              let id = savedRecordID,
              let record = store.record(withID: id)
        else { return }
        do {
            try store.supplementOptionals(of: record, with: metrics)
            supplementJustSaved = true
        } catch {
            presentStorageError(error)
        }
    }

    var supplementButtonTitle: String {
        supplementJustSaved ? "✓ 已保存" : "保存补充信息"
    }

    private func presentStorageError(_ error: Error) {
        logger.error("保存操作失败：\(error, privacy: .public)")
        storageErrorText = (error as? StorageError)?.errorDescription ?? StorageError.saveFailed.errorDescription
        showsStorageError = true
    }

    // MARK: 日期上限

    /// 检验日期不允许选择未来。
    var allowedDateRange: ClosedRange<Date> {
        .distantPast...DayDate.today
    }
}
