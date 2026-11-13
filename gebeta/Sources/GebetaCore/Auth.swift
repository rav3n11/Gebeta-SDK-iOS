import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct ServiceAccountCredentials: Codable, Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String

    public init(accessToken: String, refreshToken: String) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
    }
}

/// How the SDK authenticates. Mirrors `resolveAuth` in Gebeta-SDK-JS.
public enum GebetaAuth: Sendable {
    /// Deprecated upstream; appended as `?apiKey=`.
    case apiKey(String)
    /// Bearer token with refresh. Default for new integrations.
    case serviceAccount(TokenStore)
}

/// Holds service-account tokens and refreshes them. Access tokens live 7 minutes.
public actor TokenStore {
    public static let tokenLifetime: TimeInterval = 7 * 60
    public static let refreshInterval: TimeInterval = tokenLifetime * 0.9

    private var credentials: ServiceAccountCredentials
    private var inFlightRefresh: Task<ServiceAccountCredentials, Error>?
    private let transport: HTTPTransport

    public init(credentials: ServiceAccountCredentials, transport: HTTPTransport = URLSessionTransport()) {
        self.credentials = credentials
        self.transport = transport
    }

    public var accessToken: String { credentials.accessToken }

    /// Lets the host app push credentials obtained from its own backend.
    public func update(_ new: ServiceAccountCredentials) {
        credentials = new
    }

    /// Refreshes once; concurrent callers share the same request.
    @discardableResult
    public func refresh() async throws -> ServiceAccountCredentials {
        if let task = inFlightRefresh { return try await task.value }
        let refreshToken = credentials.refreshToken
        let transport = self.transport
        let task = Task { () throws -> ServiceAccountCredentials in
            var request = URLRequest(url: GebetaEndpoints.authRefresh)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])
            let (data, status) = try await transport.send(request)
            guard (200..<300).contains(status) else {
                throw GebetaError.unauthorized("Token refresh failed with status \(status)")
            }
            struct Envelope: Decodable { let data: ServiceAccountCredentials? }
            guard let creds = try? JSONDecoder().decode(Envelope.self, from: data).data else {
                throw GebetaError.unauthorized("Token refresh returned invalid credentials")
            }
            return creds
        }
        inFlightRefresh = task
        defer { inFlightRefresh = nil }
        let creds = try await task.value
        credentials = creds
        return creds
    }
}
