//
//  AuthzServiceWorker.swift
//  Cidaas
//
//  Created by Ganesh on 17/05/20.
//

import Foundation
import Alamofire

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

        // Required for authz generate.
        guard let cookieHeaders = SDKDeviceIdResolver.cidaasDrCookieHeaders() else {
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
            extraheaders: cookieHeaders,
            callback: callback
        )
    }

    /// `GET /authz-srv/authz` — all OAuth params as query; 302 `Location` returned as callback string.
    public func initLogin(
        extraParams: Dictionary<String, String>,
        properties: Dictionary<String, String>,
        callback: @escaping (String?, WebAuthError?) -> Void
    ) {
        var queryParams = Dictionary<String, String>()
        queryParams["nonce"] = UUID().uuidString
        queryParams["redirect_uri"] = properties["RedirectURL"]
        queryParams["client_id"] = properties["ClientId"]
        queryParams["client_secret"] = properties["ClientSecret"]
        queryParams["response_type"] = "code"
        queryParams["code_challenge"] = properties["Challenge"]
        queryParams["code_challenge_method"] = properties["Method"]
        for (key, value) in extraParams {
            queryParams[key] = value
        }

        let baseURL = (properties["DomainURL"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if baseURL.isEmpty {
            callback(nil, WebAuthError.shared.propertyMissingException())
            return
        }

        let urlString = baseURL + sharedURL.getAuthRequestURL()
        let cookieHeaders = SDKDeviceIdResolver.cidaasDrCookieHeaders() ?? [:]

        /// `GET /authz-srv/authz` — all OAuth params as query.
        /// Follows up to 2 redirects (`authz` → `login-srv/login/handle/tokenresp` → final webpage)
        /// and returns the last URL for ``InitLoginLocationParser``.
        sharedSession.startSession(
            url: urlString,
            method: .get,
            parameters: queryParams as [String: Any],
            encoding: URLEncoding.queryString,
            extraheaders: cookieHeaders,
            maxRedirects: 2,
            resolveAsFinalURL: true,
            callback: callback
        )
    }

    /// `GET /token-srv/prelogin/metadata/{trackId}` — JSON body returned as callback string.
    public func fetchPreloginMetadata(
        trackId: String,
        properties: Dictionary<String, String>,
        callback: @escaping (String?, WebAuthError?) -> Void
    ) {
        let trimmed = trackId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            callback(nil, WebAuthError.shared.serviceFailureException(
                errorCode: 417,
                errorMessage: "track_id cannot be empty",
                statusCode: 417
            ))
            return
        }

        let baseURL = (properties["DomainURL"] ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if baseURL.isEmpty {
            callback(nil, WebAuthError.shared.propertyMissingException())
            return
        }

        let urlString = baseURL + sharedURL.getPreloginMetadataURL(trackId: trimmed)
        let cookieHeaders = SDKDeviceIdResolver.cidaasDrCookieHeaders() ?? [:]

        sharedSession.startSession(
            url: urlString,
            method: .get,
            parameters: nil,
            encoding: URLEncoding.default,
            extraheaders: cookieHeaders,
            callback: callback
        )
    }
}
