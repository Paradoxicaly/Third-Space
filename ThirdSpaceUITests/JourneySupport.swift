import XCTest

@MainActor class JourneyTestCase: XCTestCase {
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .portrait
    }

    func launch(_ arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--ui-testing"] + arguments
        app.launch()
        return app
    }

    func reveal(_ element: XCUIElement, in app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<12 {
            if element.exists && element.isHittable { return }
            // The diagnosed iPad CollectionView is the sidebar, not Explore content.
            let results = app.scrollViews["explore-results-scroll"]
            let scroll = results.exists ? results : (app.scrollViews.firstMatch.exists ? app.scrollViews.firstMatch : app.collectionViews.firstMatch)
            let bounds = scroll.frame
            let navigationBottom = app.navigationBars.allElementsBoundByIndex.last?.frame.maxY ?? bounds.minY
            var bottom = bounds.maxY
            let contribution = app.buttons["Add or contribute"]
            if contribution.exists && contribution.isHittable { bottom = min(bottom, contribution.frame.minY) }
            if app.keyboards.firstMatch.exists { bottom = min(bottom, app.keyboards.firstMatch.frame.minY) }
            let top = max(bounds.minY, navigationBottom) + 12
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: bounds.midX, dy: bottom - 16))
            let end = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: bounds.midX, dy: top + 16))
            start.press(forDuration: 0.05, thenDragTo: end)
        }
        capture(app, "Unreachable element")
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "Unreachable element hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
        XCTAssertTrue(element.exists && element.isHittable, "Element is not reachable: \(element); exists=\(element.exists)", file: file, line: line)
    }

    func select(_ name: String, in app: XCUIApplication) {
        let tab = app.tabBars.buttons[name]
        if tab.exists { tab.tap(); return }
        let sidebar = app.descendants(matching: .any).matching(identifier: "main-sidebar").firstMatch
        if !sidebar.isHittable {
            let show = app.buttons["Show Sidebar"]
            if show.exists { show.tap() }
        }
        let row = sidebar.descendants(matching: .any).matching(identifier: name).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5), "Missing \(name) sidebar destination")
        row.tap()
    }

    func capture(_ app: XCUIApplication, _ name: String) {
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = name
        screenshot.lifetime = .keepAlways
        add(screenshot)
        let hierarchy = XCTAttachment(string: app.debugDescription)
        hierarchy.name = "\(name) — accessibility hierarchy"
        hierarchy.lifetime = .keepAlways
        add(hierarchy)
    }
}
