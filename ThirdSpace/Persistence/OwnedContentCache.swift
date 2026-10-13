import Foundation

/// Own, approved, ordinary-place snapshots only. No provider DTO or URL is accepted by this API.
actor OwnedContentCache {
    struct Snapshot: Codable, Sendable {
        let places: [Place]
        let fetchedAt: Date
        let expiresAt: Date
    }
    private struct State: Codable { var snapshots: [String: Snapshot] = [:]; var tombstones: Set<UUID> = [] }
    private let url: URL
    private var state: State?
    private nonisolated let invalidations = PublicationInvalidations()
    init(url: URL) { self.url = url }
    private func load() throws -> State {
        if let state { return state }
        let value = try ProtectedFile.read(State.self, from: url, default: State())
        invalidations.include(value.tombstones)
        state = value
        return value
    }
    private func persist(_ value: State) throws {
        // Withhold a known withdrawal even if durable storage subsequently fails.
        invalidations.include(value.tombstones)
        try ProtectedFile.write(JSONEncoder().encode(value), to: url)
        state = value
    }
    func store(_ places: [Place], queryID: String, fetchedAt: Date, hasSensitiveDescendants: Bool = false, savedSnapshot: Bool = false) throws {
        var value = try load()
        let ineligibleIDs = Set(places.filter { hasSensitiveDescendants || $0.precision != .exactPublic }.map(\.id))
        // A newer sensitivity decision invalidates ALL earlier query snapshots, not just this response.
        value.tombstones.formUnion(ineligibleIDs)
        value.snapshots = value.snapshots.mapValues { snapshot in
            Snapshot(places: snapshot.places.filter { !value.tombstones.contains($0.id) }, fetchedAt: snapshot.fetchedAt, expiresAt: snapshot.expiresAt)
        }
        guard !hasSensitiveDescendants else {
            value.snapshots.removeValue(forKey: queryID)
            try persist(value)
            return
        }
        let eligible = places.filter { $0.precision == .exactPublic && !value.tombstones.contains($0.id) }
        value.snapshots[queryID] = Snapshot(places: eligible, fetchedAt: fetchedAt, expiresAt: fetchedAt.addingTimeInterval(savedSnapshot ? 7 * 86_400 : 86_400))
        try persist(value)
    }
    func snapshot(queryID: String, at date: Date) -> Snapshot? {
        guard let value = try? load() else { return nil }
        guard let snapshot = value.snapshots[queryID], date < snapshot.expiresAt else { return nil }
        return Snapshot(places: snapshot.places.filter { !value.tombstones.contains($0.id) }, fetchedAt: snapshot.fetchedAt, expiresAt: snapshot.expiresAt)
    }
    /// Apply server tombstones before displaying retained data on reconnect; IDs cannot re-enter from stale pages.
    func excludingInvalidated(_ places: [Place]) throws -> [Place] {
        let value = try load()
        return places.filter { !value.tombstones.contains($0.id) }
    }
    func isInvalidated(_ id: UUID) -> Bool {
        guard let value = try? load() else { return true }
        return value.tombstones.contains(id)
    }
    func remove(placeIDs: Set<UUID>) throws {
        var value = try load()
        value.tombstones.formUnion(placeIDs)
        value.snapshots = value.snapshots.mapValues { snap in
            Snapshot(places: snap.places.filter { !value.tombstones.contains($0.id) }, fetchedAt: snap.fetchedAt, expiresAt: snap.expiresAt)
        }
        try persist(value)
    }
    /// Synchronous publication on the caller's executor. No await can separate this
    /// final eligibility check from UI assignment; invalidation uses the same lock.
    nonisolated func publishEligible(_ places: [Place], publish: ([Place]) -> Void) {
        invalidations.publishEligible(places, publish: publish)
    }
    func clear() throws { try persist(State()); invalidations.reset() }
}

private final class PublicationInvalidations: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private var ids: Set<UUID> = []
    func include(_ values: Set<UUID>) {
        lock.lock(); defer { lock.unlock() }
        ids.formUnion(values)
    }
    func reset() {
        lock.lock(); defer { lock.unlock() }
        ids = []
    }
    func publishEligible(_ places: [Place], publish: ([Place]) -> Void) {
        lock.lock(); defer { lock.unlock() }
        publish(places.filter { !ids.contains($0.id) })
    }
}

enum ProtectedFile {
    /// Only a genuinely missing file is empty. Unreadable/corrupt files must not be overwritten.
    static func read<Value: Decodable>(_ type: Value.Type, from url: URL, default value: @autoclosure () -> Value) throws -> Value {
        do { return try JSONDecoder().decode(type, from: Data(contentsOf: url)) }
        catch let error as CocoaError where error.code == .fileReadNoSuchFile { return value() }
    }
    static func write(_ data: Data, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        var mutableURL = url
        try mutableURL.setResourceValues(values)
    }
}
