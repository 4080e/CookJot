import XCTest
import CoreGraphics
import UIKit

final class TodayMenuJumpUITests: XCTestCase {
    private let app = XCUIApplication(bundleIdentifier: "devplaceholder.CookJotMenuUI")
    private var previous: XCUIElement { app.buttons["today-menu.jump.previous"] }
    private var next: XCUIElement { app.buttons["today-menu.jump.next"] }

    override func setUpWithError() throws { continueAfterFailure = false }
    override func tearDownWithError() throws {
        if (testRun?.failureCount ?? 0) > 0 {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.lifetime = .keepAlways
            add(attachment)
            print(app.debugDescription)
        }
    }

    @MainActor
    private func launch(_ scenario: String = "long", dark: Bool = false) {
        app.launchEnvironment["JUMP_UI_SCENARIO"] = scenario
        app.launchEnvironment["JUMP_UI_DARK"] = dark ? "1" : "0"
        app.launch()
        XCTAssertTrue(app.navigationBars["今日のメニュー"].waitForExistence(timeout: 10))
    }

    @MainActor
    private func row(_ title: String) -> XCUIElement {
        app.cells.containing(.staticText, identifier: title).firstMatch
    }

    @MainActor
    private func eventually(_ description: String, timeout: TimeInterval = 10, _ condition: @escaping () -> Bool) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in condition() }, object: nil)
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed, description)
    }

    @MainActor
    private func aligned(_ title: String) {
        eventually("\(title) outer card aligns to visible top") {
            let cell = self.row(title)
            return cell.exists && abs(cell.frame.minY - self.app.navigationBars.firstMatch.frame.maxY) <= 4
        }
    }

    @MainActor
    func testCollapsedTailAndBoundaries() {
        launch("short")
        eventually("First buttons become ready") { self.next.isEnabled && !self.previous.isEnabled }
        XCTAssertGreaterThanOrEqual(next.frame.width, 48)
        XCTAssertEqual(next.label, "次のレシピ")
        XCTAssertEqual(previous.label, "前のレシピ")
        next.tap()
        aligned("Jump B")
        eventually("Middle buttons ready") { self.next.isEnabled && self.previous.isEnabled }
        next.tap()
        aligned("Jump C")
        eventually("Last direction disabled") { !self.next.isEnabled && self.previous.isEnabled }
        previous.tap()
        aligned("Jump B")
    }

    @MainActor
    func testPreviousReturnsCurrentBeforePreceding() {
        launch()
        app.staticTexts["Jump A"].tap()
        eventually("First card expanded") { self.row("Jump A").frame.height > 1000 }
        app.swipeUp()
        eventually("First card midway permits up") {
            self.row("Jump A").frame.minY < self.app.navigationBars.firstMatch.frame.maxY - 4
                && self.previous.isEnabled && self.next.isEnabled
        }
        previous.tap()
        aligned("Jump A")
        eventually("First top disables only up") { !self.previous.isEnabled && self.next.isEnabled }
        next.tap()
        aligned("Jump B")
        app.staticTexts["Jump B"].tap()
        eventually("Second card expanded") { self.row("Jump B").frame.height > 1000 }
        app.swipeUp()
        eventually("Second card midway ready") {
            self.row("Jump B").frame.minY < self.app.navigationBars.firstMatch.frame.maxY - 4
                && self.previous.isEnabled && self.next.isEnabled
        }
        previous.tap()
        aligned("Jump B")
        eventually("Can immediately continue upward") { self.previous.isEnabled }
        previous.tap()
        aligned("Jump A")
        eventually("Next is ready after consecutive upward jumps") { self.next.isEnabled && !self.previous.isEnabled }
        next.tap()
        aligned("Jump B")
        XCTAssertGreaterThan(row("Jump B").frame.height, 1000, "Jump preserves expansion")
    }

    @MainActor
    func testLongCardsAndManualScroll() {
        launch()
        app.staticTexts["Jump A"].tap()
        eventually("Expanded long first card") { self.row("Jump A").frame.height > 1000 }
        // Move down to the next header through the actual UI, preserving a manual origin.
        for _ in 0..<7 {
            if app.staticTexts["Jump B"].isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.staticTexts["Jump B"].isHittable)
        app.staticTexts["Jump B"].tap()
        eventually("Expanded second card") { self.row("Jump B").frame.height > 1000 }
        app.swipeUp()
        eventually("Manual scroll settles with middle current") { self.previous.isEnabled && self.next.isEnabled }
        next.tap()
        aligned("Jump C")
        eventually("Short last card becomes ready") { self.previous.isEnabled && !self.next.isEnabled }
        previous.tap()
        aligned("Jump B")
        XCTAssertGreaterThan(row("Jump B").frame.height, 1000, "Jump must preserve expansion")
        eventually("Buttons recover") { self.previous.isEnabled }
        previous.tap()
        aligned("Jump A")
        XCTAssertGreaterThan(row("Jump A").frame.height, 1000)
    }

    @MainActor
    func testLongLastHeightAndCollapse() {
        launch("long-last")
        app.staticTexts["Jump C"].tap()
        eventually("Long last loaded") { self.row("Jump C").frame.height > 1000 }
        eventually("Buttons ready") { self.next.isEnabled }
        next.tap()
        aligned("Jump B")
        eventually("Middle ready") { self.next.isEnabled }
        next.tap()
        aligned("Jump C")
        app.staticTexts["Jump C"].tap()
        print("Collapsed last frame:", row("Jump C").frame, "visible top:", app.navigationBars.firstMatch.frame.maxY)
        eventually("Last collapses without moving its header") {
            self.row("Jump C").frame.height < 100
                && abs(self.row("Jump C").frame.minY - self.app.navigationBars.firstMatch.frame.maxY) <= 4
        }
        eventually("Collapsed last buttons recover") { self.previous.isEnabled }
        previous.tap()
        aligned("Jump B")
        eventually("Can return to short last") { self.next.isEnabled }
        next.tap()
        aligned("Jump C")
    }

    @MainActor
    func testEditingReorderRemovalAndClear() {
        launch("short")
        app.staticTexts["Jump A"].tap()
        app.staticTexts["Jump B"].tap()
        app.buttons["編集"].tap()
        XCTAssertFalse(next.exists)
        let reorder = app.buttons.matching(NSPredicate(format: "label CONTAINS %@ OR label CONTAINS %@", "Reorder", "並べ替え"))
        XCTAssertEqual(reorder.count, 3, "First edit exposes move icons")
        let remove = row("Jump A").buttons.matching(NSPredicate(format:
            "label CONTAINS %@ OR label CONTAINS %@ OR label CONTAINS %@", "Delete", "削除", "Remove"))
        XCTAssertTrue(remove.firstMatch.exists)
        reorder.element(boundBy: 2).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.7, thenDragTo: row("Jump A").coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.05)))
        app.buttons["完了"].tap()
        XCTAssertEqual(app.cells.firstMatch.staticTexts.firstMatch.label, "Jump C")
        eventually("Reordered first is ready") { self.next.isEnabled && !self.previous.isEnabled }
        next.tap()
        aligned("Jump A")
        row("Jump A").swipeLeft()
        app.buttons["メニューから解除"].tap()
        XCTAssertFalse(app.staticTexts["Jump A"].exists)
        app.buttons["メニューの操作"].tap()
        app.buttons["全件クリア"].tap()
        app.buttons["全件クリア"].tap()
        XCTAssertTrue(app.staticTexts["今日のメニューはありません"].waitForExistence(timeout: 5))
        XCTAssertFalse(next.exists)
    }

    @MainActor
    func testPhotosLinksAndForegroundRecovery() {
        launch("photo")
        app.staticTexts["Jump C"].tap()
        eventually("Photo changes last card height") { self.row("Jump C").frame.height > 800 }
        eventually("Start ready") { self.next.isEnabled }
        next.tap()
        aligned("Jump B")
        eventually("Middle ready") { self.next.isEnabled }
        next.tap()
        aligned("Jump C")
        let photo = app.buttons["レシピの写真"]
        XCTAssertTrue(photo.waitForExistence(timeout: 5))
        photo.tap()
        XCTAssertTrue(app.navigationBars["写真"].waitForExistence(timeout: 5))
        XCTAssertFalse(next.exists)
        app.buttons["閉じる"].tap()
        let url = "https://example.com/cookjot-jump"
        for _ in 0..<5 {
            if app.links[url].isHittable { break }
            app.swipeUp()
        }
        XCTAssertTrue(app.links[url].isHittable)
        // The link remains reachable above the floating controls at the scroll limit.
        app.links[url].tap()
        XCTAssertTrue(XCUIApplication(bundleIdentifier: "com.apple.mobilesafari").wait(for: .runningForeground, timeout: 10))
        app.activate()
        eventually("Foreground recovery re-enables navigation") { self.previous.isEnabled }
        previous.tap()
        aligned("Jump B")
        app.staticTexts["Jump B"].tap()
        app.staticTexts["材料　1個"].firstMatch.tap()
        XCTAssertEqual(app.state, .runningForeground, "Body taps do not open another card's link")
    }

    @MainActor
    func testEmptyAndSingle() {
        launch("empty")
        XCTAssertFalse(next.exists)
        app.terminate()
        launch("single")
        XCTAssertFalse(next.exists)
    }

    @MainActor
    func testDoubleTapDoesNotQueue() {
        launch("short")
        eventually("Ready") { self.next.isEnabled }
        next.doubleTap()
        aligned("Jump B")
        eventually("One request finishes at middle") { self.next.isEnabled && self.previous.isEnabled }
        aligned("Jump B")
    }

    @MainActor
    func testDarkMode() {
        launch("short", dark: true)
        eventually("Dark mode ready") { self.next.isEnabled }
        next.tap()
        aligned("Jump B")
        eventually("Middle ready") { self.next.isEnabled }
        next.tap()
        aligned("Jump C")
        let image = app.screenshot().image.cgImage!
        let center = image.cropping(to: CGRect(x: CGFloat(image.width / 2), y: CGFloat(image.height / 2), width: 1, height: 1))!
        var pixel = [UInt8](repeating: 0, count: 4)
        pixel.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: 1, height: 1, bitsPerComponent: 8,
                                    bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue)!
            context.draw(center, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        XCTAssertLessThan(Int(pixel[0]) + Int(pixel[1]) + Int(pixel[2]), 150, "Fixture must actually render dark mode")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Dark menu with measured tail margin"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
