import SwiftUI

struct SavedPlacesView: View {
    @EnvironmentObject private var store: PlaceStore

    private var savedPlaces: [Place] {
        Place.examples.filter(store.isSaved)
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.thirdCream.ignoresSafeArea()
                Group {
                    if savedPlaces.isEmpty {
                        ContentUnavailableView(
                            "Your saved places will appear here",
                            systemImage: "bookmark",
                            description: Text("Save spaces you want to visit again.")
                        )
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                ForEach(savedPlaces) { place in
                                    NavigationLink(value: place) {
                                        PlaceCard(place: place)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 108)
                        }
                    }
                }
            }
            .navigationTitle("Saved places")
            .navigationDestination(for: Place.self) { place in
                PlaceDetailView(place: place)
            }
        }
    }
}
