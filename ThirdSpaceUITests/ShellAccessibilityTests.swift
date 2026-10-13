import XCTest

final class ShellAccessibilityTests: JourneyTestCase {
    func testFiveDestinationsAndListAction() {
        let app = launch(["--reset-local-data"])
        XCTAssertGreaterThan(app.windows.firstMatch.frame.height, 600, "The app must not run in a legacy 320×480 compatibility canvas")
        // Map is a dedicated destination by product decision (2026-10-13); it shares Explore's filters.
        for name in ["Explore", "Map", "Featured", "Saved", "Profile"] {
            select(name, in: app)
            XCTAssertTrue(app.buttons["Add or contribute"].exists, "Missing persistent action in \(name)")
        }
        select("Explore", in: app)
        XCTAssertTrue(app.buttons["Show results as list"].exists)
        XCTAssertGreaterThanOrEqual(app.buttons["Show results as list"].frame.height, 44)
        XCTAssertTrue(app.buttons["Add or contribute"].exists)
        capture(app, "Native adaptive five-destination shell")
    }

    func testLargestTextDarkRTLAndCompactShell() throws {
        let app = launch(["--reset-local-data", "--ax-largest", "--dark", "--rtl", "--compact-width"])
        XCTAssertTrue(app.tabBars.buttons["Explore"].waitForExistence(timeout: 5))
        let contribute = app.buttons["Add or contribute"]
        XCTAssertTrue(contribute.isHittable)
        XCTAssertGreaterThanOrEqual(contribute.frame.height, 44)
        let list = app.buttons["Show results as list"]
        reveal(list, in: app)
        XCTAssertGreaterThanOrEqual(list.frame.height, 44)
        list.tap()
        capture(app, "Largest Dynamic Type, dark, RTL, compact-width results")
        try app.performAccessibilityAudit(for: [.textClipped, .sufficientElementDescription])
        contribute.tap()
        XCTAssertTrue(app.buttons["Close"].waitForExistence(timeout: 5))
        capture(app, "Largest-text local contribution form")
        app.buttons["Close"].tap()
    }

    func testPortraitLandscapeNavigation() {
        let app = launch(["--reset-local-data"])
        XCUIDevice.shared.orientation = .landscapeLeft
        select("Saved", in: app)
        XCTAssertTrue(app.buttons["Add or contribute"].isHittable)
        capture(app, "Landscape adaptive navigation")
        XCUIDevice.shared.orientation = .portrait
        select("Explore", in: app)
        XCTAssertTrue(app.buttons["Show results as list"].waitForExistence(timeout: 5))
        capture(app, "Portrait adaptive navigation")
    }
}
