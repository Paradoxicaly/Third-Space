import Foundation
import SwiftUI

@MainActor final class AppEnvironment: ObservableObject {
    /// What the catalog contains. Release builds are always fail-closed until a reviewed backend exists.
    enum CatalogMode: Equatable { case failClosed, synthetic, candidates, live }

    let catalogMode: CatalogMode
    let isSynthetic: Bool
    /// Area choices for Explore; empty when there is no catalog.
    let regions: [Region]
    let launchArguments: [String]
    let repository: any PlaceRepository
    let cache: OwnedContentCache
    let drafts: DraftStore
    let explore: ExploreViewModel
    /// Accounts, submissions, moderation and engagement; nil when no community backend is configured.
    let community: CommunityStore?
    let map: MapViewModel
    private let saved: any SavedRepository
    private var restorationGeneration: UInt64 = 0
    @Published private(set) var savedIDs: Set<UUID> = []
    @Published private(set) var savedPlaces: [Place] = []
    @Published private(set) var localDrafts: [Submission] = []
    @Published var persistenceError: String?
    @Published var savedAsOf: Date?

    /// `supabaseConfig` is passed only by the app entry point, so tests never reach a live project by accident.
    init(arguments: [String] = ProcessInfo.processInfo.arguments, storageDirectory: URL? = nil, repository: (any PlaceRepository)? = nil,
         supabaseConfig: SupabaseConfig? = nil) {
        #if DEBUG
        catalogMode = arguments.contains("--ui-testing") ? .synthetic : arguments.contains("--candidates") ? .candidates : supabaseConfig != nil ? .live : .failClosed
        #else
        catalogMode = supabaseConfig != nil ? .live : .failClosed
        #endif
        isSynthetic = catalogMode == .synthetic
        launchArguments = catalogMode == .synthetic || catalogMode == .candidates ? arguments : []
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let namespace = switch catalogMode { case .synthetic: "SyntheticUITests"; case .candidates: "CandidateCatalog"; case .failClosed, .live: "Local" }
        let folder = storageDirectory ?? support.appendingPathComponent("ThirdSpaces/\(namespace)", isDirectory: true)
        if (catalogMode == .synthetic || catalogMode == .candidates) && arguments.contains("--reset-local-data") {
            // Only the dedicated synthetic/candidate namespaces can be reset by a launch flag.
            do { if FileManager.default.fileExists(atPath: folder.path) { try FileManager.default.removeItem(at: folder) } }
            catch { persistenceError = "Could not reset local test storage." }
        }
        var candidateRegions: [Region] = []
        var candidateRepository: (any PlaceRepository)?
        if catalogMode == .candidates {
            do {
                let catalog = try OpenDataCandidateCatalog.load(from: Bundle(for: AppEnvironment.self))
                candidateRegions = catalog.regions
                candidateRepository = CandidatePlaceRepository(catalog: catalog)
            } catch { persistenceError = "Could not load the bundled candidate catalog." }
        }
        regions = isSynthetic ? Region.syntheticUITestFixtures : candidateRegions
        switch catalogMode {
        case .synthetic:
            let service = InMemoryCommunityService(url: folder.appendingPathComponent("community.json"), catalogPlaces: Place.syntheticUITestFixtures)
            community = CommunityStore(service: service, isTestBackend: true)
            self.repository = repository ?? MockPlaceRepository(launchArguments: arguments, pageSize: 2, slowDelayNanoseconds: 15_000_000_000,
                                                                approvedSubmissions: { await service.approvedPlaces() })
        case .live:
            let client = SupabaseClient(config: supabaseConfig!)
            community = CommunityStore(service: LiveCommunityService(client: client), isTestBackend: false)
            self.repository = repository ?? SupabasePlaceRepository(client: client)
        case .candidates, .failClosed:
            community = nil
            self.repository = repository ?? candidateRepository ?? FailClosedPlaceRepository()
        }
        #if DEBUG
        // Only the isolated synthetic UI-test namespace; never ordinary local data.
        if isSynthetic && arguments.contains("--malformed-query") {
            do { try ProtectedFile.write(Data("SYNTHETIC unreadable query fixture".utf8), to: folder.appendingPathComponent("query.json")) }
            catch { persistenceError = "Could not prepare the synthetic query-restoration test." }
        }
        #endif
        cache = OwnedContentCache(url: folder.appendingPathComponent("owned-cache.json"))
        drafts = DraftStore(url: folder.appendingPathComponent("drafts.json"))
        saved = LocalSavedRepository(store: LocalSavedStore(url: folder.appendingPathComponent("saved.json")))
        explore = ExploreViewModel(repository: self.repository, cache: cache, queryURL: folder.appendingPathComponent("query.json"))
        map = MapViewModel(repository: self.repository, cache: cache)
    }

