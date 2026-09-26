import Foundation

/// 生物学性别，原始值用于备份协议，展示值使用简体中文。
nonisolated enum BiologicalSex: String, Codable, CaseIterable, Sendable {
    case female
    case male

    var displayName: String {
        switch self {
        case .female: "女"
        case .male: "男"
        }
    }
}

/// 血肌酐单位，原始值用于备份协议。
nonisolated enum CreatinineUnit: String, Codable, CaseIterable, Sendable {
    case micromolPerL = "umol/L"
    case mgPerDL = "mg/dL"

    var displayName: String {
        switch self {
        case .micromolPerL: "μmol/L"
        case .mgPerDL: "mg/dL"
        }
    }
}

/// eGFR 计算的必填输入。
nonisolated struct EGFRInput: Equatable, Sendable {
    var age: Int
    var sex: BiologicalSex
    var creatinine: Double
    var unit: CreatinineUnit
}

/// 一次计算的完整结果。
nonisolated struct EGFRResult: Equatable, Sendable {
    /// 未取整的估算值
    let value: Double
    /// 保留一位小数后的展示值
    let roundedValue: Double
    /// 换算为 mg/dL 后的血肌酐
    let creatinineMgDl: Double
    let formula: String

    static let formulaName = "CKD-EPI 2021"
}

nonisolated enum EGFRInputError: Error, Equatable {
    case ageOutOfRange
    case creatinineNotPositive
    case creatinineOutOfRange

    var errorDescription: String {
        switch self {
        case .ageOutOfRange:
            "此公式适用于 18 岁及以上成人，请填写 18–120 岁的年龄"
        case .creatinineNotPositive:
            "请填写大于 0 的血肌酐数值"
        case .creatinineOutOfRange:
            "请核对血肌酐单位和数值后再试"
        }
    }
}

/// CKD-EPI 2021 成人血肌酐公式，仅用于估算，不构成诊断。
nonisolated enum EGFRCalculator {
    static let micromolPerMgDl = 88.4

    static func calculate(_ input: EGFRInput) throws -> EGFRResult {
        try validate(input)

        let creatinineMgDl = input.unit == .micromolPerL
            ? input.creatinine / micromolPerMgDl
            : input.creatinine
        let isFemale = input.sex == .female
        let kappa = isFemale ? 0.7 : 0.9
        let alpha = isFemale ? -0.241 : -0.302
        let sexMultiplier = isFemale ? 1.012 : 1.0
        let ratio = creatinineMgDl / kappa
        let value = 142
            * pow(min(ratio, 1), alpha)
            * pow(max(ratio, 1), -1.200)
            * pow(0.9938, Double(input.age))
            * sexMultiplier

        return EGFRResult(
            value: value,
            roundedValue: roundToOneDecimal(value),
            creatinineMgDl: creatinineMgDl,
            formula: EGFRResult.formulaName
        )
    }

    static func validate(_ input: EGFRInput) throws {
        if input.age < 18 || input.age > 120 {
            throw EGFRInputError.ageOutOfRange
        }
        if input.creatinine.isNaN || input.creatinine <= 0 {
            throw EGFRInputError.creatinineNotPositive
        }
        let creatinineMicromol = input.unit == .micromolPerL
            ? input.creatinine
            : input.creatinine * micromolPerMgDl
        if creatinineMicromol < 10 || creatinineMicromol > 2000 {
            throw EGFRInputError.creatinineOutOfRange
        }
    }

    /// 数值区间文案，与产品定义一致。
    static func rangeLabel(for value: Double) -> String {
        switch value {
        case 90...: "≥ 90 的数值区间"
        case 60..<90: "60–89 的数值区间"
        case 45..<60: "45–59 的数值区间"
        case 30..<45: "30–44 的数值区间"
        case 15..<30: "15–29 的数值区间"
        default: "＜ 15 的数值区间"
        }
    }

    static func roundToOneDecimal(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    /// 数值展示：保留一位小数，整数不带尾零（如 73、78.6）。
    static func formattedNumber(_ value: Double) -> String {
        let rounded = roundToOneDecimal(value)
        if rounded.rounded() == rounded {
            return String(Int(rounded))
        }
        return String(format: "%.1f", rounded)
    }
}
