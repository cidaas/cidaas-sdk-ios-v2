//
//  DBHelper.swift
//  sdkiOS
//
//  Created by ganesh on 25/07/18.
//  Copyright © 2018 Cidaas. All rights reserved.
//

import Foundation
import SwiftKeychainWrapper

public class DBHelper : NSObject {
    
    // shared instance
    public static var shared : DBHelper = DBHelper()
    
    // local variables
    public var userDefaults = UserDefaults.standard

    static let propertyFileKey = "OAuthProperty"
    static let tokenPrefix = "cidaas_user_details_"
    static let migrationVersionKey = "OAuthStorageMigrationVersion"
    static let currentMigrationVersion = 1
    static let dpopBoundLegacyKey = "com.cidaas.sdk.dpop.bound"
    static let dpopEnableKey = "OAuthEnableDpop"
    static let deviceRegKey = "OAuthDeviceRegistrationCompleted"
    static let totpBaseKey = "OAuthTOTPSecret"
    /// Never log these OAuthProperty values even when ENABLE_LOG is on.
    private static let sensitivePropertyKeys: Set<String> = [
        "Verifier", "Challenge", "ClientSecret",
        "access_token", "refresh_token", "id_token"
    ]
    
    func normalizeTenant(_ domainURL: String) -> String {
        var value = domainURL.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while value.hasSuffix("/") {
            value.removeLast()
        }
        return value
    }

    func storageSafeSegment(_ value: String) -> String {
        value
            .replacingOccurrences(of: "://", with: "_")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
    }

    func instanceSuffix(tenant: String, clientId: String) -> String {
        "\(storageSafeSegment(normalizeTenant(tenant)))_\(clientId.trimmingCharacters(in: .whitespacesAndNewlines))"
    }

