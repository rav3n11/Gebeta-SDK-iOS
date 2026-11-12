import Foundation
import GebetaCore
import MapLibre

/// Decrypts tile payloads from tiles.gebeta.app. Phase 2.
public protocol TileDecryptor: AnyObject {
    func decrypt(_ data: Data, for url: URL) throws -> Data
}

/// Thread-safe copy of the current access token. MapLibre's request hook is
/// synchronous and runs off the main thread, so it cannot await `TokenStore`.
final class TokenMirror: @unchecked Sendable {
    private let lock = NSLock()
    private var _token: String?

    var token: String? {
        get { lock.lock(); defer { lock.unlock() }; return _token }
        set { lock.lock(); _token = newValue; lock.unlock() }
    }
}

/// Signs and (optionally) decrypts every request MapLibre makes to Gebeta tile hosts.
final class GebetaNetworkDelegate: NSObject, MLNNetworkConfigurationDelegate {
    private let auth: GebetaAuth
    private let tokenMirror = TokenMirror()
    private var refreshTask: Task<Void, Never>?
    weak var decryptor: TileDecryptor?

    init(auth: GebetaAuth) {
        self.auth = auth
        super.init()
        if case .serviceAccount(let store) = auth {
            refreshTask = Task { [tokenMirror] in
                tokenMirror.token = await store.accessToken
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: UInt64(TokenStore.refreshInterval * 1_000_000_000))
                    if let creds = try? await store.refresh() { tokenMirror.token = creds.accessToken }
                }
            }
        }
    }

    deinit { refreshTask?.cancel() }

    private func isGebeta(_ url: URL?) -> Bool {
        url?.host == GebetaEndpoints.tilesHost
    }

    func willSendRequest(_ request: NSMutableURLRequest) -> NSMutableURLRequest {
        guard let url = request.url, isGebeta(url) else { return request }
        switch auth {
        case .apiKey(let key):
            var c = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            c.queryItems = (c.queryItems ?? []).filter { $0.name != "apiKey" } + [URLQueryItem(name: "apiKey", value: key)]
            request.url = c.url
        case .serviceAccount:
            if let token = tokenMirror.token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }
        }
        return request
    }

    func didReceive(_ response: MLNNetworkResponse) -> MLNNetworkResponse {
        guard let decryptor, let url = response.response?.url, isGebeta(url), let data = response.data else {
            return response
        }
        do {
            response.data = try decryptor.decrypt(data, for: url)
        } catch {
            response.data = nil
            response.error = error as NSError
        }
        return response
    }
}
