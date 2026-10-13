import Foundation
enum SavedTarget: Codable, Hashable, Sendable { case place(UUID), post(UUID) }
struct SavedCollection: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var title: String
    var items: [SavedTarget]
}
