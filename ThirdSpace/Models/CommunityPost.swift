import Foundation
enum PostType: String, Codable, Sendable { case fieldNote, question, update, accessNote, event, reply }
struct CommunityPost: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let placeID: UUID
    let approvedRevisionID: UUID
    let kind: PostType
    let originalLanguage: String
    let body: String
    let publishedAt: Date
    let parentID: UUID?
}