    func activeTenantAndClient() -> (tenant: String, clientId: String)? {
        guard let props = getPropertyFile() else { return nil }
        let clientId = (props["ClientId"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let tenant = normalizeTenant(props["DomainURL"] ?? "")
        guard !clientId.isEmpty, !tenant.isEmpty else { return nil }
        return (tenant, clientId)
    }

    func namespacedAccessTokenKey(sub: String, tenant: String, clientId: String) -> String {
        return "\(Self.tokenPrefix)\(instanceSuffix(tenant: tenant, clientId: clientId))_\(sub)"
    }

    func legacyAccessTokenKey(sub: String) -> String {
        return "\(Self.tokenPrefix)\(sub)"
    }

    func propertyRegistryKey(tenant: String, clientId: String) -> String {
        return "\(Self.propertyFileKey)_\(instanceSuffix(tenant: tenant, clientId: clientId))"
    }

    private func instanceFlagKey(_ base: String, tenant: String, clientId: String) -> String {
        return "\(base)_\(instanceSuffix(tenant: tenant, clientId: clientId))"
    }
    
    // token storage preference (default: UserDefaults)
    public func setTokenStorage(_ storage: CidaasTokenStorage, key: String = "OAuthTokenStorage") {
        userDefaults.set(storage.rawValue, forKey: key)
        userDefaults.synchronize()
    }
    
    public func getTokenStorage(key: String = "OAuthTokenStorage") -> CidaasTokenStorage {
        guard let raw = userDefaults.string(forKey: key),
              let storage = CidaasTokenStorage(rawValue: raw) else {
            return .userDefaults
        }
        return storage
    }
    
    // set enable log
    public func setEnableLog(enableLog : Bool, key : String = "OAuthEnableLog") {
        userDefaults.set(enableLog, forKey: key)
        userDefaults.synchronize()
    }
    
    // get enable log
    public func getEnableLog(key : String = "OAuthEnableLog") -> Bool {
        return ((userDefaults.object(forKey: key) ?? false) as? Bool) ?? false
    }

    /// Summarizes OAuth props, token key names, and flags when `ENABLE_LOG` is on.
    /// Sensitive values (tokens, PKCE verifier/challenge, FCM) are redacted.
    public func logPersistedState(reason: String = "dump") {
        guard getEnableLog() else { return }

        logw("——— Cidaas UserDefaults dump (\(reason)) ———", cname: "cidaas-sdk-info-log")

        if let props = getPropertyFile() {
            logw(
                "OAuthProperty (\(props.count) keys):\n\(redactedPropertyLines(props))",
                cname: "cidaas-sdk-info-log"
            )
        } else {
            logw("OAuthProperty: <nil>", cname: "cidaas-sdk-info-log")
        }

        let registryKeys = userDefaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix("\(Self.propertyFileKey)_") }
            .sorted()
        if registryKeys.isEmpty {
            logw("OAuthProperty registry: <none>", cname: "cidaas-sdk-info-log")
        } else {
            for registryKey in registryKeys {
                logw("OAuthProperty registry key=\(registryKey)", cname: "cidaas-sdk-info-log")
            }
        }

        let device = getDeviceInfo()
        logw(
            "OAuthDeviceInfo: deviceId=\(redactedSecret(device.deviceId)), make=\(device.deviceMake), model=\(device.deviceModel), version=\(device.deviceVersion), pushId=\(redactedSecret(device.pushNotificationId))",
            cname: "cidaas-sdk-info-log"
        )
        logw(
            "Flags: tokenStorage=\(getTokenStorage().rawValue), pkce=\(getEnablePkce()), dpop=\(getEnableDpop()), deviceRegCompleted=\(getDeviceRegistrationCompleted()), fcm=\(redactedSecret(getFCM())), migrationVersion=\(userDefaults.integer(forKey: Self.migrationVersionKey))",
            cname: "cidaas-sdk-info-log"
        )

        let tokenKeys = userDefaults.dictionaryRepresentation().keys
            .filter { $0.hasPrefix(Self.tokenPrefix) }
            .sorted()
        if tokenKeys.isEmpty {
            logw("Access tokens (UserDefaults): <none>", cname: "cidaas-sdk-info-log")
        } else {
            for storageKey in tokenKeys {
                let length = ((userDefaults.object(forKey: storageKey) as? String) ?? "").count
                logw(
                    "Access token UserDefaults key=\(storageKey) present=\(length > 0) len=\(length)",
                    cname: "cidaas-sdk-info-log"
                )
            }
        }

        logw("——— end UserDefaults dump ———", cname: "cidaas-sdk-info-log")
    }

    private func redactedPropertyLines(_ props: [String: String]) -> String {
        props.keys.sorted().map { key in
            let value = props[key] ?? ""
            if Self.sensitivePropertyKeys.contains(key) {
                return "  \(key)=\(redactedSecret(value))"
            }
            return "  \(key)=\(value)"
        }.joined(separator: "\n")
    }

    private func redactedSecret(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "<empty>" }
        return "<redacted len=\(trimmed.count)>"
    }
    
    // set enable back button
    public func setEnableBackButton(enableBackButton : Bool, key : String = "OAuthEnableBackButton") {
        userDefaults.set(enableBackButton, forKey: key)
        userDefaults.synchronize()
    }
    
    // get enable back button
    public func getEnableBackButton(key : String = "OAuthEnableBackButton") -> Bool {
        return ((userDefaults.object(forKey: key) ?? false) as? Bool) ?? false
    }
    
    // set enable pkce
    public func setEnablePkce(enablePkce : Bool, key : String = "OAuthEnablePkce") {
        userDefaults.set(enablePkce, forKey: key)
        userDefaults.synchronize()
    }
    
    // get enable pkce
    public func getEnablePkce(key : String = "OAuthEnablePkce") -> Bool {
        return ((userDefaults.object(forKey: key) ?? false) as? Bool) ?? false
    }

    /// Persists ``Cidaas/ENABLE_DPOP``. SessionManager also sends `DPoP` when a bound session is persisted.
    public func setEnableDpop(enableDpop: Bool, key: String = "OAuthEnableDpop") {
        if key == Self.dpopEnableKey, let ctx = activeTenantAndClient() {
            userDefaults.set(enableDpop, forKey: instanceFlagKey(Self.dpopEnableKey, tenant: ctx.tenant, clientId: ctx.clientId))
        } else {
            userDefaults.set(enableDpop, forKey: key)
        }
        userDefaults.synchronize()
    }

