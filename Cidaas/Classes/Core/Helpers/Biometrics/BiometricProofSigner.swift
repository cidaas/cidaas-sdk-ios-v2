//
//  BiometricProofSigner.swift
//  Cidaas
//
//  Creates biometric+jwt attestation JWTs for MFA TouchID enrollment and authentication.

import CryptoKit
import Foundation
import LocalAuthentication
import Security

/// Creates biometric proof JWTs (biometric+jwt) for MFA TouchID flows.
/// Uses a Secure Enclave EC P-256 key bound to biometrics.
@available(iOS 14.0, *)
public enum BiometricProofSigner {
    
    public enum KeychainTag {
        static let mfaBiometric = "com.cidaas.sdk.biometric.ecdsa"
    }
    
    public enum BiometricProofError: Error, LocalizedError {
        case keyGenerationFailed(String)
        case signingFailed(String)
        case invalidURL
        case publicKeyExtractionFailed
        case biometricAuthFailed(String)
        
        public var errorDescription: String? {
            switch self {
            case .keyGenerationFailed(let msg): return "Key generation failed: \(msg)"
            case .signingFailed(let msg): return "Signing failed: \(msg)"
            case .invalidURL: return "Invalid URL for biometric proof"
            case .publicKeyExtractionFailed: return "Failed to extract public key"
            case .biometricAuthFailed(let msg): return "Biometric authentication failed: \(msg)"
            }
        }
    }
    
    /// Result type for biometric proof JWT creation.
    public enum ProofResult {
        case success(jwt: String)
        case failure(error: BiometricProofError)
    }
    
    /// Creates a biometric proof JWT for the given HTTP method and URL.
    /// This triggers biometric authentication via Secure Enclave key.
    public static func createProofJWT(
        httpMethod: String,
        requestURL: String,
        localizedReason: String,
        completion: @escaping (ProofResult) -> Void
    ) {
        guard let url = URL(string: requestURL) else {
            completion(.failure(error: .invalidURL))
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let context = LAContext()
                context.localizedReason = localizedReason
                
                let privateKey = try loadOrCreateKey(context: context)
                let jwt = try signProofJWT(
                    httpMethod: httpMethod,
                    httpURL: url,
                    privateKey: privateKey
                )
                
                DispatchQueue.main.async {
                    completion(.success(jwt: jwt))
                }
            } catch let error as BiometricProofError {
                DispatchQueue.main.async {
                    completion(.failure(error: error))
                }
            } catch {
                DispatchQueue.main.async {
                    completion(.failure(error: .signingFailed(error.localizedDescription)))
                }
            }
        }
    }
    
    /// Ensures the biometric key exists (creates if needed).
    public static func ensureKey() throws {
        let context = LAContext()
        _ = try loadOrCreateKey(context: context)
    }
    
    /// Deletes the biometric key from keychain.
    public static func deleteKey() {
        let tagData = KeychainTag.mfaBiometric.data(using: .utf8)!
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Private Implementation
    
    private static func loadOrCreateKey(context: LAContext) throws -> SecKey {
        let tagData = KeychainTag.mfaBiometric.data(using: .utf8)!
        
        // Try to load existing key
        if let existing = loadPrivateKey(tagData: tagData, context: context) {
            return existing
        }
        
        // Create new key in Secure Enclave with biometric protection
        var error: Unmanaged<CFError>?
        
        guard let access = SecAccessControlCreateWithFlags(
            nil,
            kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly,
            [.privateKeyUsage, .biometryCurrentSet],
            &error
        ) else {
            throw BiometricProofError.keyGenerationFailed(
                error?.takeRetainedValue().localizedDescription ?? "Access control creation failed"
            )
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
            throw BiometricProofError.keyGenerationFailed(
                error?.takeRetainedValue().localizedDescription ?? "Key creation failed"
            )
        }
        
        return key
    }
    
    private static func loadPrivateKey(tagData: Data, context: LAContext) -> SecKey? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassKey,
            kSecAttrApplicationTag as String: tagData,
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecReturnRef as String: true,
            kSecUseAuthenticationContext as String: context,
        ]
        
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let key = item else { return nil }
        return (key as! SecKey)
    }
    
    // MARK: - JWT Creation
    
    private struct BiometricProofClaims: Encodable {
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
    
    private static func signProofJWT(
        httpMethod: String,
        httpURL: URL,
        privateKey: SecKey
    ) throws -> String {
        let claims = BiometricProofClaims(
            htm: httpMethod.uppercased(),
            htu: canonicalHTU(httpURL),
            iat: Int(Date().timeIntervalSince1970.rounded(.down)),
            jti: UUID().uuidString.lowercased()
        )
        
        let jwk = try ecP256JWK(from: privateKey)
        let header = ProofHeader(typ: "biometric+jwt", alg: "ES256", jwk: jwk)
        
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
            throw BiometricProofError.publicKeyExtractionFailed
        }
        
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            throw BiometricProofError.publicKeyExtractionFailed
        }
        
        guard publicKeyData.count == 65, publicKeyData.first == 0x04 else {
            throw BiometricProofError.publicKeyExtractionFailed
        }
        
        return (publicKeyData.subdata(in: 1 ..< 33), publicKeyData.subdata(in: 33 ..< 65))
    }
    
    private static func signDigest(privateKey: SecKey, digest32: Data) throws -> Data {
        var error: Unmanaged<CFError>?
        guard let derSignature = SecKeyCreateSignature(
            privateKey,
            SecKeyAlgorithm.ecdsaSignatureDigestX962SHA256,
            digest32 as CFData,
            &error
        ) as Data? else {
            throw BiometricProofError.signingFailed(
                error?.takeRetainedValue().localizedDescription ?? "Signature creation failed"
            )
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
                throw BiometricProofError.signingFailed("Bad DER signature")
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
                throw BiometricProofError.signingFailed("Bad DER length")
            }
            var length = 0
            for _ in 0 ..< byteCount {
                length = (length << 8) | Int(try readByte())
            }
            return length
        }
        
        _ = try readByte() // sequence tag
        _ = try readLength() // sequence length
        
        guard try readByte() == 0x02 else {
            throw BiometricProofError.signingFailed("Bad DER integer")
        }
        let rLength = try readLength()
        let r = der.subdata(in: index ..< index + rLength)
        index += rLength
        
        guard try readByte() == 0x02 else {
            throw BiometricProofError.signingFailed("Bad DER integer")
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
