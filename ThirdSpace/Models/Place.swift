import CoreLocation
import Foundation


enum PlaceCategory: String, CaseIterable, Identifiable, Codable, Sendable {
    case all, study, relax, social, outdoors, other
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .all: "sparkles"
        case .study: "book"
        case .relax: "leaf"
        case .social: "person.2"
        case .outdoors: "figure.walk"
        case .other: "mappin"
        }
    }
}

/// Only independently reviewed public geometry belongs here. Never construct from provider search payloads.
struct GeoPoint: Codable, Hashable, Sendable {
    let latitude: Double
    let longitude: Double
    init?(latitude: Double, longitude: Double) {
        guard latitude.isFinite, (-90...90).contains(latitude), longitude.isFinite else { return nil }
        self.latitude = latitude
        let wrapped = (longitude + 180).truncatingRemainder(dividingBy: 360)
        self.longitude = (wrapped < 0 ? wrapped + 360 : wrapped) - 180
    }
    var coordinate: CLLocationCoordinate2D { .init(latitude: latitude, longitude: longitude) }
    private enum CodingKeys: String, CodingKey { case latitude, longitude }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let latitude = try values.decode(Double.self, forKey: .latitude)
        let longitude = try values.decode(Double.self, forKey: .longitude)
        guard let validated = GeoPoint(latitude: latitude, longitude: longitude) else {
            throw DecodingError.dataCorruptedError(forKey: .latitude, in: values, debugDescription: "Invalid WGS84 coordinate")
        }
        self = validated
    }
}

enum LocationPrecision: String, Codable, Sendable { case exactPublic, approximatePublic, privatePending }

/// An approved own-catalog projection; ID and approved revision are server-assigned, never randomized at decode.
struct Place: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let approvedRevisionID: UUID
    let name: String
    let originalLanguage: String
    let category: PlaceCategory
    let regionID: String
    let location: GeoPoint?
    let precision: LocationPrecision
    let facts: [PlaceFact]
    let media: [MediaAsset]

    init(id: UUID, approvedRevisionID: UUID, name: String, originalLanguage: String, category: PlaceCategory, regionID: String, location: GeoPoint?, precision: LocationPrecision, facts: [PlaceFact], media: [MediaAsset] = []) {
        self.id = id
        self.approvedRevisionID = approvedRevisionID
        self.name = name
        self.originalLanguage = originalLanguage
        self.category = category
        self.regionID = regionID
        self.location = precision == .privatePending ? nil : location
        self.precision = precision
        self.facts = facts
        // Public projections carry only rights-cleared media approved for this record.
        self.media = media.filter { $0.rightsCleared && $0.approvedParentID == id }
    }
    private enum CodingKeys: String, CodingKey { case id, approvedRevisionID, name, originalLanguage, category, regionID, location, precision, facts, media }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try values.decode(UUID.self, forKey: .id),
            approvedRevisionID: try values.decode(UUID.self, forKey: .approvedRevisionID),
            name: try values.decode(String.self, forKey: .name),
            originalLanguage: try values.decode(String.self, forKey: .originalLanguage),
            category: try values.decode(PlaceCategory.self, forKey: .category),
            regionID: try values.decode(String.self, forKey: .regionID),
            location: try values.decodeIfPresent(GeoPoint.self, forKey: .location),
            precision: try values.decode(LocationPrecision.self, forKey: .precision),
            facts: try values.decode([PlaceFact].self, forKey: .facts),
            // Snapshots cached before media existed decode with no images.
            media: try values.decodeIfPresent([MediaAsset].self, forKey: .media) ?? []
        )
    }
    static func == (lhs: Place, rhs: Place) -> Bool { lhs.id == rhs.id && lhs.approvedRevisionID == rhs.approvedRevisionID }
    func hash(into hasher: inout Hasher) { hasher.combine(id); hasher.combine(approvedRevisionID) }

}
