import XCTest
@testable import ThirdSpace

/// The Community tab's thread feed: place-anchored threads across every approved place, with the same
/// moderation and visibility rules as the place page.
final class ForumFeedTests: XCTestCase {
    private var root: URL!
    private let catalog = Place.syntheticUITestFixtures
    private var file: URL { root.appendingPathComponent("community.json") }

    override func setUp() {
        super.setUp()
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }
    override func tearDown() { try? FileManager.default.removeItem(at: root); super.tearDown() }

    private func service() -> InMemoryCommunityService { InMemoryCommunityService(url: file, catalogPlaces: catalog) }

    private func approveAll(_ backend: InMemoryCommunityService) async throws {
        _ = try await backend.signIn(email: InMemoryCommunityService.moderatorEmail, password: InMemoryCommunityService.testPassword)
        for post in try await backend.pendingPosts() { try await backend.moderatePost(id: post.id, decision: .approved, note: nil) }
    }

    func testSeededThreadsAreSyntheticApprovedAndIncludeAnAnsweredQuestion() async throws {
        let feed = try await service().recentThreads(kind: nil, limit: 50)
        XCTAssertGreaterThanOrEqual(feed.count, 2)
        for thread in feed {
            XCTAssertEqual(thread.status, .approved)
            XCTAssertNil(thread.parentIDForFeedCheck)
            XCTAssertTrue(((thread.title ?? "") + thread.body).contains("SYNTHETIC"), "Seeded threads must be labelled synthetic")
        }
        XCTAssertTrue(feed.contains { $0.kind == .question && !$0.replies.isEmpty }, "Feed needs an answered question to exercise threads")
    }

    func testFeedShowsApprovedRootsAcrossPlacesNewestFirstAndOnlyOwnPending() async throws {
        let backend = service()
        let (first, second) = (catalog[0].id, catalog[1].id)
        _ = try await backend.signUp(email: "author@test.example", password: "secret1", username: "author_one")
        try await backend.addPost(placeID: first, kind: .question, title: "SYNTHETIC Is there quiet seating?", body: "Asking for exam week.", parentID: nil)
        try await backend.addPost(placeID: second, kind: .visitNote, title: nil, body: "SYNTHETIC Plenty of outlets near the window.", parentID: nil)

        let mine = try await backend.recentThreads(kind: nil, limit: 50)
        XCTAssertEqual(mine.filter { $0.status == .pending }.count, 2, "Authors see their own pending threads")

        _ = try await backend.signUp(email: "reader@test.example", password: "secret1", username: "reader_one")
        let before = try await backend.recentThreads(kind: nil, limit: 50)
        XCTAssertFalse(before.contains { $0.status != .approved }, "Other people's pending threads stay private")

        try await approveAll(backend)
        _ = try await backend.signIn(email: "reader@test.example", password: "secret1")
        let after = try await backend.recentThreads(kind: nil, limit: 50)
        XCTAssertEqual(Array(after.prefix(2).map(\.body)), ["SYNTHETIC Plenty of outlets near the window.", "Asking for exam week."])
        XCTAssertEqual(Set(after.prefix(2).map(\.placeID)), [first, second])
        XCTAssertEqual(after.map(\.createdAt), after.map(\.createdAt).sorted(by: >), "Newest first")
        XCTAssertFalse(after.contains { $0.kind == .answer }, "Answers belong inside threads, not in the feed")
    }

    func testKindFilterRejectedThreadsAndAnswersNeedApproval() async throws {
        let backend = service()
        let place = catalog[0].id
        _ = try await backend.signUp(email: "asker@test.example", password: "secret1", username: "asker_one")
        try await backend.addPost(placeID: place, kind: .question, title: "SYNTHETIC Open late?", body: "Looking for evening study.", parentID: nil)
        try await backend.addPost(placeID: place, kind: .correction, title: nil, body: "SYNTHETIC The entrance moved.", parentID: nil)
        try await approveAll(backend)
        let correction = try await backend.recentThreads(kind: .correction, limit: 50).first { $0.body == "SYNTHETIC The entrance moved." }
        XCTAssertNotNil(correction)
        let questions = try await backend.recentThreads(kind: .question, limit: 50)
        XCTAssertTrue(questions.allSatisfy { $0.kind == .question })

        let question = try XCTUnwrap(questions.first { $0.title == "SYNTHETIC Open late?" })
        _ = try await backend.signUp(email: "answerer@test.example", password: "secret1", username: "answerer_one")
        try await backend.addPost(placeID: place, kind: .answer, title: nil, body: "SYNTHETIC Until 9pm on weekdays.", parentID: question.id)
        _ = try await backend.signUp(email: "lurker@test.example", password: "secret1", username: "lurker_one")
        let lurkerView = try await backend.recentThreads(kind: .question, limit: 50)
        let unanswered = try XCTUnwrap(lurkerView.first { $0.id == question.id })
        XCTAssertTrue(unanswered.replies.isEmpty, "A pending answer is not public")

        try await approveAll(backend)
        _ = try await backend.signIn(email: "lurker@test.example", password: "secret1")
        let afterApproval = try await backend.recentThreads(kind: .question, limit: 50)
        let answered = try XCTUnwrap(afterApproval.first { $0.id == question.id })
        XCTAssertEqual(answered.replies.map(\.body), ["SYNTHETIC Until 9pm on weekdays."])

        _ = try await backend.signUp(email: "spammer@test.example", password: "secret1", username: "spammer_one")
        try await backend.addPost(placeID: place, kind: .visitNote, title: nil, body: "SYNTHETIC buy followers", parentID: nil)
        _ = try await backend.signIn(email: InMemoryCommunityService.moderatorEmail, password: InMemoryCommunityService.testPassword)
        for post in try await backend.pendingPosts() { try await backend.moderatePost(id: post.id, decision: .rejected, note: "spam") }
        _ = try await backend.signIn(email: "lurker@test.example", password: "secret1")
        let finalFeed = try await backend.recentThreads(kind: nil, limit: 50)
        XCTAssertFalse(finalFeed.contains { $0.body == "SYNTHETIC buy followers" })
    }

    func testLimitCapsTheFeed() async throws {
        let capped = try await service().recentThreads(kind: nil, limit: 1)
        XCTAssertEqual(capped.count, 1)
    }
}

private extension PlacePost {
    /// Feed items are thread roots; answers only appear nested in `replies`.
    var parentIDForFeedCheck: UUID? { kind == .answer ? id : nil }
}
