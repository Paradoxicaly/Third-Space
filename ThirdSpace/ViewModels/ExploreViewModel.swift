import Foundation
import SwiftUI

@MainActor final class ExploreViewModel: ObservableObject {
    @Published var query: ExploreQuery
    @Published private(set) var state: LoadState<[Place]> = .loading
    @Published private(set) var totalCount: Int?
    @Published private(set) var nextCursor: PlaceCursor?
    @Published private(set) var notice: String?
    @Published private(set) var queryRestorationProblem: String?
    private let repository: any PlaceRepository
    private let cache: OwnedContentCache
    private let queryURL: URL
    private var generation: UInt64 = 0
    private var currentPlaces: [Place] = []
    private var mayPersistQuery = false

    init(repository: any PlaceRepository, cache: OwnedContentCache, queryURL: URL) {
        self.repository = repository; self.cache = cache; self.queryURL = queryURL
        query = ExploreQuery()
        retryStoredQueryRestoration()
    }

    func retryStoredQueryRestoration() {
        do {
            query = try ProtectedFile.read(ExploreQuery.self, from: queryURL, default: ExploreQuery())
            mayPersistQuery = true
            queryRestorationProblem = nil; notice = nil
        } catch {
            mayPersistQuery = false
            queryRestorationProblem = error is DecodingError
                ? "Stored search data is unreadable or incompatible. The original file is kept; browsing is temporary. Retry restoration or deliberately reset the stored search."
                : "Could not read the stored search. The original data is kept; browsing is temporary. Retry restoration or deliberately reset the stored search."
            notice = queryRestorationProblem
        }
    }

    /// Only this explicit recovery action may replace an unreadable existing query.
    @discardableResult func resetStoredQuery() -> Bool {
        let defaults = ExploreQuery()
        do {
            try ProtectedFile.write(JSONEncoder().encode(defaults), to: queryURL)
            query = defaults; mayPersistQuery = true
            queryRestorationProblem = nil; notice = nil
            return true
        } catch {
            mayPersistQuery = false
            queryRestorationProblem = "Could not finish resetting the stored search. Check available storage or file access, then retry restoration. Browsing remains available."
            notice = queryRestorationProblem
            return false
        }
    }

    func refresh() async {
        generation &+= 1
        let requestedGeneration = generation
        let requestedQuery = query
        currentPlaces = []; nextCursor = nil; totalCount = nil; notice = queryRestorationProblem
        state = .loading
        if mayPersistQuery {
            do { try ProtectedFile.write(JSONEncoder().encode(requestedQuery), to: queryURL) }
            catch { notice = "Could not retain this search for relaunch. Browsing remains available; retry when storage is available." }
        }
        do {
            let page = try await repository.searchPlaces(requestedQuery, cursor: nil, generation: requestedGeneration)
            try Task.checkCancellation()
            guard generation == requestedGeneration, query.queryID == requestedQuery.queryID else { return }
            guard page.queryID == requestedQuery.queryID, page.generation == requestedGeneration else { throw RepositoryError.refreshRequired }
            let eligible = try await cache.excludingInvalidated(page.places)
            guard generation == requestedGeneration, query.queryID == requestedQuery.queryID else { return }
            cache.publishEligible(eligible) { places in
                currentPlaces = places; nextCursor = page.nextCursor
                totalCount = places.count == page.places.count ? page.totalCount : nil
                if places.count != page.places.count { notice = "Withdrawn records are withheld. The current total is unknown; refresh for updated results." }
                state = places.isEmpty ? (page.places.isEmpty ? .empty : .failed("These results were withdrawn. Refresh for current results.")) : .loaded(places)
            }
            do { try await cache.store(currentPlaces, queryID: requestedQuery.queryID, fetchedAt: Date()) }
            catch {
                guard generation == requestedGeneration, query.queryID == requestedQuery.queryID else { return }
                notice = "Places loaded, but could not retain an offline copy. Retry to cache them."
            }
        } catch {
            guard generation == requestedGeneration, query.queryID == requestedQuery.queryID else { return }
            if error is CancellationError || Task.isCancelled { return }
            let snapshot = await cache.snapshot(queryID: requestedQuery.queryID, at: Date())
            guard generation == requestedGeneration, query.queryID == requestedQuery.queryID else { return }
            cache.publishEligible(snapshot?.places ?? []) { places in
                if error as? RepositoryError == .offline {
                    state = .offline(cached: snapshot == nil ? nil : places, asOf: snapshot?.fetchedAt)
                } else if let snapshot {
                    state = .cached(places, asOf: snapshot.fetchedAt)
                } else {
                    state = .failed("Could not load places. Your search is kept. Retry or change the filters.")
                }
            }
        }
    }

    func loadMore() async {
        guard let cursor = nextCursor else { return }
        let requestedQuery = query
        let requestedGeneration = generation
        nextCursor = nil
        do {
            let page = try await repository.searchPlaces(requestedQuery, cursor: cursor, generation: requestedGeneration)
            try Task.checkCancellation()
            guard generation == requestedGeneration, query.queryID == requestedQuery.queryID else { return }
            guard page.queryID == requestedQuery.queryID, page.generation == requestedGeneration, page.watermark == cursor.watermark else { throw RepositoryError.refreshRequired }
            let combined = currentPlaces + page.places
            let eligible = try await cache.excludingInvalidated(combined)
            guard generation == requestedGeneration, query.queryID == requestedQuery.queryID else { return }
            cache.publishEligible(eligible) { places in
                var seen: Set<UUID> = []
                currentPlaces = places.filter { seen.insert($0.id).inserted }
                nextCursor = page.nextCursor
                totalCount = totalCount != nil && places.count == combined.count ? page.totalCount : nil
                state = .loaded(currentPlaces)
            }
            try await cache.store(currentPlaces, queryID: requestedQuery.queryID, fetchedAt: Date())
        } catch {
            guard generation == requestedGeneration, query.queryID == requestedQuery.queryID else { return }
            if error is CancellationError || Task.isCancelled { nextCursor = cursor; return }
            if error as? RepositoryError == .refreshRequired {
                await refresh()
                notice = "Results changed; the list was refreshed."
            } else {
                nextCursor = cursor
                notice = "Could not load the next page. Shown places are retained; retry Load more."
            }
        }
    }
}
