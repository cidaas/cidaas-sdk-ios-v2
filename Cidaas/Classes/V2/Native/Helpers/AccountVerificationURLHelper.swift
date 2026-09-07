//
//  AccountVerificationURLHelper.swift
//  Cidaas
//
//  Created by Ganesh on 14/05/20.
//

import Foundation

public class AccountVerificationURLHelper {
    
    public static var shared: AccountVerificationURLHelper = AccountVerificationURLHelper()
    
    public var initiateAccountVerificationURL = "/verification-actions-srv/account/initiation"
    public var verifyAccountURL = "/verification-actions-srv/account"
    public var verifyAccountListURL = "/users-srv/user/communication/status"
    
    public func getInitiateAccountVerificationURL() -> String {
        return initiateAccountVerificationURL
    }
    
    public func getVerifyAccountURL() -> String {
        return verifyAccountURL
    }
    
    public func getVerifyAccountListURL(sub: String) -> String {
        return verifyAccountListURL + "/" + sub
    }
}
