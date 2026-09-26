import Foundation
import SwiftData
import Observation
import OSLog

enum StorageError: LocalizedError, Equatable {
    case saveFailed
    case deleteFailed
    case replaceFailed

    var errorDescription: String? {
        switch self {
        case .saveFailed: "本机保存失败，请重试"
        case .deleteFailed: "本机删除失败，请重试"
        case .replaceFailed: "恢复备份失败，本机数据未修改"
        }
    }
}

/// 本机记录的增删改查入口。模块默认 MainActor 隔离（单线程主 Actor 实现），
/// 不引入额外并发容器；保存失败时回滚，保证数据一致性。
@Observable
final class RecordStore {
    private(set) var records: [RecordModel] = []

    private let modelContext: ModelContext
    private static let logger = Logger(subsystem: "com.lvxiulei.nephronios", category: "store")

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        reload()
    }

    func reload() {
        let descriptor = FetchDescriptor<RecordModel>(
            sortBy: [
                SortDescriptor(\.measuredOn, order: .forward),
                SortDescriptor(\.createdAt, order: .forward),
            ]
        )
        do {
            records = try modelContext.fetch(descriptor)
        } catch {
            RecordStore.logger.error("读取记录失败：\(error, privacy: .public)")
            records = []
        }
    }

    var recordCount: Int { records.count }

    var latestRecord: RecordModel? { records.last }

    /// 最近一条记录的 eGFR 展示文本。
    var latestEGFRText: String? {
        guard let latest = latestRecord else { return nil }
        return EGFRCalculator.formattedNumber(latest.egfr)
    }

    func record(withID id: UUID) -> RecordModel? {
        records.first { $0.id == id }
    }

    /// 查找同检验日期的最新一条记录（同日多条时按创建时间取最晚）。
    func latestRecord(onDay day: Date) -> RecordModel? {
        let day = DayDate.startOfDay(day)
        return records
            .filter { DayDate.startOfDay($0.measuredOn) == day }
            .max { $0.createdAt < $1.createdAt }
    }

    @discardableResult
    func createRecord(
        input: EGFRInput,
        result: EGFRResult,
        measuredOn: Date,
        optionals: OptionalMetricsInput = OptionalMetricsInput()
    ) throws -> RecordModel {
        let record = RecordModel(
            measuredOn: measuredOn,
            age: input.age,
            sex: input.sex,
            creatinine: input.creatinine,
            creatinineUnit: input.unit,
            egfr: result.roundedValue
        )
        record.mergeOptionalMetrics(optionals)
        modelContext.insert(record)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            RecordStore.logger.error("保存记录失败：\(error, privacy: .public)")
            throw StorageError.saveFailed
        }
        reload()
        return record
    }

    /// 同日期“用本次结果更新”：覆盖基础字段；可选指标按合并规则处理。
    func updateRecord(
        _ record: RecordModel,
        input: EGFRInput,
        result: EGFRResult,
        measuredOn: Date,
        optionals: OptionalMetricsInput
    ) throws {
        record.applyBaseFields(input: input, result: result, measuredOn: measuredOn)
        record.mergeOptionalMetrics(optionals)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            RecordStore.logger.error("更新记录失败：\(error, privacy: .public)")
            throw StorageError.saveFailed
        }
        reload()
    }

    /// “保存补充信息”：只合并可选指标，不新建记录。
    func supplementOptionals(of record: RecordModel, with metrics: OptionalMetricsInput) throws {
        record.mergeOptionalMetrics(metrics)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            RecordStore.logger.error("保存补充信息失败：\(error, privacy: .public)")
            throw StorageError.saveFailed
        }
        reload()
    }

    func deleteRecord(_ record: RecordModel) throws {
        modelContext.delete(record)
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            RecordStore.logger.error("删除记录失败：\(error, privacy: .public)")
            throw StorageError.deleteFailed
        }
        reload()
    }

    /// 恢复备份：整体替换当前本机记录。任何失败都回滚，原数据不变。
    func replaceAll(with newRecords: [RecordModel]) throws {
        do {
            try modelContext.delete(model: RecordModel.self)
        } catch {
            modelContext.rollback()
            RecordStore.logger.error("清理原记录失败：\(error, privacy: .public)")
            throw StorageError.replaceFailed
        }
        for record in newRecords {
            modelContext.insert(record)
        }
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            RecordStore.logger.error("写入恢复数据失败：\(error, privacy: .public)")
            throw StorageError.replaceFailed
        }
        reload()
    }
}
