import Foundation

/// Gebeta service URLs. Kept in sync with `packages/api/src/constants` in Gebeta-SDK-JS.
public enum GebetaEndpoints {
    public static let tilesHost = "tiles.gebeta.app"

    public static let auth = URL(string: "https://mapapi.gebeta.app/api/v1/external/auth")!
    public static let authRefresh = URL(string: "https://mapapi.gebeta.app/api/v1/external/auth/refresh")!

    public static let directions = URL(string: "https://mapapi.gebeta.app/api/route/direction/")!
    public static let geocodingBase = URL(string: "https://mapapi.gebeta.app/api/v1/route")!
    public static let geocodingSearch = URL(string: "https://mapapi.gebeta.app/v2/search/geocode")!

    public static let trackingSocket = URL(string: "wss://track.gebeta.app/v1/track")!
    public static let trackingHTTP = URL(string: "https://track.gebeta.app/v1/driver/location")!
}

/// Built-in Gebeta map styles.
public enum GebetaStyle: String, CaseIterable, Sendable {
    case standard, satellite, terrain

    public var url: URL {
        switch self {
        case .standard: return URL(string: "https://tiles.gebeta.app/styles/standard/style.json")!
        case .satellite: return URL(string: "https://tiles.gebeta.app/styles/raster/raster.json")!
        case .terrain: return URL(string: "https://tiles.gebeta.app/styles/standard/terrain/terrain.json")!
        }
    }
}
