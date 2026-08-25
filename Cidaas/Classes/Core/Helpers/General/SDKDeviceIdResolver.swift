//
//  SDKDeviceIdResolver.swift
//  Cidaas
//

import Foundation
import SwiftKeychainWrapper
import UIKit

enum SDKDeviceIdResolver {

    private static let keychainKey = "cidaas_sdk_device_id"

    /// Stable device id (UserDefaults → Keychain → vendor id). Always lowercase.
    static func resolve(persistToDBHelper: Bool = true) -> String {
        var info = DBHelper.shared.getDeviceInfo()
        let stored = normalize(info.deviceId)
        if !stored.isEmpty {
            if info.deviceId != stored {
                info.deviceId = stored
                if persistToDBHelper {
                    DBHelper.shared.setDeviceInfo(deviceInfo: info)
                }
                _ = KeychainWrapper.standard.set(stored, forKey: keychainKey)
            }
            return stored
        }

        let keychainRaw = KeychainWrapper.standard.string(forKey: keychainKey) ?? ""
        let keychainId = normalize(keychainRaw)
        if !keychainId.isEmpty {
            // Only rewrite Keychain when normalization changed the stored value.
            if keychainId != keychainRaw {
                _ = KeychainWrapper.standard.set(keychainId, forKey: keychainKey)
            }
            if persistToDBHelper {
                info.deviceId = keychainId
                DBHelper.shared.setDeviceInfo(deviceInfo: info)
            }
            return keychainId
        }

        let generated = normalize(UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString)
        _ = KeychainWrapper.standard.set(generated, forKey: keychainKey)
        if persistToDBHelper {
            info.deviceId = generated
            DBHelper.shared.setDeviceInfo(deviceInfo: info)
        }
        return generated
    }

    /// Writes a lowercase device id to UserDefaults + Keychain.
    static func persist(_ deviceId: String) {
        let normalized = normalize(deviceId)
        guard !normalized.isEmpty else { return }
        var info = DBHelper.shared.getDeviceInfo()
        info.deviceId = normalized
        DBHelper.shared.setDeviceInfo(deviceInfo: info)
        _ = KeychainWrapper.standard.set(normalized, forKey: keychainKey)
    }

    /// `Cookie: cidaas_dr=<deviceId>` for authz / MFA calls. Nil if device id is missing.
    static func cidaasDrCookieHeaders() -> [String: String]? {
        let deviceId = resolve()
        guard !deviceId.isEmpty else { return nil }
        return ["Cookie": "cidaas_dr=\(deviceId)"]
    }

    private static func normalize(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
