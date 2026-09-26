import Foundation

/// 日期统一策略：
/// - 语义上检验日期只有“天”，存储为当天在设备时区的起点（startOfDay）；
/// - 备份协议使用稳定的 ISO 日字符串（yyyy-MM-dd），不携带时分秒与时区偏移，
///   避免跨时区导入导出时日期偏移；
/// - 展示使用 zh_CN 格式。
nonisolated enum DayDate {
    /// Gregorian 日历 + 设备时区；locale 仅影响格式化，不影响天数计算。
    static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static var today: Date {
        startOfDay(Date())
    }

    /// 设备时区下的 yyyy-MM-dd 字符串。
    static func isoDayString(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    /// 解析 yyyy-MM-dd 为设备时区当天起点；严格 4-2-2 位补零格式，非法返回 nil。
    static func date(fromISODay string: String) -> Date? {
        let parts = string.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              parts[0].count == 4, parts[1].count == 2, parts[2].count == 2,
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }),
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2]),
              (1...12).contains(month),
              (1...31).contains(day)
        else { return nil }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = 0
        guard let date = calendar.date(from: components) else { return nil }
        // calendar.date(from:) 已按当前时区构造，再归一化到起点。
        return startOfDay(date)
    }

    static let displayLocale = Locale(identifier: "zh_CN")

    /// 展示用完整日期：yyyy-MM-dd。
    static var displayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = displayLocale
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }

    /// 趋势图 X 轴短日期：MM/dd。
    static var shortDisplayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = displayLocale
        formatter.dateFormat = "MM/dd"
        return formatter
    }

    /// “保存于”时间：HH:mm，24 小时制。
    static var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = displayLocale
        formatter.dateFormat = "HH:mm"
        return formatter
    }
}
