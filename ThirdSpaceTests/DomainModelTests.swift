import XCTest
@testable import ThirdSpace

final class DomainModelTests: XCTestCase {
    func testWireValuesHaveSeparateHumanReadableLabels() {
        XCTAssertEqual(FactValue.purchaseExpected.rawValue, "purchaseExpected")
        XCTAssertEqual(FactValue.purchaseExpected.displayName, "Purchase expected")
        XCTAssertEqual(SubmissionKind.newPlace.rawValue, "newPlace")
        XCTAssertEqual(SubmissionKind.newPlace.displayName, "New place")
    }

    func testStableIdentityAndOriginalScriptSurviveCoding() throws {
        let place = Place(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, approvedRevisionID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, name: "مكتبة تجريبية — SYNTHETIC", originalLanguage: "ar", category: .study, regionID: "test-region", location: .init(latitude: 12, longitude: 179), precision: .exactPublic, facts: [])
        let restored = try JSONDecoder().decode(Place.self, from: JSONEncoder().encode(place))
        XCTAssertEqual(restored.id, place.id)
        XCTAssertEqual(restored.name, place.name)
        XCTAssertEqual(restored.originalLanguage, "ar")
        XCTAssertEqual(restored.approvedRevisionID, place.approvedRevisionID)
    }

    func testSyntheticFixturesAreSourcedInDebugAndAbsentFromRelease() {
        #if DEBUG
        XCTAssertGreaterThanOrEqual(Place.syntheticUITestFixtures.count, 4)
        for place in Place.syntheticUITestFixtures {
            XCTAssertTrue(place.name.hasPrefix("SYNTHETIC"))
            XCTAssertFalse(place.facts.isEmpty)
            XCTAssertTrue(place.facts.allSatisfy { $0.source.attribution.contains("SYNTHETIC") })
            XCTAssertTrue(place.facts.allSatisfy { $0.source.kind.rawValue == "syntheticFixture" })
            XCTAssertTrue(place.facts.contains { $0.key == .hours && $0.value == .unknown })
        }
        XCTAssertEqual(Place.syntheticUITestFixtures.first?.id, UUID(uuidString: "00000000-0000-0000-0000-000000000101"))
        XCTAssertEqual(Place.syntheticUITestFixtures.first?.name, "SYNTHETIC — Reading Room")
        #else
        XCTAssertTrue(Place.syntheticUITestFixtures.isEmpty)
        #endif
    }

    func testRegionTimezoneIsOptionalAndSurvivesCoding() throws {
        let legacy = Data(#"{"id":"test","names":{"ar":"SYNTHETIC — منطقة تجريبية"}}"#.utf8)
        let restored = try JSONDecoder().decode(Region.self, from: legacy)
        XCTAssertNil(restored.timezoneIdentifier)
        let region = Region(id: "test", names: ["ne": "SYNTHETIC — परीक्षण क्षेत्र"], parentID: nil, bounds: nil, timezoneIdentifier: "Asia/Kathmandu")
        let roundTrip = try JSONDecoder().decode(Region.self, from: JSONEncoder().encode(region))
        XCTAssertEqual(roundTrip.timezoneIdentifier, "Asia/Kathmandu")
        XCTAssertEqual(roundTrip.names, region.names)
    }

    func testSyntheticRegionsIncludeScriptAndTimezoneVariation() {
        #if DEBUG
        let regions = Region.syntheticUITestFixtures
        XCTAssertGreaterThanOrEqual(regions.count, 5)
        for region in regions {
            XCTAssertTrue(region.names.values.allSatisfy { $0.contains("SYNTHETIC") })
            XCTAssertNotNil(region.timezoneIdentifier.flatMap(TimeZone.init(identifier:)))
        }
        XCTAssertTrue(regions.contains { $0.names["ar"] != nil })
        XCTAssertTrue(regions.contains { $0.names["ja"] != nil })
        XCTAssertTrue(regions.contains { $0.timezoneIdentifier == "Asia/Kathmandu" })
        XCTAssertTrue(regions.contains { $0.timezoneIdentifier == "Australia/Adelaide" })
        XCTAssertTrue(Place.syntheticUITestFixtures.allSatisfy { place in regions.contains { $0.id == place.regionID } })
        #else
        XCTAssertTrue(Region.syntheticUITestFixtures.isEmpty)
        #endif
    }

    func testUnknownAccessAndHoursNeverBecomeConfirmed() {
        let fact = PlaceFact(key: .stepFreeEntrance, value: .unknown, source: .init(kind: .communityObservation, observedAt: Date(timeIntervalSince1970: 1_700_000_000), attribution: "Synthetic observation"))
        XCTAssertFalse(fact.matches(.stepFreeEntrance, includeUnknown: false))
        XCTAssertTrue(fact.matches(.stepFreeEntrance, includeUnknown: true))
        XCTAssertNil(PlaceFact(key: .hours, value: .unknown, source: fact.source).knownOpen(at: Date()))
    }

    func testInvalidCoordinatesCannotBecomePublicGeometry() {
        XCTAssertNil(GeoPoint(latitude: 91, longitude: 0))
        XCTAssertNil(GeoPoint(latitude: .nan, longitude: 0))
        XCTAssertEqual(GeoPoint(latitude: 0, longitude: 181)?.longitude, -179)
    }

    func testDecodedCoordinatesAreValidatedToo() throws {
        let raw = Data(#"{"latitude":91,"longitude":0}"#.utf8)
        XCTAssertThrowsError(try JSONDecoder().decode(GeoPoint.self, from: raw))
    }

    func testDecodedPrivatePlaceCannotExposeGeometry() throws {
        let place = Place(id: UUID(), approvedRevisionID: UUID(), name: "SYNTHETIC", originalLanguage: "en", category: .other, regionID: "test", location: GeoPoint(latitude: 1, longitude: 2), precision: .exactPublic, facts: [])
        let encoded = String(decoding: try JSONEncoder().encode(place), as: UTF8.self)
        let malicious = encoded.replacingOccurrences(of: "exactPublic", with: "privatePending")
        let decoded = try JSONDecoder().decode(Place.self, from: Data(malicious.utf8))
        XCTAssertNil(decoded.location)
    }
}
