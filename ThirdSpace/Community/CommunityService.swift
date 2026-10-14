import Foundation

struct CommunityProfile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let username: String
}

enum ModerationStatus: String, Codable, Sendable { case pending, approved, rejected }

/// Street address typed by the member. It is plain text for moderators; it is never geocoded or looked up with a provider.
struct PlaceAddress: Codable, Hashable, Sendable {
    var street = ""
    var city = ""
    var region = ""
    var postalCode = ""
    var country = ""

    init(street: String = "", city: String = "", region: String = "", postalCode: String = "", country: String = "") {
        self.street = street; self.city = city; self.region = region; self.postalCode = postalCode; self.country = country
    }

    /// One line, e.g. "123 Main St, Los Angeles, CA 90012, United States". Empty parts are skipped.
    var formatted: String {
        let t = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines) }
        let regionPostal = [t(region), t(postalCode)].filter { !$0.isEmpty }.joined(separator: " ")
        return [t(street), t(city), regionPostal, t(country)].filter { !$0.isEmpty }.joined(separator: ", ")
    }

    func validated() throws -> PlaceAddress {
        let t = { (s: String) in s.trimmingCharacters(in: .whitespacesAndNewlines) }
        let clean = PlaceAddress(street: t(street), city: t(city), region: t(region), postalCode: t(postalCode), country: t(country))
        guard (3...120).contains(clean.street.count) else { throw CommunityError.invalidInput("Enter the street address, including the building number.") }
        guard (2...80).contains(clean.city.count) else { throw CommunityError.invalidInput("Enter the city or town.") }
        guard (2...80).contains(clean.country.count) else { throw CommunityError.invalidInput("Enter the country.") }
        guard clean.region.count <= 80, clean.postalCode.count <= 20 else { throw CommunityError.invalidInput("The state/region or postal code is too long.") }
        return clean
    }
}

struct PlaceSubmissionDraft: Sendable, Equatable {
    var name: String
    var category: PlaceCategory
    var description: String
    var location: GeoPoint
    var address: PlaceAddress

    /// Client-side checks mirror the database constraints so errors appear before a round trip.
    func validated() throws -> PlaceSubmissionDraft {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...120).contains(trimmed.count) else { throw CommunityError.invalidInput("Enter a name between 2 and 120 characters.") }
        guard category != .all else { throw CommunityError.invalidInput("Choose a category.") }
        guard description.count <= 2000 else { throw CommunityError.invalidInput("Keep the description under 2,000 characters.") }
        return PlaceSubmissionDraft(name: trimmed, category: category, description: description.trimmingCharacters(in: .whitespacesAndNewlines), location: location, address: try address.validated())
    }
}

struct SubmittedPlace: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let name: String
    let category: PlaceCategory
    let description: String
    let latitude: Double
    let longitude: Double
    /// One-line address typed by the submitter; nil for records created before addresses existed.
    let address: String?
    let status: ModerationStatus
    let submittedBy: UUID?
    let decisionNote: String?
    let createdAt: Date
}

struct PlaceReview: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let placeID: UUID
    let author: CommunityProfile
    let body: String
    let createdAt: Date
}

enum CommunityPostKind: String, Codable, CaseIterable, Sendable, Identifiable {
    case question, visitNote = "visit_note", correction, answer
    static var rootCases: [CommunityPostKind] { [.question, .visitNote, .correction] }
    var id: String { rawValue }
    var label: String {
        switch self {
        case .question: "Question"
        case .visitNote: "Visit note"
        case .correction: "Correction"
        case .answer: "Answer"
        }
    }
    var icon: String {
        switch self {
        case .question: "questionmark.bubble"
        case .visitNote: "text.bubble"
        case .correction: "pencil.line"
        case .answer: "arrowshape.turn.up.left"
        }
    }
}

struct PlacePost: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let placeID: UUID
    let kind: CommunityPostKind
    let title: String?
    let body: String
    let author: CommunityProfile
    let createdAt: Date
    let status: ModerationStatus
    let replies: [PlacePost]
    let helpfulCount: Int
    let markedHelpful: Bool
}

