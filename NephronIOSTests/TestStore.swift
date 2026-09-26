import Foundation
import SwiftData
@testable import NephronIOS

/// 所有存储类测试共享同一个内存 ModelContainer。
/// SwiftData 在同进程反复创建/销毁多个容器时可能触发内部断言崩溃，
/// 因此只创建一次，每个用例使用独立 ModelContext 并先清空数据。
@MainActor
enum TestStore {
    static let container: ModelContainer = try! ModelContainer(
        for: RecordModel.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    static func makeWipedStore() throws -> RecordStore {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        try context.delete(model: RecordModel.self)
        try context.save()
        return RecordStore(modelContext: context)
    }
}
