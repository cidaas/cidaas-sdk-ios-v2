//
//  SafariAuthenticationSession.swift
//  Cidaas
//
//  Created by ganesh on 04/12/18.
//

import Foundation
import SafariServices
import AuthenticationServices

@available(iOS 12.0, *)
public class SafariAuthenticationSession<T> : AuthSession<T>, ASWebAuthenticationPresentationContextProviding {
    
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        return UIApplication.shared.windows.filter({ $0.isKeyWindow }).last ?? ASPresentationAnchor()
    }
    
    
    var authSession: ASWebAuthenticationSession?
    var urlValue: URL
    
    public init(urlValue : URL, redirectURL : String, sub: String = "",callback: @escaping (Result<T>) -> ()) {
        self.urlValue = urlValue
        super.init(callback: callback)
        let arrayOfURL = redirectURL.components(separatedBy: "://")
        var shortRedirectURL = redirectURL
        if arrayOfURL.count > 0 {
            shortRedirectURL = arrayOfURL[0]
        }
        
        self.authSession = ASWebAuthenticationSession(url: self.urlValue, callbackURLScheme:shortRedirectURL,
        completionHandler: { (resultURL, resultError) in
            guard resultError == nil, let callbackURL = resultURL else {
                // Avoid treating the next login redirect as a logout success.
                if T.self == Bool.self {
                    Cidaas.shared.browserLogoutCallback = nil
                }
                if case SFAuthenticationError.canceledLogin = resultError! {
                    callback(Result.failure(error: WebAuthError.shared.userCancelledException()))
                } else {
                    callback(Result.failure(error: WebAuthError.shared.userCancelledException()))
                }
                return TransactionStore.shared.clear()
            }
            
            if T.self == Bool.self {
                DBHelper.shared.removeAccessToken(sub: sub)
                CidaasHTTPProofToken.clearPersistedDpopBinding()
            }
            
            _ = TransactionStore.shared.resume(callbackURL, options: [:])
             
        })
        
        if #available(iOS 13.0, *) {
            self.authSession?.presentationContextProvider = self
        }
        self.authSession?.start()
    }
}
