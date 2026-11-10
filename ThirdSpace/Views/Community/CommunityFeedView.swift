import SwiftUI

/// One thread in the forum feed, resolved against the public place catalog.
struct ForumThreadItem: Identifiable, Hashable {
    let post: PlacePost
    let place: Place
    var id: UUID { post.id }
}

@MainActor final class ForumFeedModel: ObservableObject {
    enum Phase: Equatable { case loading, loaded, failed }
    @Published private(set) var phase: Phase = .loading
    @Published private(set) var threads: [ForumThreadItem] = []

    /// Threads whose place is not in the public catalog are dropped, never shown as dangling rows.
    func load(kind: CommunityPostKind?, service: any CommunityService, places: any PlaceRepository) async {
        if threads.isEmpty { phase = .loading }
        do {
            let posts = try await service.recentThreads(kind: kind, limit: 50)
            var resolved: [UUID: Place] = [:]
            var items: [ForumThreadItem] = []
            for post in posts {
                if resolved[post.placeID] == nil, let place = try await places.getPlace(post.placeID) { resolved[post.placeID] = place }
                if let place = resolved[post.placeID] { items.append(ForumThreadItem(post: post, place: place)) }
            }
            threads = items
            phase = .loaded
        } catch {
            phase = .failed
        }
    }
}

/// The Community tab: a forum of place-anchored threads, with Featured picks one switch away.
struct CommunityFeedView: View {
    enum Mode: String, CaseIterable, Identifiable { case threads = "Threads", featured = "Featured picks"; var id: Self { self } }

    @EnvironmentObject private var environment: AppEnvironment
    @StateObject private var model = ForumFeedModel()
    @State private var mode: Mode = .threads
    @State private var kindFilter = "all"
    @State private var composing = false

    private var kind: CommunityPostKind? { CommunityPostKind(rawValue: kindFilter) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: FieldGuide.Spacing.lg) {
                    Picker("Show", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("community-mode")
                    switch mode {
                    case .threads: threadsSection
                    case .featured: FeaturedPicksSection()
                    }
                }
                .padding(FieldGuide.Spacing.base)
                .frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
            }
            .background(FieldGuide.Palette.canvas.ignoresSafeArea())
            .navigationTitle("Community")
            .navigationDestination(for: ForumThreadItem.self) { item in
                if let community = environment.community {
                    ThreadView(item: item, community: community) { await reload() }
                }
            }
            .toolbar {
                if environment.community != nil && mode == .threads {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { composing = true } label: { Label("Start a thread", systemImage: "square.and.pencil") }
                            .accessibilityIdentifier("start-thread")
                    }
                }
            }
            .sheet(isPresented: $composing) {
                if let community = environment.community {
                    NewThreadView(community: community) { await reload() }
                }
            }
            .refreshable { await reload() }
            .task(id: kindFilter) { await reload() }
        }
    }

    private func reload() async {
        guard let community = environment.community else { return }
        await model.load(kind: kind, service: community.service, places: environment.repository)
    }

    @ViewBuilder private var threadsSection: some View {
        if environment.community == nil {
            ContentUnavailableView("Community isn’t available here", systemImage: "bubble.left.and.bubble.right",
                                   description: Text("This build has no community backend. Browsing places still works."))
        } else {
            VStack(alignment: .leading, spacing: FieldGuide.Spacing.md) {
                Text("Questions, visit notes and corrections from people who use these places. A moderator checks every post before it’s public.")
                    .foregroundStyle(FieldGuide.Palette.secondary)
                Picker("Thread type", selection: $kindFilter) {
                    Text("All threads").tag("all")
                    ForEach(CommunityPostKind.rootCases) { Label($0.label + "s", systemImage: $0.icon).tag($0.rawValue) }
                }
                .pickerStyle(.menu)
                .frame(minHeight: 44)
                .accessibilityIdentifier("thread-filter")
                threadList
            }
        }
    }

    @ViewBuilder private var threadList: some View {
        switch model.phase {
        case .loading:
            ProgressView("Loading threads").frame(maxWidth: .infinity, minHeight: 120)
        case .failed:
            ContentUnavailableView {
                Label("Couldn’t load threads", systemImage: "exclamationmark.triangle")
            } description: {
                Text("Nothing was replaced with sample content. Try again when you’re connected.")
            } actions: {
                Button("Retry") { Task { await reload() } }.frame(minHeight: 44)
            }
        case .loaded where model.threads.isEmpty:
            ContentUnavailableView("No threads yet", systemImage: "bubble.left.and.bubble.right",
                                   description: Text(kind == nil ? "Start one about a place you know." : "No \(kind!.label.lowercased())s yet."))
        case .loaded:
            LazyVStack(alignment: .leading, spacing: FieldGuide.Spacing.sm) {
                ForEach(model.threads) { item in
                    NavigationLink(value: item) { ThreadRow(item: item) }
                        .buttonStyle(.plain)
                }
            }
        }
    }
}

