import XCTest

/// Featured picks, saved sorting and share, through the real UI on synthetic fixtures.
@MainActor final class BrowseImprovementJourneyTests: JourneyTestCase {
    func testFeaturedPicksSaveSortAndShare() {
        let app = launch(["--reset-local-data"])
        select("Featured", in: app)
        let pick = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "featured-")).firstMatch
        XCTAssertTrue(pick.waitForExistence(timeout: 10), "Active synthetic picks should show")
        XCTAssertFalse(app.staticTexts["SYNTHETIC reason: expired pick that should never appear."].exists, "Expired pick leaked")
        capture(app, "Featured picks with curator and end date")

        for name in ["SYNTHETIC — Reading Room", "SYNTHETIC — Demonstration Garden"] {
            let save = app.buttons["Save \(name)"]
            reveal(save, in: app)
            save.tap()
            XCTAssertTrue(app.buttons["Unsave \(name)"].waitForExistence(timeout: 5))
        }

        select("Saved", in: app)
        let count = app.staticTexts["saved-count"]
        XCTAssertTrue(count.waitForExistence(timeout: 10))
        XCTAssertEqual(count.label, "2 saved places")
        app.buttons["Area"].tap()
        XCTAssertTrue(app.staticTexts["SYNTHETIC — Islands"].waitForExistence(timeout: 5), "Area sort should label each area")
        capture(app, "Saved places sorted by area")

        app.buttons["Open SYNTHETIC — Reading Room"].tap()
        let share = app.buttons["share-place"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        capture(app, "Place page with share button")
        share.tap()
        let sheet = app.otherElements["ActivityListView"]
        XCTAssertTrue(sheet.waitForExistence(timeout: 10) || app.navigationBars["UIActivityContentView"].waitForExistence(timeout: 5), "Share sheet should open")
        sleep(1)
        capture(app, "Share sheet with name and area only")
    }
}
