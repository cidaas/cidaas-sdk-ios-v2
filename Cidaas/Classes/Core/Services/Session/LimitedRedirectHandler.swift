//
//  LimitedRedirectHandler.swift
//  Cidaas
//

import Alamofire
import Foundation

/// Follows at most `maxRedirects` hops, then stops so the caller receives that response
/// (typically the last `Location` / webpage URL). Persists session cookies on each hop.
/// Does not follow custom-scheme URLs (app `redirect_uri`) — URLSession cannot load them.
final class LimitedRedirectHandler: RedirectHandler, @unchecked Sendable {

    private let maxRedirects: Int
    private let lock = NSLock()
    private var redirectCount = 0

    init(maxRedirects: Int) {
        self.maxRedirects = max(0, maxRedirects)
    }

    func task(
        _ task: URLSessionTask,
        willBeRedirectedTo request: URLRequest,
        for response: HTTPURLResponse,
        completion: @escaping (URLRequest?) -> Void
    ) {
        CidaasSessionCookies.persist(from: response)

        lock.lock()
        redirectCount += 1
        let count = redirectCount
        lock.unlock()

        guard count <= maxRedirects else {
            completion(nil)
            return
        }

        // ponytail: myapp://callback?code=… — refuse follow so Location is returned instead of NSURLErrorUnsupportedURL.
        if !Self.isHTTPURL(request.url) {
            completion(nil)
            return
        }

        var next = request
        // Always disable the jar on followed hops so URLSession cannot inject cookies
        // when mergeIntoCookieHeader returns nil (no device id / session cookies yet).
        next.httpShouldHandleCookies = false
        let existing = next.value(forHTTPHeaderField: "Cookie")
        let deviceId = SDKDeviceIdResolver.resolve()
        if let merged = CidaasSessionCookies.mergeIntoCookieHeader(existing, deviceId: deviceId) {
            next.setValue(merged, forHTTPHeaderField: "Cookie")
        }
        completion(next)
    }

    static func isHTTPURL(_ url: URL?) -> Bool {
        guard let scheme = url?.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}
