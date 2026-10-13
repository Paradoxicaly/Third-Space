import XCTest
@testable import ThirdSpace

@MainActor final class QueryRestorationTests: XCTestCase {
    func testMissingFileUsesFirstLaunchDefaultsAndCanPersist() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("query.json")
        let model = model(root: root, queryURL: url)
        XCTAssertEqual(model.query, ExploreQuery())
        XCTAssertNil(model.notice)
        await model.refresh()
        assertBrowsingWorks(model)
        XCTAssertEqual(try JSONDecoder().decode(ExploreQuery.self, from: Data(contentsOf: url)), ExploreQuery())
    }

    func testMalformedFileSurvivesAutomaticRefreshAndTemporaryQueryChanges() async throws {
        try await assertUnreadableBytesKept(Data("SYNTHETIC malformed query — not JSON".utf8))
    }

    func testIncompatibleJSONSurvivesAutomaticRefresh() async throws {
        try await assertUnreadableBytesKept(Data("{\"future_schema\":2}".utf8))
    }

    func testReadFailureIsReportedRatherThanTreatedAsMissing() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("query.json", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let marker = url.appendingPathComponent("preserve.txt")
        let bytes = Data("SYNTHETIC read-failure sentinel".utf8)
        try bytes.write(to: marker)
        let model = model(root: root, queryURL: url)
        XCTAssertNotNil(model.notice, "A read error silently became an ordinary first launch")
        await model.refresh()
        assertBrowsingWorks(model)
        XCTAssertNotNil(model.notice)
        XCTAssertEqual(try Data(contentsOf: marker), bytes)
    }

    func testExplicitResetReplacesOnlyStoredQueryAndAllowsFuturePersistence() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("query.json")
        let bytes = Data("SYNTHETIC unreadable query".utf8)
        try bytes.write(to: url)
        let saves = root.appendingPathComponent("saved.json")
        let drafts = root.appendingPathComponent("drafts.json")
        try Data("SYNTHETIC saves sentinel".utf8).write(to: saves)
        try Data("SYNTHETIC drafts sentinel".utf8).write(to: drafts)
        let model = model(root: root, queryURL: url)
        await model.refresh()
        XCTAssertEqual(try Data(contentsOf: url), bytes)
        XCTAssertTrue(model.resetStoredQuery())
        XCTAssertNil(model.queryRestorationProblem)
        XCTAssertEqual(try JSONDecoder().decode(ExploreQuery.self, from: Data(contentsOf: url)), ExploreQuery())
        model.query.text = "SYNTHETIC deliberate recovered search"
        await model.refresh()
        XCTAssertEqual(try JSONDecoder().decode(ExploreQuery.self, from: Data(contentsOf: url)), model.query)
        XCTAssertEqual(try Data(contentsOf: saves), Data("SYNTHETIC saves sentinel".utf8))
        XCTAssertEqual(try Data(contentsOf: drafts), Data("SYNTHETIC drafts sentinel".utf8))
    }

    func testFailedResetKeepsReadFailureActionableAndBrowsingAvailable() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("query.json", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        let marker = url.appendingPathComponent("preserve.txt")
        try Data("SYNTHETIC sentinel".utf8).write(to: marker)
        let model = model(root: root, queryURL: url)
        XCTAssertFalse(model.resetStoredQuery())
        XCTAssertNotNil(model.queryRestorationProblem)
        await model.refresh()
        assertBrowsingWorks(model)
        XCTAssertEqual(try Data(contentsOf: marker), Data("SYNTHETIC sentinel".utf8))
    }

    func testRetryDoesNotAuthorizeOverwritingStillUnreadableData() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("query.json")
        let bytes = Data("SYNTHETIC unreadable query".utf8)
        try bytes.write(to: url)
        let model = model(root: root, queryURL: url)
        model.retryStoredQueryRestoration()
        await model.refresh()
        XCTAssertNotNil(model.queryRestorationProblem)
        XCTAssertEqual(try Data(contentsOf: url), bytes)
    }

    func testRetryRestoresValidDataAfterExternalStorageRepair() async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("query.json")
        try Data("SYNTHETIC unreadable query".utf8).write(to: url)
        let model = model(root: root, queryURL: url)
        var repaired = ExploreQuery(); repaired.text = "SYNTHETIC repaired storage"
        try JSONEncoder().encode(repaired).write(to: url)
        model.retryStoredQueryRestoration()
        XCTAssertEqual(model.query, repaired)
        XCTAssertNil(model.queryRestorationProblem)
        await model.refresh()
        assertBrowsingWorks(model)
        XCTAssertEqual(try JSONDecoder().decode(ExploreQuery.self, from: Data(contentsOf: url)), repaired)
    }

    private func assertUnreadableBytesKept(_ bytes: Data) async throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let url = root.appendingPathComponent("query.json")
        try bytes.write(to: url)
        let model = model(root: root, queryURL: url)
        XCTAssertNotNil(model.notice, "Restoration failure must be actionable, not silently defaulted")
        await model.refresh()
        assertBrowsingWorks(model)
        XCTAssertEqual(try Data(contentsOf: url), bytes, "Automatic refresh replaced unreadable existing data")
        model.query.text = "Temporary SYNTHETIC search"
        await model.refresh()
        assertBrowsingWorks(model)
        XCTAssertEqual(try Data(contentsOf: url), bytes, "A temporary search bypassed failed-restoration protection")
        XCTAssertNotNil(model.notice)
    }

    private func temporaryRoot() -> URL { FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString) }
    private func model(root: URL, queryURL: URL) -> ExploreViewModel {
        ExploreViewModel(repository: ImmediateSyntheticRepository(), cache: OwnedContentCache(url: root.appendingPathComponent("cache.json")), queryURL: queryURL)
    }
    private func assertBrowsingWorks(_ model: ExploreViewModel, file: StaticString = #filePath, line: UInt = #line) {
        guard case .loaded(let places) = model.state else { return XCTFail("Preservation prevented browsing", file: file, line: line) }
        XCTAssertEqual(places.count, 1, file: file, line: line)
    }
}

private struct ImmediateSyntheticRepository: PlaceRepository {
    func searchPlaces(_ query: ExploreQuery, cursor: PlaceCursor?, generation: UInt64) async throws -> PlacePage {
        let place = Place(id: UUID(uuidString: "88888888-0000-0000-0000-000000000001")!, approvedRevisionID: UUID(uuidString: "88888888-0000-0000-0000-000000000002")!, name: "SYNTHETIC — query restoration test", originalLanguage: "en", category: .study, regionID: "synthetic-test", location: nil, precision: .exactPublic, facts: [])
        return PlacePage(places: [place], queryID: query.queryID, generation: generation, watermark: "synthetic-test", nextCursor: nil, totalCount: 1)
    }
    func getPlace(_ id: UUID) async throws -> Place? { nil }
    func mapSummary(_ query: ExploreQuery, zoomBucket: Int) async throws -> MapSummary { throw RepositoryError.unavailable }
}
