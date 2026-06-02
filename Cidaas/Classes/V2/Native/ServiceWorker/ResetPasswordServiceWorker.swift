//
//  ResetPasswordServiceWorker.swift
//  Cidaas
//
//  Created by Ganesh on 17/05/20.
//

import Foundation

public class ResetPasswordServiceWorker {
    
    public static var shared: ResetPasswordServiceWorker = ResetPasswordServiceWorker()
    var sharedSession: SessionManager
    var sharedURL: ResetpasswordURLHelper
    
    public init() {
        sharedSession = SessionManager.shared
        sharedURL = ResetpasswordURLHelper.shared
    }
    
    // Initiate reset password
    public func initiateResetPassword(incomingData : InitiateResetPasswordEntity, properties : Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        
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
        
        // construct url
        urlString = baseURL + sharedURL.getInitiateResetPasswordURL()
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, callback: callback)
    }
    
    // Handle reset password
    public func handleResetPassword(incomingData : HandleResetPasswordEntity, properties : Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        
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
        
        // construct url
        if ((properties["CidaasVersion"] != nil) && properties["CidaasVersion"] == "3") {
            urlString = baseURL + sharedURL.getHandleResetPasswordV3URL()
        } else {
            urlString = baseURL + sharedURL.getHandleResetPasswordURL()
        }

        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams) { response, error in
            Self.deliverHandleResetPasswordResponse(response: response, error: error, requestURLString: urlString, callback: callback)
        }
    }
    
    // reset password
    public func resetPassword(incomingData : ResetPasswordEntity, properties : Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        
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
        
        // construct url
        if ((properties["CidaasVersion"] != nil) && properties["CidaasVersion"] == "3") {
            urlString = baseURL + sharedURL.getResetPasswordV3URL()
        } else {
            urlString = baseURL + sharedURL.getResetPasswordURL()
        }
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, callback: callback)
    }

    /// **`startSession`** returns the raw **`Location`** header string on **302** (not JSON). Resolve URL, then map **`/identity/error`** → error or **`exchangeId`+`rprq`** → presenter JSON.
    private static func deliverHandleResetPasswordResponse(response: String?, error: WebAuthError?, requestURLString: String, callback: @escaping (String?, WebAuthError?) -> Void) {
        if let error = error {
            callback(nil, error)
            return
        }
        guard let raw = response?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            callback(nil, WebAuthError.shared.serviceFailureException(errorCode: 400, errorMessage: "Empty response", statusCode: 400))
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
        if let json = presenterJSONFromExchangeIdAndRprq(resolved) {
            callback(json, nil)
            return
        }
        callback(nil, WebAuthError.shared.serviceFailureException(errorCode: 400, errorMessage: "Could not read exchangeId and rprq from Location: \(raw)", statusCode: 400))
    }

    private static func resolveRedirectLocation(_ location: String, relativeTo base: URL?) -> URL? {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let u = URL(string: trimmed), u.scheme != nil { return u }
        if let base = base { return URL(string: trimmed, relativeTo: base)?.absoluteURL }
        return URL(string: trimmed)
    }

    private static func identityErrorFromRedirectURL(_ url: URL) -> WebAuthError? {
        guard url.path.lowercased().contains("error") else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func query(_ name: String) -> String? {
            items.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value.flatMap { $0.isEmpty ? nil : $0 }
        }
        let errCode = query("error_code") ?? query("error") ?? "identity_error"
        var msg = query("error_description") ?? query("error") ?? ""
        if let decoded = msg.removingPercentEncoding { msg = decoded }
        if msg.isEmpty { msg = "Identity error" }
        return WebAuthError.shared.serviceFailureException(errorCode: errCode, errorMessage: msg, statusCode: 400)
    }

    private static func presenterJSONFromExchangeIdAndRprq(_ url: URL) -> String? {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        var exchangeId: String?
        var rprq: String?
        for item in items {
            guard let value = item.value, !value.isEmpty else { continue }
            if item.name.caseInsensitiveCompare("exchangeId") == .orderedSame {
                exchangeId = value
            } else if item.name.caseInsensitiveCompare("rprq") == .orderedSame {
                rprq = value
            }
        }
        guard let excId = exchangeId, let rp = rprq else { return nil }
        let payload: [String: Any] = [
            "success": true,
            "status": 200,
            "data": ["exchangeId": excId, "resetRequestId": rp]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload), let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }
}
