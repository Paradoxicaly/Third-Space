import Foundation
actor DraftStore {
    private let url: URL
    init(url: URL) { self.url = url }
    func all() throws -> [Submission] {
        try ProtectedFile.read([Submission].self, from: url, default: [])
    }
    func put(_ draft: Submission) throws {
        guard draft.state == .localDraft else { return }
        var drafts = try all().filter { $0.id != draft.id }
        drafts.append(draft)
        try ProtectedFile.write(JSONEncoder().encode(drafts), to: url)
    }
    func remove(_ id: UUID) throws { try ProtectedFile.write(JSONEncoder().encode(try all().filter { $0.id != id }), to: url) }
    func clear() throws { try ProtectedFile.write(JSONEncoder().encode([Submission]()), to: url) }
}
