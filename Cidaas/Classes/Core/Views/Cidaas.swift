//
//  Cidaas.swift
//  sdkiOS
//
//  Created by ganesh on 25/07/18.
//  Copyright © 2018 Cidaas. All rights reserved.
//

import Foundation
import SafariServices
import Security
import SwiftKeychainWrapper
import WebKit

public class Cidaas {
    
    // shared instance
    public static var shared : Cidaas = Cidaas()
    
    // private local variables
    var requestId : String = ""
    var loginURLString : String = ""
    var redirectURLString : String = ""
    var fcmToken : String = ""
    var enableLog : Bool = false
    var enablePkce : Bool = true
    var deviceInfo : DeviceInfoModel
    var storage: TransactionStore
    var timer = Timer()
    var browserCallback: ((Result<LoginResponseEntity>) -> ())!
    var browserLogoutCallback: ((Result<Bool>) -> ())!
    var propertyFileRead: Bool = false
    
    // static variables
    public static var intermediate_verifiation_id: String = ""
    
    // log flag
    public var ENABLE_LOG : Bool {
        get {
            enableLog = DBHelper.shared.getEnableLog()
            return enableLog
        }
        set (enableLog) {
            self.enableLog = enableLog
            // save local
            DBHelper.shared.setEnableLog(enableLog: enableLog)
        }
    }
    
    // pkce flag
    public var ENABLE_PKCE : Bool {
        get {
            self.enablePkce = DBHelper.shared.getEnablePkce()
            return self.enablePkce
        }
        set (enablePkce) {
            self.enablePkce = enablePkce
            // save local
            DBHelper.shared.setEnablePkce(enablePkce: enablePkce)
        }
    }

    // Pinning applies to SessionManager HTTP calls. Pass hashes from the app; host falls back to DomainURL.
    public func setPublicKeyPinning(
        trustedPublicKeyHashes: [String]? = nil,
        pinnedHosts: [String]? = nil,
        validateHost: Bool = true,
        performDefaultValidation: Bool = true
    ) {
        let hosts = Self.resolvePinnedHosts(explicit: pinnedHosts)
        let hashes = trustedPublicKeyHashes ?? CidaasPublicKeyPinningConfiguration.defaultTrustedHashes
        guard !hashes.isEmpty else {
            logw("setPublicKeyPinning: trustedPublicKeyHashes is empty", cname: "cidaas-sdk-error-log")
            return
        }
        guard !hosts.isEmpty else {
            logw("setPublicKeyPinning: pinnedHosts is empty", cname: "cidaas-sdk-error-log")
            return
        }
        let options = CidaasPublicKeyPinningOptions(
            trustedPublicKeyHashes: hashes,
            pinnedHosts: hosts,
            validateHost: validateHost,
            performDefaultValidation: performDefaultValidation
        )
        SessionManager.shared.setPublicKeyPinning(options)
        logw("Public key pinning enabled: \(hosts.joined(separator: ", "))", cname: "cidaas-sdk-info-log")
    }

    public func clearPublicKeyPinning() {
        SessionManager.shared.setPublicKeyPinning(nil)
        logw("Public key pinning disabled", cname: "cidaas-sdk-info-log")
    }

    private static func resolvePinnedHosts(explicit: [String]?) -> [String] {
        if let explicit {
            let trimmed = explicit
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
            if !trimmed.isEmpty { return trimmed }
        }
        if let domain = DBHelper.shared.getPropertyFile()?["DomainURL"],
           let host = CidaasPublicKeyPinningLoader.hostFromDomainURL(domain) {
            return [host.lowercased()]
        }
        return []
    }

