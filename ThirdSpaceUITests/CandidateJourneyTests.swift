import XCTest

/// Unreviewed open-data candidates (DEBUG `--candidates`), not synthetic fixtures.
@MainActor final class CandidateJourneyTests: JourneyTestCase {
    private func launchCandidates() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["--candidates", "--reset-local-data"]
        app.launch()
        return app
    }

    func testCandidatesAreLabelledSearchableAndShowProvenance() {
        let app = launchCandidates()
        XCTAssertTrue(app.staticTexts["Unreviewed open-data candidates · not verified"].waitForExistence(timeout: 10))
        let total = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Showing 30 of")).firstMatch
        XCTAssertTrue(total.waitForExistence(timeout: 10))
        let search = app.textFields["Search owned places"]
        search.tap(); search.typeText("North Park Rec\n")
        let place = app.buttons["Open North Park Rec Center"]
        XCTAssertTrue(place.waitForExistence(timeout: 10))
        capture(app, "Candidate search result")
        place.tap()
        XCTAssertTrue(app.staticTexts["Unreviewed candidate — not checked by Third Spaces"].waitForExistence(timeout: 5))
        let address = app.staticTexts["4044 Idaho St, San Diego, CA 92104"]
        reveal(address, in: app)
        let licence = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "ODC-PDDL")).firstMatch
        reveal(licence, in: app)
        XCTAssertFalse(app.staticTexts["Open now"].exists)
        capture(app, "Candidate detail with source and licence")
    }

    func testCandidateMapShowsCaliforniaAreaCounts() {
        let app = launchCandidates()
        select("Map", in: app)
        let cell = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "map-cell-")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 10))
        XCTAssertTrue(cell.label.contains("candidate place"), cell.label)
        capture(app, "Candidate map area counts")
    }
}
