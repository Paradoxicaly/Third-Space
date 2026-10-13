import Foundation
import SwiftUI

/// Map display state. Filters come from the shared Explore query; the viewport replaces its area
/// only for what the map shows, until the user explicitly lists that area.
@MainActor final class MapViewModel: ObservableObject {
    enum Content {
        case loading
        case aggregate([AggregateCell])
        case places([Place], truncated: Bool)
        case offline
        case failed(String)
    }

    @Published private(set) var content: Content = .loading
    @Published var selectedPlaceID: UUID?
    @Published private(set) var viewport: MapViewport?
    private let repository: any PlaceRepository
    private let cache: OwnedContentCache
    private var generation: UInt64 = 0

    init(repository: any PlaceRepository, cache: OwnedContentCache) {
        self.repository = repository
        self.cache = cache
    }

    var selectedPlace: Place? {
        guard let selectedPlaceID, case .places(let places, _) = content else { return nil }
        return places.first { $0.id == selectedPlaceID }
    }

    func load(viewport: MapViewport, filters: ExploreQuery) async {
        generation &+= 1
        let requestedGeneration = generation
        self.viewport = viewport
        var query = filters
        query.area = viewport.bounds.map(ExploreArea.bounds) ?? .world
        do {
            let summary = try await repository.mapSummary(query, zoomBucket: viewport.zoomBucket)
            try Task.checkCancellation()
            guard generation == requestedGeneration else { return }
            switch summary {
            case .aggregate(let cells, _, _):
                selectedPlaceID = nil
                content = .aggregate(cells)
            case .places(let places, let truncated, _, _):
                let eligible = try await cache.excludingInvalidated(places)
                guard generation == requestedGeneration else { return }
                cache.publishEligible(eligible) { published in
                    content = .places(published, truncated: truncated)
                    if let selectedPlaceID, !published.contains(where: { $0.id == selectedPlaceID }) { self.selectedPlaceID = nil }
                }
            }
        } catch {
            guard generation == requestedGeneration, !(error is CancellationError), !Task.isCancelled else { return }
            selectedPlaceID = nil
            // Never substitute sample markers; the list remains the fallback.
            content = error as? RepositoryError == .offline ? .offline : .failed("Could not load map places. The list remains available; retry.")
        }
    }
}
