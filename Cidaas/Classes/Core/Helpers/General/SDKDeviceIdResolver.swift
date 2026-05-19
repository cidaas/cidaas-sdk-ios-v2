//
//  SDKDeviceIdResolver.swift
//  Cidaas
//

import Foundation
import SwiftKeychainWrapper
import UIKit

enum SDKDeviceIdResolver {

    private static let keychainKey = "cidaas_sdk_device_id"

    /// Stable SDK device id: `DBHelper` first, then Keychain, then `identifierForVendor` (UUID fallback).
    static func resolve(persistToDBHelper: Bool = true) -> String {
        var info = DBHelper.shared.getDeviceInfo()
        let stored = info.deviceId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !stored.isEmpty {
            return stored
        }

        if let keychainId = KeychainWrapper.standard.string(forKey: keychainKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
           !keychainId.isEmpty {
            if persistToDBHelper {
                info.deviceId = keychainId
                DBHelper.shared.setDeviceInfo(deviceInfo: info)
            }
            return keychainId
        }

        let generated = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        _ = KeychainWrapper.standard.set(generated, forKey: keychainKey)
        if persistToDBHelper {
            info.deviceId = generated
            DBHelper.shared.setDeviceInfo(deviceInfo: info)
        }
        return generated
    }
}
