//
//  DeviceRegistrationChallengeB64.swift
//  Cidaas
//

import Foundation

/// Base64 helpers for the registration nonce and App Attest key id.
enum DeviceRegistrationChallengeB64 {

    /// Decodes standard or URL-safe base64 to raw bytes.
    static func decodeToData(_ value: String) -> Data? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = Data(base64Encoded: trimmed) {
            return data
        }
        var b64 = trimmed.replacingOccurrences(of: "-", with: "+").replacingOccurrences(of: "_", with: "/")
        let remainder = b64.count % 4
        if remainder != 0 {
            b64 += String(repeating: "=", count: 4 - remainder)
        }
        return Data(base64Encoded: b64)
    }

    /// Normalizes Apple's App Attest key id to standard Base64.
    static func standardBase64KeyId(fromAppleKeyId appleKeyId: String) throws -> String {
        let trimmed = appleKeyId.trimmingCharacters(in: .whitespacesAndNewlines)
        if let raw = Data(base64Encoded: trimmed) {
            return raw.base64EncodedString()
        }
        var normalized = trimmed
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = normalized.count % 4
        if remainder != 0 {
            normalized += String(repeating: "=", count: 4 - remainder)
        }
        guard let raw = Data(base64Encoded: normalized) else {
            throw NSError(
                domain: "CidaasDeviceRegistration",
                code: 2,
                userInfo: [NSLocalizedDescriptionKey: "invalid App Attest keyId base64"]
            )
        }
        return raw.base64EncodedString()
    }
}
