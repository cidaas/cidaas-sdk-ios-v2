//
//  DeviceRegistrationProofs.swift
//  Cidaas
//

import CryptoKit
import Foundation
import LocalAuthentication
import Security

/// Builds DPoP and biometric proof JWTs and the verify request body/headers.
@available(iOS 14.0, *)
enum DeviceRegistrationProofs {

    /// Body and headers ready to send for the verify step.
    struct PreparedVerificationRequest {
        let bodyParams: [String: Any]
        let extraHeaders: [String: String]
    }

    /// Loads or creates signing keys, builds proof JWTs, and assembles the verify payload.
    static func prepareVerificationRequest(
        verificationURLString: String,
        sessionId: String,
        attestationObject: Data,
        appAttestKeyId: String,
        appVersion: String,
        platform: String
    ) throws -> PreparedVerificationRequest {
        guard let url = URL(string: verificationURLString) else {
            throw NSError(
                domain: "CidaasDeviceRegistration",
                code: 10,
                userInfo: [NSLocalizedDescriptionKey: "invalid device registration verification URL"]
            )
        }

        let keyIdB64 = try DeviceRegistrationChallengeB64.standardBase64KeyId(fromAppleKeyId: appAttestKeyId)
        let dpopPrivateKey = try DPoPSigningKey.loadOrCreate()
        let biometricContext = LAContext()
        biometricContext.localizedReason = "Verify your identity to register this device"
        let biometricPrivateKey = try BiometricSigningKey.loadOrCreate(context: biometricContext)

        let dpopProof = try proofJWT(typ: "dpop+jwt", httpMethod: "POST", httpURL: url, privateKey: dpopPrivateKey)
        let biometricProof = try proofJWT(
            typ: "biometric+jwt",
            httpMethod: "POST",
            httpURL: url,
            privateKey: biometricPrivateKey,
            biometricContext: biometricContext
        )
        let dpopThumbprint = try jwkThumbprintSHA256(privateKey: dpopPrivateKey)
        let biometricThumbprint = try jwkThumbprintSHA256(privateKey: biometricPrivateKey)

        let bodyParams: [String: Any] = [
            "session_id": sessionId.lowercased(),
            "attestation": attestationObject.base64EncodedString(),
            "key_id": keyIdB64,
            "app_version": appVersion,
            "platform": platform,
            "dpop_jwk_thumbprint": dpopThumbprint,
            "biometric_jwk_thumbprint": biometricThumbprint,
        ]
        let extraHeaders = [
            "DPoP": dpopProof,
            "Biometric": biometricProof,
        ]
        return PreparedVerificationRequest(bodyParams: bodyParams, extraHeaders: extraHeaders)
    }

    // MARK: - Signing keys (persisted in Keychain)

    /// Long-lived EC key for DPoP proofs at registration.
    private enum DPoPSigningKey {
        private static let tag = "com.cidaas.sdk.device.registration.dpop.ecdsa".data(using: .utf8)!

        static func loadOrCreate() throws -> SecKey {
            if let existing = loadPrivate() {
                return existing
            }
            var error: Unmanaged<CFError>?
            let attrs: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeySizeInBits as String: 256,
                kSecPrivateKeyAttrs as String: [
                    kSecAttrIsPermanent as String: true,
                    kSecAttrApplicationTag as String: tag,
                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                ],
            ]
            guard let key = SecKeyCreateRandomKey(attrs as CFDictionary, &error) else {
                throw error!.takeRetainedValue() as Error
            }
            return key
        }