struct ThreadRow: View {
    let item: ForumThreadItem

    var body: some View {
        VStack(alignment: .leading, spacing: FieldGuide.Spacing.xs) {
            HStack {
                Label(item.post.kind.label, systemImage: item.post.kind.icon)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(FieldGuide.Palette.community)
                Spacer()
                if item.post.status == .pending {
                    Label("Waiting for review", systemImage: "clock").font(.footnote).foregroundStyle(FieldGuide.Palette.warning)
                }
            }
            if let title = item.post.title { Text(title).font(.headline) }
            Text(item.post.body).lineLimit(3).foregroundStyle(item.post.title == nil ? FieldGuide.Palette.primary : FieldGuide.Palette.secondary)
            Label(item.place.name, systemImage: "mappin.and.ellipse").font(.footnote.weight(.semibold))
            HStack(spacing: FieldGuide.Spacing.sm) {
                Text("@\(item.post.author.username) · \(item.post.createdAt.formatted(date: .abbreviated, time: .omitted))")
                Spacer()
                if item.post.kind == .question {
                    Label(answerText, systemImage: "bubble.left").labelStyle(.titleAndIcon)
                }
            }
            .font(.footnote).foregroundStyle(FieldGuide.Palette.secondary)
        }
        .padding(FieldGuide.Spacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FieldGuide.Palette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FieldGuide.Palette.divider, lineWidth: 1))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the thread")
        .accessibilityIdentifier("thread-\(item.post.id.uuidString)")
    }

    private var answerText: String {
        let count = item.post.replies.count
        return count == 1 ? "1 answer" : "\(count) answers"
    }
}

/// Human-curated, time-limited picks (formerly the Featured tab). Nobody pays to be here.
struct FeaturedPicksSection: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var picks: [(item: FeaturedItem, place: Place)] = []
    @State private var state: LoadPhase = .loading

    private enum LoadPhase { case loading, loaded, failed }

    var body: some View {
        VStack(alignment: .leading, spacing: FieldGuide.Spacing.lg) {
            switch state {
            case .loading:
                ProgressView("Loading picks").frame(maxWidth: .infinity, minHeight: 120)
            case .failed:
                ContentUnavailableView {
                    Label("Couldn’t load featured picks", systemImage: "exclamationmark.triangle")
                } description: {
                    Text("Nothing was replaced with sample content. Try again when you’re connected.")
                } actions: {
                    Button("Retry") { Task { await load() } }.frame(minHeight: 44)
                }
            case .loaded where picks.isEmpty:
                ContentUnavailableView("Nothing featured here yet", systemImage: "square.stack", description: Text("Human-curated guides will appear when a region has approved, dated selections. No paid ranking."))
            case .loaded:
                if let notice = environment.catalogNotice {
                    Label(notice, systemImage: "flask").font(.footnote).foregroundStyle(FieldGuide.Palette.warning)
                }
                Text("Picked by people, for a set time. Nobody pays to be here.")
                    .foregroundStyle(FieldGuide.Palette.secondary)
                ForEach(picks, id: \.item.id) { pick in
                    VStack(alignment: .leading, spacing: FieldGuide.Spacing.sm) {
                        Text(pick.item.reason).font(.body).foregroundStyle(FieldGuide.Palette.primary)
                        Label("\(pick.item.curator) · until \(pick.item.endsAt.formatted(date: .abbreviated, time: .omitted))", systemImage: "person.crop.circle.badge.checkmark")
                            .font(.footnote).foregroundStyle(FieldGuide.Palette.secondary)
                        PlaceCard(place: pick.place)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("featured-\(pick.item.id.uuidString)")
                }
            }
        }
        .task { await load() }
    }

    /// Picks whose place is no longer approved are dropped, never shown as a dangling card.
    private func load() async {
        state = .loading
        do {
            let items = try await environment.featured.activeItems(regionID: nil, at: Date())
            var resolved: [(item: FeaturedItem, place: Place)] = []
            for item in items {
                if let place = try await environment.repository.getPlace(item.targetID) { resolved.append((item, place)) }
            }
            picks = resolved
            state = .loaded
        } catch {
            state = .failed
        }
    }
}
