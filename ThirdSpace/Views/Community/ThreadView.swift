import SwiftUI

/// One forum thread: the opening post, its answers, and an answer composer for questions.
/// Reads the live thread from the place's community details so answers and votes stay current.
struct ThreadView: View {
    let item: ForumThreadItem
    @ObservedObject var community: CommunityStore
    let onChange: () async -> Void
    @StateObject private var model: PlaceCommunityModel
    @State private var draft = ""
    @State private var sentForReview = false
    @State private var showingAccount = false
    @State private var reportTarget: ReportTarget?
    @FocusState private var answerFocused: Bool

    init(item: ForumThreadItem, community: CommunityStore, onChange: @escaping () async -> Void) {
        self.item = item
        self.community = community
        self.onChange = onChange
        _model = StateObject(wrappedValue: PlaceCommunityModel(placeID: item.place.id, community: community))
    }

    /// The live copy once loaded; the feed's copy until then. Nil if the thread was removed.
    private var thread: PlacePost? {
        guard let details = model.details else { return item.post }
        return details.posts.first { $0.id == item.post.id }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FieldGuide.Spacing.lg) {
                NavigationLink { PlaceDetailView(place: item.place) } label: {
                    Label("About this place: \(item.place.name)", systemImage: "mappin.and.ellipse")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                }
                .accessibilityIdentifier("thread-place-link")
                if let thread {
                    opening(thread)
                    answers(thread)
                    composer(thread)
                } else {
                    ContentUnavailableView("This thread is no longer available", systemImage: "eye.slash",
                                           description: Text("It may have been removed by a moderator."))
                }
                if let error = model.error {
                    Text(error).font(.footnote).foregroundStyle(FieldGuide.Palette.destructive)
                }
            }
            .padding(FieldGuide.Spacing.base)
            .frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(FieldGuide.Palette.canvas.ignoresSafeArea())
        .navigationTitle(item.post.kind.label)
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.load() }
        .refreshable { await model.load() }
        .sheet(item: $reportTarget) { ReportSheet(target: $0, community: community) }
        .sheet(isPresented: $showingAccount) { AccountView(community: community) }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") { answerFocused = false }.accessibilityIdentifier("keyboard-done")
            }
        }
    }

    private func opening(_ thread: PlacePost) -> some View {
        VStack(alignment: .leading, spacing: FieldGuide.Spacing.sm) {
            Label(thread.kind.label, systemImage: thread.kind.icon)
                .font(.subheadline.weight(.semibold)).foregroundStyle(FieldGuide.Palette.community)
            if let title = thread.title { Text(title).font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader) }
            Text(thread.body)
            byline(thread)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("thread-opening")
    }

    private func byline(_ post: PlacePost) -> some View {
        HStack(spacing: FieldGuide.Spacing.xs) {
            Text("@\(post.author.username) · \(post.createdAt.formatted(date: .abbreviated, time: .omitted))")
                .font(.footnote).foregroundStyle(FieldGuide.Palette.secondary)
            status(post)
            Spacer()
            if community.isSignedIn && post.author.id != community.profile?.id && post.status == .approved {
                Button { reportTarget = .post(post.id) } label: { Image(systemName: "flag").frame(minWidth: 44, minHeight: 44) }
                    .accessibilityLabel("Report post by \(post.author.username)")
            }
        }
    }

    @ViewBuilder private func status(_ post: PlacePost) -> some View {
        switch post.status {
        case .pending: Label("Waiting for review", systemImage: "clock").font(.footnote).foregroundStyle(FieldGuide.Palette.warning)
        case .rejected: Label("Not approved", systemImage: "xmark.circle").font(.footnote).foregroundStyle(FieldGuide.Palette.destructive)
        case .approved: EmptyView()
        }
    }

    @ViewBuilder private func answers(_ thread: PlacePost) -> some View {
        if thread.kind == .question {
            VStack(alignment: .leading, spacing: FieldGuide.Spacing.sm) {
                Text(thread.replies.count == 1 ? "1 answer" : "\(thread.replies.count) answers")
                    .font(.headline).accessibilityAddTraits(.isHeader)
                if thread.replies.isEmpty {
                    Text("No answers yet.").foregroundStyle(FieldGuide.Palette.secondary)
                }
                ForEach(thread.replies) { answer in
                    VStack(alignment: .leading, spacing: FieldGuide.Spacing.xs) {
                        Text(answer.body)
                        byline(answer)
                        if answer.status == .approved, community.isSignedIn, answer.author.id != community.profile?.id {
                            Button { Task { await model.helpful(answer) } } label: {
                                Label("Helpful · \(answer.helpfulCount)", systemImage: answer.markedHelpful ? "hand.thumbsup.fill" : "hand.thumbsup")
                                    .frame(minHeight: 44)
                            }
                            .disabled(model.working)
                            .accessibilityValue(answer.markedHelpful ? "Marked helpful" : "Not marked helpful")
                            .accessibilityIdentifier("helpful-\(answer.id)")
                        }
                    }
                    .padding(FieldGuide.Spacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(FieldGuide.Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("answer-\(answer.id)")
                }
            }
        }
    }

    @ViewBuilder private func composer(_ thread: PlacePost) -> some View {
        if thread.kind == .question && thread.status == .approved {
            VStack(alignment: .leading, spacing: FieldGuide.Spacing.sm) {
                if !community.isSignedIn {
                    Button("Sign in to answer") { showingAccount = true }.frame(minHeight: 44)
                } else {
                    TextField("Write an answer", text: $draft, axis: .vertical)
                        .lineLimit(3...8)
                        .padding(12)
                        .background(FieldGuide.Palette.surface, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FieldGuide.Palette.controlBorder, lineWidth: 1))
                        .focused($answerFocused)
                        .accessibilityIdentifier("thread-answer-text")
                    Button("Submit answer for review") {
                        Task {
                            answerFocused = false
                            if await model.answer(thread.id, body: draft) {
                                draft = ""; sentForReview = true
                                await onChange()
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)
                    .disabled(model.working || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("thread-answer-submit")
                    if sentForReview {
                        Label("Sent for review. Only you can see it until a moderator approves it.", systemImage: "checkmark.circle")
                            .font(.footnote).foregroundStyle(FieldGuide.Palette.community)
                            .accessibilityIdentifier("thread-answer-sent")
                    }
                }
            }
        }
    }
}
