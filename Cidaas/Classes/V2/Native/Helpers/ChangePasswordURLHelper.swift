//
//  ChangePasswordURLHelper.swift
//  Cidaas
//
//  Created by Ganesh on 18/05/20.
//

import Foundation

public class ChangePasswordURLHelper {
    
    public static var shared : ChangePasswordURLHelper = ChangePasswordURLHelper()
    
    /// `PUT /password-srv/password` — change password (authenticated user).
    public var changePasswordURL = "/password-srv/password"
    /// `POST /password-srv/password` — set password when none configured (authenticated user).
    public var setPasswordURL = "/password-srv/password"
    
    public func getChangePasswordURL() -> String {
        return changePasswordURL
    }

    public func getSetPasswordURL() -> String {
        return setPasswordURL
    }
}
