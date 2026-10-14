import Foundation

/// Synthetic data is explicit and launch-gated. Never select this adapter as a production network fallback.
actor MockPlaceRepository: PlaceRepository {
    private let places: [Place]
    private let enabled: Bool
    private let pageSize: Int
    private let isOffline: Bool
    private let failOnce: Bool
    private let delayNanoseconds: UInt64
    private enum Operation: Hashable { case search, detail, map }
    private var failedOperations: Set<Operation> = []
    private let watermark = "synthetic-revision-1"
    /// Synthetic community submissions approved by the on-device moderator join the public catalog.
    private let approvedSubmissions: (@Sendable () async -> [Place])?
    init(launchArguments: [String] = ProcessInfo.processInfo.arguments, pageSize: Int = 30, slowDelayNanoseconds: UInt64 = 500_000_000,
         approvedSubmissions: (@Sendable () async -> [Place])? = nil) {
        self.approvedSubmissions = approvedSubmissions
        #if DEBUG
        self.enabled = launchArguments.contains("--ui-testing")
        self.places = enabled && !launchArguments.contains("--empty") ? Place.syntheticUITestFixtures : []
        self.isOffline = launchArguments.contains("--offline")
        self.failOnce = launchArguments.contains("--error")
        self.delayNanoseconds = launchArguments.contains("--slow") ? slowDelayNanoseconds : 0
        #else
        self.enabled = false
        self.places = []
        self.isOffline = false
        self.failOnce = false
        self.delayNanoseconds = 0
        #endif
        self.pageSize = max(1, min(30, pageSize))
    }
    /// Offline persists; --error fails exactly once per operation so list/map races cannot consume each other's failure.
    private func prepare(_ operation: Operation) async throws {
        guard enabled else { throw RepositoryError.unavailable }
        try Task.checkCancellation()
        if delayNanoseconds > 0 { try await Task.sleep(nanoseconds: delayNanoseconds) }
        try Task.checkCancellation()
        if isOffline { throw RepositoryError.offline }
        if failOnce, failedOperations.insert(operation).inserted { throw RepositoryError.unavailable }
    }
    private func allPlaces() async -> [Place] { places + (await approvedSubmissions?() ?? []) }
    func searchPlaces(_ query: ExploreQuery, cursor: PlaceCursor?, generation: UInt64) async throws -> PlacePage {
        try await prepare(.search)
        if let cursor, cursor.queryID != query.queryID || cursor.generation != generation || cursor.watermark != watermark {
            throw RepositoryError.refreshRequired
        }
        let matching = await allPlaces().filter(query.matches).sorted { $0.id.uuidString < $1.id.uuidString }
        let start = cursor?.offset ?? 0
        guard start >= 0, start <= matching.count else { throw RepositoryError.refreshRequired }
        let page = Array(matching.dropFirst(start).prefix(pageSize))
        let next = start + page.count < matching.count ? PlaceCursor(queryID: query.queryID, generation: generation, watermark: watermark, offset: start + page.count) : nil
        return PlacePage(places: page, queryID: query.queryID, generation: generation, watermark: watermark, nextCursor: next, totalCount: matching.count)
    }
    func getPlace(_ id: UUID) async throws -> Place? {
        try await prepare(.detail)
        return await allPlaces().first { $0.id == id }
    }
    func mapSummary(_ query: ExploreQuery, zoomBucket: Int) async throws -> MapSummary {
        try await prepare(.map)
        let matching = await allPlaces().filter(query.matches)
        if zoomBucket < 3 {
            return .aggregate(Self.gridCells(matching.compactMap(\.location), zoomBucket: zoomBucket), queryID: query.queryID, watermark: watermark)
        }
        return .places(Array(matching.prefix(200)), truncated: matching.count > 200, queryID: query.queryID, watermark: watermark)
    }
    /// Fixed lat/long grid (45° at world scale, halving per bucket). Cells are aligned to -180/-90 so a
    /// place beside the antimeridian falls in exactly one cell; cells carry counts, never member points.
    static func gridCells(_ points: [GeoPoint], zoomBucket: Int) -> [AggregateCell] {
        let size = 45 / pow(2, Double(max(0, zoomBucket)))
        var counts: [[Int]: Int] = [:]
        for point in points {
            let row = min(Int((point.latitude + 90) / size), Int(180 / size) - 1)
            let column = min(Int((point.longitude + 180) / size), Int(360 / size) - 1)
            counts[[row, column], default: 0] += 1
        }
        return counts.sorted { $0.key.lexicographicallyPrecedes($1.key) }.compactMap { key, count in
            let south = -90 + Double(key[0]) * size, west = -180 + Double(key[1]) * size
            return GeoBounds(south: south, west: west, north: min(90, south + size), east: min(180, west + size)).map { AggregateCell(bounds: $0, count: count) }
        }
    }
}

actor MockCommunityRepository: CommunityRepository {
    func posts(placeID: UUID, kind: PostType?, cursor: UUID?) async throws -> [CommunityPost] { [] }
}
actor MockSubmissionRepository: SubmissionRepository {
    func submit(_ submission: Submission) async throws -> Submission { throw RepositoryError.unavailable } // no remote publication without staffed backend
    func findDuplicates(name: String, regionID: String) async throws -> [Place] { [] }
}
actor LocalSavedRepository: SavedRepository {
    private let store: LocalSavedStore
    init(store: LocalSavedStore) { self.store = store }
    func savedItems() async throws -> Set<SavedTarget> { try await store.all() }
    func setSaved(_ target: SavedTarget, saved: Bool) async throws { try await store.setSaved(target, saved: saved) }
    func collections() async throws -> [SavedCollection] { [] }
}
actor MockFeaturedRepository: FeaturedRepository {
    func activeItems(regionID: String?, at date: Date) async throws -> [FeaturedItem] { [] }
}
actor MockProfileRepository: ProfileRepository {
    func publicProfile(id: UUID) async throws -> PublicProfile? { nil }
}