    func restoreLocalState() async {
        restorationGeneration &+= 1
        let requestedGeneration = restorationGeneration
        do {
            let items = try await saved.savedItems()
            guard restorationGeneration == requestedGeneration else { return }
            let restoredIDs = Set(items.compactMap { if case .place(let id) = $0 { return id }; return nil })
            var restored: [Place] = []
            var oldestSnapshot: Date?
            for id in restoredIDs.sorted(by: { $0.uuidString < $1.uuidString }) {
                guard !(await cache.isInvalidated(id)) else { continue }
                let snapshot = await cache.snapshot(queryID: "saved:\(id.uuidString)", at: Date())
                if let snapshot, let place = snapshot.places.first {
                    restored.append(place)
                    oldestSnapshot = min(oldestSnapshot ?? snapshot.fetchedAt, snapshot.fetchedAt)
                } else if let place = try? await repository.getPlace(id), !(await cache.isInvalidated(id)) { restored.append(place) }
            }
            let restoredDrafts = try await drafts.all()
            let eligible = try await cache.excludingInvalidated(restored)
            cache.publishEligible(eligible) { places in
                guard restorationGeneration == requestedGeneration else { return }
                savedIDs = restoredIDs
                savedPlaces = places; savedAsOf = oldestSnapshot
                localDrafts = restoredDrafts
            }
        } catch {
            guard restorationGeneration == requestedGeneration else { return }
            persistenceError = "Could not load local saves or drafts. Retry from Saved; your existing files are kept."
        }
    }

    /// Honesty label shown on browse surfaces whenever records are not approved catalog data.
    var catalogNotice: String? {
        switch catalogMode {
        case .synthetic: "Synthetic demo · not verified places"
        case .candidates: "Unreviewed open-data candidates · not verified"
        case .failClosed, .live: nil
        }
    }

    /// What a map count is counting, spoken and shown on area bubbles.
    var recordNoun: String {
        switch catalogMode {
        case .synthetic: "synthetic place"
        case .candidates: "candidate place"
        case .failClosed, .live: "approved place"
        }
    }

    /// Opening map frame: the catalog's own coverage when it is known, otherwise the world. Never the user's location.
    var initialMapViewport: MapViewport? {
        catalogMode == .candidates ? MapViewport(centerLatitude: 37.2, centerLongitude: -119.4, latitudeDelta: 10.5, longitudeDelta: 10.5) : nil
    }

    func isSaved(_ place: Place) -> Bool { savedIDs.contains(place.id) }
    func toggleSaved(_ place: Place) async {
        let shouldSave = !isSaved(place)
        // Invalidate late restoration before the first mutation suspension, not only after it completes.
        restorationGeneration &+= 1
        do {
            // Persist a protected eligible snapshot first; never imply a save succeeded after an I/O error.
            if shouldSave { try await cache.store([place], queryID: "saved:\(place.id.uuidString)", fetchedAt: Date(), savedSnapshot: true) }
            try await saved.setSaved(.place(place.id), saved: shouldSave)
            await restoreLocalState()
        } catch { persistenceError = "Could not save on this device. The previous saved state is kept. Retry." }
    }
    func keepDraft(id: UUID, kind: SubmissionKind, text: String, language: String = "en") async -> Bool {
        do {
            try await drafts.put(Submission(id: id, kind: kind, originalLanguage: language, body: text, state: .localDraft))
            localDrafts = try await drafts.all()
            return true
        } catch {
            persistenceError = "Could not keep this draft on your device. Your text is still in the form; retry before closing."
            return false
        }
    }
    func removeDraft(_ id: UUID) async {
        do { try await drafts.remove(id); localDrafts = try await drafts.all() }
        catch { persistenceError = "Could not remove the local draft. Retry." }
    }
}


