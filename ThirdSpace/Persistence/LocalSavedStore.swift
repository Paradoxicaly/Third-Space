import Foundation
actor LocalSavedStore {
    private let url: URL
    init(url: URL) { self.url = url }
    func all() throws -> Set<SavedTarget> {
        try ProtectedFile.read(Set<SavedTarget>.self, from: url, default: [])
    }
    func contains(_ target: SavedTarget) throws -> Bool { try all().contains(target) }
    func setSaved(_ target: SavedTarget, saved: Bool) throws {
        var values = try all()
        if saved { values.insert(target) } else { values.remove(target) }
        try ProtectedFile.write(JSONEncoder().encode(values), to: url)
    }
    func clear() throws { try ProtectedFile.write(JSONEncoder().encode(Set<SavedTarget>()), to: url) }
}
