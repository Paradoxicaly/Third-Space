import XCTest
@testable import ThirdSpace

final class BrowseImprovementTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_793_000_000) // 2026-10-27

    func testFeaturedPicksAreLaunchGatedAndOnlyActive() async throws {
        let ordinary = MockFeaturedRepository(launchArguments: [])
        let none = try await ordinary.activeItems(regionID: nil, at: now)
        XCTAssertTrue(none.isEmpty, "Ordinary launches must not show synthetic picks")

        let synthetic = MockFeaturedRepository(launchArguments: ["--ui-testing"])
        let active = try await synthetic.activeItems(regionID: nil, at: now)
        XCTAssertFalse(active.isEmpty)
        XCTAssertTrue(active.allSatisfy { $0.isActive(at: now) })
        XCTAssertLessThan(active.count, FeaturedItem.syntheticUITestFixtures.count, "An expired fixture should be filtered out")
        XCTAssertTrue(active.allSatisfy { $0.curator.hasPrefix("SYNTHETIC") })
    }

    func testFeaturedPicksFilterByRegion() async throws {
        let synthetic = MockFeaturedRepository(launchArguments: ["--ui-testing"])
        let west = try await synthetic.activeItems(regionID: "test-west", at: now)
        let westPlaces = Set(Place.syntheticUITestFixtures.filter { $0.regionID == "test-west" }.map(\.id))
        XCTAssertFalse(west.isEmpty)
        XCTAssertTrue(west.allSatisfy { westPlaces.contains($0.targetID) })
    }

    func testSavedSortByNameAndByArea() {
        let places = Place.syntheticUITestFixtures
        let byName = SavedSort.name.apply(places)
        XCTAssertEqual(byName.map(\.name), places.map(\.name).sorted { $0.localizedStandardCompare($1) == .orderedAscending })
        let byArea = SavedSort.area.apply(places)
        XCTAssertEqual(byArea.map(\.regionID), places.map(\.regionID).sorted())
        let islands = byArea.filter { $0.regionID == "test-islands" }.map(\.name)
        XCTAssertEqual(islands, islands.sorted { $0.localizedStandardCompare($1) == .orderedAscending }, "Ties within an area sort by name")
    }

    func testShareTextNamesThePlaceButNeverItsCoordinates() throws {
        let place = try XCTUnwrap(Place.syntheticUITestFixtures.first)
        let text = place.shareText(areaName: "SYNTHETIC — West")
        XCTAssertTrue(text.contains(place.name))
        XCTAssertTrue(text.contains("SYNTHETIC — West"))
        XCTAssertTrue(text.contains("Study"))
        let location = try XCTUnwrap(place.location)
        XCTAssertFalse(text.contains(String(location.latitude)))
        XCTAssertFalse(text.contains(String(location.longitude)))
    }
}
