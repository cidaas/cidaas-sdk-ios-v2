//
//  LoginViewController.swift
//  Cidaas
//
//  Created by Ganesh on 18/05/20.
//

import Foundation

public class LoginViewController {
    
    public static var shared: LoginViewController = LoginViewController()
    var sharedInteractor: LoginInteractor
    
    public init() {
        sharedInteractor = LoginInteractor.shared
    }
    
    // login with credentials service
    public func loginWithCredentials(incomingData : LoginEntity, callback: @escaping(Result<LoginResponseEntity>) -> Void) {
        sharedInteractor.loginWithCredentials(incomingData: incomingData, callback: callback)
    }

    public func loginAfterRegister(trackId: String, callback: @escaping (Result<LoginResponseEntity>) -> Void) {
        sharedInteractor.loginAfterRegister(trackId: trackId, callback: callback)
    }
}
