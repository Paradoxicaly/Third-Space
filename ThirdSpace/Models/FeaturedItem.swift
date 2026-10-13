import Foundation
struct FeaturedItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let targetID: UUID
    let curator: String
    let reason: String
    let startsAt: Date
    let endsAt: Date
    func isActive(at date: Date) -> Bool { startsAt <= date && date < endsAt }
}
