//
//  CidaasCertificatePinning.swift
//  Cidaas
//

import Alamofire
import Foundation

// Optional SDK defaults. Apps should pass hashes via Cidaas.setPublicKeyPinning(trustedPublicKeyHashes:).
public enum CidaasPublicKeyPinningConfiguration {
    public static let primaryPublicKeySHA256Base64 = "REPLACE_WITH_PRIMARY_PUBLIC_KEY_SHA256_BASE64"
    public static let backupPublicKeySHA256Base64 = "REPLACE_WITH_BACKUP_PUBLIC_KEY_SHA256_BASE64"

    public static var defaultTrustedHashes: [String] {
        [primaryPublicKeySHA256Base64, backupPublicKeySHA256Base64].filter {
            !$0.isEmpty && !$0.hasPrefix("REPLACE_WITH_")
        }
    }
}

public struct CidaasPublicKeyPinningOptions {
    public let trustedPublicKeyHashes: [String]
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
