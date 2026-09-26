import Testing
import Foundation
import SwiftData
@testable import NephronIOS

@MainActor
struct RecordStoreTests {
    private func makeStore() throws -> RecordStore {
        try TestStore.makeWipedStore()
    }

    private func makeInput(creatinine: Double = 75) -> EGFRInput {
        EGFRInput(age: 45, sex: .female, creatinine: creatinine, unit: .micromolPerL)
    }

    // MARK: 保存、查询、删除

    @Test func saveAndFetchSortedByMeasuredDate() throws {
        let store = try makeStore()
        let today = DayDate.today
        let earlier = DayDate.calendar.date(byAdding: .day, value: -10, to: today)!

        try store.createRecord(
            input: makeInput(),
            result: try EGFRCalculator.calculate(makeInput()),
            measuredOn: earlier
        )
        try store.createRecord(
            input: makeInput(),
            result: try EGFRCalculator.calculate(makeInput()),
            measuredOn: today
        )

        #expect(store.recordCount == 2)
        #expect(store.records.first?.measuredOn == DayDate.startOfDay(earlier))
        #expect(store.records.last?.measuredOn == DayDate.startOfDay(today))
    }

    @Test func deleteRemovesRecord() throws {
        let store = try makeStore()
        let input = makeInput()
        let record = try store.createRecord(
            input: input,
            result: try EGFRCalculator.calculate(input),
            measuredOn: DayDate.today
        )
        #expect(store.recordCount == 1)
        try store.deleteRecord(record)
        #expect(store.recordCount == 0)
        #expect(store.latestRecord == nil)
    }

    // MARK: 同日期查找

    @Test func latestRecordOnDayPicksLatestCreatedAt() throws {
        let store = try makeStore()
        let day = DayDate.today
        let morning = day.addingTimeInterval(8 * 3600)
        let evening = day.addingTimeInterval(20 * 3600)

        // 直接构造两条同日记录以精确控制创建时间
        let early = RecordModel(
            measuredOn: day,
            createdAt: morning,
            age: 45,
            sex: .female,
            creatinine: 70,
            creatinineUnit: .micromolPerL,
            egfr: 80
        )
        let late = RecordModel(
            measuredOn: day,
            createdAt: evening,
            age: 45,
            sex: .female,
            creatinine: 90,
            creatinineUnit: .micromolPerL,
            egfr: 60
        )
        try store.replaceAll(with: [early, late])

        let found = store.latestRecord(onDay: day)
        #expect(found?.createdAt == evening)
        #expect(found?.creatinine == 90)
    }

    @Test func latestRecordOnDayIgnoresOtherDays() throws {
        let store = try makeStore()
        let input = makeInput()
        try store.createRecord(
            input: input,
            result: try EGFRCalculator.calculate(input),
            measuredOn: DayDate.today
        )
        let yesterday = DayDate.calendar.date(byAdding: .day, value: -1, to: DayDate.today)!
        #expect(store.latestRecord(onDay: yesterday) == nil)
    }

    // MARK: 同日期更新 / 保留新记录

    @Test func updateSameDayRecordDoesNotIncreaseCount() throws {
        let store = try makeStore()
        let day = DayDate.today
        let input1 = makeInput(creatinine: 70)
        let record = try store.createRecord(
            input: input1,
            result: try EGFRCalculator.calculate(input1),
            measuredOn: day
        )
        let input2 = makeInput(creatinine: 100)
        let result2 = try EGFRCalculator.calculate(input2)
        try store.updateRecord(
            record,
            input: input2,
            result: result2,
            measuredOn: day,
            optionals: OptionalMetricsInput()
        )

        #expect(store.recordCount == 1)
        #expect(store.records[0].creatinine == 100)
        #expect(store.records[0].egfr == result2.roundedValue)
    }

    @Test func keepAsNewRecordIncreasesCount() throws {
        let store = try makeStore()
        let day = DayDate.today
        let input1 = makeInput(creatinine: 70)
        _ = try store.createRecord(
            input: input1,
            result: try EGFRCalculator.calculate(input1),
            measuredOn: day
        )
        let input2 = makeInput(creatinine: 100)
        _ = try store.createRecord(
            input: input2,
            result: try EGFRCalculator.calculate(input2),
            measuredOn: day
        )

        #expect(store.recordCount == 2)
        #expect(store.records.allSatisfy { $0.measuredOn == DayDate.startOfDay(day) })
    }

