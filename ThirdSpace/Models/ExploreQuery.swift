import Foundation

enum ExploreIntent: String, Codable, CaseIterable, Hashable, Sendable { case focus, meet, unwind, move, create }
enum ExploreSort: String, Codable, Sendable { case relevance, distance, freshness }

struct GeoBounds: Codable, Hashable, Sendable {
    let south: Double
    let west: Double
    let north: Double
    let east: Double
    init?(south: Double, west: Double, north: Double, east: Double) {
        guard south.isFinite, north.isFinite, (-90...90).contains(south), (-90...90).contains(north), south <= north,
              let westPoint = GeoPoint(latitude: 0, longitude: west), let eastPoint = GeoPoint(latitude: 0, longitude: east) else { return nil }
        self.south = south; self.west = westPoint.longitude
        self.north = north; self.east = east == 180 ? 180 : eastPoint.longitude
    }
    private enum CodingKeys: String, CodingKey { case south, west, north, east }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let south = try values.decode(Double.self, forKey: .south)
        let west = try values.decode(Double.self, forKey: .west)
        let north = try values.decode(Double.self, forKey: .north)
        let east = try values.decode(Double.self, forKey: .east)
        guard let validated = GeoBounds(south: south, west: west, north: north, east: east) else {
            throw DecodingError.dataCorruptedError(forKey: .south, in: values, debugDescription: "Invalid WGS84 bounds")
        }
        self = validated
    }
    var longitudeIntervals: [ClosedRange<Double>] {
        west <= east ? [west...east] : [west...180, (-180)...east]
    }
    func contains(_ point: GeoPoint) -> Bool {
        (south...north).contains(point.latitude) && longitudeIntervals.contains { $0.contains(point.longitude) }
    }
}

enum ExploreArea: Codable, Hashable, Sendable { case world, region(String), bounds(GeoBounds) }

struct ExploreQuery: Codable, Hashable, Sendable {
    var area: ExploreArea
    var text: String
    var intents: Set<ExploreIntent>
    var requiredFacts: Set<FactKey>
    var includeUnknown: Bool
    var sort: ExploreSort
    init(area: ExploreArea = .world, text: String = "", intents: Set<ExploreIntent> = [], requiredFacts: Set<FactKey> = [], includeUnknown: Bool = false, sort: ExploreSort = .relevance) {
        self.area = area; self.text = text; self.intents = intents
        self.requiredFacts = requiredFacts; self.includeUnknown = includeUnknown; self.sort = sort
    }
    /// Canonical identity, not Swift's randomized Hasher. Safe to share across list/map requests.
    var queryID: String {
        let areaKey: String
        switch area {
        case .world: areaKey = "world"
        case .region(let id): areaKey = "region:\(Self.normalize(id))"
        case .bounds(let b): areaKey = "bounds:\(b.south),\(b.west),\(b.north),\(b.east)"
        }
        let components = [areaKey, Self.normalize(text), intents.map(\.rawValue).sorted().joined(separator: ","), requiredFacts.map(\.rawValue).sorted().joined(separator: ","), String(includeUnknown), sort.rawValue]
        // Length-prefixed UTF-8 components cannot confuse user text with field boundaries.
        return "q1:" + components.map { "\($0.utf8.count):\($0)" }.joined()
    }
    static func normalize(_ value: String) -> String {
        value.split(whereSeparator: \.isWhitespace).joined(separator: " ").folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }
    func matches(_ place: Place) -> Bool {
        switch area {
        case .world: break
        case .region(let id): if Self.normalize(place.regionID) != Self.normalize(id) { return false }
        case .bounds(let bounds): guard let point = place.location, bounds.contains(point) else { return false }
        }
        if !text.isEmpty && !Self.normalize(place.name).contains(Self.normalize(text)) { return false }
        let supported: Set<ExploreIntent>
        switch place.category {
        case .all: supported = []
        case .study: supported = [.focus]
        case .social: supported = [.meet]
        case .relax: supported = [.unwind]
        case .outdoors: supported = [.move, .unwind]
        case .other: supported = [.create]
        }
        guard intents.isEmpty || !intents.isDisjoint(with: supported) else { return false }
        return requiredFacts.allSatisfy { key in
            let facts = place.facts.filter { $0.key == key }
            // Missing evidence is unknown, not an explicit negative observation.
            guard !facts.isEmpty else { return includeUnknown }
            return facts.contains { $0.matches(key, includeUnknown: includeUnknown) }
        }
    }
}

struct QueryGeneration: Sendable {
    let value: UInt64
    let queryID: String
    func accepts(queryID: String, generation: UInt64) -> Bool { self.queryID == queryID && value == generation }
}
