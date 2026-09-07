//
//  CidaasSessionCookies.swift
//  Cidaas
//
//  Persists login-session cookies (`cidaas_sid`, `cidaas_sso`) in the Keychain
//  and merges them into outbound `Cookie` headers.
//

import Foundation
import Security

enum CidaasSessionCookies {

    private static let service = "com.cidaas.sdk.session-cookies"
    private static let sidKey = "cidaas_sid"
    private static let ssoKey = "cidaas_sso"

    private static let lock = NSLock()
    /// ponytail: hostless XCTest often gets Keychain -34018; memory keeps same-process reads working. Host apps use Keychain.
    private static var memoryFallback: [String: String] = [:]

    static var sid: String { read(account: sidKey) }

    static var sso: String { read(account: ssoKey) }

    /// Writes non-nil, non-empty values. Pass `nil` to leave that cookie unchanged.
    static func persist(sid: String?, sso: String?) {
        if let sid, !trimmed(sid).isEmpty {
            write(trimmed(sid), account: sidKey)
        }
        if let sso, !trimmed(sso).isEmpty {
            write(trimmed(sso), account: ssoKey)
        }
    }

    /// Reads `Set-Cookie` (and cookie jar for `url`) for `cidaas_sid` / `cidaas_sso`.
    static func persist(fromResponseHeaders headerFields: [AnyHashable: Any], url: URL? = nil) {
        var foundSid: String?
        var foundSso: String?
        for (key, value) in headerFields {
            guard let name = key as? String,
                  name.lowercased() == "set-cookie" else { continue }
            let raw = (value as? String) ?? String(describing: value)
            if let v = cookieValue(named: sidKey, in: raw) { foundSid = v }
            if let v = cookieValue(named: ssoKey, in: raw) { foundSso = v }
        }
        if let url, let jarCookies = HTTPCookieStorage.shared.cookies(for: url) {
            for cookie in jarCookies {
                if cookie.name == sidKey { foundSid = cookie.value }
                if cookie.name == ssoKey { foundSso = cookie.value }
            }
        }
        persist(sid: foundSid, sso: foundSso)
    }

    static func persist(from httpResponse: HTTPURLResponse?) {
        guard let httpResponse else { return }
        persist(fromResponseHeaders: httpResponse.allHeaderFields, url: httpResponse.url)
    }

    static func clear() {
        delete(account: sidKey)
        delete(account: ssoKey)
    }

    private static let drName = "cidaas_dr"

    /// Merges present session cookies into an existing `Cookie` header.
    /// Adds `cidaas_dr` when `deviceId` is non-empty (or keeps an existing `cidaas_dr`),
    /// and Keychain `cidaas_sid` / `cidaas_sso` when stored. Returns `nil` when nothing to send.
    static func mergeIntoCookieHeader(_ existing: String?, deviceId: String? = nil) -> String? {
        var otherSegments: [String] = []
        var existingDr: String?
        if let existing = existing?.trimmingCharacters(in: .whitespacesAndNewlines), !existing.isEmpty {
            for part in existing.split(separator: ";") {
                let trimmedPart = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmedPart.isEmpty else { continue }
                let pieces = trimmedPart.split(separator: "=", maxSplits: 1).map(String.init)
                let name = pieces.first?.lowercased() ?? ""
                if name == sidKey || name == ssoKey { continue }
                if name == drName {
                    existingDr = pieces.count > 1 ? pieces[1] : ""
                    continue
                }
                otherSegments.append(trimmedPart)
            }
        }

        let resolvedDr = {
            let fromParam = trimmed(deviceId)
            if !fromParam.isEmpty { return fromParam }
            return trimmed(existingDr)
        }()
        let storedSid = sid
        let storedSso = sso

        var segments = otherSegments
        if !resolvedDr.isEmpty { segments.insert("\(drName)=\(resolvedDr)", at: 0) }
        if !storedSid.isEmpty { segments.append("\(sidKey)=\(storedSid)") }
        if !storedSso.isEmpty { segments.append("\(ssoKey)=\(storedSso)") }
        guard !segments.isEmpty else { return nil }
        return segments.joined(separator: "; ")
    }

    // MARK: - Keychain (+ memory fallback)

    private static func write(_ value: String, account: String) {
        lock.lock()
        defer { lock.unlock() }
        deleteUnlocked(account: account)
        guard let data = value.data(using: .utf8) else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(query as CFDictionary, nil)
        if status == errSecSuccess {
            memoryFallback.removeValue(forKey: account)
        } else {
            memoryFallback[account] = value
        }
    }

    private static func read(account: String) -> String {
        lock.lock()
        defer { lock.unlock() }
        if let mem = memoryFallback[account] {
            return trimmed(mem)
        }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return ""
        }
        return trimmed(value)
    }

    private static func delete(account: String) {
        lock.lock()
        defer { lock.unlock() }
        deleteUnlocked(account: account)
    }

    private static func deleteUnlocked(account: String) {
        memoryFallback.removeValue(forKey: account)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(query as CFDictionary)
    }

    private static func cookieValue(named name: String, in setCookieHeader: String) -> String? {
        let marker = "\(name)="
        guard let range = setCookieHeader.range(of: marker, options: .caseInsensitive) else {
            return nil
        }
        let after = setCookieHeader[range.upperBound...]
        let end = after.firstIndex(where: { $0 == ";" || $0 == "," || $0 == "\n" || $0 == "\r" })
            ?? after.endIndex
        let value = String(after[..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private static func trimmed(_ value: String?) -> String {
        (value ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
