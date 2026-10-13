//
//  EntityToModelConverter.swift
//  sdkiOS
//
//  Created by ganesh on 25/07/18.
//  Copyright © 2018 Cidaas. All rights reserved.
//

import Foundation

public class EntityToModelConverter {
    
    // shared instance
    public static var shared : EntityToModelConverter = EntityToModelConverter()
    public var userDefaults = UserDefaults.standard

    static let legacySaltKeyAccount = "salt,key"
    
    /// Per tenant+client Keychain account.
    func saltKeychainAccount() -> String {
        guard let ctx = DBHelper.shared.activeTenantAndClient() else {
            return Self.legacySaltKeyAccount
        }
        return "\(Self.legacySaltKeyAccount)_\(DBHelper.shared.instanceSuffix(tenant: ctx.tenant, clientId: ctx.clientId))"
    }

    func migrateSaltKeyIfNeeded() {
        guard let ctx = DBHelper.shared.activeTenantAndClient() else { return }
        let namespaced = "\(Self.legacySaltKeyAccount)_\(DBHelper.shared.instanceSuffix(tenant: ctx.tenant, clientId: ctx.clientId))"
        if readSaltKeyData(account: namespaced) != nil { return }
        guard let legacy = readSaltKeyData(account: Self.legacySaltKeyAccount) else { return }
        writeSaltKeyData(legacy, account: namespaced)
    }
    
    // access token entity to model
    public func accessTokenEntityToAccessTokenModel(accessTokenEntity : AccessTokenEntity, callback: @escaping (AccessTokenModel)-> Void) {
        let salt = randomString(length: 16)
        let key = randomString(length: 16)
        let encData = (salt + "," + key).data(using: .utf8)!
        writeSaltKeyData(encData, account: saltKeychainAccount())

        AccessTokenModel.shared.expires_in = accessTokenEntity.expires_in
        AccessTokenModel.shared.id_token = accessTokenEntity.id_token
        AccessTokenModel.shared.sub = accessTokenEntity.sub
        do {
            AccessTokenModel.shared.refresh_token = try accessTokenEntity.refresh_token.aesEncrypt(key: key, iv: salt)
            AccessTokenModel.shared.access_token = try accessTokenEntity.access_token.aesEncrypt(key: key, iv: salt)
        } catch {
            logw(
                "accessTokenEntityToAccessTokenModel encrypt failed: \(error.localizedDescription)",
                cname: "cidaas-sdk-error-log"
            )
            AccessTokenModel.shared.refresh_token = ""
            AccessTokenModel.shared.access_token = ""
        }
        callback(AccessTokenModel.shared)
    }
    
    // access token model to entity
    public func accessTokenModelToAccessTokenEntity(accessTokenModel : AccessTokenModel = AccessTokenModel.shared, callback: @escaping (AccessTokenEntity)-> Void) {
        let accessTokenEntity = AccessTokenEntity()
        let pair = readSaltAndKey()
        let salt = pair.salt
        let key = pair.key
        
        accessTokenEntity.expires_in = accessTokenModel.expires_in
        accessTokenEntity.id_token = accessTokenModel.id_token
        do {
            accessTokenEntity.refresh_token = try accessTokenModel.refresh_token.aesDecrypt(key: key, iv: salt)
        } catch {
            accessTokenEntity.refresh_token = accessTokenModel.refresh_token
        }
        
        accessTokenEntity.sub = accessTokenModel.sub
        
        do {
            accessTokenEntity.access_token = try accessTokenModel.access_token.aesDecrypt(key: key, iv: salt)
        } catch {
            accessTokenEntity.access_token = accessTokenModel.access_token
        }
        
        callback(accessTokenEntity)
    }

    private func readSaltAndKey() -> (salt: String, key: String) {
        var accounts = [saltKeychainAccount()]
        if accounts[0] != Self.legacySaltKeyAccount {
            accounts.append(Self.legacySaltKeyAccount)
        }
        for account in accounts {
            guard let data = readSaltKeyData(account: account),
                  let decoded = String(data: data, encoding: .utf8)
            else { continue }
            let parts = decoded.components(separatedBy: ",")
            guard parts.count > 1 else { continue }
            return (parts[0], parts[1])
        }
        return ("", "")
    }

    private func readSaltKeyData(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecMatchLimit as String: kSecMatchLimitOne,
            kSecReturnAttributes as String: true,
            kSecReturnData as String: true,
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == noErr,
              let existingItem = item as? [String: Any],
              let saltKey = existingItem[kSecValueData as String] as? Data
        else { return nil }
        return saltKey
    }

    private func writeSaltKeyData(_ encData: Data, account: String) {
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecValueData as String: encData,
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    public func randomString(length: Int) -> String {
        let letters : NSString = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        let len = UInt32(letters.length)
        var randomString = ""
        for _ in 0 ..< length {
            let rand = arc4random_uniform(len)
            var nextChar = letters.character(at: Int(rand))
            randomString += NSString(characters: &nextChar, length: 1) as String
        }
        return randomString
    }
}
