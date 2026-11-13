import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Minimal transport so clients can be unit-tested without the network.
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest) async throws -> (Data, Int)
}

public struct URLSessionTransport: HTTPTransport {
    public init() {}

    public func send(_ request: URLRequest) async throws -> (Data, Int) {
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            return (data, (response as? HTTPURLResponse)?.statusCode ?? 0)
        } catch {
            throw GebetaError.network(error.localizedDescription)
        }
    }
}

/// Applies Gebeta auth to requests: `apiKey` query param, or bearer token with
/// a single refresh-and-retry on 401 (same contract as the JS AuthManager).
public struct AuthorizedClient: Sendable {
    public let auth: GebetaAuth
    public let transport: HTTPTransport

    public init(auth: GebetaAuth, transport: HTTPTransport = URLSessionTransport()) {
        self.auth = auth
        self.transport = transport
    }

    public func get(_ url: URL, query: [URLQueryItem]) async throws -> Data {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        var items = query
        if case .apiKey(let key) = auth {
            items.append(URLQueryItem(name: "apiKey", value: key.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        components.queryItems = (components.queryItems ?? []) + items
        let request = URLRequest(url: components.url!)

        switch auth {
        case .apiKey:
            return try check(await transport.send(request))
        case .serviceAccount(let store):
            let first = try await transport.send(authorized(request, token: await store.accessToken))
            guard first.1 == 401 else { return try check(first) }
            let creds = try await store.refresh()
            let retry = try await transport.send(authorized(request, token: creds.accessToken))
            if retry.1 == 401 { throw GebetaError.unauthorized("Authentication failed after token refresh") }
            return try check(retry)
        }
    }

    private func authorized(_ request: URLRequest, token: String) -> URLRequest {
        var r = request
        r.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        return r
    }

    private func check(_ result: (Data, Int)) throws -> Data {
        guard (200..<300).contains(result.1) else {
            throw GebetaError.http(status: result.1, body: String(data: result.0, encoding: .utf8))
        }
        return result.0
    }
}
