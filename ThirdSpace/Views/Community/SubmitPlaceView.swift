import MapKit
import SwiftUI

/// Submit a new place for human review. The member types the street address and sets the pin (map centre or typed
/// coordinates); the address is never geocoded and no provider search result or POI is stored.
struct SubmitPlaceView: View {
    @ObservedObject var community: CommunityStore
    let startingCenter: GeoPoint?
    @State private var name = ""
    @State private var category: PlaceCategory = .study
    @State private var details = ""
    @State private var address = PlaceAddress()
    @State private var latitude = ""
    @State private var longitude = ""
    @State private var working = false
    @State private var error: String?
    @State private var submitted: SubmittedPlace?
    @State private var showingAccount = false

    private var location: GeoPoint? {
        guard let lat = Double(latitude.replacingOccurrences(of: ",", with: ".")), let lon = Double(longitude.replacingOccurrences(of: ",", with: ".")),
              (-180...180).contains(lon) else { return nil }
        return GeoPoint(latitude: lat, longitude: lon)
    }

    private var addressComplete: Bool {
        [address.street, address.city, address.country].allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    var body: some View {
        Group {
            if let submitted {
                confirmation(submitted)
            } else if !community.isSignedIn {
                VStack(spacing: FieldGuide.Spacing.base) {
                    ContentUnavailableView("Sign in to submit a place", systemImage: "person.crop.circle.badge.plus",
                                           description: Text("Submissions are reviewed by a moderator before anyone else can see them."))
                    Button("Sign in or create account") { showingAccount = true }.buttonStyle(FieldGuideActionStyle()).padding()
                }
            } else {
                form
            }
        }
        .navigationTitle("Submit a place")
        .sheet(isPresented: $showingAccount) { AccountView(community: community) }
        .onAppear {
            if latitude.isEmpty, let start = startingCenter {
                latitude = String(format: "%.5f", start.latitude); longitude = String(format: "%.5f", start.longitude)
            }
        }
    }

    private var form: some View {
        Form {
            Section {
                Text("Your submission stays private until a moderator approves it. Add places that people can actually visit.")
                    .foregroundStyle(FieldGuide.Palette.secondary)
            }
            Section("About the place") {
                TextField("Name", text: $name, prompt: Text("Name").foregroundColor(FieldGuide.Palette.secondary))
                    .accessibilityIdentifier("submit-name")
                Picker("Category", selection: $category) {
                    ForEach(PlaceCategory.allCases.filter { $0 != .all }) { category in
                        Label(category.rawValue.capitalized, systemImage: category.icon).tag(category)
                    }
                }
                TextField("Description", text: $details, prompt: Text("What makes it a good third space?").foregroundColor(FieldGuide.Palette.secondary), axis: .vertical)
                    .lineLimit(3...8)
                    .accessibilityIdentifier("submit-description")
            }
            Section {
                TextField("Street address", text: $address.street, prompt: Text("123 Main St, Suite 4").foregroundColor(FieldGuide.Palette.secondary))
                    .textContentType(.fullStreetAddress).textInputAutocapitalization(.words)
                    .accessibilityIdentifier("submit-street")
                TextField("City or town", text: $address.city, prompt: Text("City or town").foregroundColor(FieldGuide.Palette.secondary))
                    .textContentType(.addressCity).textInputAutocapitalization(.words)
                    .accessibilityIdentifier("submit-city")
                TextField("State or region (optional)", text: $address.region, prompt: Text("State, province or region (optional)").foregroundColor(FieldGuide.Palette.secondary))
                    .textContentType(.addressState).textInputAutocapitalization(.words)
                    .accessibilityIdentifier("submit-region")
                TextField("Postal code (optional)", text: $address.postalCode, prompt: Text("Postal or ZIP code (optional)").foregroundColor(FieldGuide.Palette.secondary))
                    .textContentType(.postalCode).textInputAutocapitalization(.characters)
                    .accessibilityIdentifier("submit-postal-code")
                TextField("Country", text: $address.country, prompt: Text("Country").foregroundColor(FieldGuide.Palette.secondary))
                    .textContentType(.countryName).textInputAutocapitalization(.words)
                    .accessibilityIdentifier("submit-country")
            } header: {
                Text("Address")
            } footer: {
                Text("Use the address a visitor would find on the door or the venue's own website. Include the building number, and the suite or floor if the place is inside a larger building. For a park or trail, use the main entrance or nearest street address. Street, city and country are required. A moderator checks it against your pin.")
            }
            Section {
                LocationPicker(latitude: $latitude, longitude: $longitude)
                    .frame(height: 220)
                    .listRowInsets(EdgeInsets())
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Map for choosing the location. Move the map so the pin sits on the place, or type coordinates below.")
                TextField("Latitude", text: $latitude, prompt: Text("Latitude").foregroundColor(FieldGuide.Palette.secondary))
                    .keyboardType(.numbersAndPunctuation).accessibilityIdentifier("submit-latitude")
                TextField("Longitude", text: $longitude, prompt: Text("Longitude").foregroundColor(FieldGuide.Palette.secondary))
                    .keyboardType(.numbersAndPunctuation).accessibilityIdentifier("submit-longitude")
            } header: {
                Text("Location")
            } footer: {
                Text("Drag the map so the pin sits on the entrance, or type coordinates. Place the pin yourself; it is not looked up from the address, and only the position you choose is saved. Make sure it matches the address above.")
            }
            if let error {
                Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(FieldGuide.Palette.destructive)
                    .accessibilityIdentifier("submit-error")
            }
            Button {
                Task { await submit() }
            } label: { Text(working ? "Submitting…" : "Submit for review") }
                .buttonStyle(FieldGuideActionStyle())
                .disabled(working || name.trimmingCharacters(in: .whitespaces).isEmpty || location == nil || !addressComplete)
                .listRowBackground(Color.clear)
        }
    }

    private func submit() async {
        guard let location else { error = "Enter a valid latitude and longitude."; return }
        working = true; error = nil
        community.message = nil
        if let result = await community.submit(PlaceSubmissionDraft(name: name, category: category, description: details, location: location, address: address)) {
            submitted = result
        } else {
            error = community.message ?? "Could not submit. Your entries are kept; try again."
        }
        working = false
    }

    private func confirmation(_ place: SubmittedPlace) -> some View {
        VStack(alignment: .leading, spacing: FieldGuide.Spacing.base) {
            Label("Submitted — pending review", systemImage: "clock")
                .font(.title2.weight(.semibold)).foregroundStyle(FieldGuide.Palette.warning)
                .accessibilityIdentifier("submission-pending")
            Text("“\(place.name)” is waiting for a moderator. Only you can see it until it's approved. You'll find the decision under Profile → My submissions.")
            Spacer()
        }
        .padding(FieldGuide.Spacing.base)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(FieldGuide.Palette.canvas)
    }
}

/// Map with a fixed centre pin; moving the map updates the coordinate fields and vice versa.
private struct LocationPicker: UIViewRepresentable {
    @Binding var latitude: String
    @Binding var longitude: String

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        let configuration = MKStandardMapConfiguration()
        configuration.pointOfInterestFilter = .excludingAll
        map.preferredConfiguration = configuration
        map.delegate = context.coordinator
        let pin = UIImageView(image: UIImage(systemName: "mappin", withConfiguration: UIImage.SymbolConfiguration(pointSize: 30, weight: .bold)))
        pin.tintColor = UIColor(FieldGuide.Palette.action)
        pin.translatesAutoresizingMaskIntoConstraints = false
        map.addSubview(pin)
        NSLayoutConstraint.activate([pin.centerXAnchor.constraint(equalTo: map.centerXAnchor),
                                     pin.bottomAnchor.constraint(equalTo: map.centerYAnchor)])
        if let lat = Double(latitude), let lon = Double(longitude) {
            map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: lat, longitude: lon), span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)), animated: false)
        }
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        guard let lat = Double(latitude), let lon = Double(longitude), (-90...90).contains(lat), (-180...180).contains(lon),
              !context.coordinator.isUpdatingFromMap else { return }
        let center = map.centerCoordinate
        if abs(center.latitude - lat) > 0.00001 || abs(center.longitude - lon) > 0.00001 {
            map.setCenter(CLLocationCoordinate2D(latitude: lat, longitude: lon), animated: false)
        }
    }

    @MainActor final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: LocationPicker
        var isUpdatingFromMap = false
        init(_ parent: LocationPicker) { self.parent = parent }

        private var userMoved = false

        // Only a drag/pinch writes coordinates back; programmatic moves from typed text must not rewrite it.
        func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
            userMoved = (mapView.subviews.first?.gestureRecognizers ?? []).contains { $0.state == .began || $0.state == .changed || $0.state == .ended }
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            guard userMoved else { return }
            userMoved = false
            isUpdatingFromMap = true
            parent.latitude = String(format: "%.5f", mapView.centerCoordinate.latitude)
            parent.longitude = String(format: "%.5f", mapView.centerCoordinate.longitude)
            isUpdatingFromMap = false
        }
    }
}
