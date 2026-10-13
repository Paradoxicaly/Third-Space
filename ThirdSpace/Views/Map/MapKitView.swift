import MapKit
import SwiftUI
import UIKit

/// MKMapView for display and native clustering only. Owned places are the only markers; Apple
/// points of interest are hidden so provider POIs never masquerade as catalog records.
struct MapKitView: UIViewRepresentable {
    let content: MapViewModel.Content
    let selectedPlaceID: UUID?
    let initialViewport: MapViewport?
    let isSynthetic: Bool
    let onViewportChange: (MapViewport) -> Void
    let onSelectPlace: (UUID?) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        let configuration = MKStandardMapConfiguration()
        configuration.pointOfInterestFilter = .excludingAll
        map.preferredConfiguration = configuration
        map.showsUserLocation = false // no location prompt; browsing is permission-free
        map.delegate = context.coordinator
        map.register(PlacePinView.self, forAnnotationViewWithReuseIdentifier: PlacePinView.reuseID)
        map.register(AreaCountView.self, forAnnotationViewWithReuseIdentifier: AreaCountView.reuseID)
        map.register(ClusterCountView.self, forAnnotationViewWithReuseIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier)
        let start = initialViewport ?? MapViewport(centerLatitude: 20, centerLongitude: 0, latitudeDelta: 140, longitudeDelta: 359.9)
        map.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: start.centerLatitude, longitude: start.centerLongitude),
                                         span: MKCoordinateSpan(latitudeDelta: start.latitudeDelta, longitudeDelta: start.longitudeDelta)), animated: false)
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        context.coordinator.sync(map)
    }

    @MainActor final class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapKitView
        private var places: [UUID: PlaceAnnotation] = [:]
        private var cells: [String: AreaAnnotation] = [:]
        /// Last selection applied in either direction; only changes flow from SwiftUI to the map,
        /// so an update carrying not-yet-published state cannot undo a fresh tap.
        private var appliedSelection: UUID?

        init(parent: MapKitView) { self.parent = parent }

        private var animates: Bool { !UIAccessibility.isReduceMotionEnabled }

        func sync(_ map: MKMapView) {
            switch parent.content {
            case .loading:
                return // keep current markers while the next viewport loads
            case .aggregate(let newCells):
                replacePlaces(with: [], on: map)
                replaceCells(with: newCells, on: map)
            case .places(let newPlaces, _):
                replaceCells(with: [], on: map)
                replacePlaces(with: newPlaces.filter { $0.location != nil }, on: map)
            case .offline, .failed:
                replaceCells(with: [], on: map)
                replacePlaces(with: [], on: map)
            }
            guard parent.selectedPlaceID != appliedSelection else { return }
            appliedSelection = parent.selectedPlaceID
            if let id = parent.selectedPlaceID, let annotation = places[id] {
                map.selectAnnotation(annotation, animated: animates)
            } else {
                map.selectedAnnotations.forEach { map.deselectAnnotation($0, animated: animates) }
            }
        }

        private func replacePlaces(with newPlaces: [Place], on map: MKMapView) {
            let wanted = Dictionary(newPlaces.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
            let stale = places.filter { id, annotation in wanted[id].map { $0.approvedRevisionID != annotation.place.approvedRevisionID } ?? true }
            map.removeAnnotations(Array(stale.values))
            stale.keys.forEach { places[$0] = nil }
            let added = wanted.values.filter { places[$0.id] == nil }.compactMap(PlaceAnnotation.init)
            added.forEach { places[$0.place.id] = $0 }
            map.addAnnotations(added)
        }

        private func replaceCells(with newCells: [AggregateCell], on map: MKMapView) {
            let wanted = Dictionary(newCells.map { (AreaAnnotation.key(for: $0), $0) }, uniquingKeysWith: { first, _ in first })
            let stale = cells.filter { wanted[$0.key] == nil }
            map.removeAnnotations(Array(stale.values))
            stale.keys.forEach { cells[$0] = nil }
            let added = wanted.filter { cells[$0.key] == nil }.map { AreaAnnotation(cell: $0.value) }
            added.forEach { cells[$0.key] = $0 }
            map.addAnnotations(added)
        }

        func mapView(_ mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
            let region = mapView.region
            parent.onViewportChange(MapViewport(centerLatitude: region.center.latitude, centerLongitude: region.center.longitude,
                                                latitudeDelta: region.span.latitudeDelta, longitudeDelta: region.span.longitudeDelta))
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            switch annotation {
            case let place as PlaceAnnotation:
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: PlacePinView.reuseID, for: place) as? PlacePinView
                view?.configure(place.place)
                return view
            case let area as AreaAnnotation:
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: AreaCountView.reuseID, for: area) as? AreaCountView
                view?.configure(area.cell, synthetic: parent.isSynthetic)
                return view
            case let cluster as MKClusterAnnotation:
                let view = mapView.dequeueReusableAnnotationView(withIdentifier: MKMapViewDefaultClusterAnnotationViewReuseIdentifier, for: cluster) as? ClusterCountView
                view?.configure(count: cluster.memberAnnotations.count, synthetic: parent.isSynthetic)
                return view
            default:
                return nil
            }
        }

        func mapView(_ mapView: MKMapView, didSelect annotation: any MKAnnotation) {
            switch annotation {
            case let place as PlaceAnnotation:
                appliedSelection = place.place.id
                // Centre first: the preview then shortens the map around the marker instead of
                // pushing it out of the viewport (which would drop it from the results).
                mapView.setCenter(place.coordinate, animated: animates)
                parent.onSelectPlace(place.place.id)
            case let cluster as MKClusterAnnotation:
                mapView.deselectAnnotation(cluster, animated: false)
                mapView.showAnnotations(cluster.memberAnnotations, animated: animates)
            case let area as AreaAnnotation:
                mapView.deselectAnnotation(area, animated: false)
                mapView.setRegion(area.region, animated: animates)
            default:
                break
            }
        }

        func mapView(_ mapView: MKMapView, didDeselect annotation: any MKAnnotation) {
            guard let place = annotation as? PlaceAnnotation, appliedSelection == place.place.id else { return }
            appliedSelection = nil
            parent.onSelectPlace(nil)
        }
    }
}

