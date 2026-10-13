import SwiftUI

struct PlaceResultsList: View {
    @ObservedObject var model: ExploreViewModel
    var body: some View {
        VStack(alignment: .leading, spacing: FieldGuide.Spacing.base) {
            switch model.state {
            case .loading:
                ProgressView("Loading places…").frame(maxWidth: .infinity, minHeight: 80)
            case .loaded(let places):
                Text("Showing \(places.count) of \(model.totalCount.map(String.init) ?? "unknown") places")
                    .font(.subheadline).foregroundStyle(FieldGuide.Palette.secondary)
                rows(places)
            case .empty:
                if model.query.text.isEmpty && model.query.intents.isEmpty && model.query.requiredFacts.isEmpty {
                    ContentUnavailableView("This area isn’t mapped yet", systemImage: "globe", description: Text("No own-catalog places are available in this area. Browse another area or keep a local draft."))
                } else {
                    ContentUnavailableView("No places match these filters", systemImage: "line.3.horizontal.decrease.circle", description: Text("Try fewer filters or another search."))
                    Button { model.query.text = ""; model.query.intents = []; model.query.requiredFacts = [] } label: {
                        Text("Clear search and filters").frame(minHeight: 44).contentShape(Rectangle())
                    }
                }
            case .failed(let message):
                ContentUnavailableView("Could not load places", systemImage: "exclamationmark.triangle", description: Text(message))
                retry
            case .cached(let places, let asOf):
                Label("Catalog unavailable — cached places", systemImage: "exclamationmark.triangle")
                    .foregroundStyle(FieldGuide.Palette.warning)
                Text("As of \(asOf.formatted(date: .abbreviated, time: .shortened)). Retained snapshot, not live coverage or complete current results.")
                    .font(.footnote).foregroundStyle(FieldGuide.Palette.secondary)
                rows(places)
                retry
            case .offline(let cached, let asOf):
                if let cached {
                    Label("Offline — cached places", systemImage: "wifi.slash").foregroundStyle(FieldGuide.Palette.warning)
                    if let asOf { Text("As of \(asOf.formatted(date: .abbreviated, time: .shortened))").font(.footnote).foregroundStyle(FieldGuide.Palette.secondary) }
                    if cached.isEmpty { Text("The cached snapshot contains no places. This is not a live coverage result.") }
                    rows(cached)
                } else {
                    ContentUnavailableView("Connect to load places", systemImage: "wifi.slash", description: Text("There is no cached copy for this search. Manual search and local drafts remain available; no sample results are inserted."))
                }
                retry
            }
            if let notice = model.notice, notice != model.queryRestorationProblem {
                Label(notice, systemImage: "exclamationmark.circle").foregroundStyle(FieldGuide.Palette.warning)
            }
        }
    }
    private var retry: some View {
        Button { Task { await model.refresh() } } label: {
            Text("Retry").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
    }
    @ViewBuilder private func rows(_ places: [Place]) -> some View {
        ForEach(places) { PlaceCard(place: $0) }
        if model.nextCursor != nil {
            Button { Task { await model.loadMore() } } label: {
                Text("Load more").frame(maxWidth: .infinity, minHeight: 48).contentShape(Rectangle())
            }
        }
    }
}
