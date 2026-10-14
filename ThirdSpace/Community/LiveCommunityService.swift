import Foundation

/// Supabase-backed community. Every rule the UI relies on is also enforced by RLS and the
/// `moderate_place` / `resolve_report` functions in `supabase/migrations`.
struct LiveCommunityService: CommunityService {
    let client: SupabaseClient

    private struct ProfileRow: Decodable, Sendable { let id: UUID; let username: String }
    private struct PlaceRow: Decodable, Sendable {
        let id: UUID; let name: String; let category: String; let description: String
        let latitude: Double; let longitude: Double; let address: String?; let status: String
        let submitted_by: UUID?; let decision_note: String?; let created_at: Date
        let submitter: ProfileRow?
    }
    private struct RatingRow: Decodable, Sendable { let user_id: UUID; let stars: Int }
    private struct ReviewRow: Decodable, Sendable { let id: UUID; let place_id: UUID; let body: String; let created_at: Date; let author: ProfileRow? }
    private struct PostRow: Decodable, Sendable { let id: UUID; let place_id: UUID; let parent_id: UUID?; let kind: String; let title: String?; let body: String; let status: String; let hidden: Bool; let created_at: Date; let author: ProfileRow? }
    private struct HelpfulVoteRow: Decodable, Sendable { let post_id: UUID; let user_id: UUID }
    private struct HelpfulSummaryRow: Decodable, Sendable { let post_id: UUID; let helpful_count: Int }
    private struct LikeRow: Decodable, Sendable { let place_id: UUID; let user_id: UUID }
    private struct FollowRow: Decodable, Sendable { let follower_id: UUID }
    private struct ReportRow: Decodable, Sendable { let id: UUID; let target_type: String; let target_id: UUID; let reason: String; let details: String; let created_at: Date }
    private struct Empty: Decodable, Sendable {}

    private static let placeColumns = "id,name,category,description,address,latitude,longitude,status,submitted_by,decision_note,created_at,submitter:profiles!places_submitted_by_fkey(id,username)"

    private func eq(_ column: String, _ value: CustomStringConvertible) -> URLQueryItem { URLQueryItem(name: column, value: "eq.\(value)") }

    private func requireUser() async throws -> UUID {
        guard try await client.validSession() != nil, let id = await client.userID else { throw CommunityError.signedOut }
        return id
    }

    private func submitted(_ row: PlaceRow) -> SubmittedPlace {
        SubmittedPlace(id: row.id, name: row.name, category: PlaceCategory(rawValue: row.category) ?? .other, description: row.description,
                       latitude: row.latitude, longitude: row.longitude, address: row.address, status: ModerationStatus(rawValue: row.status) ?? .pending,
                       submittedBy: row.submitted_by, decisionNote: row.decision_note, createdAt: row.created_at)
    }

    // MARK: Accounts

    func currentUserID() async -> UUID? {
        guard (try? await client.validSession()) != nil else { return nil }
        return await client.userID
    }

    func signUp(email: String, password: String, username: String) async throws -> CommunityProfile {
        guard username.range(of: #"^[A-Za-z0-9_]{3,24}$"#, options: .regularExpression) != nil else {
            throw CommunityError.invalidInput("Usernames use 3–24 letters, numbers or underscores.")
        }
        let session = try await client.signUp(email: email, password: password, username: username)
        return try await profile(session.userID) ?? CommunityProfile(id: session.userID, username: username)
    }

    func signIn(email: String, password: String) async throws -> CommunityProfile {
        let session = try await client.signIn(email: email, password: password)
        guard let profile = try await profile(session.userID) else { throw CommunityError.notFound }
        return profile
    }

    func signOut() async { await client.signOut() }

    func profile(_ id: UUID) async throws -> CommunityProfile? {
        try await client.select("profiles", query: [URLQueryItem(name: "select", value: "id,username"), eq("id", id)], as: ProfileRow.self)
            .rows.first.map { CommunityProfile(id: $0.id, username: $0.username) }
    }

    func isModerator() async throws -> Bool {
        guard await currentUserID() != nil else { return false }
        return try await client.rpcValue("is_moderator", as: Bool.self)
    }

    // MARK: Submissions & moderation

    func submitPlace(_ draft: PlaceSubmissionDraft) async throws -> SubmittedPlace {
        _ = try await requireUser()
        let valid = try draft.validated()
        // Status and submitter are forced server-side; sending them would be ignored.
        let rows: [PlaceRow] = try await client.insert("places", select: Self.placeColumns, [
            "name": valid.name, "category": valid.category.rawValue, "description": valid.description,
            "latitude": valid.location.latitude, "longitude": valid.location.longitude, "address": valid.address.formatted,
        ])
        guard let row = rows.first else { throw CommunityError.server("The submission was not confirmed.") }
        return submitted(row)
    }