    // constructor
    public init(storage : TransactionStore = TransactionStore.shared) {
        // set device info in local
        deviceInfo = DeviceInfoModel()
        deviceInfo.deviceId = SDKDeviceIdResolver.resolve(persistToDBHelper: false)
        logw("Device Id : " + deviceInfo.deviceId, cname: "cidaas-sdk-info-log")
        deviceInfo.deviceMake = "Apple"
        let deviceHelper = DeviceHelper()
        deviceInfo.deviceModel = String(describing: deviceHelper.hardware())
        deviceInfo.deviceVersion = UIDevice.current.systemVersion
        DBHelper.shared.setDeviceInfo(deviceInfo: deviceInfo)
        
        
        // set storage in local
        self.storage = storage
        
        // set enable pkce in local
        self.ENABLE_PKCE = true
        
        // set enable log in local
        self.ENABLE_LOG = false
        
        // read property from file
        self.readPropertyFile()
        
    }
    
    
    // read property file
    public func readPropertyFile() {
        FileHelper.shared.readProperties {
            switch $0 {
            case .failure(let error):
                // log error
                let loggerMessage = "Read properties file failure : " + "Error Code - " + String(describing: error.errorCode) + ", Error Message - " + error.errorMessage + ", Status Code - " + String(describing: error.statusCode)
                logw(loggerMessage, cname: "cidaas-sdk-error-log")
                
                return
            case .success(let properties):
                // log success
                let loggerMessage = "Read properties file success : " + "Properties Count - " + String(describing: properties.count)
                logw(loggerMessage, cname: "cidaas-sdk-success-log")
                
                
                self.saveProperties(properties: properties) {
                    switch $0 {
                    case .failure (let error):
                        // log error
                        let loggerMessage = "Saving properties failure : " + "Error Code - " + String(describing: error.errorCode) + ", Error Message - " + error.errorMessage + ", Status Code - " + String(describing: error.statusCode)
                        logw(loggerMessage, cname: "cidaas-sdk-error-log")
                        return
                    case .success(let response):
                        // log success
                        let loggerMessage = "Saved Property status : \(response)"
                        logw(loggerMessage, cname: "cidaas-sdk-success-log")
                        self.propertyFileRead = true
                        break
                    }
                }
            }
        }
    }
    
    
    // set url manually
    public func setURL(domainURL: String, clientId: String, redirectURL: String, userDeviceId: String = "") {
        FileHelper.shared.paramsToDictionaryConverter(domainURL: domainURL, clientId: clientId, redirectURL: redirectURL) {
            switch $0 {
            case .failure(let error):
                // log error
                let loggerMessage = "Read properties file failure : " + "Error Code - " + String(describing: error.errorCode) + ", Error Message - " + error.errorMessage + ", Status Code - " + String(describing: error.statusCode)
                logw(loggerMessage, cname: "cidaas-sdk-error-log")
                
                return
            case .success(let properties):
                // log success
                let loggerMessage = "Read properties file success : " + "Properties Count - " + String(describing: properties.count)
                logw(loggerMessage, cname: "cidaas-sdk-success-log")
                
                
                self.saveProperties(properties: properties) {
                    switch $0 {
                    case .failure (let error):
                        // log error
                        let loggerMessage = "Saving properties failure : " + "Error Code - " + String(describing: error.errorCode) + ", Error Message - " + error.errorMessage + ", Status Code - " + String(describing: error.statusCode)
                        logw(loggerMessage, cname: "cidaas-sdk-error-log")
                        return
                    case .success(let response):
                        // log success
                        let loggerMessage = "Saved Property status : \(response)"
                        logw(loggerMessage, cname: "cidaas-sdk-success-log")
                        
                        if userDeviceId != "" {
                            DBHelper.shared.setUserDeviceId(userDeviceId: userDeviceId, key: properties["DomainURL"] ?? "")
                        }
                        
                        break
                    }
                }
            }
        }
    }
    

    
    // login with browser
    public func loginWithBrowser(delegate: UIViewController, extraParams: Dictionary<String, String> = Dictionary<String, String>(), callback: @escaping (Result<LoginResponseEntity>) -> Void) {
        var savedProp = DBHelper.shared.getPropertyFile()
        if (savedProp != nil) {
            self.browserCallback = callback
            savedProp!["view_type"] = "login"
            LoginController.shared.loginWithBrowser(delegate: delegate, extraParams: extraParams, properties: savedProp!, callback: callback)
        }
        else {
            // log error
            let loggerMessage = "Read properties file failure : " + "Error Code -  10001, Error Message -  File not found, Status Code - 404"
            logw(loggerMessage, cname: "cidaas-sdk-error-log")
            
            let error = WebAuthError.shared.fileNotFoundException()
            
            // return failure callback
            DispatchQueue.main.async {
                callback(Result.failure(error: error))
            }
            return
        }
    }
    
