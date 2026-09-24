import SwiftUI

struct PlaceDetailView: View {
    let place: Place
    @EnvironmentObject private var store: PlaceStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ZStack(alignment: .topTrailing) {
                    RoundedRectangle(cornerRadius: 28)
                        .fill(Color.thirdTeal.opacity(0.15))
                        .frame(height: 230)
                    Image(systemName: place.imageName)
                        .font(.system(size: 72))
                        .foregroundStyle(Color.thirdTeal)
                    Button {
                        store.toggleSaved(place)
                    } label: {
                        Image(systemName: store.isSaved(place) ? "bookmark.fill" : "bookmark")
                            .font(.title3)
                            .foregroundStyle(Color.thirdCoral)
                            .padding(12)
                            .background(.white, in: Circle())
                    }
                    .padding(16)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text(place.name)
                        .font(.largeTitle.bold())
                        .foregroundStyle(Color.thirdInk)
                    Text(place.vibe)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Color.thirdTeal)
                    RatingView(rating: place.rating, reviewCount: place.reviewCount)
                    Text(place.description)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("What you'll find")
                        .font(.title3.bold())
                    FlowLayout(spacing: 8) {
                        ForEach(place.amenities, id: \.self) { amenity in
                            AmenityPill(text: amenity)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Label(place.address, systemImage: "mappin.and.ellipse")
                    Label(place.isOpen ? "Open today until 7:00 PM" : "Closed now • opens tomorrow at 8:00 AM", systemImage: "clock")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                Button {
                    // Directions will connect to Apple Maps in a later milestone.
                } label: {
                    Label("Get directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .background(Color.thirdCoral, in: RoundedRectangle(cornerRadius: 16))
                }
            }
            .padding(20)
        }
        .background(Color.thirdCream.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > width, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return CGSize(width: width, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var point = bounds.origin
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if point.x + size.width > bounds.maxX, point.x > bounds.minX {
                point.x = bounds.minX
                point.y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: point, proposal: ProposedViewSize(size))
            point.x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
