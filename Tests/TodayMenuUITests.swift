import XCTest

final class TodayMenuUITests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "devplaceholder.CookJotMenuUI")

    override func setUpWithError() throws {
        continueAfterFailure = false
        app.launch()
    }

    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.lifetime = .keepAlways
            add(attachment)
            print(app.debugDescription)
        }
    }

    @MainActor
    func testMenuWorkflow() throws {
        let source = "https://example.com/cookjot-menu-test"
        addRecipe("Menu Test A", ingredients: "Egg 1\n\nSalt 2", instructions: "Mix\n\nCook",
                  memo: "Memo first\n\nMemo last", source: source)
        addRecipe("Menu Test B", ingredients: "Carrot 1", instructions: "Cut")

        let search = app.searchFields.firstMatch
        search.tap()
        search.typeText("Menu Test A")
        let a = app.cells.containing(.staticText, identifier: "Menu Test A").firstMatch
        XCTAssertTrue(a.waitForExistence(timeout: 5))
        let initialY = a.frame.minY
        a.swipeRight()
        app.buttons["メニューに追加"].tap()
        XCTAssertEqual(search.value as? String, "Menu Test A")
        XCTAssertTrue(a.exists)
        XCTAssertEqual(a.frame.minY, initialY, accuracy: 1, "Registration must preserve scroll position")
        a.swipeRight()
        XCTAssertTrue(app.buttons["メニューから解除"].exists)
        app.buttons["メニューから解除"].tap()
        a.swipeRight()
        app.buttons["メニューに追加"].tap()
        // Existing trailing deletion remains available beside the leading action.
        a.swipeLeft()
        XCTAssertTrue(app.buttons["削除"].exists)
        a.swipeRight()

        // Clear the search without changing the recipe list's sort setting.
        search.tap()
        if search.buttons.firstMatch.exists {
            search.buttons.firstMatch.tap()
        } else {
            search.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: "Menu Test A".count))
        }
        let b = app.cells.containing(.staticText, identifier: "Menu Test B").firstMatch
        XCTAssertTrue(b.waitForExistence(timeout: 5))
        b.swipeRight()
        app.buttons["メニューに追加"].tap()
        openMenu()
        XCTAssertFalse(app.staticTexts["Egg 1\n\nSalt 2"].exists)
        let titleA = app.staticTexts["Menu Test A"]
        let collapsedY = titleA.frame.minY
        titleA.tap()
        XCTAssertTrue(app.staticTexts["Egg 1\n\nSalt 2"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Mix\n\nCook"].exists)
        XCTAssertEqual(titleA.frame.minY, collapsedY, accuracy: 1, "Expansion keeps the title at the row's top")
        for content in ["Egg 1\n\nSalt 2", "Mix\n\nCook", "Memo first\n\nMemo last"] {
            app.staticTexts[content].tap()
            XCTAssertEqual(app.state, .runningForeground, "Body taps must not open the recipe link")
            XCTAssertFalse(app.staticTexts["Egg 1\n\nSalt 2"].exists, "Body taps normally collapse the disclosure")
            titleA.tap()
            XCTAssertTrue(app.staticTexts[content].waitForExistence(timeout: 5))
        }
        titleA.tap()
        XCTAssertEqual(app.state, .runningForeground, "Title tap only collapses the row")
        XCTAssertFalse(app.staticTexts["Egg 1\n\nSalt 2"].exists)
        XCTAssertEqual(titleA.frame.minY, collapsedY, accuracy: 1, "Collapse keeps the title at the row's top")
        // Tap the trailing indicator itself, rather than the title's hit target.
        tapDisclosureIndicator(for: "Menu Test A")
        XCTAssertTrue(app.staticTexts["Egg 1\n\nSalt 2"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.state, .runningForeground, "Indicator tap must not open the reference link")
        XCTAssertEqual(titleA.frame.minY, collapsedY, accuracy: 1, "Indicator opening keeps the same title position as label opening")
        XCTAssertTrue(app.staticTexts["Memo first\n\nMemo last"].exists)
        let indicatorAttachment = XCTAttachment(screenshot: app.screenshot())
        indicatorAttachment.name = "Menu opened using trailing disclosure indicator"
        indicatorAttachment.lifetime = .keepAlways
        add(indicatorAttachment)
        tapDisclosureIndicator(for: "Menu Test A")
        XCTAssertFalse(app.staticTexts["Egg 1\n\nSalt 2"].exists)
        XCTAssertEqual(titleA.frame.minY, collapsedY, accuracy: 1, "Indicator collapse preserves header position")
        titleA.tap()
        let link = app.links[source].exists ? app.links[source] : app.buttons[source]
        XCTAssertTrue(link.exists)
        link.tap()
        XCTAssertTrue(XCUIApplication(bundleIdentifier: "com.apple.mobilesafari").wait(for: .runningForeground, timeout: 10))
        app.activate()
        XCTAssertTrue(app.staticTexts["Egg 1\n\nSalt 2"].exists)
        tapDisclosureIndicator(for: "Menu Test B")
        XCTAssertTrue(app.staticTexts["Carrot 1"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Egg 1\n\nSalt 2"].exists)
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["Carrot 1"].isHittable)
        app.swipeDown()

        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertTrue(app.staticTexts["Egg 1\n\nSalt 2"].exists)
        app.buttons["編集"].tap()
        XCTAssertFalse(app.staticTexts["Egg 1\n\nSalt 2"].exists)
        XCTAssertFalse(app.staticTexts["Carrot 1"].exists)

        let reorder = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "Reorder", "並べ替え"))
        XCTAssertEqual(reorder.count, 2)
        for title in ["Menu Test A", "Menu Test B"] {
            let row = app.cells.containing(.staticText, identifier: title).firstMatch
            let delete = row.buttons.matching(NSPredicate(format:
                "label CONTAINS %@ OR label CONTAINS %@ OR label CONTAINS %@", "Delete", "削除", "Remove"))
            XCTAssertTrue(delete.firstMatch.exists, "First edit must expose the removal control for \(title)")
        }
        let firstRow = app.cells.containing(.staticText, identifier: "Menu Test A").firstMatch
        reorder.element(boundBy: 1).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.7, thenDragTo: firstRow.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.05)))
        app.buttons["完了"].tap()
        XCTAssertFalse(app.staticTexts["Egg 1\n\nSalt 2"].exists)
        XCTAssertEqual(app.cells.element(boundBy: 0).staticTexts.firstMatch.label, "Menu Test B")

        app.terminate()
        app.launch()
        openMenu()
        XCTAssertEqual(app.cells.element(boundBy: 0).staticTexts.firstMatch.label, "Menu Test B")
        XCTAssertFalse(app.staticTexts["Carrot 1"].exists)
        app.staticTexts["Menu Test A"].tap()
        XCTAssertTrue(app.staticTexts["Egg 1\n\nSalt 2"].exists)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        openMenu()
        XCTAssertFalse(app.staticTexts["Egg 1\n\nSalt 2"].exists)

        app.cells.containing(.staticText, identifier: "Menu Test B").firstMatch.swipeLeft()
        app.buttons["メニューから解除"].tap()
        XCTAssertFalse(app.staticTexts["Menu Test B"].exists)
        app.buttons["メニューの操作"].tap()
        app.buttons["全件クリア"].tap()
        XCTAssertTrue(app.buttons["キャンセル"].waitForExistence(timeout: 5))
        app.buttons["キャンセル"].tap()
        XCTAssertTrue(app.staticTexts["Menu Test A"].exists)
        app.buttons["メニューの操作"].tap()
        app.buttons["全件クリア"].tap()
        app.buttons["全件クリア"].tap()
        XCTAssertTrue(app.staticTexts["今日のメニューはありません"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["Menu Test A"].exists)
        XCTAssertTrue(app.staticTexts["Menu Test B"].exists)

        // A registered recipe is also removed from the menu by normal recipe deletion.
        let row = app.cells.containing(.staticText, identifier: "Menu Test A").firstMatch
        row.swipeRight()
        app.buttons["メニューに追加"].tap()
        row.swipeLeft()
        app.buttons["削除"].tap()
        openMenu()
        XCTAssertTrue(app.staticTexts["今日のメニューはありません"].waitForExistence(timeout: 5))
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Menu empty state"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func tapDisclosureIndicator(for title: String) {
        let cell = app.cells.containing(.staticText, identifier: title).firstMatch
        let label = cell.staticTexts[title]
        XCTAssertTrue(label.isHittable)
        let offset = CGVector(dx: cell.frame.width - 24, dy: label.frame.midY - cell.frame.minY)
        cell.coordinate(withNormalizedOffset: .zero).withOffset(offset).tap()
    }

    @MainActor
    private func openMenu() {
        // iOS 27 hides navigation toolbar actions while the search presentation is active.
        if !app.buttons["今日のメニュー"].exists {
            for label in ["close", "閉じる", "キャンセル", "Cancel"] where app.buttons[label].exists {
                app.buttons[label].tap()
                break
            }
        }
        XCTAssertTrue(app.buttons["今日のメニュー"].waitForExistence(timeout: 5))
        app.buttons["今日のメニュー"].tap()
        XCTAssertTrue(app.navigationBars["今日のメニュー"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func addRecipe(_ title: String, ingredients: String, instructions: String,
                           memo: String = "", source: String = "") {
        app.buttons["新規レシピ"].tap()
        let name = app.textFields["レシピ名"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText(title)
        fill("材料", with: ingredients)
        fill("作り方", with: instructions)
        if !memo.isEmpty { fill("メモ", with: memo) }
        if !source.isEmpty { fill("URL（任意）", with: source) }
        app.buttons["保存"].tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
    }

    @MainActor
    private func fill(_ label: String, with value: String) {
        func input() -> XCUIElement {
            app.textViews[label].exists ? app.textViews[label] : app.textFields[label]
        }
        for _ in 0..<5 {
            if input().exists && input().isHittable { break }
            app.swipeUp()
        }
        let field = input()
        XCTAssertTrue(field.exists && field.isHittable, "Input must be reachable: \(label)")
        field.tap()
        field.typeText(value)
    }
}
