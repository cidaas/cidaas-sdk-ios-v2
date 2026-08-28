//
//  JwksEncKeySelector.swift
//  Cidaas
//

import Foundation
import Security

/// Encryption public key selected from JWKS (`use=enc`, EC P-256, ECDH-ES).
public struct EncPublicKey {
    public let kid: String
    public let x: Data
    public let y: Data
    public let alg: String?

    enum KeyError: Error, LocalizedError {
        case importFailed

        var errorDescription: String? {
            "Failed to import encryption public key"
        }
    }

    /// SecKey representation of the recipient public key (uncompressed P-256).
    public func secKey() throws -> SecKey {
        var point = Data([0x04])
        point.append(x)
        point.append(y)
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 256
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(point as CFData, attributes as CFDictionary, &error) else {
            if let error {
                throw error.takeRetainedValue() as Error
            }
            throw KeyError.importFailed
        }
        return key
    }
}

/// Selects an encryption public key from a JWKS document.
///
/// A key is eligible when it has `use=enc`, `kty=EC`, `crv=P-256`, a non-empty `kid`,
/// and `alg` empty or `ECDH-ES`. Keys that omit `crv` are rejected.
/// When several keys match, one is chosen at random.
public enum JwksEncKeySelector {
    private static let lock = NSLock()
    private static var randomSource: () -> UInt = { UInt.random(in: 0 ... UInt.max) }

    /// Test hook for deterministic key selection.
    static func setRandomSource(_ source: @escaping () -> UInt) {
        lock.lock()
        randomSource = source
        lock.unlock()
    }

    static func resetRandomSource() {
        lock.lock()
        randomSource = { UInt.random(in: 0 ... UInt.max) }
        lock.unlock()
    }

    /// Returns a suitable encryption key from JWKS JSON, or `nil` when none match.
    public static func selectEncryptionKey(from jwksJson: String) throws -> EncPublicKey? {
        guard let data = jwksJson.data(using: .utf8),
              let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let keys = root["keys"] as? [[String: Any]],
              !keys.isEmpty else {
            return nil
        }

        var candidates: [EncPublicKey] = []
        for key in keys {
            if let candidate = parseCandidate(key) {
                candidates.append(candidate)
            }
        }
        guard !candidates.isEmpty else { return nil }
        if candidates.count == 1 { return candidates[0] }

        lock.lock()
        let next = randomSource()
        lock.unlock()
        let index = Int(next % UInt(candidates.count))
        return candidates[index]
    }

    private static func parseCandidate(_ key: [String: Any]) -> EncPublicKey? {
        guard (key["use"] as? String) == "enc" else { return nil }
        guard (key["kty"] as? String) == "EC" else { return nil }

        let alg = key["alg"] as? String
        if let alg, !alg.isEmpty, alg != "ECDH-ES" {
            return nil
        }
        guard (key["crv"] as? String) == "P-256" else { return nil }

        let kid = (key["kid"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !kid.isEmpty else { return nil }

        guard let xB64 = key["x"] as? String, !xB64.isEmpty,
              let yB64 = key["y"] as? String, !yB64.isEmpty,
              let x = base64URLDecode(xB64),
              let y = base64URLDecode(yB64),
              x.count == 32,
              y.count == 32 else {
            return nil
        }

        return EncPublicKey(kid: kid, x: x, y: y, alg: alg)
    }

    private static func base64URLDecode(_ value: String) -> Data? {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = base64.count % 4
        if remainder > 0 {
            base64.append(String(repeating: "=", count: 4 - remainder))
        }
        return Data(base64Encoded: base64)
    }
}
