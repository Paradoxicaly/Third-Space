import XCTest
@testable import ThirdSpace

final class MapViewportTests: XCTestCase {
    func testZoomBucketFollowsLongitudeSpan() {
        XCTAssertEqual(MapViewport(centerLatitude: 0, centerLongitude: 0, latitudeDelta: 170, longitudeDelta: 360).zoomBucket, 0)
        XCTAssertEqual(MapViewport(centerLatitude: 0, centerLongitude: 0, latitudeDelta: 45, longitudeDelta: 45).zoomBucket, 3)
        // MapKit pads a requested 45° cell to the screen aspect; a slightly wider span stays in the same bucket.
        XCTAssertEqual(MapViewport(centerLatitude: 0, centerLongitude: 0, latitudeDelta: 60, longitudeDelta: 47).zoomBucket, 3)
        XCTAssertGreaterThan(MapViewport(centerLatitude: 0, centerLongitude: 0, latitudeDelta: 1, longitudeDelta: 1).zoomBucket, 7)
    }

    func testViewportAcrossAntimeridianSplitsLongitude() throws {
        let bounds = try XCTUnwrap(MapViewport(centerLatitude: -17.8, centerLongitude: 179, latitudeDelta: 4, longitudeDelta: 4).bounds)
        XCTAssertEqual(bounds.west, 177, accuracy: 0.0001)
        XCTAssertEqual(bounds.east, -179, accuracy: 0.0001)
        XCTAssertTrue(bounds.contains(GeoPoint(latitude: -18, longitude: -179.5)!))
        XCTAssertTrue(bounds.contains(GeoPoint(latitude: -17.7, longitude: 179.5)!))
        XCTAssertFalse(bounds.contains(GeoPoint(latitude: -17.7, longitude: 170)!))
    }

    func testWorldSpanCoversAllLongitudesAndClampsLatitude() throws {
        let bounds = try XCTUnwrap(MapViewport(centerLatitude: 20, centerLongitude: 0, latitudeDelta: 200, longitudeDelta: 400).bounds)
        XCTAssertEqual(bounds.south, -80, accuracy: 0.0001)
        XCTAssertEqual(bounds.north, 90, accuracy: 0.0001)
        XCTAssertTrue(bounds.contains(GeoPoint(latitude: 0, longitude: 179.999)!))
        XCTAssertTrue(bounds.contains(GeoPoint(latitude: 0, longitude: -180)!))
    }
}

final class MapSummaryContractTests: XCTestCase {
    func testWorldAggregateGridCountsEveryPlaceIncludingAntimeridianNeighbours() async throws {
        let repository = MockPlaceRepository(launchArguments: ["--ui-testing"])
        guard case .aggregate(let cells, _, _) = try await repository.mapSummary(ExploreQuery(), zoomBucket: 0) else {
            return XCTFail("World zoom did not aggregate")
        }
        XCTAssertGreaterThan(cells.count, 1, "World view should show where places are, not one global bubble")
        XCTAssertEqual(cells.reduce(0) { $0 + $1.count }, Place.syntheticUITestFixtures.count)
        for place in Place.syntheticUITestFixtures {
            let point = try XCTUnwrap(place.location)
            XCTAssertEqual(cells.filter { $0.bounds.contains(point) }.count, 1, "\(place.name) must be counted in exactly one cell")
        }
    }

    func testZoomedSummaryReturnsOnlyPlacesInsideViewport() async throws {
        let repository = MockPlaceRepository(launchArguments: ["--ui-testing"])
        let viewport = try XCTUnwrap(MapViewport(centerLatitude: -17.8, centerLongitude: 179, latitudeDelta: 4, longitudeDelta: 4).bounds)
        guard case .places(let places, let truncated, _, _) = try await repository.mapSummary(ExploreQuery(area: .bounds(viewport)), zoomBucket: 6) else {
            return XCTFail("Zoomed map did not return places")
        }
        XCTAssertFalse(truncated)
        XCTAssertEqual(Set(places.map(\.name)), ["SYNTHETIC — 架空の庭", "SYNTHETIC — Demonstration Garden"])
    }
}

