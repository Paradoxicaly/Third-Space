import SwiftUI
import UIKit

/// Renders one approved media asset with its alt text. Remote sources are reviewed owned storage only.
struct PlaceImage: View {
    let asset: MediaAsset

    var body: some View {
        Group {
            switch asset.source {
            case .bundled(let name):
                Image(name).resizable().scaledToFill()
            case .remote(let url):
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { FieldGuide.Palette.selected }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(asset.altText)
        .accessibilityAddTraits(.isImage)
    }

    /// Small image for map pins; remote images are not fetched into annotation views.
    static func uiImage(for asset: MediaAsset?) -> UIImage? {
        guard let asset, case .bundled(let name) = asset.source else { return nil }
        return UIImage(named: name)
    }
}

/// Labelled outline used when a place has no approved photo; never an invented venue picture.
struct NoPhotoPlaceholder: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 8)
            .strokeBorder(FieldGuide.Palette.controlBorder, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
            .background(FieldGuide.Palette.canvas, in: RoundedRectangle(cornerRadius: 8))
            .overlay {
                Label("No photo yet", systemImage: "photo")
                    .labelStyle(.iconOnly)
                    .foregroundStyle(FieldGuide.Palette.secondary)
            }
            .accessibilityElement()
            .accessibilityLabel("No photo yet")
    }
}
