import Testing
@testable import NephronIOS

/// CKD-EPI 2021 计算与校验。
/// 参考值由参考项目 nephron 的 TypeScript 公式独立计算得出。
struct EGFRCalculatorTests {
    // MARK: 基本计算

    @Test(arguments: [
        (age: 40, sex: BiologicalSex.female, creatinine: 1.0, unit: CreatinineUnit.mgPerDL, expected: 73.0),
        (age: 40, sex: .male, creatinine: 1.2, unit: .mgPerDL, expected: 78.4),
        (age: 60, sex: .female, creatinine: 75.0, unit: .micromolPerL, expected: 78.6),
        (age: 25, sex: .male, creatinine: 200.0, unit: .micromolPerL, expected: 40.2),
    ])
    func ckdEpi2021ReferenceValues(
        age: Int,
        sex: BiologicalSex,
        creatinine: Double,
        unit: CreatinineUnit,
        expected: Double
    ) throws {
        let result = try EGFRCalculator.calculate(EGFRInput(age: age, sex: sex, creatinine: creatinine, unit: unit))
        #expect(result.roundedValue == expected)
        #expect(result.formula == "CKD-EPI 2021")
    }

    @Test func resultCarriesConvertedCreatinine() throws {
        let result = try EGFRCalculator.calculate(EGFRInput(age: 40, sex: .female, creatinine: 1.0, unit: .mgPerDL))
        #expect(result.creatinineMgDl == 1.0)
    }

    // MARK: 单位换算一致性

    @Test(arguments: [
        (age: 40, sex: BiologicalSex.female, umol: 88.4, mgdl: 1.0, expected: 73.0),
        (age: 80, sex: .male, umol: 53.04, mgdl: 0.6, expected: 97.6),
    ])
    func umolAndMgDlGiveSameResult(
        age: Int,
        sex: BiologicalSex,
        umol: Double,
        mgdl: Double,
        expected: Double
    ) throws {
        let byUmol = try EGFRCalculator.calculate(EGFRInput(age: age, sex: sex, creatinine: umol, unit: .micromolPerL))
        let byMg = try EGFRCalculator.calculate(EGFRInput(age: age, sex: sex, creatinine: mgdl, unit: .mgPerDL))
        #expect(byUmol.roundedValue == byMg.roundedValue)
        #expect(byUmol.creatinineMgDl == byMg.creatinineMgDl)
        #expect(byMg.roundedValue == expected)
    }

    // MARK: 输入校验与错误文案

    @Test func ageBelow18Rejected() {
        #expect(throws: EGFRInputError.ageOutOfRange) {
            try EGFRCalculator.calculate(EGFRInput(age: 17, sex: .female, creatinine: 60, unit: .micromolPerL))
        }
    }

    @Test func ageAbove120Rejected() {
        #expect(throws: EGFRInputError.ageOutOfRange) {
            try EGFRCalculator.calculate(EGFRInput(age: 121, sex: .male, creatinine: 60, unit: .micromolPerL))
        }
    }

    @Test func ageErrorTextIsExplicit() {
        #expect(EGFRInputError.ageOutOfRange.errorDescription == "此公式适用于 18 岁及以上成人，请填写 18–120 岁的年龄")
    }

    @Test func creatinineZeroRejected() {
        #expect(throws: EGFRInputError.creatinineNotPositive) {
            try EGFRCalculator.calculate(EGFRInput(age: 40, sex: .female, creatinine: 0, unit: .micromolPerL))
        }
    }

    @Test func creatinineNegativeRejected() {
        #expect(throws: EGFRInputError.creatinineNotPositive) {
            try EGFRCalculator.calculate(EGFRInput(age: 40, sex: .female, creatinine: -5, unit: .mgPerDL))
        }
    }

    @Test func creatinineBelowRangeRejectedInUmol() {
        #expect(throws: EGFRInputError.creatinineOutOfRange) {
            try EGFRCalculator.calculate(EGFRInput(age: 40, sex: .female, creatinine: 9, unit: .micromolPerL))
        }
    }

    @Test func creatinineAboveRangeRejectedInUmol() {
        #expect(throws: EGFRInputError.creatinineOutOfRange) {
            try EGFRCalculator.calculate(EGFRInput(age: 40, sex: .male, creatinine: 2001, unit: .micromolPerL))
        }
    }

    @Test func creatinineRangeCheckedAfterUnitConversion() {
        // 0.05 mg/dL ≈ 4.42 μmol/L，换算后低于 10，应拒绝。
        #expect(throws: EGFRInputError.creatinineOutOfRange) {
            try EGFRCalculator.calculate(EGFRInput(age: 40, sex: .female, creatinine: 0.05, unit: .mgPerDL))
        }
        // 23 mg/dL ≈ 2033 μmol/L，换算后高于 2000，应拒绝。
        #expect(throws: EGFRInputError.creatinineOutOfRange) {
            try EGFRCalculator.calculate(EGFRInput(age: 40, sex: .male, creatinine: 23, unit: .mgPerDL))
        }
    }

    @Test(arguments: [
        (age: 18, sex: BiologicalSex.female, creatinine: 10.0),
        (age: 120, sex: .male, creatinine: 2000.0),
    ])
    func boundaryValuesAccepted(age: Int, sex: BiologicalSex, creatinine: Double) throws {
        _ = try EGFRCalculator.calculate(EGFRInput(age: age, sex: sex, creatinine: creatinine, unit: .micromolPerL))
    }

    @Test func creatinineErrorTextsAreExplicit() {
        #expect(EGFRInputError.creatinineNotPositive.errorDescription == "请填写大于 0 的血肌酐数值")
        #expect(EGFRInputError.creatinineOutOfRange.errorDescription == "请核对血肌酐单位和数值后再试")
    }

    // MARK: 区间文案

    @Test(arguments: [
        (120.0, "≥ 90 的数值区间"),
        (90.0, "≥ 90 的数值区间"),
        (89.9, "60–89 的数值区间"),
        (60.0, "60–89 的数值区间"),
        (59.9, "45–59 的数值区间"),
        (45.0, "45–59 的数值区间"),
        (44.9, "30–44 的数值区间"),
        (30.0, "30–44 的数值区间"),
        (29.9, "15–29 的数值区间"),
        (15.0, "15–29 的数值区间"),
        (14.9, "＜ 15 的数值区间"),
    ])
    func rangeLabels(value: Double, expected: String) {
        #expect(EGFRCalculator.rangeLabel(for: value) == expected)
    }

    // MARK: 数值格式化

    @Test func formattedNumberKeepsOneDecimal() {
        #expect(EGFRCalculator.formattedNumber(73.0) == "73")
        #expect(EGFRCalculator.formattedNumber(78.55) == "78.6")
        #expect(EGFRCalculator.formattedNumber(14.94) == "14.9")
    }

    @Test func roundingToOneDecimal() {
        #expect(EGFRCalculator.roundToOneDecimal(73.04) == 73.0)
        #expect(EGFRCalculator.roundToOneDecimal(78.55) == 78.6)
    }
}
