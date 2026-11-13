import XCTest
@testable import GebetaCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class MockTransport: HTTPTransport, @unchecked Sendable {
    var responses: [(Data, Int)]
    private(set) var requests: [URLRequest] = []
    init(_ responses: [(String, Int)]) { self.responses = responses.map { (Data($0.0.utf8), $0.1) } }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return responses.removeFirst()
    }
}

final class GebetaCoreTests: XCTestCase {
    func testPolylineDecode() throws {
        // Canonical example from the encoded polyline algorithm docs (precision 1e5).
        let pts = try Polyline.decode("_p~iF~ps|U_ulLnnqC_mqNvxq`@")
        XCTAssertEqual(pts.count, 3)
        XCTAssertEqual(pts[0].lat, 38.5, accuracy: 1e-9)
        XCTAssertEqual(pts[0].lng, -120.2, accuracy: 1e-9)
        XCTAssertEqual(pts[2].lat, 43.252, accuracy: 1e-9)
    }

    func testPolylineTruncatedThrows() {
        XCTAssertThrowsError(try Polyline.decode("_p~iF~ps|"))
    }

    func testGeocodeParsesAlternateCoordinateKeys() async throws {
        let body = #"{"msg":"Ok","data":[{"name":"Bole","latitude":8.99,"longitude":38.79},{"name":"Piassa","location":{"lat":9.03,"lng":38.75}}]}"#
        let t = MockTransport([(body, 200)])
        let store = TokenStore(credentials: .init(accessToken: "a", refreshToken: "r"), transport: t)
        let g = Gebeta(auth: .serviceAccount(store), transport: t)
        let r = try await g.geocoding.geocode("Bole")
        XCTAssertEqual(r.map(\.name), ["Bole", "Piassa"])
        XCTAssertEqual(r[1].lngLat, LngLat(lng: 38.75, lat: 9.03))
        XCTAssertEqual(t.requests[0].value(forHTTPHeaderField: "Authorization"), "Bearer a")
    }

    func testRefreshAndRetryOn401() async throws {
        let t = MockTransport([
            ("", 401),
            (#"{"data":{"accessToken":"new","refreshToken":"r2"}}"#, 200),
            (#"{"msg":"ok","data":[]}"#, 200),
        ])
        let store = TokenStore(credentials: .init(accessToken: "old", refreshToken: "r"), transport: t)
        let g = Gebeta(auth: .serviceAccount(store), transport: t)
        _ = try await g.geocoding.reverseGeocode(LngLat(lng: 38.7, lat: 9.0))
        XCTAssertEqual(t.requests.count, 3)
        XCTAssertEqual(t.requests[2].value(forHTTPHeaderField: "Authorization"), "Bearer new")
        let token = await store.accessToken
        XCTAssertEqual(token, "new")
    }

    func testApiKeyGoesInQuery() async throws {
        let t = MockTransport([(#"{"data":{"results":[]}}"#, 200)])
        let g = Gebeta(auth: .apiKey(" key123\n"), transport: t)
        _ = try await g.geocoding.geocode("Bole")
        let url = try XCTUnwrap(t.requests[0].url?.absoluteString)
        XCTAssertTrue(url.contains("apiKey=key123"))
        XCTAssertTrue(url.contains("query=Bole"))
    }

    func testDirectionsJoinsLegsAndConvertsKm() throws {
        let body = #"{"msg":"ok","trip":{"legs":[{"shape":"_p~iF~ps|U_ulLnnqC","maneuvers":[{"type":1,"instruction":"Head north"}]},{"shape":"_flwFn`faV_mqNvxq`@"}],"summary":{"length":1.5,"time":120}}}"#
        let route = try DirectionsClient.parse(Data(body.utf8))
        XCTAssertEqual(route.coordinates.count, 3)
        XCTAssertEqual(route.distanceMeters, 1500)
        XCTAssertEqual(route.steps.first?.instruction, "Head north")
    }
}
