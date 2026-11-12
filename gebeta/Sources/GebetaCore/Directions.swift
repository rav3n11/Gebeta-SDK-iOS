import Foundation

public struct DirectionsClient: Sendable {
    let client: AuthorizedClient

    public init(client: AuthorizedClient) {
        self.client = client
    }

    public func route(from origin: LngLat, to destination: LngLat, waypoints: [LngLat] = []) async throws -> Route {
        var query = [
            URLQueryItem(name: "origin", value: "\(origin.lat),\(origin.lng)"),
            URLQueryItem(name: "destination", value: "\(destination.lat),\(destination.lng)"),
        ]
        if !waypoints.isEmpty {
            let list = waypoints.map { "{\($0.lat),\($0.lng)}" }.joined(separator: ",")
            query.append(URLQueryItem(name: "waypoints", value: "[\(list)]"))
        }
        let data = try await client.get(GebetaEndpoints.directions, query: query)
        return try Self.parse(data)
    }

    static func parse(_ data: Data) throws -> Route {
        struct Response: Decodable {
            struct Summary: Decodable { let length: Double?; let time: Double? }
            struct Maneuver: Decodable { let type: Int?; let instruction: String?; let time: Double?; let length: Double? }
            struct Leg: Decodable { let shape: String; let maneuvers: [Maneuver]?; let summary: Summary? }
            struct Trip: Decodable { let legs: [Leg]; let summary: Summary? }
            struct Err: Decodable { let message: String? }
            let msg: String?
            let trip: Trip?
            let error: Err?
        }
        let r = try decode(Response.self, data)
        guard let trip = r.trip, !trip.legs.isEmpty else {
            throw GebetaError.api(r.error?.message ?? "No route found")
        }
        var coords: [LngLat] = []
        var steps: [RouteStep] = []
        for leg in trip.legs {
            let legCoords = try Polyline.decode(leg.shape)
            // Consecutive legs share their joining point.
            coords += (coords.last == legCoords.first) ? Array(legCoords.dropFirst()) : legCoords
            steps += (leg.maneuvers ?? []).map {
                RouteStep(instruction: $0.instruction, type: $0.type, time: $0.time, length: $0.length)
            }
        }
        return Route(
            coordinates: coords,
            steps: steps,
            distanceMeters: trip.summary?.length.map { $0 * 1000 },
            durationSeconds: trip.summary?.time
        )
    }
}

/// Encoded polyline decoding at 1e5 precision, matching Gebeta-SDK-JS.
public enum Polyline {
    public static func decode(_ encoded: String, precision: Double = 1e5) throws -> [LngLat] {
        let bytes = Array(encoded.utf8)
        var index = 0, lat = 0, lng = 0
        var out: [LngLat] = []

        func next() throws -> Int {
            var result = 0, shift = 0, byte = 0
            repeat {
                guard index < bytes.count else { throw GebetaError.invalidPolyline("Unexpected end at \(index)") }
                byte = Int(bytes[index]) - 63
                index += 1
                result |= (byte & 0x1f) << shift
                shift += 5
            } while byte >= 0x20
            return (result & 1) != 0 ? ~(result >> 1) : (result >> 1)
        }

        while index < bytes.count {
            lat += try next()
            lng += try next()
            out.append(LngLat(lng: Double(lng) / precision, lat: Double(lat) / precision))
        }
        return out
    }
}
