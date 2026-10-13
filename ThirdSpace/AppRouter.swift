import SwiftUI

@MainActor final class AppRouter: ObservableObject {
    @Published var section: MainSection? = .explore
}