    // login with browser
    public func logoutWithBrowser(delegate: UIViewController, sub: String, callback: @escaping (Result<Bool>) -> Void) {
        var savedProp = DBHelper.shared.getPropertyFile()
        if (savedProp != nil) {
            self.browserLogoutCallback = callback
            LogoutWithBrowserController.shared.logoutWithBrowser(delegate: delegate, sub: sub, properties: savedProp!, callback: callback)
            
        }
        else {
            // log error
            let loggerMessage = "Read properties file failure : " + "Error Code -  10001, Error Message -  File not found, Status Code - 404"
            logw(loggerMessage, cname: "cidaas-sdk-error-log")
            
            let error = WebAuthError.shared.fileNotFoundException()
            
            // return failure callback
            DispatchQueue.main.async {
                callback(Result.failure(error: error))
            }
            return
        }
    }
    
    // login with browser
    public func logoutWithBrowser(delegate: UIViewController, accessToken: String, callback: @escaping (Result<Bool>) -> Void) {
        var savedProp = DBHelper.shared.getPropertyFile()
        if (savedProp != nil) {
            self.browserLogoutCallback = callback
            LogoutWithBrowserController.shared.logoutWithBrowser(delegate: delegate, accessToken: accessToken, properties: savedProp!, callback: callback)
        }
        else {
            // log error
            let loggerMessage = "Read properties file failure : " + "Error Code -  10001, Error Message -  File not found, Status Code - 404"
            logw(loggerMessage, cname: "cidaas-sdk-error-log")
            
            let error = WebAuthError.shared.fileNotFoundException()
            
            // return failure callback
            DispatchQueue.main.async {
                callback(Result.failure(error: error))
            }
            return
        }
    }
    
    
    // register with browser
    public func registerWithBrowser(delegate: UIViewController, extraParams: Dictionary<String, String> = Dictionary<String, String>(), callback: @escaping (Result<LoginResponseEntity>) -> Void) {
        var savedProp = DBHelper.shared.getPropertyFile()
        if (savedProp != nil) {
            self.browserCallback = callback
            savedProp!["view_type"] = "register"
            LoginController.shared.loginWithBrowser(delegate: delegate, extraParams: extraParams, properties: savedProp!, callback: callback)
        }
        else {
            // log error
            let loggerMessage = "Read properties file failure : " + "Error Code -  10001, Error Message -  File not found, Status Code - 404"
            logw(loggerMessage, cname: "cidaas-sdk-error-log")
            
            let error = WebAuthError.shared.fileNotFoundException()
            
            // return failure callback
            DispatchQueue.main.async {
                callback(Result.failure(error: error))
            }
            return
        }
    }
    
   

    
    // login with social
    public func loginWithSocial(provider: String, requestId: String, delegate: UIViewController, extraParams: Dictionary<String, String> = Dictionary<String, String>(), callback: @escaping (Result<LoginResponseEntity>) -> Void) {
        let savedProp = DBHelper.shared.getPropertyFile()
        if (savedProp != nil) {
            self.browserCallback = callback
                LoginController.shared.loginWithSocial(provider: provider, requestId: requestId, delegate: delegate, properties: savedProp!, callback: callback)
        }
        else {
            // log error
            let loggerMessage = "Read properties file failure : " + "Error Code -  10001, Error Message -  File not found, Status Code - 404"
            logw(loggerMessage, cname: "cidaas-sdk-error-log")
            
            let error = WebAuthError.shared.fileNotFoundException()
            
            // return failure callback
            DispatchQueue.main.async {
                callback(Result.failure(error: error))
            }
            return
        }
    }
    

    
    // get login url
    public func getLoginURL(extraParams: Dictionary<String, String>, callback: @escaping (Result<URL>) -> Void) {
        var savedProp = DBHelper.shared.getPropertyFile()
        if (savedProp != nil) {
            savedProp?["ViewType"] = "login"
            callback(Result.success(result: LoginController.shared.constructURL(extraParams: extraParams, properties: savedProp!)))
        }
        else {
            // log error
            let loggerMessage = "Read properties file failure : " + "Error Code -  10001, Error Message -  File not found, Status Code - 404"
            logw(loggerMessage, cname: "cidaas-sdk-error-log")
            
            let error = WebAuthError.shared.fileNotFoundException()
            
            // return failure callback
            DispatchQueue.main.async {
                callback(Result.failure(error: error))
            }
            return
        }
    }
    
    
    // get register url
    public func getRegistrationURL(extraParams: Dictionary<String, String>, callback: @escaping (Result<URL>) -> Void) {
        var savedProp = DBHelper.shared.getPropertyFile()
        if (savedProp != nil) {
            savedProp?["ViewType"] = "register"
            callback(Result.success(result: LoginController.shared.constructURL(extraParams: extraParams, properties: savedProp!)))
        }
        else {
            // log error
            let loggerMessage = "Read properties file failure : " + "Error Code -  10001, Error Message -  File not found, Status Code - 404"
            logw(loggerMessage, cname: "cidaas-sdk-error-log")
            
            let error = WebAuthError.shared.fileNotFoundException()
            
            // return failure callback
            DispatchQueue.main.async {
                callback(Result.failure(error: error))
            }
            return
        }
    }
    
    
    // handle token
    public func handleToken(url: URL) {
        if LoginController.shared.delegate != nil {
            let delegate = LoginController.shared.delegate as! UIViewController
            delegate.dismiss(animated: true, completion: nil)
        }

        // Logout redirect has no authorization code — must run before the login callback branch.
        if browserLogoutCallback != nil {
            let logoutCallback = browserLogoutCallback
            browserLogoutCallback = nil
            DispatchQueue.main.async {
                logoutCallback?(Result.success(result: true))
            }
            return
        }

        if browserCallback != nil {
            let code = url.valueOf("code") ?? ""
            if code != "" {
                AccessTokenController.shared.getAccessToken(code: code, callback: browserCallback!)
            }
        }
    }
    