struct RatingSummary: Codable, Hashable, Sendable {
    let average: Double
    let count: Int
}

struct PlaceCommunityDetails: Sendable, Equatable {
    var description: String
    var submitter: CommunityProfile?
    var rating: RatingSummary?
    var myRating: Int?
    var liked: Bool
    var likeCount: Int
    var reviews: [PlaceReview]
    var posts: [PlacePost] = []
}

enum ReportTarget: Codable, Hashable, Sendable {
    case place(UUID), review(UUID), post(UUID), profile(UUID)

    var type: String { switch self { case .place: "place"; case .review: "review"; case .post: "post"; case .profile: "profile" } }
    var id: UUID { switch self { case .place(let id), .review(let id), .post(let id), .profile(let id): id } }
}

enum ReportReason: String, Codable, CaseIterable, Sendable {
    case spam, harassment, unsafe, inaccurate, privateProperty = "private_property", other

    var label: String {
        switch self {
        case .spam: "Spam or advertising"
        case .harassment: "Harassment or hate"
        case .unsafe: "Unsafe or dangerous"
        case .inaccurate: "Wrong or misleading information"
        case .privateProperty: "Private property or not open to the public"
        case .other: "Something else"
        }
    }
}

struct CommunityReport: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let target: ReportTarget
    let reason: ReportReason
    let details: String
    let createdAt: Date
}

/// Everything the community features need. Authorization is enforced by the backend; implementations
/// must not grant moderator power from client state.
protocol CommunityService: Sendable {
    func currentUserID() async -> UUID?
    func signUp(email: String, password: String, username: String) async throws -> CommunityProfile
    func signIn(email: String, password: String) async throws -> CommunityProfile
    func signOut() async
    func profile(_ id: UUID) async throws -> CommunityProfile?
    func isModerator() async throws -> Bool

    func submitPlace(_ draft: PlaceSubmissionDraft) async throws -> SubmittedPlace
    func mySubmissions() async throws -> [SubmittedPlace]
    func pendingSubmissions() async throws -> [SubmittedPlace]
    func moderate(placeID: UUID, decision: ModerationStatus, note: String?) async throws
    func pendingPosts() async throws -> [PlacePost]
    func moderatePost(id: UUID, decision: ModerationStatus, note: String?) async throws

    func details(placeID: UUID) async throws -> PlaceCommunityDetails
    func rate(placeID: UUID, stars: Int) async throws
    func addReview(placeID: UUID, body: String) async throws
    func addPost(placeID: UUID, kind: CommunityPostKind, title: String?, body: String, parentID: UUID?) async throws
    func setPostHelpful(postID: UUID, helpful: Bool) async throws
    func setLiked(placeID: UUID, liked: Bool) async throws
    func likedPlaceIDs() async throws -> Set<UUID>
    func setFollowing(userID: UUID, following: Bool) async throws
    func isFollowing(userID: UUID) async throws -> Bool
    func followerCount(userID: UUID) async throws -> Int

    func report(_ target: ReportTarget, reason: ReportReason, details: String) async throws
    func openReports() async throws -> [CommunityReport]
    func resolveReport(_ id: UUID, dismiss: Bool, hideReview: Bool) async throws
}

enum Recommendations {
    /// Ranks unliked places by how many of the user's liked places share their category, then by rating,
    /// then by name. Pure and deterministic so the "likes change recommendations" criterion is testable.
    static func rank(_ places: [Place], liked: [Place], ratings: [UUID: Double] = [:], limit: Int = 10) -> [Place] {
        let likedIDs = Set(liked.map(\.id))
        let affinity = Dictionary(liked.map { ($0.category, 1) }, uniquingKeysWith: +)
        return places
            .filter { !likedIDs.contains($0.id) }
            .sorted { lhs, rhs in
                let left = (affinity[lhs.category] ?? 0, ratings[lhs.id] ?? 0), right = (affinity[rhs.category] ?? 0, ratings[rhs.id] ?? 0)
                if left.0 != right.0 { return left.0 > right.0 }
                if left.1 != right.1 { return left.1 > right.1 }
                return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }
}
