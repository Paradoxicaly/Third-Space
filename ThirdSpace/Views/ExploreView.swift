import SwiftUI

struct ExploreView: View {
    @State private var searchText = ""
    @State private var selectedCategory: PlaceCategory = .all

    private var filteredPlaces: [Place] {
        Place.examples.filter { place in
            let categoryMatches = selectedCategory == .all || place.category == selectedCategory
            let searchMatches = searchText.isEmpty || place.name.localizedCaseInsensitiveContains(searchText) || place.subtitle.localizedCaseInsensitiveContains(searchText)
            return categoryMatches && searchMatches
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.thirdCream.ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 7) {
                            Text("Find your")
                                .font(.title2.weight(.semibold))
                            Text("third space.")
                                .font(.largeTitle.bold())
                                .foregroundStyle(Color.thirdCoral)
                            Text("Welcoming places to focus, connect, and recharge.")
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)

                        HStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(.secondary)
                            TextField("Search nearby spaces", text: $searchText)
                            Image(systemName: "slider.horizontal.3")
                                .foregroundStyle(Color.thirdTeal)
                        }
                        .padding(14)
                        .background(.white, in: RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.05), radius: 12, y: 5)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(PlaceCategory.allCases) { category in
                                    Button {
                                        selectedCategory = category
                                    } label: {
                                        Label(category.rawValue, systemImage: category.icon)
                                            .font(.subheadline.weight(.semibold))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 10)
                                            .foregroundStyle(selectedCategory == category ? .white : Color.thirdInk)
                                            .background(selectedCategory == category ? Color.thirdTeal : .white, in: Capsule())
                                    }
                                }
                            }
                        }

                        HStack {
                            Text("Near you")
                                .font(.title2.bold())
                            Spacer()
                            Text("\(filteredPlaces.count) places")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        LazyVStack(spacing: 16) {
                            ForEach(filteredPlaces) { place in
                                NavigationLink(value: place) {
                                    PlaceCard(place: place)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                    .padding(.bottom, 108)
                }
            }
            .navigationDestination(for: Place.self) { place in
                PlaceDetailView(place: place)
            }
        }
    }
}

struct PlaceCard: View {
    let place: Place
    @EnvironmentObject private var store: PlaceStore

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.thirdTeal.opacity(0.16))
                Image(systemName: place.imageName)
                    .font(.title)
                    .foregroundStyle(Color.thirdTeal)
            }
            .frame(width: 78, height: 104)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(place.name)
                            .font(.headline)
                            .foregroundStyle(Color.thirdInk)
                        Text(place.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                    Button {
                        store.toggleSaved(place)
                    } label: {
                        Image(systemName: store.isSaved(place) ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(Color.thirdCoral)
                            .padding(5)
                    }
                }
                RatingView(rating: place.rating, reviewCount: place.reviewCount)
                HStack {
                    Text(place.isOpen ? "Open" : "Closed")
                        .foregroundStyle(place.isOpen ? Color.thirdTeal : .secondary)
                    Text("•")
                    Text(place.distance)
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .background(.white, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 12, y: 5)
    }
}
