import XCTest

@MainActor final class MapJourneyTests: JourneyTestCase {
    private func first(_ prefix: String, in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    /// A phone's minimum zoom shows only part of the world, so drill into whichever area is visible.
    private func zoomToFirstMarker(in app: XCUIApplication) -> XCUIElement {
        let marker = first("map-place-", in: app)
        for _ in 0..<5 where !marker.waitForExistence(timeout: 3) {
            let cell = first("map-cell-", in: app)
            if cell.exists { cell.tap() }
        }
        XCTAssertTrue(marker.waitForExistence(timeout: 5), "Zooming into an area should reveal place markers")
        return marker
    }

    func testWorldMapZoomsFromAreaToPhotoMarkerPreviewAndDetail() {
        let app = launch(["--reset-local-data"])
        select("Map", in: app)
        XCTAssertTrue(app.staticTexts["Synthetic demo · not verified places"].waitForExistence(timeout: 10))
        let cell = first("map-cell-", in: app)
        XCTAssertTrue(cell.waitForExistence(timeout: 10), "World view should show area counts")
        XCTAssertTrue(cell.label.contains("synthetic place"), "Area bubble must say what it counts: \(cell.label)")
        XCTAssertEqual(app.alerts.count, 0, "Opening the map must not prompt for location")
        capture(app, "World map with synthetic area counts")

        let marker = zoomToFirstMarker(in: app)
        let name = String(marker.label.prefix { $0 != "," })
        XCTAssertTrue(name.hasPrefix("SYNTHETIC — "), "Marker must be named, not a raw coordinate: \(marker.label)")
        capture(app, "Zoomed map with photo markers")
        marker.tap()

        XCTAssertTrue(first("map-preview", in: app).waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts[name].exists)
        let photo = app.images.matching(NSPredicate(format: "label BEGINSWITH %@", "Synthetic abstract illustration")).firstMatch
        let noPhoto = app.descendants(matching: .any)["No photo yet"]
        XCTAssertTrue(photo.exists || noPhoto.exists, "Preview should show the approved photo or the labelled no-photo state")
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Save ")).firstMatch.exists)
        capture(app, "Marker preview")

        app.buttons["Open details"].tap()
        XCTAssertTrue(app.staticTexts["Hours unknown — check before visiting"].waitForExistence(timeout: 5))
        reveal(app.staticTexts["Photos"], in: app)
        if !app.staticTexts["No approved photos yet"].exists {
            reveal(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "SYNTHETIC test image")).firstMatch, in: app)
        }
        capture(app, "Detail photos with visible synthetic credit")
    }

    func testMapAreaCanBeListedWithSameFilters() {
        let app = launch(["--reset-local-data"])
        select("Map", in: app)
        XCTAssertTrue(first("map-cell-", in: app).waitForExistence(timeout: 10))
        let marker = zoomToFirstMarker(in: app)
        // Same stable record ID in both views; labels may carry native bidi isolation marks.
        let placeID = marker.identifier.replacingOccurrences(of: "map-place-", with: "")
        app.buttons["List places in this area"].tap()
        XCTAssertTrue(app.buttons["open-place-\(placeID)"].waitForExistence(timeout: 10), "Listed area should include the place seen on the map")
        let total = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "Showing ")).firstMatch
        XCTAssertTrue(total.exists)
        XCTAssertFalse(total.label.hasSuffix("of 6 places"), "List should be limited to the committed map area: \(total.label)")
        capture(app, "Map area committed to list")
    }

    func testMapOfflineIsLabelledNotEmptyCoverage() {
        let app = launch(["--reset-local-data", "--offline"])
        select("Map", in: app)
        XCTAssertTrue(app.staticTexts["Offline — map places unavailable"].waitForExistence(timeout: 10))
        XCTAssertFalse(first("map-cell-", in: app).exists)
        XCTAssertTrue(app.buttons["Show places as list"].exists, "List fallback must remain available")
    }
}
