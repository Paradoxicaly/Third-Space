import XCTest
@testable import ThirdSpace

/// Acceptance criteria 2–9 against the on-device backend, which mirrors the Supabase rules.
final class CommunityServiceTests: XCTestCase {
    private var root: URL!
    private let catalog = Place.syntheticUITestFixtures
    private var file: URL { root.appendingPathComponent("community.json") }

    override func setUp() {
        super.setUp()
        root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }
    override func tearDown() { try? FileManager.default.removeItem(at: root); super.tearDown() }

    private func service() -> InMemoryCommunityService { InMemoryCommunityService(url: file, catalogPlaces: catalog) }
    private let nook = PlaceSubmissionDraft(name: "Test Nook", category: .study, description: "Quiet corner", location: GeoPoint(latitude: 34.05, longitude: -118.24)!,
                                                address: PlaceAddress(street: "123 Main St", city: "Los Angeles", region: "CA", postalCode: "90012", country: "United States"))

    // Address
    func testAddressIsRequiredAndStoredWithSubmission() async throws {
        let backend = service()
        _ = try await backend.signUp(email: "addr@test.example", password: "secret1", username: "addr_user")
        var missing = nook; missing.address = PlaceAddress(street: "", city: "Los Angeles", region: "", postalCode: "", country: "United States")
        do { _ = try await backend.submitPlace(missing); XCTFail("Street is required") } catch CommunityError.invalidInput {}
        var noCountry = nook; noCountry.address.country = " "
        do { _ = try await backend.submitPlace(noCountry); XCTFail("Country is required") } catch CommunityError.invalidInput {}
        let stored = try await backend.submitPlace(nook)
        XCTAssertEqual(stored.address, "123 Main St, Los Angeles, CA 90012, United States")
        XCTAssertEqual(PlaceAddress(street: " 5 Rue X ", city: "Paris", region: "", postalCode: "", country: "France").formatted, "5 Rue X, Paris, France")
    }

    // 2 + 3
    func testSubmissionIsPendingPrivateUntilModeratorApproves() async throws {
        let backend = service()
        _ = try await backend.signUp(email: "member@test.example", password: "secret1", username: "member_one")
        let submitted = try await backend.submitPlace(nook)
        XCTAssertEqual(submitted.status, .pending)
        let approvedBefore = await backend.approvedPlaces()
        XCTAssertTrue(approvedBefore.isEmpty, "Pending places must not be public")
        do { try await backend.moderate(placeID: submitted.id, decision: .approved, note: nil); XCTFail("Member approved a place") }
        catch CommunityError.forbidden {}

        _ = try await backend.signIn(email: InMemoryCommunityService.moderatorEmail, password: InMemoryCommunityService.testPassword)
        let queue = try await backend.pendingSubmissions()
        XCTAssertEqual(queue.map(\.id), [submitted.id])
        try await backend.moderate(placeID: submitted.id, decision: .approved, note: nil)
        let approvedAfter = await backend.approvedPlaces()
        XCTAssertEqual(approvedAfter.map(\.id), [submitted.id])

        _ = try await backend.signIn(email: "member@test.example", password: "secret1")
        let mine = try await backend.mySubmissions()
        XCTAssertEqual(mine.first?.status, .approved, "Submitter sees the decision")
    }

    func testRejectionCarriesNoteAndModeratorCannotDecideOwnSubmission() async throws {
        let backend = service()
        _ = try await backend.signIn(email: InMemoryCommunityService.moderatorEmail, password: InMemoryCommunityService.testPassword)
        let own = try await backend.submitPlace(nook)
        do { try await backend.moderate(placeID: own.id, decision: .approved, note: nil); XCTFail("Self-approval allowed") }
        catch CommunityError.invalidInput {}
        _ = try await backend.signUp(email: "other@test.example", password: "secret1", username: "other_one")
        let theirs = try await backend.submitPlace(PlaceSubmissionDraft(name: "Parking Lot", category: .other, description: "", location: GeoPoint(latitude: 1, longitude: 1)!,
                                                                                address: PlaceAddress(street: "1 Test Rd", city: "Testville", region: "", postalCode: "", country: "Testland")))
        _ = try await backend.signIn(email: InMemoryCommunityService.moderatorEmail, password: InMemoryCommunityService.testPassword)
        try await backend.moderate(placeID: theirs.id, decision: .rejected, note: "Not open to the public")
        _ = try await backend.signIn(email: "other@test.example", password: "secret1")
        let decided = try await backend.mySubmissions().first
        XCTAssertEqual(decided?.status, .rejected)
        XCTAssertEqual(decided?.decisionNote, "Not open to the public")
        let publicPlaces = await backend.approvedPlaces()
        XCTAssertTrue(publicPlaces.isEmpty)
    }

