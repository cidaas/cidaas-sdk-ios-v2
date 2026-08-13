//
//  CidaasHTTPProofToken.swift
//  Cidaas
//

import Foundation

/// DPoP proof headers for SDK HTTP calls. Driven by global ``Cidaas/ENABLE_DPOP``.
enum CidaasHTTPProofToken {
    private static let persistedBindingKey = "com.cidaas.sdk.dpop.bound"

    /// Whether the SDK should send DPoP (global flag, iOS 14+).
    static var isEnabled: Bool {
        guard #available(iOS 14.0, *) else { return false }
        return Cidaas.shared.ENABLE_DPOP
    }

    /// When ``Cidaas/ENABLE_DPOP`` is true, send a fresh `DPoP` proof on **every** API URL.
    static func shouldSendDpopHeader(for urlString: String) -> Bool {
        guard isEnabled else { return false }
        return !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    static func persistDpopBindingIfNeeded(from entity: AccessTokenEntity) {
        guard isEnabled else {
            clearPersistedDpopBinding()
            return
        }
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
