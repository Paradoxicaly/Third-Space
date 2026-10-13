import XCTest
@testable import ThirdSpace

final class RepositoryContractTests: XCTestCase {
    func testMockFixturesRequireExplicitUITestingLaunch() async throws {
        let disabled = MockPlaceRepository(launchArguments: [])
        do {
            _ = try await disabled.searchPlaces(ExploreQuery(), cursor: nil, generation: 1)
            XCTFail("Production selected a synthetic repository")
        } catch RepositoryError.unavailable { }
        let enabled = MockPlaceRepository(launchArguments: ["--ui-testing"])
        #if DEBUG
        let page = try await enabled.searchPlaces(ExploreQuery(), cursor: nil, generation: 1)
        XCTAssertFalse(page.places.isEmpty)
        XCTAssertTrue(page.places.allSatisfy { $0.name.contains("SYNTHETIC") })
        #else
        do {
            _ = try await enabled.searchPlaces(ExploreQuery(), cursor: nil, generation: 1)
            XCTFail("Release must ignore even an explicit --ui-testing flag")
        } catch RepositoryError.unavailable { }
        do {
            _ = try await enabled.getPlace(UUID())
            XCTFail("Release detail lookup used a mock")
        } catch RepositoryError.unavailable { }
        do {
            _ = try await enabled.mapSummary(ExploreQuery(), zoomBucket: 4)
            XCTFail("Release map summary used a mock")
        } catch RepositoryError.unavailable { }
        #endif
    }

    func testFailClosedRepositoryNeverManufacturesCoverage() async throws {
        let repository = FailClosedPlaceRepository()
        do {
            _ = try await repository.searchPlaces(ExploreQuery(), cursor: nil, generation: 1)
            XCTFail("Unavailable catalog was reported as coverage")
        } catch RepositoryError.unavailable { }
        do {
            _ = try await repository.getPlace(UUID())
            XCTFail("Unavailable catalog detail was reported as missing")
        } catch RepositoryError.unavailable { }
        do {
            _ = try await repository.mapSummary(ExploreQuery(), zoomBucket: 1)
            XCTFail("Unavailable map summary was reported as coverage")
        } catch RepositoryError.unavailable { }
    }

    #if DEBUG
    func testOfflineNeverReturnsFixturesOnRetry() async throws {
        let repository = MockPlaceRepository(launchArguments: ["--ui-testing", "--offline"])
        for _ in 0..<2 {
            do {
                _ = try await repository.searchPlaces(ExploreQuery(), cursor: nil, generation: 1)
                XCTFail("Offline request manufactured a successful fixture page")
            } catch RepositoryError.offline { }
        }
        do {
            _ = try await repository.getPlace(UUID())
            XCTFail("Offline detail should fail")
        } catch RepositoryError.offline { }
        do {
            _ = try await repository.mapSummary(ExploreQuery(), zoomBucket: 1)
            XCTFail("Offline map summary should fail")
        } catch RepositoryError.offline { }
    }

    func testErrorScenarioRecoversOnDeterministicRetry() async throws {
        let repository = MockPlaceRepository(launchArguments: ["--ui-testing", "--error"])
        do {
            _ = try await repository.searchPlaces(ExploreQuery(), cursor: nil, generation: 1)
            XCTFail("Error scenario did not fail its first request")
        } catch RepositoryError.unavailable { }
        let page = try await repository.searchPlaces(ExploreQuery(), cursor: nil, generation: 2)
        XCTAssertFalse(page.places.isEmpty)
        XCTAssertEqual(page.generation, 2)
    }

    func testEmptyScenarioHasNoDetailOrAggregateCells() async throws {
        let repository = MockPlaceRepository(launchArguments: ["--ui-testing", "--empty"])
        let page = try await repository.searchPlaces(ExploreQuery(), cursor: nil, generation: 1)
        XCTAssertTrue(page.places.isEmpty)
        XCTAssertEqual(page.totalCount, 0)
        XCTAssertNil(page.nextCursor)
        let detail = try await repository.getPlace(UUID(uuidString: "00000000-0000-0000-0000-000000000101")!)
        XCTAssertNil(detail)
        guard case .aggregate(let cells, _, _) = try await repository.mapSummary(ExploreQuery(), zoomBucket: 1) else {
            return XCTFail("World query did not return an aggregate summary")
        }
        XCTAssertTrue(cells.isEmpty)
    }

    func testSlowScenarioRespectsCancellation() async throws {
        let repository = MockPlaceRepository(launchArguments: ["--ui-testing", "--slow"], slowDelayNanoseconds: 5_000_000_000)
        let task = Task { try await repository.searchPlaces(ExploreQuery(), cursor: nil, generation: 1) }
        task.cancel()
        do {
            _ = try await task.value
            XCTFail("Cancelled slow request published fixtures")
        } catch is CancellationError { }
    }

    func testWorldAggregateCoversEntireNormalizedLongitudeRange() async throws {
        let repository = MockPlaceRepository(launchArguments: ["--ui-testing"])
        guard case .aggregate(let cells, _, _) = try await repository.mapSummary(ExploreQuery(), zoomBucket: 1) else {
            return XCTFail("World query did not return an aggregate summary")
        }
        // Grid cells replace the single world cell; places beside ±180° are still counted once each.
        XCTAssertEqual(cells.reduce(0) { $0 + $1.count }, Place.syntheticUITestFixtures.count)
        XCTAssertTrue(cells.contains { $0.bounds.contains(GeoPoint(latitude: -17.7, longitude: 179.5)!) })
        XCTAssertTrue(cells.contains { $0.bounds.contains(GeoPoint(latitude: -18, longitude: -179.5)!) })
    }

    func testCursorCannotBeReusedAcrossQueryOrRevision() async throws {
        let repository = MockPlaceRepository(launchArguments: ["--ui-testing"], pageSize: 1)
        let query = ExploreQuery()
        let first = try await repository.searchPlaces(query, cursor: nil, generation: 1)
        let cursor = try XCTUnwrap(first.nextCursor)
        do {
            _ = try await repository.searchPlaces(ExploreQuery(text: "different"), cursor: cursor, generation: 2)
            XCTFail("Cursor from a superseded query was accepted")
        } catch RepositoryError.refreshRequired { }
        let second = try await repository.searchPlaces(query, cursor: cursor, generation: 1)
        XCTAssertNotEqual(first.places.first?.id, second.places.first?.id)
    }

    func testNegativeCursorOffsetRequiresRefreshInsteadOfCrashing() async throws {
        let repository = MockPlaceRepository(launchArguments: ["--ui-testing"])
        let query = ExploreQuery()
        let first = try await repository.searchPlaces(query, cursor: nil, generation: 1)
        let malformed = PlaceCursor(queryID: first.queryID, generation: first.generation, watermark: first.watermark, offset: -1)
        do {
            _ = try await repository.searchPlaces(query, cursor: malformed, generation: 1)
            XCTFail("Negative cursor offset was accepted")
        } catch RepositoryError.refreshRequired { }
    }

    func testMissingPlaceNeverFallsBackToSyntheticData() async throws {
        let repository = MockPlaceRepository(launchArguments: ["--ui-testing"])
        let missing = try await repository.getPlace(UUID())
        XCTAssertNil(missing)
    }
    #endif
}
