import Foundation

/// Where a place record came from. Required for every imported record; "approved" is set only by
/// server-side human review, never by an importer.
struct PlaceProvenance: Codable, Hashable, Sendable {
    enum ReviewStatus: String, Codable, Sendable { case unreviewedCandidate, approved }

    let reviewStatus: ReviewStatus
    let sourceTitle: String
    let publisher: String
    let license: String
    let sourceURL: String
    let citation: String
    let sourceRecordID: String
    let coordinateMethod: String
    let retrieved: String
    let address: String?
}
