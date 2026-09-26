import SwiftUI

enum RootTab: Int, CaseIterable {
    case calculator
    case history
    case knowledge
    case settings

    static func initialFromLaunchArguments() -> RootTab {
        guard let index = ProcessInfo.processInfo.arguments.first(where: { $0.hasPrefix("-uitest-tab=") })
            .flatMap({ Int($0.dropFirst("-uitest-tab=".count)) }),
            RootTab(rawValue: index) != nil
        else { return .calculator }
        return RootTab(rawValue: index)!
    }
}

/// 四个 Tab 顺序固定：计算、记录、了解、我的。
struct RootTabView: View {
    @State private var selection: RootTab = RootTab.initialFromLaunchArguments()

    var body: some View {
        TabView(selection: $selection) {
            CalculatorView()
                .tabItem { Label("计算", systemImage: "square.grid.3x3") }
                .tag(RootTab.calculator)
            HistoryView()
                .tabItem { Label("记录", systemImage: "chart.xyaxis.line") }
                .tag(RootTab.history)
            KnowledgeView()
                .tabItem { Label("了解", systemImage: "book") }
                .tag(RootTab.knowledge)
            SettingsView()
                .tabItem { Label("我的", systemImage: "person") }
                .tag(RootTab.settings)
        }
        .tint(Palette.primary)
        .preferredColorScheme(ProcessInfo.processInfo.arguments.contains("-uitest-force-dark") ? .dark : nil)
        .modifier(ForcedDynamicType(enabled: ProcessInfo.processInfo.arguments.contains("-uitest-force-large-text")))
        .environment(\.switchTab) { tab in
            selection = tab
        }
    }
}

private struct ForcedDynamicType: ViewModifier {
    let enabled: Bool

    func body(content: Content) -> some View {
        if enabled {
            content.dynamicTypeSize(.accessibility3)
        } else {
            content
        }
    }
}

/// 供“查看记录 / 去计算”等跨 Tab 跳转使用的切换器。
struct TabSwitcher: EnvironmentKey {
    static let defaultValue: (RootTab) -> Void = { _ in }
}

extension EnvironmentValues {
    var switchTab: (RootTab) -> Void {
        get { self[TabSwitcher.self] }
        set { self[TabSwitcher.self] = newValue }
    }
}
