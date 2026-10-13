import Foundation
import SwiftUI

@MainActor final class AppEnvironment: ObservableObject {
    let isSynthetic: Bool
    let launchArguments: [String]
    let repository: any PlaceRepository
    let cache: OwnedContentCache
    let drafts: DraftStore
    let explore: ExploreViewModel
    let map: MapViewModel
    private let saved: any SavedRepository
    private var restorationGeneration: UInt64 = 0
    @Published private(set) var savedIDs: Set<UUID> = []
    @Published private(set) var savedPlaces: [Place] = []
    @Published private(set) var localDrafts: [Submission] = []
    @Published var persistenceError: String?
    @Published var savedAsOf: Date?

    init(arguments: [String] = ProcessInfo.processInfo.arguments, storageDirectory: URL? = nil, repository: (any PlaceRepository)? = nil) {
        #if DEBUG
        isSynthetic = arguments.contains("--ui-testing")
        launchArguments = isSynthetic ? arguments : []
        #else
        isSynthetic = false
        launchArguments = []
        #endif
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let folder = storageDirectory ?? support.appendingPathComponent("ThirdSpaces/\(isSynthetic ? "SyntheticUITests" : "Local")", isDirectory: true)
        if isSynthetic && arguments.contains("--reset-local-data") {
            // Only the dedicated synthetic test namespace can be reset by a launch flag.
            do { if FileManager.default.fileExists(atPath: folder.path) { try FileManager.default.removeItem(at: folder) } }
            catch { persistenceError = "Could not reset synthetic test storage." }
        }
        self.repository = repository ?? (isSynthetic ? MockPlaceRepository(launchArguments: arguments, pageSize: 2, slowDelayNanoseconds: 15_000_000_000) : FailClosedPlaceRepository())
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


