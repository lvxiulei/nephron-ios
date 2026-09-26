import Foundation
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.lvxiulei.nephronios", category: "seed")

/// 仅供 UI 测试与截图验收使用的演示数据注入。
/// 只有携带特定启动参数时才会执行，正常启动不产生任何影响。
enum SeedData {
    static func runIfNeeded(container: ModelContainer) {
        let arguments = ProcessInfo.processInfo.arguments
        let seeds: [(daysAgo: Int, creatinine: Double, unit: CreatinineUnit, age: Int, sex: BiologicalSex)]
        let shouldSeed: Bool

        if arguments.contains("-uitest-seed-demo") {
            shouldSeed = true
            seeds = [
                (30, 68, .micromolPerL, 45, .female),
                (21, 74, .micromolPerL, 45, .female),
                (14, 82, .micromolPerL, 45, .female),
                (7, 78, .micromolPerL, 45, .female),
                (1, 71, .micromolPerL, 45, .female),
            ]
        } else if arguments.contains("-uitest-seed-single") {
            shouldSeed = true
            seeds = [(3, 75, .micromolPerL, 45, .female)]
        } else if arguments.contains("-uitest-seed-same-date") {
            shouldSeed = true
            seeds = [
                (0, 68, .micromolPerL, 45, .female),
                (0, 92, .micromolPerL, 45, .female),
            ]
        } else if arguments.contains("-uitest-reset") {
            shouldSeed = true
            seeds = []
        } else {
            shouldSeed = false
            seeds = []
        }

        guard shouldSeed else { return }

        let context = ModelContext(container)
        context.autosaveEnabled = false
        do {
            try context.delete(model: RecordModel.self)
        } catch {
            logger.error("清理演示数据失败：\(error, privacy: .public)")
        }
        for (index, seed) in seeds.enumerated() {
            let input = EGFRInput(age: seed.age, sex: seed.sex, creatinine: seed.creatinine, unit: seed.unit)
            guard let result = try? EGFRCalculator.calculate(input) else { continue }
            let measuredOn = DayDate.calendar.date(byAdding: .day, value: -seed.daysAgo, to: DayDate.today) ?? DayDate.today
            let createdAt = DayDate.calendar.date(byAdding: .minute, value: index * 5, to: measuredOn.addingTimeInterval(9 * 3600))
                ?? measuredOn
            let record: RecordModel
            if index == 1 && arguments.contains("-uitest-seed-same-date") {
                // 第二条同日期记录补充可选指标，便于截图展示已填写项目。
                record = RecordModel(
                    measuredOn: measuredOn,
                    createdAt: createdAt,
                    age: seed.age,
                    sex: seed.sex,
                    creatinine: seed.creatinine,
                    creatinineUnit: seed.unit,
                    egfr: result.roundedValue,
                    systolicBP: 128,
                    diastolicBP: 76,
                    uricAcid: 390,
                    potassium: 4.2
                )
            } else {
                record = RecordModel(
                    measuredOn: measuredOn,
                    createdAt: createdAt,
                    age: seed.age,
                    sex: seed.sex,
                    creatinine: seed.creatinine,
                    creatinineUnit: seed.unit,
                    egfr: result.roundedValue
                )
            }
            context.insert(record)
        }
        do {
            try context.save()
        } catch {
            logger.error("写入演示数据失败：\(error, privacy: .public)")
        }
    }
}
