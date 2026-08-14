//
//  File.swift
//
//
//  Created by Widas Ganesh RH on 18/03/25.
//

import Foundation
import UIKit
import SafariServices

public class LogoutWithBrowserController: NSObject, SFSafariViewControllerDelegate {
    // shared instance
    public static var shared : LogoutWithBrowserController = LogoutWithBrowserController()
    public var storage: TransactionStore = TransactionStore.shared
    private var safariVC: SFSafariViewController?
    
    // logout with browser
    public func logoutWithBrowser(delegate: UIViewController, sub: String, properties: Dictionary<String, String>, callback: @escaping(Result<Bool>) -> Void) {
        guard validateDomain(properties: properties, callback: callback) else { return }
        
        if sub.isEmpty {
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "sub cannot be empty", statusCode: 417)
            DispatchQueue.main.async {
                callback(Result.failure(error: error))
            }
            return
        }
        
        AccessTokenController.shared.getAccessToken(sub: sub) {
            switch $0 {
            case .success(result: let tokenResp):
                let accessToken = tokenResp.data.access_token
                if accessToken.isEmpty {
                    let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "access_token cannot be empty", statusCode: 417)
                    DispatchQueue.main.async {
                        callback(Result.failure(error: error))
                    }
                    return
                }
                self.presentBrowserLogout(
                    accessToken: accessToken,
                    sub: sub,
                    properties: properties,
                    callback: callback
                )
            case .failure(error: let error):
                DispatchQueue.main.async {
                    callback(Result.failure(error: error))
                }
            }
        }
    }
    
    // logout with browser
    public func logoutWithBrowser(delegate: UIViewController, accessToken: String, properties: Dictionary<String, String>, callback: @escaping(Result<Bool>) -> Void) {
        guard validateDomain(properties: properties, callback: callback) else { return }
        
        if accessToken.isEmpty {
            let error = WebAuthError.shared.serviceFailureException(errorCode: 417, errorMessage: "access_token cannot be empty", statusCode: 417)
            DispatchQueue.main.async {
                callback(Result.failure(error: error))
            }
            return
        }
        
        guard let sub = TokenHelper.shared.getSubFromAccessToken(from: accessToken), !sub.isEmpty else {
            let error = WebAuthError.shared.serviceFailureException(errorCode: 400, errorMessage: "not able to access sub from access_token", statusCode: 400)
            DispatchQueue.main.async {
                callback(Result.failure(error: error))
            }
            return
        }
        
        logw("Browser logout resolved sub: \(sub)", cname: "cidaas-sdk-info-log")
        presentBrowserLogout(
            accessToken: accessToken,
            sub: sub,
            properties: properties,
            callback: callback
        )
    }
    
    private func validateDomain(properties: Dictionary<String, String>, callback: @escaping(Result<Bool>) -> Void) -> Bool {
        if properties["DomainURL"] == "" || properties["DomainURL"] == nil {
            let error = WebAuthError.shared.propertyMissingException()
            let loggerMessage = "Read properties failure : " + "Error Code - " + String(describing: error.errorCode) + ", Error Message - " + error.errorMessage + ", Status Code - " + String(describing: error.statusCode)
            logw(loggerMessage, cname: "cidaas-sdk-error-log")
            DispatchQueue.main.async {
                callback(Result.failure(error: error))
            }
            return false
        }
        return true
    }
    
    private func presentBrowserLogout(
        accessToken: String,
        sub: String,
        properties: Dictionary<String, String>,
        callback: @escaping(Result<Bool>) -> Void
    ) {
        let postLogoutRedirectURL = properties["PostLogoutRedirectURL"] ?? ""
        let redirectURL = properties["RedirectURL"] ?? ""
        // ASWebAuthenticationSession must match the scheme that end_session redirects to.
        let callbackRedirectURL = !postLogoutRedirectURL.isEmpty ? postLogoutRedirectURL : redirectURL
        
        let logoutUrl = generateLogoutURL(
            accessToken: accessToken,
            postLogoutRedirectURL: postLogoutRedirectURL,
            properties: properties
        )
        
        logw("Browser logout URL: \(logoutUrl)", cname: "cidaas-sdk-network-log")
        
        guard !logoutUrl.isEmpty, let logoutURL = URL(string: logoutUrl) else {
            let error = WebAuthError.shared.serviceFailureException(errorCode: 400, errorMessage: "Invalid Logout URL: \(logoutUrl)", statusCode: 400)
            DispatchQueue.main.async {
                callback(Result.failure(error: error))
            }
            return
        }
        
        let logoutSession = SafariAuthenticationSession<Bool>(
            urlValue: logoutURL,
            redirectURL: callbackRedirectURL,
            sub: sub,
            callback: callback
        )
        storage.store(logoutSession)
    }
    
    public func generateLogoutURL(accessToken: String, postLogoutRedirectURL: String, properties: Dictionary<String, String>) -> String {
        guard !accessToken.isEmpty else { return "" }
        
        var domainURL = properties["DomainURL"] ?? ""
        while domainURL.hasSuffix("/") {
            domainURL = String(domainURL.dropLast())
        }
        guard !domainURL.isEmpty else { return "" }
        
        guard var components = URLComponents(string: domainURL + LoginURLHelper.shared.logoutURL) else {
            return ""
        }
        
        var queryItems = [URLQueryItem(name: "access_token_hint", value: accessToken)]
        if !postLogoutRedirectURL.isEmpty {
            queryItems.append(URLQueryItem(name: "post_logout_redirect_uri", value: postLogoutRedirectURL))
        }
        components.queryItems = queryItems
        return components.url?.absoluteString ?? ""
    }
}
