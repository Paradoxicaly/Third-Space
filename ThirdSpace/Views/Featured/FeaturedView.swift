import SwiftUI

struct FeaturedView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @State private var picks: [(item: FeaturedItem, place: Place)] = []
    @State private var state: LoadPhase = .loading

    private enum LoadPhase { case loading, loaded, failed }

    var body: some View {
        NavigationStack {
            ZStack {
                FieldGuide.Palette.canvas.ignoresSafeArea()
                switch state {
                case .loading:
                    ProgressView("Loading picks")
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
                    list
                }
            }
            .navigationTitle("Featured")
            .task { await load() }
        }
    }

    private var list: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FieldGuide.Spacing.lg) {
                if let notice = environment.catalogNotice {
                    Label(notice, systemImage: "flask").font(.footnote).foregroundStyle(FieldGuide.Palette.warning)
                }
                Text("Picked by people, for a set time. Nobody pays to be here.")
                    .foregroundStyle(FieldGuide.Palette.secondary)
                ForEach(picks, id: \.item.id) { pick in
                    VStack(alignment: .leading, spacing: FieldGuide.Spacing.sm) {
                        Text(pick.item.reason).font(.body)
                            .foregroundStyle(FieldGuide.Palette.primary)
                        Label("\(pick.item.curator) · until \(pick.item.endsAt.formatted(date: .abbreviated, time: .omitted))", systemImage: "person.crop.circle.badge.checkmark")
                            .font(.footnote).foregroundStyle(FieldGuide.Palette.secondary)
                        PlaceCard(place: pick.place)
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityIdentifier("featured-\(pick.item.id.uuidString)")
                }
            }
            .padding(FieldGuide.Spacing.base)
            .frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
        }
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