final class PlaceAnnotation: NSObject, MKAnnotation {
    let place: Place
    let coordinate: CLLocationCoordinate2D
    var title: String? { place.name }

    init?(_ place: Place) {
        guard let location = place.location else { return nil }
        self.place = place
        coordinate = location.coordinate
    }
}

final class AreaAnnotation: NSObject, MKAnnotation {
    let cell: AggregateCell
    let key: String
    let coordinate: CLLocationCoordinate2D

    init(cell: AggregateCell) {
        self.cell = cell
        key = Self.key(for: cell)
        // Cells never cross ±180°, so the midpoint is the cell centre.
        coordinate = CLLocationCoordinate2D(latitude: (cell.bounds.south + cell.bounds.north) / 2, longitude: (cell.bounds.west + cell.bounds.east) / 2)
    }

    static func key(for cell: AggregateCell) -> String {
        "\(cell.bounds.south),\(cell.bounds.west),\(cell.bounds.north),\(cell.bounds.east),\(cell.count)"
    }

    var region: MKCoordinateRegion {
        MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: cell.bounds.north - cell.bounds.south, longitudeDelta: cell.bounds.east - cell.bounds.west))
    }
}

private enum PinColors {
    static let cream = UIColor(red: 0xF7 / 255, green: 0xF5 / 255, blue: 0xEC / 255, alpha: 1)
    static let forest = UIColor(FieldGuide.Brand.forest)
    static let action = UIColor(FieldGuide.Palette.action)
    static let onAction = UIColor(FieldGuide.Palette.onAction)
    static let surface = UIColor(FieldGuide.Palette.surface)
    static let primary = UIColor(FieldGuide.Palette.primary)
}

