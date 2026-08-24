//
//  CidaasHTTPProof.swift
//  Cidaas
//

import CryptoKit
import Foundation
import LocalAuthentication
import Security

/// Builds DPoP proof JWTs for OAuth token calls and device-registration attestation payloads.
@available(iOS 14.0, *)
enum CidaasHTTPProof {

    enum KeychainTag {
        static let dpop = "com.cidaas.sdk.dpop.ecdsa"
        static let biometric = "com.cidaas.sdk.biometric.ecdsa"
    }

    struct DeviceRegistrationMaterial {
        let dpopThumbprint: String
        let biometricThumbprint: String
        let biometricPublicKeyDER: String
        private let dpopPrivateKey: SecKey

        init(
            dpopThumbprint: String,
            biometricThumbprint: String,
            biometricPublicKeyDER: String,
            dpopPrivateKey: SecKey
        ) {
            self.dpopThumbprint = dpopThumbprint
            self.biometricThumbprint = biometricThumbprint
            self.biometricPublicKeyDER = biometricPublicKeyDER
            self.dpopPrivateKey = dpopPrivateKey
        }

        /// Builds the verify `dpop+jwt`. `rawAttestation` may be empty when platform attestation is omitted.
        func attestationJWT(
            rawAttestation: String,
            verificationURLString: String,
            httpMethod: String
        ) throws -> String {
            let attestation = rawAttestation.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: verificationURLString) else {
                throw NSError(
                    domain: "CidaasHTTPProof",
                    code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "invalid URL for attestation JWT"]
                )
            }
            return try CidaasHTTPProof.attestationProofJWT(
                rawAttestation: attestation,
                biometricPublicKeyDER: biometricPublicKeyDER,
                httpMethod: httpMethod,
                httpURL: url,
                privateKey: dpopPrivateKey
            )
        }
    }

    static func loadDeviceRegistrationMaterial(
        dpopKeyTag: String = KeychainTag.dpop,
        biometricKeyTag: String = KeychainTag.biometric
    ) throws -> DeviceRegistrationMaterial {
        let dpopKey = try SigningKey.loadOrCreate(tag: dpopKeyTag, secureEnclave: false)
        let dpopThumbprint = try jwkThumbprintSHA256(privateKey: dpopKey)
        let context = LAContext()
        let biometricKey = try SigningKey.loadOrCreate(tag: biometricKeyTag, secureEnclave: true, context: context)
        return DeviceRegistrationMaterial(
            dpopThumbprint: dpopThumbprint,
            biometricThumbprint: try jwkThumbprintSHA256(privateKey: biometricKey),
            biometricPublicKeyDER: try pkixDERBase64(from: biometricKey),
            dpopPrivateKey: dpopKey
        )
    }

    /// RFC 7638 JWK thumbprint for the SDK DPoP key, used as `dpop_jkt` on authorization requests.
    static func dpopJKT(dpopKeyTag: String = KeychainTag.dpop) -> String? {
        guard let key = try? SigningKey.loadOrCreate(tag: dpopKeyTag, secureEnclave: false) else { return nil }
        return try? jwkThumbprintSHA256(privateKey: key)
    }

    /// `DPoP` proof JWT header.
    /// - Parameter accessToken: When presenting an access token (resource APIs), include RFC 9449 `ath`.
    ///   Omit for `/token-srv/token` (token endpoint must not send `ath`).
    static func dpopProofHeader(
        urlString: String,
        httpMethod: String,
        accessToken: String? = nil
    ) throws -> [String: String] {
        guard let url = URL(string: urlString) else {
            throw NSError(
                domain: "CidaasHTTPProof",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "invalid URL for DPoP proof"]
            )
        }
        let privateKey = try SigningKey.loadOrCreate(tag: KeychainTag.dpop, secureEnclave: false)
        let proof = try dpopProofJWT(
            httpMethod: httpMethod,
            httpURL: url,
            privateKey: privateKey,
            accessToken: accessToken
        )
        return ["DPoP": proof]
    }

    // MARK: - Signing keys

    private enum SigningKey {
        static func loadOrCreate(tag: String, secureEnclave: Bool, context: LAContext = LAContext()) throws -> SecKey {
            let tagData = tag.data(using: .utf8)!
            if let existing = loadPrivate(tagData: tagData, context: secureEnclave ? context : nil) {
                return existing
            }
            var error: Unmanaged<CFError>?
            if secureEnclave {
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
                        kSecAttrApplicationTag as String: tagData,
                        kSecAttrAccessControl as String: access,
                    ],
                ]
                guard let key = SecKeyCreateRandomKey(attrs as CFDictionary, &error) else {
                    throw error!.takeRetainedValue() as Error
                }
                return key
            }
            let attrs: [String: Any] = [
                kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                kSecAttrKeySizeInBits as String: 256,
                kSecPrivateKeyAttrs as String: [
                    kSecAttrIsPermanent as String: true,
                    kSecAttrApplicationTag as String: tagData,
                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                ],
            ]
            guard let key = SecKeyCreateRandomKey(attrs as CFDictionary, &error) else {
                throw error!.takeRetainedValue() as Error
            }
            return key
        }

        private static func loadPrivate(tagData: Data, context: LAContext?) -> SecKey? {
            var query: [String: Any] = [
                kSecClass as String: kSecClassKey,
                kSecAttrApplicationTag as String: tagData,
                kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                kSecReturnRef as String: true,
            ]
            if let context {
                query[kSecUseAuthenticationContext as String] = context
            }
            var item: CFTypeRef?
            let status = SecItemCopyMatching(query as CFDictionary, &item)
            guard status == errSecSuccess, let key = item else { return nil }
            return (key as! SecKey)
        }
    }

    // MARK: - DPoP proof JWT

    private struct DPoPProofClaims: Encodable {
        let htm: String
        let htu: String
        let iat: Int
        let jti: String
        /// RFC 9449 access-token hash; only when presenting an access token to a resource server.
        let ath: String?
    }

    // MARK: - Attestation JWT

    private struct AttestationProofClaims: Encodable {
        let htm: String
        let htu: String
        let iat: Int
        let jti: String
        let attestation: String
        let biometricPublicKeyDER: String

        enum CodingKeys: String, CodingKey {
            case htm
            case htu
            case iat
            case jti
            case attestation
            case biometricPublicKeyDER = "biometric_public_key_der"
        }
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

    private static func dpopProofJWT(
        httpMethod: String,
        httpURL: URL,
        privateKey: SecKey,
        accessToken: String? = nil
    ) throws -> String {
        let trimmedToken = accessToken?.trimmingCharacters(in: .whitespacesAndNewlines)
        let ath: String? = {
            guard let trimmedToken, !trimmedToken.isEmpty else { return nil }
            return accessTokenHash(trimmedToken)
        }()
        let claims = DPoPProofClaims(
            htm: httpMethod.uppercased(),
            htu: canonicalHTU(httpURL),
            iat: Int(Date().timeIntervalSince1970.rounded(.down)),
            jti: UUID().uuidString.lowercased(),
            ath: ath
        )
        return try signProofJWT(typ: "dpop+jwt", privateKey: privateKey, claims: claims)
    }

    private static func attestationProofJWT(
        rawAttestation: String,
        biometricPublicKeyDER: String,
        httpMethod: String,
        httpURL: URL,
        privateKey: SecKey
    ) throws -> String {
        let claims = AttestationProofClaims(
            htm: httpMethod.uppercased(),
            htu: canonicalHTU(httpURL),
            iat: Int(Date().timeIntervalSince1970.rounded(.down)),
            jti: UUID().uuidString.lowercased(),
            attestation: rawAttestation,
            biometricPublicKeyDER: biometricPublicKeyDER
        )
        return try signProofJWT(typ: "dpop+jwt", privateKey: privateKey, claims: claims)
    }

    private static func signProofJWT<C: Encodable>(
        typ: String,
        privateKey: SecKey,
        claims: C
    ) throws -> String {
        let jwk = try ecP256JWK(from: privateKey)
        let header = ProofHeader(typ: typ, alg: "ES256", jwk: jwk)
        let headerB64 = base64URL(try JSONEncoder().encode(header))
        let claimsB64 = base64URL(try JSONEncoder().encode(claims))
        let signingInput = "\(headerB64).\(claimsB64)"
        let digest = Data(SHA256.hash(data: Data(signingInput.utf8)))
        let signature = try signDigest(privateKey: privateKey, digest32: digest)
        return "\(signingInput).\(base64URL(signature))"
    }

    private static func ecP256JWK(from privateKey: SecKey) throws -> JWK {
        let (x, y) = try ecP256PublicCoordinates(from: privateKey)
        return JWK(kty: "EC", crv: "P-256", x: base64URL(x), y: base64URL(y))
    }

    private static func ecP256PublicCoordinates(from privateKey: SecKey) throws -> (x: Data, y: Data) {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw NSError(domain: "CidaasHTTPProof", code: 20, userInfo: [NSLocalizedDescriptionKey: "missing public key"])
        }
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }
        guard publicKeyData.count == 65, publicKeyData.first == 0x04 else {
            throw NSError(domain: "CidaasHTTPProof", code: 21, userInfo: [NSLocalizedDescriptionKey: "unexpected public key format"])
        }
        return (publicKeyData.subdata(in: 1 ..< 33), publicKeyData.subdata(in: 33 ..< 65))
    }

    private static func jwkThumbprintSHA256(privateKey: SecKey) throws -> String {
        let (x, y) = try ecP256PublicCoordinates(from: privateKey)
        let json = "{\"crv\":\"P-256\",\"kty\":\"EC\",\"x\":\"\(base64URL(x))\",\"y\":\"\(base64URL(y))\"}"
        let digest = Data(SHA256.hash(data: Data(json.utf8)))
        return base64URL(digest)
    }

    private static func pkixDERBase64(from privateKey: SecKey) throws -> String {
        try pkixDER(from: privateKey).base64EncodedString()
    }

    /// Builds PKIX SPKI DER for an EC P-256 public key.
    private static func pkixDER(from privateKey: SecKey) throws -> Data {
        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw NSError(domain: "CidaasHTTPProof", code: 24, userInfo: [NSLocalizedDescriptionKey: "missing public key"])
        }
        var error: Unmanaged<CFError>?
        guard let point = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }
        guard point.count == 65, point.first == 0x04 else {
            throw NSError(domain: "CidaasHTTPProof", code: 25, userInfo: [NSLocalizedDescriptionKey: "unexpected public key format"])
        }
        let algorithmID = Data([
            0x30, 0x13,
            0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01,
            0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07,
        ])
        var bitString = Data([0x03, 0x42, 0x00])
        bitString.append(point)
        var payload = Data()
        payload.append(algorithmID)
        payload.append(bitString)
        var der = Data([0x30, UInt8(payload.count)])
        der.append(payload)
        return der
    }

    private static func signDigest(privateKey: SecKey, digest32: Data) throws -> Data {
        var error: Unmanaged<CFError>?
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

    /// RFC 9449 `ath` = base64url(SHA-256(access_token)) using the raw token string.
    private static func accessTokenHash(_ accessToken: String) -> String {
        let digest = Data(SHA256.hash(data: Data(accessToken.utf8)))
        return base64URL(digest)
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
                throw NSError(domain: "CidaasHTTPProof", code: 30, userInfo: [NSLocalizedDescriptionKey: "bad DER signature"])
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
                throw NSError(domain: "CidaasHTTPProof", code: 31, userInfo: [NSLocalizedDescriptionKey: "bad DER length"])
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
            throw NSError(domain: "CidaasHTTPProof", code: 32, userInfo: [NSLocalizedDescriptionKey: "bad DER integer"])
        }
        let rLength = try readLength()
        let r = der.subdata(in: index ..< index + rLength)
        index += rLength
        guard try readByte() == 0x02 else {
            throw NSError(domain: "CidaasHTTPProof", code: 33, userInfo: [NSLocalizedDescriptionKey: "bad DER integer"])
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
