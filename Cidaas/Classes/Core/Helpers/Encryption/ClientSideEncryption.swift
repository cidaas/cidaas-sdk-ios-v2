//
//  ClientSideEncryption.swift
//  Cidaas
//

import Foundation

/// Facade used to encrypt sensitive fields before they are placed on the wire.
public enum ClientSideEncryption {

    public enum EncryptionError: Error, LocalizedError {
        case failed(String)

        public var errorDescription: String? {
            switch self {
            case .failed(let detail):
                return "Client-side encryption failed: \(detail)"
            }
        }
    }

    /// Returns `value` unchanged when encryption is disabled or the value is nil/empty.
    /// Otherwise returns a compact JWE (`kid`, `iat`, `jti` in the protected header).
    ///
    /// Fail-closed: when encryption is enabled, JWKS / key selection / JWE failures throw.
    /// There is no plaintext fallback. Prefer warming the cache with
    /// `JwksClient.prefetchAsync` or `Cidaas.setEncryptionEnabled(true)` at startup.
    public static func encryptIfEnabled(_ value: String?, baseUrlOverride: String? = nil) throws -> String? {
        guard Privacy.isEncryptionEnabled() else { return value }
        guard let value, !value.isEmpty else { return value }

        do {
            let jwksJson = try JwksClient.getJwksJson(baseUrlOverride: baseUrlOverride)
            guard let encKey = try JwksEncKeySelector.selectEncryptionKey(from: jwksJson) else {
                throw EncryptionError.failed("No use=enc ECDH-ES P-256 key found in JWKS")
            }
            return try JweFieldEncryptor.encrypt(value, with: encKey)
        } catch let error as EncryptionError {
            logw(error.localizedDescription, cname: "cidaas-sdk-encryption-log")
            throw error
        } catch {
            let wrapped = EncryptionError.failed(describe(error))
            logw(wrapped.localizedDescription, cname: "cidaas-sdk-encryption-log")
            throw wrapped
        }
    }

    /// Encrypts verification `pass_code` when encryption is enabled.
    public static func encryptPassCodeIfEnabled(
        _ passCode: String?,
        verificationType: String?,
        baseUrlOverride: String? = nil
    ) throws -> String? {
        guard shouldEncryptVerificationPassCode(verificationType) else {
            return passCode
        }
        return try encryptIfEnabled(passCode, baseUrlOverride: baseUrlOverride)
    }

    /// Returns whether `pass_code` for the given verification type should be encrypted.
    public static func shouldEncryptVerificationPassCode(_ verificationType: String?) -> Bool {
        guard let verificationType, !verificationType.isEmpty else { return false }
        let type = verificationType.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        return type == VerificationTypes.BACKUPCODE.rawValue || type == VerificationTypes.PATTERN.rawValue
    }

    /// Encrypts the named string fields in a request body dictionary in place.
    /// Each field receives its own JWE with a unique `jti`.
    public static func encryptFieldsInBody(
        _ bodyParams: inout [String: Any],
        fieldNames: [String],
        baseUrlOverride: String? = nil
    ) throws {
        guard Privacy.isEncryptionEnabled() else { return }
        for name in fieldNames {
            guard let value = bodyParams[name] as? String, !value.isEmpty else { continue }
            bodyParams[name] = try encryptIfEnabled(value, baseUrlOverride: baseUrlOverride)
        }
    }

    /// Encrypts the named string fields in a `[String: String]` request body in place.
    /// Each field receives its own JWE with a unique `jti`.
    public static func encryptFieldsInBody(
        _ bodyParams: inout [String: String],
        fieldNames: [String],
        baseUrlOverride: String? = nil
    ) throws {
        guard Privacy.isEncryptionEnabled() else { return }
        for name in fieldNames {
            guard let value = bodyParams[name], !value.isEmpty else { continue }
            if let encrypted = try encryptIfEnabled(value, baseUrlOverride: baseUrlOverride) {
                bodyParams[name] = encrypted
            }
        }
    }

    /// Applies verification encryption rules to enroll or authenticate request bodies.
    public static func applyVerificationEncryption(
        _ bodyParams: inout [String: Any],
        verificationType: String,
        baseUrlOverride: String? = nil
    ) throws {
        guard Privacy.isEncryptionEnabled() else { return }

        if let passCode = bodyParams["pass_code"] as? String, !passCode.isEmpty {
            if let encrypted = try encryptPassCodeIfEnabled(
                passCode,
                verificationType: verificationType,
                baseUrlOverride: baseUrlOverride
            ) {
                bodyParams["pass_code"] = encrypted
            }
        } else if let password = bodyParams["password"] as? String, !password.isEmpty {
            if let encrypted = try encryptIfEnabled(password, baseUrlOverride: baseUrlOverride) {
                bodyParams["password"] = encrypted
            }
        }
    }

    private static func describe(_ error: Error) -> String {
        let ns = error as NSError
        var parts = ["\(type(of: error))"]
        if !error.localizedDescription.isEmpty {
            parts.append(error.localizedDescription)
        }
        if let underlying = ns.userInfo[NSUnderlyingErrorKey] as? Error {
            parts.append("cause \(underlying.localizedDescription)")
        }
        return parts.joined(separator: ": ")
    }
}
