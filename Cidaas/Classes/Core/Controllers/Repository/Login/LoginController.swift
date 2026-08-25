//
//  LoginController.swift
//  sdkiOS
//
//  Created by ganesh on 25/07/18.
//  Copyright © 2018 Cidaas. All rights reserved.
//

import Foundation
import SafariServices
import WebKit

public class LoginController {
    
    // shared instance
    public static var shared : LoginController = LoginController()
    public var delegate: Any!
    public var storage: TransactionStore = TransactionStore.shared
    
    // constructor
    public init() {
        
    }
    
    // login With browser
    public func loginWithBrowser(delegate: UIViewController, extraParams: Dictionary<String, String>, properties: Dictionary<String, String>, callback: @escaping(Result<LoginResponseEntity>) -> Void) {
        // null check
        if properties["DomainURL"] == "" || properties["DomainURL"] == nil || properties["ClientId"] == "" || properties["ClientId"] == nil || properties["RedirectURL"] == "" || properties["RedirectURL"] == nil {
            let error = WebAuthError.shared.propertyMissingException()
            // log error
            let loggerMessage = "Read properties failure : " + "Error Code - " + String(describing: error.errorCode) + ", Error Message - " + error.errorMessage + ", Status Code - " + String(describing: error.statusCode)
            logw(loggerMessage, cname: "cidaas-sdk-error-log")
            
            DispatchQueue.main.async {
                callback(Result.failure(error: error))
            }
            return
        }
        
        // construct url
        let loginURL = constructURL(extraParams: extraParams, properties: properties)
        presentBrowserLogin(loginURL: loginURL, delegate: delegate, properties: properties, callback: callback)
    }

    /// Opens ASWebAuthenticationSession with a pre-built authorize URL (e.g. after PAR).
    public func loginWithBrowser(
        loginURL: URL,
        delegate: UIViewController,
        properties: Dictionary<String, String>,
        callback: @escaping (Result<LoginResponseEntity>) -> Void
    ) {
        if properties["DomainURL"] == "" || properties["DomainURL"] == nil || properties["ClientId"] == "" || properties["ClientId"] == nil || properties["RedirectURL"] == "" || properties["RedirectURL"] == nil {
            let error = WebAuthError.shared.propertyMissingException()
            let loggerMessage = "Read properties failure : " + "Error Code - " + String(describing: error.errorCode) + ", Error Message - " + error.errorMessage + ", Status Code - " + String(describing: error.statusCode)
            logw(loggerMessage, cname: "cidaas-sdk-error-log")
            DispatchQueue.main.async {
                callback(Result.failure(error: error))
            }
            return
        }
        presentBrowserLogin(loginURL: loginURL, delegate: delegate, properties: properties, callback: callback)
    }