    // call biometrics
    // 1. call biometrics
    // 2. Maintain logs based on flags
    public func askDeviceAuthentication(localizedReason: String, invalidateAuthenticationContext: Bool = false, callback: @escaping (DeviceAuthenticationResponseEntity) -> Void) {
        let touch = TouchID()
        let response = DeviceAuthenticationResponseEntity()
        touch.checkIfPasscodeAvailable(invalidateAuthenticationContext: invalidateAuthenticationContext, callback: { (success_pass, message_pass, code_pass) in
            if success_pass == true {
                touch.checkTouchIDMatching(localizedReason: localizedReason, callback: { (success_inner, message_inner, code_inner) in
                    if success_inner == true {
                        response.success = true
                        response.status = 200
                        response.message = "Authentication success"
                    }
                    else {
                        // failure callback
                        response.success = success_inner
                        response.status = code_inner ?? 400
                        response.message = message_inner ?? "Authentication Failed"
                    }
                    DispatchQueue.main.async {
                        callback(response)
                        return
                    }
                })
            }
            else {
                // failure callback
                response.success = success_pass
                response.status = code_pass ?? 400
                response.message = message_pass ?? "Authentication Failed"
                DispatchQueue.main.async {
                    callback(response)
                    return
                }
            }
        })
    }
    
    
    // get user info from plist
    // 1. Read properties from file
    // 2. Call getUserInfo method
    // 3. Maintain logs based on flags
    
    public func getUserInfo(sub: String, callback: @escaping(Result<UserInfoEntity>) -> Void) {
        
        let savedProp = DBHelper.shared.getPropertyFile()
        if (savedProp != nil) {
            UsersController.shared.getUserInfo(sub: sub, properties: savedProp!, callback: callback)
        }
        else {
            // log error
            let loggerMessage = "Read properties file failure : " + "Error Code -  10001, Error Message -  File not found, Status Code - 404"
            logw(loggerMessage, cname: "cidaas-sdk-error-log")
            
            let error = WebAuthError.shared.fileNotFoundException()
            
            // return failure callback
            DispatchQueue.main.async {
                callback(Result.failure(error: error))
            }
            return
        }
    }
    
    public func getUserInfo(accessToken: String, callback: @escaping(Result<UserInfoEntity>) -> Void) {
        
        let savedProp = DBHelper.shared.getPropertyFile()
        if (savedProp != nil) {
            UsersController.shared.getUserInfo(accessToken: accessToken, properties: savedProp!, callback: callback)
        }
        else {
            // log error
            let loggerMessage = "Read properties file failure : " + "Error Code -  10001, Error Message -  File not found, Status Code - 404"
            logw(loggerMessage, cname: "cidaas-sdk-error-log")
            
            let error = WebAuthError.shared.fileNotFoundException()
            
            // return failure callback
            DispatchQueue.main.async {
                callback(Result.failure(error: error))
            }
            return
        }
    }
    
    
    // get access token from sub
    // 1. Call getAccessToken method
    
