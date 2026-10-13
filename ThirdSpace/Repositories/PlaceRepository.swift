import Foundation
enum RepositoryError: Error, Equatable { case refreshRequired, unavailable, offline }

/// Until a rights-cleared backend is configured, failure is not zero approved coverage.
struct FailClosedPlaceRepository: PlaceRepository {
    func searchPlaces(_ query: ExploreQuery, cursor: PlaceCursor?, generation: UInt64) async throws -> PlacePage {
        throw RepositoryError.unavailable
    }
    func getPlace(_ id: UUID) async throws -> Place? { throw RepositoryError.unavailable }
    func mapSummary(_ query: ExploreQuery, zoomBucket: Int) async throws -> MapSummary {
        throw RepositoryError.unavailable
    }
}
struct PlaceCursor: Codable, Hashable, Sendable {
    let queryID: String
    let generation: UInt64
    let watermark: String
    let offset: Int
}
struct PlacePage: Sendable {
    let places: [Place]
    let queryID: String
    let generation: UInt64
    let watermark: String
    let nextCursor: PlaceCursor?
    let totalCount: Int?
}
enum MapSummary: Sendable {
    case places([Place], truncated: Bool, queryID: String, watermark: String)
    case aggregate([AggregateCell], queryID: String, watermark: String)
}
struct AggregateCell: Sendable {
    let bounds: GeoBounds
    let count: Int
}
protocol PlaceRepository: Sendable {
    func searchPlaces(_ query: ExploreQuery, cursor: PlaceCursor?, generation: UInt64) async throws -> PlacePage
    func getPlace(_ id: UUID) async throws -> Place?
    func mapSummary(_ query: ExploreQuery, zoomBucket: Int) async throws -> MapSummary
}
