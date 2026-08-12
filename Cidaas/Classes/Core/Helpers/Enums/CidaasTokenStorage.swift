//
//  CidaasTokenStorage.swift
//  Cidaas
//

import Foundation

/// Where the SDK persists encrypted access / refresh tokens.
public enum CidaasTokenStorage: String {
    /// Default. Encrypted token JSON is stored in `UserDefaults`.
    case userDefaults
    /// Encrypted token JSON is stored in the iOS Keychain.
    case keychain
}
