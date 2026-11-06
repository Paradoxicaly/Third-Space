import SwiftUI

/// Order for the local saved list; ties always fall back to the place name.
enum SavedSort: String, CaseIterable, Identifiable {
    case name = "Name", area = "Area"
    var id: Self { self }
    func apply(_ places: [Place]) -> [Place] {
        places.sorted { lhs, rhs in
            if self == .area, lhs.regionID != rhs.regionID { return lhs.regionID < rhs.regionID }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }
}

struct SavedPlacesView: View {
    @EnvironmentObject private var environment: AppEnvironment
    @AppStorage("savedSort") private var sort: SavedSort = .name

    var body: some View {
        NavigationStack {
            ZStack {
                FieldGuide.Palette.canvas.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: FieldGuide.Spacing.base) {
                        Text("Private saves on this device. Not published or synced to an account.")
                            .foregroundStyle(FieldGuide.Palette.secondary)
                        if let asOf = environment.savedAsOf {
                            Label("Offline-capable snapshots as of \(asOf.formatted(date: .abbreviated, time: .shortened))", systemImage: "clock")
                                .foregroundStyle(FieldGuide.Palette.warning)
                        }
                        if environment.savedPlaces.isEmpty {
                        ContentUnavailableView(
                            "Your saved places will appear here",
                            systemImage: "bookmark",
                            description: Text("Save spaces you want to visit again.")
                        )
                        } else {
                            ViewThatFits(in: .horizontal) {
                                HStack { savedCount; Spacer(); sortPicker }
                                VStack(alignment: .leading, spacing: FieldGuide.Spacing.sm) { savedCount; sortPicker }
                            }
                            let sorted = sort.apply(environment.savedPlaces)
                            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, place in
                                // Area headers mark where each region's run begins.
                                if sort == .area, index == 0 || sorted[index - 1].regionID != place.regionID {
                                    Text(environment.areaName(for: place.regionID))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(FieldGuide.Palette.secondary)
                                        .padding(.top, FieldGuide.Spacing.xs)
                                        .accessibilityAddTraits(.isHeader)
                                }
                                PlaceCard(place: place)
                            }
                        }
                        if environment.savedIDs.count > environment.savedPlaces.count {
                            Text("Some saved places are unavailable or their cached copy has expired. Saved IDs are retained; connect to refresh them.")
                                .foregroundStyle(FieldGuide.Palette.warning)
                        }
                        Button("Refresh local saves") { Task { await environment.restoreLocalState() } }.frame(minHeight: 44)
                    }
                    .padding(FieldGuide.Spacing.base)
                    .frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Saved places")
            .task { await environment.restoreLocalState() }
        }
    }

    private var savedCount: some View {
        Text(environment.savedPlaces.count == 1 ? "1 saved place" : "\(environment.savedPlaces.count) saved places")
            .font(.headline).foregroundStyle(FieldGuide.Palette.primary)
            .accessibilityIdentifier("saved-count")
    }

    private var sortPicker: some View {
        Picker("Sort saved places", selection: $sort) {
            ForEach(SavedSort.allCases) { Text($0.rawValue).tag($0) }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 240)
        .accessibilityIdentifier("saved-sort")
    }
}