    public func getEnableDpop(key: String = "OAuthEnableDpop") -> Bool {
        if key == Self.dpopEnableKey, let ctx = activeTenantAndClient() {
            let instanceKey = instanceFlagKey(Self.dpopEnableKey, tenant: ctx.tenant, clientId: ctx.clientId)
            if let value = userDefaults.object(forKey: instanceKey) as? Bool {
                return value
            }
        }
        return ((userDefaults.object(forKey: key) ?? false) as? Bool) ?? false
    }

    public func setDeviceRegistrationCompleted(_ completed: Bool, key: String = "OAuthDeviceRegistrationCompleted") {
        if key == Self.deviceRegKey, let ctx = activeTenantAndClient() {
            userDefaults.set(completed, forKey: instanceFlagKey(Self.deviceRegKey, tenant: ctx.tenant, clientId: ctx.clientId))
        } else {
            userDefaults.set(completed, forKey: key)
        }
        userDefaults.synchronize()
    }

    public func getDeviceRegistrationCompleted(key: String = "OAuthDeviceRegistrationCompleted") -> Bool {
        if key == Self.deviceRegKey, let ctx = activeTenantAndClient() {
            let instanceKey = instanceFlagKey(Self.deviceRegKey, tenant: ctx.tenant, clientId: ctx.clientId)
            if let value = userDefaults.object(forKey: instanceKey) as? Bool {
                return value
            }
        }
        return ((userDefaults.object(forKey: key) ?? false) as? Bool) ?? false
    }

    public func setDpopBound(_ bound: Bool) {
        if let ctx = activeTenantAndClient() {
            userDefaults.set(bound, forKey: instanceFlagKey(Self.dpopBoundLegacyKey, tenant: ctx.tenant, clientId: ctx.clientId))
        } else {
            userDefaults.set(bound, forKey: Self.dpopBoundLegacyKey)
        }
        userDefaults.synchronize()
    }

    public func getDpopBound() -> Bool {
        if let ctx = activeTenantAndClient() {
            let instanceKey = instanceFlagKey(Self.dpopBoundLegacyKey, tenant: ctx.tenant, clientId: ctx.clientId)
            if userDefaults.object(forKey: instanceKey) != nil {
                return userDefaults.bool(forKey: instanceKey)
            }
        }
        return userDefaults.bool(forKey: Self.dpopBoundLegacyKey)
    }

    public func clearDpopBound() {
        if let ctx = activeTenantAndClient() {
            userDefaults.removeObject(forKey: instanceFlagKey(Self.dpopBoundLegacyKey, tenant: ctx.tenant, clientId: ctx.clientId))
        }
        userDefaults.removeObject(forKey: Self.dpopBoundLegacyKey)
        userDefaults.synchronize()
    }
    
    // set FCM token
    public func setFCM(fcmToken : String, key : String = "OAuthFCM") {
        userDefaults.set(fcmToken, forKey: key)
        userDefaults.synchronize()
    }
    
    // get FCM token
    public func getFCM(key : String = "OAuthFCM") -> String {
        return ((userDefaults.object(forKey: key) ?? "") as? String) ?? ""
    }
    
