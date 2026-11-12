import Foundation

public struct GeocodingClient: Sendable {
    let client: AuthorizedClient

    public init(client: AuthorizedClient) {
        self.client = client
    }

    /// Forward geocoding. API-key auth uses the v2 search endpoint, as in Gebeta-SDK-JS.
    public func geocode(_ name: String) async throws -> [GeocodeResult] {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GebetaError.validation("Name is required for geocoding") }

        if case .apiKey = client.auth {
            let data = try await client.get(GebetaEndpoints.geocodingSearch, query: [URLQueryItem(name: "query", value: trimmed)])
            struct Search: Decodable { struct D: Decodable { let results: [RawResult]? }; let data: D? }
            let decoded = try decode(Search.self, data)
            return try (decoded.data?.results ?? []).map { try $0.toResult() }
        }

        let data = try await client.get(GebetaEndpoints.geocodingBase.appendingPathComponent("geocoding"),
                                        query: [URLQueryItem(name: "name", value: trimmed)])
        return try parseEnvelope(data)
    }

    public func reverseGeocode(_ point: LngLat) async throws -> [GeocodeResult] {
        let data = try await client.get(GebetaEndpoints.geocodingBase.appendingPathComponent("revgeocoding"), query: [
            URLQueryItem(name: "lat", value: String(point.lat)),
            URLQueryItem(name: "lon", value: String(point.lng)),
        ])
        return try parseEnvelope(data)
    }

    func parseEnvelope(_ data: Data) throws -> [GeocodeResult] {
        struct Envelope: Decodable {
            struct Err: Decodable { let message: String? }
            let msg: String?
            let data: [RawResult]?
            let error: Err?
        }
        let env = try decode(Envelope.self, data)
        // The API mixes 'ok' and 'Ok'.
        guard env.msg?.lowercased() == "ok" else {
            throw GebetaError.api(env.error?.message ?? env.msg ?? "Geocoding failed")
        }
        return try (env.data ?? []).map { try $0.toResult() }
    }
}

/// The geocoder returns coordinates under several key names.
struct RawResult: Decodable {
    struct Loc: Decodable { let lat: Double?; let lng: Double? }
    let name: String?
    let lat: Double?, lng: Double?
    let latitude: Double?, longitude: Double?
    let location: Loc?

    func toResult() throws -> GeocodeResult {
        guard let name, !name.isEmpty else { throw GebetaError.decoding("Invalid geocoding result: missing name") }
        guard let la = lat ?? latitude ?? location?.lat, let ln = lng ?? longitude ?? location?.lng else {
            throw GebetaError.decoding("Invalid geocoding result: missing coordinates for \"\(name)\"")
        }
        return GeocodeResult(name: name, lngLat: LngLat(lng: ln, lat: la))
    }
}

func decode<T: Decodable>(_ type: T.Type, _ data: Data) throws -> T {
    do { return try JSONDecoder().decode(type, from: data) } catch {
        throw GebetaError.decoding(String(describing: error))
    }
}
