import SwiftUI

@main
struct ThirdSpaceApp: App {
    @StateObject private var store = PlaceStore()

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(store)
        }
    }
}