    private func presentBrowserLogin(
        loginURL: URL,
        delegate: UIViewController,
        properties: Dictionary<String, String>,
        callback: @escaping (Result<LoginResponseEntity>) -> Void
    ) {
        let redirectURL = properties["RedirectURL"] ?? ""

        if #available(iOS 12.0, *) {
            let session = SafariAuthenticationSession<LoginResponseEntity>(urlValue: loginURL, redirectURL: redirectURL, callback: callback)
            self.storage.store(session)
        } else {
            self.delegate = delegate
            openSafari(loginURL: loginURL)
        }
    }
    
    // login With social
    public func loginWithSocial(provider: String, requestId: String, delegate: UIViewController, properties: Dictionary<String, String>, callback: @escaping(Result<LoginResponseEntity>) -> Void) {
        // null check
        if properties["DomainURL"] == "" || properties["DomainURL"] == nil || properties["ClientId"] == "" || properties["ClientId"] == nil || properties["RedirectURL"] == "" || properties["RedirectURL"] == nil {
            let error = WebAuthError.shared.propertyMissingException()
            // log error
            let loggerMessage = "Read properties failure : " + "Error Code - " + String(describing: error.errorCode) + ", Error Message - " + error.errorMessage + ", Status Code - " + String(describing: error.statusCode)
            logw(loggerMessage, cname: "cidaas-sdk-error-log")
            
            DispatchQueue.main.async {
                callback(Result.failure(error: error))
            }
            return
        }
        
        // construct url
        let loginURL = constructSocialURL(provider: provider, requestId: requestId, properties: properties)
        let redirectURL = properties["RedirectURL"] ?? ""
        
       if #available(iOS 13.0, *) {

           // initiate safari session with the constructed url performing single sign on
            let session = SafariAuthenticationSession(urlValue: loginURL, redirectURL: redirectURL, callback: callback)
           // save the session
           self.storage.store(session)
       }
       else {
            self.delegate = delegate
            // call open safari method
            openSafari(loginURL : loginURL)
       }
    }
    
    // open safari browser. This method opens the Safari browser to display the login page. This method should be called internally and only for lower versions of ios (below 11.0)
    private func openSafari(loginURL : URL) {
        
        // assign url to safari controller
        let vc = SFSafariViewController(url: loginURL)
        vc.view.tintColor = UIColor.orange
        // present the safari controller
        let delegate = self.delegate as! UIViewController
        delegate.present(vc, animated: true, completion: nil)
    }
    
    /// Shared authorize params for authz query URLs and PAR body.
    public func authorizationParameters(
        extraParams: Dictionary<String, String>,
        properties: Dictionary<String, String>
    ) -> Dictionary<String, String> {
        var params = Dictionary<String, String>()
        params["redirect_uri"] = properties["RedirectURL"] ?? ""
        params["response_type"] = "code"
        params["client_id"] = properties["ClientId"] ?? ""
        params["view_type"] = properties["ViewType"] ?? "login"
        params["code_challenge"] = properties["Challenge"]
        params["code_challenge_method"] = properties["Method"]
        params["nonce"] = UUID().uuidString

        params = CidaasHTTPProofAuthz.mergingDpopJKT(into: params)

        for (key, value) in extraParams {
            params[key] = value
        }

        // Map legacy `scopes` → OAuth `scope`
        let scope = (params["scope"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let legacyScopes = (params["scopes"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if scope.isEmpty, !legacyScopes.isEmpty {
            params["scope"] = legacyScopes
            params.removeValue(forKey: "scopes")
        }

        // Generate CSRF state when omitted
        let state = (params["state"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if state.isEmpty {
            params["state"] = UUID().uuidString.replacingOccurrences(of: "-", with: "")
        }

        return params
    }

    public func constructURL(extraParams: Dictionary<String, String>, properties: Dictionary<String, String>) -> URL {
        let urlParams = authorizationParameters(extraParams: extraParams, properties: properties)

        var urlComponents = URLComponents(string: properties["AuthorizationURL"] ?? "")
        urlComponents?.queryItems = []

        for (key, value) in urlParams {
            urlComponents?.queryItems?.append(URLQueryItem(name: key, value: value))
        }

        return (urlComponents?.url)!
    }

    /// Authz URL after PAR: `client_id` + `request_uri` only.
    public func constructParAuthorizationURL(
        requestURI: String,
        properties: Dictionary<String, String>
    ) -> URL? {
        let authzURL = (properties["AuthorizationURL"] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !authzURL.isEmpty,
              var urlComponents = URLComponents(string: authzURL)
        else {
            return nil
        }
        urlComponents.queryItems = [
            URLQueryItem(name: "client_id", value: properties["ClientId"] ?? ""),
            URLQueryItem(name: "request_uri", value: requestURI)
        ]
        return urlComponents.url
    }
    
    public func constructSocialURL(provider: String, requestId: String, properties: Dictionary<String, String>) -> URL {
        
        let baseURL = (properties["DomainURL"]) ?? ""
        
        // construct url
        let urlString = baseURL + URLHelper.shared.getSocialLoginURL(provider: provider, requestId: requestId)
        
        let urlComponents = URLComponents(string : urlString)
        
        return (urlComponents?.url)!
    }
}
