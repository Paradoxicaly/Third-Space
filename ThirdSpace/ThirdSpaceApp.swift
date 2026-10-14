import SwiftUI

@main
struct ThirdSpaceApp: App {
    @StateObject private var environment = AppEnvironment(supabaseConfig: .bundled())
    @StateObject private var router = AppRouter()
    @AppStorage("appearance") private var appearance = "system"

    var body: some Scene {
        WindowGroup {
            RootTabView()
                .environmentObject(environment)
                .environmentObject(router)
                .preferredColorScheme(appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
                .modifier(DevelopmentPreviewConfiguration(arguments: environment.launchArguments))
                .task { await environment.restoreLocalState(); await environment.community?.restore() }
        }
    }
}

private struct DevelopmentPreviewConfiguration: ViewModifier {
    let arguments: [String]
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage("appearance") private var appearance = "system"
    func body(content: Content) -> some View {
        #if DEBUG
        content
            .environment(\.dynamicTypeSize, arguments.contains("--ax-largest") ? .accessibility5 : dynamicTypeSize)
            .environment(\.layoutDirection, arguments.contains("--rtl") ? .rightToLeft : layoutDirection)
            .environment(\.horizontalSizeClass, arguments.contains("--compact-width") ? .compact : sizeClass)
            .preferredColorScheme(arguments.contains("--dark") || appearance == "dark" ? .dark : appearance == "light" ? .light : nil)
        #else
        content
        #endif
    }
}
