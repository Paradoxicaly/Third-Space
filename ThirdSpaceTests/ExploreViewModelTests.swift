import XCTest
@testable import ThirdSpace

@MainActor final class ExploreViewModelTests: XCTestCase {
    func testUnavailableErrorIsNotMisreportedAsOffline() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = ExploreViewModel(repository: FailureRepository(error: .unavailable), cache: OwnedContentCache(url: root.appendingPathComponent("cache.json")), queryURL: root.appendingPathComponent("query.json"))
        await model.refresh()
        guard case .failed = model.state else { return XCTFail("A repository outage is an error, not an offline coverage result") }
    }

    func testColdOfflineAndCachedOfflineAreDistinct() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = OwnedContentCache(url: root.appendingPathComponent("cache.json"))
        let model = ExploreViewModel(repository: FailureRepository(error: .offline), cache: cache, queryURL: root.appendingPathComponent("query.json"))
        await model.refresh()
        XCTAssertTrue(model.state.isColdOffline)
        let places = Place.syntheticUITestFixtures
        try await cache.store(places, queryID: model.query.queryID, fetchedAt: Date())
        await model.refresh()
        guard case .offline(let cached, let asOf) = model.state else { return XCTFail("Offline cache was hidden") }
        XCTAssertEqual(cached?.count, places.count)
        XCTAssertNotNil(asOf)
    }

    func testPaginationAndQueryRestoreUseRealIDs() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = OwnedContentCache(url: root.appendingPathComponent("cache.json"))
        let repository = MockPlaceRepository(launchArguments: ["--ui-testing"], pageSize: 1)
        let model = ExploreViewModel(repository: repository, cache: cache, queryURL: root.appendingPathComponent("query.json"))
        model.query.text = "SYNTHETIC"
        await model.refresh()
        XCTAssertNotNil(model.nextCursor)
        await model.loadMore()
        guard case .loaded(let places) = model.state else { return XCTFail("Pagination did not load") }
        XCTAssertEqual(places.count, 2)
        XCTAssertEqual(Set(places.map(\.id)).count, 2)
        let restored = ExploreViewModel(repository: repository, cache: cache, queryURL: root.appendingPathComponent("query.json"))
        XCTAssertEqual(restored.query.queryID, model.query.queryID)
    }

    func testSupersededResponseCannotReplaceNewQuery() async {
        // A repository may finish an older request after a newer query has loaded.
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = ExploreViewModel(repository: DelayedRepository(), cache: OwnedContentCache(url: root.appendingPathComponent("cache.json")), queryURL: root.appendingPathComponent("query.json"))
        model.query.text = "old"
        let first = Task { await model.refresh() }
        await Task.yield()
        model.query.text = "new"
        await model.refresh()
        await first.value
        guard case .loaded(let places) = model.state else { return XCTFail("New results were lost") }
        XCTAssertEqual(places.first?.name, "SYNTHETIC — new")
    }

    func testOutageRetainsDatedCacheWithoutCallingItOffline() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = OwnedContentCache(url: root.appendingPathComponent("cache.json"))
        let model = ExploreViewModel(repository: FailureRepository(error: .unavailable), cache: cache, queryURL: root.appendingPathComponent("query.json"))
        let asOf = Date()
        try await cache.store([], queryID: model.query.queryID, fetchedAt: asOf)
        await model.refresh()
        guard case .cached(let places, let date) = model.state else { return XCTFail("Outage hid the retained cache or claimed the device was offline") }
        XCTAssertTrue(places.isEmpty)
        XCTAssertEqual(date, asOf)
    }

    func testStalePageCannotResurrectAnInvalidatedPlace() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let cache = OwnedContentCache(url: root.appendingPathComponent("cache.json"))
        let model = ExploreViewModel(repository: DelayedRepository(), cache: cache, queryURL: root.appendingPathComponent("query.json"))
        await model.refresh()
        guard case .loaded(let places) = model.state, let place = places.first else { return XCTFail("Fixture did not load") }
        try await cache.remove(placeIDs: [place.id])
        await model.refresh()
        guard case .failed = model.state else { return XCTFail("Withdrawn results were resurrected or misrepresented as zero coverage") }
    }

    func testQueryStorageFailureDoesNotPreventPermissionFreeBrowse() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let model = ExploreViewModel(repository: DelayedRepository(), cache: OwnedContentCache(url: root.appendingPathComponent("cache.json")), queryURL: root)
        await model.refresh()
        guard case .loaded = model.state else { return XCTFail("Query restore storage failure blocked otherwise valid browsing") }
        XCTAssertNotNil(model.notice)
    }

    func testCancelledRequestDoesNotBecomeAnOutage() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = ExploreViewModel(repository: MockPlaceRepository(launchArguments: ["--ui-testing", "--slow"]), cache: OwnedContentCache(url: root.appendingPathComponent("cache.json")), queryURL: root.appendingPathComponent("query.json"))
        let task = Task { await model.refresh() }
        task.cancel()
        await task.value
        if case .failed = model.state { XCTFail("Cancellation was presented as a repository outage") }
        XCTAssertNil(model.nextCursor)
    }
}

private actor FailureRepository: PlaceRepository {
    let error: RepositoryError
    init(error: RepositoryError) { self.error = error }
    func searchPlaces(_ query: ExploreQuery, cursor: PlaceCursor?, generation: UInt64) async throws -> PlacePage { throw error }
    func getPlace(_ id: UUID) async throws -> Place? { throw error }
    func mapSummary(_ query: ExploreQuery, zoomBucket: Int) async throws -> MapSummary { throw error }
}
private actor DelayedRepository: PlaceRepository {
    func searchPlaces(_ query: ExploreQuery, cursor: PlaceCursor?, generation: UInt64) async throws -> PlacePage {
        if query.text == "old" { try await Task.sleep(nanoseconds: 100_000_000) }
        let place = Place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!, approvedRevisionID: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!, name: "SYNTHETIC — \(query.text)", originalLanguage: "en", category: .other, regionID: "test", location: nil, precision: .exactPublic, facts: [])
        return PlacePage(places: [place], queryID: query.queryID, generation: generation, watermark: "test", nextCursor: nil, totalCount: 1)
    }
    func getPlace(_ id: UUID) async throws -> Place? { nil }
    func mapSummary(_ query: ExploreQuery, zoomBucket: Int) async throws -> MapSummary { throw RepositoryError.unavailable }
}
