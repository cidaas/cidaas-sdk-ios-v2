//
//  PublicKeyHashTrustEvaluator.swift
//  Cidaas
//

import Alamofire
import CommonCrypto
import Foundation
import Security

public final class PublicKeyHashTrustEvaluator: ServerTrustEvaluating {

    private let trustedPublicKeyHashes: Set<String>
    private let performDefaultValidation: Bool
    private let validateHost: Bool

    public init(
        trustedPublicKeyHashes: [String],
        performDefaultValidation: Bool = true,
        validateHost: Bool = true
    ) {
        self.trustedPublicKeyHashes = Set(
            trustedPublicKeyHashes.map { Self.normalizeBase64Hash($0) }.filter { !$0.isEmpty }
        )
        self.performDefaultValidation = performDefaultValidation
        self.validateHost = validateHost
    }

    public func evaluate(_ trust: SecTrust, forHost host: String) throws {
        guard !trustedPublicKeyHashes.isEmpty else {
            throw AFError.serverTrustEvaluationFailed(reason: .noPublicKeysFound)
        }

        if performDefaultValidation {
            try trust.af.performDefaultValidation(forHost: host)
        }

        if validateHost {
            try trust.af.performValidation(forHost: host)
        }

        let serverHashes = Set(trust.af.publicKeys.compactMap { Self.sha256SPKIBase64Hash(for: $0) })
        guard !serverHashes.isDisjoint(with: trustedPublicKeyHashes) else {
            throw AFError.serverTrustEvaluationFailed(
                reason: .publicKeyPinningFailed(
                    host: host,
                    trust: trust,
                    pinnedKeys: [],
                    serverKeys: trust.af.publicKeys
                )
            )
        }
    }

    static func sha256SPKIBase64Hash(for publicKey: SecKey) -> String? {
        guard let spkiData = spkiData(for: publicKey) else { return nil }
        return normalizeBase64Hash(sha256Base64(spkiData))
    }

    static func spkiData(for publicKey: SecKey) -> Data? {
        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            return nil
        }

        guard let attributes = SecKeyCopyAttributes(publicKey) as? [CFString: Any],
              let keyType = attributes[kSecAttrKeyType] as? String else {
            return nil
        }

        if keyType == (kSecAttrKeyTypeRSA as String) {
            switch keyData.count {
            case 256:
                return Data(rsa2048ASN1Header) + keyData
            case 512:
                return Data(rsa4096ASN1Header) + keyData
            default:
                return nil
            }
        }

        if keyType == (kSecAttrKeyTypeECSECPrimeRandom as String), keyData.count == 65 {
            return Data(ec256ASN1Header) + keyData
        }

        return nil
    }

    static func sha256Base64(_ data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            _ = CC_SHA256(baseAddress, CC_LONG(buffer.count), &digest)
        }
        return Data(digest).base64EncodedString()
    }

    static func normalizeBase64Hash(_ hash: String) -> String {
        hash.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static let rsa2048ASN1Header: [UInt8] = [
        0x30, 0x82, 0x01, 0x22, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
        0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x01, 0x0f, 0x00
    ]

    private static let rsa4096ASN1Header: [UInt8] = [
        0x30, 0x82, 0x02, 0x0a, 0x30, 0x0d, 0x06, 0x09, 0x2a, 0x86, 0x48, 0x86,
        0xf7, 0x0d, 0x01, 0x01, 0x01, 0x05, 0x00, 0x03, 0x82, 0x02, 0x03, 0x00
    ]

    private static let ec256ASN1Header: [UInt8] = [
        0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x02,
        0x01, 0x06, 0x08, 0x2a, 0x86, 0x48, 0xce, 0x3d, 0x03, 0x01, 0x07, 0x03,
        0x42, 0x00
    ]
}
