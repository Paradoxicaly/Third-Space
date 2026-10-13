import XCTest
@testable import ThirdSpace

final class LocalPersistenceFailureTests: XCTestCase {
    private let malformed = Data("NOT JSON — SYNTHETIC CORRUPTION".utf8)

    func testDraftWriteDoesNotReplaceUnreadableExistingData() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try malformed.write(to: url)
        let draft = Submission(id: UUID(), kind: .newPlace, originalLanguage: "en", body: "SYNTHETIC", state: .localDraft)
        do { try await DraftStore(url: url).put(draft); XCTFail("Unreadable drafts were silently replaced") } catch { }
        XCTAssertEqual(try Data(contentsOf: url), malformed)
    }

    func testSavedWriteDoesNotReplaceUnreadableExistingData() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try malformed.write(to: url)
        do { try await LocalSavedStore(url: url).setSaved(.place(UUID()), saved: true); XCTFail("Unreadable saves were silently replaced") } catch { }
        XCTAssertEqual(try Data(contentsOf: url), malformed)
    }

    func testCacheWriteDoesNotEraseUnreadableTombstoneState() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        try malformed.write(to: url)
        do { try await OwnedContentCache(url: url).store([], queryID: "q", fetchedAt: Date()); XCTFail("Unreadable tombstone state was erased") } catch { }
        XCTAssertEqual(try Data(contentsOf: url), malformed)
    }
}