    func mySubmissions() async throws -> [SubmittedPlace] {
        let user = try await requireUser()
        return try await client.select("places", query: [URLQueryItem(name: "select", value: Self.placeColumns), eq("submitted_by", user),
                                                         URLQueryItem(name: "order", value: "created_at.desc")], as: PlaceRow.self).rows.map(submitted)
    }

    func pendingSubmissions() async throws -> [SubmittedPlace] {
        guard try await isModerator() else { throw CommunityError.forbidden }
        return try await client.select("places", query: [URLQueryItem(name: "select", value: Self.placeColumns), eq("status", "pending"),
                                                         URLQueryItem(name: "order", value: "created_at.asc"), URLQueryItem(name: "limit", value: "100")],
                                       as: PlaceRow.self).rows.map(submitted)
    }

    func moderate(placeID: UUID, decision: ModerationStatus, note: String?) async throws {
        _ = try await requireUser()
        var body: [String: Any] = ["place_id": placeID.uuidString, "decision": decision.rawValue]
        if let note, !note.isEmpty { body["note"] = note }
        try await client.rpc("moderate_place", body)
    }

    func pendingPosts() async throws -> [PlacePost] {
        guard try await isModerator() else { throw CommunityError.forbidden }
        let rows = try await client.select("place_posts", query: [
            URLQueryItem(name: "select", value: "id,place_id,parent_id,kind,title,body,status,hidden,created_at,author:profiles!place_posts_author_id_fkey(id,username)"),
            eq("status", "pending"), URLQueryItem(name: "order", value: "created_at.asc"), URLQueryItem(name: "limit", value: "100")
        ], as: PostRow.self).rows
        return rows.compactMap { row in
            guard let author = row.author, let kind = CommunityPostKind(rawValue: row.kind) else { return nil }
            return PlacePost(id: row.id, placeID: row.place_id, kind: kind, title: row.title, body: row.body,
                             author: CommunityProfile(id: author.id, username: author.username), createdAt: row.created_at,
                             status: ModerationStatus(rawValue: row.status) ?? .pending, replies: [], helpfulCount: 0, markedHelpful: false)
        }
    }

    func moderatePost(id: UUID, decision: ModerationStatus, note: String?) async throws {
        _ = try await requireUser()
        guard decision != .pending else { throw CommunityError.invalidInput("Choose approve or reject.") }
        try await client.rpc("moderate_place_post", ["post_id": id.uuidString, "decision": decision.rawValue, "note": note ?? ""])
    }

    // MARK: Engagement

