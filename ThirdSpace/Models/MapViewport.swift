import Foundation

/// The visible map region as plain numbers, so zoom and bounds rules stay testable without MapKit.
struct MapViewport: Equatable, Sendable {
    let centerLatitude: Double
    let centerLongitude: Double
    let latitudeDelta: Double
    let longitudeDelta: Double

    /// 0 at whole-world scale; each step halves the visible longitude span. Rounded because
    /// MapKit pads a requested region to the screen's aspect ratio.
    var zoomBucket: Int {
        max(0, Int(log2(360 / max(longitudeDelta, 0.000_1)).rounded()))
    }

    /// WGS84 bounds of the viewport; west > east means it crosses the antimeridian.
    var bounds: GeoBounds? {
        let south = max(-90, centerLatitude - latitudeDelta / 2)
        let north = min(90, centerLatitude + latitudeDelta / 2)
        guard longitudeDelta < 360 else { return GeoBounds(south: south, west: -180, north: north, east: 180) }
        return GeoBounds(south: south, west: centerLongitude - longitudeDelta / 2, north: north, east: centerLongitude + longitudeDelta / 2)
    }
}
