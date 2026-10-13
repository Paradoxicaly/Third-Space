import Foundation
protocol FeaturedRepository: Sendable {
    func activeItems(regionID: String?, at date: Date) async throws -> [FeaturedItem]
}
