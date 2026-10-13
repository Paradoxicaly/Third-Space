import Foundation
struct Region: Identifiable, Codable, Hashable, Sendable {
    let id: String
    let names: [String: String] // BCP-47 -> original/approved local name
    let parentID: String?
    let bounds: GeoBounds?
    /// Optional because a geographic region may span zones. Never infer a venue's clock from viewer locale.
    let timezoneIdentifier: String?
    init(id: String, names: [String: String], parentID: String?, bounds: GeoBounds?, timezoneIdentifier: String? = nil) {
        self.id = id
        self.names = names
        self.parentID = parentID
        self.bounds = bounds
        self.timezoneIdentifier = timezoneIdentifier
    }
}
