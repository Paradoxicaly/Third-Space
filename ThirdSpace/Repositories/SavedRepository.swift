import Foundation
protocol SavedRepository: Sendable {
    func savedItems() async throws -> Set<SavedTarget>
    func setSaved(_ target: SavedTarget, saved: Bool) async throws
    func collections() async throws -> [SavedCollection]
}
