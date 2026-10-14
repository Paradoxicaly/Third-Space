import SwiftUI

@MainActor final class PlaceCommunityModel: ObservableObject {
    @Published private(set) var details: PlaceCommunityDetails?
    @Published var error: String?
    @Published private(set) var working = false
    let placeID: UUID
    private let community: CommunityStore

    init(placeID: UUID, community: CommunityStore) {
        self.placeID = placeID
        self.community = community
    }

    func load() async {
        do { details = try await community.service.details(placeID: placeID); error = nil }
        catch { self.error = error.localizedDescription }
    }

    func rate(_ stars: Int) async { await run { try await self.community.service.rate(placeID: self.placeID, stars: stars) } }

    func toggleLike() async {
        guard let liked = details?.liked else { return }
        working = true
        if await community.setLiked(placeID, liked: !liked) { await load() } else { error = community.message }
        working = false
    }

    func post(kind: CommunityPostKind, title: String?, body: String) async -> Bool {
        await run { try await self.community.service.addPost(placeID: self.placeID, kind: kind, title: title, body: body, parentID: nil) }
    }

    func postReview(_ body: String) async -> Bool { await run { try await self.community.service.addReview(placeID: self.placeID, body: body) } }

    func answer(_ questionID: UUID, body: String) async -> Bool {
        await run { try await self.community.service.addPost(placeID: self.placeID, kind: .answer, title: nil, body: body, parentID: questionID) }
    }

    func helpful(_ answer: PlacePost) async {
        await run { try await self.community.service.setPostHelpful(postID: answer.id, helpful: !answer.markedHelpful) }
    }

    @discardableResult
    private func run(_ work: @escaping () async throws -> Void) async -> Bool {
        working = true
        defer { working = false }
        do { try await work(); await load(); return true }
        catch { self.error = error.localizedDescription; return false }
    }
}

/// Ratings, likes and reviews for one approved place. Everything shown comes back from the backend.
struct PlaceCommunitySection: View {
    let place: Place
    @ObservedObject var community: CommunityStore
    @StateObject private var model: PlaceCommunityModel
    @State private var draft = ""
    @State private var postTitle = ""
    @State private var postBody = ""
    @State private var postKind: CommunityPostKind = .question
    @State private var selectedPostKind = "all"
    @State private var replyingTo: UUID?
    @State private var replyDraft = ""
    @State private var showingAccount = false
    @State private var reportTarget: ReportTarget?

