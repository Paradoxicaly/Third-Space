import XCTest
@testable import ThirdSpace

@MainActor final class SavedRestorationRaceTests: XCTestCase {
    func testWithdrawalWhileFallbackIsSuspendedCannotPublishOrRecache() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let place = syntheticPlace()
        let repository = SuspendedDetailRepository(place: place)
        let environment = AppEnvironment(storageDirectory: root, repository: repository)
        try await LocalSavedStore(url: root.appendingPathComponent("saved.json")).setSaved(.place(place.id), saved: true)
        try await environment.cache.store([place], queryID: "saved:\(place.id.uuidString)", fetchedAt: .distantPast, savedSnapshot: true)
        let restoration = Task { await environment.restoreLocalState() }
        await repository.waitUntilLookupStarts()
        try await environment.cache.remove(placeIDs: [place.id])
        await repository.completeLookup()
        await restoration.value
        XCTAssertTrue(environment.savedPlaces.isEmpty, "An in-flight fallback published a withdrawn record")
        let snapshot = await environment.cache.snapshot(queryID: "saved:\(place.id.uuidString)", at: Date())
        XCTAssertTrue(snapshot?.places.isEmpty ?? true, "A withdrawn record was recached")
        let invalidated = await environment.cache.isInvalidated(place.id)
        XCTAssertTrue(invalidated)
    }

    func testOlderRestorationCannotOverwriteNewerUnsave() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let place = syntheticPlace()
        let repository = SuspendedDetailRepository(place: place)
        let environment = AppEnvironment(storageDirectory: root, repository: repository)
        await environment.toggleSaved(place)
        XCTAssertTrue(environment.savedIDs.contains(place.id))
        try await environment.cache.store([place], queryID: "saved:\(place.id.uuidString)", fetchedAt: .distantPast, savedSnapshot: true)
        let older = Task { await environment.restoreLocalState() }
        await repository.waitUntilLookupStarts()
        await environment.toggleSaved(place)
        XCTAssertTrue(environment.savedPlaces.isEmpty)
        await repository.completeLookup()
        await older.value
        XCTAssertFalse(environment.savedIDs.contains(place.id))
        XCTAssertTrue(environment.savedPlaces.isEmpty, "An older restoration republished an unsaved place")
        let durable = try await LocalSavedStore(url: root.appendingPathComponent("saved.json")).all()
        XCTAssertFalse(durable.contains(.place(place.id)))
    }

    func testPublicationRechecksInvalidationAfterEarlierEligibilityRead() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let place = syntheticPlace()
        let cache = OwnedContentCache(url: root.appendingPathComponent("cache.json"))
        let previouslyEligible = try await cache.excludingInvalidated([place])
        try await cache.remove(placeIDs: [place.id])
        var published: [Place] = []
        cache.publishEligible(previouslyEligible) { published = $0 }
        XCTAssertTrue(published.isEmpty, "Pre-await or earlier filtering is not publication-boundary validation")
    }

    private func syntheticPlace() -> Place {
        Place(id: UUID(uuidString: "77777777-0000-0000-0000-000000000001")!, approvedRevisionID: UUID(uuidString: "77777777-0000-0000-0000-000000000002")!, name: "SYNTHETIC — controlled restoration", originalLanguage: "en", category: .study, regionID: "synthetic-test", location: nil, precision: .exactPublic, facts: [])
    }
}

private actor SuspendedDetailRepository: PlaceRepository {
    let place: Place
    private var started = false
    private var startWaiter: CheckedContinuation<Void, Never>?
    private var lookup: CheckedContinuation<Place?, Never>?
    init(place: Place) { self.place = place }
    func waitUntilLookupStarts() async {
        if started { return }
        await withCheckedContinuation { startWaiter = $0 }
    }
    func completeLookup() {
        lookup?.resume(returning: place)
        lookup = nil
    }
    func getPlace(_ id: UUID) async throws -> Place? {
        started = true
        startWaiter?.resume(); startWaiter = nil
        return await withCheckedContinuation { lookup = $0 }
    }
    func searchPlaces(_ query: ExploreQuery, cursor: PlaceCursor?, generation: UInt64) async throws -> PlacePage { throw RepositoryError.unavailable }
    func mapSummary(_ query: ExploreQuery, zoomBucket: Int) async throws -> MapSummary { throw RepositoryError.unavailable }
}
