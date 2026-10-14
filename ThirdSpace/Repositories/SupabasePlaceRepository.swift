import Foundation

/// Approved places from Supabase for Explore and Map. RLS already limits anonymous and member reads to
/// approved rows; the explicit `status=eq.approved` filter keeps a moderator's own view public-only here.
struct SupabasePlaceRepository: PlaceRepository {
    let client: SupabaseClient
    private let pageSize = 30
    private let aggregateBelowBucket = 7
    private let mapCap = 200

    private struct Row: Decodable, Sendable {
        struct Source: Decodable, Sendable {
            let sourceTitle, publisher, license, sourceURL, citation, sourceRecordID, coordinateMethod, retrieved: String
            let address: String?
        }
        let id: UUID; let name: String; let category: String
        let latitude: Double; let longitude: Double; let created_at: Date
        let source: Source?
    }
    private struct Point: Decodable, Sendable { let latitude: Double; let longitude: Double }

    private static let columns = "id,name,category,latitude,longitude,created_at,source"

    private func place(_ row: Row) -> Place {
        let provenance = row.source.map {
            PlaceProvenance(reviewStatus: .approved, sourceTitle: $0.sourceTitle, publisher: $0.publisher, license: $0.license,
                            sourceURL: $0.sourceURL, citation: $0.citation, sourceRecordID: $0.sourceRecordID,
                            coordinateMethod: $0.coordinateMethod, retrieved: $0.retrieved, address: $0.address)
        }
        // Revision follows the approval row; a re-approved edit would change created_at in a future revision table.
        return Place(id: row.id, approvedRevisionID: row.id, name: row.name, originalLanguage: "en",
                     category: PlaceCategory(rawValue: row.category) ?? .other, regionID: "community",
                     location: GeoPoint(latitude: row.latitude, longitude: row.longitude), precision: .exactPublic,
                     facts: [], provenance: provenance)
    }

    /// PostgREST filters for the shared Explore query. Text is reduced to letters, digits and spaces so it
    /// cannot alter the filter grammar.
    private func filters(_ query: ExploreQuery) -> [URLQueryItem]? {
        var items = [URLQueryItem(name: "status", value: "eq.approved")]
        var alternatives: [String] = []   // each becomes or(...); several are ANDed together
        let text = query.text.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == " " }.map(String.init).joined()
            .split(separator: " ").joined(separator: " ")
        if !text.isEmpty {
            alternatives.append("name.ilike.*\(text)*,source->>address.ilike.*\(text)*")
        }
        if !query.intents.isEmpty {
            var categories: Set<String> = []
            for intent in query.intents {
                switch intent {
                case .focus: categories.insert("study")
                case .meet: categories.insert("social")
                case .unwind: categories.formUnion(["relax", "outdoors"])
                case .move: categories.insert("outdoors")
                case .create: categories.insert("other")
                }
            }
            items.append(URLQueryItem(name: "category", value: "in.(\(categories.sorted().joined(separator: ",")))"))
        }
        // Community places carry no sourced practical facts yet: a required fact can match only "unknown".
        if !query.requiredFacts.isEmpty && !query.includeUnknown { return nil }
        if case .bounds(let bounds) = query.area {
            items.append(URLQueryItem(name: "latitude", value: "gte.\(bounds.south)"))
            items.append(URLQueryItem(name: "latitude", value: "lte.\(bounds.north)"))
            if bounds.west <= bounds.east {
                items.append(URLQueryItem(name: "longitude", value: "gte.\(bounds.west)"))
                items.append(URLQueryItem(name: "longitude", value: "lte.\(bounds.east)"))
            } else {
                // Antimeridian: two longitude intervals.
                alternatives.append("longitude.gte.\(bounds.west),longitude.lte.\(bounds.east)")
            }
        }
        if alternatives.count == 1 { items.append(URLQueryItem(name: "or", value: "(\(alternatives[0]))")) }
        if alternatives.count > 1 { items.append(URLQueryItem(name: "and", value: "(\(alternatives.map { "or(\($0))" }.joined(separator: ",")))")) }
        return items
    }

    func searchPlaces(_ query: ExploreQuery, cursor: PlaceCursor?, generation: UInt64) async throws -> PlacePage {
        let watermark = "live"
        if let cursor, cursor.queryID != query.queryID || cursor.generation != generation { throw RepositoryError.refreshRequired }
        guard let items = filters(query) else {
            return PlacePage(places: [], queryID: query.queryID, generation: generation, watermark: watermark, nextCursor: nil, totalCount: 0)
        }
        let offset = cursor?.offset ?? 0
        let page = try await mapErrors {
            try await client.select("places", query: [URLQueryItem(name: "select", value: Self.columns)] + items +
                                    [URLQueryItem(name: "order", value: "name.asc,id.asc"), URLQueryItem(name: "limit", value: "\(pageSize)"),
                                     URLQueryItem(name: "offset", value: "\(offset)")], count: true, as: Row.self)
        }
        let places = page.rows.map(place)
        let total = page.total
        let next = offset + places.count < (total ?? 0) ? PlaceCursor(queryID: query.queryID, generation: generation, watermark: watermark, offset: offset + places.count) : nil
        return PlacePage(places: places, queryID: query.queryID, generation: generation, watermark: watermark, nextCursor: next, totalCount: total)
    }

    func getPlace(_ id: UUID) async throws -> Place? {
        try await mapErrors {
            try await client.select("places", query: [URLQueryItem(name: "select", value: Self.columns), URLQueryItem(name: "id", value: "eq.\(id)"),
                                                      URLQueryItem(name: "status", value: "eq.approved")], as: Row.self).rows.first.map(place)
        }
    }

    func mapSummary(_ query: ExploreQuery, zoomBucket: Int) async throws -> MapSummary {
        guard let items = filters(query) else { return .places([], truncated: false, queryID: query.queryID, watermark: "live") }
        if zoomBucket < aggregateBelowBucket {
            let points = try await mapErrors {
                try await client.select("places", query: [URLQueryItem(name: "select", value: "latitude,longitude")] + items + [URLQueryItem(name: "limit", value: "10000")], as: Point.self).rows
            }
            let cells = MockPlaceRepository.gridCells(points.compactMap { GeoPoint(latitude: $0.latitude, longitude: $0.longitude) }, zoomBucket: zoomBucket)
            return .aggregate(cells, queryID: query.queryID, watermark: "live")
        }
        let rows = try await mapErrors {
            try await client.select("places", query: [URLQueryItem(name: "select", value: Self.columns)] + items + [URLQueryItem(name: "limit", value: "\(mapCap + 1)")], as: Row.self).rows
        }
        return .places(rows.prefix(mapCap).map(place), truncated: rows.count > mapCap, queryID: query.queryID, watermark: "live")
    }

    /// Keep Explore's offline/outage distinction.
    private func mapErrors<T>(_ work: () async throws -> T) async throws -> T {
        do { return try await work() }
        catch CommunityError.offline { throw RepositoryError.offline }
        catch is CommunityError { throw RepositoryError.unavailable }
    }
}
