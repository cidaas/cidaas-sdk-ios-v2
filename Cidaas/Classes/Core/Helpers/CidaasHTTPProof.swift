//
//  CidaasHTTPProof.swift
//  Cidaas
//

import CryptoKit
import Foundation
import LocalAuthentication
import Security

/// Builds `DPoP` and `Biometric` proof JWT headers for HTTP requests.
@available(iOS 14.0, *)
enum CidaasHTTPProof {

    enum KeychainTag {
        /// Single DPoP key for device registration and all `useDpop` session calls. 
        static let dpop = "com.cidaas.sdk.dpop.ecdsa"
        /// Single biometric key for device registration and all `useBiometric` session calls.
        static let biometric = "com.cidaas.sdk.biometric.ecdsa"
    }

    static func proofHeaders(
        urlString: String,
        httpMethod: String,
        useDpop: Bool,
        useBiometric: Bool,
        biometricLocalizedReason: String,
        dpopKeyTag: String = KeychainTag.dpop,
        biometricKeyTag: String = KeychainTag.biometric
    ) throws -> [String: String] {
        guard useDpop || useBiometric else { return [:] }
        guard let url = URL(string: urlString) else {
            throw NSError(
                domain: "CidaasHTTPProof",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "invalid URL for HTTP proof"]
            )
        }

        var headers: [String: String] = [:]
        if useDpop {
            let privateKey = try SigningKey.loadOrCreate(tag: dpopKeyTag, secureEnclave: false)
            headers["DPoP"] = try proofJWT(
                typ: "dpop+jwt",
                httpMethod: httpMethod,
                httpURL: url,
                privateKey: privateKey
            )
        }
        if useBiometric {
            let context = LAContext()
            context.localizedReason = biometricLocalizedReason
            let privateKey = try SigningKey.loadOrCreate(tag: biometricKeyTag, secureEnclave: true, context: context)
            headers["Biometric"] = try proofJWT(
                typ: "biometric+jwt",
                httpMethod: httpMethod,
                httpURL: url,
                privateKey: privateKey,
                biometricContext: context
            )
        }
        return headers
    }

    static func jwkThumbprints(
        useDpop: Bool,
        useBiometric: Bool,
        biometricLocalizedReason: String,
        dpopKeyTag: String = KeychainTag.dpop,
        biometricKeyTag: String = KeychainTag.biometric
    ) throws -> (dpop: String?, biometric: String?) {
        var dpopThumbprint: String?
        var biometricThumbprint: String?
        if useDpop {
            let key = try SigningKey.loadOrCreate(tag: dpopKeyTag, secureEnclave: false)
            dpopThumbprint = try jwkThumbprintSHA256(privateKey: key)
        }
        if useBiometric {
            let context = LAContext()
            context.localizedReason = biometricLocalizedReason
            let key = try SigningKey.loadOrCreate(tag: biometricKeyTag, secureEnclave: true, context: context)
            biometricThumbprint = try jwkThumbprintSHA256(privateKey: key)
        }
        return (dpopThumbprint, biometricThumbprint)
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

    // MARK: - Proof JWT

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
            throw NSError(domain: "CidaasHTTPProof", code: 20, userInfo: [NSLocalizedDescriptionKey: "missing public key"])
        }
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }
        guard publicKeyData.count == 65, publicKeyData.first == 0x04 else {
            throw NSError(domain: "CidaasHTTPProof", code: 21, userInfo: [NSLocalizedDescriptionKey: "unexpected public key format"])
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
            throw NSError(domain: "CidaasHTTPProof", code: 22, userInfo: [NSLocalizedDescriptionKey: "missing public key"])
        }
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw error!.takeRetainedValue() as Error
        }
        guard publicKeyData.count == 65, publicKeyData.first == 0x04 else {
            throw NSError(domain: "CidaasHTTPProof", code: 23, userInfo: [NSLocalizedDescriptionKey: "unexpected public key format"])
        }
        let x = base64URL(publicKeyData.subdata(in: 1 ..< 33))
        let y = base64URL(publicKeyData.subdata(in: 33 ..< 65))
        let json = "{\"crv\":\"P-256\",\"kty\":\"EC\",\"x\":\"\(x)\",\"y\":\"\(y)\"}"
        let digest = Data(SHA256.hash(data: Data(json.utf8)))
        return base64URL(digest)
    }

    private static func signDigest(privateKey: SecKey, digest32: Data, biometricContext: LAContext?) throws -> Data {
        var error: Unmanaged<CFError>?
        if let biometricContext, biometricContext.localizedReason.isEmpty {
            biometricContext.localizedReason = "Verify your identity"
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
