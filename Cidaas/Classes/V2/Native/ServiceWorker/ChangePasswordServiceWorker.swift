//
//  ChangePasswordServiceWorker.swift
//  Cidaas
//
//  Created by Ganesh on 18/05/20.
//

import Foundation

public class ChangePasswordServiceWorker {
    
    public static var shared: ChangePasswordServiceWorker = ChangePasswordServiceWorker()
    var sharedSession: SessionManager
    var sharedURL: ChangePasswordURLHelper
    
    public init() {
        sharedSession = SessionManager.shared
        sharedURL = ChangePasswordURLHelper.shared
    }
    
    // Change password
    public func changePassword(access_token: String, incomingData : ChangePasswordEntity, properties : Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        
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
        
        var headers: [String: String] = [String: String]()
        headers["access_token"] = access_token
        
        // construct url
        urlString = baseURL + sharedURL.getChangePasswordURL()
        
        sharedSession.startSession(url: urlString, method: .put, parameters: bodyParams, extraheaders: headers, callback: callback)
    }
}