    // set property file
    public func setPropertyFile(properties : Dictionary<String, String>?, key : String = "OAuthProperty") {
        let previous = userDefaults.object(forKey: key) as? Dictionary<String, String>
        let previousDomain = previous?["DomainURL"]
        let previousClient = previous?["ClientId"]
        let newDomain = properties?["DomainURL"]
        let newClient = properties?["ClientId"]
        if previousDomain != newDomain || previousClient != newClient {
            JwksClient.clearCache()
        }
        userDefaults.set(properties, forKey: key)
        userDefaults.synchronize()
        if let properties {
            if let tenant = properties["DomainURL"], let clientId = properties["ClientId"],
               !tenant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
               !clientId.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                userDefaults.set(properties, forKey: propertyRegistryKey(tenant: tenant, clientId: clientId))
                userDefaults.synchronize()
            }
            logw(
                "Saved OAuthProperty (\(properties.count) keys):\n\(redactedPropertyLines(properties))",
                cname: "cidaas-sdk-info-log"
            )
        } else {
            logw("Saved OAuthProperty: <nil>", cname: "cidaas-sdk-info-log")
        }
        migrateStorageIfNeeded()
        EntityToModelConverter.shared.migrateSaltKeyIfNeeded()
    }
    
    // get property file
    public func getPropertyFile(key : String = "OAuthProperty") -> Dictionary<String, String>? {
        guard let value = userDefaults.object(forKey: key) else {
            return nil
        }
        return value as? Dictionary<String, String> ?? nil
    }
    
    // set device info
    public func setDeviceInfo(deviceInfo : DeviceInfoModel, key : String = "OAuthDeviceInfo") {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(deviceInfo)
            let device_string = String(data: data, encoding: .utf8)
            userDefaults.set(device_string, forKey: key)
            userDefaults.synchronize()
            logw(
                "Saved OAuthDeviceInfo: deviceId=\(redactedSecret(deviceInfo.deviceId)), make=\(deviceInfo.deviceMake), model=\(deviceInfo.deviceModel)",
                cname: "cidaas-sdk-info-log"
            )
        }
        catch {
            userDefaults.synchronize()
            logw("setDeviceInfo failed: \(error.localizedDescription)", cname: "cidaas-sdk-error-log")
        }
    }
    
    // get device info
    public func getDeviceInfo(key : String = "OAuthDeviceInfo") -> DeviceInfoModel {
        guard let value = userDefaults.object(forKey: key) else {
            return DeviceInfoModel()
        }
        let device_string = value as? String ?? ""
        let decoder = JSONDecoder()
        do {
            let data = device_string.data(using: .utf8)!
            let deviceInfoEntity = try decoder.decode(DeviceInfoModel.self, from: data)
            return deviceInfoEntity
        }
        catch {
            return DeviceInfoModel()
        }
    }
    
    // set access token in the configured store (UserDefaults or Keychain)
    public func setAccessToken(accessTokenModel : AccessTokenModel) {
        let userId = accessTokenModel.sub.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userId.isEmpty else {
            logw("setAccessToken skipped: sub is empty", cname: "cidaas-sdk-error-log")
            return
        }
        guard let ctx = activeTenantAndClient() else {
            logw("setAccessToken skipped: active ClientId or DomainURL is missing", cname: "cidaas-sdk-error-log")
            return
        }
        
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(accessTokenModel)
            guard let access_token_string = String(data : data, encoding : .utf8) else {
                logw("setAccessToken failed: could not encode token JSON", cname: "cidaas-sdk-error-log")
                return
            }
            let storageKey = namespacedAccessTokenKey(sub: userId, tenant: ctx.tenant, clientId: ctx.clientId)
            writeAccessTokenString(access_token_string, storageKey: storageKey)
            logw(
                "Saved access token for sub \(userId) client \(ctx.clientId) in \(getTokenStorage().rawValue) key=\(storageKey) len=\(access_token_string.count)",
                cname: "cidaas-sdk-info-log"
            )
        }
        catch {
            logw("setAccessToken failed: \(error.localizedDescription)", cname: "cidaas-sdk-error-log")
        }
    }
    
    // get access token from the configured store, then the other store
    public func getAccessToken(key : String) -> AccessTokenModel {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return AccessTokenModel()
        }
        if let ctx = activeTenantAndClient() {
            let namespaced = namespacedAccessTokenKey(sub: trimmed, tenant: ctx.tenant, clientId: ctx.clientId)
            if let model = readAccessToken(storageKey: namespaced), !model.sub.isEmpty {
                return model
            }
        }
        return readAccessToken(storageKey: legacyAccessTokenKey(sub: trimmed)) ?? AccessTokenModel()
    }
    
    // remove access token from both stores (logout)
    public func removeAccessToken(sub: String) {
        let trimmed = sub.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        if let ctx = activeTenantAndClient() {
            removeAccessToken(storageKey: namespacedAccessTokenKey(sub: trimmed, tenant: ctx.tenant, clientId: ctx.clientId))
        }
        removeAccessToken(storageKey: legacyAccessTokenKey(sub: trimmed))
    }

    func migrateStorageIfNeeded() {
        let version = userDefaults.integer(forKey: Self.migrationVersionKey)
        guard version < Self.currentMigrationVersion else { return }
        guard let ctx = activeTenantAndClient() else { return }

        let allKeys = userDefaults.dictionaryRepresentation().keys
        for key in allKeys where isLegacyAccessTokenKey(key) {
            let sub = String(key.dropFirst(Self.tokenPrefix.count))
            let newKey = namespacedAccessTokenKey(sub: sub, tenant: ctx.tenant, clientId: ctx.clientId)
            copyAccessTokenIfNeeded(from: key, to: newKey)
        }

        copyBoolIfNeeded(from: Self.dpopEnableKey, to: instanceFlagKey(Self.dpopEnableKey, tenant: ctx.tenant, clientId: ctx.clientId))
        copyBoolIfNeeded(from: Self.dpopBoundLegacyKey, to: instanceFlagKey(Self.dpopBoundLegacyKey, tenant: ctx.tenant, clientId: ctx.clientId))
        copyBoolIfNeeded(from: Self.deviceRegKey, to: instanceFlagKey(Self.deviceRegKey, tenant: ctx.tenant, clientId: ctx.clientId))
        let legacyTotp = Self.totpBaseKey + "-totp"
        let instanceTotp = instanceFlagKey(Self.totpBaseKey, tenant: ctx.tenant, clientId: ctx.clientId) + "-totp"
        copyStringIfNeeded(from: legacyTotp, to: instanceTotp)

        userDefaults.set(Self.currentMigrationVersion, forKey: Self.migrationVersionKey)
        userDefaults.synchronize()
        logw(
            "Migrated OAuth storage to v\(Self.currentMigrationVersion) for tenant \(ctx.tenant) client \(ctx.clientId)",
            cname: "cidaas-sdk-info-log"
        )
    }
    
    private func writeAccessTokenString(_ access_token_string: String, storageKey: String) {
        let storage = getTokenStorage()
        switch storage {
        case .keychain:
            let saved = KeychainWrapper.standard.set(access_token_string, forKey: storageKey)
            guard saved else {
                logw("setAccessToken failed: Keychain write failed for key \(storageKey)", cname: "cidaas-sdk-error-log")
                return
            }
            userDefaults.removeObject(forKey: storageKey)
            userDefaults.synchronize()
        case .userDefaults:
            userDefaults.set(access_token_string, forKey: storageKey)
            userDefaults.synchronize()
            _ = KeychainWrapper.standard.removeObject(forKey: storageKey)
        }
    }

    private func readAccessToken(storageKey: String) -> AccessTokenModel? {
        let preferred = getTokenStorage()
        if let value = readAccessTokenString(for: storageKey, from: preferred) {
            let model = decodeAccessToken(value)
            return model.sub.isEmpty ? nil : model
        }
        let fallback: CidaasTokenStorage = (preferred == .keychain) ? .userDefaults : .keychain
        if let value = readAccessTokenString(for: storageKey, from: fallback) {
            let model = decodeAccessToken(value)
            return model.sub.isEmpty ? nil : model
        }
        return nil
    }

    private func removeAccessToken(storageKey: String) {
        userDefaults.removeObject(forKey: storageKey)
        userDefaults.synchronize()
        _ = KeychainWrapper.standard.removeObject(forKey: storageKey)
    }

    func isLegacyAccessTokenKey(_ key: String) -> Bool {
        guard key.hasPrefix(Self.tokenPrefix) else { return false }
        let rest = String(key.dropFirst(Self.tokenPrefix.count))
        if rest.hasPrefix("https_") || rest.hasPrefix("http_") {
            return false
        }
        return !rest.isEmpty
    }

    private func copyAccessTokenIfNeeded(from oldKey: String, to newKey: String) {
        if readAccessToken(storageKey: newKey) != nil {
            return
        }
        if let value = readAccessTokenString(for: oldKey, from: .userDefaults)
            ?? readAccessTokenString(for: oldKey, from: .keychain) {
            writeAccessTokenString(value, storageKey: newKey)
        }
    }

    private func copyBoolIfNeeded(from oldKey: String, to newKey: String) {
        guard userDefaults.object(forKey: newKey) == nil else { return }
        guard userDefaults.object(forKey: oldKey) != nil else { return }
        userDefaults.set(userDefaults.bool(forKey: oldKey), forKey: newKey)
    }

    private func copyStringIfNeeded(from oldKey: String, to newKey: String) {
        guard userDefaults.object(forKey: newKey) == nil else { return }
        guard let value = userDefaults.string(forKey: oldKey), !value.isEmpty else { return }
        userDefaults.set(value, forKey: newKey)
    }
    
    private func readAccessTokenString(for storageKey: String, from storage: CidaasTokenStorage) -> String? {
        switch storage {
        case .keychain:
            let value = KeychainWrapper.standard.string(forKey: storageKey)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return value.isEmpty ? nil : value
        case .userDefaults:
            guard let raw = userDefaults.object(forKey: storageKey) as? String else {
                return nil
            }
            let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return value.isEmpty ? nil : value
        }
    }
    
    private func decodeAccessToken(_ access_token_string: String) -> AccessTokenModel {
        let decoder = JSONDecoder()
        do {
            guard let data = access_token_string.data(using: .utf8) else {
                return AccessTokenModel()
            }
            return try decoder.decode(AccessTokenModel.self, from: data)
        }
        catch {
            return AccessTokenModel()
        }
    }
    
    // set user deviceId
    public func setUserDeviceId(userDeviceId : String, key : String = "OAuthUserDeviceId") {
        userDefaults.set(userDeviceId, forKey: key + "-user-device-id")
        userDefaults.synchronize()
    }
    
    // get user deviceId
    public func getUserDeviceId(key : String = "OAuthUserDeviceId") -> String {
        guard let value = userDefaults.object(forKey: key + "-user-device-id") else {
            return ""
        }
        return value as? String ?? ""
    }
    
    // set TOTP secret qrcode
    public func setTOTPSecret(secret : String, name: String, issuer: String, key : String = "OAuthTOTPSecret") {
        userDefaults.set("otpauth://totp?secret=\(secret)&name=\(name)&issuer=\(issuer)", forKey: totpStorageKey(base: key))
        userDefaults.synchronize()
    }
    
    // get TOTP secret qrcode
    public func getTOTPSecret(key : String = "OAuthTOTPSecret") -> String {
        let namespaced = totpStorageKey(base: key)
        if let value = userDefaults.object(forKey: namespaced) as? String, !value.isEmpty {
            return value
        }
        let legacy = key + "-totp"
        guard let value = userDefaults.object(forKey: legacy) else {
            return ""
        }
        return value as? String ?? ""
    }

    private func totpStorageKey(base: String) -> String {
        if base == Self.totpBaseKey, let ctx = activeTenantAndClient() {
            return instanceFlagKey(Self.totpBaseKey, tenant: ctx.tenant, clientId: ctx.clientId) + "-totp"
        }
        return base + "-totp"
    }
    
    // set location
    public func setLocation(lat: String, lon: String, key: String = "OAuthLocation") {
        userDefaults.set(lat + "-" + lon, forKey: key)
        userDefaults.synchronize()
    }
    
    // get location
    public func getLocation(key: String = "OAuthLocation") -> (String, String) {
        guard let value = userDefaults.object(forKey: key) else {
            return ("", "")
        }
        // split by hyphen
        let splittedLocation: [Substring] = (value as? String ?? "").split(separator: "-")
        if splittedLocation.count  > 1 {
            return (String(splittedLocation[0]), String(splittedLocation[1]))
        }
        return ("", "")
    }
}
