import SwiftUI

struct SavedPlacesView: View {
    @EnvironmentObject private var environment: AppEnvironment

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
                            ForEach(environment.savedPlaces) { PlaceCard(place: $0) }
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
}
