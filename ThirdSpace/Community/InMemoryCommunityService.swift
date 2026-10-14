import Foundation

/// On-device stand-in for the Supabase backend, used for synthetic demos and tests only. It mirrors the
/// server rules (pending-only inserts, moderator-only decisions, no self-approval) and persists to one
/// file in the synthetic namespace so state survives navigation and relaunch.
actor InMemoryCommunityService: CommunityService {
    struct Account: Codable, Sendable { let email: String; let password: String; let profile: CommunityProfile }
    struct StoredRating: Codable, Sendable { let placeID: UUID; let userID: UUID; var stars: Int }
    struct StoredReview: Codable, Sendable { let id: UUID; let placeID: UUID; let authorID: UUID; let body: String; let createdAt: Date; var hidden: Bool }
    struct StoredPost: Codable, Sendable { let id: UUID; let placeID: UUID; let parentID: UUID?; let authorID: UUID; let kind: CommunityPostKind; let title: String?; let body: String; let createdAt: Date; var status: ModerationStatus; var hidden: Bool }
    struct StoredReport: Codable, Sendable { let id: UUID; let reporterID: UUID; let target: ReportTarget; let reason: ReportReason; let details: String; let createdAt: Date; var open: Bool }
    struct State: Codable, Sendable {
        var accounts: [Account] = []
        var moderatorIDs: Set<UUID> = []
        var signedIn: UUID?
        var submissions: [SubmittedPlace] = []
        var ratings: [StoredRating] = []
        var reviews: [StoredReview] = []
        var posts: [StoredPost] = []
        var helpfulVotes: [UUID: Set<UUID>] = [:]
        var likes: [UUID: Set<UUID>] = [:]       // user -> places
        var follows: [UUID: Set<UUID>] = [:]     // follower -> followees
        var reports: [StoredReport] = []
    }

    static let moderatorEmail = "moderator@synthetic.test"
    static let neighborEmail = "neighbor@synthetic.test"
    static let testPassword = "synthetic-password"

    private var state: State
    private let url: URL?
    private let catalogPlaceIDs: Set<UUID>

    init(url: URL?, catalogPlaces: [Place]) {
        self.url = url
        catalogPlaceIDs = Set(catalogPlaces.map(\.id))
        if let url, let stored = try? ProtectedFile.read(State.self, from: url, default: State()), !stored.accounts.isEmpty {
            state = stored
        } else {
            state = Self.seeded(catalogPlaces)
        }
    }

    /// Two visibly synthetic accounts: a moderator and a neighbour who has already reviewed a place.
    private static func seeded(_ places: [Place]) -> State {
        var state = State()
        let moderator = CommunityProfile(id: UUID(uuidString: "00000000-0000-0000-0002-000000000001")!, username: "SYNTHETIC_moderator")
        let neighbor = CommunityProfile(id: UUID(uuidString: "00000000-0000-0000-0002-000000000002")!, username: "SYNTHETIC_neighbor")
        state.accounts = [Account(email: moderatorEmail, password: testPassword, profile: moderator),
                          Account(email: neighborEmail, password: testPassword, profile: neighbor)]
        state.moderatorIDs = [moderator.id]
        if let first = places.first {
            state.reviews = [StoredReview(id: UUID(uuidString: "00000000-0000-0000-0003-000000000001")!, placeID: first.id, authorID: neighbor.id,
                                          body: "SYNTHETIC review — invented test text, not a real visit.", createdAt: Date(timeIntervalSince1970: 1_700_000_000), hidden: false)]
            state.ratings = [StoredRating(placeID: first.id, userID: neighbor.id, stars: 3)]
        }
        return state
    }

    private func persist() throws {
        guard let url else { return }
        try ProtectedFile.write(JSONEncoder().encode(state), to: url)
    }

    private func requireUser() throws -> UUID {
        guard let id = state.signedIn else { throw CommunityError.signedOut }
        return id
    }

    private func requireApproved(_ placeID: UUID) throws {
        guard catalogPlaceIDs.contains(placeID) || state.submissions.contains(where: { $0.id == placeID && $0.status == .approved }) else {
            throw CommunityError.notFound
        }
    }

    private func profileFor(_ id: UUID) -> CommunityProfile? { state.accounts.first { $0.profile.id == id }?.profile }

    /// Approved user submissions, merged into the public catalog by the synthetic place repository.
    func approvedPlaces() -> [Place] {
        state.submissions.filter { $0.status == .approved }.map { submission in
            Place(id: submission.id, approvedRevisionID: submission.id, name: submission.name, originalLanguage: "en",
                  category: submission.category, regionID: "community",
                  location: GeoPoint(latitude: submission.latitude, longitude: submission.longitude),
                  precision: .exactPublic, facts: [])
        }
    }

    // MARK: Accounts

    func currentUserID() -> UUID? { state.signedIn }

    func signUp(email: String, password: String, username: String) throws -> CommunityProfile {
        guard username.range(of: #"^[A-Za-z0-9_]{3,24}$"#, options: .regularExpression) != nil else {
            throw CommunityError.invalidInput("Usernames use 3–24 letters, numbers or underscores.")
        }
        guard password.count >= 6 else { throw CommunityError.invalidInput("Use a password of at least 6 characters.") }
        let normalized = email.lowercased()
        guard !state.accounts.contains(where: { $0.email == normalized || $0.profile.username.lowercased() == username.lowercased() }) else {
            throw CommunityError.invalidInput("That username or email is already in use.")
        }
        let profile = CommunityProfile(id: UUID(), username: username)
        state.accounts.append(Account(email: normalized, password: password, profile: profile))
        state.signedIn = profile.id
        try persist()
        return profile
    }

    func signIn(email: String, password: String) throws -> CommunityProfile {
        guard let account = state.accounts.first(where: { $0.email == email.lowercased() && $0.password == password }) else {
            throw CommunityError.invalidInput("Email or password is incorrect.")
        }
        state.signedIn = account.profile.id
        try persist()
        return account.profile
    }

    func signOut() { state.signedIn = nil; try? persist() }

    func profile(_ id: UUID) -> CommunityProfile? { profileFor(id) }

    func isModerator() -> Bool { state.signedIn.map { state.moderatorIDs.contains($0) } ?? false }

    // MARK: Submissions & moderation

    func submitPlace(_ draft: PlaceSubmissionDraft) throws -> SubmittedPlace {
        let user = try requireUser()
        let valid = try draft.validated()
        let submission = SubmittedPlace(id: UUID(), name: valid.name, category: valid.category, description: valid.description,
                                        latitude: valid.location.latitude, longitude: valid.location.longitude,
                                        address: valid.address.formatted, status: .pending, submittedBy: user, decisionNote: nil, createdAt: Date())
        state.submissions.append(submission)
        try persist()
        return submission
    }

    func mySubmissions() throws -> [SubmittedPlace] {
        let user = try requireUser()
        return state.submissions.filter { $0.submittedBy == user }.sorted { $0.createdAt > $1.createdAt }
    }

    func pendingSubmissions() throws -> [SubmittedPlace] {
        guard isModerator() else { throw CommunityError.forbidden }
        return state.submissions.filter { $0.status == .pending }.sorted { $0.createdAt < $1.createdAt }
    }

    func moderate(placeID: UUID, decision: ModerationStatus, note: String?) throws {
        let user = try requireUser()
        guard state.moderatorIDs.contains(user) else { throw CommunityError.forbidden }
        guard decision != .pending, let index = state.submissions.firstIndex(where: { $0.id == placeID && $0.status == .pending }) else { throw CommunityError.notFound }
        guard state.submissions[index].submittedBy != user else { throw CommunityError.invalidInput("Moderators can't decide their own submissions.") }
        let old = state.submissions[index]
        state.submissions[index] = SubmittedPlace(id: old.id, name: old.name, category: old.category, description: old.description,
                                                  latitude: old.latitude, longitude: old.longitude, address: old.address, status: decision,
                                                  submittedBy: old.submittedBy, decisionNote: note, createdAt: old.createdAt)
        try persist()
    }

    func pendingPosts() throws -> [PlacePost] {
        guard isModerator() else { throw CommunityError.forbidden }
        return state.posts.filter { $0.status == .pending }.sorted { $0.createdAt < $1.createdAt }.compactMap(postValue)
    }

    func moderatePost(id: UUID, decision: ModerationStatus, note: String?) throws {
        let user = try requireUser()
        guard state.moderatorIDs.contains(user) else { throw CommunityError.forbidden }
        guard decision != .pending, let index = state.posts.firstIndex(where: { $0.id == id && $0.status == .pending }) else { throw CommunityError.notFound }
        guard state.posts[index].authorID != user else { throw CommunityError.invalidInput("Moderators can't decide their own posts.") }
        state.posts[index].status = decision
        try persist()
    }

    // MARK: Engagement

    func details(placeID: UUID) throws -> PlaceCommunityDetails {
        let submission = state.submissions.first { $0.id == placeID }
        let ratings = state.ratings.filter { $0.placeID == placeID }
        let user = state.signedIn
        let reviews = state.reviews
            .filter { $0.placeID == placeID && (!$0.hidden || $0.authorID == user) }
            .sorted { $0.createdAt > $1.createdAt }
            .compactMap { review in profileFor(review.authorID).map { PlaceReview(id: review.id, placeID: placeID, author: $0, body: review.body, createdAt: review.createdAt) } }
        let visiblePosts = state.posts.filter {
            $0.placeID == placeID && !$0.hidden && ($0.status == .approved || $0.authorID == user)
        }
        let roots = visiblePosts.filter { $0.parentID == nil }.sorted { $0.createdAt > $1.createdAt }
        let posts = roots.compactMap { root -> PlacePost? in
            guard let author = profileFor(root.authorID) else { return nil }
            let replies = visiblePosts.filter { $0.parentID == root.id }.sorted { $0.createdAt < $1.createdAt }.compactMap { postValue($0) }
            return PlacePost(id: root.id, placeID: root.placeID, kind: root.kind, title: root.title, body: root.body,
                             author: author, createdAt: root.createdAt, status: root.status, replies: replies,
                             helpfulCount: 0, markedHelpful: false)
        }
        return PlaceCommunityDetails(
            description: submission?.description ?? "",
            submitter: submission?.submittedBy.flatMap(profileFor),
            rating: ratings.isEmpty ? nil : RatingSummary(average: Double(ratings.map(\.stars).reduce(0, +)) / Double(ratings.count), count: ratings.count),
            myRating: user.flatMap { id in ratings.first { $0.userID == id }?.stars },
            liked: user.map { state.likes[$0, default: []].contains(placeID) } ?? false,
            likeCount: state.likes.values.filter { $0.contains(placeID) }.count,
            reviews: reviews, posts: posts)
    }

    private func postValue(_ post: StoredPost) -> PlacePost? {
        guard let author = profileFor(post.authorID) else { return nil }
        let votes = state.helpfulVotes[post.id, default: []]
        return PlacePost(id: post.id, placeID: post.placeID, kind: post.kind, title: post.title, body: post.body,
                         author: author, createdAt: post.createdAt, status: post.status, replies: [],
                         helpfulCount: votes.count, markedHelpful: state.signedIn.map(votes.contains) ?? false)
    }

    func rate(placeID: UUID, stars: Int) throws {
        let user = try requireUser()
        try requireApproved(placeID)
        guard (1...5).contains(stars) else { throw CommunityError.invalidInput("Choose 1 to 5 stars.") }
        if let index = state.ratings.firstIndex(where: { $0.placeID == placeID && $0.userID == user }) { state.ratings[index].stars = stars }
        else { state.ratings.append(StoredRating(placeID: placeID, userID: user, stars: stars)) }
        try persist()
    }

    func addReview(placeID: UUID, body: String) throws {
        let user = try requireUser()
        try requireApproved(placeID)
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...4000).contains(text.count) else { throw CommunityError.invalidInput("Write between 1 and 4,000 characters.") }
        state.reviews.append(StoredReview(id: UUID(), placeID: placeID, authorID: user, body: text, createdAt: Date(), hidden: false))
        try persist()
    }

    func addPost(placeID: UUID, kind: CommunityPostKind, title: String?, body: String, parentID: UUID?) throws {
        let user = try requireUser()
        try requireApproved(placeID)
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...4000).contains(text.count) else { throw CommunityError.invalidInput("Write between 1 and 4,000 characters.") }
        if let parentID {
            guard kind == .answer, let parent = state.posts.first(where: { $0.id == parentID }),
                  parent.placeID == placeID, parent.parentID == nil, parent.kind == .question,
                  parent.status == .approved, !parent.hidden else { throw CommunityError.notFound }
            state.posts.append(StoredPost(id: UUID(), placeID: placeID, parentID: parentID, authorID: user, kind: .answer,
                                          title: nil, body: text, createdAt: Date(), status: .pending, hidden: false))
        } else {
            if kind == .question {
                guard let trimmedTitle, (1...160).contains(trimmedTitle.count) else {
                    throw CommunityError.invalidInput("Questions need a title between 1 and 160 characters.")
                }
            } else if kind != .visitNote && kind != .correction {
                throw CommunityError.invalidInput("Choose a post type.")
            }
            state.posts.append(StoredPost(id: UUID(), placeID: placeID, parentID: nil, authorID: user, kind: kind,
                                          title: kind == .question ? trimmedTitle : nil, body: text, createdAt: Date(), status: .pending, hidden: false))
        }
        try persist()
    }

    func setPostHelpful(postID: UUID, helpful: Bool) throws {
        let user = try requireUser()
        guard let post = state.posts.first(where: { item in
            item.id == postID && item.kind == .answer && item.status == .approved && !item.hidden
        }) else { throw CommunityError.notFound }
        guard post.authorID != user else { throw CommunityError.notFound }
        if helpful { state.helpfulVotes[postID, default: []].insert(user) }
        else { state.helpfulVotes[postID]?.remove(user) }
        try persist()
    }

    func setLiked(placeID: UUID, liked: Bool) throws {
        let user = try requireUser()
        try requireApproved(placeID)
        if liked { state.likes[user, default: []].insert(placeID) } else { state.likes[user]?.remove(placeID) }
        try persist()
    }

    func likedPlaceIDs() throws -> Set<UUID> { state.likes[try requireUser()] ?? [] }

    func setFollowing(userID: UUID, following: Bool) throws {
        let user = try requireUser()
        guard user != userID else { throw CommunityError.invalidInput("You can't follow yourself.") }
        guard profileFor(userID) != nil else { throw CommunityError.notFound }
        if following { state.follows[user, default: []].insert(userID) } else { state.follows[user]?.remove(userID) }
        try persist()
    }

    func isFollowing(userID: UUID) throws -> Bool { state.follows[try requireUser(), default: []].contains(userID) }

    func followerCount(userID: UUID) -> Int { state.follows.values.filter { $0.contains(userID) }.count }

    // MARK: Reports

    func report(_ target: ReportTarget, reason: ReportReason, details: String) throws {
        let user = try requireUser()
        guard details.count <= 1000 else { throw CommunityError.invalidInput("Keep details under 1,000 characters.") }
        state.reports.append(StoredReport(id: UUID(), reporterID: user, target: target, reason: reason, details: details, createdAt: Date(), open: true))
        try persist()
    }

    func openReports() throws -> [CommunityReport] {
        guard isModerator() else { throw CommunityError.forbidden }
        return state.reports.filter(\.open).map { CommunityReport(id: $0.id, target: $0.target, reason: $0.reason, details: $0.details, createdAt: $0.createdAt) }
    }

    func resolveReport(_ id: UUID, dismiss: Bool, hideReview: Bool) throws {
        guard isModerator() else { throw CommunityError.forbidden }
        guard let index = state.reports.firstIndex(where: { $0.id == id && $0.open }) else { throw CommunityError.notFound }
        state.reports[index].open = false
        if hideReview, !dismiss, case .review(let reviewID) = state.reports[index].target,
           let reviewIndex = state.reviews.firstIndex(where: { $0.id == reviewID }) {
            state.reviews[reviewIndex].hidden = true
        }
        if hideReview, !dismiss, case .post(let postID) = state.reports[index].target,
           let postIndex = state.posts.firstIndex(where: { $0.id == postID }) {
            state.posts[postIndex].hidden = true
        }
        try persist()
    }
}
