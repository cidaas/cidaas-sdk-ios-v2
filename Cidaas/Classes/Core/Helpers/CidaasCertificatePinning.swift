//
//  CidaasCertificatePinning.swift
//  Cidaas
//

import Alamofire
import Foundation

/// Hardcoded SHA-256 SPKI public key hashes (Base64). Replace placeholders before production use.
///
/// Generate hashes from a certificate, e.g.:
/// `openssl s_client -connect api.example.com:443 </dev/null 2>/dev/null | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64`
public enum CidaasPublicKeyPinningConfiguration {
    /// Primary server public key — SHA-256(SPKI), Base64.
    public static let primaryPublicKeySHA256Base64 = "REPLACE_WITH_PRIMARY_PUBLIC_KEY_SHA256_BASE64"
    /// Backup / failover certificate public key — SHA-256(SPKI), Base64.
    public static let backupPublicKeySHA256Base64 = "REPLACE_WITH_BACKUP_PUBLIC_KEY_SHA256_BASE64"

    /// Default trusted hashes (primary + backup), excluding unreplaced placeholders.
    public static var defaultTrustedHashes: [String] {
        [primaryPublicKeySHA256Base64, backupPublicKeySHA256Base64].filter {
            !$0.isEmpty && !$0.hasPrefix("REPLACE_WITH_")
        }
    }
}

/// Configuration for TLS public-key hash pinning on Alamofire ``Session`` traffic.
public struct CidaasPublicKeyPinningOptions {
    /// SHA-256 SPKI hashes (Base64) of trusted server public keys.
    public let trustedPublicKeyHashes: [String]
    /// Host names only (e.g. `api.example.com`), not full URLs.
    public let pinnedHosts: [String]
    public var validateHost: Bool
    public var performDefaultValidation: Bool

    public init(
        trustedPublicKeyHashes: [String],
        pinnedHosts: [String],
        validateHost: Bool = true,
        performDefaultValidation: Bool = true
    ) {
        self.trustedPublicKeyHashes = trustedPublicKeyHashes
        self.pinnedHosts = pinnedHosts
        self.validateHost = validateHost
        self.performDefaultValidation = performDefaultValidation
    }

    /// Uses ``CidaasPublicKeyPinningConfiguration/defaultTrustedHashes``.
    public init(
        pinnedHosts: [String],
        validateHost: Bool = true,
        performDefaultValidation: Bool = true
    ) {
        self.init(
            trustedPublicKeyHashes: CidaasPublicKeyPinningConfiguration.defaultTrustedHashes,
            pinnedHosts: pinnedHosts,
            validateHost: validateHost,
            performDefaultValidation: performDefaultValidation
        )
    }
}

public enum CidaasPublicKeyPinningLoader {

    /// Host from `DomainURL` in the SDK property file, if configured.
    public static func hostFromDomainURL(_ domainURL: String) -> String? {
        let trimmed = domainURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: trimmed), let host = url.host, !host.isEmpty else {
            return nil
        }
        return host
    }
}

enum CidaasCertificatePinning {

    static func makeServerTrustManager(options: CidaasPublicKeyPinningOptions) -> ServerTrustManager? {
        guard !options.trustedPublicKeyHashes.isEmpty, !options.pinnedHosts.isEmpty else {
            return nil
        }
        var evaluators: [String: ServerTrustEvaluating] = [:]
        let evaluator = PublicKeyHashTrustEvaluator(
            trustedPublicKeyHashes: options.trustedPublicKeyHashes,
            performDefaultValidation: options.performDefaultValidation,
            validateHost: options.validateHost
        )
        for host in options.pinnedHosts {
            let normalized = host.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty else { continue }
            evaluators[normalized] = evaluator
        }
        guard !evaluators.isEmpty else { return nil }
        return ServerTrustManager(allHostsMustBeEvaluated: true, evaluators: evaluators)
    }
}
