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
    
    private func accessTokenKey(for userId: String) -> String {
        return "cidaas_user_details_\(userId)"
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
        userDefaults.set(properties, forKey: key)
        userDefaults.synchronize()
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
        }
        catch {
            userDefaults.synchronize()
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
        
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(accessTokenModel)
            guard let access_token_string = String(data : data, encoding : .utf8) else {
                logw("setAccessToken failed: could not encode token JSON", cname: "cidaas-sdk-error-log")
                return
            }
            let storageKey = accessTokenKey(for: userId)
            let storage = getTokenStorage()
            switch storage {
            case .keychain:
                let saved = KeychainWrapper.standard.set(access_token_string, forKey: storageKey)
                guard saved else {
                    logw("setAccessToken failed: Keychain write failed for sub \(userId)", cname: "cidaas-sdk-error-log")
                    return
                }
                // Only drop the other store after a confirmed write.
                userDefaults.removeObject(forKey: storageKey)
                userDefaults.synchronize()
            case .userDefaults:
                userDefaults.set(access_token_string, forKey: storageKey)
                userDefaults.synchronize()
                _ = KeychainWrapper.standard.removeObject(forKey: storageKey)
            }
            logw("Saved access token for sub \(userId) in \(storage.rawValue)", cname: "cidaas-sdk-info-log")
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
        let storageKey = accessTokenKey(for: trimmed)
        let preferred = getTokenStorage()
        if let value = readAccessTokenString(for: storageKey, from: preferred) {
            return decodeAccessToken(value)
        }
        let fallback: CidaasTokenStorage = (preferred == .keychain) ? .userDefaults : .keychain
        if let value = readAccessTokenString(for: storageKey, from: fallback) {
            return decodeAccessToken(value)
        }
        return AccessTokenModel()
    }
    
    // remove access token from both stores (logout)
    public func removeAccessToken(sub: String) {
        let trimmed = sub.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let storageKey = accessTokenKey(for: trimmed)
        userDefaults.removeObject(forKey: storageKey)
        userDefaults.synchronize()
        _ = KeychainWrapper.standard.removeObject(forKey: storageKey)
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
        userDefaults.set("otpauth://totp?secret=\(secret)&name=\(name)&issuer=\(issuer)", forKey: key + "-totp")
        userDefaults.synchronize()
    }
    
    // get TOTP secret qrcode
    public func getTOTPSecret(key : String = "OAuthTOTPSecret") -> String {
        guard let value = userDefaults.object(forKey: key + "-totp") else {
            return ""
        }
        return value as? String ?? ""
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
