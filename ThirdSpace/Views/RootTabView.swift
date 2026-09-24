import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            ExploreView()
                .tabItem { Label("Explore", systemImage: "safari.fill") }

            PlacesMapView()
                .tabItem { Label("Map", systemImage: "map.fill") }

            SavedPlacesView()
                .tabItem { Label("Saved", systemImage: "bookmark.fill") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .tint(Color.thirdCoral)
        .toolbarBackground(Color.thirdCream, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
    }
}
