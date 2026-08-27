//
//  JwksClient.swift
//  Cidaas
//

import Alamofire
import Foundation

/// Fetches and caches JWKS from `{baseUrl}/.well-known/jwks.json`.
///
/// Network fetches never run on the main thread. Fresh entries are reused for `cacheTTL`.
/// `prefetchAsync` (also invoked by `Cidaas.setEncryptionEnabled(true)`) at app startup.
///
/// JWKS requests use the shared SDK Alamofire session.
public enum JwksClient {

    static let cacheTTL: TimeInterval = 15 * 60

    private struct CachedJwks {
        let baseUrl: String
        let jwksJson: String
        let fetchedAt: Date
    }

    private static let lock = NSLock()
    private static var cache: CachedJwks?
    private static var refreshScheduled = false
    private static let fetchQueue = DispatchQueue(label: "com.cidaas.jwks-fetch", qos: .utility)

    /// Test hook that returns JWKS JSON without performing HTTP.
    static var fetchOverride: ((String) throws -> String)?

    /// Clears the cached JWKS document (for example after a domain change).
    public static func clearCache() {
        lock.lock()
        cache = nil
        refreshScheduled = false
        lock.unlock()
    }

    /// Test hook that injects a cached JWKS entry.
    static func putCacheForTest(baseUrl: String, jwksJson: String, fetchedAt: Date = Date()) {
        lock.lock()
        cache = CachedJwks(baseUrl: normalizeBaseUrl(baseUrl), jwksJson: jwksJson, fetchedAt: fetchedAt)
        lock.unlock()
    }

    /// Warms the JWKS cache on a background queue. Safe to call from the main thread.
    /// No-op log when the cache is already fresh for the domain.
    public static func prefetchAsync(baseUrlOverride: String? = nil) {
        let baseUrl = normalizeBaseUrl(resolvedBaseUrl(override: baseUrlOverride))
        guard !baseUrl.isEmpty else {
            logw("JWKS prefetch skipped: domain URL not configured", cname: "cidaas-sdk-jwks-log")
            return
        }
        fetchQueue.async {
            if readFreshCache(baseUrl: baseUrl) != nil {
                return
            }
            do {
                _ = try getJwksJson(baseUrlOverride: baseUrl)
            } catch {
                logw("JWKS prefetch failed for \(baseUrl): \(error.localizedDescription)", cname: "cidaas-sdk-jwks-log")
            }
        }
    }

    /// Returns JWKS JSON for the given or configured domain.
    /// - Throws: when the domain is missing, the main-thread cache is empty, or the network fetch fails.
    public static func getJwksJson(baseUrlOverride: String? = nil) throws -> String {
        let baseUrl = normalizeBaseUrl(resolvedBaseUrl(override: baseUrlOverride))
        guard !baseUrl.isEmpty else {
            throw JwksError.domainNotConfigured
        }

        if let fresh = readFreshCache(baseUrl: baseUrl) {
            return fresh
        }

        let stale = readStaleCache(baseUrl: baseUrl)
        if Thread.isMainThread {
            if let stale {
                scheduleBackgroundRefresh(baseUrl: baseUrl)
                logw("Using stale JWKS for \(baseUrl) while refreshing in background", cname: "cidaas-sdk-jwks-log")
                return stale
            }
            throw JwksError.emptyCacheOnMainThread
        }

        return try fetchFromNetwork(baseUrl: baseUrl)
    }

    // MARK: - Private

    private static func resolvedBaseUrl(override: String?) -> String {
        if let override, !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return override
        }
        return DBHelper.shared.getPropertyFile()?["DomainURL"] ?? ""
    }

    private static func readFreshCache(baseUrl: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard let cached = cache,
              cached.baseUrl == baseUrl,
              !cached.jwksJson.isEmpty,
              Date().timeIntervalSince(cached.fetchedAt) < cacheTTL else {
            return nil
        }
        return cached.jwksJson
    }

    private static func readStaleCache(baseUrl: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        guard let cached = cache,
              cached.baseUrl == baseUrl,
              !cached.jwksJson.isEmpty else {
            return nil
        }
        return cached.jwksJson
    }

    private static func scheduleBackgroundRefresh(baseUrl: String) {
        lock.lock()
        let shouldSchedule = !refreshScheduled
        if shouldSchedule { refreshScheduled = true }
        lock.unlock()
        guard shouldSchedule else { return }

        fetchQueue.async {
            defer {
                lock.lock()
                refreshScheduled = false
                lock.unlock()
            }
            do {
                _ = try fetchFromNetwork(baseUrl: baseUrl)
                logw("JWKS background refresh OK for \(baseUrl)", cname: "cidaas-sdk-jwks-log")
            } catch {
                logw("JWKS background refresh failed for \(baseUrl): \(error.localizedDescription)", cname: "cidaas-sdk-jwks-log")
            }
        }
    }

    private static func fetchFromNetwork(baseUrl: String) throws -> String {
        if let fresh = readFreshCache(baseUrl: baseUrl) {
            return fresh
        }

        if let fetchOverride {
            let json = try fetchOverride(baseUrl)
            lock.lock()
            cache = CachedJwks(baseUrl: baseUrl, jwksJson: json, fetchedAt: Date())
            lock.unlock()
            return json
        }

        let url = baseUrl + "/.well-known/jwks.json"
        logw("Fetching JWKS \(url)", cname: "cidaas-sdk-jwks-log")

        let semaphore = DispatchSemaphore(value: 0)
        var resultBody: String?
        var resultError: Error?

        SessionManager.shared.session.request(url, method: .get)
            .validate(statusCode: 200 ..< 300)
            .responseString { response in
                switch response.result {
                case .success(let body):
                    let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        resultError = JwksError.emptyResponse
                    } else {
                        resultBody = body
                    }
                case .failure(let error):
                    if let status = response.response?.statusCode {
                        resultError = JwksError.httpStatus(status)
                    } else {
                        resultError = error
                    }
                }
                semaphore.signal()
            }

        semaphore.wait()

        if let error = resultError {
            throw error
        }
        guard let jwksJson = resultBody else {
            throw JwksError.emptyResponse
        }

        lock.lock()
        cache = CachedJwks(baseUrl: baseUrl, jwksJson: jwksJson, fetchedAt: Date())
        lock.unlock()
        logw("JWKS fetched and cached for \(baseUrl) (\(jwksJson.count) bytes)", cname: "cidaas-sdk-jwks-log")
        return jwksJson
    }

    static func normalizeBaseUrl(_ baseUrl: String?) -> String {
        guard var trimmed = baseUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return ""
        }
        while trimmed.hasSuffix("/") {
            trimmed.removeLast()
        }
        return trimmed
    }

    public enum JwksError: Error, LocalizedError {
        case domainNotConfigured
        case emptyCacheOnMainThread
        case emptyResponse
        case httpStatus(Int)

        public var errorDescription: String? {
            switch self {
            case .domainNotConfigured:
                return "Domain URL is not configured"
            case .emptyCacheOnMainThread:
                return "JWKS cache is empty and encryption was requested on the main thread. Call JwksClient.prefetchAsync() or Cidaas.setEncryptionEnabled(true) before performing sensitive operations."
            case .emptyResponse:
                return "JWKS response body is empty"
            case .httpStatus(let code):
                return "JWKS fetch failed with HTTP \(code)"
            }
        }
    }
}
