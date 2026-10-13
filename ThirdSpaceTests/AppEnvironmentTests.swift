import XCTest
@testable import ThirdSpace

@MainActor final class AppEnvironmentTests: XCTestCase {
    func testNormalCompositionFailsClosedAndIgnoresScenarioFlags() async {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let environment = AppEnvironment(arguments: ["--offline", "--empty", "--malformed-query"], storageDirectory: root)
        XCTAssertFalse(environment.isSynthetic)
        XCTAssertTrue(environment.launchArguments.isEmpty)
        XCTAssertNil(environment.explore.queryRestorationProblem)
        await environment.explore.refresh()
        guard case .failed = environment.explore.state else { return XCTFail("Normal launch manufactured offline/empty/synthetic coverage") }
    }

    func testExplicitTestingFlagCannotEnableFixturesInReleaseComposition() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let environment = AppEnvironment(arguments: ["--ui-testing", "--reset-local-data", "--malformed-query"], storageDirectory: root)
        #if DEBUG
        XCTAssertTrue(environment.isSynthetic)
        let page = try await environment.repository.searchPlaces(ExploreQuery(), cursor: nil, generation: 1)
        XCTAssertEqual(page.places.count, 2)
        #else
        XCTAssertFalse(environment.isSynthetic)
        XCTAssertTrue(environment.launchArguments.isEmpty)
        XCTAssertNil(environment.explore.queryRestorationProblem)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("query.json").path), "Release executed a destructive synthetic preparation flag")
        do { _ = try await environment.repository.searchPlaces(ExploreQuery(), cursor: nil, generation: 1); XCTFail("Release composition enabled fixtures") } catch RepositoryError.unavailable { }
        #endif
    }

    #if DEBUG
    func testSavedTombstoneCannotFallBackToStaleRepositoryRecord() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let environment = AppEnvironment(arguments: ["--ui-testing"], storageDirectory: root)
        let place = try XCTUnwrap(Place.syntheticUITestFixtures.first)
        await environment.toggleSaved(place)
        XCTAssertEqual(environment.savedPlaces.first?.id, place.id)
        try await environment.cache.remove(placeIDs: [place.id])
        await environment.restoreLocalState()
        XCTAssertTrue(environment.savedIDs.contains(place.id))
        XCTAssertTrue(environment.savedPlaces.isEmpty, "A tombstoned saved item was resurrected through repository fallback")
    }
    #endif
}
