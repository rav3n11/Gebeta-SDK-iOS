import Foundation

/// Entry point for Gebeta services. `GebetaMaps` builds on this.
///
/// ```swift
/// let gebeta = Gebeta(auth: .serviceAccount(TokenStore(credentials: creds)))
/// let places = try await gebeta.geocoding.geocode("Bole")
/// let route = try await gebeta.directions.route(from: a, to: b)
/// ```
public struct Gebeta: Sendable {
    public let auth: GebetaAuth
    public let geocoding: GeocodingClient
    public let directions: DirectionsClient

    public init(auth: GebetaAuth, transport: HTTPTransport = URLSessionTransport()) {
        let client = AuthorizedClient(auth: auth, transport: transport)
        self.auth = auth
        self.geocoding = GeocodingClient(client: client)
        self.directions = DirectionsClient(client: client)
    }
}
