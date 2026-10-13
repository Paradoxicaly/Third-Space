import Foundation
struct PlaceEvent: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let placeID: UUID
    let title: String
    let timezoneIdentifier: String
    let startsAt: Date
    let endsAt: Date
    let isCancelled: Bool
}
