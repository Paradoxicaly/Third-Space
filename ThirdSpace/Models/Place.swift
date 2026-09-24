import CoreLocation
import SwiftUI

enum PlaceCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case study = "Study"
    case relax = "Relax"
    case social = "Social"
    case outdoors = "Outdoors"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .all: "sparkles"
        case .study: "books.vertical.fill"
        case .relax: "cup.and.saucer.fill"
        case .social: "person.2.fill"
        case .outdoors: "leaf.fill"
        }
    }
}

struct Place: Identifiable, Hashable {
    let id: UUID
    let name: String
    let category: PlaceCategory
    let subtitle: String
    let address: String
    let distance: String
    let rating: Double
    let reviewCount: Int
    let imageName: String
    let isOpen: Bool
    let amenities: [String]
    let vibe: String
    let description: String
    let coordinate: CLLocationCoordinate2D

    init(
        id: UUID = UUID(),
        name: String,
        category: PlaceCategory,
        subtitle: String,
        address: String,
        distance: String,
        rating: Double,
        reviewCount: Int,
        imageName: String,
        isOpen: Bool,
        amenities: [String],
        vibe: String,
        description: String,
        coordinate: CLLocationCoordinate2D
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.subtitle = subtitle
        self.address = address
        self.distance = distance
        self.rating = rating
        self.reviewCount = reviewCount
        self.imageName = imageName
        self.isOpen = isOpen
        self.amenities = amenities
        self.vibe = vibe
        self.description = description
        self.coordinate = coordinate
    }

    static func == (lhs: Place, rhs: Place) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

@MainActor
final class PlaceStore: ObservableObject {
    @Published private(set) var savedIDs: Set<UUID> = []

    func isSaved(_ place: Place) -> Bool {
        savedIDs.contains(place.id)
    }

    func toggleSaved(_ place: Place) {
        if savedIDs.contains(place.id) {
            savedIDs.remove(place.id)
        } else {
            savedIDs.insert(place.id)
        }
    }
}
