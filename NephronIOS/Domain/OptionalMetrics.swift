import Foundation

/// 可选检验指标的输入值类型：不参与 eGFR 计算，随检验日期一起保存。
/// 血压高压 / 低压必须同时填写才算“已填写血压”这一项。
nonisolated struct OptionalMetricsInput: Equatable, Sendable {
    var systolicBP: Int? = nil
    var diastolicBP: Int? = nil
    /// 尿酸 μmol/L
    var uricAcid: Double? = nil
    /// 红细胞 /ul
    var redBloodCell: Double? = nil
    /// 钾 mmol/L
    var potassium: Double? = nil
    /// 磷 mmol/L
    var phosphorus: Double? = nil
    /// 尿蛋白肌酐比值 g/g.Cr
    var urineProteinCreatinineRatio: Double? = nil
    /// 尿蛋白定量 g/L
    var urineProteinQuantitative: Double? = nil

    /// “已填写 N 项”：血压两项齐算 1 项，其余各算 1 项。
    var filledCount: Int {
        var count = 0
        if systolicBP != nil, diastolicBP != nil { count += 1 }
        if uricAcid != nil { count += 1 }
        if redBloodCell != nil { count += 1 }
        if potassium != nil { count += 1 }
        if phosphorus != nil { count += 1 }
        if urineProteinCreatinineRatio != nil { count += 1 }
        if urineProteinQuantitative != nil { count += 1 }
        return count
    }

    var hasBloodPressurePair: Bool {
        systolicBP != nil && diastolicBP != nil
    }
}

/// 一条已保存记录中某个可选指标的展示条目。
nonisolated struct OptionalMetricEntry: Identifiable, Equatable, Sendable {
    let name: String
    let valueText: String
    var id: String { name }
}
