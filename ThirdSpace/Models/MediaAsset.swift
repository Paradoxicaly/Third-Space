import Foundation

/// Where approved image bytes come from. Synthetic fixtures are bundled; reviewed uploads will be served
/// from owned storage after EXIF/GPS stripping. Provider imagery is never a source.
enum MediaSource: Codable, Hashable, Sendable {
    case bundled(name: String)
    case remote(URL)
}

struct MediaAsset: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let approvedParentID: UUID?
    let creatorCredit: String
    let altText: String
    let rightsCleared: Bool
    let source: MediaSource
    /// Synthetic images are generated test patterns, never presented as photographs of a real place.
    let isSynthetic: Bool
    // Quarantine URLs and raw GPS metadata never enter public projections.

    init(id: UUID, approvedParentID: UUID?, creatorCredit: String, altText: String, rightsCleared: Bool, source: MediaSource, isSynthetic: Bool = false) {
        self.id = id
        self.approvedParentID = approvedParentID
        self.creatorCredit = creatorCredit
        self.altText = altText
        self.rightsCleared = rightsCleared
        self.source = source
        self.isSynthetic = isSynthetic
    }
}
