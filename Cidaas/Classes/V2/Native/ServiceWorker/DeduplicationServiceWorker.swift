//
//  DeduplicationServiceWorker.swift
//  Cidaas
//
//  Created by Ganesh on 17/05/20.
//

import Foundation

public class DeduplicationServiceWorker {
    
    public static var shared: DeduplicationServiceWorker = DeduplicationServiceWorker()
    var sharedSession: SessionManager
    var sharedURL: DeduplicationURLHelper
    
    public init() {
        sharedSession = SessionManager.shared
        sharedURL = DeduplicationURLHelper.shared
    }
    
    // Get Deduplication Details
    public func getDeduplicationDetails(track_id: String, properties : Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        
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
        urlString = baseURL + sharedURL.getDeduplicationDetailsURL(track_id: track_id)
        
        sharedSession.startSession(url: urlString, method: .get, parameters: nil, callback: callback)
    }
    
    // Get Register Deduplication
    public func registerDeduplication(track_id: String, properties : Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        
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
        urlString = baseURL + sharedURL.getRegisterDeduplicationURL(track_id: track_id)
        
        sharedSession.startSession(url: urlString, method: .post, parameters: nil, callback: callback)
    }
    
    // Deduplication Login
    public func deduplicationLogin(incomingData : LoginEntity, properties : Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        
        // local variables
        var urlString : String
        var baseURL : String
        
        // construct body params
        var bodyParams = Dictionary<String, String>()
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(incomingData)
            bodyParams = try! JSONSerialization.jsonObject(with: data, options: []) as? Dictionary<String, String> ?? Dictionary<String, String>()
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
                fieldNames: ["password"],
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
        
        // construct url
        urlString = baseURL + sharedURL.getLoginDeduplicationURL()
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, callback: callback)
    }
}