    init(place: Place, community: CommunityStore) {
        self.place = place
        self.community = community
        _model = StateObject(wrappedValue: PlaceCommunityModel(placeID: place.id, community: community))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: FieldGuide.Spacing.base) {
            Text("Community").font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
            if let details = model.details {
                if !details.description.isEmpty { Text(details.description) }
                if let submitter = details.submitter {
                    NavigationLink { UserProfileView(profile: submitter, community: community) } label: {
                        Label("Submitted by @\(submitter.username)", systemImage: "person")
                    }
                }
                summary(details)
                if community.isSignedIn { actions(details) } else {
                    Button("Sign in to rate, like or review") { showingAccount = true }.frame(minHeight: 44)
                }
                posts(details)
                reviews(details)
            } else if let error = model.error {
                Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(FieldGuide.Palette.warning)
                Button("Retry") { Task { await model.load() } }.frame(minHeight: 44)
            } else {
                ProgressView("Loading community…")
            }
            if let error = model.error, model.details != nil {
                Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(FieldGuide.Palette.destructive)
                    .accessibilityIdentifier("community-error")
            }
            if community.isSignedIn {
                Button { reportTarget = .place(place.id) } label: { Label("Report this place", systemImage: "flag") }
                    .frame(minHeight: 44).accessibilityIdentifier("report-place")
            }
        }
        .task(id: community.profile?.id) { await model.load() }
        .sheet(isPresented: $showingAccount) { AccountView(community: community) }
        .sheet(item: $reportTarget) { ReportSheet(target: $0, community: community) }
    }

    private func posts(_ details: PlaceCommunityDetails) -> some View {
        VStack(alignment: .leading, spacing: FieldGuide.Spacing.sm) {
            Text("Questions & field notes").font(.headline).accessibilityAddTraits(.isHeader)
            Picker("Filter posts", selection: $selectedPostKind) {
                Text("All types").tag("all")
                ForEach(CommunityPostKind.rootCases) { kind in Text(kind.label).tag(kind.rawValue) }
            }
            .pickerStyle(.menu)
            .accessibilityIdentifier("filter-place-posts")
            if community.isSignedIn {
                VStack(alignment: .leading, spacing: FieldGuide.Spacing.xs) {
                    Picker("Post type", selection: $postKind) {
                        ForEach(CommunityPostKind.rootCases) { kind in Label(kind.label, systemImage: kind.icon).tag(kind) }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("place-post-kind")
                    if postKind == .question {
                        TextField("Question title", text: $postTitle)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("place-post-title")
                    }
                    TextField(postKind == .question ? "Add context" : "Share a practical note", text: $postBody, axis: .vertical)
                        .lineLimit(2...6)
                        .padding(12)
                        .background(FieldGuide.Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FieldGuide.Palette.controlBorder, lineWidth: 1))
                        .accessibilityIdentifier("place-post-body")
                    Button("Submit for review") {
                        Task {
                            if await model.post(kind: postKind, title: postTitle, body: postBody) {
                                postTitle = ""; postBody = ""
                            }
                        }
                    }
                    .frame(minHeight: 44)
                    .disabled(model.working || postBody.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || (postKind == .question && postTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                    .accessibilityIdentifier("submit-place-post")
                }
                .padding(FieldGuide.Spacing.sm)
                .background(FieldGuide.Palette.surface, in: RoundedRectangle(cornerRadius: 12))
            } else {
                Button("Sign in to ask or share a field note") { showingAccount = true }.frame(minHeight: 44)
            }
            let visiblePosts = selectedPostKind == "all" ? details.posts : details.posts.filter { $0.kind.rawValue == selectedPostKind }
            if visiblePosts.isEmpty {
                Text(selectedPostKind == "all" ? "No questions or field notes yet." : "No \(CommunityPostKind(rawValue: selectedPostKind)?.label.lowercased() ?? "") posts yet.")
                    .foregroundStyle(FieldGuide.Palette.secondary)
            }
            ForEach(visiblePosts) { post in
                VStack(alignment: .leading, spacing: FieldGuide.Spacing.sm) {
                    HStack {
                        Label(post.kind.label, systemImage: post.kind.icon).font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(post.createdAt.formatted(date: .abbreviated, time: .omitted)).font(.footnote).foregroundStyle(FieldGuide.Palette.secondary)
                    }
                    if let title = post.title { Text(title).font(.subheadline.weight(.semibold)) }
                    Text(post.body)
                    HStack {
                        Text("@\(post.author.username)").font(.footnote.weight(.semibold))
                        if post.status == .pending {
                            Label("Pending review", systemImage: "clock").font(.footnote).foregroundStyle(FieldGuide.Palette.warning)
                        } else if post.status == .rejected {
                            Label("Not approved", systemImage: "xmark.circle").font(.footnote).foregroundStyle(FieldGuide.Palette.destructive)
                        }
                        Spacer()
                        if community.isSignedIn && post.author.id != community.profile?.id {
                            Button { reportTarget = .post(post.id) } label: { Image(systemName: "flag").frame(minWidth: 44, minHeight: 44) }
                                .accessibilityLabel("Report post by \(post.author.username)")
                        }
                    }
                    if post.kind == .question, post.status == .approved, community.isSignedIn {
                        Button(replyingTo == post.id ? "Cancel answer" : "Answer question") {
                            replyingTo = replyingTo == post.id ? nil : post.id
                            replyDraft = ""
                        }
                        .frame(minHeight: 44)
                        if replyingTo == post.id {
                            TextField("Write an answer", text: $replyDraft, axis: .vertical).lineLimit(2...5).textFieldStyle(.roundedBorder)
                            Button("Submit answer for review") {
                                Task { if await model.answer(post.id, body: replyDraft) { replyDraft = ""; replyingTo = nil } }
                            }
                            .frame(minHeight: 44)
                            .disabled(model.working || replyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                    ForEach(post.replies) { answer in
                        VStack(alignment: .leading, spacing: FieldGuide.Spacing.xs) {
                            Text(answer.body)
                            HStack {
                                Text("@\(answer.author.username)").font(.footnote.weight(.semibold))
                                if answer.status == .pending {
                                    Label("Pending review", systemImage: "clock").font(.footnote).foregroundStyle(FieldGuide.Palette.warning)
                                } else if answer.status == .rejected {
                                    Label("Not approved", systemImage: "xmark.circle").font(.footnote).foregroundStyle(FieldGuide.Palette.destructive)
                                }
                                Spacer()
                                if answer.status == .approved, community.isSignedIn, answer.author.id != community.profile?.id {
                                    Button { Task { await model.helpful(answer) } } label: {
                                        Label("Helpful · \(answer.helpfulCount)", systemImage: answer.markedHelpful ? "hand.thumbsup.fill" : "hand.thumbsup")
                                            .frame(minHeight: 44)
                                    }
                                    .accessibilityValue(answer.markedHelpful ? "Marked helpful" : "Not marked helpful")
                                    .accessibilityIdentifier("helpful-\(answer.id)")
                                    Button { reportTarget = .post(answer.id) } label: { Image(systemName: "flag").frame(minWidth: 44, minHeight: 44) }
                                        .accessibilityLabel("Report answer by \(answer.author.username)")
                                }
                            }
                        }
                        .padding(FieldGuide.Spacing.sm)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(FieldGuide.Palette.canvas, in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding(FieldGuide.Spacing.sm)
                .background(FieldGuide.Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .leading) { FieldGuide.Brand.teal.frame(width: 3).accessibilityHidden(true) }
            }
        }
    }

    private func summary(_ details: PlaceCommunityDetails) -> some View {
        HStack(spacing: FieldGuide.Spacing.base) {
            if let rating = details.rating {
                Label(String(format: "%.1f · %d rating%@", rating.average, rating.count, rating.count == 1 ? "" : "s"), systemImage: "star.fill")
                    .accessibilityIdentifier("rating-summary")
            } else {
                Label("No ratings yet", systemImage: "star").foregroundStyle(FieldGuide.Palette.secondary)
                    .accessibilityIdentifier("rating-summary")
            }
            Label("\(details.likeCount) like\(details.likeCount == 1 ? "" : "s")", systemImage: "heart")
                .foregroundStyle(FieldGuide.Palette.secondary)
                .accessibilityIdentifier("like-count")
        }
        .font(.subheadline)
    }

    private func actions(_ details: PlaceCommunityDetails) -> some View {
        VStack(alignment: .leading, spacing: FieldGuide.Spacing.sm) {
            Button { Task { await model.toggleLike() } } label: {
                FieldGuideChip(title: details.liked ? "Liked" : "Like", systemImage: details.liked ? "heart.fill" : "heart", isSelected: details.liked)
            }
            .buttonStyle(.plain)
            .disabled(model.working)
            .accessibilityLabel(details.liked ? "Unlike" : "Like")
            .accessibilityValue(details.liked ? "Liked" : "Not liked")
            .accessibilityIdentifier("like-button")
            Text("Your rating").font(.subheadline.weight(.semibold))
            HStack(spacing: 0) {
                ForEach(1...5, id: \.self) { stars in
                    Button { Task { await model.rate(stars) } } label: {
                        Image(systemName: stars <= (details.myRating ?? 0) ? "star.fill" : "star")
                            .font(.title2).foregroundStyle(FieldGuide.Palette.action)
                            .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                    .disabled(model.working)
                    .accessibilityLabel("Rate \(stars) star\(stars == 1 ? "" : "s")")
                    .accessibilityAddTraits(details.myRating == stars ? .isSelected : [])
                    .accessibilityIdentifier("rate-\(stars)")
                }
            }
        }
    }

    private func reviews(_ details: PlaceCommunityDetails) -> some View {
        VStack(alignment: .leading, spacing: FieldGuide.Spacing.sm) {
            Text("Reviews").font(.headline).accessibilityAddTraits(.isHeader)
            if community.isSignedIn {
                TextField("Write a review", text: $draft, prompt: Text("Share what it's like to spend time here").foregroundColor(FieldGuide.Palette.secondary), axis: .vertical)
                    .lineLimit(2...6)
                    .padding(12)
                    .background(FieldGuide.Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(FieldGuide.Palette.controlBorder, lineWidth: 1))
                    .accessibilityIdentifier("review-text")
                Button("Post review") {
                    Task { if await model.postReview(draft) { draft = "" } }
                }
                .frame(minHeight: 44)
                .disabled(model.working || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("post-review")
            }
            if details.reviews.isEmpty {
                Text("No reviews yet.").foregroundStyle(FieldGuide.Palette.secondary)
            }
            ForEach(details.reviews) { review in
                VStack(alignment: .leading, spacing: FieldGuide.Spacing.xs) {
                    HStack {
                        NavigationLink { UserProfileView(profile: review.author, community: community) } label: {
                            Text("@\(review.author.username)").font(.subheadline.weight(.semibold))
                        }
                        .accessibilityIdentifier("review-author-\(review.author.username)")
                        Text(review.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.footnote).foregroundStyle(FieldGuide.Palette.secondary)
                        Spacer()
                        if community.isSignedIn && review.author.id != community.profile?.id {
                            Button { reportTarget = .review(review.id) } label: { Image(systemName: "flag").frame(minWidth: 44, minHeight: 44) }
                                .accessibilityLabel("Report review by \(review.author.username)")
                        }
                    }
                    Text(review.body)
                }
                .padding(FieldGuide.Spacing.sm)
                .background(FieldGuide.Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                .overlay(alignment: .leading) { FieldGuide.Brand.teal.frame(width: 3).accessibilityHidden(true) }
            }
        }
    }
}

extension ReportTarget: Identifiable {}

/// Report a place, review or account with a reason; confirms receipt.
struct ReportSheet: View {
    let target: ReportTarget
    @ObservedObject var community: CommunityStore
    @Environment(\.dismiss) private var dismiss
    @State private var reason: ReportReason = .inaccurate
    @State private var details = ""
    @State private var sent = false
    @State private var error: String?
    @State private var working = false

    var body: some View {
        NavigationStack {
            Form {
                if sent {
                    Label("Report sent. A moderator will review it.", systemImage: "checkmark.circle")
                        .foregroundStyle(FieldGuide.Palette.action)
                        .accessibilityIdentifier("report-confirmation")
                } else {
                    Picker("Reason", selection: $reason) {
                        ForEach(ReportReason.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.inline)
                    TextField("Details (optional)", text: $details, prompt: Text("Anything a moderator should know").foregroundColor(FieldGuide.Palette.secondary), axis: .vertical)
                        .lineLimit(2...5)
                    if let error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(FieldGuide.Palette.destructive) }
                    Button(working ? "Sending…" : "Send report") {
                        Task {
                            working = true
                            do { try await community.service.report(target, reason: reason, details: details); sent = true }
                            catch { self.error = error.localizedDescription }
                            working = false
                        }
                    }
                    .disabled(working)
                    .frame(minHeight: 44)
                    .accessibilityIdentifier("send-report")
                }
            }
            .navigationTitle("Report \(target.type == "profile" ? "account" : target.type)")
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button(sent ? "Done" : "Cancel") { dismiss() }.frame(minHeight: 44) } }
        }
        .tint(FieldGuide.Palette.action)
    }
}

/// Another member's public profile with follow/unfollow and report.
struct UserProfileView: View {
    let profile: CommunityProfile
    @ObservedObject var community: CommunityStore
    @State private var following: Bool?
    @State private var followers = 0
    @State private var error: String?
    @State private var reporting = false

    var body: some View {
        List {
            Section {
                Label("@\(profile.username)", systemImage: "person.crop.circle").font(.title3.weight(.semibold))
                Text("\(followers) follower\(followers == 1 ? "" : "s")").foregroundStyle(FieldGuide.Palette.secondary)
                    .accessibilityIdentifier("follower-count")
            }
            if community.isSignedIn && community.profile?.id != profile.id {
                Section {
                    if let following {
                        Button {
                            Task { await setFollowing(!following) }
                        } label: {
                            FieldGuideChip(title: following ? "Following" : "Follow", systemImage: following ? "person.fill.checkmark" : "person.badge.plus", isSelected: following)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(following ? "Unfollow \(profile.username)" : "Follow \(profile.username)")
                        .accessibilityValue(following ? "Following" : "Not following")
                        .accessibilityIdentifier("follow-button")
                    } else { ProgressView() }
                    Button { reporting = true } label: { Label("Report account", systemImage: "flag") }
                        .frame(minHeight: 44).accessibilityIdentifier("report-account")
                }
            }
            if let error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(FieldGuide.Palette.destructive) }
        }
        .scrollContentBackground(.hidden)
        .background(FieldGuide.Palette.canvas)
        .navigationTitle(profile.username)
        .task { await load() }
        .sheet(isPresented: $reporting) { ReportSheet(target: .profile(profile.id), community: community) }
    }

    private func load() async {
        do {
            followers = try await community.service.followerCount(userID: profile.id)
            if community.isSignedIn { following = try await community.service.isFollowing(userID: profile.id) }
        } catch { self.error = error.localizedDescription }
    }

    private func setFollowing(_ value: Bool) async {
        do { try await community.service.setFollowing(userID: profile.id, following: value); await load() }
        catch { self.error = error.localizedDescription }
    }
}
