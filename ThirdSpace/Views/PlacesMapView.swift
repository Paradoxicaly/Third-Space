import MapKit
import SwiftUI

struct PlacesMapView: View {
    @State private var selectedPlace: Place?

    private let region = MKCoordinateRegion(
        center: CLLocationCoordinate2D(latitude: 34.1494, longitude: -118.1467),
        span: MKCoordinateSpan(latitudeDelta: 0.025, longitudeDelta: 0.025)
    )

    var body: some View {
        NavigationStack {
            Map(initialPosition: .region(region), selection: $selectedPlace) {
                ForEach(Place.examples) { place in
                    Marker(place.name, systemImage: place.imageName, coordinate: place.coordinate)
                        .tint(Color.thirdCoral)
                        .tag(place)
                }
            }
            .mapStyle(.standard(elevation: .realistic))
            .overlay(alignment: .bottom) {
                if let selectedPlace {
                    NavigationLink(value: selectedPlace) {
                        PlaceCard(place: selectedPlace)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 10)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Tap a pin to learn about a space")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 11)
                        .background(.ultraThinMaterial, in: Capsule())
                        .padding(.bottom, 18)
                }
            }
            .navigationTitle("Explore the map")
            .navigationDestination(for: Place.self) { place in
                PlaceDetailView(place: place)
            }
        }
    }
}
