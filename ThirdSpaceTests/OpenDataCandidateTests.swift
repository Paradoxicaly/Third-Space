import XCTest
@testable import ThirdSpace

final class OpenDataCandidateCatalogTests: XCTestCase {
    private func catalogPlaces() throws -> [Place] {
        try OpenDataCandidateCatalog.load(from: Bundle(for: AppEnvironment.self)).places
    }

    func testBundledCatalogCoversCaliforniaWithStableUniqueRecords() throws {
        let places = try catalogPlaces()
        XCTAssertGreaterThanOrEqual(places.count, 250)
        XCTAssertEqual(Set(places.map(\.id)).count, places.count, "IDs must be unique")
        for place in places {
            let point = try XCTUnwrap(place.location, "\(place.name) has no public position")
            XCTAssertTrue((32.4...42.1).contains(point.latitude) && (-124.6 ... -114.1).contains(point.longitude), "\(place.name) is outside California")
            XCTAssertFalse(place.name.isEmpty)
            XCTAssertTrue(place.regionID.hasPrefix("us-ca-"))
        }
        // Spot-check a known public building against its published address (4044 Idaho St, San Diego).
        let northPark = try XCTUnwrap(places.first { $0.name == "North Park Rec Center" })
        XCTAssertEqual(northPark.id, UUID(uuidString: "96848D16-4B83-5F06-90EB-A6B5991F9671"))
        XCTAssertEqual(try XCTUnwrap(northPark.location).latitude, 32.7509, accuracy: 0.002)
        XCTAssertEqual(try XCTUnwrap(northPark.location).longitude, -117.1342, accuracy: 0.002)
    }

    func testEveryCandidateCarriesSourceLicenceAndCitationAndNoInventedFacts() throws {
        for place in try catalogPlaces() {
            let provenance = try XCTUnwrap(place.provenance, "\(place.name) lacks provenance")
            XCTAssertEqual(provenance.reviewStatus, .unreviewedCandidate)
            XCTAssertFalse(provenance.license.isEmpty)
            XCTAssertFalse(provenance.citation.isEmpty)
            XCTAssertFalse(provenance.sourceRecordID.isEmpty)
            XCTAssertFalse(provenance.coordinateMethod.isEmpty)
            XCTAssertNotNil(provenance.address)
            XCTAssertTrue(place.facts.isEmpty, "Open-data candidates must not claim practical facts")
            XCTAssertTrue(place.media.isEmpty, "No imagery without separate rights review")
        }
    }

    func testProvenanceSurvivesCodingAndLegacyPlacesDecodeWithout() throws {
        let place = try XCTUnwrap(try catalogPlaces().first)
        let restored = try JSONDecoder().decode(Place.self, from: JSONEncoder().encode(place))
        XCTAssertEqual(restored.provenance, place.provenance)
        let legacy = Data(#"{"id":"11111111-1111-1111-1111-111111111111","approvedRevisionID":"22222222-2222-2222-2222-222222222222","name":"SYNTHETIC","originalLanguage":"en","category":"study","regionID":"test","precision":"exactPublic","facts":[]}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(Place.self, from: legacy).provenance)
    }
}

final class CandidateRepositoryTests: XCTestCase {
    private func repository() throws -> CandidatePlaceRepository {
        try CandidatePlaceRepository(catalog: OpenDataCandidateCatalog.load(from: Bundle(for: AppEnvironment.self)))
    }

    func testSearchPagesRealCandidatesAndMatchesAddressText() async throws {
        let repository = try repository()
        let first = try await repository.searchPlaces(ExploreQuery(), cursor: nil, generation: 1)
        XCTAssertEqual(first.places.count, 30)
        XCTAssertGreaterThanOrEqual(first.totalCount ?? 0, 250)
        XCTAssertNotNil(first.nextCursor)
        let oakland = try await repository.searchPlaces(ExploreQuery(text: "oakland"), cursor: nil, generation: 2)
        XCTAssertGreaterThan(oakland.totalCount ?? 0, 5, "City text should match candidate addresses, not only names")
    }

    func testMapAggregatesAtStateScaleAndListsPlacesWhenZoomed() async throws {
        let repository = try repository()
        let total = try await repository.searchPlaces(ExploreQuery(), cursor: nil, generation: 1).totalCount
        guard case .aggregate(let cells, _, _) = try await repository.mapSummary(ExploreQuery(), zoomBucket: 4) else {
            return XCTFail("State-scale candidate map should aggregate")
        }
        XCTAssertEqual(cells.reduce(0) { $0 + $1.count }, total)
        let downtownSF = try XCTUnwrap(MapViewport(centerLatitude: 37.78, centerLongitude: -122.42, latitudeDelta: 0.2, longitudeDelta: 0.2).bounds)
        guard case .places(let places, _, _, _) = try await repository.mapSummary(ExploreQuery(area: .bounds(downtownSF)), zoomBucket: 11) else {
            return XCTFail("Zoomed candidate map should list places")
        }
        XCTAssertFalse(places.isEmpty)
        XCTAssertTrue(places.allSatisfy { downtownSF.contains($0.location!) })
    }
}

@MainActor final class CandidateCompositionTests: XCTestCase {
    func testCandidateFlagIsDebugOnlyAndSeparateFromSyntheticFixtures() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let environment = AppEnvironment(arguments: ["--candidates"], storageDirectory: root)
        #if DEBUG
        XCTAssertEqual(environment.catalogMode, .candidates)
        XCTAssertFalse(environment.isSynthetic)
        XCTAssertEqual(environment.recordNoun, "candidate place")
        XCTAssertNotNil(environment.catalogNotice)
        XCTAssertGreaterThan(environment.regions.count, 50)
        let page = try await environment.repository.searchPlaces(ExploreQuery(), cursor: nil, generation: 1)
        XCTAssertFalse(page.places.contains { $0.name.hasPrefix("SYNTHETIC") })
        #else
        XCTAssertEqual(environment.catalogMode, .failClosed)
        do { _ = try await environment.repository.searchPlaces(ExploreQuery(), cursor: nil, generation: 1); XCTFail("Release composition enabled candidates") } catch RepositoryError.unavailable { }
        #endif
    }
}