@MainActor final class MapViewModelTests: XCTestCase {
    func testMapUsesSharedFiltersWithViewportArea() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = MapViewModel(repository: MockPlaceRepository(launchArguments: ["--ui-testing"]), cache: OwnedContentCache(url: root.appendingPathComponent("cache.json")))
        // The viewport replaces Explore's chosen region (test-east is elsewhere); intent filters still apply.
        let southAsia = MapViewport(centerLatitude: 27, centerLongitude: 85, latitudeDelta: 20, longitudeDelta: 30)
        await model.load(viewport: southAsia, filters: ExploreQuery(area: .region("test-east"), intents: [.focus]))
        guard case .places(let places, _) = model.content else { return XCTFail("Expected zoomed places") }
        XCTAssertEqual(places.map(\.name), ["SYNTHETIC — परीक्षण अध्ययन कक्ष"])
        await model.load(viewport: southAsia, filters: ExploreQuery(intents: [.meet]))
        guard case .places(let social, _) = model.content else { return XCTFail("Expected zoomed places") }
        XCTAssertTrue(social.isEmpty, "Shared intent filter was ignored")
    }

    func testFailureIsDistinctFromOfflineAndEmpty() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = OwnedContentCache(url: root.appendingPathComponent("cache.json"))
        let viewport = MapViewport(centerLatitude: 0, centerLongitude: 0, latitudeDelta: 170, longitudeDelta: 360)
        let offline = MapViewModel(repository: MockPlaceRepository(launchArguments: ["--ui-testing", "--offline"]), cache: cache)
        await offline.load(viewport: viewport, filters: ExploreQuery())
        guard case .offline = offline.content else { return XCTFail("Offline map was not labelled offline") }
        let failing = MapViewModel(repository: FailClosedPlaceRepository(), cache: cache)
        await failing.load(viewport: viewport, filters: ExploreQuery())
        guard case .failed = failing.content else { return XCTFail("Unavailable catalog shown as something other than a failure") }
    }

    func testSelectionClearsWhenPlaceLeavesResults() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = MapViewModel(repository: MockPlaceRepository(launchArguments: ["--ui-testing"]), cache: OwnedContentCache(url: root.appendingPathComponent("cache.json")))
        let zoomed = MapViewport(centerLatitude: 34, centerLongitude: -118, latitudeDelta: 10, longitudeDelta: 10)
        await model.load(viewport: zoomed, filters: ExploreQuery())
        model.selectedPlaceID = Place.syntheticUITestFixtures.first?.id
        XCTAssertNotNil(model.selectedPlace)
        await model.load(viewport: zoomed, filters: ExploreQuery(text: "no such synthetic place"))
        XCTAssertNil(model.selectedPlaceID)
        XCTAssertNil(model.selectedPlace)
    }
}

final class PlaceMediaTests: XCTestCase {
    private let placeID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

    private func asset(parent: UUID?, cleared: Bool) -> MediaAsset {
        MediaAsset(id: UUID(), approvedParentID: parent, creatorCredit: "SYNTHETIC test", altText: "Synthetic pattern", rightsCleared: cleared, source: .bundled(name: "synthetic-media-reading-room"))
    }

    func testPublicPlaceKeepsOnlyRightsClearedMediaOfItsOwnRecord() {
        let place = Place(id: placeID, approvedRevisionID: UUID(), name: "SYNTHETIC", originalLanguage: "en", category: .study, regionID: "test", location: nil, precision: .exactPublic, facts: [],
                          media: [asset(parent: placeID, cleared: true), asset(parent: placeID, cleared: false), asset(parent: UUID(), cleared: true), asset(parent: nil, cleared: true)])
        XCTAssertEqual(place.media.count, 1)
        XCTAssertTrue(place.media.allSatisfy { $0.rightsCleared && $0.approvedParentID == placeID })
    }

    func testCachedPlaceWithoutMediaFieldStillDecodes() throws {
        let legacy = Data(#"{"id":"11111111-1111-1111-1111-111111111111","approvedRevisionID":"22222222-2222-2222-2222-222222222222","name":"SYNTHETIC","originalLanguage":"en","category":"study","regionID":"test","precision":"exactPublic","facts":[]}"#.utf8)
        let place = try JSONDecoder().decode(Place.self, from: legacy)
        XCTAssertTrue(place.media.isEmpty)
    }

    func testMediaSurvivesCodingAndRedactionAppliesOnDecode() throws {
        let place = Place(id: placeID, approvedRevisionID: UUID(), name: "SYNTHETIC", originalLanguage: "en", category: .study, regionID: "test", location: nil, precision: .exactPublic, facts: [], media: [asset(parent: placeID, cleared: true)])
        let restored = try JSONDecoder().decode(Place.self, from: JSONEncoder().encode(place))
        XCTAssertEqual(restored.media, place.media)
    }

    func testSyntheticFixtureMediaIsLabelledAndSomePlacesHaveNone() {
        #if DEBUG
        let fixtures = Place.syntheticUITestFixtures
        XCTAssertTrue(fixtures.contains { !$0.media.isEmpty })
        XCTAssertTrue(fixtures.contains { $0.media.isEmpty }, "No-photo state must stay exercised")
        for media in fixtures.flatMap(\.media) {
            XCTAssertTrue(media.isSynthetic)
            XCTAssertTrue(media.creatorCredit.hasPrefix("SYNTHETIC"))
            XCTAssertFalse(media.altText.isEmpty)
            guard case .bundled(let name) = media.source else { return XCTFail("Synthetic media must be bundled, never fetched") }
            XCTAssertNotNil(UIImage(named: name), "Missing bundled synthetic image \(name)")
        }
        #endif
    }
}
