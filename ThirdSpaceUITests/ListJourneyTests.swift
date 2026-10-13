import XCTest

final class ListJourneyTests: JourneyTestCase {
    func testPermissionFreeSearchFilterDetailAndLocalSave() {
        let app = launch(["--reset-local-data"])
        XCTAssertTrue(app.staticTexts["Synthetic demo · not verified places"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Show results as list"].exists)
        let search = app.textFields["Search owned places"]
        XCTAssertTrue(search.exists)
        search.tap()
        search.typeText("Reading\n")
        app.buttons["Explore filters"].tap()
        app.switches["Focus"].tap()
        let wifi = app.switches["Wi-Fi"]
        reveal(wifi, in: app); wifi.tap()
        app.buttons["Done"].tap()
        app.buttons["Show results as list"].tap()
        XCTAssertTrue(app.staticTexts["Results"].isHittable)
        let save = app.buttons["Save SYNTHETIC — Reading Room"]
        reveal(save, in: app)
        save.tap()
        XCTAssertTrue(app.buttons["Unsave SYNTHETIC — Reading Room"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.alerts.count, 0)
        select("Saved", in: app)
        let detail = app.buttons["Open SYNTHETIC — Reading Room"]
        XCTAssertTrue(detail.waitForExistence(timeout: 5))
        detail.tap()
        XCTAssertTrue(app.staticTexts["Hours unknown — check before visiting"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Open now"].exists)
        capture(app, "Saved detail with unknown hours and dated synthetic evidence")
        app.terminate()
        let restored = launch(["--offline"])
        XCTAssertEqual(restored.textFields["Search owned places"].value as? String, "Reading")
        reveal(restored.staticTexts["Offline — cached places"], in: restored)
        select("Saved", in: restored)
        XCTAssertTrue(restored.buttons["Open SYNTHETIC — Reading Room"].waitForExistence(timeout: 5))
        capture(restored, "Saved snapshot after cold offline relaunch")
    }

    func testColdOfflineShowsConnectionMessageNotFakeNoCoverage() {
        let app = launch(["--reset-local-data", "--offline"])
        XCTAssertTrue(app.staticTexts["Connect to load places"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["This area isn’t mapped yet"].exists)
        XCTAssertFalse(app.buttons["Open SYNTHETIC — Reading Room"].exists)
        capture(app, "Cold offline without fabricated coverage")
    }

    func testDraftSurvivesRelaunch() {
        let app = launch(["--reset-local-data"])
        app.buttons["Add or contribute"].tap()
        let field = app.descendants(matching: .any).matching(identifier: "draft-text").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        app.typeText("My local draft")
        app.buttons["Keep draft"].tap()
        XCTAssertTrue(app.buttons["Show results as list"].waitForExistence(timeout: 5))
        app.terminate()
        let restored = launch()
        select("Profile", in: restored)
        let draft = restored.staticTexts["My local draft"]
        reveal(draft, in: restored)
        XCTAssertTrue(draft.exists)
        restored.buttons["Add or contribute"].tap()
        let restoredField = restored.descendants(matching: .any).matching(identifier: "draft-text").firstMatch
        XCTAssertTrue(restoredField.waitForExistence(timeout: 5))
        XCTAssertEqual(restoredField.value as? String, "My local draft")
        capture(restored, "Local draft restored after relaunch, never submitted")
    }

    func testEmptyCoverageAndFilterEmptyAreDifferent() {
        let app = launch(["--reset-local-data", "--empty"])
        XCTAssertTrue(app.staticTexts["This area isn’t mapped yet"].waitForExistence(timeout: 10))
        let search = app.textFields["Search owned places"]
        search.tap(); search.typeText("No such synthetic place\n")
        XCTAssertTrue(app.staticTexts["No places match these filters"].waitForExistence(timeout: 5))
        let clear = app.buttons["Clear search and filters"]
        reveal(clear, in: app); clear.tap()
        XCTAssertTrue(app.staticTexts["This area isn’t mapped yet"].waitForExistence(timeout: 5))
        capture(app, "Empty coverage, not an outage")
    }

    func testOutageRetryRecoversWithoutCallingItOffline() {
        let app = launch(["--reset-local-data", "--error"])
        XCTAssertTrue(app.staticTexts["Could not load places"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Connect to load places"].exists)
        let retry = app.buttons["Retry"]
        reveal(retry, in: app); retry.tap()
        XCTAssertTrue(app.buttons["Open SYNTHETIC — Reading Room"].waitForExistence(timeout: 5))
        capture(app, "Deterministic mock retry recovered")
    }

    func testWarmOfflineAndOutageRetainDatedSnapshots() {
        let app = launch(["--reset-local-data"])
        XCTAssertTrue(app.buttons["Open SYNTHETIC — Reading Room"].waitForExistence(timeout: 10))
        app.terminate()
        let offline = launch(["--offline"])
        XCTAssertTrue(offline.staticTexts["Offline — cached places"].waitForExistence(timeout: 10))
        XCTAssertFalse(offline.staticTexts["This area isn’t mapped yet"].exists)
        capture(offline, "Warm offline retained cache")
        offline.terminate()
        let outage = launch(["--error"])
        XCTAssertTrue(outage.staticTexts["Catalog unavailable — cached places"].waitForExistence(timeout: 10))
        XCTAssertFalse(outage.staticTexts["Offline — cached places"].exists)
        capture(outage, "Outage retained cache is not device offline")
    }

    func testLoadingAndSupersededSearchRemainCoherent() {
        let app = launch(["--reset-local-data", "--slow"])
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "Loading places…").firstMatch.waitForExistence(timeout: 3))
        capture(app, "Mock loading")
        let search = app.textFields["Search owned places"]
        search.tap(); search.typeText("Reading\n")
        XCTAssertTrue(app.staticTexts["Showing 1 of 1 places"].waitForExistence(timeout: 20))
        XCTAssertTrue(app.buttons["Open SYNTHETIC — Reading Room"].exists)
        XCTAssertFalse(app.buttons["open-place-00000000-0000-0000-0000-000000000102"].exists)
        capture(app, "Superseded search leaves only current query results")
    }

    func testExplicitPaginationLoadsActualPlacesAtWorldScale() {
        let app = launch(["--reset-local-data"])
        XCTAssertTrue(app.staticTexts["Showing 2 of 6 places"].waitForExistence(timeout: 5))
        reveal(app.buttons["Load more"], in: app)
        app.buttons["Load more"].tap()
        XCTAssertTrue(app.staticTexts["Showing 4 of 6 places"].waitForExistence(timeout: 5))
        reveal(app.buttons["Load more"], in: app)
        app.buttons["Load more"].tap()
        XCTAssertTrue(app.staticTexts["Showing 6 of 6 places"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Load more"].exists)
        reveal(app.buttons["Open SYNTHETIC — परीक्षण अध्ययन कक्ष"], in: app)
        capture(app, "World list paginates actual synthetic places including original Nepali script")
    }

    func testUnreadableStoredQueryRequiresDeliberateRecovery() {
        let app = launch(["--reset-local-data", "--malformed-query"])
        XCTAssertTrue(app.staticTexts["Stored search needs attention"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Retry stored search restoration"].exists)
        let reset = app.buttons["Reset stored search"]
        reveal(reset, in: app)
        capture(app, "Unreadable stored search remains actionable while browsing")
        reset.tap()
        XCTAssertTrue(app.alerts["Reset stored search?"].waitForExistence(timeout: 3))
        app.alerts.buttons["Cancel"].tap()
        XCTAssertTrue(reset.exists, "Cancel must not replace unreadable data")
        app.buttons["Retry stored search restoration"].tap()
        XCTAssertTrue(reset.exists, "Retry is not destructive recovery")
        reset.tap()
        app.alerts.buttons["Reset search"].tap()
        XCTAssertFalse(app.staticTexts["Stored search needs attention"].exists)
        XCTAssertTrue(app.buttons["Open SYNTHETIC — Reading Room"].waitForExistence(timeout: 5))
        capture(app, "Explicit query-only reset preserves browsing")
        app.terminate()
        let restored = launch()
        XCTAssertTrue(restored.buttons["Open SYNTHETIC — Reading Room"].waitForExistence(timeout: 5))
        XCTAssertFalse(restored.buttons["Reset stored search"].exists)
    }

    func testManualSyntheticAreaPreservesOriginalNameAndReadableFacts() {
        let app = launch(["--reset-local-data"])
        let area = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Browse area")).firstMatch
        reveal(area, in: app)
        area.tap()
        XCTAssertTrue(app.buttons["SYNTHETIC — East"].waitForExistence(timeout: 3))
        app.buttons["SYNTHETIC — East"].tap()
        XCTAssertTrue(app.staticTexts["Showing 1 of 1 places"].waitForExistence(timeout: 5))
        let place = app.buttons["open-place-00000000-0000-0000-0000-000000000102"]
        reveal(place, in: app)
        // Native interpolation adds FSI/PDI bidi controls. Still assert the complete
        // original-language accessible name, independently of the stable-ID selector.
        XCTAssertEqual(place.label.replacingOccurrences(of: "\u{2068}", with: "").replacingOccurrences(of: "\u{2069}", with: ""), "Open SYNTHETIC — مكتبة تجريبية")
        place.tap()
        reveal(app.staticTexts["Cost: Purchase expected"], in: app)
        XCTAssertTrue(app.staticTexts["Hours unknown — check before visiting"].exists)
        XCTAssertFalse(app.buttons["Open SYNTHETIC — Reading Room"].exists)
        XCTAssertEqual(app.alerts.count, 0)
        capture(app, "Permission-free owned synthetic area and original Arabic name")
    }
}
