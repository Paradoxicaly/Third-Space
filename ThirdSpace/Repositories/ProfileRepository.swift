import Foundation
struct PublicProfile: Identifiable, Sendable {
    let id: UUID
    let pseudonym: String
    let preferredLocale: String?
}
protocol ProfileRepository: Sendable {
    func publicProfile(id: UUID) async throws -> PublicProfile?
}
