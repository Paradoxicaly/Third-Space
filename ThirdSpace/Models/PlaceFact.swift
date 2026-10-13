import Foundation

enum FactKey: String, Codable, CaseIterable, Sendable { case cost, noise, seating, wifi, outlets, indoors, outdoors, stepFreeEntrance, accessibleToilet, transit, hours }
enum FactValue: String, Codable, Sendable { case yes, no, unknown, free, purchaseExpected, paid, quiet, moderate, lively }
enum SourceKind: String, Codable, Sendable { case communityObservation, authorizedOrganization, licensedSource, syntheticFixture }
struct FactSource: Codable, Hashable, Sendable {
    let kind: SourceKind
    let observedAt: Date
    let attribution: String
}
struct PlaceFact: Codable, Hashable, Sendable {
    let key: FactKey
    let value: FactValue
    let source: FactSource
    /// Unknown is never asserted as true. Hours require a separate licensed, timezone-aware schedule.
    func knownOpen(at date: Date) -> Bool? { nil }
    func matches(_ requirement: FactKey, includeUnknown: Bool) -> Bool {
        guard key == requirement else { return false }
        if value == .unknown { return includeUnknown }
        return value == .yes || value == .free || value == .quiet
    }
}
