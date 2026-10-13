import SwiftUI

struct PlaceDetailView: View {
    let place: Place
    @EnvironmentObject private var environment: AppEnvironment

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FieldGuide.Spacing.lg) {
                Text(place.name).font(.title.weight(.semibold))
                if environment.isSynthetic {
                    Label("SYNTHETIC — NOT A VERIFIED PLACE", systemImage: "flask")
                        .foregroundStyle(FieldGuide.Palette.warning)
                }
                Text("Original language: \(place.originalLanguage) · \(place.regionID)")
                    .font(.subheadline).foregroundStyle(FieldGuide.Palette.secondary)
                Label("Hours unknown — check before visiting", systemImage: "clock")
                Text("Practical evidence").font(.title2.weight(.semibold))
                ForEach([FactKey.cost, .noise, .wifi, .outlets, .stepFreeEntrance, .accessibleToilet], id: \.self) { key in
                    VStack(alignment: .leading, spacing: FieldGuide.Spacing.xs) {
                        if let fact = place.facts.first(where: { $0.key == key }) {
                            Text("\(key.label): \(fact.value.displayName)")
                            Text("\(fact.source.attribution) · observed \(fact.source.observedAt.formatted(date: .abbreviated, time: .omitted))")
                                .font(.footnote).foregroundStyle(FieldGuide.Palette.secondary)
                        } else { Text("\(key.label): unknown — no source supplied") }
                    }
                }
                Text("Photos").font(.title2.weight(.semibold)).accessibilityAddTraits(.isHeader)
                if place.media.isEmpty {
                    Label("No approved photos yet", systemImage: "photo")
                        .foregroundStyle(FieldGuide.Palette.secondary)
                } else {
                    ForEach(place.media) { asset in
                        VStack(alignment: .leading, spacing: FieldGuide.Spacing.xs) {
                            Color.clear
                                .aspectRatio(4 / 3, contentMode: .fit)
                                .overlay { PlaceImage(asset: asset) }
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            // Credit sits on the opaque page, never over the image.
                            Text(asset.creatorCredit)
                                .font(.footnote).foregroundStyle(FieldGuide.Palette.secondary)
                        }
                    }
                }
                Button {
                    Task { await environment.toggleSaved(place) }
                } label: {
                    Label(environment.isSaved(place) ? "Remove local save" : "Save on this device", systemImage: "bookmark")
                }
                .buttonStyle(FieldGuideActionStyle())
                Text("M2 detail preview. Community, directions and live contributions are not connected. No rating, opening-time or accessibility verification is implied.")
                    .foregroundStyle(FieldGuide.Palette.secondary)
            }
            .padding(FieldGuide.Spacing.base)
            .frame(maxWidth: 720, alignment: .leading).frame(maxWidth: .infinity)
        }
        .foregroundStyle(FieldGuide.Palette.primary)
        .background(FieldGuide.Palette.canvas.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }
}
