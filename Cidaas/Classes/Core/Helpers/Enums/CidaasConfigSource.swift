//
//  CidaasConfigSource.swift
//  Cidaas
//

import Foundation

/// How the active `OAuthProperty` slot was last configured.
public enum CidaasConfigSource: String {
    /// Loaded from `Cidaas.plist` via `readPropertyFile()`.
    case plist
    /// Set programmatically via `setURL`.
    case setURL
}