    // MARK: 可选指标合并

    @Test func updateKeepsUnfilledOptionalsAndOverwritesFilled() throws {
        let store = try makeStore()
        let day = DayDate.today
        let input = makeInput()
        let record = try store.createRecord(
            input: input,
            result: try EGFRCalculator.calculate(input),
            measuredOn: day,
            optionals: OptionalMetricsInput(
                systolicBP: 120,
                diastolicBP: 80,
                uricAcid: 380,
                potassium: 4.0
            )
        )

        // 本次只填写尿酸：尿酸覆盖，血压与钾保留旧值。
        let newInput = makeInput(creatinine: 90)
        try store.updateRecord(
            record,
            input: newInput,
            result: try EGFRCalculator.calculate(newInput),
            measuredOn: day,
            optionals: OptionalMetricsInput(uricAcid: 420)
        )

        #expect(store.records[0].systolicBP == 120)
        #expect(store.records[0].diastolicBP == 80)
        #expect(store.records[0].uricAcid == 420)
        #expect(store.records[0].potassium == 4.0)
    }

    @Test func partialBloodPressureNotMerged() throws {
        let store = try makeStore()
        let input = makeInput()
        let record = try store.createRecord(
            input: input,
            result: try EGFRCalculator.calculate(input),
            measuredOn: DayDate.today
        )

        // 只填高压不填低压：不合并，避免出现半对血压。
        try store.supplementOptionals(of: record, with: OptionalMetricsInput(systolicBP: 130))
        #expect(store.records[0].systolicBP == nil)
        #expect(store.records[0].diastolicBP == nil)
    }

    @Test func supplementOptionalsDoesNotCreateNewRecord() throws {
        let store = try makeStore()
        let input = makeInput()
        let record = try store.createRecord(
            input: input,
            result: try EGFRCalculator.calculate(input),
            measuredOn: DayDate.today
        )

        try store.supplementOptionals(
            of: record,
            with: OptionalMetricsInput(uricAcid: 400, phosphorus: 1.2)
        )
        #expect(store.recordCount == 1)
        #expect(store.records[0].uricAcid == 400)
        #expect(store.records[0].phosphorus == 1.2)
    }

    @Test func bloodPressurePairCountsAsOneFilledItem() {
        let metrics = OptionalMetricsInput(systolicBP: 120, diastolicBP: 80, uricAcid: 380)
        #expect(metrics.filledCount == 2)
        #expect(OptionalMetricsInput(systolicBP: 120).filledCount == 0)
        #expect(OptionalMetricsInput().filledCount == 0)
    }

    // MARK: 排序（趋势点）

    @Test func trendOrderingSameDayUsesCreatedAt() throws {
        let store = try makeStore()
        let day = DayDate.today
        let earlier = DayDate.calendar.date(byAdding: .day, value: -5, to: day)!

        let records = [
            RecordModel(measuredOn: day, createdAt: day.addingTimeInterval(18 * 3600), age: 45, sex: .female, creatinine: 80, creatinineUnit: .micromolPerL, egfr: 70),
            RecordModel(measuredOn: earlier, createdAt: earlier.addingTimeInterval(9 * 3600), age: 45, sex: .female, creatinine: 70, creatinineUnit: .micromolPerL, egfr: 80),
            RecordModel(measuredOn: day, createdAt: day.addingTimeInterval(8 * 3600), age: 45, sex: .female, creatinine: 90, creatinineUnit: .micromolPerL, egfr: 65),
        ]
        try store.replaceAll(with: records)

        #expect(store.records.map(\.egfr) == [80, 65, 70])
    }

    @Test func filledMetricEntriesOnlyIncludeFilled() throws {
        let store = try makeStore()
        let input = makeInput()
        _ = try store.createRecord(
            input: input,
            result: try EGFRCalculator.calculate(input),
            measuredOn: DayDate.today,
            optionals: OptionalMetricsInput(systolicBP: 128, diastolicBP: 76, uricAcid: 390)
        )
        let entries = store.records[0].filledMetricEntries
        #expect(entries.map(\.name) == ["血压", "尿酸"])
        #expect(entries[0].valueText == "128/76 mmHg")
        #expect(entries[1].valueText == "390 μmol/L")
    }
}
