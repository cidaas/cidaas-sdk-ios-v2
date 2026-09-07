//
//  ResetpasswordURLHelper.swift
//  Cidaas
//
//  Created by Ganesh on 17/05/20.
//

import Foundation

public class ResetpasswordURLHelper {
    
    public static var shared: ResetpasswordURLHelper = ResetpasswordURLHelper()
    
    /// `POST /password-srv/resetpassword` — action selected via query param.
    public var resetPasswordURL = "/password-srv/resetpassword"
    
    /// Start reset (`action=initiatereset`).
    public func getInitiateResetPasswordURL() -> String {
        return resetPasswordURL + "?action=initiatereset"
    }
    
    /// Validate OTP / code (`action=validatecode`).
    public func getHandleResetPasswordURL() -> String {
        return resetPasswordURL + "?action=validatecode"
    }
   
    /// Accept new password (`action=acceptreset`).
    public func getResetPasswordURL() -> String {
        return resetPasswordURL + "?action=acceptreset"
    }
}
