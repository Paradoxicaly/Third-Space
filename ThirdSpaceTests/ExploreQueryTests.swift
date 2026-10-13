import XCTest
@testable import ThirdSpace

final class ExploreQueryTests: XCTestCase {
    func testAntimeridianSplitsAndIncludesBothSides() {
        let bounds = GeoBounds(south: -10, west: 170, north: 10, east: -170)!
        XCTAssertEqual(bounds.longitudeIntervals.count, 2)
        XCTAssertTrue(bounds.contains(GeoPoint(latitude: 0, longitude: 179)!))
        XCTAssertTrue(bounds.contains(GeoPoint(latitude: 0, longitude: -179)!))
        XCTAssertFalse(bounds.contains(GeoPoint(latitude: 0, longitude: 0)!))
        XCTAssertNil(GeoBounds(south: -91, west: 0, north: 1, east: 1))
        let world = GeoBounds(south: -90, west: -180, north: 90, east: 180)!
        XCTAssertTrue(world.contains(GeoPoint(latitude: 0, longitude: 0)!))
    }

    func testDecodedBoundsRejectInvalidLatitudeAndOrdering() throws {
        for json in [
            #"{"south":-91,"west":0,"north":10,"east":1}"#,
            #"{"south":20,"west":0,"north":10,"east":1}"#,
            #"{"south":0,"west":0,"north":91,"east":1}"#
        ] {
            XCTAssertThrowsError(try JSONDecoder().decode(GeoBounds.self, from: Data(json.utf8)))
        }
    }

    func testDecodedBoundsNormalizeLongitudeAndPreserveWorldSpan() throws {
        let decoded = try JSONDecoder().decode(GeoBounds.self, from: Data(#"{"south":-10,"west":181,"north":10,"east":190}"#.utf8))
        XCTAssertEqual(decoded.west, -179)
        XCTAssertEqual(decoded.east, -170)
        let world = GeoBounds(south: -90, west: -180, north: 90, east: 180)!
        let restored = try JSONDecoder().decode(GeoBounds.self, from: JSONEncoder().encode(world))
        XCTAssertEqual(restored.east, 180)
        XCTAssertTrue(restored.contains(GeoPoint(latitude: 0, longitude: 0)!))
    }

    func testIntentIsOrAndPracticalRequirementsAreAnd() {
        let source = FactSource(kind: .communityObservation, observedAt: .distantPast, attribution: "SYNTHETIC")
        let place = Place(id: UUID(), approvedRevisionID: UUID(), name: "SYNTHETIC", originalLanguage: "en", category: .study, regionID: "test", location: nil, precision: .exactPublic, facts: [PlaceFact(key: .wifi, value: .yes, source: source), PlaceFact(key: .stepFreeEntrance, value: .unknown, source: source)])
        let query = ExploreQuery(area: .region("test"), intents: [.focus, .meet], requiredFacts: [.wifi, .stepFreeEntrance])
        XCTAssertFalse(query.matches(place))
        XCTAssertTrue(ExploreQuery(area: .region("test"), intents: [.focus, .meet], requiredFacts: [.wifi, .stepFreeEntrance], includeUnknown: true).matches(place))
        XCTAssertFalse(ExploreQuery(area: .region("test"), intents: [.move], requiredFacts: [.wifi], includeUnknown: true).matches(place))
    }

    func testMissingFactsAreUnknownButExplicitNegativeIsNot() {
        let missing = Place(id: UUID(), approvedRevisionID: UUID(), name: "SYNTHETIC", originalLanguage: "en", category: .study, regionID: "test", location: nil, precision: .exactPublic, facts: [])
        let source = FactSource(kind: .communityObservation, observedAt: .distantPast, attribution: "SYNTHETIC")
        let negative = Place(id: UUID(), approvedRevisionID: UUID(), name: "SYNTHETIC", originalLanguage: "en", category: .study, regionID: "test", location: nil, precision: .exactPublic, facts: [PlaceFact(key: .wifi, value: .no, source: source)])
        XCTAssertFalse(ExploreQuery(requiredFacts: [.wifi]).matches(missing))
        XCTAssertTrue(ExploreQuery(requiredFacts: [.wifi, .outlets], includeUnknown: true).matches(missing))
        XCTAssertFalse(ExploreQuery(requiredFacts: [.wifi, .outlets], includeUnknown: true).matches(negative))
    }

    func testNormalizedQueryIDAndGenerationRejectOldPages() {
        let first = ExploreQuery(area: .region(" TEST "), text: "  QUIET   ROOM ", intents: [.focus, .meet])
        let second = ExploreQuery(area: .region("test"), text: "quiet room", intents: [.meet, .focus])
        XCTAssertEqual(first.queryID, second.queryID)
        XCTAssertTrue(QueryGeneration(value: 3, queryID: first.queryID).accepts(queryID: second.queryID, generation: 3))
        XCTAssertFalse(QueryGeneration(value: 3, queryID: first.queryID).accepts(queryID: second.queryID, generation: 2))
    }

    func testQueryIdentityCannotCollideWhenTextContainsSeparators() {
        let first = ExploreQuery(area: .region("SYNTHETIC-a|b"), text: "c")
        let second = ExploreQuery(area: .region("SYNTHETIC-a"), text: "b|c")
        XCTAssertNotEqual(first.queryID, second.queryID)
    }
}