    func details(placeID: UUID) async throws -> PlaceCommunityDetails {
        let user = await currentUserID()
        async let place = client.select("places", query: [URLQueryItem(name: "select", value: Self.placeColumns), eq("id", placeID)], as: PlaceRow.self)
        async let ratings = client.select("ratings", query: [URLQueryItem(name: "select", value: "user_id,stars"), eq("place_id", placeID)], as: RatingRow.self)
        async let reviews = client.select("reviews", query: [URLQueryItem(name: "select", value: "id,place_id,body,created_at,author:profiles!reviews_author_id_fkey(id,username)"),
                                                             eq("place_id", placeID), URLQueryItem(name: "order", value: "created_at.desc")], as: ReviewRow.self)
        async let likes = client.select("likes", query: [URLQueryItem(name: "select", value: "place_id,user_id"), eq("place_id", placeID)], as: LikeRow.self)
        async let postResults = client.select("place_posts", query: [URLQueryItem(name: "select", value: "id,place_id,parent_id,kind,title,body,status,hidden,created_at,author:profiles!place_posts_author_id_fkey(id,username)"),
                                                                      eq("place_id", placeID), URLQueryItem(name: "order", value: "created_at.desc"), URLQueryItem(name: "limit", value: "200")], as: PostRow.self)
        let (placeRows, ratingRows, reviewRows, likeRows, postResult) = try await (place.rows, ratings.rows, reviews.rows, likes.rows, postResults)
        let row = placeRows.first
        let allPosts = postResult.rows.compactMap { row -> (PostRow, CommunityProfile, CommunityPostKind)? in
            guard let author = row.author, let kind = CommunityPostKind(rawValue: row.kind) else { return nil }
            return (row, CommunityProfile(id: author.id, username: author.username), kind)
        }
        let answerIDs = Array(Set(allPosts.filter { $0.2 == .answer }.map { $0.0.id })).prefix(200)
        let postFilter = "in.(\(answerIDs.map(\.uuidString).joined(separator: ",")))"
        let helpfulCounts: [HelpfulSummaryRow]
        let myHelpfulVotes: [HelpfulVoteRow]
        if answerIDs.isEmpty {
            helpfulCounts = []; myHelpfulVotes = []
        } else {
            helpfulCounts = try await client.select("place_post_helpful_summary", query: [
                URLQueryItem(name: "select", value: "post_id,helpful_count"), URLQueryItem(name: "post_id", value: postFilter)
            ], as: HelpfulSummaryRow.self).rows
            if let user {
                myHelpfulVotes = try await client.select("place_post_helpful_votes", query: [
                    URLQueryItem(name: "select", value: "post_id,user_id"), URLQueryItem(name: "post_id", value: postFilter), eq("user_id", user)
                ], as: HelpfulVoteRow.self).rows
            } else { myHelpfulVotes = [] }
        }
        let helpfulCountByPost = Dictionary(uniqueKeysWithValues: helpfulCounts.map { ($0.post_id, $0.helpful_count) })
        let myHelpfulPostIDs = Set(myHelpfulVotes.map(\.post_id))
        let roots = allPosts.filter { $0.0.parent_id == nil }
        let posts = roots.compactMap { root -> PlacePost? in
            let row = root.0
            guard !row.hidden, row.status == "approved" || root.1.id == user else { return nil }
            let replies = allPosts.filter { $0.0.parent_id == row.id && !$0.0.hidden && ($0.0.status == "approved" || $0.1.id == user) }.map { answer in
                return PlacePost(id: answer.0.id, placeID: answer.0.place_id, kind: answer.2, title: answer.0.title, body: answer.0.body,
                                 author: answer.1, createdAt: answer.0.created_at, status: ModerationStatus(rawValue: answer.0.status) ?? .pending,
                                 replies: [], helpfulCount: helpfulCountByPost[answer.0.id] ?? 0, markedHelpful: myHelpfulPostIDs.contains(answer.0.id))
            }.sorted { $0.createdAt < $1.createdAt }
            return PlacePost(id: row.id, placeID: row.place_id, kind: root.2, title: row.title, body: row.body,
                             author: root.1, createdAt: row.created_at, status: ModerationStatus(rawValue: row.status) ?? .pending,
                             replies: replies, helpfulCount: 0, markedHelpful: false)
        }
        return PlaceCommunityDetails(
            description: row?.description ?? "",
            submitter: row?.submitter.map { CommunityProfile(id: $0.id, username: $0.username) },
            rating: ratingRows.isEmpty ? nil : RatingSummary(average: Double(ratingRows.map(\.stars).reduce(0, +)) / Double(ratingRows.count), count: ratingRows.count),
            myRating: user.flatMap { id in ratingRows.first { $0.user_id == id }?.stars },
            liked: user.map { id in likeRows.contains { $0.user_id == id } } ?? false,
            likeCount: likeRows.count,
            reviews: reviewRows.compactMap { review in
                review.author.map { PlaceReview(id: review.id, placeID: review.place_id, author: CommunityProfile(id: $0.id, username: $0.username), body: review.body, createdAt: review.created_at) }
            }, posts: posts)
    }

    func rate(placeID: UUID, stars: Int) async throws {
        let user = try await requireUser()
        guard (1...5).contains(stars) else { throw CommunityError.invalidInput("Choose 1 to 5 stars.") }
        let _: [RatingRow] = try await client.insert("ratings", select: "user_id,stars",
                                                     ["place_id": placeID.uuidString, "user_id": user.uuidString, "stars": stars, "updated_at": ISO8601DateFormatter().string(from: Date())],
                                                     upsertOn: "place_id,user_id")
    }

