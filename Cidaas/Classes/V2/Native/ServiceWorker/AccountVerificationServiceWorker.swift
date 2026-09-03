//
//  AccountVerificationServiceWorker.swift
//  Cidaas
//
//  Created by Ganesh on 14/05/20.
//

import Foundation

public class AccountVerificationServiceWorker {
    
    public static var shared: AccountVerificationServiceWorker = AccountVerificationServiceWorker()
    var sharedSession: SessionManager
    var sharedURL: AccountVerificationURLHelper
    
    public init() {
        sharedSession = SessionManager.shared
        sharedURL = AccountVerificationURLHelper.shared
    }
    
    // initiate account verification
    public func initiateAccountVerification(incomingData : InitiateAccountVerificationEntity, properties : Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        
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
        
        let baseURL = (properties["DomainURL"]) ?? ""
        
        if (baseURL == "") {
            callback(nil, WebAuthError.shared.propertyMissingException())
            return
        }
        
        let urlString = baseURL + sharedURL.getInitiateAccountVerificationURL()
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams) { response, error in
            Self.deliverInitiateAccountVerificationResponse(response: response, error: error, requestURLString: urlString, callback: callback)
        }
    }
    
    // verify account
    public func verifyAccount(incomingData : VerifyAccountEntity, properties : Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        
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
        
        let baseURL = (properties["DomainURL"]) ?? ""
        
        if (baseURL == "") {
            callback(nil, WebAuthError.shared.propertyMissingException())
            return
        }
        
        let urlString = baseURL + sharedURL.getVerifyAccountURL()
        
        sharedSession.startSession(url: urlString, method: .post, parameters: bodyParams, callback: callback)
    }
    
    // get account verification list
    public func getAccountVerificationList(sub: String, properties : Dictionary<String, String>, callback: @escaping (String?, WebAuthError?) -> Void) {
        
        let baseURL = (properties["DomainURL"]) ?? ""
        
        if (baseURL == "") {
            callback(nil, WebAuthError.shared.propertyMissingException())
            return
        }
        
        let urlString = baseURL + sharedURL.getVerifyAccountListURL(sub: sub)
        
        sharedSession.startSession(url: urlString, method: .get, parameters: nil, callback: callback)
    }

    /// Initiate returns **302** with `accvid` (code flow) on `Location`, or JSON. Map redirect → presenter JSON / error.
    private static func deliverInitiateAccountVerificationResponse(response: String?, error: WebAuthError?, requestURLString: String, callback: @escaping (String?, WebAuthError?) -> Void) {
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
        if let redirectErr = errorFromRedirectURL(resolved) {
            callback(nil, redirectErr)
            return
        }
        if let json = presenterJSONFromAccvid(resolved) {
            callback(json, nil)
            return
        }
        callback(nil, WebAuthError.shared.serviceFailureException(errorCode: 400, errorMessage: "Could not read accvid from Location: \(raw)", statusCode: 400))
    }

    private static func resolveRedirectLocation(_ location: String, relativeTo base: URL?) -> URL? {
        let trimmed = location.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let u = URL(string: trimmed), u.scheme != nil { return u }
        if let base = base { return URL(string: trimmed, relativeTo: base)?.absoluteURL }
        return URL(string: trimmed)
    }

    private static func errorFromRedirectURL(_ url: URL) -> WebAuthError? {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func query(_ name: String) -> String? {
            items.first { $0.name.caseInsensitiveCompare(name) == .orderedSame }?.value.flatMap { $0.isEmpty ? nil : $0 }
        }
        let errCode = query("error_code")
        let err = query("error")
        guard errCode != nil || err != nil else { return nil }
        let code = errCode ?? err ?? "identity_error"
        var msg = query("error_description") ?? err ?? ""
        if let decoded = msg.removingPercentEncoding { msg = decoded }
        if msg.isEmpty { msg = "Account verification error" }
        return WebAuthError.shared.serviceFailureException(errorCode: code, errorMessage: msg, statusCode: 400)
    }

    private static func presenterJSONFromAccvid(_ url: URL) -> String? {
        guard let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems else { return nil }
        var accvid: String?
        for item in items {
            guard let value = item.value, !value.isEmpty else { continue }
            if item.name.caseInsensitiveCompare("accvid") == .orderedSame {
                accvid = value
                break
            }
        }
        guard let id = accvid else { return nil }
        let payload: [String: Any] = [
            "success": true,
            "status": 200,
            "data": ["accvid": id]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload), let str = String(data: data, encoding: .utf8) else { return nil }
        return str
    }
}
