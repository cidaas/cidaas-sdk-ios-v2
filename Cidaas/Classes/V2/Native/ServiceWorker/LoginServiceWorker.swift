//
//  LoginServiceWorker.swift
//  Cidaas
//
//  Created by Ganesh on 18/05/20.
//

import Foundation

public class LoginServiceWorker {
    
    public static var shared: LoginServiceWorker = LoginServiceWorker()
    var sharedSession: SessionManager
    var sharedURL: LoginURLHelper
    
    public init() {
        sharedSession = SessionManager.shared
        sharedURL = LoginURLHelper.shared
    }
    
    public func logout(access_token : String, properties : Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void){
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
               urlString = baseURL + sharedURL.getLogout(accessToken: access_token)
               // urlString = baseURL + "/session/end_session?access_token_hint="+access_token
               
               sharedSession.startSession(url: urlString, method: .get, parameters: nil, callback: callback)
    }
    
    // login with credentials service
    public func loginWithCredentials(incomingData : LoginEntity, properties : Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        
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
        
        // construct url
        urlString = baseURL + sharedURL.getLoginWithCredentialsURL()
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, callback: callback)
    }

    /// `POST /login-srv/login/handle/afterregister/{trackId}` — expects 302 `Location` with OAuth `code`.
    public func loginAfterRegister(trackId: String, properties: Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        let baseURL = (properties["DomainURL"]) ?? ""
        if baseURL == "" {
            callback(nil, WebAuthError.shared.propertyMissingException())
            return
        }
        let encodedTrackId = trackId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trackId
        let urlString = baseURL + sharedURL.getLoginAfterRegisterURL(trackId: encodedTrackId)
        sharedSession.startSession(url: urlString, method: .post, parameters: [:]) { response, error in
            Self.deliverLoginAfterRegisterResponse(
                response: response,
                error: error,
                requestURLString: urlString,
                callback: callback
            )
        }
    }

    private static func deliverLoginAfterRegisterResponse(
        response: String?,
        error: WebAuthError?,
        requestURLString: String,
        callback: @escaping (String?, WebAuthError?) -> Void
    ) {
        if let error = error {
            callback(nil, error)
            return
        }
        guard let raw = response?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            callback(nil, WebAuthError.shared.serviceFailureException(errorCode: 400, errorMessage: "Empty login-after-register response", statusCode: 400))
            return
        }
        if raw.hasPrefix("{") || raw.hasPrefix("[") {
            callback(raw, nil)
            return
        }
        let base = URL(string: requestURLString)
        guard let resolved = resolveRedirectLocation(raw, relativeTo: base) else {
            callback(nil, WebAuthError.shared.serviceFailureException(errorCode: 400, errorMessage: "Invalid Location: \(raw)", statusCode: 400))
            return
        }
        if let identityErr = identityErrorFromRedirectURL(resolved) {
            callback(nil, identityErr)
            return
        }
        callback(resolved.absoluteString, nil)
    }

    private static func resolveRedirectLocation(_ location: String, relativeTo base: URL?) -> URL? {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let u = URL(string: trimmed), u.scheme != nil { return u }
        if let base = base { return URL(string: trimmed, relativeTo: base)?.absoluteURL }
        return URL(string: trimmed)
    }

    /// Maps identity error redirects to a WebAuthError.
    /// Matches `/error`, `/error/…`, paths ending in `/error`, or `error` / `error_code` query params.
    private static func identityErrorFromRedirectURL(_ url: URL) -> WebAuthError? {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func query(_ name: String) -> String? {
            items.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value.flatMap { $0.isEmpty ? nil : $0 }
        }
        let path = url.path.lowercased()
        let isErrorPath = path == "/error" || path.hasPrefix("/error/") || path.hasSuffix("/error")
        let hasErrorQuery = query("error") != nil || query("error_code") != nil
        guard isErrorPath || hasErrorQuery else { return nil }

        let errCode = query("error_code") ?? query("error") ?? "identity_error"
        var msg = query("error_description") ?? query("error") ?? ""
        if let decoded = msg.removingPercentEncoding { msg = decoded }
        if msg.isEmpty { msg = "Identity error" }
        return WebAuthError.shared.serviceFailureException(errorCode: 400, errorMessage: "\(errCode): \(msg)", statusCode: 400)
    }
}