    func addReview(placeID: UUID, body: String) async throws {
        _ = try await requireUser()
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...4000).contains(text.count) else { throw CommunityError.invalidInput("Write between 1 and 4,000 characters.") }
        let _: [Empty] = try await client.insert("reviews", select: "id", ["place_id": placeID.uuidString, "body": text])
    }

    func addPost(placeID: UUID, kind: CommunityPostKind, title: String?, body: String, parentID: UUID?) async throws {
        _ = try await requireUser()
        let text = body.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanTitle = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...4000).contains(text.count) else { throw CommunityError.invalidInput("Write between 1 and 4,000 characters.") }
        if kind == .question, !(1...160).contains(cleanTitle?.count ?? 0) { throw CommunityError.invalidInput("Questions need a title between 1 and 160 characters.") }
        if parentID == nil && kind == .answer { throw CommunityError.invalidInput("Answers need a question.") }
        if parentID != nil && kind != .answer { throw CommunityError.invalidInput("Choose answer for a reply.") }
        let postKind = parentID == nil ? kind.rawValue : "answer"
        var payload: [String: Any] = ["place_id": placeID.uuidString, "kind": postKind, "body": text]
        if let cleanTitle, parentID == nil { payload["title"] = cleanTitle }
        if let parentID { payload["parent_id"] = parentID.uuidString }
        let _: [Empty] = try await client.insert("place_posts", select: "id", payload)
    }

    func setPostHelpful(postID: UUID, helpful: Bool) async throws {
        let user = try await requireUser()
        if helpful {
            let _: [HelpfulVoteRow] = try await client.insert("place_post_helpful_votes", select: "post_id,user_id",
                                                              ["post_id": postID.uuidString, "user_id": user.uuidString], upsertOn: "post_id,user_id")
        } else {
            try await client.delete("place_post_helpful_votes", query: [eq("post_id", postID), eq("user_id", user)])
        }
    }

    func setLiked(placeID: UUID, liked: Bool) async throws {
        let user = try await requireUser()
        if liked {
            let _: [LikeRow] = try await client.insert("likes", select: "place_id,user_id", ["place_id": placeID.uuidString, "user_id": user.uuidString], upsertOn: "place_id,user_id")
        } else {
            try await client.delete("likes", query: [eq("place_id", placeID), eq("user_id", user)])
        }
    }

    func likedPlaceIDs() async throws -> Set<UUID> {
        let user = try await requireUser()
        return Set(try await client.select("likes", query: [URLQueryItem(name: "select", value: "place_id,user_id"), eq("user_id", user)], as: LikeRow.self).rows.map(\.place_id))
    }

    func setFollowing(userID: UUID, following: Bool) async throws {
        let user = try await requireUser()
        guard user != userID else { throw CommunityError.invalidInput("You can't follow yourself.") }
        if following {
            let _: [FollowRow] = try await client.insert("follows", select: "follower_id", ["follower_id": user.uuidString, "followee_id": userID.uuidString], upsertOn: "follower_id,followee_id")
        } else {
            try await client.delete("follows", query: [eq("follower_id", user), eq("followee_id", userID)])
        }
    }

    func isFollowing(userID: UUID) async throws -> Bool {
        let user = try await requireUser()
        return !(try await client.select("follows", query: [URLQueryItem(name: "select", value: "follower_id"), eq("follower_id", user), eq("followee_id", userID)], as: FollowRow.self).rows.isEmpty)
    }

    func followerCount(userID: UUID) async throws -> Int {
        try await client.select("follows", query: [URLQueryItem(name: "select", value: "follower_id"), eq("followee_id", userID), URLQueryItem(name: "limit", value: "1")],
                                count: true, as: FollowRow.self).total ?? 0
    }

    // MARK: Reports

    func report(_ target: ReportTarget, reason: ReportReason, details: String) async throws {
        _ = try await requireUser()
        let _: [Empty] = try await client.insert("reports", select: "id", ["target_type": target.type, "target_id": target.id.uuidString, "reason": reason.rawValue, "details": details])
    }

    func openReports() async throws -> [CommunityReport] {
        guard try await isModerator() else { throw CommunityError.forbidden }
        return try await client.select("reports", query: [URLQueryItem(name: "select", value: "id,target_type,target_id,reason,details,created_at"), eq("status", "open"),
                                                          URLQueryItem(name: "order", value: "created_at.asc")], as: ReportRow.self).rows.compactMap { row in
            let target: ReportTarget? = switch row.target_type { case "place": .place(row.target_id); case "review": .review(row.target_id); case "post": .post(row.target_id); case "profile": .profile(row.target_id); default: nil }
            return target.map { CommunityReport(id: row.id, target: $0, reason: ReportReason(rawValue: row.reason) ?? .other, details: row.details, createdAt: row.created_at) }
        }
    }

    func resolveReport(_ id: UUID, dismiss: Bool, hideReview: Bool) async throws {
        try await client.rpc("resolve_report", ["report_id": id.uuidString, "outcome": dismiss ? "dismissed" : "resolved", "hide_review": hideReview && !dismiss])
    }
}
