//
//  Privacy.swift
//  Cidaas
//

import Foundation

/// Process-wide privacy and security toggles for the SDK.
public enum Privacy {
    private static let lock = NSLock()
    private static var encryptionEnabled = false

    /// When `true`, sensitive request fields (for example `password` and selected `pass_code` values)
    /// are JWE-encrypted before they are sent on the wire.
    /// Default is `false` for backward compatibility.
    public static func setEncryptionEnabled(_ enabled: Bool) {
        lock.lock()
        encryptionEnabled = enabled
        lock.unlock()
    }

    public static func isEncryptionEnabled() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return encryptionEnabled
    }
}
