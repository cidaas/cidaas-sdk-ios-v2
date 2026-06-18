//
//  CidaasHTTPProofToken.swift
//  Cidaas
//

import Foundation

/// Active DPoP flag for in-flight browser auth (code exchange) and persisted binding for refresh.
enum CidaasDpopFlowContext {
    private static let lock = NSLock()
    private static var activeUseDpop = false

    static var useDpopForActiveBrowserFlow: Bool {
        lock.lock()
        defer { lock.unlock() }
        return activeUseDpop
    }

    static func runWithUseDpop<T>(
        _ enabled: Bool,
        operation: (@escaping (Result<T>) -> Void) -> Void,
        completion: @escaping (Result<T>) -> Void
    ) {
        lock.lock()
        let previous = activeUseDpop
        if enabled {
            activeUseDpop = true
        }
        lock.unlock()

        operation { result in
            lock.lock()
            activeUseDpop = previous
            lock.unlock()
            completion(result)
        }
    }
}

/// DPoP proof on `POST /token-srv/token` (code exchange and refresh). Uses the `DPoP` header, not `dpop_jkt`.
enum CidaasHTTPProofToken {
    private static let persistedBindingKey = "com.cidaas.sdk.dpop.bound"

    static func effectiveUseDpopForTokenEndpoint() -> Bool {
        if CidaasDpopFlowContext.useDpopForActiveBrowserFlow { return true }
        return UserDefaults.standard.bool(forKey: persistedBindingKey)
    }

    /// DPoP header applies only to `POST /token-srv/token` (code exchange and refresh).
    static func shouldSendDpopHeader(for urlString: String) -> Bool {
        guard effectiveUseDpopForTokenEndpoint() else { return false }
        if let url = URL(string: urlString) {
            let path = url.path
            return path == "/token-srv/token" || path.hasSuffix("/token-srv/token")
        }
        return urlString.contains("/token-srv/token")
    }

    static func persistDpopBindingIfNeeded(from entity: AccessTokenEntity) {
        let bound = isDpopBound(entity)
        UserDefaults.standard.set(bound, forKey: persistedBindingKey)
    }

    static func clearPersistedDpopBinding() {
        UserDefaults.standard.removeObject(forKey: persistedBindingKey)
    }

    static func isDpopBound(_ entity: AccessTokenEntity) -> Bool {
        if entity.token_type.compare("DPoP", options: .caseInsensitive) == .orderedSame {
            return true
        }
        return accessTokenPayloadHasCnfJkt(entity.access_token)
    }

    private static func accessTokenPayloadHasCnfJkt(_ accessToken: String) -> Bool {
        let segments = accessToken.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count >= 2 else { return false }
        guard let payloadData = base64URLDecode(String(segments[1])),
              let json = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
              let cnf = json["cnf"] as? [String: Any],
              let jkt = cnf["jkt"] as? String
        else { return false }
        return !jkt.isEmpty
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = (4 - base64.count % 4) % 4
        if padding > 0 {
            base64 += String(repeating: "=", count: padding)
        }
        return Data(base64Encoded: base64)
    }
}