        private static func loadPrivate() -> SecKey? {
            let query: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: tag,
                kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                kSecReturnRef as String: true,
            ]
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            guard status == errSecSuccess, let key = item else { return nil }
            return (key as! SecKey)
        }
    }

    /// Secure Enclave key gated by Face ID / Touch ID.
    private enum BiometricSigningKey {
        private static let tag = "com.cidaas.sdk.device.registration.biometric.ecdsa".data(using: .utf8)!

        static func loadOrCreate(context: LAContext = LAContext()) throws -> SecKey {
            if let existing = loadPrivate(context: context) {
                return existing
            }
            var error: Unmanaged<CFError>?
            guard let access = SecAccessControlCreateWithFlags(
                nil,
                kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
                [.privateKeyUsage, .biometryCurrentSet],
                &error
            ) else {
                throw error!.takeRetainedValue() as Error
            }
            let attrs: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeySizeInBits as String: 256,
                kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
                kSecPrivateKeyAttrs as String: [
                    kSecAttrIsPermanent as String: true,
                    kSecAttrApplicationTag as String: tag,
                    kSecAttrAccessControl as String: access,
                ],
            ]
            guard let key = SecKeyCreateRandomKey(attrs as CFDictionary, &error) else {
                throw error!.takeRetainedValue() as Error
            }
            return key
        }

        private static func loadPrivate(context: LAContext) -> SecKey? {
            let query: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: tag,
                kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                kSecReturnRef as String: true,
                kSecUseAuthenticationContext as String: context,
            ]
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            guard status == errSecSuccess, let key = item else { return nil }
            return (key as! SecKey)
        }
    }

    // MARK: - Proof JWT (dpop+jwt / biometric+jwt)

    private struct ProofClaims: Encodable {
        let htm: String
        let htu: String
        let iat: Int
        let jti: String
    }

    private struct ProofHeader: Encodable {
        let typ: String
        let alg: String
        let jwk: JWK
    }

    private struct JWK: Encodable {
        let kty: String
        let crv: String
        let x: String
        let y: String
    }

    private static func proofJWT(
        typ: String,
        httpMethod: String,
        httpURL: URL,
        privateKey: SecKey,
        biometricContext: LAContext? = nil
    ) throws -> String {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw NSError(domain: "CidaasDeviceRegistration", code: 20, userInfo: [NSLocalizedDescriptionKey: "missing public key"])
        }
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }
        guard publicKeyData.count == 65, publicKeyData.first == 0x04 else {
            throw NSError(domain: "CidaasDeviceRegistration", code: 21, userInfo: [NSLocalizedDescriptionKey: "unexpected public key format"])
        }
        let x = publicKeyData.subdata(in: 1 ..< 33)
        let y = publicKeyData.subdata(in: 33 ..< 65)
        let jwk = JWK(kty: "EC", crv: "P-256", x: base64URL(x), y: base64URL(y))
        let header = ProofHeader(typ: typ, alg: "ES256", jwk: jwk)
        let claims = ProofClaims(
            htm: httpMethod.uppercased(),
            htu: canonicalHTU(httpURL),
            iat: Int(Date().timeIntervalSince1970.rounded(.down)),
            jti: UUID().uuidString.lowercased()
        )
        let headerB64 = base64URL(try JSONEncoder().encode(header))
        let claimsB64 = base64URL(try JSONEncoder().encode(claims))
        let signingInput = "\(headerB64).\(claimsB64)"
        let digest = Data(SHA256.hash(data: Data(signingInput.utf8)))
        let signature = try signDigest(privateKey: privateKey, digest32: digest, biometricContext: biometricContext)
        return "\(signingInput).\(base64URL(signature))"
    }

    private static func jwkThumbprintSHA256(privateKey: SecKey) throws -> String {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw NSError(domain: "CidaasDeviceRegistration", code: 22, userInfo: [NSLocalizedDescriptionKey: "missing public key"])
        }
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }
        guard publicKeyData.count == 65, publicKeyData.first == 0x04 else {
            throw NSError(domain: "CidaasDeviceRegistration", code: 23, userInfo: [NSLocalizedDescriptionKey: "unexpected public key format"])
        }
        let x = base64URL(publicKeyData.subdata(in: 1 ..< 33))
        let y = base64URL(publicKeyData.subdata(in: 33 ..< 65))
        let json = "{\"crv\":\"P-256\",\"kty\":\"EC\",\"x\":\"\(x)\",\"y\":\"\(y)\"}"
        let digest = Data(SHA256.hash(data: Data(json.utf8)))
        return base64URL(digest)
    }

    private static func signDigest(privateKey: SecKey, digest32: Data, biometricContext: LAContext? = nil) throws -> Data {
        var error: Unmanaged<CFError>?
        if let biometricContext {
            biometricContext.localizedReason = biometricContext.localizedReason.isEmpty
                ? "Verify your identity to register this device"
                : biometricContext.localizedReason
        }
        guard let derSignature = SecKeyCreateSignature(
            privateKey,
            SecKeyAlgorithm.ecdsaSignatureDigestX962SHA256,
            digest32 as CFData,
            &error
        ) as Data? else {
            throw error!.takeRetainedValue() as Error
        }
        return try derToJoseES256(derSignature)
    }

    private static func canonicalHTU(_ url: URL) -> String {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.fragment = nil
        components?.query = nil
        return components?.url?.absoluteString ?? url.absoluteString
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private static func derToJoseES256(_ der: Data) throws -> Data {
        var index = 0
        func readByte() throws -> UInt8 {
            guard index < der.count else {
                throw NSError(domain: "CidaasDeviceRegistration", code: 30, userInfo: [NSLocalizedDescriptionKey: "bad DER signature"])
            }
            let value = der[index]
            index += 1
            return value
        }
        func readLength() throws -> Int {
            let first = try readByte()
            if first & 0x80 == 0 { return Int(first) }
            let byteCount = Int(first & 0x7f)
            guard byteCount > 0, byteCount <= 2 else {
                throw NSError(domain: "CidaasDeviceRegistration", code: 31, userInfo: [NSLocalizedDescriptionKey: "bad DER length"])
            }
            var length = 0
            for _ in 0 ..< byteCount {
                length = (length << 8) | Int(try readByte())
            }
            return length
        }
        _ = try readByte()
        _ = try readLength()
        guard try readByte() == 0x02 else {
            throw NSError(domain: "CidaasDeviceRegistration", code: 32, userInfo: [NSLocalizedDescriptionKey: "bad DER integer"])
        }
        let rLength = try readLength()
        let r = der.subdata(in: index ..< index + rLength)
        index += rLength
        guard try readByte() == 0x02 else {
            throw NSError(domain: "CidaasDeviceRegistration", code: 33, userInfo: [NSLocalizedDescriptionKey: "bad DER integer"])
        }
        let sLength = try readLength()
        let s = der.subdata(in: index ..< index + sLength)

        func fixed32(_ value: Data) -> Data {
            var bytes = [UInt8](value)
            while bytes.count > 32, bytes.first == 0x00 {
                bytes.removeFirst()
            }
            if bytes.count < 32 {
                bytes = Array(repeating: 0, count: 32 - bytes.count) + bytes
            }
            return Data(bytes.prefix(32))
        }
        return fixed32(r) + fixed32(s)
    }
}
