import UIKit
import GebetaCore
import MapLibre

/// MapLibre map view preconfigured for Gebeta: authenticated tiles, Gebeta
/// styles, and services (geocoding, directions) available from the view.
open class GebetaMapView: MLNMapView {
    public let gebeta: Gebeta
    private let networkDelegate: GebetaNetworkDelegate

    public init(frame: CGRect, auth: GebetaAuth, style: GebetaStyle = .standard) {
        self.gebeta = Gebeta(auth: auth)
        self.networkDelegate = GebetaNetworkDelegate(auth: auth)
        // Must be in place before the first style request.
        // TODO(phase 1): sharedManager is process-wide; support multiple map views with different auth.
        MLNNetworkConfiguration.sharedManager.delegate = networkDelegate
        super.init(frame: frame, styleURL: style.url)
    }

    @available(*, unavailable)
    public required init?(coder: NSCoder) {
        fatalError("Use init(frame:auth:style:)")
    }

    public var tileDecryptor: TileDecryptor? {
        get { networkDelegate.decryptor }
        set { networkDelegate.decryptor = newValue }
    }

    public func setGebetaStyle(_ style: GebetaStyle) {
        styleURL = style.url
    }

    /// Fetches a route and draws it as a line layer.
    @discardableResult
    public func showRoute(from origin: LngLat, to destination: LngLat, waypoints: [LngLat] = []) async throws -> Route {
        let route = try await gebeta.directions.route(from: origin, to: destination, waypoints: waypoints)
        await MainActor.run { self.drawRoute(route) }
        return route
    }

    @MainActor
    private func drawRoute(_ route: Route) {
        guard let style else { return }
        var coords = route.coordinates.map { CLLocationCoordinate2D(latitude: $0.lat, longitude: $0.lng) }
        let line = MLNPolylineFeature(coordinates: &coords, count: UInt(coords.count))
        let id = "gebeta-route"
        if let source = style.source(withIdentifier: id) as? MLNShapeSource {
            source.shape = line
        } else {
            let source = MLNShapeSource(identifier: id, shape: line)
            style.addSource(source)
            let layer = MLNLineStyleLayer(identifier: id, source: source)
            layer.lineWidth = NSExpression(forConstantValue: 5)
            layer.lineColor = NSExpression(forConstantValue: UIColor.systemBlue)
            layer.lineCap = NSExpression(forConstantValue: "round")
            layer.lineJoin = NSExpression(forConstantValue: "round")
            style.addLayer(layer)
        }
        let bounds = MLNPolyline(coordinates: &coords, count: UInt(coords.count)).overlayBounds
        setVisibleCoordinateBounds(bounds, edgePadding: UIEdgeInsets(top: 60, left: 40, bottom: 60, right: 40), animated: true, completionHandler: nil)
    }
}
