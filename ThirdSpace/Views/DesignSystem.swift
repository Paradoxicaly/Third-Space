import SwiftUI

extension Color {
    static let thirdInk = Color(red: 0.08, green: 0.14, blue: 0.23)
    static let thirdCoral = Color(red: 0.95, green: 0.36, blue: 0.28)
    static let thirdTeal = Color(red: 0.08, green: 0.53, blue: 0.55)
    static let thirdCream = Color(red: 0.98, green: 0.96, blue: 0.91)
    static let thirdGold = Color(red: 0.95, green: 0.69, blue: 0.25)
}

struct RatingView: View {
    let rating: Double
    let reviewCount: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "star.fill")
                .foregroundStyle(Color.thirdGold)
            Text(rating.formatted(.number.precision(.fractionLength(1))))
                .fontWeight(.semibold)
            Text("(\(reviewCount))")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}

struct AmenityPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption.weight(.medium))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.thirdTeal.opacity(0.12), in: Capsule())
            .foregroundStyle(Color.thirdTeal)
    }
}
