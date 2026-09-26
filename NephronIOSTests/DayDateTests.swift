import Testing
import Foundation
@testable import NephronIOS

struct DayDateTests {
    @Test func isoDayRoundTrip() {
        let now = Date()
        let day = DayDate.startOfDay(now)
        let text = DayDate.isoDayString(for: day)
        #expect(text.count == 10)
        let parsed = DayDate.date(fromISODay: text)
        #expect(parsed == day)
    }

    @Test(arguments: [
        "2026-9-5",   // 非补零
        "2026-13-01", // 月份越界
        "2026-09-32", // 日期越界
        "not-a-date",
        "",
        "2026/09/01", // 分隔符错误
    ])
    func invalidISODayReturnsNil(input: String) {
        #expect(DayDate.date(fromISODay: input) == nil)
    }

    @Test func isoDayStringHasFixedWidth() {
        let date = DayDate.date(fromISODay: "2026-02-03")!
        #expect(DayDate.isoDayString(for: date) == "2026-02-03")
    }

    @Test func startOfDayDropsTime() {
        let noon = DayDate.date(fromISODay: "2026-09-25")!.addingTimeInterval(13 * 3600 + 37 * 60)
        #expect(DayDate.startOfDay(noon) == DayDate.date(fromISODay: "2026-09-25"))
    }
}
