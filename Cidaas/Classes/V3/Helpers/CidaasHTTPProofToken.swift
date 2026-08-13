//
//  CidaasHTTPProofToken.swift
//  Cidaas
//

import Foundation

/// DPoP proof headers for SDK HTTP calls.
/// Sending is driven by ``Cidaas/ENABLE_DPOP`` and/or a persisted DPoP-bound session.
enum CidaasHTTPProofToken {
    private static let persistedBindingKey = "com.cidaas.sdk.dpop.bound"

    /// Whether the global DPoP flag is on (iOS 14+).
    static var isEnabled: Bool {
        guard #available(iOS 14.0, *) else { return false }
        return Cidaas.shared.ENABLE_DPOP
    }

    /// Last saved access token was DPoP-bound (`token_type` / `cnf.jkt`).
    /// Used so refresh (and other calls) still send `DPoP` if the session is bound
    /// even when ``Cidaas/ENABLE_DPOP`` is temporarily off (e.g. upgrade / flag not set yet).
    static var hasPersistedDpopBinding: Bool {
        UserDefaults.standard.bool(forKey: persistedBindingKey)
    }

    /// Send a fresh `DPoP` proof when the global flag is on **or** the current session is DPoP-bound.
    static func shouldSendDpopHeader(for urlString: String) -> Bool {
        guard #available(iOS 14.0, *) else { return false }
        guard !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        return isEnabled || hasPersistedDpopBinding
    }

    /// Remember whether the saved token is DPoP-bound so later refresh can still attach `DPoP`.
    static func persistDpopBindingIfNeeded(from entity: AccessTokenEntity) {
        UserDefaults.standard.set(isDpopBound(entity), forKey: persistedBindingKey)
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
