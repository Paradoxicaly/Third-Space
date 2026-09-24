import CoreLocation

extension Place {
    static let examples: [Place] = [
        Place(
            name: "Juniper & Bean",
            category: .study,
            subtitle: "Sunlit coffee shop with long tables",
            address: "1452 Oak Avenue",
            distance: "0.4 mi",
            rating: 4.8,
            reviewCount: 126,
            imageName: "cup.and.saucer.fill",
            isOpen: true,
            amenities: ["Wi-Fi", "Outlets", "Quiet corners", "Pastries"],
            vibe: "Quiet • Warm • Great for focus",
            description: "A bright neighborhood coffee shop with reliable Wi-Fi, plenty of outlets, and room to settle in with a project.",
            coordinate: CLLocationCoordinate2D(latitude: 34.1478, longitude: -118.1445)
        ),
        Place(
            name: "Civic Reading Room",
            category: .study,
            subtitle: "Free library space with garden views",
            address: "82 Library Lane",
            distance: "0.7 mi",
            rating: 4.9,
            reviewCount: 89,
            imageName: "books.vertical.fill",
            isOpen: true,
            amenities: ["Free", "Wi-Fi", "Silent floor", "Accessible"],
            vibe: "Peaceful • Focused • Free",
            description: "A calm public reading room with large shared tables, a quiet floor, and a small courtyard just outside.",
            coordinate: CLLocationCoordinate2D(latitude: 34.1512, longitude: -118.1415)
        ),
        Place(
            name: "Arroyo Community Garden",
            category: .outdoors,
            subtitle: "Open-air tables surrounded by native plants",
            address: "310 Arroyo Drive",
            distance: "1.1 mi",
            rating: 4.7,
            reviewCount: 42,
            imageName: "leaf.fill",
            isOpen: true,
            amenities: ["Free", "Outdoor seating", "Dog-friendly", "Water fountain"],
            vibe: "Open • Relaxed • Community-minded",
            description: "A welcoming community garden with shaded tables, weekend workshops, and an easygoing neighborhood feel.",
            coordinate: CLLocationCoordinate2D(latitude: 34.1450, longitude: -118.1512)
        ),
        Place(
            name: "The Common Table",
            category: .social,
            subtitle: "Community hub for games, food, and events",
            address: "65 Market Street",
            distance: "1.4 mi",
            rating: 4.6,
            reviewCount: 67,
            imageName: "person.2.fill",
            isOpen: false,
            amenities: ["Events", "Food", "Accessible", "Group tables"],
            vibe: "Lively • Social • Casual",
            description: "A casual community venue with rotating events, shared tables, and food from local vendors.",
            coordinate: CLLocationCoordinate2D(latitude: 34.1550, longitude: -118.1500)
        )
    ]
}
