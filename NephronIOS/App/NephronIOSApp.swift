import SwiftUI
import SwiftData
import OSLog

private let logger = Logger(subsystem: "com.lvxiulei.nephronios", category: "app")

@main
struct NephronIOSApp: App {
    let container: ModelContainer
    @State private var store: RecordStore

    init() {
        let arguments = ProcessInfo.processInfo.arguments
        let useInMemory = arguments.contains("-uitest-in-memory")
        let configuration = ModelConfiguration(isStoredInMemoryOnly: useInMemory)
        do {
            container = try ModelContainer(for: RecordModel.self, configurations: configuration)
        } catch {
            // 磁盘存储损坏等场景退回内存模式，保证 App 仍可运行，但数据不会持久化。
            logger.error("ModelContainer 创建失败，退回内存存储：\(error, privacy: .public)")
            container = try! ModelContainer(
                for: RecordModel.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
        SeedData.runIfNeeded(container: container)
        _store = State(initialValue: RecordStore(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environment(store)
        }
        .modelContainer(container)
    }
}