    public func getAccessToken(sub: String, callback: @escaping(Result<LoginResponseEntity>) -> Void) {
        AccessTokenController.shared.getAccessToken(sub: sub, callback: callback)
    }
    
    
    // set access token
    // 1. Call setAccessToken method
    
    public func setAccessToken(accessTokenEntity: AccessTokenEntity, callback: @escaping(Result<LoginResponseEntity>) -> Void) {
        
        // validate fields
        if accessTokenEntity.access_token == "" || accessTokenEntity.expires_in == 0 || accessTokenEntity.refresh_token == "" || accessTokenEntity.sub == "" {
            let error = WebAuthError.shared.propertyMissingException()
            error.errorMessage = "access_token or expires_in or refresh_token or sub must not be empty"
            callback(Result.failure(error: error))
        }
        
        // assign to access token model
        EntityToModelConverter.shared.accessTokenEntityToAccessTokenModel(accessTokenEntity: accessTokenEntity, callback: { _ in
            
            AccessTokenController.shared.saveAccessToken(accessTokenEntity: accessTokenEntity, callback: callback)
            
        })
    }

    
    // get access token from social token
    // 1. Call getAccessToken method
    
    public func getAccessToken(requestId: String, socialToken: String, provider: String, viewType: String, extraParams: Dictionary<String, String> = Dictionary<String, String>(), callback: @escaping(Result<LoginResponseEntity>) -> Void) {
            AccessTokenController.shared.getAccessToken(requestId: requestId, socialToken: socialToken, provider: provider, viewType: viewType, callback: callback)
    }
    
    // get access token from refresh token
    // 1. Call getAccessToken method
    
    public func getAccessToken(refreshToken: String, callback: @escaping(Result<LoginResponseEntity>) -> Void) {
        AccessTokenController.shared.getAccessToken(refreshToken: refreshToken, callback: callback)
    }

    
    // save properties
    func saveProperties(properties: Dictionary<String, String>, callback:@escaping (Result<Bool>) -> Void) {
        var savedProperties = properties
        
        if self.enablePkce == false {
            // client secret null check
            if properties["ClientSecret"] == "" || properties["ClientSecret"] == nil {
                let error = WebAuthError.shared.propertyMissingException()
                // log error
                let loggerMessage = "Read properties failure : " + "Error Code - " + String(describing: error.errorCode) + ", Error Message - " + error.errorMessage + ", Status Code - " + String(describing: error.statusCode)
                logw(loggerMessage, cname: "cidaas-sdk-error-log")
                
                DispatchQueue.main.async {
                    callback(Result.failure(error: error))
                }
                return
            }
            else {
                savedProperties["ClientSecret"] = properties["ClientSecret"]
            }
        }
            
        else {
            // create challenge and verifier
            let generator : OAuthChallengeGenerator = OAuthChallengeGenerator()
            savedProperties["Verifier"] = generator.verifier
            savedProperties["Challenge"] = generator.challenge()
            savedProperties["Method"] = generator.method
        }
        savedProperties["AuthorizationURL"] = (properties["DomainURL"]!) + "/authz-srv/authz"
        savedProperties["TokenURL"] = (properties["DomainURL"]!) + "/token-srv/token"
        savedProperties["GrantType"] = "authorization_code"
        savedProperties["ResponseType"] = "code"
        savedProperties["UserInfoURL"] = (properties["DomainURL"]!) + "/users-srv/userinfo"
        
        // construct url (will be removed. only for testing)
        self.loginURLString = (savedProperties["AuthorizationURL"]!) + "?response_type=" + (savedProperties["ResponseType"]!)
        self.loginURLString = self.loginURLString + "&client_id=" + (savedProperties["ClientId"]!)
        self.loginURLString = self.loginURLString + "&viewtype=login&redirect_uri=" + (savedProperties["RedirectURL"]!)
        self.loginURLString = self.loginURLString + "&code_challenge=" + (savedProperties["Challenge"]!)
        self.loginURLString = self.loginURLString + "&code_challenge_method=" + (savedProperties["Method"]!)
        self.redirectURLString = (savedProperties["RedirectURL"]!)
        
        // save local
        DBHelper.shared.setPropertyFile(properties: savedProperties)
        
        DispatchQueue.main.async {
            callback(Result.success(result: true))
        }
    }
    
}

extension Notification.Name {
    static let totp = Notification.Name("TOTP")
}
