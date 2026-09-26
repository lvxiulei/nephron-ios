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

    /// 点键盘工具栏“完成”收起键盘（悬浮 Tab 栏会被键盘遮挡，切 Tab 前必须收起）。
    @MainActor private func dismissKeyboard(_ app: XCUIApplication) {
        let done = app.buttons["calculator.keyboard.done"]
        if done.waitForExistence(timeout: 2) {
            done.tap()
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
