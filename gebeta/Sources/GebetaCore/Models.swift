import Foundation

public struct LngLat: Hashable, Sendable, Codable {
    public var lng: Double
    public var lat: Double

    public init(lng: Double, lat: Double) {
        self.lng = lng
        self.lat = lat
    }
}

public struct GeocodeResult: Sendable, Hashable {
    public var name: String
    public var lngLat: LngLat
}

public struct RouteStep: Sendable, Hashable {
    public var instruction: String?
    /// Valhalla maneuver type.
    public var type: Int?
    /// Seconds.
    public var time: Double?
    /// Kilometres, as returned by the API.
    public var length: Double?
}

public struct Route: Sendable, Hashable {
    public var coordinates: [LngLat]
    public var steps: [RouteStep]
    /// Metres, if the API returned a summary.
    public var distanceMeters: Double?
    /// Seconds, if the API returned a summary.
    public var durationSeconds: Double?
}

public enum GebetaError: Error, Equatable, Sendable {
    case validation(String)
    case network(String)
    case http(status: Int, body: String?)
    case unauthorized(String)
    case api(String)
    case decoding(String)
    case invalidPolyline(String)
}
