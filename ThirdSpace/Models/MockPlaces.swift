import Foundation

extension Place {
    /// Visibly fictional fixtures. Access only through the launch-gated mock repository.
    #if DEBUG
    private static func syntheticFacts(cost: FactValue, noise: FactValue, wifi: FactValue, outdoors: FactValue) -> [PlaceFact] {
        let source = FactSource(kind: .syntheticFixture, observedAt: Date(timeIntervalSince1970: 1_700_000_000), attribution: "SYNTHETIC fixture author — invented test evidence, not a real venue observation")
        return [
            PlaceFact(key: .cost, value: cost, source: source),
            PlaceFact(key: .noise, value: noise, source: source),
            PlaceFact(key: .wifi, value: wifi, source: source),
            PlaceFact(key: .outdoors, value: outdoors, source: source),
            PlaceFact(key: .seating, value: .yes, source: source),
            PlaceFact(key: .stepFreeEntrance, value: .unknown, source: source),
            PlaceFact(key: .hours, value: .unknown, source: source)
        ]
    }
    private static func syntheticMedia(_ placeNumber: Int, _ items: [(name: String, alt: String)]) -> [MediaAsset] {
        let parent = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", placeNumber))!
        return items.enumerated().map { index, item in
            MediaAsset(id: UUID(uuidString: String(format: "00000000-0000-0000-0001-%08d%04d", placeNumber, index))!,
                       approvedParentID: parent,
                       creatorCredit: "SYNTHETIC test image — generated pattern, not a photograph of this place",
                       altText: "Synthetic abstract illustration: \(item.alt). Not a photograph of this place.",
                       rightsCleared: true, source: .bundled(name: item.name), isSynthetic: true)
        }
    }
    static let syntheticUITestFixtures: [Place] = [
        Place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!, approvedRevisionID: UUID(uuidString: "00000000-0000-0000-0000-000000001101")!, name: "SYNTHETIC — Reading Room", originalLanguage: "en", category: .study, regionID: "test-west", location: GeoPoint(latitude: 34.1, longitude: -118.1), precision: .exactPublic, facts: syntheticFacts(cost: .free, noise: .quiet, wifi: .yes, outdoors: .no), media: syntheticMedia(101, [("synthetic-media-reading-room", "rows of coloured bands suggesting shelves"), ("synthetic-media-reading-room-window", "a grid of window panes")])),
        Place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!, approvedRevisionID: UUID(uuidString: "00000000-0000-0000-0000-000000001102")!, name: "SYNTHETIC — مكتبة تجريبية", originalLanguage: "ar", category: .social, regionID: "test-east", location: GeoPoint(latitude: 25.2, longitude: 55.3), precision: .exactPublic, facts: syntheticFacts(cost: .purchaseExpected, noise: .lively, wifi: .unknown, outdoors: .no), media: syntheticMedia(102, [("synthetic-media-library", "round teal shapes on a warm background")])),
        Place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000103")!, approvedRevisionID: UUID(uuidString: "00000000-0000-0000-0000-000000001103")!, name: "SYNTHETIC — 架空の庭", originalLanguage: "ja", category: .outdoors, regionID: "test-islands", location: GeoPoint(latitude: -17.7, longitude: 179.5), precision: .exactPublic, facts: syntheticFacts(cost: .free, noise: .moderate, wifi: .no, outdoors: .yes)),
        Place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000104")!, approvedRevisionID: UUID(uuidString: "00000000-0000-0000-0000-000000001104")!, name: "SYNTHETIC — Demonstration Garden", originalLanguage: "en", category: .relax, regionID: "test-islands", location: GeoPoint(latitude: -18, longitude: -179.5), precision: .exactPublic, facts: syntheticFacts(cost: .paid, noise: .quiet, wifi: .unknown, outdoors: .yes), media: syntheticMedia(104, [("synthetic-media-garden", "layered green hills under a yellow circle")])),
        Place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000105")!, approvedRevisionID: UUID(uuidString: "00000000-0000-0000-0000-000000001105")!, name: "SYNTHETIC — परीक्षण अध्ययन कक्ष", originalLanguage: "ne", category: .study, regionID: "test-quarter", location: GeoPoint(latitude: 27.7, longitude: 85.3), precision: .exactPublic, facts: syntheticFacts(cost: .free, noise: .quiet, wifi: .yes, outdoors: .no)),
        Place(id: UUID(uuidString: "00000000-0000-0000-0000-000000000106")!, approvedRevisionID: UUID(uuidString: "00000000-0000-0000-0000-000000001106")!, name: "SYNTHETIC — Southern Workshop", originalLanguage: "en", category: .other, regionID: "test-south", location: GeoPoint(latitude: -34.9, longitude: 138.6), precision: .exactPublic, facts: syntheticFacts(cost: .paid, noise: .moderate, wifi: .no, outdoors: .unknown), media: syntheticMedia(106, [("synthetic-media-workshop", "diagonal stripes with two solid blocks")]))
    ]
    #else
    static let syntheticUITestFixtures: [Place] = []
    #endif
}

extension Region {
    /// Synthetic labels and relationships only. These are not geographic coverage claims.
    #if DEBUG
    static let syntheticUITestFixtures: [Region] = [
        Region(id: "test-west", names: ["en": "SYNTHETIC — West"], parentID: nil, bounds: nil, timezoneIdentifier: "America/Los_Angeles"),
        Region(id: "test-east", names: ["en": "SYNTHETIC — East", "ar": "SYNTHETIC — منطقة تجريبية"], parentID: nil, bounds: nil, timezoneIdentifier: "Asia/Dubai"),
        Region(id: "test-islands", names: ["en": "SYNTHETIC — Islands", "ja": "SYNTHETIC — 架空の島々"], parentID: nil, bounds: nil, timezoneIdentifier: "Pacific/Fiji"),
        Region(id: "test-quarter", names: ["en": "SYNTHETIC — Quarter-hour region", "ne": "SYNTHETIC — परीक्षण क्षेत्र"], parentID: nil, bounds: nil, timezoneIdentifier: "Asia/Kathmandu"),
        Region(id: "test-south", names: ["en": "SYNTHETIC — South"], parentID: nil, bounds: nil, timezoneIdentifier: "Australia/Adelaide")
    ]
    #else
    static let syntheticUITestFixtures: [Region] = []
    #endif
}
