import Foundation

/// UI 测试与截图验收专用的启动参数钩子。
/// 只有携带对应 `-uitest-*` 参数时才生效，正常启动零影响。
enum UITestHooks {
    private static let arguments = ProcessInfo.processInfo.arguments

    /// 预填计算表单（女 / 45 岁 / 75 μmol/L）
    static var prefillCalculator: Bool {
        arguments.contains("-uitest-prefill")
    }

    /// 默认展开可选指标区域
    static var expandOptional: Bool {
        arguments.contains("-uitest-expand-optional")
    }

    /// 启动后自动点一次「计算 eGFR」（配合截图展示结果卡）
    static var autoCalculate: Bool {
        arguments.contains("-uitest-autocalculate")
    }

    /// 启动后自动触发一次保存（配合同日期种子数据显示“记录对照”弹层）
    static var triggerComparison: Bool {
        arguments.contains("-uitest-trigger-comparison")
    }

    /// 趋势图默认选中最新点（配合选中态截图）
    static var trendSelectLast: Bool {
        arguments.contains("-uitest-trend-select-last")
    }

    /// 启后滚动到页面底部（配合可选指标展开截图）
    static var scrollToBottom: Bool {
        arguments.contains("-uitest-scroll-bottom")
    }
}
