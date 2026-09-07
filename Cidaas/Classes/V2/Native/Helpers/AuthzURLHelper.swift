//
//  AuthzURLHelper.swift
//  Cidaas
//
//  Created by Ganesh on 17/05/20.
//

import Foundation

public class AuthzURLHelper {
    
    public static var shared : AuthzURLHelper = AuthzURLHelper()
    
    public var authzURL = "/authz-srv/authrequest/authz/generate"
    /// Silent / authorize entry (`GET`, query params, 302).
    public var authRequestURL = "/authz-srv/authz"
    public var preloginMetadataURL = "/token-srv/prelogin/metadata"
    
    public func getAuthzURL() -> String {
        return authzURL
    }

    public func getAuthRequestURL() -> String {
        return authRequestURL
    }

    public func getPreloginMetadataURL(trackId: String) -> String {
        return preloginMetadataURL + "/" + trackId
    }
}
