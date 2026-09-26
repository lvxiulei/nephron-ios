import Testing
import Foundation
@testable import NephronIOS

/// 方案 A：失焦后校验——输入中不打扰、失焦才提示、再编辑即清除。
@MainActor
struct CalculatorViewModelValidationTests {
    private func makeViewModel() throws -> CalculatorViewModel {
        CalculatorViewModel(store: try TestStore.makeWipedStore())
    }

    @Test func ageErrorOnlyAppearsAfterBlur() throws {
        let vm = try makeViewModel()
        vm.ageText = "3"
        #expect(vm.ageErrorText == nil, "输入中的中间值不应提示")

        vm.ageDidEndEditing()
        #expect(vm.ageErrorText != nil, "失焦后应出现范围错误")
        #expect(vm.ageErrorText == EGFRInputError.ageOutOfRange.errorDescription)

        vm.ageTextEdited()
        #expect(vm.ageErrorText == nil, "再次编辑应立即清除错误")
    }

    @Test func validAgeShowsNoErrorAfterBlur() throws {
        let vm = try makeViewModel()
        vm.ageText = "45"
        vm.ageDidEndEditing()
        #expect(vm.ageErrorText == nil)
    }

    @Test func emptyAgeNeverShowsError() throws {
        let vm = try makeViewModel()
        vm.ageDidEndEditing()
        #expect(vm.ageErrorText == nil, "空值失焦不提示")
    }

    @Test func creatinineErrorOnlyAppearsAfterBlur() throws {
        let vm = try makeViewModel()
        vm.creatinineText = "8" // 换算后 8 μmol/L，低于 10
        #expect(vm.creatinineErrorText == nil, "输入中的中间值不应提示")

        vm.creatinineDidEndEditing()
        #expect(vm.creatinineErrorText == EGFRInputError.creatinineOutOfRange.errorDescription)

        vm.creatinineTextEdited()
        #expect(vm.creatinineErrorText == nil)
    }

    @Test func validCreatinineShowsNoErrorAfterBlur() throws {
        let vm = try makeViewModel()
        vm.creatinineText = "75"
        vm.creatinineDidEndEditing()
        #expect(vm.creatinineErrorText == nil)
    }

    @Test func partialValueKeepsResultComputableSilently() throws {
        let vm = try makeViewModel()
        vm.ageText = "45"
        vm.creatinineText = "7"
        // 中间值：不提示错误（范围校验在计算时进行，按钮由有效性自然控制）
        #expect(vm.creatinineErrorText == nil)
        vm.calculateTapped()
        #expect(vm.displayResult == nil, "低于合理范围的肌酐不应得到结果")
        #expect(vm.creatinineErrorText == nil, "点计算不等于失焦，不应触发红字")
    }
}
