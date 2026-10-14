import Foundation
import SwiftUI

/// Signed-in member state shared across screens. Server responses are the source of truth: nothing is
/// shown as saved until the backend accepts it.
@MainActor final class CommunityStore: ObservableObject {
    let service: any CommunityService
    /// On-device test backend (synthetic mode); enables the test-account switcher.
    let isTestBackend: Bool
    @Published private(set) var profile: CommunityProfile?
    @Published private(set) var isModerator = false
    @Published private(set) var likedIDs: Set<UUID> = []
    @Published private(set) var submissions: [SubmittedPlace] = []
    @Published var message: String?

    init(service: any CommunityService, isTestBackend: Bool) {
        self.service = service
        self.isTestBackend = isTestBackend
    }

    var isSignedIn: Bool { profile != nil }

    func restore() async {
        guard let id = await service.currentUserID() else { clear(); return }
        do {
            profile = try await service.profile(id)
            isModerator = try await service.isModerator()
            likedIDs = try await service.likedPlaceIDs()
            submissions = try await service.mySubmissions()
        } catch { message = error.localizedDescription }
    }

    private func clear() { profile = nil; isModerator = false; likedIDs = []; submissions = [] }

    @discardableResult
    func signUp(email: String, password: String, username: String) async -> Bool {
        await perform { _ = try await self.service.signUp(email: email, password: password, username: username) }
    }

    @discardableResult
    func signIn(email: String, password: String) async -> Bool {
        await perform { _ = try await self.service.signIn(email: email, password: password) }
    }

    func signOut() async { await service.signOut(); clear() }

    func submit(_ draft: PlaceSubmissionDraft) async -> SubmittedPlace? {
        do {
            let submitted = try await service.submitPlace(draft)
            submissions = try await service.mySubmissions()
            return submitted
        } catch { message = error.localizedDescription; return nil }
    }

    func refreshSubmissions() async {
        guard isSignedIn else { return }
        do { submissions = try await service.mySubmissions() } catch { message = error.localizedDescription }
    }

    func setLiked(_ placeID: UUID, liked: Bool) async -> Bool {
        do {
            try await service.setLiked(placeID: placeID, liked: liked)
            likedIDs = try await service.likedPlaceIDs()
            return true
        } catch { message = error.localizedDescription; return false }
    }

    /// Unliked places ranked by the categories of liked ones (see `Recommendations.rank`).
    func recommendations(from repository: any PlaceRepository) async -> [Place] {
        guard isSignedIn, !likedIDs.isEmpty else { return [] }
        var liked: [Place] = []
        for id in likedIDs.sorted(by: { $0.uuidString < $1.uuidString }).prefix(20) {
            if let place = try? await repository.getPlace(id) { liked.append(place) }
        }
        let intents = Set(liked.map { $0.category.intent })
        var pool: [Place] = []
        if let related = try? await repository.searchPlaces(ExploreQuery(intents: intents), cursor: nil, generation: 0) { pool += related.places }
        if let general = try? await repository.searchPlaces(ExploreQuery(), cursor: nil, generation: 0) { pool += general.places }
        var seen: Set<UUID> = []
        return Recommendations.rank(pool.filter { seen.insert($0.id).inserted }, liked: liked, limit: 5)
    }

    private func perform(_ work: @escaping () async throws -> Void) async -> Bool {
        do { try await work(); await restore(); return true }
        catch { message = error.localizedDescription; return false }
    }

    #if DEBUG
    /// Synthetic test accounts only; the live backend never exposes this.
    func useTestAccount(email: String) async {
        guard isTestBackend else { return }
        await signIn(email: email, password: InMemoryCommunityService.testPassword)
    }
    #endif
}

extension PlaceCategory {
    var intent: ExploreIntent {
        switch self {
        case .study, .all: .focus
        case .social: .meet
        case .relax: .unwind
        case .outdoors: .move
        case .other: .create
        }
    }
}
