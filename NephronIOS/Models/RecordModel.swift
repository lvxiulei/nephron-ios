import Foundation
import SwiftData

/// 一条 eGFR 检验记录。`measuredOn` 仅日期语义（设备时区当天起点）；
/// 可选指标为空表示“该次未填写”。
@Model
final class RecordModel {
    var id: UUID
    var measuredOn: Date
    var createdAt: Date
    var age: Int
    var sex: BiologicalSex
    var creatinine: Double
    var creatinineUnit: CreatinineUnit
    var egfr: Double
    var formula: String

    // 可选指标
    var systolicBP: Int?
    var diastolicBP: Int?
    var uricAcid: Double?
    var redBloodCell: Double?
    var potassium: Double?
    var phosphorus: Double?
    var urineProteinCreatinineRatio: Double?
    var urineProteinQuantitative: Double?

    init(
        id: UUID = UUID(),
        measuredOn: Date,
        createdAt: Date = Date(),
        age: Int,
        sex: BiologicalSex,
        creatinine: Double,
        creatinineUnit: CreatinineUnit,
        egfr: Double,
        formula: String = EGFRResult.formulaName,
        systolicBP: Int? = nil,
        diastolicBP: Int? = nil,
        uricAcid: Double? = nil,
        redBloodCell: Double? = nil,
        potassium: Double? = nil,
        phosphorus: Double? = nil,
        urineProteinCreatinineRatio: Double? = nil,
        urineProteinQuantitative: Double? = nil
    ) {
        self.id = id
        self.measuredOn = DayDate.startOfDay(measuredOn)
        self.createdAt = createdAt
        self.age = age
        self.sex = sex
        self.creatinine = creatinine
        self.creatinineUnit = creatinineUnit
        self.egfr = egfr
        self.formula = formula
        self.systolicBP = systolicBP
        self.diastolicBP = diastolicBP
        self.uricAcid = uricAcid
        self.redBloodCell = redBloodCell
        self.potassium = potassium
        self.phosphorus = phosphorus
        self.urineProteinCreatinineRatio = urineProteinCreatinineRatio
        self.urineProteinQuantitative = urineProteinQuantitative
    }

    /// 用一次新的计算结果覆盖基础字段（不含可选指标）。
    func applyBaseFields(input: EGFRInput, result: EGFRResult, measuredOn date: Date) {
        self.measuredOn = DayDate.startOfDay(date)
        self.age = input.age
        self.sex = input.sex
        self.creatinine = input.creatinine
        self.creatinineUnit = input.unit
        self.egfr = result.roundedValue
        self.formula = result.formula
    }

    /// 合并可选指标：本次填写的覆盖旧值，未填写的保留旧值。
    /// 血压按“高压/低压”成对合并：只有两者都填写时才覆盖。
    func mergeOptionalMetrics(_ metrics: OptionalMetricsInput) {
        if metrics.hasBloodPressurePair {
            systolicBP = metrics.systolicBP
            diastolicBP = metrics.diastolicBP
        }
        if let value = metrics.uricAcid { uricAcid = value }
        if let value = metrics.redBloodCell { redBloodCell = value }
        if let value = metrics.potassium { potassium = value }
        if let value = metrics.phosphorus { phosphorus = value }
        if let value = metrics.urineProteinCreatinineRatio { urineProteinCreatinineRatio = value }
        if let value = metrics.urineProteinQuantitative { urineProteinQuantitative = value }
    }

    /// 用可选指标输入整组覆盖（保存补充信息时使用，未填写的项清空？——
    /// 产品语义是“补充”，因此仍按合并处理，见 mergeOptionalMetrics）。
    var optionalMetricsInput: OptionalMetricsInput {
        OptionalMetricsInput(
            systolicBP: systolicBP,
            diastolicBP: diastolicBP,
            uricAcid: uricAcid,
            redBloodCell: redBloodCell,
            potassium: potassium,
            phosphorus: phosphorus,
            urineProteinCreatinineRatio: urineProteinCreatinineRatio,
            urineProteinQuantitative: urineProteinQuantitative
        )
    }

    /// 已填写可选指标的展示条目，仅包含有值的项目。
    var filledMetricEntries: [OptionalMetricEntry] {
        var entries: [OptionalMetricEntry] = []
        if let systolic = systolicBP, let diastolic = diastolicBP {
            entries.append(OptionalMetricEntry(name: "血压", valueText: "\(systolic)/\(diastolic) mmHg"))
        }
        if let value = uricAcid {
            entries.append(OptionalMetricEntry(name: "尿酸", valueText: formatNumber(value) + " μmol/L"))
        }
        if let value = redBloodCell {
            entries.append(OptionalMetricEntry(name: "红细胞", valueText: formatNumber(value) + " /ul"))
        }
        if let value = potassium {
            entries.append(OptionalMetricEntry(name: "钾", valueText: formatNumber(value) + " mmol/L"))
        }
        if let value = phosphorus {
            entries.append(OptionalMetricEntry(name: "磷", valueText: formatNumber(value) + " mmol/L"))
        }
        if let value = urineProteinCreatinineRatio {
            entries.append(OptionalMetricEntry(name: "尿蛋白肌酐比值", valueText: formatNumber(value) + " g/g.Cr"))
        }
        if let value = urineProteinQuantitative {
            entries.append(OptionalMetricEntry(name: "尿蛋白定量", valueText: formatNumber(value) + " g/L"))
        }
        return entries
    }

    private func formatNumber(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2g", value)
    }
}
