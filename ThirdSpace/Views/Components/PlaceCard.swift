import SwiftUI

struct PlaceCard: View {
    let place: Place
    @EnvironmentObject private var environment: AppEnvironment
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .headline) private var tileSize: CGFloat = 44

    private var shownFacts: [PlaceFact] { Array(place.facts.prefix(2)) }

    var body: some View {
        // Save overlays the corner so the name keeps the full card width at accessibility sizes,
        // where the tile row sits beside it; otherwise the text reserves the button's width.
        ZStack(alignment: .topTrailing) {
            NavigationLink {
                PlaceDetailView(place: place)
            } label: {
                summary
                    .padding(.trailing, dynamicTypeSize.isAccessibilitySize ? 0 : 44)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(place.name)")
            .accessibilityValue(spokenSummary)
            .accessibilityIdentifier("open-place-\(place.id.uuidString)")
            saveButton
        }
        .padding(FieldGuide.Spacing.base)
        .background(FieldGuide.Palette.surface, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(FieldGuide.Palette.divider, lineWidth: 1))
    }

    private var summary: some View {
        // Accessibility sizes stack the tile above the text instead of squeezing the name.
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: FieldGuide.Spacing.sm))
            : AnyLayout(HStackLayout(alignment: .top, spacing: FieldGuide.Spacing.sm))
        return layout {
            thumbnail.accessibilityHidden(true)
            VStack(alignment: .leading, spacing: FieldGuide.Spacing.xs) {
                Text(place.name).font(.headline).foregroundStyle(FieldGuide.Palette.primary)
                Text(categoryLine).font(.subheadline).foregroundStyle(FieldGuide.Palette.secondary)
                if !shownFacts.isEmpty {
                    FlowLayout(spacing: FieldGuide.Spacing.xs) {
                        ForEach(shownFacts, id: \.key) { FactTag(fact: $0) }
                    }
                    .padding(.top, FieldGuide.Spacing.xxs)
                }
                Text(provenance).font(.footnote).foregroundStyle(FieldGuide.Palette.secondary)
            }
        }
    }

    /// Approved photo as a 4:3 thumbnail; otherwise the category tile (no invented imagery).
    @ViewBuilder private var thumbnail: some View {
        // Grows a little with text, never enough to push the name below the fold.
        let side = min(tileSize, 60)
        if let photo = place.media.first {
            PlaceImage(asset: photo)
                .frame(width: side * 4 / 3, height: side)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            Image(systemName: place.category.icon)
                .font(.system(size: side * 0.45))
                // Fixed cream, not adaptive canvas: the pin-symbol pair is cream on forest in both appearances.
                .foregroundStyle(Color(hex: 0xF7F5EC))
                .frame(width: side, height: side)
                .background(FieldGuide.Brand.forest, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var saveButton: some View {
        let saved = environment.isSaved(place)
        return Button {
            Task { await environment.toggleSaved(place) }
        } label: {
            Image(systemName: saved ? "bookmark.fill" : "bookmark")
                .font(.title3)
                .foregroundStyle(FieldGuide.Palette.action)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("\(saved ? "Unsave" : "Save") \(place.name)")
        .accessibilityValue(saved ? "Saved" : "Not saved")
        .accessibilityHint("Saves privately on this device")
    }

    private var categoryLine: String { "\(place.category.rawValue.capitalized) · \(place.provenance?.address ?? place.regionID)" }

    /// One dated source line for the card instead of repeating provenance on every fact.
    private var provenance: String {
        guard !shownFacts.isEmpty else {
            if let provenance = place.provenance, provenance.reviewStatus == .unreviewedCandidate {
                return "Unreviewed candidate · \(provenance.publisher) · no practical observations yet"
            }
            return "No practical observations recorded yet"
        }
        let sources = shownFacts.map(\.source)
        let attribution = sources.allSatisfy { $0.kind == .syntheticFixture }
            ? "SYNTHETIC fixture (invented)"
            : Set(sources.map(\.attribution)).sorted().joined(separator: ", ")
        let dates = sources.map(\.observedAt)
        let first = dates.min()!.formatted(date: .abbreviated, time: .omitted)
        let last = dates.max()!.formatted(date: .abbreviated, time: .omitted)
        return "\(attribution) · observed \(first == last ? first : "\(first) – \(last)")"
    }

    private var spokenSummary: String {
        ([categoryLine] + shownFacts.map { "\($0.key.label): \($0.value.displayName)" } + [provenance]).joined(separator: ". ")
    }
}

/// Compact icon + value tag. Unknown names the fact and stays visually distinct from a negative.
struct FactTag: View {
    let fact: PlaceFact

    var body: some View {
        Label {
            Text(fact.tagText)
        } icon: {
            Image(systemName: fact.value == .unknown ? "questionmark.circle" : fact.key.icon)
        }
        .font(.subheadline)
        .foregroundStyle(fact.value == .unknown ? FieldGuide.Palette.secondary : FieldGuide.Palette.primary)
        .padding(.horizontal, FieldGuide.Spacing.xs)
        .padding(.vertical, FieldGuide.Spacing.xxs)
        .background(FieldGuide.Palette.canvas, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(FieldGuide.Palette.divider, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(fact.key.label): \(fact.value.displayName)")
    }
}

extension PlaceFact {
    var tagText: String {
        switch value {
        case .yes: key.label
        case .no: String(localized: "No \(key.label.lowercased())")
        case .unknown: String(localized: "\(key.label) unknown")
        default: value.displayName
        }
    }
}

extension FactKey {
    var label: String {
        switch self {
        case .cost: "Cost"
        case .noise: "Noise"
        case .seating: "Seating"
        case .wifi: "Wi-Fi"
        case .outlets: "Outlets"
        case .indoors: "Indoors"
        case .outdoors: "Outdoors"
        case .stepFreeEntrance: "Step-free entrance"
        case .accessibleToilet: "Accessible toilet"
        case .transit: "Transit"
        case .hours: "Hours"
        }
    }

    var icon: String {
        switch self {
        case .cost: "tag"
        case .noise: "speaker.wave.1"
        case .seating: "chair"
        case .wifi: "wifi"
        case .outlets: "powerplug"
        case .indoors: "house"
        case .outdoors: "tree"
        case .stepFreeEntrance: "figure.roll"
        case .accessibleToilet: "toilet"
        case .transit: "tram"
        case .hours: "clock"
        }
    }
}

extension ExploreIntent {
    var label: String {
        switch self {
        case .focus: String(localized: "Focus")
        case .meet: String(localized: "Meet")
        case .unwind: String(localized: "Unwind")
        case .move: String(localized: "Move")
        case .create: String(localized: "Create")
        }
    }

    var icon: String {
        switch self {
        case .focus: "book"
        case .meet: "person.2"
        case .unwind: "leaf"
        case .move: "figure.walk"
        case .create: "pencil.and.outline"
        }
    }
}