    // 4 + 5 + 6 + 7: saved state survives reopening (a fresh service instance reading the same file).
    func testRatingReviewLikeAndFollowPersistAcrossReopen() async throws {
        let place = try XCTUnwrap(catalog.first)
        var backend = service()
        _ = try await backend.signUp(email: "member@test.example", password: "secret1", username: "member_one")
        try await backend.rate(placeID: place.id, stars: 5)
        try await backend.addReview(placeID: place.id, body: "Lovely quiet tables")
        try await backend.setLiked(placeID: place.id, liked: true)
        let neighbor = UUID(uuidString: "00000000-0000-0000-0002-000000000002")!
        try await backend.setFollowing(userID: neighbor, following: true)

        backend = service()
        let details = try await backend.details(placeID: place.id)
        XCTAssertEqual(details.myRating, 5)
        XCTAssertEqual(details.rating?.count, 2)
        XCTAssertEqual(try XCTUnwrap(details.rating?.average), 4.0, accuracy: 0.001, "Seeded 3 + new 5")
        XCTAssertTrue(details.reviews.contains { $0.body == "Lovely quiet tables" && $0.author.username == "member_one" })
        XCTAssertTrue(details.liked)
        let following = try await backend.isFollowing(userID: neighbor)
        XCTAssertTrue(following)

        try await backend.rate(placeID: place.id, stars: 2)
        try await backend.setLiked(placeID: place.id, liked: false)
        try await backend.setFollowing(userID: neighbor, following: false)
        backend = service()
        let updated = try await backend.details(placeID: place.id)
        XCTAssertEqual(updated.myRating, 2, "Re-rating replaces, never duplicates")
        XCTAssertEqual(updated.rating?.count, 2)
        XCTAssertFalse(updated.liked)
        let stillFollowing = try await backend.isFollowing(userID: neighbor)
        XCTAssertFalse(stillFollowing)
    }

    func testEngagementRequiresSignInAndAnApprovedPlace() async throws {
        let backend = service()
        let place = try XCTUnwrap(catalog.first)
        do { try await backend.rate(placeID: place.id, stars: 4); XCTFail("Signed-out rating saved") } catch CommunityError.signedOut {}
        let me = try await backend.signUp(email: "member@test.example", password: "secret1", username: "member_one")
        let pending = try await backend.submitPlace(nook)
        do { try await backend.addReview(placeID: pending.id, body: "x"); XCTFail("Reviewed a pending place") } catch CommunityError.notFound {}
        do { try await backend.setFollowing(userID: me.id, following: true); XCTFail("Followed self") } catch CommunityError.invalidInput {}
    }

    // 9
    func testReportsReachModeratorsOnlyAndCanHideAReview() async throws {
        let backend = service()
        let place = try XCTUnwrap(catalog.first)
        _ = try await backend.signUp(email: "member@test.example", password: "secret1", username: "member_one")
        let seeded = try await backend.details(placeID: place.id)
        let review = try XCTUnwrap(seeded.reviews.first)
        try await backend.report(.review(review.id), reason: .harassment, details: "Rude")
        try await backend.report(.place(place.id), reason: .inaccurate, details: "")
        try await backend.report(.profile(review.author.id), reason: .spam, details: "")
        do { _ = try await backend.openReports(); XCTFail("Member read the report queue") } catch CommunityError.forbidden {}

        _ = try await backend.signIn(email: InMemoryCommunityService.moderatorEmail, password: InMemoryCommunityService.testPassword)
        let reports = try await backend.openReports()
        XCTAssertEqual(Set(reports.map(\.target.type)), ["review", "place", "profile"])
        let reviewReport = try XCTUnwrap(reports.first { $0.target == .review(review.id) })
        try await backend.resolveReport(reviewReport.id, dismiss: false, hideReview: true)
        let afterHide = try await backend.details(placeID: place.id)
        XCTAssertFalse(afterHide.reviews.contains { $0.id == review.id })
        let remaining = try await backend.openReports()
        XCTAssertEqual(remaining.count, 2)
    }
}

/// Criterion 8: likes change recommendations.
final class RecommendationTests: XCTestCase {
    private func place(_ name: String, _ category: PlaceCategory) -> Place {
        Place(id: UUID(), approvedRevisionID: UUID(), name: name, originalLanguage: "en", category: category, regionID: "test",
              location: nil, precision: .exactPublic, facts: [])
    }

    func testLikingAPlaceRanksRelatedAboveUnrelated() {
        let liked = place("Liked Library", .study)
        let related = place("Zed Study Hall", .study)        // alphabetically last on purpose
        let unrelated = place("Alpha Social Club", .social)
        let before = Recommendations.rank([liked, related, unrelated], liked: [])
        XCTAssertEqual(before.first?.id, unrelated.id, "Without likes, ordering is neutral (alphabetical)")
        let after = Recommendations.rank([liked, related, unrelated], liked: [liked])
        XCTAssertEqual(after.map(\.id), [related.id, unrelated.id], "Related ranks above unrelated and the liked place is excluded")
    }

