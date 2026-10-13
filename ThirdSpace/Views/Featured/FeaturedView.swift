import SwiftUI

struct FeaturedView: View {

    var body: some View {
        NavigationStack {
            ContentUnavailableView("Nothing featured here yet", systemImage: "square.stack", description: Text("Human-curated guides will appear when a region has approved, dated selections. No paid ranking."))
                .navigationTitle("Featured")
                .background(FieldGuide.Palette.canvas)
        }
    }
}
