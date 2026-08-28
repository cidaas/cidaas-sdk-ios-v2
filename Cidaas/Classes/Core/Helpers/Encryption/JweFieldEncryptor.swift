//
//  JweFieldEncryptor.swift
//  Cidaas
//

import CommonCrypto
import CryptoSwift
import Foundation
import Security

/// Builds compact JWE using ECDH-ES + A256GCM.
/// Protected header includes `kid`, `iat`, `jti`, and the ephemeral public key (`epk`).
public enum JweFieldEncryptor {

    public enum EncryptError: Error, LocalizedError {
        case missingKid
        case keyGenerationFailed
        case keyExchangeFailed
        case invalidSharedSecret
        case randomGenerationFailed
        case encryptionFailed(String)

        public var errorDescription: String? {
            switch self {
            case .missingKid:
                return "Encryption JWK must include kid"
            case .keyGenerationFailed:
                return "Failed to generate ephemeral EC P-256 key"
            case .keyExchangeFailed:
                return "ECDH key agreement failed"
            case .invalidSharedSecret:
                return "Unexpected ECDH shared secret length"
            case .randomGenerationFailed:
                return "Failed to generate secure random bytes"
            case .encryptionFailed(let detail):
                return "JWE encryption failed: \(detail)"
            }
        }
    }

    /// Encrypts `plaintext` to a compact JWE string for the given recipient public key.
    public static func encrypt(_ plaintext: String, with encryptionPublicKey: EncPublicKey) throws -> String {
        let kid = encryptionPublicKey.kid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kid.isEmpty else { throw EncryptError.missingKid }

        let recipientKey = try encryptionPublicKey.secKey()
        let ephemeralPrivate = try generateEphemeralP256PrivateKey()
        guard let ephemeralPublic = SecKeyCopyPublicKey(ephemeralPrivate) else {
            throw EncryptError.keyGenerationFailed
        }

        let sharedZ = try ecdhSharedSecret(privateKey: ephemeralPrivate, publicKey: recipientKey)
        guard sharedZ.count == 32 else { throw EncryptError.invalidSharedSecret }
        let cek = concatKDF(z: sharedZ, keyDataLenBits: 256, encAlgorithm: "A256GCM")

        let (epkX, epkY) = try ecP256PublicCoordinates(from: ephemeralPublic)
        let iat = Int(Date().timeIntervalSince1970)
        let jti = UUID().uuidString

        // Protected header is serialized once and used both on the wire and as AES-GCM AAD.
        var header = [String: Any]()
        header["alg"] = "ECDH-ES"
        header["enc"] = "A256GCM"
        header["kid"] = kid
        header["iat"] = iat
        header["jti"] = jti
        header["epk"] = [
            "kty": "EC",
            "crv": "P-256",
            "x": base64URL(epkX),
            "y": base64URL(epkY)
        ]

        let headerJSON = try JSONSerialization.data(withJSONObject: header, options: [])
        let protectedB64 = base64URL(headerJSON)

        let iv = try randomBytes(count: 12)
        let aad = Array(protectedB64.utf8)
        let gcm = GCM(iv: Array(iv), additionalAuthenticatedData: aad, mode: .detached)
        let aes = try AES(key: Array(cek), blockMode: gcm, padding: .noPadding)
        let ciphertext: [UInt8]
        do {
            ciphertext = try aes.encrypt(Array(plaintext.utf8))
        } catch {
            throw EncryptError.encryptionFailed(error.localizedDescription)
        }
        guard let tag = gcm.authenticationTag, tag.count == 16 else {
            throw EncryptError.encryptionFailed("missing GCM authentication tag")
        }

        // ECDH-ES (direct key agreement): Encrypted Key is empty in compact serialization.
        return "\(protectedB64)..\(base64URL(iv)).\(base64URL(Data(ciphertext))).\(base64URL(Data(tag)))"
    }

    // MARK: - ECDH / KDF

    private static func generateEphemeralP256PrivateKey() throws -> SecKey {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeySizeInBits as String: 256,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: false
            ]
        ]
        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            if let error {
                throw error.takeRetainedValue() as Error
            }
            throw EncryptError.keyGenerationFailed
        }
        return key
    }

    private static func ecdhSharedSecret(privateKey: SecKey, publicKey: SecKey) throws -> Data {
        let params: [String: Any] = [
            String(SecKeyKeyExchangeParameter.requestedSize.rawValue): 32
        ]
        var error: Unmanaged<CFError>?
        guard let shared = SecKeyCopyKeyExchangeResult(
            privateKey,
            .ecdhKeyExchangeStandard,
            publicKey,
            params as CFDictionary,
            &error
        ) as Data? else {
            if let error {
                throw error.takeRetainedValue() as Error
            }
            throw EncryptError.keyExchangeFailed
        }
        return shared
    }

    /// RFC 7518 §4.6.2 Concat KDF with SHA-256 (single round for 256-bit CEK).
    private static func concatKDF(z: Data, keyDataLenBits: Int, encAlgorithm: String) -> Data {
        var otherInfo = Data()
        let encBytes = Array(encAlgorithm.utf8)
        otherInfo.append(uint32BE(UInt32(encBytes.count)))
        otherInfo.append(contentsOf: encBytes)
        otherInfo.append(uint32BE(0)) // PartyUInfo empty
        otherInfo.append(uint32BE(0)) // PartyVInfo empty
        otherInfo.append(uint32BE(UInt32(keyDataLenBits)))

        var input = Data()
        input.append(uint32BE(1))
        input.append(z)
        input.append(otherInfo)
        return sha256(input)
    }

    private static func uint32BE(_ value: UInt32) -> Data {
        var be = value.bigEndian
        return Data(bytes: &be, count: 4)
    }

    private static func sha256(_ data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            _ = CC_SHA256(buffer.baseAddress, CC_LONG(buffer.count), &hash)
        }
        return Data(hash)
    }

    private static func ecP256PublicCoordinates(from publicKey: SecKey) throws -> (Data, Data) {
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            if let error {
                throw error.takeRetainedValue() as Error
            }
            throw EncryptError.keyGenerationFailed
        }
        guard publicKeyData.count == 65, publicKeyData.first == 0x04 else {
            throw EncryptError.keyGenerationFailed
        }
        return (publicKeyData.subdata(in: 1 ..< 33), publicKeyData.subdata(in: 33 ..< 65))
    }

    private static func randomBytes(count: Int) throws -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        guard status == errSecSuccess else {
            throw EncryptError.randomGenerationFailed
        }
        return Data(bytes)
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
