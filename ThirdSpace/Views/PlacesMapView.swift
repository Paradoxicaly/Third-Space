import SwiftUI

/// Dedicated Map destination. Filters are Explore's shared query; the viewport only becomes the
/// list's area when the user chooses "List places in this area".
struct PlacesMapView: View {
    @EnvironmentObject private var environment: AppEnvironment
    var body: some View {
        MapScreen(map: environment.map, explore: environment.explore)
    }
}

private struct MapScreen: View {
    @ObservedObject var map: MapViewModel
    @ObservedObject var explore: ExploreViewModel
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var router: AppRouter
    @State private var loadTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    statusPanel
                    MapKitView(content: map.content, selectedPlaceID: map.selectedPlaceID,
                               initialViewport: map.viewport ?? environment.initialMapViewport,
                               recordNoun: environment.recordNoun,
                               onViewportChange: schedule,
                               onSelectPlace: { map.selectedPlaceID = $0 })
                        .accessibilityElement(children: .contain)
                        .accessibilityLabel("Map of places")
                    if let place = map.selectedPlace {
                        MapPreviewCard(place: place, maxHeight: geometry.size.height * 0.55) { map.selectedPlaceID = nil }
                    }
                }
            }
            .background(FieldGuide.Palette.canvas)
            .navigationTitle("Map")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: explore.query.queryID) {
                if let viewport = map.viewport { schedule(viewport) }
            }
        }
    }

    /// Debounced so a pan or pinch issues one request when it settles.
    private func schedule(_ viewport: MapViewport) {
        loadTask?.cancel()
        loadTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await map.load(viewport: viewport, filters: explore.query)
        }
    }

    private var activeFilterCount: Int {
        explore.query.intents.count + explore.query.requiredFacts.count + (explore.query.text.isEmpty ? 0 : 1)
    }

    // Status sits on an opaque panel, never directly over map tiles.
    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: FieldGuide.Spacing.xs) {
            if let notice = environment.catalogNotice {
                SyntheticBadge(text: notice)
            }
            status
            if activeFilterCount > 0 {
                Label("\(activeFilterCount) Explore filter\(activeFilterCount == 1 ? "" : "s") applied", systemImage: "line.3.horizontal.decrease")
                    .font(.footnote).foregroundStyle(FieldGuide.Palette.secondary)
            }
            listButton
        }
        .padding(.horizontal, FieldGuide.Spacing.base)
        .padding(.vertical, FieldGuide.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FieldGuide.Palette.surface)
        .overlay(alignment: .bottom) { FieldGuide.Palette.divider.frame(height: 1) }
    }

    @ViewBuilder private var status: some View {
        switch map.content {
        case .loading:
            ProgressView("Loading map places…").font(.subheadline)
        case .aggregate(let cells):
            Text(cells.isEmpty ? "No places match in this view. Zoom out or change filters." : "Tap an area count, or zoom in, to see places.")
                .font(.subheadline).foregroundStyle(FieldGuide.Palette.secondary)
        case .places(let places, let truncated):
            Text(places.isEmpty ? "No places match in this view. Zoom out or change filters."
                 : truncated ? "Showing the first \(places.count) places here — zoom in to see all."
                 : "\(places.count) place\(places.count == 1 ? "" : "s") in view. Tap a marker for a preview.")
                .font(.subheadline).foregroundStyle(FieldGuide.Palette.secondary)
        case .offline:
            Label("Offline — map places unavailable", systemImage: "wifi.slash")
                .font(.subheadline).foregroundStyle(FieldGuide.Palette.warning)
        case .failed(let message):
            Label(message, systemImage: "exclamationmark.triangle")
                .font(.subheadline).foregroundStyle(FieldGuide.Palette.warning)
            Button {
                if let viewport = map.viewport { schedule(viewport) }
            } label: {
                Text("Retry").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
            }
        }
    }

    @ViewBuilder private var listButton: some View {
        switch map.content {
        case .offline, .failed:
            Button { router.section = .explore } label: {
                FieldGuideChip(title: "Show places as list", systemImage: "list.bullet")
            }
            .buttonStyle(.plain)
        default:
            if let bounds = map.viewport?.bounds {
                Button {
                    explore.query.area = .bounds(bounds)
                    router.section = .explore
                } label: {
                    FieldGuideChip(title: "List places in this area", systemImage: "list.bullet")
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens Explore with the visible map area as the search area")
            }
        }
    }
}

/// Preview of the selected marker, below the map so map attribution stays visible.
private struct MapPreviewCard: View {
    let place: Place
    let maxHeight: CGFloat
    let onClose: () -> Void
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        // Natural height when it fits; scrolls (e.g. at accessibility text sizes) instead of hiding the map.
        ViewThatFits(in: .vertical) {
            content.padding(FieldGuide.Spacing.base)
            ScrollView { content.padding(FieldGuide.Spacing.base) }
        }
        .frame(maxHeight: maxHeight)
        .background(FieldGuide.Palette.surface)
        .overlay(alignment: .top) { FieldGuide.Palette.divider.frame(height: 1) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("map-preview")
        .onAppear { titleFocused = true }
        .onChange(of: place.id) { titleFocused = true }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: FieldGuide.Spacing.sm) {
            let layout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: FieldGuide.Spacing.sm))
                : AnyLayout(HStackLayout(alignment: .top, spacing: FieldGuide.Spacing.sm))
            HStack(alignment: .top, spacing: FieldGuide.Spacing.xs) {
                layout {
                    photo
                    VStack(alignment: .leading, spacing: FieldGuide.Spacing.xs) {
                        Text(place.name).font(.headline).foregroundStyle(FieldGuide.Palette.primary)
                            .accessibilityAddTraits(.isHeader)
                            .accessibilityFocused($titleFocused)
                        Text("\(place.category.rawValue.capitalized) · \(place.regionID)")
                            .font(.subheadline).foregroundStyle(FieldGuide.Palette.secondary)
                        FlowLayout(spacing: FieldGuide.Spacing.xs) {
                            ForEach(Array(place.facts.prefix(2)), id: \.key) { FactTag(fact: $0) }
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 0) {
                    Button(action: onClose) {
                        Image(systemName: "xmark").frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                    }
                    .accessibilityLabel("Close preview")
                    saveButton
                }
                .foregroundStyle(FieldGuide.Palette.action)
            }
            NavigationLink { PlaceDetailView(place: place) } label: { Text("Open details") }
                .buttonStyle(FieldGuideActionStyle())
        }
    }

    @ViewBuilder private var photo: some View {
        if let asset = place.media.first {
            Color.clear
                .frame(width: 112, height: 84)
                .overlay { PlaceImage(asset: asset) }
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            NoPhotoPlaceholder().frame(width: 112, height: 84)
        }
    }

    private var saveButton: some View {
        let saved = environment.isSaved(place)
        return Button {
            Task { await environment.toggleSaved(place) }
        } label: {
            Image(systemName: saved ? "bookmark.fill" : "bookmark").font(.title3)
                .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
        }
        .accessibilityLabel("\(saved ? "Unsave" : "Save") \(place.name)")
        .accessibilityValue(saved ? "Saved" : "Not saved")
        .accessibilityHint("Saves privately on this device")
    }
}
