import XCTest

/// UI 测试：空态进入、填写计算保存、同日期对照（更新 / 保留新记录）、深色与大字体下的关键按钮。
final class NephronIOSUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launchClean(_ extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-in-memory", "-uitest-reset"] + extra
        app.launch()
        return app
    }

    /// 轻推滚动，直到元素出现在安全可视区域（避开悬浮 Tab 栏与顶部）。
    @MainActor private func scrollToVisible(_ element: XCUIElement, in app: XCUIApplication) {
        let window = app.windows.firstMatch
        for _ in 0..<8 {
            let frame = element.frame
            let bounds = window.frame
            guard frame.height > 0 else { break }
            let topVisible = bounds.minY + 100
            let bottomVisible = bounds.maxY - 140
            if frame.minY >= topVisible && frame.maxY <= bottomVisible {
                break
            }
            if frame.maxY > bottomVisible {
                app.swipeUp()
            } else {
                app.swipeDown()
            }
            usleep(350_000)
        }
    }

    /// 滚动收起键盘（scrollDismissesKeyboard(.immediately)；悬浮 Tab 栏会被键盘遮挡，切 Tab 前必须收起）。
    @MainActor private func dismissKeyboard(_ app: XCUIApplication) {
        if app.keyboards.firstMatch.exists {
            app.swipeUp()
            usleep(500_000)
        }
    }

    @MainActor private func fillRequiredFields(_ app: XCUIApplication, age: String, creatinine: String) {
        let ageField = app.textFields["calculator.age.field"]
        XCTAssertTrue(ageField.waitForExistence(timeout: 10))
        scrollToVisible(ageField, in: app)
        ageField.tap()
        ageField.typeText(age)

        let creatinineField = app.textFields["calculator.creatinine.field"]
        XCTAssertTrue(creatinineField.exists)
        scrollToVisible(creatinineField, in: app)
        creatinineField.tap()
        creatinineField.typeText(creatinine)
        // 输入完成后立即收键盘：键盘展开时下方按钮会被键盘窗口盖住导致点击落空
        dismissKeyboard(app)
    }

    /// 点击「计算 eGFR」并等待结果卡出现。
    @MainActor private func calculateEgfr(_ app: XCUIApplication) {
        let calcButton = app.buttons["calculator.calculate.button"]
        XCTAssertTrue(calcButton.waitForExistence(timeout: 5))
        scrollToVisible(calcButton, in: app)
        calcButton.tap()
        XCTAssertTrue(app.staticTexts["估算 eGFR"].waitForExistence(timeout: 5), "点击计算后未出现结果卡")
    }

    @MainActor private func saveCurrentResult(_ app: XCUIApplication) {
        calculateEgfr(app)
        let saveButton = app.buttons["calculator.save.button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 5))
        scrollToVisible(saveButton, in: app)
        saveButton.tap()
        // 注意：此处不收键盘——若触发同日期对照弹层，全屏遮罩会拦截键盘工具栏的点击
    }

    @MainActor private func recordCountLabel(in app: XCUIApplication) -> String {
        let title = app.staticTexts["已记录次数"]
        let value = app.descendants(matching: .any)["history.summary.count.value"]
        if !title.waitForExistence(timeout: 8) || !value.waitForExistence(timeout: 5) {
            print("===DUMP-BEGIN===\n\(app.debugDescription)\n===DUMP-END===")
            XCTFail("记录摘要未出现")
        }
        return "已记录次数 \(value.label) 次"
    }

    /// 空状态：首次打开停在计算页；记录页空态可跳回计算。
    @MainActor func testEmptyStateEntersCalculator() throws {
        let app = launchClean()

        XCTAssertTrue(app.tabBars.buttons["计算"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["先把检验单看明白。"].exists)
        XCTAssertTrue(app.staticTexts["这次检验"].exists)

        app.tabBars.buttons["记录"].tap()
        XCTAssertTrue(app.staticTexts["这里还没有记录"].waitForExistence(timeout: 5))
        let goButton = app.buttons["去计算 eGFR"]
        XCTAssertTrue(goButton.exists)
        goButton.tap()
        XCTAssertTrue(app.staticTexts["先把检验单看明白。"].waitForExistence(timeout: 5))
    }

    /// 填写必填项 → 计算 → 保存 → 已保存；记录页出现 1 条。
    @MainActor func testFillCalculateAndSave() throws {
        let app = launchClean()
        fillRequiredFields(app, age: "45", creatinine: "75")

        saveCurrentResult(app)

        let savedButton = app.buttons["calculator.save.button"]
        XCTAssertTrue(savedButton.waitForExistence(timeout: 5))
        XCTAssertEqual(savedButton.label, "✓ 已保存")

        dismissKeyboard(app)
        app.tabBars.buttons["记录"].tap()
        let label = recordCountLabel(in: app)
        XCTAssertEqual(label, "已记录次数 1 次")
    }

    /// 同日期保存触发“记录对照”弹层；点“用本次结果更新”后记录数不变。
    @MainActor func testSameDateComparisonUpdateKeepsCount() throws {
        let app = launchClean()
        fillRequiredFields(app, age: "45", creatinine: "75")
        saveCurrentResult(app)

        // 修改肌酐后再次保存 → 弹层
        changeCreatinine(app, to: "100")
        saveCurrentResult(app)

        XCTAssertTrue(app.staticTexts["发现同日期记录"].waitForExistence(timeout: 5))
        // 弹层出现伴随键盘收起的重排，等布局稳定再点
        usleep(700_000)
        let updateButton = app.buttons["comparison.update.button"]
        XCTAssertTrue(updateButton.exists)
        updateButton.tap()

        dismissKeyboard(app)
        app.tabBars.buttons["记录"].tap()
        XCTAssertEqual(recordCountLabel(in: app), "已记录次数 1 次")
    }

    /// 同日期对照弹层点“保留为新记录”后记录数 +1。
    @MainActor func testSameDateComparisonKeepNewIncreasesCount() throws {
        let app = launchClean()
        fillRequiredFields(app, age: "45", creatinine: "75")
        saveCurrentResult(app)

        changeCreatinine(app, to: "100")
        saveCurrentResult(app)

        XCTAssertTrue(app.staticTexts["发现同日期记录"].waitForExistence(timeout: 5))
        // 弹层出现伴随键盘收起的重排，等布局稳定再点
        usleep(700_000)
        let keepNewButton = app.buttons["comparison.keep-new.button"]
        XCTAssertTrue(keepNewButton.exists)
        keepNewButton.tap()

        dismissKeyboard(app)
        app.tabBars.buttons["记录"].tap()
        XCTAssertEqual(recordCountLabel(in: app), "已记录次数 2 次")
    }

    /// 深色模式 + 大号字体：关键按钮仍可见、可点、标签完整。
    @MainActor func testDarkModeAndLargeTypeKeepButtonsVisible() throws {
        let app = launchClean(["-uitest-prefill", "-uitest-force-dark", "-uitest-force-large-text"])

        calculateEgfr(app)

        let saveButton = app.buttons["calculator.save.button"]
        XCTAssertTrue(saveButton.waitForExistence(timeout: 8))
        scrollToVisible(saveButton, in: app)
        XCTAssertTrue(saveButton.isHittable)
        XCTAssertEqual(saveButton.label, "保存这次记录")

        let viewButton = app.buttons["calculator.view-records.button"]
        scrollToVisible(viewButton, in: app)
        XCTAssertTrue(viewButton.isHittable)
        XCTAssertEqual(viewButton.label, "查看记录")
    }

    /// 可选指标区展开 / 收起基本路径。
    @MainActor func testOptionalMetricsToggle() throws {
        let app = launchClean(["-uitest-prefill", "-uitest-autocalculate"])
        let toggle = app.buttons["calculator.optional.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 8))
        scrollToVisible(toggle, in: app)
        toggle.tap()

        let field = app.textFields["血压·高压输入框"]
        XCTAssertTrue(field.waitForExistence(timeout: 3))

        scrollToVisible(toggle, in: app)
        toggle.tap()
        XCTAssertFalse(field.waitForExistence(timeout: 3))
    }

    /// 了解页公式折叠区展开 / 收起基本路径。
    @MainActor func testKnowledgeFormulaToggle() throws {
        let app = launchClean(["-uitest-tab=2"])
        let toggle = app.buttons["knowledge.formula.toggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 8))
        scrollToVisible(toggle, in: app)
        toggle.tap()
        XCTAssertTrue(app.staticTexts["公式表达式"].waitForExistence(timeout: 3))
        scrollToVisible(toggle, in: app)
        toggle.tap()
        XCTAssertFalse(app.staticTexts["公式表达式"].waitForExistence(timeout: 3))
    }

    /// 检验日期：点击日期块弹出日历面板，选择后可完成关闭。
    @MainActor func testDatePickerOpensAndCloses() throws {
        let app = launchClean(["-uitest-prefill"])
        let dateField = app.buttons["calculator.date.field"]
        XCTAssertTrue(dateField.waitForExistence(timeout: 8))
        scrollToVisible(dateField, in: app)
        dateField.tap()

        let done = app.buttons["calculator.date.done"]
        XCTAssertTrue(done.waitForExistence(timeout: 5), "日历面板未出现")
        done.tap()

        XCTAssertTrue(dateField.waitForExistence(timeout: 5), "关闭后日期块未恢复")
    }

    /// 长按趋势图：出现选中提示卡（日期 + eGFR）。
    @MainActor func testTrendLongPressShowsTooltip() throws {
        let app = launchClean(["-uitest-seed-demo", "-uitest-seed-same-date", "-uitest-tab=1"])
        let chart = app.otherElements.matching(
            NSPredicate(format: "label CONTAINS %@", "eGFR 趋势图")
        ).firstMatch
        XCTAssertTrue(chart.waitForExistence(timeout: 8))

        chart.press(forDuration: 0.8)

        let anyTooltip = app.descendants(matching: .any)["trend.tooltip"]
        XCTAssertTrue(anyTooltip.waitForExistence(timeout: 5), "长按后未出现选中提示卡")
    }

    /// 左滑删除：弹框出现期间记录行不得发生滚动跳变或顺序互换（紧凑采样 + 滚动深度场景）。
    @MainActor func testSwipeDeleteDialogKeepsRowsStable() throws {
        let app = launchClean(["-uitest-seed-demo", "-uitest-tab=1", "-uitest-history-scroll-records"])
        // 钩子会把摘要卡滚出屏（虚拟化移出可达性树），就绪标志改用滚动后仍在屏的列表表头
        XCTAssertTrue(app.staticTexts["检验信息"].waitForExistence(timeout: 8))

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"
        func dateText(_ daysAgo: Int) -> String {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
            return dayFormatter.string(from: date)
        }

        let target = app.staticTexts[dateText(7)]
        if !target.waitForExistence(timeout: 5) {
            print("===DUMP-BEGIN===\n\(app.debugDescription)\n===DUMP-END===")
            XCTFail("目标记录行未出现：\(dateText(7))")
        }
        // 页头（2026-09-29 新增）使整体下移后，第 5 行（30 天前）落出 List 虚拟化缓冲、
        // 启动时不在可达性树；第二采样参照改用常驻可见的最新行（1 天前）
        let oldest = app.staticTexts[dateText(1)]
        XCTAssertTrue(oldest.waitForExistence(timeout: 3), "第二参照行未出现")
        let summary = app.staticTexts["已记录次数"]

        // 摘要卡滚出屏外后 List 会将其移出可达性树。判定列表是否“跳回顶部”要看
        // 摘要卡是否真正进入可视区：弹框呈现时系统可能实例化屏幕外的单元格
        //（不出现在画面上），只看“是否存在于可达性树”会误判。
        func summaryVisible() -> Bool {
            guard summary.exists else { return false }
            let frame = summary.frame
            return frame.maxY > 0 && frame.minY < 780
        }

        // 滚动深度由启动钩子 -uitest-history-scroll-records 完成（ScrollViewReader 滚到表头）：
        // 页头（2026-09-29 新增）后，整屏 swipeUp / 坐标拖拽 / 行元素快滑的起笔会落入
        // 趋势图、行滑动手势或悬浮 Tab 栏，均无法可靠滚动。钩子在 0.8s 后触发，这里等它完成
        var scrolled = false
        for _ in 0..<20 {
            if !summaryVisible() { scrolled = true; break }
            usleep(200_000)
        }
        XCTAssertTrue(scrolled, "钩子滚动未生效：摘要卡始终可见")

        let baseTargetY = target.frame.minY
        let baseOldestY = oldest.frame.minY
        XCTAssertFalse(summaryVisible(), "前置条件不满足：摘要卡仍可见，无滚动深度")

        target.swipeLeft()
        usleep(500_000)
        let trashButton = app.buttons["删除"].firstMatch
        XCTAssertTrue(trashButton.waitForExistence(timeout: 3), "左滑后未出现删除按钮")
        trashButton.tap()
        XCTAssertTrue(app.staticTexts["删除这条记录？"].waitForExistence(timeout: 3), "删除确认弹框未出现")

        // 紧凑采样两行日期的纵向轨迹：一起平移＝滚动跳变，互换＝重排
        var samples: [String] = []
        var maxTargetDelta: CGFloat = 0
        var maxOldestDelta: CGFloat = 0
        var summaryCameVisible = false
        for _ in 0..<24 {
            let targetY = target.frame.minY
            let oldestY = oldest.frame.minY
            maxTargetDelta = max(maxTargetDelta, abs(targetY - baseTargetY))
            maxOldestDelta = max(maxOldestDelta, abs(oldestY - baseOldestY))
            if summaryVisible() { summaryCameVisible = true }
            samples.append("t=\(Int(targetY)),o=\(Int(oldestY))")
            usleep(30_000)
        }
        print("===PROBE=== base t=\(Int(baseTargetY)),o=\(Int(baseOldestY)) \(samples.joined(separator: " | "))")

        app.buttons["取消"].tap()
        usleep(400_000)
        var afterSamples: [String] = []
        for _ in 0..<8 {
            afterSamples.append("t=\(Int(target.frame.minY)),o=\(Int(oldest.frame.minY))")
            usleep(50_000)
        }
        print("===PROBE-AFTER-CANCEL=== \(afterSamples.joined(separator: " | "))")

        XCTAssertFalse(summaryCameVisible, "弹框出现时摘要卡回到可视区＝列表滚动被重置回顶部：\(samples)")

        XCTAssertLessThanOrEqual(
            maxTargetDelta, 3,
            "弹框出现期间目标行纵向跳动 \(maxTargetDelta)pt：\(samples) 取消后：\(afterSamples)"
        )
        XCTAssertLessThanOrEqual(
            maxOldestDelta, 3,
            "弹框出现期间最旧行纵向跳动 \(maxOldestDelta)pt：\(samples) 取消后：\(afterSamples)"
        )
        XCTAssertEqual(target.frame.minY, baseTargetY, accuracy: 3, "取消弹框后目标行未回到原位")
        XCTAssertEqual(oldest.frame.minY, baseOldestY, accuracy: 3, "取消弹框后最旧行未回到原位")
    }

    /// 在记录行上斜向上滚动时，横向位移不能误触发删除按钮。
    @MainActor func testDiagonalUpwardScrollDoesNotRevealDelete() throws {
        let app = launchClean(["-uitest-seed-demo", "-uitest-tab=1", "-uitest-history-scroll-records"])
        XCTAssertTrue(app.staticTexts["检验信息"].waitForExistence(timeout: 8))

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        let date = Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        let row = app.staticTexts[formatter.string(from: date)]
        XCTAssertTrue(row.waitForExistence(timeout: 5))

        let start = row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let end = start.withOffset(CGVector(dx: -30, dy: -160))
        start.press(forDuration: 0.05, thenDragTo: end)

        XCTAssertFalse(app.buttons["删除"].firstMatch.exists, "斜向上滚动误展开删除按钮")
    }

    /// 截图驱动：按环境变量 SCREENSHOT_MODE（light / dark / large）附加启动参数，
    /// 停留在“删除按钮展开”“确认弹框弹出”两种状态，供并行 simctl 截屏抓取。
    @MainActor func testScreenshotDriverDeleteStates() throws {
        var args = ["-uitest-seed-demo", "-uitest-tab=1"]
        let mode = ProcessInfo.processInfo.environment["SCREENSHOT_MODE"] ?? "light"
        if mode == "dark" { args += ["-uitest-force-dark"] }
        if mode == "large" { args += ["-uitest-force-large-text"] }
        let app = XCUIApplication()
        app.launchArguments = ["-uitest-in-memory", "-uitest-reset"] + args
        app.launch()

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"
        func dateText(_ daysAgo: Int) -> String {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
            return dayFormatter.string(from: date)
        }
        XCTAssertTrue(app.staticTexts["已记录次数"].waitForExistence(timeout: 8), "截图驱动：记录页未出现")

        // 滚动后选一条基本可见的记录行：不压顶、不进悬浮 Tab 栏区（栏顶约 778）。
        // 先在静止位判定——页头（2026-09-29 新增）使静止位首行落在 y≈696；
        // 拖拽起笔 (0.5, 0.80)≈y699 恰落在该行文字上会被自绘滑动手势吃掉，列表不滚
        let bottomLimit: CGFloat = 726
        let window = app.windows.firstMatch
        var swipeTarget: XCUIElement?
        for _ in 0..<12 where swipeTarget == nil {
            for days in [1, 7, 14, 21, 30] {
                let row = app.staticTexts[dateText(days)]
                if row.exists && row.frame.height > 0 && row.frame.minY > 90 && row.frame.maxY < bottomLimit {
                    swipeTarget = row
                    break
                }
            }
            if swipeTarget == nil {
                let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.80))
                let end = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.25))
                start.press(forDuration: 0.1, thenDragTo: end, withVelocity: 250, thenHoldForDuration: 0.2)
                usleep(1_000_000)
            }
        }
        guard let target = swipeTarget else {
            var dump = ""
            for days in [1, 7, 14, 21, 30] {
                let row = app.staticTexts[dateText(days)]
                if row.exists {
                    dump += "[\(dateText(days)) y=\(Int(row.frame.minY))..\(Int(row.frame.maxY))] "
                } else {
                    dump += "[\(dateText(days)) 不存在] "
                }
            }
            print("===SHOT-DUMP=== \(dump)")
            XCTFail("截图驱动：无基本可见的记录行")
            return
        }

        usleep(600_000)
        target.swipeLeft()
        usleep(1_500_000)  // 展开态停留，供截屏
        let trashButton = app.buttons["删除"].firstMatch
        XCTAssertTrue(trashButton.waitForExistence(timeout: 3), "截图驱动：未露出删除按钮")
        trashButton.tap()
        XCTAssertTrue(app.staticTexts["删除这条记录？"].waitForExistence(timeout: 3), "截图驱动：弹框未出现")
        usleep(2_500_000)  // 弹框态停留，供截屏
        app.buttons["取消"].tap()
        usleep(1_000_000)
    }

    /// 对照诊断：左滑后不点删除、点别处收起滑动（无弹框无状态变化），列表是否仍跳动。
    @MainActor func testSwipeCloseWithoutAlertKeepsRowsStable() throws {
        let app = launchClean(["-uitest-seed-demo", "-uitest-tab=1", "-uitest-history-scroll-records"])
        // 钩子会把摘要卡滚出屏（虚拟化移出可达性树），就绪标志改用滚动后仍在屏的列表表头
        XCTAssertTrue(app.staticTexts["检验信息"].waitForExistence(timeout: 8))

        let dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.dateFormat = "yyyy-MM-dd"
        func dateText(_ daysAgo: Int) -> String {
            let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
            return dayFormatter.string(from: date)
        }

        let target = app.staticTexts[dateText(7)]
        XCTAssertTrue(target.waitForExistence(timeout: 5), "目标记录行未出现")
        // 同上：30 天前行落出虚拟化缓冲，第二参照改用常驻可见的最新行
        let oldest = app.staticTexts[dateText(1)]
        XCTAssertTrue(oldest.waitForExistence(timeout: 3), "第二参照行未出现")
        let summary = app.staticTexts["已记录次数"]
        func summaryVisible() -> Bool {
            guard summary.exists else { return false }
            let frame = summary.frame
            return frame.maxY > 0 && frame.minY < 780
        }

        // 同弹框探针：滚动深度由启动钩子完成，这里等它生效（详见弹框探针处注释）
        var scrolled = false
        for _ in 0..<20 {
            if !summaryVisible() { scrolled = true; break }
            usleep(200_000)
        }
        XCTAssertTrue(scrolled, "钩子滚动未生效：摘要卡始终可见")

        let baseTargetY = target.frame.minY
        let baseOldestY = oldest.frame.minY
        XCTAssertFalse(summaryVisible(), "前置条件不满足：摘要卡仍可见，无滚动深度")

        target.swipeLeft()
        usleep(500_000)
        let rowDelete = app.buttons["删除"].firstMatch
        XCTAssertTrue(rowDelete.waitForExistence(timeout: 3), "左滑后未露出删除按钮")
        // 点另一行收起展开的删除按钮：不触发确认弹框
        oldest.tap()
        usleep(300_000)

        var samples: [String] = []
        var maxTargetDelta: CGFloat = 0
        var maxOldestDelta: CGFloat = 0
        var summaryCameVisible = false
        for _ in 0..<12 {
            let targetY = target.frame.minY
            let oldestY = oldest.frame.minY
            maxTargetDelta = max(maxTargetDelta, abs(targetY - baseTargetY))
            maxOldestDelta = max(maxOldestDelta, abs(oldestY - baseOldestY))
            if summaryVisible() { summaryCameVisible = true }
            samples.append("t=\(Int(targetY)),o=\(Int(oldestY))")
            usleep(50_000)
        }
        print("===PROBE-CLOSE-ONLY=== base t=\(Int(baseTargetY)),o=\(Int(baseOldestY)) \(samples.joined(separator: " | "))")

        XCTAssertFalse(summaryCameVisible, "仅收起滑动也会重置滚动：\(samples)")
        XCTAssertLessThanOrEqual(maxTargetDelta, 3, "仅收起滑动目标行也跳动：\(samples)")
        XCTAssertLessThanOrEqual(maxOldestDelta, 3, "仅收起滑动最旧行也跳动：\(samples)")
    }

    @MainActor private func changeCreatinine(_ app: XCUIApplication, to newValue: String) {
        let creatinineField = app.textFields["calculator.creatinine.field"]
        XCTAssertTrue(creatinineField.waitForExistence(timeout: 5))
        scrollToVisible(creatinineField, in: app)
        creatinineField.tap()
        // 删除现有两位输入后键入新值
        creatinineField.typeText("\u{8}\u{8}")
        creatinineField.typeText(newValue)
    }
}
