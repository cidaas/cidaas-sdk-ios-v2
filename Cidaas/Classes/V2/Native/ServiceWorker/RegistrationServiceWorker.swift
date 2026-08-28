//
//  RegistrationServiceWorker.swift
//  Cidaas
//
//  Created by Ganesh on 17/05/20.
//

import Foundation

public class RegistrationServiceWorker {
    
    public static var shared: RegistrationServiceWorker = RegistrationServiceWorker()
    var sharedSession: SessionManager
    var sharedURL: RegistrationURLHelper
    
    public init() {
        sharedSession = SessionManager.shared
        sharedURL = RegistrationURLHelper.shared
    }
    
    // Get registration fields
    public func getRegistrationFields(acceptlanguage: String, requestId: String, properties : Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        
        // local variables
        var urlString : String
        var baseURL : String
        
        // assign base url
        baseURL = (properties["DomainURL"]) ?? ""
        
        if (baseURL == "") {
            callback(nil, WebAuthError.shared.propertyMissingException())
            return
        }
        
        // construct url
        urlString = baseURL + sharedURL.getRegistrationFieldsURL(acceptlanguage: acceptlanguage, requestId: requestId)
        
        sharedSession.startSession(url: urlString, method: .get, parameters: nil, callback: callback)
    }
    
    // Register user
    public func registerUser(requestId: String, incomingData : RegistrationEntity, properties : Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        
        // local variables
        var urlString : String
        var baseURL : String
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        // assign base url
        baseURL = (properties["DomainURL"]) ?? ""
        
        if (baseURL == "") {
            callback(nil, WebAuthError.shared.propertyMissingException())
            return
        }

        // Encrypt sensitive fields when client-side encryption is enabled.
        do {
            try ClientSideEncryption.encryptFieldsInBody(
                &bodyParams,
                fieldNames: ["password", "password_echo", "confirmPassword"],
                baseUrlOverride: baseURL
            )
        } catch {
            callback(nil, WebAuthError.shared.serviceFailureException(
                errorCode: 417,
                errorMessage: error.localizedDescription,
                statusCode: 417
            ))
            return
        }
        
        var headers: [String: String] = [String: String]()
        headers["requestId"] = requestId
        
        // construct url
        urlString = baseURL + sharedURL.getRegistrationURL()
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, extraheaders: headers, callback: callback)
    }
    
    // Update user
    public func updateUser(access_token: String, incomingData: RegistrationEntity, properties : Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        
        // local variables
        var urlString : String
        var baseURL : String
        
        // construct body params
        var bodyParams = Dictionary<String, Any>()
        
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, Any> ?? Dictionary<String, Any>()
            
            
        }
        catch(_) {
            callback(nil, WebAuthError.shared.conversionException())
            return
        }
        
        // assign base url
        baseURL = (properties["DomainURL"]) ?? ""
        
        if (baseURL == "") {
            callback(nil, WebAuthError.shared.propertyMissingException())
            return
        }
        
        var headers: [String: String] = [String: String]()
        headers["access_token"] = access_token
        
        // construct url
        urlString = baseURL + sharedURL.getUpdateUserURL(sub: incomingData.sub)
        
        sharedSession.startSession(url: urlString, method: .put, parameters: bodyParams,extraheaders: headers, callback: callback)
    }
}