/// Round photo marker (category symbol on forest when there is no approved photo).
final class PlacePinView: MKAnnotationView {
    static let reuseID = "place-pin"
    private let imageView = UIImageView()
    private let size: CGFloat = 52

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        frame = CGRect(x: 0, y: 0, width: size, height: size)
        clusteringIdentifier = "owned-place"
        collisionMode = .circle
        canShowCallout = false
        layer.cornerRadius = size / 2
        layer.borderWidth = 1
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.1
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 3)
        imageView.frame = bounds.insetBy(dx: 4, dy: 4)
        imageView.layer.cornerRadius = (size - 8) / 2
        imageView.clipsToBounds = true
        addSubview(imageView)
        isAccessibilityElement = true
        // Layer colours are static CGColors; refresh them when appearance changes.
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self]) { (view: PlacePinView, _) in view.updateSelection() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(_ place: Place) {
        backgroundColor = PinColors.cream
        if let photo = PlaceImage.uiImage(for: place.media.first) {
            imageView.image = photo
            imageView.contentMode = .scaleAspectFill
            imageView.backgroundColor = .clear
        } else {
            imageView.image = UIImage(systemName: place.category.icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 20, weight: .semibold))
            imageView.tintColor = PinColors.cream
            imageView.contentMode = .center
            imageView.backgroundColor = PinColors.forest
        }
        let precision = place.precision == .approximatePublic ? "approximate area" : "public location"
        accessibilityLabel = "\(place.name), \(place.category.rawValue.capitalized), \(precision)"
        accessibilityHint = "Shows a preview"
        accessibilityIdentifier = "map-place-\(place.id.uuidString)"
        updateSelection()
    }

    override var isSelected: Bool { didSet { updateSelection() } }

    private func updateSelection() {
        // Selection: thicker deep ring plus the selected trait; a single ≤1.1 scale unless Reduce Motion.
        layer.borderWidth = isSelected ? 3 : 1
        layer.borderColor = (isSelected ? PinColors.action : PinColors.primary).resolvedColor(with: traitCollection).cgColor
        transform = isSelected && !UIAccessibility.isReduceMotionEnabled ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
        accessibilityTraits = isSelected ? [.button, .selected] : .button
        zPriority = isSelected ? .max : .defaultUnselected
    }
}

/// Count bubble base: deep fill for native clusters, outlined plate for world-scale areas.
class CountBubbleView: MKAnnotationView {
    let label = UILabel()

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        collisionMode = .circle
        displayPriority = .required
        canShowCallout = false
        label.font = UIFontMetrics(forTextStyle: .headline).scaledFont(for: .systemFont(ofSize: 17, weight: .semibold), maximumPointSize: 28)
        label.textAlignment = .center
        addSubview(label)
        isAccessibilityElement = true
        accessibilityTraits = .button
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func layoutBubble(_ text: String) {
        label.text = text
        let side = max(44, label.intrinsicContentSize.width + 20, label.intrinsicContentSize.height + 16)
        frame = CGRect(x: 0, y: 0, width: side, height: side)
        label.frame = bounds
        layer.cornerRadius = side / 2
    }
}

final class ClusterCountView: CountBubbleView {
    func configure(count: Int, synthetic: Bool) {
        backgroundColor = PinColors.action
        label.textColor = PinColors.onAction
        layer.borderWidth = 0
        layoutBubble("\(count)")
        accessibilityLabel = "\(count) \(synthetic ? "synthetic" : "approved") places here"
        accessibilityHint = "Zooms in to show them"
        accessibilityIdentifier = "map-cluster"
    }
}

final class AreaCountView: CountBubbleView {
    static let reuseID = "area-count"

    func configure(_ cell: AggregateCell, synthetic: Bool) {
        backgroundColor = PinColors.surface
        label.textColor = PinColors.action
        layer.borderWidth = 2
        updateBorder()
        layoutBubble("\(cell.count)")
        let noun = synthetic ? "synthetic place" : "approved place"
        accessibilityLabel = "\(cell.count) \(noun)\(cell.count == 1 ? "" : "s") in this area"
        accessibilityHint = "Zooms in to this area"
        accessibilityIdentifier = "map-cell-\(Int(cell.bounds.south)),\(Int(cell.bounds.west))"
    }

    override init(annotation: (any MKAnnotation)?, reuseIdentifier: String?) {
        super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
        registerForTraitChanges([UITraitUserInterfaceStyle.self, UITraitAccessibilityContrast.self]) { (view: AreaCountView, _) in view.updateBorder() }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    private func updateBorder() {
        layer.borderColor = PinColors.action.resolvedColor(with: traitCollection).cgColor
    }
}
