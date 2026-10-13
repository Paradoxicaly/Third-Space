import SwiftUI

enum MainSection: String, CaseIterable, Identifiable {
    case explore = "Explore", map = "Map", featured = "Featured", saved = "Saved", profile = "Profile"
    var id: Self { self }
    var symbol: String {
        switch self {
        case .explore: "safari"
        case .map: "map"
        case .featured: "square.stack"
        case .saved: "bookmark"
        case .profile: "person.crop.circle"
        }
    }
}

struct RootTabView: View {
    @Environment(\.horizontalSizeClass) private var sizeClass
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var environment: AppEnvironment
    @State private var showingContribute = false
    @State private var columns: NavigationSplitViewVisibility = .all

    var body: some View {
        Group {
            if sizeClass == .regular {
                NavigationSplitView(columnVisibility: $columns) {
                    List(MainSection.allCases, selection: $router.section) { section in
                        Label(section.rawValue, systemImage: section.symbol)
                            .tag(section)
                    }
                    .navigationTitle("Third Spaces")
                    .accessibilityIdentifier("main-sidebar")
                } detail: {
                    sectionView(router.section ?? .explore)
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                TabView(selection: $router.section) {
                    ForEach(MainSection.allCases) { section in
                        sectionView(section)
                            .tabItem { Label(section.rawValue, systemImage: section.symbol) }
                            .tag(Optional(section))
                    }
                }
                .toolbarBackground(FieldGuide.Palette.surface, for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
            }
        }
        .tint(FieldGuide.Palette.action)
        .foregroundStyle(FieldGuide.Palette.primary)
        .sheet(isPresented: $showingContribute) { ContributeMenu() }
        .alert("Local storage problem", isPresented: Binding(get: { environment.persistenceError != nil }, set: { if !$0 { environment.persistenceError = nil } })) {
            Button("OK") { environment.persistenceError = nil }
        } message: { Text(environment.persistenceError ?? "") }
    }

    @ViewBuilder private func sectionView(_ section: MainSection) -> some View {
        VStack(spacing: 0) {
            switch section {
            case .explore: ExploreView()
            case .map: PlacesMapView()
            case .featured: FeaturedView()
            case .saved: SavedPlacesView()
            case .profile: ProfileView()
            }
            Button { showingContribute = true } label: {
                Label("Add or contribute", systemImage: "plus.circle")
                    .font(.body.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 48)
                    .contentShape(Rectangle())
            }
            .background(FieldGuide.Palette.surface)
        }
    }
}
