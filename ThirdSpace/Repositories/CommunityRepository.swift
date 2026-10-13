import Foundation
protocol CommunityRepository: Sendable {
    func posts(placeID: UUID, kind: PostType?, cursor: UUID?) async throws -> [CommunityPost]
}
