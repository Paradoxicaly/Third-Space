import Foundation

/// Bundled open-data candidates produced by `scripts/import-open-candidates.py`. Unreviewed: usable only
/// behind the DEBUG `--candidates` flag until human review and rights sign-off approve them.
struct OpenDataCandidateCatalog: Sendable {
    let notice: String
    let regions: [Region]
    let places: [Place]

    private struct File: Decodable {
        struct Source: Decodable { let id, title, publisher, license, url, citation: String }
        struct RegionRecord: Decodable { let id, name: String }
        struct Record: Decodable {
            let id, revisionID: UUID
            let name, regionID, sourceID, sourceRecordID, coordinateMethod, address: String
            let category: PlaceCategory
            let precision: LocationPrecision
            let latitude, longitude: Double
            let facts: [PlaceFact]
        }
        let schemaVersion: Int
        let status, notice, retrieved: String
        let sources: [Source]
        let regions: [RegionRecord]
        let places: [Record]
    }

    enum LoadError: Error { case missing, unsupported, unknownSource(String) }

    static func load(from bundle: Bundle) throws -> OpenDataCandidateCatalog {
        guard let url = bundle.url(forResource: "california-candidates", withExtension: "json") else { throw LoadError.missing }
        let file = try JSONDecoder().decode(File.self, from: Data(contentsOf: url))
        guard file.schemaVersion == 1, file.status == "unreviewedCandidates" else { throw LoadError.unsupported }
        let sources = Dictionary(uniqueKeysWithValues: file.sources.map { ($0.id, $0) })
        let places = try file.places.map { record -> Place in
            guard let source = sources[record.sourceID] else { throw LoadError.unknownSource(record.sourceID) }
            let provenance = PlaceProvenance(reviewStatus: .unreviewedCandidate, sourceTitle: source.title, publisher: source.publisher,
                                             license: source.license, sourceURL: source.url, citation: source.citation,
                                             sourceRecordID: record.sourceRecordID, coordinateMethod: record.coordinateMethod,
                                             retrieved: file.retrieved, address: record.address)
            return Place(id: record.id, approvedRevisionID: record.revisionID, name: record.name, originalLanguage: "en",
                         category: record.category, regionID: record.regionID,
                         location: GeoPoint(latitude: record.latitude, longitude: record.longitude),
                         precision: record.precision, facts: record.facts, provenance: provenance)
        }
        let regions = file.regions.map { Region(id: $0.id, names: ["en": $0.name], parentID: "us-ca", bounds: nil, timezoneIdentifier: "America/Los_Angeles") }
        return OpenDataCandidateCatalog(notice: file.notice, regions: regions, places: places)
    }
}

actor CandidatePlaceRepository: PlaceRepository {
    private let places: [Place]
    private let pageSize = 30
    private let watermark: String
    /// Dense data: area counts until roughly a 3° span, then capped individual places.
    private let aggregateBelowBucket = 7
    private let mapCap = 200

    init(catalog: OpenDataCandidateCatalog) {
        places = catalog.places
        watermark = "candidates-\(catalog.places.count)"
    }

    func searchPlaces(_ query: ExploreQuery, cursor: PlaceCursor?, generation: UInt64) async throws -> PlacePage {
        if let cursor, cursor.queryID != query.queryID || cursor.generation != generation || cursor.watermark != watermark {
            throw RepositoryError.refreshRequired
        }
        let matching = places.filter(query.matches)
        let start = cursor?.offset ?? 0
        guard start >= 0, start <= matching.count else { throw RepositoryError.refreshRequired }
        let page = Array(matching.dropFirst(start).prefix(pageSize))
        let next = start + page.count < matching.count ? PlaceCursor(queryID: query.queryID, generation: generation, watermark: watermark, offset: start + page.count) : nil
        return PlacePage(places: page, queryID: query.queryID, generation: generation, watermark: watermark, nextCursor: next, totalCount: matching.count)
    }

    func getPlace(_ id: UUID) async throws -> Place? { places.first { $0.id == id } }

    func mapSummary(_ query: ExploreQuery, zoomBucket: Int) async throws -> MapSummary {
        let matching = places.filter(query.matches)
        if zoomBucket < aggregateBelowBucket {
            return .aggregate(MockPlaceRepository.gridCells(matching.compactMap(\.location), zoomBucket: zoomBucket), queryID: query.queryID, watermark: watermark)
        }
        return .places(Array(matching.prefix(mapCap)), truncated: matching.count > mapCap, queryID: query.queryID, watermark: watermark)
    }
}
