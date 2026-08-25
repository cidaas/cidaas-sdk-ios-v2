//
//  AuthzServiceWorker.swift
//  Cidaas
//
//  Created by Ganesh on 17/05/20.
//

import Foundation

public class AuthzServiceWorker {
    
    public static var shared: AuthzServiceWorker = AuthzServiceWorker()
    var sharedSession: SessionManager
    var sharedURL: AuthzURLHelper
    
    public init() {
        sharedSession = SessionManager.shared
        sharedURL = AuthzURLHelper.shared
    }
    
    // getting requestId
    public func getRequestId(
        extraParams: Dictionary<String, String>,
        properties : Dictionary<String, String>,
        callback: @escaping (String?, WebAuthError?) -> Void
    ) {
        
        // local variables
        var urlString : String
        var baseURL : String
        
        // construct body params
        var bodyParams = Dictionary<String, String>()
        bodyParams["nonce"] = UUID().uuidString
        bodyParams["redirect_uri"] = properties["RedirectURL"]
        bodyParams["client_id"] = properties["ClientId"]
        bodyParams["client_secret"] = properties["ClientSecret"]
        bodyParams["response_type"] = "code"
        bodyParams["code_challenge"] = properties["Challenge"]
        bodyParams["code_challenge_method"] = properties["Method"]
        
        for(key, value) in extraParams {
            bodyParams[key] = value
        }

        // assign base url
        baseURL = (properties["DomainURL"]) ?? ""
        
        if (baseURL == "") {
            callback(nil, WebAuthError.shared.propertyMissingException())
            return
        }
        
        // construct url
        urlString = baseURL + sharedURL.getAuthzURL()

        let deviceId = SDKDeviceIdResolver.resolve()
        guard !deviceId.isEmpty else {
            callback(nil, WebAuthError.shared.serviceFailureException(
                errorCode: 417,
                errorMessage: "deviceId missing for cidaas_dr Cookie",
                statusCode: 417
            ))
            return
        }

        sharedSession.startSession(
            url: urlString,
            method: .post,
            parameters: bodyParams,
            extraheaders: ["Cookie": "cidaas_dr=\(deviceId)"],
            callback: callback
        )
    }
}
