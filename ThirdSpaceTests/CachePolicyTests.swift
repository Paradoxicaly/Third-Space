import XCTest
@testable import ThirdSpace

final class CachePolicyTests: XCTestCase {
    func testSensitiveParentAndDescendantAreNeverCached() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = OwnedContentCache(url: url)
        let sensitive = Place(id: UUID(), approvedRevisionID: UUID(), name: "SYNTHETIC SECRET", originalLanguage: "en", category: .other, regionID: "test", location: GeoPoint(latitude: 0, longitude: 1), precision: .approximatePublic, facts: [])
        try await cache.store([sensitive], queryID: "q", fetchedAt: Date(), hasSensitiveDescendants: true)
        let reload = OwnedContentCache(url: url)
        let snapshot = await reload.snapshot(queryID: "q", at: Date())
        XCTAssertNil(snapshot)
    }

    func testNewSensitivityPurgesOldSnapshot() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = OwnedContentCache(url: url)
        let id = UUID()
        let ordinary = Place(id: id, approvedRevisionID: UUID(), name: "SYNTHETIC", originalLanguage: "en", category: .study, regionID: "test", location: nil, precision: .exactPublic, facts: [])
        try await cache.store([ordinary], queryID: "q", fetchedAt: Date())
        try await cache.remove(placeIDs: [id])
        let result = await OwnedContentCache(url: url).snapshot(queryID: "q", at: Date())
        XCTAssertEqual(result?.places.count, 0)
    }

    func testTombstoneRemovesPreviouslyStoredContentAcrossRelaunch() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = OwnedContentCache(url: url)
        let place = Place(id: UUID(), approvedRevisionID: UUID(), name: "SYNTHETIC", originalLanguage: "en", category: .study, regionID: "test", location: nil, precision: .exactPublic, facts: [])
        try await cache.store([place], queryID: "q", fetchedAt: Date())
        try await cache.remove(placeIDs: [place.id])
        let result = await OwnedContentCache(url: url).snapshot(queryID: "q", at: Date())
        XCTAssertEqual(result?.places.count, 0)
    }

    func testSensitiveReplacementPurgesPriorSnapshotsWithoutSeparateTombstoneCall() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = OwnedContentCache(url: url)
        let id = UUID()
        let ordinary = Place(id: id, approvedRevisionID: UUID(), name: "SYNTHETIC", originalLanguage: "en", category: .study, regionID: "test", location: nil, precision: .exactPublic, facts: [])
        try await cache.store([ordinary], queryID: "old", fetchedAt: Date())
        try await cache.store([ordinary], queryID: "old", fetchedAt: Date(), hasSensitiveDescendants: true)
        let replacement = Place(id: id, approvedRevisionID: UUID(), name: "SYNTHETIC SECRET", originalLanguage: "en", category: .study, regionID: "test", location: nil, precision: .approximatePublic, facts: [])
        try await cache.store([replacement], queryID: "other", fetchedAt: Date())
        let reload = OwnedContentCache(url: url)
        let old = await reload.snapshot(queryID: "old", at: Date())
        let other = await reload.snapshot(queryID: "other", at: Date())
        XCTAssertTrue(old == nil || old?.places.isEmpty == true)
        XCTAssertEqual(other?.places.count, 0)
    }

    func testSnapshotExpiresAtBoundaryAndTombstoneRejectsStalePage() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        let cache = OwnedContentCache(url: url)
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let place = Place(id: UUID(), approvedRevisionID: UUID(), name: "SYNTHETIC", originalLanguage: "en", category: .study, regionID: "test", location: nil, precision: .exactPublic, facts: [])
        try await cache.store([place], queryID: "q", fetchedAt: now)
        let expired = await cache.snapshot(queryID: "q", at: now.addingTimeInterval(86_400))
        XCTAssertNil(expired)
        try await cache.remove(placeIDs: [place.id])
        try await cache.store([place], queryID: "q", fetchedAt: now)
        let stale = await OwnedContentCache(url: url).snapshot(queryID: "q", at: now)
        XCTAssertEqual(stale?.places.count, 0)
    }

    func testOfflineColdStartDoesNotManufacturePlaces() async {
        let cache = OwnedContentCache(url: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString))
        let cold = await cache.snapshot(queryID: "world", at: Date())
        XCTAssertNil(cold)
        let state = LoadState<[Place]>.offline(cached: nil, asOf: nil)
        XCTAssertTrue(state.isColdOffline)
    }

    func testSavedAndDraftsSurviveNewStoreInstances() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let id = UUID()
        let saves = LocalSavedStore(url: directory.appendingPathComponent("saves.json"))
        try await saves.setSaved(.place(id), saved: true)
        let drafts = DraftStore(url: directory.appendingPathComponent("drafts.json"))
        let draft = Submission(id: UUID(), kind: .newPlace, originalLanguage: "ja", body: "SYNTHETIC DRAFT", state: .localDraft)
        try await drafts.put(draft)
        let saved = try await LocalSavedStore(url: directory.appendingPathComponent("saves.json")).contains(.place(id))
        let restoredDrafts = try await DraftStore(url: directory.appendingPathComponent("drafts.json")).all()
        XCTAssertTrue(saved)
        XCTAssertEqual(restoredDrafts.first?.id, draft.id)
    }
}