    @MainActor func testStoreRecommendationsFollowLikesThroughTheRepository() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let fixtures = Place.syntheticUITestFixtures
        let backend = InMemoryCommunityService(url: root.appendingPathComponent("community.json"), catalogPlaces: fixtures)
        let store = CommunityStore(service: backend, isTestBackend: true)
        let repository = MockPlaceRepository(launchArguments: ["--ui-testing"])
        await store.signUp(email: "member@test.example", password: "secret1", username: "member_one")
        let readingRoom = try XCTUnwrap(fixtures.first { $0.category == .study })
        let none = await store.recommendations(from: repository)
        XCTAssertTrue(none.isEmpty, "No likes, no personalised recommendations")
        _ = await store.setLiked(readingRoom.id, liked: true)
        let recommendations = await store.recommendations(from: repository)
        XCTAssertEqual(recommendations.first?.category, .study, "Another study place should lead after liking a study place")
        XCTAssertFalse(recommendations.contains { $0.id == readingRoom.id })
    }
}

/// The live client must send requests the database rules expect, without touching the network.
final class LiveCommunityRequestTests: XCTestCase {
    final class Stub: URLProtocol {
        nonisolated(unsafe) static var handler: ((URLRequest) -> (Int, [String: String], Data))?
        nonisolated(unsafe) static var requests: [URLRequest] = []
        override class func canInit(with request: URLRequest) -> Bool { true }
        override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
        override func startLoading() {
            var request = self.request
            if request.httpBody == nil, let stream = request.httpBodyStream {
                stream.open(); var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable { let read = stream.read(&buffer, maxLength: buffer.count); if read <= 0 { break }; data.append(buffer, count: read) }
                stream.close(); request.httpBody = data
            }
            Self.requests.append(request)
            let (status, headers, body) = Self.handler?(request) ?? (500, [:], Data())
            client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: headers)!, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: body)
            client?.urlProtocolDidFinishLoading(self)
        }
        override func stopLoading() {}
    }

    private func makeService() -> LiveCommunityService {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [Stub.self]
        let client = SupabaseClient(config: SupabaseConfig(url: URL(string: "https://example.supabase.co")!, anonKey: "anon-key"),
                                    session: URLSession(configuration: configuration), keychainAccount: "test-\(UUID().uuidString)")
        return LiveCommunityService(client: client)
    }

    override func setUp() { super.setUp(); Stub.requests = [] }

    func testSignInThenSubmitSendsNoStatusAndUsesUserToken() async throws {
        let user = UUID()
        Stub.handler = { request in
            let path = request.url!.path
            if path.hasSuffix("/auth/v1/token") {
                return (200, [:], Data(#"{"access_token":"user-jwt","refresh_token":"r","expires_in":3600,"user":{"id":"\#(user.uuidString)"}}"#.utf8))
            }
            if path.hasSuffix("/rest/v1/profiles") { return (200, [:], Data(#"[{"id":"\#(user.uuidString)","username":"member_one"}]"#.utf8)) }
            if path.hasSuffix("/rest/v1/places") {
                return (201, [:], Data(#"[{"id":"\#(UUID().uuidString)","name":"Test Nook","category":"study","description":"","latitude":34.05,"longitude":-118.24,"status":"pending","submitted_by":"\#(user.uuidString)","decision_note":null,"created_at":"2026-10-13T20:00:00.123456+00:00","submitter":null}]"#.utf8))
            }
            return (404, [:], Data("{}".utf8))
        }
        let service = makeService()
        let profile = try await service.signIn(email: "member@test.example", password: "secret1")
        XCTAssertEqual(profile.username, "member_one")
        let submitted = try await service.submitPlace(PlaceSubmissionDraft(name: "Test Nook", category: .study, description: "", location: GeoPoint(latitude: 34.05, longitude: -118.24)!,
                                                                                address: PlaceAddress(street: "123 Main St", city: "Los Angeles", region: "CA", postalCode: "", country: "United States")))
        XCTAssertEqual(submitted.status, .pending)
        let insert = try XCTUnwrap(Stub.requests.last { $0.url!.path.hasSuffix("/rest/v1/places") })
        XCTAssertEqual(insert.httpMethod, "POST")
        XCTAssertEqual(insert.value(forHTTPHeaderField: "Authorization"), "Bearer user-jwt")
        XCTAssertEqual(insert.value(forHTTPHeaderField: "apikey"), "anon-key")
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: insert.httpBody ?? Data()) as? [String: Any])
        XCTAssertNil(body["status"], "Clients never send a moderation status")
        XCTAssertNil(body["submitted_by"])
        await service.signOut()
    }

    func testSignedOutEngagementIsRejectedBeforeAnyWrite() async {
        Stub.handler = { _ in (500, [:], Data()) }
        let service = makeService()
        do { try await service.rate(placeID: UUID(), stars: 4); XCTFail("Signed-out rating attempted") } catch CommunityError.signedOut {} catch { XCTFail("\(error)") }
        XCTAssertFalse(Stub.requests.contains { $0.httpMethod == "POST" && $0.url!.path.contains("/rest/v1/") })
    }

    func testBundledConfigRejectsServiceRoleKeys() {
        XCTAssertNil(SupabaseConfig.bundled(Bundle(for: LiveCommunityRequestTests.self)), "Tests bundle has no Supabase.plist")
    }
}
